//
//  VMPFrontView.m
//  OnTheFly
//
//  Created by sumiisan on 2013/10/06.
//
//
#include "MultiPlatform.h"
#include <sys/types.h>
#include <sys/sysctl.h>

#if VMP_IPHONE
//
//	iphone
//
#import "VMAppDelegate.h"

#define vmpTextValue text
#define vmpAlphaValue alpha
#define quartzPath CGPath
#define vmpFrontViewIsVisible ([[UIApplication sharedApplication] applicationState] == UIApplicationStateActive)
#define CALayerCompositingFilterAvailable 0
#else
//
//	osx
//
#import "VMPAppDelegate.h"
#import "NSBezierPath+CGPathConversion.h"
#import "VMPColorAnimation.h"
#define addLineToPoint lineToPoint
#define vmpAlphaValue alphaValue
#define vmpTextValue stringValue
#define vmpFrontViewIsVisible ( [VMPAppDelegate defaultAppDelegate].window ? [VMPAppDelegate defaultAppDelegate].window.isVisible : NO )
#define CALayerCompositingFilterAvailable 1
#endif

#import "VMPFrontView.h"
#import "VMSong.h"
#import "VMPSongPlayer.h"
#import "VMScoreEvaluator.h"

#define Eucl_Distance(p1,p2) ({ double	d1 = p1.x - p2.x, d2 = p1.y - p2.y; sqrt(d1 * d1 + d2 * d2); })

/*---------------------------------------------------------------------------------
 
 VMPShapeLayer
 
 ----------------------------------------------------------------------------------*/



@implementation VMPFrontView

static const int numOfCircles = 5;
static const __unused CGFloat dragThreshold = 30;
static CGFloat holeHotSpotRadius = 0;

@synthesize frontViewWasVisibleAtLastCall = frontViewWasVisibleAtLastCall_,standardRadius=standardRadius_,holeCenter=holeCenter_,dragOffsetY=dragOffsetY_,angle=angle_,hueOffset=hueOffset_,speed=speed_,velocity=velocity_,targetVelocity=targetVelocity_,stem=stem_,blendMode=blendMode_,shouldRecognizeTap=shouldRecognizeTap_,timeIndicator=timeIndicator_,touchBeginPoint=touchBeginPoint_,
stemLength=stemLength_,refreshScreenCounter=refreshScreenCounter_,lastDayPhase=lastDayPhase_,circles=circles_;


#if VMP_OSX
@synthesize transitionRemain=transitionRemain_,transitionColor=transitionColor_;


//
//	this utility is for os x version < 10.8 ( alternative for NSColor's .CGColor )
//
- (CGColorRef)CGColorFromNSColor:(NSColor*)color {
    const NSInteger numberOfComponents = [color numberOfComponents];
    CGFloat components[numberOfComponents];
    CGColorSpaceRef colorSpace = [[color colorSpace] CGColorSpace];
    [color getComponents:(CGFloat *)&components];
    return (CGColorRef)[(id)CGColorCreate(colorSpace, components) autorelease];
}
#endif

- (void)setBackgroundColor:(VMPColor *)backgroundColor {
	[super setBackgroundColor:backgroundColor];
	if ( useCALayer ) return;
	
	CGFloat brightness;
#if VMP_OSX
	brightness = backgroundColor.brightnessComponent;
#else
	brightness = [backgroundColor getHue:nil saturation:nil brightness:&brightness alpha:nil];
#endif
	
	if ( brightness < 0.5 ) {
		self.blendMode = kCGBlendModeScreen;
	} else {
		self.blendMode = kCGBlendModeMultiply;
	}
}

- (void)makeCircles {
	for (CAShapeLayer *c in circles_) {
		[c removeFromSuperlayer];
	}
	[self.circles removeAllObjects];
	for ( int i = 0; i < numOfCircles + 1; ++i ) {
		VMPBezierPath *path;
		if( i < numOfCircles )
			path = [VMPBezierPath bezierPathWithOvalInRect:VMPMakeRect(-standardRadius_, - standardRadius_,
																	   standardRadius_*2, standardRadius_*2)];
		else
			path = [VMPBezierPath bezierPathWithOvalInRect:VMPMakeRect(-standardRadius_*0.95, - standardRadius_*0.95,
																	   standardRadius_*1.9, standardRadius_*1.9)];
		
		CAShapeLayer *circle = [CAShapeLayer layer];
		circle.path = path.quartzPath;
		[self.circles addObject:circle];
#if VMP_OSX
		circle.fillColor = [self CGColorFromNSColor:[VMPColor clearColor]];
#else
		circle.fillColor = [VMPColor clearColor].CGColor;
#endif
		circle.frame = CGRectMake(holeCenter_.x, holeCenter_.y, 0, 0);
#if CALayerCompositingFilterAvailable
		if( self.blendMode == kCGBlendModeMultiply )
			circle.compositingFilter = [CIFilter filterWithName:@"CIMultiplyBlendMode"];
		else
			circle.compositingFilter = [CIFilter filterWithName:@"CIScreenBlendMode"];
#endif
		[self.layer addSublayer:circle];
	}
}

- (void)initializeShapes {
	if( useCALayer ) [self makeCircles];
	self.stem = [CAShapeLayer layer];
	stem_.path = [VMPBezierPath bezierPath].quartzPath;
	stem_.hidden = YES;
	[self.layer addSublayer:stem_];
}

- (BOOL)hasEnoughCPUPowerForCPURendering {
#if VMP_IPHONE
	size_t size;
	sysctlbyname("hw.machine", NULL, &size, NULL, 0);
	char *machine = malloc(size);
	sysctlbyname("hw.machine", machine, &size, NULL, 0);
	NSString *platform = [NSString stringWithUTF8String:machine];
	free(machine);
	
	int numero;
	NSLog(@"iOS platform: %@",platform);
	
	NSString *dev1 = [[platform componentsSeparatedByString:@","] objectAtIndex:0];
	if ( [dev1 hasPrefix:@"iPhone"] ) {
		numero = [[dev1 substringFromIndex:6] intValue];
		if ( numero < 5 ) return NO;
	} else if ( [dev1 hasPrefix:@"iPad"] ) {
		numero = [[dev1 substringFromIndex:4] intValue];
		if ( numero < 3 ) return NO;
	} else if ( [dev1 hasPrefix:@"iPod"] ) {
		numero = [[dev1 substringFromIndex:4] intValue];
		if ( numero < 5 ) return NO;
	}
#endif
	return YES;
}

- (id)initWithFrame:(VMPRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code

#if VMP_OSX
		[self setWantsLayer:YES];
		screenSize = frame.size;
#else
		screenSize = [UIScreen mainScreen].bounds.size;
#endif
		
#if CALayerCompositingFilterAvailable
		useCALayer = NO;	//	no! because it was not efficient. drawing in drawRect() was faster!
#else
		useCALayer = YES;	//	yes! because it is too slow anyway
		//! [self hasEnoughCPUPowerForCPURendering];	//	use CALayer without compositing filter if the CPU power is low.
#endif
				
		self.timeIndicator = [[[VMPLabel alloc] initWithFrame:VMPRectZero] autorelease];
		timeIndicator_.hidden = YES;
		timeIndicator_.tag = 'timL';
		timeIndicator_.backgroundColor = [VMPColor clearColor];
		timeIndicator_.textColor = [VMPColor grayColor];
#if VMP_IPHONE
		timeIndicator_.textAlignment = NSTextAlignmentCenter;
#else
		timeIndicator_.alignment = NSCenterTextAlignment;
		timeIndicator_.drawsBackground = NO;
		timeIndicator_.editable = NO;
		timeIndicator_.bordered = NO;
		timeIndicator_.font = [NSFont systemFontOfSize:14];
		
#endif
		[self addSubview:timeIndicator_];
		[self animate:nil];	//	initialize position and color

		//
		
		self.circles = [NSMutableArray array];
		[self calculateDimensions:self.bounds.size];
		
		[self initializeShapes];
		
		NSNotificationCenter *dc = (NSNotificationCenter*) [NSNotificationCenter defaultCenter];
		[dc addObserver:self selector:@selector(playerStarted:) name:PLAYERSTARTED_NOTIFICATION object:nil];
		[dc addObserver:self selector:@selector(endOfSequence:) name:ENDOFSEQUENCE_NOTIFICATION object:nil];
		[dc addObserver:self selector:@selector(playerStopped:) name:PLAYERSTOPPED_NOTIFICATION object:nil];
		
		lastDayPhase_ = DEFAULTEVALUATOR.timeManager.dayPhase;
		self.backgroundColor = DEFAULTEVALUATOR.timeManager.backgroundColor;
		touchBeginPoint_ = VMPMakePoint(-9999, 0);
    }
	
    return self;
}

- (void)calculateDimensions:(CGSize)size {
	screenSize = size;
	CGFloat narrowerSide = MIN( size.height, size.width );
	
	standardRadius_ = narrowerSide * 0.21;
	holeHotSpotRadius = narrowerSide * 0.27;
	holeCenter_ = CGPointMake( size.width * 0.5, size.height * 0.33 );
	
	//NSLog(@"std rad:%f",standardRadius_);
	[self makeCircles];
	refreshScreenCounter_ = 99999;

	self.frame = CGRectMake(0,0,size.width,size.height);
}

- (BOOL)isOpaque {
	return YES;
}

#if VMP_IPHONE
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
	UITouch *touch = [[event allTouches] anyObject];
    touchBeginPoint_ = [touch locationInView:self];
#elif A_DUMMY_CONDITION_NEVER_TRUE
}
#else
- (void)mouseDown:(NSEvent *)theEvent {
	touchBeginPoint_ = [self convertPoint:[theEvent locationInWindow] fromView:nil];
#endif
	stemLength_ = 0;
	shouldRecognizeTap_ = YES;
	
	BOOL touchOnHole = Eucl_Distance( holeCenter_, touchBeginPoint_ ) <= holeHotSpotRadius;
#if VMP_OSX
	BOOL touchOnIndicator = CGRectContainsPoint( NSRectToCGRect(timeIndicator_.frame), NSPointToCGPoint(touchBeginPoint_) );
#else
	BOOL touchOnIndicator = CGRectContainsPoint(timeIndicator_.frame, touchBeginPoint_);
#endif
	dragOffsetY_ = 0;
	if ( touchOnIndicator ) {
		shouldRecognizeTap_ = NO;
		dragOffsetY_ = touchBeginPoint_.y - timeIndicator_.frame.origin.y;
	}
	
	if(( ! touchOnHole ) && (! touchOnIndicator) )
		touchBeginPoint_.x = -9999;		//	indicates invalid touch
	else
		timeIndicator_.backgroundColor = VMPColorBy(0.7, 0.7, 0.7, 0.2);
}

#if VMP_IPHONE

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
	stemLength_ = 0;
	stem_.strokeColor = [UIColor clearColor].CGColor;
	timeIndicator_.backgroundColor = [UIColor clearColor];
	touchBeginPoint_.x = -9999;
}

	
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
#elif A_DUMMY_CONDITION_NEVER_TRUE
}
#else
- (void)mouseUp:(NSEvent *)theEvent {
#endif

	timeIndicator_.backgroundColor = [VMPColor clearColor];
	if ( stemLength_ == 0 && touchBeginPoint_.x >= 0 && shouldRecognizeTap_ )
		[self togglePlayState:nil];
	touchBeginPoint_.x = -9999;
	
}
	
#if VMP_IPHONE
- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
	if ( touchBeginPoint_.x < 0 ) return;	//	invalid touch
	
	UITouch *touch = [[event allTouches] anyObject];
	CGPoint touchPoint = [touch locationInView:self];
#elif A_DUMMY_CONDITION_NEVER_TRUE
}
#else
- (void)mouseDragged:(NSEvent *)theEvent {
	if ( touchBeginPoint_.x < 0 ) return;	//	invalid touch
	VMPPoint touchPoint = [self convertPoint:[theEvent locationInWindow] fromView:nil];
#endif
	
	if ( ! CURRENTSONG.supportsTimer ) {
		return;		//	no timer support
	}
	
	//double distance = Eucl_Distance( touchPoint, touchBeginPoint_ );
	
	CGFloat baseY = ( holeCenter_.y + standardRadius_ * 1.2 );
	CGFloat distance = touchPoint.y - dragOffsetY_ - baseY;
	
	if ( distance > 0 ) {
		shouldRecognizeTap_ = NO;
		
		if ( distance > 120 )
		distance = 120;	//	that's 12 hours
		
		stemLength_ = distance;
		float minutes = distance * distance * 0.05;
		
		DEFAULTEVALUATOR.timeManager.remainTimeUntilShutdown = minutes * 60;

		[self plotStem:minutes enabled:YES];
#if VMP_OSX
		stem_.strokeColor = [self CGColorFromNSColor:[VMPColor lightGrayColor]];
#else
		stem_.strokeColor = [VMPColor lightGrayColor].CGColor;
#endif
		stem_.lineWidth = 4;
		stem_.hidden = NO;
		stem_.lineCap = kCALineCapRound;
		
		
		timeIndicator_.hidden = NO;
		
	} else {
		[self plotStem:0. enabled:NO];
		DEFAULTEVALUATOR.timeManager.remainTimeUntilShutdown = -1;
	}
	
#if VMP_OSX
//	[self animate:nil];
#endif
}

- (void)plotStem:(float)minutesLeft enabled:(BOOL)enabled {

	if ( ! enabled ) {
		stemLength_ = 0;
		stem_.hidden = YES;
		stem_.path = [VMPBezierPath bezierPath].quartzPath;	//	test
		timeIndicator_.hidden = YES;
	} else {
		float min = minutesLeft > 0 ? minutesLeft : 0;	//	avoid zero division
		
		//
		//	stem
		//
		stemLength_ = sqrt( min / 0.05 );
		if ( stemLength_ > 150 ) stemLength_ = 0;	//	insurance
		CGFloat baseY = ( holeCenter_.y + standardRadius_ * 1.2 );
		if( useCALayer ) {
			VMPBezierPath *path = [VMPBezierPath bezierPath];
			[path moveToPoint:VMPMakePoint(holeCenter_.x, baseY ) ];
			[path addLineToPoint:VMPMakePoint(holeCenter_.x, baseY + stemLength_ )];
			stem_.path = path.quartzPath;
		}
		//
		//	time indicator
		//
		timeIndicator_.frame = VMPMakeRect( 0, baseY + stemLength_, self.bounds.size.width, 30 );
		if ( min > 5 * 60 )
			min = round( min / 30. ) * 30;
		else if ( min > 3 * 60 )
			min = round( min / 15. ) * 15;
		else if ( min > 15 )
			min = round( min / 5. )  * 5;
		
		float hourP	= ((int)min) / 60.0;
		int minP	= (((int)min) % 60 );
		
		if ( minutesLeft > 0 ) {
			timeIndicator_.vmpTextValue = [NSString stringWithFormat:@"%d:%02d", (int)hourP, minP ];
		} else {
			timeIndicator_.vmpTextValue = @"•••";
		}
	}
}

- (void)playerStarted:(NSNotification*)notification {
	targetVelocity_ = 1;
}

- (void)playerStopped:(NSNotification*)notification {
	targetVelocity_ = 0;
}

- (void)endOfSequence:(NSNotification*)notification {
	targetVelocity_ = 0;
}

- (void)togglePlayState:(id)sender {
#if VMP_IPHONE
	if ( [DEFAULTSONGPLAYER isRunning] ) {
		targetVelocity_ = 0;
		[[VMAppDelegate defaultAppDelegate] pause];
	} else {
		if( [[VMAppDelegate defaultAppDelegate] resume] ) {
			targetVelocity_ = 1;
		}
	}
#else
	if ( [DEFAULTSONGPLAYER isRunning] ) {
		targetVelocity_ = 0;
		[[VMPAppDelegate defaultAppDelegate] pause:self];
	} else {
		targetVelocity_ = 1;
		[[VMPAppDelegate defaultAppDelegate] resume:self];
	}
#endif
}

#if VMP_OSX		// disable drawrect for iOS because it conflicts with UIView Animation
- (void)drawRect:(VMPRect)rect {
	[super drawRect:rect];
	if ( useCALayer ) return;
	if ( rect.size.width == 0 || rect.size.height == 0 ) return;
	
	CGFloat brightness = touchBeginPoint_.x >= 0 ? 0.7 : 1.0 - ( velocity_ * 0.2 );
	CGFloat radius = screenSize.width * 0.2;//( 0.25 - ( velocity_ * 0.08 ));
	CGFloat gap = radius * ( 0.4 - velocity_ * 0.3 );
	CGFloat baseRad = ( 2 * M_PI / numOfCircles );
	CGFloat hueInterval = 1.0 / numOfCircles;
	CGFloat offsetRad = angle_ * 2 * M_PI;
	CGContextRef context = [[NSGraphicsContext currentContext] graphicsPort];
	//	circles
	VMPBezierPath *bezierPath;
	for( int i = 0; i < numOfCircles; ++i ) {
		CGFloat rad = baseRad * i + offsetRad;
		CGPoint center = CGPointMake( holeCenter_.x + cos(rad) * gap, holeCenter_.y + sin(rad) * gap );
		bezierPath  = [VMPBezierPath
					   bezierPathWithOvalInRect:VMPMakeRect(center.x - radius, center.y - radius,
															radius*2, radius*2)];

		CGFloat hue = hueInterval * i;
		
		[VMPColorByHSBA(hue, 1., brightness, 0.1 + ( velocity_ * 0.35) ) setFill];
#if VMP_IPHONE
		[bezierPath fillWithBlendMode:self.blendMode alpha:1.];
#else
		CGContextSetBlendMode( context, self.blendMode );
		[bezierPath fill];
#endif //VMP_IPHONE
	}
	
	if( stemLength_ > 0 ) {
		VMPBezierPath *path = [VMPBezierPath bezierPath];
		CGFloat baseY = ( holeCenter_.y + standardRadius_ * 1.2 );
		
		[path moveToPoint:VMPMakePoint(holeCenter_.x, baseY ) ];
		[path addLineToPoint:VMPMakePoint(holeCenter_.x, baseY + stemLength_ )];
		CGContextSetBlendMode( context, kCGBlendModeCopy );
		path.lineWidth = 4;
#if VMP_OSX
		path.lineCapStyle = NSRoundLineCapStyle;
#else
		path.lineCapStyle = kCGLineCapRound;
#endif //VMP_OSX
		[[VMPColor lightGrayColor] setStroke];
		[path stroke];
	}
}
#endif //VMP_OSX

	
- (void)updateCALayers {
	CGFloat narrowSide = MIN(screenSize.width,screenSize.height);
	CGFloat brightness = touchBeginPoint_.x >= 0 ? 0.7 : 1.0 - ( velocity_ * 0.2 );
	CGFloat radius = narrowSide * 0.22 + (( 1 - velocity_ ) * narrowSide * 0.3 );
	CGFloat r2 = radius*2;
	CGFloat gapBaseRadius = radius < 160.0 ? radius : 160.0;
	CGFloat gap = gapBaseRadius * 0.2 - ( radius * velocity_ * 0.1 );
	CGFloat baseRad = ( 2 * M_PI / numOfCircles );
	CGFloat hueInterval = 1.0 / numOfCircles;
	CGFloat offsetRad = angle_ * 2 * M_PI;
#if CALayerCompositingFilterAvailable
	CGFloat alpha = 0.2 + ( velocity_ * 0.4 );
#else
	CGFloat alpha = 0.1 + ( velocity_ * velocity_ *.3 );
#endif
	for ( int i = 0; i < numOfCircles; ++i ) {
		CGFloat rad = baseRad * i + offsetRad;
		CAShapeLayer *circle = [self.circles objectAtIndex:i];
		CGPoint center = CGPointMake( holeCenter_.x + cos(rad) * gap, holeCenter_.y + sin(rad) * gap );
#if CALayerCompositingFilterAvailable
		CGFloat hue = hueInterval * i;
#else
		CGFloat hue = hueInterval * i + hueOffset_;
#endif
		if ( hue > 1 ) hue -= 1.;
#if VMP_OSX
		circle.fillColor = [self CGColorFromNSColor:VMPColorByHSBA(hue, 1., brightness, alpha )];
#else
		circle.fillColor = VMPColorByHSBA(hue, 1., brightness, alpha ).CGColor;
#endif
		circle.frame = CGRectMake( center.x, center.y, r2, r2 );
	}
	CAShapeLayer *centerCircle = [self.circles lastObject];
	CGFloat a = velocity_ * 1.2 - 0.6;
	centerCircle.fillColor = VMPColorByHSBA( 0, 0, 0.1, a > 0. ? a : 0. ).CGColor;
	centerCircle.frame = CGRectMake( holeCenter_.x, holeCenter_.y, r2, r2 );
	
}

//	handle remote control
- (MPRemoteCommandHandlerStatus)handleRemoteControl {
	[self togglePlayState:nil];
    return MPRemoteCommandHandlerStatusSuccess;
}

- (void)animate:(id)whatever {
	BOOL frontviewIsVisible;
	@try {
		frontviewIsVisible = vmpFrontViewIsVisible;		//	can cause EXC_BAD_ACCESS .. see if we can catch this.
	}
	@catch (NSException *exception) {
		frontviewIsVisible = NO;
	}
	
	//	pre-calculate velocities
	if ( velocity_ != targetVelocity_ ) {
		velocity_ += ( targetVelocity_ - velocity_ ) * 0.02;
#if VMP_OSX
		stem_.strokeColor = [self CGColorFromNSColor:VMPColorBy( .5, .5, .5, velocity_ * .6 + .1 )];
#else
		stem_.strokeColor = VMPColorBy( .5, .5, .5, velocity_ * .6 + .1 ).CGColor;
#endif
		timeIndicator_.vmpAlphaValue =velocity_ * .6 + .3;
	}

	//
	//	update graph
	//
	if ( frontviewIsVisible ) {
		if ( useCALayer ) {
			[self updateCALayers];
		} else {
			if ( velocity_ > 0 )
				VMPSetNeedsDisplay(self);
		}
	}
	
	//
	//	update counters and timers
	//
	angle_ += 0.011 * velocity_;
	hueOffset_ += 0.007 * velocity_;
	++refreshScreenCounter_;
	if ( angle_ > 1 )
		angle_ -= 1;
	if ( hueOffset_ > 1 )
		hueOffset_ -= 1;
	if ( refreshScreenCounter_ > 30 ) {
		refreshScreenCounter_ = 0;
		float minutesLeft = DEFAULTEVALUATOR.timeManager.remainTimeUntilShutdown / 60.0;
		if ( minutesLeft < 0 && (! DEFAULTSONGPLAYER.isRunning ))
			DEFAULTEVALUATOR.timeManager.shutdownTime = nil;		//	stop timer if we are not playing
		if ( frontviewIsVisible )
			[self plotStem: minutesLeft enabled: DEFAULTEVALUATOR.timeManager.shutdownTime != nil];
		
		if ( frontviewIsVisible != frontViewWasVisibleAtLastCall_ ) {
			NSLog(@"appState changed %d -> %d", frontViewWasVisibleAtLastCall_, frontviewIsVisible );
			frontViewWasVisibleAtLastCall_ = frontviewIsVisible;
		}
		
		VMDayPhase dp = DEFAULTEVALUATOR.timeManager.dayPhase;
		if ( dp != lastDayPhase_ ) {
			NSLog(@"dayPhase changed %d -> %d", lastDayPhase_, dp );
			[[NSNotificationCenter defaultCenter] postNotificationName:DAYPHASE_CHANGED_NOTIFICATION object:self];

#if VMP_IPHONE
			[UIView animateWithDuration:5.0f animations:^()
			 {
				 self.backgroundColor = DEFAULTEVALUATOR.timeManager.backgroundColor;
			 }];
#else
			VMPColorAnimation *anim = [[VMPColorAnimation alloc] initWithDuration:5.0 animationCurve:NSAnimationLinear];
			anim.target = self;
			anim.method = @selector(setBackgroundColor:);
			anim.color1 = self.backgroundColor;
			anim.color2 = DEFAULTEVALUATOR.timeManager.backgroundColor;
			anim.animationBlockingMode = NSAnimationNonblockingThreaded;
			[anim startAnimation];
			[anim release];
#endif
			lastDayPhase_ = dp;
		}
	}

	[self performSelector:@selector(animate:) withObject:nil afterDelay:( velocity_ > 0 ? 0.03333333334 : 1. )];
}

- (void)dealloc {
	self.circles = nil;
	self.stem = nil;
	self.timeIndicator = nil;
#if VMP_OSX
	self.transitionColor = nil;
#endif
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[super dealloc];
}
	
@end

//
//  VMPDrippyButton.m
//  OnTheFly
//
//  Created by sumiisan on 2013/08/07.
//
//

#import "VMPRainyView.h"

@implementation VMPDripParticle
@synthesize maxsize=maxsize_, progress=progress_, position=position_, luminousity=luminousity_;
@end

@implementation VMPRainyView
@synthesize particles=particles_, enabled=enabled_;

#if VMP_OSX
static const int	numberOfParticles = 45;
static const double frameRate		  = 10;
static const double	maxSizeFactor	  = 1;
static const double progressPerHook	  = 0.06 / frameRate;
#elif VMP_IPHONE
static const int	numberOfParticles = 5;
static const double frameRate		  = 6;
static const double	maxSizeFactor	  = 1.5;
static const double progressPerHook	  = 0.06 / frameRate;
#endif

- (id)initWithFrame:(VMPRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
		self.particles = [[[NSMutableArray alloc] init] autorelease];
		double p = 1.0 / (double)numberOfParticles;
		for ( int i = 0; i < numberOfParticles; ++i ) {
			VMPDripParticle *dp = [[[VMPDripParticle alloc] init] autorelease];
			dp.progress = p * i;
			dp.position = CGPointMake( rand() % (int)frame.size.width, rand() % (int)frame.size.height);
#if VMP_IPHONE
			dp.luminousity = 0.75;
			dp.maxsize  = sqrt( frame.size.height * frame.size.width ) * maxSizeFactor;
#else
			dp.luminousity = rand() / (CGFloat)RAND_MAX;
			dp.maxsize  = sqrt( frame.size.height * frame.size.width ) * maxSizeFactor * ( 0.7 + ( rand() / (double)RAND_MAX * 0.3 ) );
#endif
			[self.particles addObject:dp];
		}
		self.backgroundColor = [VMPColor whiteColor];
		self.enabled = YES;
    }
    return self;
}

- (void)setEnabled:(BOOL)enabled {
	enabled_ = enabled;
	self.hidden = ! enabled;
	if ( enabled ) [self performSelector:@selector(animate:) withObject:nil afterDelay:0.1];
}

- (void)dealloc {
	self.particles = nil;
	[super dealloc];
}

- (void)animate:(id)object {
	for ( VMPDripParticle *dp in self.particles ) {
		dp.progress += progressPerHook;
		if ( dp.progress > 1. ) {
			dp.progress = 0;
			dp.position = CGPointMake( rand() % (int)self.frame.size.width, rand() % (int)self.frame.size.height);
#if VMP_OSX
			dp.luminousity = rand() / (CGFloat)RAND_MAX;
			dp.maxsize  = sqrt( self.frame.size.height * self.frame.size.width ) * maxSizeFactor * ( 0.7 + ( rand() / (double)RAND_MAX * 0.3 ) );
#endif
		}
	}
	VMPSetNeedsDisplay(self);
	if ( enabled_ ) [self performSelector:@selector(animate:) withObject:nil afterDelay:(1.0/frameRate)];
}


- (void)drawRect:(VMPRect)rect {
	if ( rect.size.width == 0 || rect.size.height == 0 ) return;
	[super drawRect:rect];
	[self setCanvas];

#if VMP_OSX
	CGContextSetBlendMode(canvas, kCGBlendModeMultiply );// kCGBlendModeMultiply);
#endif
	
	[[VMPColor lightGrayColor] setFill];
	
	for ( VMPDripParticle *dp in self.particles ) {
		double radius = dp.progress * dp.maxsize * 0.5;
		
		
		VMPBezierPath *path = [VMPBezierPath bezierPathWithOvalInRect:VMPMakeRect(dp.position.x - radius,
																				  dp.position.y - radius,
																				  radius *2, radius *2) ];
#if VMP_OSX
		[[VMPColor colorWithCalibratedWhite:dp.luminousity * 0.5 + 0.25 alpha:1-dp.progress] setFill];
		[path fill];
#elif VMP_IPHONE
		[path fillWithBlendMode:kCGBlendModeMultiply alpha:1-dp.progress];
#endif
		//const float gray[] = {0xcc,0xcc,0xcc,255. * ( 1- dp.progress )};
		//CGContextSetFillColor(ctx, gray);
		//CGContextFillEllipseInRect(ctx, CGRectMake(dp.position.x - radius,
		//										   dp.position.y - radius,
		//										   radius *2, radius *2));
		
	}
	
}

@end

//
//  VMPFrontView.m
//  OnTheFly
//
//  Created by sumiisan on 2013/10/06.
//
//

#import "VMAppDelegate.h"
#import "VMPFrontView.h"
#import "VMPSongPlayer.h"
#import "VMScoreEvaluator.h"

#define Eucl_Distance(p1,p2) ({ double	d1 = p1.x - p2.x, d2 = p1.y - p2.y; sqrt(d1 * d1 + d2 * d2); })



@implementation VMPFrontView

static const int numOfCircles = 5;
static const CGFloat dragThreshold = 30;
static CGFloat holeHotSpotRadius = 0;


- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
		self.stem = [CAShapeLayer layer];
		_stem.path = [UIBezierPath bezierPath].CGPath;
		_stem.hidden = YES;
		[self.layer addSublayer:_stem];
		
		self.timeIndicator = [[UILabel alloc] initWithFrame:CGRectZero];
		_timeIndicator.hidden = YES;
		_timeIndicator.tag = 'timL';
		_timeIndicator.backgroundColor = [UIColor clearColor];
		_timeIndicator.textColor = [UIColor grayColor];
		_timeIndicator.textAlignment = NSTextAlignmentCenter;
		[self addSubview:_timeIndicator];
		//
		
		self.circles = [NSMutableArray array];
		CGRect screenRect = [[UIScreen mainScreen] bounds];
		_standardRadius = screenRect.size.width * 0.21;
		holeHotSpotRadius = screenRect.size.width * 0.27;
		_holeCenter = CGPointMake( screenRect.size.width * 0.5, screenRect.size.height * 0.33 );
		for ( int i = 0; i < numOfCircles; ++i ) {
			CAShapeLayer *circle = [CAShapeLayer layer];
			[self.circles addObject:circle];
			circle.path = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(-_standardRadius, -_standardRadius,
																			_standardRadius*2, _standardRadius*2)].CGPath;
			circle.fillColor = [UIColor clearColor].CGColor;
			circle.frame = CGRectMake(_holeCenter.x, _holeCenter.y, 0, 0);

			[self.layer addSublayer:circle];
		}
		[self animate:nil];	//	initialize position and color
		NSNotificationCenter *dc = (NSNotificationCenter*) [NSNotificationCenter defaultCenter];
		
		[dc addObserver:self selector:@selector(playerStarted:) name:PLAYERSTARTED_NOTIFICATION object:nil];
		[dc addObserver:self selector:@selector(endOfSequence:) name:ENDOFSEQUENCE_NOTIFICATION object:nil];
		[dc addObserver:self selector:@selector(playerStopped:) name:PLAYERSTOPPED_NOTIFICATION object:nil];
		
		_lastDayPhase = DEFAULTEVALUATOR.timeManager.dayPhase;
		self.backgroundColor = DEFAULTEVALUATOR.timeManager.backgroundColor;

		_touchBeginPoint = CGPointMake(-9999, 0);
    }
	
    return self;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
	UITouch *touch = [[event allTouches] anyObject];
    _touchBeginPoint = [touch locationInView:self];
	_stemLength = 0;
	_shouldRecognizeTap = YES;
	
	BOOL touchOnHole = Eucl_Distance( _holeCenter, _touchBeginPoint ) <= holeHotSpotRadius;
	BOOL touchOnIndicator = CGRectContainsPoint(_timeIndicator.frame, _touchBeginPoint);
	
	_dragOffsetY = 0;
	if ( touchOnIndicator ) {
		_shouldRecognizeTap = NO;
		_dragOffsetY = _touchBeginPoint.y - _timeIndicator.frame.origin.y;
	}
	
	if(( ! touchOnHole ) && (! touchOnIndicator) )
		_touchBeginPoint.x = -9999;		//	indicates invalid touch
	else
		_timeIndicator.backgroundColor = [UIColor colorWithWhite:0.7 alpha:0.2];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
	_stemLength = 0;
	_stem.strokeColor = [UIColor clearColor].CGColor;
	_timeIndicator.backgroundColor = [UIColor clearColor];
	_touchBeginPoint.x = -9999;
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
	_timeIndicator.backgroundColor = [UIColor clearColor];
	if ( _stemLength == 0 && _touchBeginPoint.x >= 0 && _shouldRecognizeTap )
		[self togglePlayState:nil];
	_touchBeginPoint.x = -9999;
	
}


- (void)plotStem:(float)minutesLeft enabled:(BOOL)enabled {

	if ( ! enabled ) {
		_stemLength = 0;
		_stem.hidden = YES;
		_stem.path = [UIBezierPath bezierPath].CGPath;	//	test
		_timeIndicator.hidden = YES;
		
	} else {
		float min = minutesLeft > 0 ? minutesLeft : 0;	//	avoid zero division
		
		_stemLength = sqrt( min / 0.05 );
		if ( _stemLength > 150 )
			_stemLength = 0;	//	insurance
		CGFloat baseY = ( _holeCenter.y + _standardRadius * 1.2 );
		UIBezierPath *path = [UIBezierPath bezierPath];
		[path moveToPoint:CGPointMake(_holeCenter.x, baseY ) ];
		[path addLineToPoint:CGPointMake(_holeCenter.x, baseY + _stemLength )];
		_stem.path = path.CGPath;
		_timeIndicator.frame = CGRectMake( 0, baseY + _stemLength, 320, 30 );
		float hourP	= ((int)min) / 60.0;
		int minP	= (((int)min) % 60 );
		if ( hourP > 0.2 ) minP = minP / 5  * 5;
		if ( hourP > 3 ) minP = minP / 15 * 15;
		if ( hourP > 5 ) minP = minP / 30 * 30;
		
		if ( minutesLeft > 0 ) {
			_timeIndicator.text = [NSString stringWithFormat:@"%d:%02d", (int)hourP, minP ];
		} else {
			_timeIndicator.text = @"•••";
		}
	}
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
	if ( _touchBeginPoint.x < 0 ) return;	//	invalid touch
	
	UITouch *touch = [[event allTouches] anyObject];
	CGPoint touchPoint = [touch locationInView:self];
	
	//double distance = Eucl_Distance( touchPoint, _touchBeginPoint );
	
	CGFloat baseY = ( _holeCenter.y + _standardRadius * 1.2 );
	CGFloat distance = touchPoint.y - _dragOffsetY - baseY;
	
	if ( distance > 0 ) {
		_shouldRecognizeTap = NO;
		
		if ( distance > 120 )
			distance = 120;	//	that's 12 hours
		
		_stemLength = distance;
		float minutes = distance * distance * 0.05;
		/*	inverse function:
		 
		 distance = sqrt( minutes / 0.05 )
		 
		 */

		[self plotStem:minutes enabled:YES];
		
		_stem.strokeColor = [UIColor lightGrayColor].CGColor;
		_stem.lineWidth = 4;
		_stem.hidden = NO;
		_stem.lineCap = kCALineCapRound;
		
		
		_timeIndicator.hidden = NO;
	
		DEFAULTEVALUATOR.timeManager.remainTimeUntilShutdown = minutes * 60;
	} else {
		[self plotStem:0. enabled:NO];
		DEFAULTEVALUATOR.timeManager.remainTimeUntilShutdown = -1;
	}
	
	
}


- (void)playerStarted:(NSNotification*)notification {
	_targetVelocity = 1;
}

- (void)playerStopped:(NSNotification*)notification {
	_targetVelocity = 0;
}

- (void)endOfSequence:(NSNotification*)notification {
	_targetVelocity = 0;
}

- (void)togglePlayState:(id)sender {
	if ( [DEFAULTSONGPLAYER isRunning] ) {
		_targetVelocity = 0;
		[[VMAppDelegate defaultAppDelegate] pause];
	} else {
		_targetVelocity = 1;
		[[VMAppDelegate defaultAppDelegate] resume];
	}
	
}

- (void)animate:(id)whatever {
	
	UIApplicationState appState = [[UIApplication sharedApplication] applicationState];
	
	if ( _velocity != _targetVelocity ) {
		_velocity += ( _targetVelocity - _velocity ) * 0.02;
		
		_stem.strokeColor =  [UIColor colorWithWhite:.5 alpha: _velocity * .6 + .1].CGColor;
		_timeIndicator.alpha =_velocity * .6 + .3;
	}
	
	
	//
	//	update hole graph
	//
	
	
	if ( appState == UIApplicationStateActive ) {
		CGFloat brightness = _touchBeginPoint.x >= 0 ? 0.7 : 1.0 - ( _velocity * 0.2 );
		CGRect screenRect = [[UIScreen mainScreen] bounds];
		CGFloat radius = screenRect.size.width * 0.22 + (( 1 - _velocity ) * screenRect.size.width * 0.3 );
		CGFloat gap = radius * 0.2 - ( radius * _velocity * 0.1 );
		CGFloat baseRad = ( 2 * M_PI / numOfCircles );
		CGFloat hueInterval = 1.0 / numOfCircles;
		CGFloat offsetRad = _angle * 2 * M_PI;
		
		for ( int i = 0; i < numOfCircles; ++i ) {
			CGFloat rad = baseRad * i + offsetRad;
			CAShapeLayer *circle = self.circles[i];
			CGPoint center = CGPointMake( _holeCenter.x + cos(rad) * gap, _holeCenter.y + sin(rad) * gap );
			
			CGFloat hue = hueInterval * i + _hueOffset;
			if ( hue > 1 ) hue -= 1.;
			circle.fillColor = [UIColor colorWithHue:hue saturation:1. brightness:brightness alpha:0.1 + ( _velocity * 0.2) ].CGColor;
			circle.frame = CGRectMake(center.x, center.y, radius*2, radius*2);
		}
	}
	//
	//	update counters and timers
	//
	
	_angle += 0.011 * _velocity;
	_hueOffset += 0.007 * _velocity;
	++_refreshScreenCounter;
	if ( _angle > 1 )
		_angle -= 1;
	if ( _hueOffset > 1 )
		_hueOffset -= 1;
	if ( _refreshScreenCounter > 30 ) {
		_refreshScreenCounter = 0;
		float minutesLeft = DEFAULTEVALUATOR.timeManager.remainTimeUntilShutdown / 60.0;
		if ( minutesLeft < 0 && (! DEFAULTSONGPLAYER.isRunning ))
			DEFAULTEVALUATOR.timeManager.shutdownTime = nil;		//	stop timer if we are not playing
		if ( appState == UIApplicationStateActive )
			[self plotStem: minutesLeft enabled: DEFAULTEVALUATOR.timeManager.shutdownTime != nil];
		
		if ( appState != _lastAppState ) {
			NSLog(@"appState changed %d -> %d", _lastAppState, appState );
			_lastAppState = appState;
		}
		
		VMDayPhase dp = DEFAULTEVALUATOR.timeManager.dayPhase;
		if ( dp != _lastDayPhase ) {
			[UIView beginAnimations:nil context:nil];
			[UIView setAnimationDuration:5.0];
			self.backgroundColor = DEFAULTEVALUATOR.timeManager.backgroundColor;
			[UIView commitAnimations];
			_lastDayPhase = dp;
		}
	
	}

	[self performSelector:@selector(animate:) withObject:nil afterDelay:( _velocity > 0 ? 0.03 : 1. )];

	
}

- (void)dealloc {
	self.circles = nil;
	self.stem = nil;
	self.timeIndicator = nil;
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[super dealloc];
}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    // Drawing code
}
*/

@end

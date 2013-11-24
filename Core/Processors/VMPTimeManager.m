//
//  VMPTimeManager.m
//  OnTheFly
//
//  Created by sumiisan on 2013/10/09.
//
//
#import "VMPTimeManager.h"

@implementation VMPTimeManager
@synthesize shutdownTime = shutdownTime_;
@synthesize timerExecuted=timerExecuted_;

static VMArray *backgroundColors; // 0   1   2   3   4   5   6   7   8   9   10  11  12  13  14  15  16  17  18  19  20  21  22  23
static VMFloat nightnessOfHour[] = { 1., 1., 1., 1., .7, .5, .3, 0., 0., 0., 0., 0., 0., 0., 0., 0., 0., .1, .3, .5, .7, .8, .9, 1. };

- (id)init {
	self = [super init];
	if (self) {
		backgroundColors = [VMArray arrayWithArray:@[VMPColorBy(182./255., 202./255., 237./255., 1.),
													 VMPColorBy(237./255., 237./255., 237./255., 1.),
													 VMPColorBy(182./255., 202./255., 237./255., 1.),
													// VMPColorBy(237./255., 192./255., 164./255., 1.),
													 VMPColorBy( 30./255.,  30./255.,  30./255., 1.)
													 ]
								   ];
		Retain(backgroundColors);
	}
	return self;
}

- (void)executeTimer {
	if( self.shutdownTime ) {
		NSLog(@"timer was executed at %.2f", [self.shutdownTime timeIntervalSinceNow] );
	}
	self.timerExecuted = YES;
	self.remainTimeUntilShutdown = -1;
}

- (void)resetTimer {
	self.timerExecuted = NO;
}

- (void)setRemainTimeUntilShutdown:(VMTime)seconds {
	if ( seconds < 0 ) {
		self.shutdownTime = nil;
		return;
	}
	
	self.timerExecuted = NO;
	VMTime now = [[NSDate date] timeIntervalSince1970];
	VMTime shutDownTime = now + seconds;
	self.shutdownTime = [NSDate dateWithTimeIntervalSince1970:shutDownTime];
}

- (VMTime)remainTimeUntilShutdown {
	if (! self.shutdownTime) return INFINITY;
	return [self.shutdownTime timeIntervalSinceNow];
}

- (VMInt)hourOfDay {
	NSDate *now = [NSDate date];
	NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *components = [calendar components:NSHourCalendarUnit fromDate:now];
	return components.hour;
}

- (VMDayPhase)dayPhase {
	VMInt hour = self.hourOfDay;

	if ( hour < 5  ) return vmdp_night;
	if ( hour < 7  ) return vmdp_dawn;
	if ( hour < 17 ) return vmdp_day;
	if ( hour < 19 ) return vmdp_dusk;

	return vmdp_night;
}

- (VMFloat)dayNess {
	return 1. - self.nightNess;
}

- (VMFloat)nightNess {
	//
	//	nightness increases if sleep time is near
	//
	VMTime remain = self.remainTimeUntilShutdown;
	if ( remain < 0 ) remain = 0;
	VMFloat closeToEnd = 0.;
	if ( remain < 600 ) closeToEnd = ( 600 - remain ) * 0.002;	//	0 .. 1.2
	VMFloat nightness = nightnessOfHour[ self.hourOfDay ] + closeToEnd;
	
	return nightness > 1. ? 1. : nightness;
}

- (VMPColor*)backgroundColor {
	return [backgroundColors item:[self dayPhase]];
}

@end

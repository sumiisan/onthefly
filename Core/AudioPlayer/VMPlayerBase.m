//
//  PlayerBase.m
//  VariableMusicPlayer
//
//  Created by cboy on 12/10/22.
//  Copyright 2012 sumiisan (aframasda.com). All rights reserved.
//

#import "VMPlayerBase.h"
#import "MultiPlatform.h"
#import "VMPSongPlayer.h"

@implementation VMPlayerBase
/*
- (void)watchCurrentTimeForDebug {
	VMTime ct = [[NSDate date] timeIntervalSince1970]-timerOffset;
	if ( timePaused ) ct = timePaused;
	
	if ( [self class] == [VMPSongPlayer class] && ( ct < 0 || ct > 99999 ))
		NSLog(@"debug1");
}*/

- (id)init {
    self = [super init];
    if (self) {
        [self initTime];
    }
    return self;
}

- (void)dealloc {
    [super dealloc];
}

- (void)initTime {
	self.currentTime = RESET_TIME;
//	[self watchCurrentTimeForDebug];
	timePaused = 0;
}

- (void)pause {
	timePaused = self.currentTime;
//	[self watchCurrentTimeForDebug];
}

- (void)resume {
	self.currentTime = timePaused;
	timePaused = 0;
	[self restartTimer];
//	[self watchCurrentTimeForDebug];
}

-(NSTimeInterval)currentTime {
	if ( timePaused ) return timePaused;
//	[self watchCurrentTimeForDebug];
   return [[NSDate date] timeIntervalSince1970]-timerOffset;
}

-(void)setCurrentTime:(NSTimeInterval)t {
    timerOffset = [[NSDate date] timeIntervalSince1970]-t;
//	[self watchCurrentTimeForDebug];
}

- (void)restartTimer {
	[timer invalidate];
	timer = [NSTimer timerWithTimeInterval:kTimerInterval
									target:self
								  selector:@selector(timerReceiver:)
								  userInfo:nil
								   repeats:YES ];
	[[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
}

- (void)startTimer:(SEL)callback {
	timerCallback = callback;
	timer = [NSTimer timerWithTimeInterval:kTimerInterval
									target:self
								  selector:@selector(timerReceiver:)
								  userInfo:nil
								   repeats:YES ];
	[[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
}

- (void)timerReceiver:(NSTimer*)timer {
	if ( (!self.isPaused) && timerCallback ) 
		[self performSelector:timerCallback];
}

- (void)stopTimer {
	if( timer ) {
		[timer invalidate];
		timer = nil;
	}
}

- (BOOL)isPaused {
	return ( timePaused != 0 );
}

@end

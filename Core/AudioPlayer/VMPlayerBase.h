//
//  PlayerBase.h
//  VariableMusicPlayer
//
//  Created by cboy on 12/10/22.
//  Copyright 2012 sumiisan (aframasda.com). All rights reserved.
//

#import <Foundation/Foundation.h>

#define RESET_TIME (-[[NSDate date] timeIntervalSince1970])
#define INFINITE_TIME INFINITY

@interface VMPlayerBase : NSObject {
@protected
	NSTimer			*timer;
	NSTimeInterval	timePaused;
	SEL				timerCallback;
@private
    NSTimeInterval  timerOffset;
}

@property (nonatomic) NSTimeInterval currentTime;

- (NSTimeInterval)currentTime;
- (void)setCurrentTime: ( NSTimeInterval )t;
- (void)initTime;
- (void)pause;
- (void)resume;
- (void)startTimer:(SEL)callback;
- (void)restartTimer;
- (void)stopTimer;

- (BOOL)isPaused;
@end

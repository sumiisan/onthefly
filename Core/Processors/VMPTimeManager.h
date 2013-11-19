//
//  VMPTimeManager.h
//  OnTheFly
//
//  Created by sumiisan on 2013/10/09.
//
//

#import <Foundation/Foundation.h>
#import "MultiPlatform.h"
#import "VMDataTypes.h"

typedef enum {
	vmdp_dawn,
	vmdp_day,
	vmdp_dusk,
	vmdp_night,
	vmdp_unknown
} VMDayPhase;

@interface VMPTimeManager : NSObject

@property (nonatomic, retain)	NSDate			*shutdownTime;
@property (nonatomic)			VMTime			remainTimeUntilShutdown;
@property (nonatomic,readonly)	VMFloat			dayNess;
@property (nonatomic,readonly)	VMFloat			nightNess;
@property (nonatomic,readonly)	VMPColor		*backgroundColor;
@property (nonatomic)			BOOL			timerExecuted;

- (VMDayPhase)dayPhase;
- (void)executeTimer;
- (void)resetTimer;

@end

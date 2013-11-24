//
//  VMPTimeManager.h
//  OnTheFly
//
//  Created by sumiisan on 2013/10/09.
//
//

#import <Foundation/Foundation.h>
#import "MultiPlatform.h"
#import "VMARC.h"
#import "VMDataTypes.h"

typedef enum {
	vmdp_dawn,
	vmdp_day,
	vmdp_dusk,
	vmdp_night,
	vmdp_unknown
} VMDayPhase;

@interface VMPTimeManager : NSObject {
#ifdef SUPPORT_32BIT_MAC
	NSDate	*shutdownTime_;
	BOOL	timerExecuted_;
#endif
}

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

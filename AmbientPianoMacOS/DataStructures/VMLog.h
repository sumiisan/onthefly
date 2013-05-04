//
//  VMLog.h
//  GotchaP
//
//  Created by sumiisan on 2013/04/22.
//
//

#import <Foundation/Foundation.h>
#import "VMDataTypes.h"

/*---------------------------------------------------------------------------------
 *
 *
 *	Log Item
 *
 *
 *---------------------------------------------------------------------------------*/

@interface VMHistoryLog : NSObject
@property (nonatomic)									VMInt			index;
@property (nonatomic, retain)							id				data;
@property (nonatomic, readonly)							vmObjectType	type;
@property (nonatomic, retain)							VMString		*action;
@property (nonatomic, retain)							VMHash			*subInfo;
@property (nonatomic)									VMTime			timestamp;
@property (nonatomic)									VMTime			playbackTimestamp;

//	VMPLogView vars & flags
@property (nonatomic)									VMFloat			expandedHeight;
@property (nonatomic, getter=isExpanded)				BOOL			expanded;
@property (nonatomic, getter=isAutomaticallyExpanded)	BOOL			automaticallyExpanded;

+ (VMHistoryLog*)historyWithAction:(VMString*)action data:(id)data subInfo:(VMHash*)subInfo;

@end


/*---------------------------------------------------------------------------------
 *
 *
 *	Logger
 *
 *
 *---------------------------------------------------------------------------------*/

@interface VMLog : VMArray {
@protected
	VMInt index_intern;
}

@property (nonatomic)			VMInt		maximumNumberOfLog;
- (VMInt)issueIndex;
- (VMInt)nextIndex;
- (void)log:(id)item;
- (void)logWarning:(NSString *)messageFormat withData:(NSString *)data;
- (void)logError:(NSString *)messageFormat withData:(NSString *)data;
- (void)record:(VMArray*)arrayOfData;

@end

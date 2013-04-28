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
@property (nonatomic)			VMInt			index;
@property (nonatomic, retain)	id				data;
@property (nonatomic, readonly)	vmObjectType	type;
//@property (nonatomic, readonly)	VMCue			*cue;
@property (nonatomic, retain)	VMString		*action;
@property (nonatomic, retain)	VMHash			*subInfo;
@property (nonatomic)			VMTime			timestamp;
@property (nonatomic)			VMTime			playbackTimestamp;
@property (nonatomic, getter=isExpanded) BOOL	expanded;
@property (nonatomic)			VMFloat			expandedHeight;			//	used by VMPLogView 0 = not expanded

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
- (void)record:(VMArray*)arrayOfData;

@end

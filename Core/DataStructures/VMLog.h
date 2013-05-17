//
//  VMLog.h
//  OnTheFly
//
//  Created by sumiisan on 2013/04/22.
//
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "VMDataTypes.h"

typedef enum {
	VMLogOwner_Player,
	VMLogOwner_Statistics,
	VMLogOwner_System,
	VMLogOwner_User
} VMLogOwnerType;


/*---------------------------------------------------------------------------------
 *
 *
 *	History
 *
 *
 *---------------------------------------------------------------------------------*/

@interface VMHistory : VMArray
@property (nonatomic, assign)	VMInt	position;

- (BOOL)canMove:(VMInt)steps;
- (void)move:(VMInt)steps;
- (id)currentItem;

@end

/*---------------------------------------------------------------------------------
 *
 *
 *	Log Item
 *
 *
 *---------------------------------------------------------------------------------*/

@interface VMLogItem : NSManagedObject

@property (nonatomic, VMStrong) NSNumber * index_obj;
@property (nonatomic, VMStrong) NSNumber * owner_obj;
@property (nonatomic, VMStrong) NSNumber * type_obj;
@property (nonatomic, VMStrong) id data;
@property (nonatomic, VMStrong) NSString * action;
@property (nonatomic, VMStrong) NSNumber * timestamp_obj;
@property (nonatomic, VMStrong) NSNumber * playbackTimestamp_obj;
@property (nonatomic, VMStrong) id subInfo_obj;
@property (nonatomic, VMStrong) NSNumber * expanded_obj;

@end

/*---------------------------------------------------------------------------------
 *
 *
 *	Log Record
 *
 *
 *---------------------------------------------------------------------------------*/

@interface VMLogRecord : VMLogItem {
	CGFloat expandedHeightCache_static_;
}

@property (nonatomic)									VMInt			index;
@property (nonatomic, readonly)							vmObjectType	type;
@property (nonatomic)									VMTime			timestamp;
@property (nonatomic)									VMTime			playbackTimestamp;
@property (nonatomic, VMStrong)							VMHash			*subInfo;

//	VMPLogView vars & flags
@property (nonatomic, getter=isExpanded)				BOOL			expanded;
@property (nonatomic)									CGFloat			expandedHeight;
@property (nonatomic, getter=isAutomaticallyExpanded)	BOOL			automaticallyExpanded;
@property (nonatomic, VMReadonly)							VMData			*VMData;

+ (VMLogRecord*)historyWithAction:(VMString*)action
							  data:(id)data
						   subInfo:(VMHash*)subInfo
							 owner:(VMLogOwnerType)owner
				usePersistentStore:(BOOL)usePersistentStore;

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
	VMInt				index_intern;
	__unsafe_unretained	NSManagedObjectContext		*moc_;
}

@property (nonatomic)			VMInt			maximumNumberOfLog;
@property (nonatomic)			VMLogOwnerType	owner;
@property (nonatomic, readonly)	BOOL			usePersistentStore;

//	designated initializer
- (id)initWithOwner:(int)owner managedObjectContext:(NSManagedObjectContext*)moc;

- (void)load;
- (void)loadWithPredicateString:(VMString*)predicateString;
- (void)save;

- (VMInt)issueIndex;
- (VMInt)nextIndex;
- (void)log:(id)item;
- (void)addTextLog:(VMString*)action message:(VMString*)message;
- (void)addUserLogWithText:(VMString*)message dataId:(VMId*)dataId;

- (void)logWarning:(NSString *)messageFormat withData:(NSString *)data;
- (void)logError:(NSString *)messageFormat withData:(NSString *)data;
- (void)record:(VMArray*)arrayOfData filter:(BOOL)doFilter;

@end

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
 *	Log Item
 *
 *
 *---------------------------------------------------------------------------------*/

@interface VMLogItem : NSManagedObject

@property (nonatomic, retain) NSNumber * index_obj;
@property (nonatomic, retain) NSNumber * owner_obj;
@property (nonatomic, retain) NSNumber * type_obj;
@property (nonatomic, retain) id data;
@property (nonatomic, retain) NSString * action;
@property (nonatomic, retain) NSNumber * timestamp_obj;
@property (nonatomic, retain) NSNumber * playbackTimestamp_obj;
@property (nonatomic, retain) id subInfo_obj;
@property (nonatomic, retain) NSNumber * expanded_obj;

@end

/*---------------------------------------------------------------------------------
 *
 *
 *	History Log
 *
 *
 *---------------------------------------------------------------------------------*/

@interface VMHistoryLog : VMLogItem {
	CGFloat expandedHeightCache_static_;
}

@property (nonatomic)									VMInt			index;
@property (nonatomic, readonly)							vmObjectType	type;
@property (nonatomic)									VMTime			timestamp;
@property (nonatomic)									VMTime			playbackTimestamp;
@property (nonatomic, retain)							VMHash			*subInfo;

//	VMPLogView vars & flags
@property (nonatomic, getter=isExpanded)				BOOL			expanded;
@property (nonatomic)									CGFloat			expandedHeight;
@property (nonatomic, getter=isAutomaticallyExpanded)	BOOL			automaticallyExpanded;
@property (nonatomic, readonly)							VMData			*VMData;

+ (VMHistoryLog*)historyWithAction:(VMString*)action
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
	VMInt	index_intern;
	__weak	NSManagedObjectContext		*moc_;

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

//
//  VMLog.m
//  OnTheFly
//
//  Created by sumiisan on 2013/04/22.
//
//

#import "VMLog.h"
#import "VMPMacros.h"
#import "VMException.h"
#import "VMPreprocessor.h"
#if VMP_DESKTOP
#import "VMPlayerOSXDelegate.h"
#endif
/*---------------------------------------------------------------------------------
 *
 *
 *	History Log
 *
 *
 *---------------------------------------------------------------------------------*/

@implementation VMLogItem

@dynamic index_obj;
@dynamic owner_obj;
@dynamic data;
@dynamic action;
@dynamic type_obj;
@dynamic timestamp_obj;
@dynamic playbackTimestamp_obj;
@dynamic subInfo_obj;
@dynamic expanded_obj;

@end


/*---------------------------------------------------------------------------------
 
 VMHistoryLog
 
 ----------------------------------------------------------------------------------*/

#pragma mark -
#pragma mark VMHistoryLog

@implementation VMHistoryLog
@synthesize automaticallyExpanded;

//
#pragma mark -
#pragma mark	** one and only designated initializer: **
//
+ (VMHistoryLog*)historyWithAction:(VMString*)action
							  data:(id)data
						   subInfo:(VMHash*)subInfo
							 owner:(VMLogOwnerType)owner
				usePersistentStore:(BOOL)usePersistentStore {
	VMHistoryLog *log;
	if ( usePersistentStore ) {
		log = [[[VMHistoryLog alloc] initWithEntity:[APPDELEGATE entityDescriptionFor:@"VMLogItem"] insertIntoManagedObjectContext:APPDELEGATE.managedObjectContext] autorelease];
	} else {
		log = [[[VMHistoryLog alloc] initWithEntity:[APPDELEGATE entityDescriptionFor:@"VMLogItem"] insertIntoManagedObjectContext:nil] autorelease];
	}
	
	log.action		= action;
	log.subInfo_obj	= subInfo;
	log.owner_obj	= @(owner);
	
	if ( ClassMatch( data, VMData ) ) {
		log.type = ((VMData*) data).type;
		log.data = ((VMData*) data).id;
	} else {
		log.type = 0;
		log.data = data;
	}
	log->expandedHeightCache__ = -1;	
	return log;
}
#pragma mark -


- (VMInt)index {
	return [self.index_obj doubleValue];
}

- (void)setIndex:(VMInt)index {
	self.index_obj = @(index);
}

- (vmObjectType)type {
	return [self.type_obj intValue];
}

- (void)setType:(vmObjectType)type {
	self.type_obj = @(type);
}

- (void)setSubInfo:(VMHash *)subInfo {
	self.subInfo_obj = subInfo;
}

- (VMHash*)subInfo {
	return self.subInfo_obj;
}

- (VMTime)timestamp {
	return [self.timestamp_obj doubleValue];
}

- (void)setTimestamp:(VMTime)timestamp {
	self.timestamp_obj = VMFloatObj(timestamp);
}

- (VMTime)playbackTimestamp {
	return [self.playbackTimestamp_obj doubleValue];
}

- (void)setPlaybackTimestamp:(VMTime)playbackTimestamp {
	self.playbackTimestamp_obj = VMFloatObj(playbackTimestamp);
}

- (BOOL)isExpanded {
	return [self.expanded_obj boolValue];
}

- (void)setExpanded:(BOOL)expanded {
	self.expanded_obj = VMBoolObj(expanded);
}

- (VMData*)VMData {
	if ( ClassMatch(self.data, VMId ) ) return [DEFAULTSONG data:self.data];
	return self.data;
}

- (CGFloat)expandedHeight {
	if ( expandedHeightCache__ < 0 ) {
		expandedHeightCache__ = 0;
		
		if( [self.action isEqualToString:@"SEL"] ) expandedHeightCache__ += 30.;
				
		VMString *message = [[self.subInfo item:@"message"] stringByAppendingString:@" "];
		if ( message ) {
			expandedHeightCache__ += [self heightForStringDrawing:message font:[NSFont systemFontOfSize:10] width:250] +3;
		}

	}
	return expandedHeightCache__;
}

- (void)setExpandedHeight:(CGFloat)expandedHeight {
	expandedHeightCache__ = expandedHeight;
}

/*
 code taken from
 https://developer.apple.com/library/mac/#documentation/Cocoa/Conceptual/TextLayout/Tasks/StringHeight.html#//apple_ref/doc/uid/20001809-CJBGBIBB
 */
- (CGFloat)heightForStringDrawing:(NSString*)myString font:(NSFont*)myFont width:(float)myWidth {
	NSTextStorage *textStorage = [[[NSTextStorage alloc] initWithString:myString] autorelease];
	NSTextContainer *textContainer = [[[NSTextContainer alloc] initWithContainerSize: NSMakeSize(myWidth, FLT_MAX)] autorelease];
	NSLayoutManager *layoutManager = [[[NSLayoutManager alloc] init] autorelease];
	[layoutManager addTextContainer:textContainer];
	[textStorage addLayoutManager:layoutManager];
	[textStorage addAttribute:NSFontAttributeName value:myFont range:NSMakeRange(0, [textStorage length])];
	[textContainer setLineFragmentPadding:0.0];
	[layoutManager glyphRangeForTextContainer:textContainer];
	return [layoutManager usedRectForTextContainer:textContainer].size.height;
}


- (VMFragment*)frag {
	return (VMFragment*)self.data;
}

- (id)init {
	assert(0);		//	use init with entity
	return nil;
}

- (id)initWithEntity:(NSEntityDescription *)entity insertIntoManagedObjectContext:(NSManagedObjectContext *)context {
	self = [super initWithEntity:entity insertIntoManagedObjectContext:context];
	expandedHeightCache__ = -1;
	return self;
}



- (void)dealloc {
	self.action = nil;
	self.data = nil;
	self.subInfo = nil;
	[super dealloc];
}

@end


/*---------------------------------------------------------------------------------
 
 VMLog
 
 ----------------------------------------------------------------------------------*/

#pragma mark -
#pragma mark VMLog

@implementation VMLog
	 
- (id)init {
	assert(0);	//	use initWithOwner initializer
	return nil;
}

#pragma mark ** designated initializer **
- (id)initWithOwner:(int)owner managedObjectContext:(NSManagedObjectContext*)moc {
	self = [super init];
	if (self) {
		moc_ = moc;
		self.maximumNumberOfLog = 100000;	//	the default value;
		self.owner = owner;
		if ( moc_ )
			[self loadWithPredicateString:nil];
	}
	return self;
}


#pragma mark -
#pragma mark accessor
- (VMInt)indexOfItem:(VMInt)index {
	id d = [self item:index];
	VMHistoryLog *hs = ClassCastIfMatch(d, VMHistoryLog);
	if ( hs ) return hs.index;
	VMHash *ha = ClassCastIfMatch(d, VMHash);
	if ( ha ) return [ha itemAsInt:@"vmlog_index"];
	return -1;
}


- (BOOL)usePersistentStore {
	return moc_ != nil;
}


- (VMInt)issueIndex {
	return index_intern++;
}

- (VMInt)nextIndex {
	return index_intern;
}


#pragma mark -
#pragma mark save and load
/*---------------------------------------------------------------------------------
 
 save and load
 
 ----------------------------------------------------------------------------------*/

- (void)update:(VMHistoryLog*)logItem {
}


- (void)load {
	[self loadWithPredicateString:nil];
}

- (void)loadWithPredicateString:(VMString*)predicateString {
	NSManagedObjectContext *moc = [APPDELEGATE managedObjectContext];
	if(!moc) return;	//	probably no data
	NSFetchRequest *req = [[NSFetchRequest alloc] init];
	req.entity = [APPDELEGATE entityDescriptionFor:@"VMLogItem"];
	if ( predicateString )
		predicateString = [NSString stringWithFormat:@"owner_obj = %d and %@", self.owner, predicateString];
	else
		predicateString = [NSString stringWithFormat:@"owner_obj = %d", self.owner];
	
	req.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"index_obj" ascending:YES]];
	
	req.predicate = [NSPredicate predicateWithFormat:predicateString];
	NSArray *array = [moc executeFetchRequest:req error:nil];
	
	//	[self setArray:array fromIndex:0];		//	if use HashedArray
	self->array_ = [array mutableCopy];
	index_intern = ((VMHistoryLog*)self.lastItem).index +1;
	
	NSLog(@"Load:%@ %@\nData[0]:%@",req.predicate.predicateFormat, req.sortDescriptors.description ,[self item:0]);
	[req release];
}

- (void)clear {	//	override
	if ( self.owner == VMLogOwner_User )
		if( [VMException ensure:@"Clear user log ?"] == 1 )
			return;

	if( self.usePersistentStore ) {
		[self loadWithPredicateString:nil];	//	select all
		for ( VMHistoryLog *hl in self ) {
			[moc_ deleteObject:hl];
		}
		[self save];
	}
	[super clear];
	
}

- (void)save {
	if ( self.usePersistentStore ) {
		NSError *err = nil;
		NSLog ( @"updated Objects: %@", [moc_ updatedObjects].description );
		NSLog ( @"inserted Objects: %@", [moc_ insertedObjects].description );
		NSLog ( @"deleted Objects: %@", [moc_ deletedObjects].description );
		[moc_ save:&err];
		if (err) {
			[VMException raise:@"Failed to store log" format:@"error: %@", err.localizedDescription ];
		}
	}
}


#pragma mark -
#pragma mark log

/*---------------------------------------------------------------------------------
 
 log a single item
 
 ----------------------------------------------------------------------------------*/

- (void)log:(id)item {
	VMHash *hash = ClassCastIfMatch(item, VMHash);
	if ( hash ) {
		[hash setItem:@([self issueIndex]) for:@"vmlog_index"];
		[hash setItem:@([[NSDate date] timestamp]) for:@"vmlog_timestamp"];
		return;
	}
	
	VMHistoryLog *historyLog = ClassCastIfMatch(item, VMHistoryLog);
	if ( !historyLog ) {
		//	wrap item with history log
		historyLog = [VMHistoryLog historyWithAction:@"Unknown"
												data:item
											 subInfo:nil
											   owner:self.owner
								  usePersistentStore:self.usePersistentStore];
	}
	
	historyLog.index     = [self issueIndex];
	historyLog.timestamp = [[NSDate date] timeIntervalSinceReferenceDate];
	
	[self push:historyLog];
	if( moc_ )
		[moc_ insertObject:historyLog];
	
	if (self.count > ( self.maximumNumberOfLog * 1.5 )) {
		[self truncateFirst:self.maximumNumberOfLog];
	}
	
	return;
}

/*---------------------------------------------------------------------------------
 
 batch log
 
 ----------------------------------------------------------------------------------*/

- (void)record:(VMArray*)arrayOfData filter:(BOOL)doFilter {
	for( id data in arrayOfData ) {
		if ( ClassMatch( data, VMHistoryLog )) {
			[self log:data];
			continue;
		}
		
		
		VMHistoryLog *lastHl = self.lastItem;
		VMHash *subInfo =  nil;
		
		if ( ClassMatch( data, VMId )) {		//	try to convert string into object
			VMData *d = [DEFAULTSONG.songData item:data];
			if (d) data = d;
		}
		
		VMData		*d = ClassCastIfMatch( data, VMData );
		VMString	*action;
		if ( d ) {
			if (d.type == vmObjectType_chance && doFilter)
				continue;
			//	no need to log chances since they are stored by the owning selector.
			
			action = [VMPreprocessor shortTypeStringForType:d.type];
			
			if ( lastHl.type == vmObjectType_selector && lastHl.subInfo && doFilter ) {
				[lastHl.subInfo setItem:d.id for:@"vmlog_selected"];
			}
		} else if ( ClassMatch( data, VMHash )) {
			VMHash *h = (VMHash*)data;
			action = [h item:@"vmlog_type"];
			[h removeItem:@"vmlog_type"];
			
			if ( [action isEqualToString:@"scores"] ) {
				VMHistoryLog *hl = self.lastItem;
				if ( hl.type == vmObjectType_selector ) {
					hl.subInfo = data;
					continue;
				}
			}
			
		} else {
			action = @"Log";
			if ( ClassMatch(data, VMString )) {
				[self addTextLog:action message:data];
				continue;
			}
		}
		VMHistoryLog *log = [VMHistoryLog historyWithAction:action
													   data:data
													subInfo:subInfo
													  owner:self.owner
										 usePersistentStore:self.usePersistentStore];
		[self log:log];
	}
}

#pragma mark -
#pragma mark add text log
/*---------------------------------------------------------------------------------
 
 add text log
 
 ----------------------------------------------------------------------------------*/

- (void)addTextLog:(VMString*)action message:(VMString*)message {
	VMHistoryLog *hl = [VMHistoryLog historyWithAction:action
												  data:message
											   subInfo:[VMHash hashWithObjectsAndKeys:message,@"message",nil]
												 owner:self.owner
									usePersistentStore:self.usePersistentStore
						];
	hl.expanded =YES;
	[self log:hl];
}

- (void)addUserLogWithText:(VMString*)message dataId:(VMId*)dataId {
	VMData *d = [DEFAULTSONG data:dataId];
	if (d) {
		VMHistoryLog *hl = [VMHistoryLog historyWithAction:@"UserLog"
													  data:d
												   subInfo:[VMHash hashWith:@{@"message":message,
															@"id":dataId}]
													 owner:VMLogOwner_User
										usePersistentStore:YES];
		hl.expanded = YES;
		[self log:hl];
		[self save];
	} else {
		[VMException alert:@"No fragment selected."];
	}
}


- (void)logWarning:(NSString *)messageFormat withData:(NSString *)data {
	if (data)
		[self addTextLog:@"Warning" message:[NSString stringWithFormat:messageFormat, data]];
	else
		[self addTextLog:@"Warning" message:messageFormat];
}

- (void)logError:(NSString*)messageFormat withData:(NSString*)data {
	if (data)
		[self addTextLog:@"Error" message:[NSString stringWithFormat:messageFormat, data]];
	else
		[self addTextLog:@"Error" message:messageFormat];
}

/*
//	NSCopying
- (id)copyWithZone:(NSZone *)zone {
	VMLog *copy = [[VMLog allocWithZone:zone] initWithOwner:self.owner load:NO clear:NO];
	copy->array_ = [self.array copy];
	copy->index_intern = index_intern;
	copy.maximumNumberOfLog = self.maximumNumberOfLog;
	return copy;
}
*/

@end


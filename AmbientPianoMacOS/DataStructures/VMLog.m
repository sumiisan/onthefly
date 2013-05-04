//
//  VMLog.m
//  GotchaP
//
//  Created by sumiisan on 2013/04/22.
//
//

#import "VMLog.h"
#import "VMPMacros.h"
#import "VMException.h"
#import "VMPreprocessor.h"

/*---------------------------------------------------------------------------------
 
 VMHistoryLog
 
 ----------------------------------------------------------------------------------*/

#pragma mark -
#pragma mark VMHistoryLog

@implementation VMHistoryLog

+ (VMHistoryLog*)historyWithAction:(VMString*)action data:(id)data subInfo:(VMHash*)subInfo {
	VMHistoryLog *log = [[[VMHistoryLog alloc] init] autorelease];
	
	log.action = action;
	log.data = data;
	log.subInfo = subInfo;
	//	index and timestamp will be set by the logger.
	
	return log;
}

- (vmObjectType)type {
	if ( ClassMatch( self.data, VMData ) ) return ((VMData*)self.data).type;
	return vmObjectType_notVMObject;
}

- (VMCue*)cue {
	return (VMCue*)self.data;
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
	self = [super init];
	if (self) {
		self.maximumNumberOfLog = 100000;	//	the default value;
	}
	return self;
}

- (VMInt)issueIndex {
	return index_intern++;
}

- (VMInt)nextIndex {
	return index_intern;
}

- (void)record:(VMArray*)arrayOfData {
	for( id data in arrayOfData ) {
		VMHistoryLog *lastHl = self.lastItem;
		
		VMData		*d = ClassCastIfMatch( data, VMData );
		VMString	*type;
		if ( d ) {
			if (d.type == vmObjectType_chance) continue;	//	no need to log chances since they are stored by the owning selector.
		
			type = [VMPreprocessor shortTypeStringForType:d.type];
			
			if ( lastHl.type == vmObjectType_selector && lastHl.subInfo ) {
				[lastHl.subInfo setItem:d.id for:@"vmlog_selected"];
			}
			/*
			if ( d.type == vmObjectType_audioCue && lastHl.type == vmObjectType_sequence ) {
				VMSequence *sq = lastHl.data;
				if ( [sq.cues position:d.id] >= 0 ) {
					if ( ! lastHl.subInfo ) lastHl.subInfo = ARInstance( VMHash );
					VMArray *audioCues = [lastHl.subInfo item:@"audioCues"];
					if ( ! audioCues ) {
						audioCues = ARInstance(VMArray);
						[lastHl.subInfo setItem:audioCues for:@"audioCues"];
					}
					[audioCues push:d];
					lastHl.expandedHeight = audioCues.count * 15;
					continue;
				}
			}
			*/
		} else {
			VMHash *h = (VMHash*)data;
			type = [h item:@"vmlog_type"];
			[h removeItem:@"vmlog_type"];
			
			if ( [type isEqualToString:@"scores"] ) {
				VMHistoryLog *hl = self.lastItem;
				if ( hl.type == vmObjectType_selector ) {
					hl.subInfo = data;
					hl.expandedHeight = 30;
					continue;
				}
			}
			
		}
		VMHistoryLog *log = [VMHistoryLog historyWithAction:type
													   data:data
													subInfo:nil];
		[self log:log];
	}
}


- (void)log:(id)item {
	VMHash *hash = ClassCastIfMatch(item, VMHash);
	if ( hash ) {
		[hash setItem:VMIntObj([self issueIndex]) for:@"vmlog_index"];
		[hash setItem:VMIntObj([[NSDate date] timestamp]) for:@"vmlog_timestamp"];
		return;
	}
	
	VMHistoryLog *historyLog = ClassCastIfMatch(item, VMHistoryLog);
	if ( !historyLog ) {
		//	wrap item with history log
		historyLog = [VMHistoryLog historyWithAction:nil data:item subInfo:nil];
	}
	
	historyLog.index     = [self issueIndex];
	historyLog.timestamp = [[NSDate date] timeIntervalSinceReferenceDate];
	[self push:item];
	
	if (self.count > ( self.maximumNumberOfLog * 1.5 )) {
		[self truncateFirst:self.maximumNumberOfLog];
	}
	
	return;
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


- (void)addTextLog:(VMString*)action message:(VMString*)message {
	VMHistoryLog *hl = [VMHistoryLog historyWithAction:action
												  data:message
											   subInfo:[VMHash hashWithObjectsAndKeys:message,@"message",nil]
						];
	hl.expandedHeight = [self heightForStringDrawing:message font:[NSFont systemFontOfSize:10] width:250] +1;
	[self log:hl];
}


- (void)logWarning:(NSString *)messageFormat withData:(NSString *)data {
	[self addTextLog:@"warning" message:[NSString stringWithFormat: @"Warning: %@:%@", messageFormat, data]];
}

- (void)logError:(NSString*)messageFormat withData:(NSString*)data {
	[self addTextLog:@"error" message:[NSString stringWithFormat: @"Error: %@:%@", messageFormat, data]];
}

- (VMInt)indexOfItem:(VMInt)index {
	id d = [self item:index];
	VMHistoryLog *hs = ClassCastIfMatch(d, VMHistoryLog);
	if ( hs ) return hs.index;
	VMHash *ha = ClassCastIfMatch(d, VMHash);
	if ( ha ) return [ha itemAsInt:@"vmlog_index"];
	return -1;
}

- (VMLog*)subLogWithRange:(VMRange)range {
	VMFloat length = ( range.maximum - range.minimum );
	if ( length < 1 ) return nil;
	VMLog *log = [[self copy] autorelease];
	[log crop:range];
	log->index_intern = [log indexOfItem:log.count-1] +1;
	return log;
}


//	NSCopying
- (id)copyWithZone:(NSZone *)zone {
	VMLog *copy = [[VMLog allocWithZone:zone] init];
	copy->array_ = [self.array copy];
	copy->index_intern = index_intern;
	copy.maximumNumberOfLog = self.maximumNumberOfLog;
	return copy;
}


@end

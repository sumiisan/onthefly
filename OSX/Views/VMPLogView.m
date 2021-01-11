//
//  VMPLogView.m
//  OnTheFly
//
//  Created by sumiisan on 2013/04/21.
//
//

#import "VMPLogView.h"
#import "VMSong.h"
#import "VMPFragmentCell.h"
#import "VMPMacros.h"
#import "VMPAnalyzer.h"
#import "VMPSongPlayer.h"
#import "VMPreprocessor.h"
#import "VMOnTheFlyEditorAppDelegate.h"
#import "VMPNotification.h"

static const VMFloat kDefaultLogItemViewHeight = 14.0;

/*---------------------------------------------------------------------------------
 
 Log Item View
 
 ----------------------------------------------------------------------------------*/

#pragma mark -
#pragma mark Log Item View (NSTableCellView subclass)
#pragma mark -

@implementation VMPLogItemView

- (id)initWithCoder:(NSCoder *)aDecoder {
	self = [super initWithCoder:aDecoder];
	if (self) {
		self.backgroundColor = [NSColor colorWithCalibratedRed:.9 green:.9 blue:.9 alpha:1.];
	}
	return self;
}

- (void)dealloc {
	VMNullify(backgroundColor);
	Dealloc( super );;
}

- (void)drawRect:(NSRect)dirtyRect {
	if ( ! self.fired ) {
		[[self.backgroundColor colorModifiedByHueOffset:0. saturationFactor:0.6 brightnessFactor:1.3] setFill];
	} else {
		[self.backgroundColor setFill];
	}
	NSRectFillUsingOperation(dirtyRect, NSCompositeSourceOver);
}

@end

/*---------------------------------------------------------------------------------
 *
 *
 *	log view panel
 *
 *
 *---------------------------------------------------------------------------------*/

#pragma mark -
#pragma mark Log View Panel
#pragma mark -

@interface VMPLogView()
@property	(nonatomic, assign)	BOOL updateScheduled;
@end

@implementation VMPLogView

- (void)initInternal {
	if (kUseNotification) {
		[VMPNotificationCenter addObserver:self
								  selector:@selector(songPlayerListener:)
									  name:nil
									object:DEFAULTSONGPLAYER];
		[VMPNotificationCenter addObserver:self
								  selector:@selector(logReceived:)
									  name:VMPNotificationLogAdded
									object:nil];
	}
}

- (id)init {
	self = [super init];
	if (self) [self initInternal];
	return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
	self = [super initWithCoder:aDecoder];
	if (self) [self initInternal];
	return self;
}

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
	if (self) [self initInternal];
    return self;
}

- (void)dealloc {
	VMNullify(log);
	VMNullify(filteredLog);
	if (kUseNotification) [VMPNotificationCenter removeObserver:self];
	Dealloc( super );;
}

- (void)awakeFromNib {
	//	don't place anything heavy in here because it get's called from tableview datasource method.
	self.logTableView.doubleAction = @selector(doubleClickOnRow:);
}

- (void)viewDidMoveToWindow {
	[self sourceChoosen:self];
}


#pragma mark -
#pragma mark accessor

- (VMLogRecord*)itemAtRow:(NSInteger)row {
	return [self.filteredLog item:row];
}

- (VMLogOwnerType)currentSource {
	return (int)self.sourceChooser.selectedSegment;
}

- (void)setCurrentSource:(VMLogOwnerType)currentSource {
	self.sourceChooser.selectedSegment = (NSInteger)currentSource;
}


#pragma mark -
#pragma mark * actions *

/*---------------------------------------------------------------------------------
 
 action
 
 ----------------------------------------------------------------------------------*/

#pragma mark locate
- (void)locateLogWithIndex:(VMInt)index ofSource:(VMLogOwnerType)owner {
	self.currentSource = owner;
	[self sourceChoosen:self];
	[self makeFilteredLog];
	
	VMInt row = 0;
	if ( index < 0 ) {
		row = self.filteredLog.count -1;
	} else {
		for ( VMLogRecord *lr in self.filteredLog ) {
			if( lr.index >= index ) break;
			++row;
		}
	}
	[self.logTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
	[self.logTableView scrollRowToVisible:row];
}

#pragma mark updating log
/*---------------------------------------------------------------------------------
 
 songPlayerListener: receive notifications from VMPSongPlayer
 
 ----------------------------------------------------------------------------------*/

- (void)songPlayerListener:(NSNotification*)notification {
	if ( [notification.name isEqualToString:@"AudioFragmentQueued"] ) {
		if ( self.currentSource != VMLogOwner_MediaPlayer ) return;
		
		//
		// new audioFragment was queued: update player log.
		//
		VMFloat scrollerPosition = self.logScrollView.verticalScroller.floatValue;
		
		[self makeFilteredLog];
		[self.logTableView noteNumberOfRowsChanged];
		
		if ( scrollerPosition == 1. ) {
			[self.logScrollView.contentView scrollToPoint:
			 NSMakePoint(0., self.logTableView.frame.size.height - self.logScrollView.contentSize.height)];
			[self.logScrollView reflectScrolledClipView:self.logScrollView.contentView];
		}
	}
	
	if ( [notification.name isEqualToString:@"AudioFragmentFired"]) {
		
		//VMAudioFragmentPlayer *ac = (notification.userInfo)[@"audioFragment"];
		
		VMInt	seekCount = 100;
		VMTime	now = [NSDate timeIntervalSinceReferenceDate];
		for ( VMInt row = self.logTableView.numberOfRows -1; row > 0; --row ) {
			VMLogRecord *rl = [self itemAtRow:row];
			if ( rl.type == vmObjectType_audioFragmentPlayer ) {
				VMAudioFragmentPlayer *afp = ClassCast(rl.data, VMAudioFragmentPlayer);
				if ( afp.firedTimestamp < now ) 
					[self fireAllAudioFragmentsBelowIndex:rl.index];
				break;
			}
			if (! --seekCount ) break;
		}
		
		[self.logTableView reloadData];
	}
}

- (void)fireAllAudioFragmentsBelowIndex:(VMInt)index {
	VMTime now = [NSDate timeIntervalSinceReferenceDate];

	VMInt i = _log.count -1;
	for ( ; i; --i ) {
		VMLogRecord *hl = [_log item:i];
		if ( hl.index <= index ) break;
	}
	
	for ( ; i; --i ) {
		VMLogRecord *hl = [_log item:i];
		if ( hl.playbackTimestamp ) break;
		hl.playbackTimestamp = now;
	}
}


- (void)logReceived:(NSNotification*)notification {
	int owner = [(notification.userInfo)[@"owner"] intValue];
	
	if ( self.currentSource != owner ) {
		[self.sourceChooser setSelected:YES forSegment:owner];
		[self.window makeKeyAndOrderFront:self];
	} else {
		//	only update once in 0.5 secs.
		if( ! _updateScheduled ) {
			_updateScheduled = YES;
			[self sourceChoosen:self];
			[self performSelector:@selector(resetSchedule:) withObject:self afterDelay:0.5];
		}

		//	always show logwindow when system log or user log was added.
		if ( owner == VMLogOwner_System || owner == VMLogOwner_User )
			[self.window makeKeyAndOrderFront:self];
	}
}

- (void)resetSchedule:(id)sender {
	_updateScheduled = NO;
}

#pragma mark change source
- (IBAction)sourceChoosen:(id)sender {
	_updateScheduled = NO;
	switch ( self.currentSource ) {
		case VMLogOwner_MediaPlayer:
			self.log = CURRENTSONG.log;
			[self makeFilteredLog];
			break;
			
		case VMLogOwner_Statistics:
			self.log = DEFAULTANALYZER.log;
			[self makeFilteredLog];
			break;
			
		case VMLogOwner_System:
			self.log = APPDELEGATE.systemLog;
			self.filteredLog = AutoRelease([self.log copy]);
			[self.logTableView reloadData];
			break;
			
		case VMLogOwner_User:
			self.log = APPDELEGATE.userLog;
			self.filteredLog = AutoRelease([self.log copy]);
			[self makeFilteredLog];
			break;
	}
}

#pragma mark click and double click

- (VMLogRecord*)postNotification:(VMString*)notificationName {
	VMLogRecord *hl = [self itemAtRow:self.logTableView.selectedRow];
	if ( hl.type != vmObjectType_notVMObject ) {
		id data = [self itemAtRow:self.logTableView.selectedRow].data;
		if ( ClassMatch(data, VMData) ) data = ((VMData*)data).id;
		[VMPNotificationCenter postNotificationName:notificationName
											 object:self
										   userInfo:@{@"id":data}];
	}
	return hl;
}

- (IBAction)clickOnRow:(id)sender {
	[self postNotification:VMPNotificationFragmentSelected];
	
	//	redraw for change row color
	NSRange visibleRange = [self.logTableView rowsInRect:[self.logTableView visibleRect]];
	[self.logTableView reloadDataForRowIndexes:[NSIndexSet indexSetWithIndexesInRange:visibleRange]
								 columnIndexes:[NSIndexSet indexSetWithIndex:0]];
}

- (IBAction)doubleClickOnRow:(id)sender {
	[self postNotification:VMPNotificationFragmentDoubleClicked];
}

#pragma mark filtering
- (IBAction)filterSelected:(id)sender {
	[self makeFilteredLog];
}


- (void)makeFilteredLog {
	NSSegmentedControl *fs = self.filterSelector;
	
	if( ! self.log.usePersistentStore ) {
		//
		//	no persistent store context connected to model
		//
		VMHash *typeHash = ARInstance(VMHash);
		if( [fs isSelectedForSegment:0] )   [typeHash setItem:@(YES) for:@(vmObjectType_selector)];
		if( [fs isSelectedForSegment:1] )   [typeHash setItem:@(YES) for:@(vmObjectType_sequence)];
		if( [fs isSelectedForSegment:2] ) { [typeHash setItem:@(YES) for:@(vmObjectType_audioFragment)];
											[typeHash setItem:@(YES) for:@(vmObjectType_audioFragmentPlayer)]; }
		if( [fs isSelectedForSegment:3] )   [typeHash setItem:@(YES) for:@(vmObjectType_notVMObject)];
		
		self.filteredLog = AutoRelease([[VMLog alloc] initWithOwner:self.currentSource managedObjectContext:nil] );
		for ( VMLogRecord *hl in self.log )
			if ( [typeHash item:@( hl.type ) ] ) [self.filteredLog push:hl];
		
	} else {
		//
		//	use persistent store: fetch from db
		//
		VMArray *typeArray = ARInstance(VMArray);
		if( [fs isSelectedForSegment:0] ) [typeArray push:[NSString stringWithFormat:@"type_obj = %d",vmObjectType_selector]];
		if( [fs isSelectedForSegment:1] ) [typeArray push:[NSString stringWithFormat:@"type_obj = %d",vmObjectType_sequence]];
		if( [fs isSelectedForSegment:2] ) [typeArray push:[NSString stringWithFormat:@"type_obj = %d or type_obj = %d",
														   vmObjectType_audioFragment, vmObjectType_audioFragmentPlayer ]];
		if( [fs isSelectedForSegment:3] ) [typeArray push:[NSString stringWithFormat:@"type_obj = %d",vmObjectType_notVMObject]];
		
		self.filteredLog = AutoRelease([[VMLog alloc] initWithOwner:self.currentSource
									managedObjectContext:[APPDELEGATE managedObjectContext]] );
		if ( typeArray.count > 0 )
			[self.filteredLog loadWithPredicateString:[NSString stringWithFormat:@"(%@)", [typeArray join:@" or "]]];
		else
			[self.filteredLog loadWithPredicateString:nil];
	}
	[self.logTableView reloadData];
}

#pragma mark expand / shrink
- (IBAction)disclosureButtonClicked:(id)sender {
	VMInt row = [self.logTableView rowForView:((NSButton*)sender).superview];
	VMLogRecord *hl = [self itemAtRow:row];
	hl.expanded = ! hl.expanded;
	
	NSIndexSet *is = [NSIndexSet indexSetWithIndex:row];
	[self.logTableView noteHeightOfRowsWithIndexesChanged:is];
	[self.logTableView reloadData];
}

#pragma mark clear log
- (IBAction)clearLog:(id)sender {
	[self.log clear];
	[self makeFilteredLog];
}

#pragma mark text edit


- (IBAction)textChanged:(id)sender {
	NSTextField *tf = sender;
	VMInt row = tf.tag;
	
	VMLogRecord *hl = [self itemAtRow:row];
	VMHash *subInfo = hl.subInfo;
	[subInfo setItem:tf.stringValue for:@"message"];
	hl.subInfo = subInfo;
	
	hl.expandedHeight = -1;
	[self.filteredLog save];
	
	[self.logTableView reloadData];
}


#pragma mark -
#pragma mark tableview datasource and delegate

/*---------------------------------------------------------------------------------
 
 tableview
 
 ----------------------------------------------------------------------------------*/


- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
	return self.filteredLog.count +1;
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
	if ( tableColumn ) {
		return [NSString stringWithFormat:@"(%ld items)",self.filteredLog.count];
	}
	return nil;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
	if ( ! tableColumn ) return nil;
	VMPLogItemView *logView = [tableView makeViewWithIdentifier:@"logItemView" owner:self];
	VMFloat width = tableColumn.width;
	BOOL selected = row == tableView.selectedRow;

	if ( logView ) {
		
		if ( self.filteredLog.count <= row ) {
			//	last row is always empty:
			NSTextField *tf = AutoRelease([[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, width, 14)] );
			tf.backgroundColor = [NSColor lightGrayColor];
			tf.alignment = NSCenterTextAlignment;
			tf.stringValue = @"*";
			tf.bordered = NO;
			tf.font = [NSFont systemFontOfSize:10];
			return tf;
		}
		VMLogRecord *rl = [self itemAtRow:row];
		
		
		vmObjectType type = rl.type;
		NSString *action = rl.action;
		if ( ! action ) return nil;
		
		NSColor *bgColor = [NSColor colorWithCalibratedRed:.5 green:.5 blue:.5 alpha:1.];
		if( type != vmObjectType_notVMObject ) {
			action = [action stringByAppendingFormat:@"\t%@",ClassMatch(rl.data, VMId) ? rl.data : rl.VMData.id];
			bgColor = [NSColor backgroundColorForDataType:type];
		} else {
			if		( [action hasPrefix:@"War"] )
				bgColor = [NSColor colorWithCalibratedRed:1. green:.8 blue:.4 alpha:1.];
			else if ( [action hasPrefix:@"Err"] )
				bgColor = [NSColor colorWithCalibratedRed:1. green:.5 blue:.5 alpha:1.];
		}
		logView.backgroundColor = selected ? [bgColor colorModifiedByHueOffset:0
															  saturationFactor:1.1
															  brightnessFactor:.5] : bgColor;

		logView.textField.stringValue = action;
		NSDate *date = [NSDate dateWithTimeIntervalSinceReferenceDate:rl.timestamp];
		logView.timeStampField.stringValue = [NSDateFormatter localizedStringFromDate:date
																			dateStyle:NSDateFormatterNoStyle
																			timeStyle:NSDateFormatterMediumStyle];
		logView.discosureButton.state = rl.isExpanded ? NSOnState : NSOffState;
		
		
		logView.discosureButton.hidden = (rl.subInfo == nil);
		
		//	don't care about vmAudioFragmentPlayer's firedTimestamp here.
		logView.fired = ( rl.playbackTimestamp != 0 && rl.playbackTimestamp < [NSDate timeIntervalSinceReferenceDate] );
		
		if ( rl.isExpanded )  {
			//	logview is expanded:
			VMPGraph *expansionView = AutoRelease([[VMPGraph alloc]
												   initWithFrame:NSMakeRect(0, 0, width, rl.expandedHeight )] );			expansionView.backgroundColor = [NSColor whiteColor];
			expansionView.tag = 'expv';
			
			[[logView viewWithTag:'expv'] removeFromSuperview];
			[logView addSubview:expansionView];
			switch ( (int)rl.type ) {
				case vmObjectType_selector: {
					
					if ( [action hasPrefix:@"SEL"] ) {
						VMHash *scoreForFragments = rl.subInfo;
						VMArray *keys = [scoreForFragments sortedKeys];
						VMFloat sum = [[scoreForFragments values] sum];
						VMFloat pixPerScore = width / sum;
						VMFloat x = 0;
						VMId *selectedFragment = [scoreForFragments item:@"vmlog_selected"];
						for( VMId *key in keys ) {
							if ( [key isEqualToString:@"vmlog_selected"] ) continue;
							VMFloat score = [scoreForFragments itemAsFloat:key];
							VMFloat sw = score * pixPerScore;							
							VMPFragmentCell *fc = [[VMPFragmentCell alloc] initWithFrame:NSMakeRect(x, 0, sw -1, 29)];
							x += sw;
							VMData *d = [CURRENTSONG data:key];
							[fc setData:d];
							if ( [key isEqualToString:selectedFragment] ) fc.selected = YES;
							[expansionView addSubview:fc];
							Release(fc);
						}
					}
					break;
				}
					
				case vmObjectType_sequence: {					
					if ( rl.subInfo ) {
						VMArray *acList = [rl.subInfo item:@"audioFragments"];
						VMFloat y = rl.expandedHeight - 15;
						if ( acList ) {
							for( VMAudioFragment *ac in acList) {
								NSTextField *tf = [[NSTextField alloc] initWithFrame:NSMakeRect(12, y, width-12, 14)];
								tf.stringValue = [NSString stringWithFormat:@"AC %@", ac.id];
								tf.backgroundColor = [NSColor backgroundColorForDataType:vmObjectType_audioFragment];
								tf.bordered = tf.editable = NO;
								tf.tag = -1;
								tf.font = [NSFont systemFontOfSize:10];
								tf.drawsBackground = YES;
								[expansionView addSubview:tf];
								Release( tf );
								y -= 15;
							}
						}
					}
					break;
				}
					
				case vmObjectType_notVMObject: {
					logView.fired = YES;
					break;
				}
			}	//	end switch(hl.type)
			
			//
			//	add message if provided
			//
			if ( rl.subInfo ) {
				VMString *message = rl.message;
				if ( message ) {
					VMPTextField *tf = [[VMPTextField alloc] initWithFrame:expansionView.frame];
					tf.stringValue = message;
					tf.bordered = NO;
					tf.bezeled = tf.editable = ( self.log.owner == VMLogOwner_User );
					tf.font = [NSFont systemFontOfSize:10];
					tf.target = self;
					tf.action = @selector(textChanged:);
					tf.tag = row;
					[expansionView addSubview:tf];
					if ( selected )
						[tf becomeFirstResponder];
					Release( tf );
				}
			}
			
			
		} else { // hl is not expanded
			//	not expanded
			[[logView viewWithTag:'expv'] removeFromSuperview];
		}
		
		return logView;
	}

	//	fallback
	NSTextField *tf = AutoRelease( [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 250, 14)] );
	tf.stringValue = @"logItem not created";
	return tf;
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row {
	VMLogRecord *hl = [self itemAtRow:row];
	return hl.isExpanded ? hl.expandedHeight + kDefaultLogItemViewHeight : kDefaultLogItemViewHeight;
}

/*

- (void)tableView:(NSTableView *)tableView didAddRowView:(NSTableRowView *)rowView forRow:(NSInteger)row {
	
}

- (void)tableView:(NSTableView *)tableView didRemoveRowView:(NSTableRowView *)rowView forRow:(NSInteger)row {
	
}
*/

@end

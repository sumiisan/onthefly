//
//  VMPLogView.m
//  GotchaP
//
//  Created by sumiisan on 2013/04/21.
//
//

#import "VMPLogView.h"
#import "VMSong.h"
#import "VMPGraph.h"
#import "VMPMacros.h"
#import "VMPAnalyzer.h"
#import "VMPSongPlayer.h"
#import "VMPreprocessor.h"

#import "VMPNotification.h"

static const VMFloat kDefaultLogItemViewHeight = 14.0;

/*---------------------------------------------------------------------------------
 
 Log Item View
 
 ----------------------------------------------------------------------------------*/

#pragma mark -
#pragma mark Log Item View

@implementation VMPLogItemView

- (id)initWithCoder:(NSCoder *)aDecoder {
	self = [super initWithCoder:aDecoder];
	if (self) {
		self.backgroundColor = [NSColor colorWithCalibratedRed:.9 green:.9 blue:.9 alpha:1.];
	}
	return self;
}

- (void)dealloc {
	self.backgroundColor = nil;
	[super dealloc];
}

- (void)drawRect:(NSRect)dirtyRect {
//	self.textField.backgroundColor = self.backgroundColor;
//	self.timeStampField.backgroundColor = self.backgroundColor;
	if ( ! self.fired ) {
		[[self.backgroundColor colorModifiedByHueOffset:0. saturationFactor:0.8 brightnessFactor:1.2] setFill];
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
@implementation VMPLogView

- (void)initInternal {
	if (kUseNotification) {
		[VMPNotificationCenter addObserver:self
								  selector:@selector(songPlayerListener:)
									  name:nil
									object:DEFAULTSONGPLAYER];
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
	self.log = nil;
	self.filteredLog = nil;
	if (kUseNotification) [VMPNotificationCenter removeObserver:self];
	[super dealloc];
}

- (void)awakeFromNib {
	//	don't place anything in here because it get's called from tableview datasource method.
}

- (void)viewDidMoveToSuperview {
	self.logTableView.doubleAction = @selector(doubleClickOnRow:);
	[self sourceChoosen:self];
	[self sourceChoosen:self];
}


#pragma mark -
#pragma mark accessor

- (VMHistoryLog*)itemAtRow:(NSInteger)row {
	return [self.filteredLog item:row];
}

- (VMPLogViewSourceType)currentSource {
	return (int)self.sourceChooser.selectedSegment;
}

- (void)setCurrentSource:(VMPLogViewSourceType)currentSource {
	self.sourceChooser.selectedSegment = (NSInteger)currentSource;
}


#pragma mark -
#pragma mark actions

/*---------------------------------------------------------------------------------
 
 action
 
 ----------------------------------------------------------------------------------*/


- (void)locateLogWithIndex:(VMInt)index ofSource:(VMPLogViewSourceType)source {
	self.currentSource = source;
	[self sourceChoosen:self];
	[self makeFilteredLog];
	
	VMInt row = 0;
	if ( index < 0 ) {
		row = self.filteredLog.count -1;
	} else {
		for ( VMHistoryLog *hl in self.filteredLog ) {
			if( hl.index >= index ) break;
			++row;
		}
	}
	[self.logTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
	[self.logTableView scrollRowToVisible:row];
}


/*---------------------------------------------------------------------------------
 
 songPlayerListener: receive notifications from VMPSongPlayer
 
 ----------------------------------------------------------------------------------*/

- (void)songPlayerListener:(NSNotification*)notification {
	if ( self.currentSource != VMPLogViewSource_Player ) return;
	if ( [notification.name isEqualToString:@"AudioCueQueued"] ) {
		
		//
		// new audioCue was queued: update player log.
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
	
	if ( [notification.name isEqualToString:@"AudioCueFired"]) {
		
		VMAudioCue *ac = [notification.userInfo objectForKey:@"audioCue"];
//		NSRange range = [self.logTableView rowsInRect:self.logTableView.visibleRect];
		
		VMInt seekCount = 100;
		for ( VMInt row = self.logTableView.numberOfRows -1; row > 0; --row ) {
			VMHistoryLog *hl = [self itemAtRow:row];
			if ( hl.data == ac ) {
				[self fireAllAudioCuesBelowIndex:hl.index];
				break;
			}
			if (! --seekCount ) break;
		}
		
		[self.logTableView reloadData];
	}
}

- (void)fireAllAudioCuesBelowIndex:(VMInt)index {
	VMTime now = [NSDate timeIntervalSinceReferenceDate];

	VMInt i = _log.count -1;
	for ( ; i; --i ) {
		VMHistoryLog *hl = [_log item:i];
		if ( hl.index <= index ) break;
	}
	
	for ( ; i; --i) {
		VMHistoryLog *hl = [_log item:i];
		if ( hl.playbackTimestamp ) break;
		hl.playbackTimestamp = now;
	}
}


- (IBAction)sourceChoosen:(id)sender {
	switch ( self.currentSource ) {
		case VMPLogViewSource_Player:
			//	song log
			self.log = DEFAULTSONG.log;
			[self makeFilteredLog];
			break;
			
		case VMPLogViewSource_Statistics:
			//	stats
			self.log = DEFAULTANALYZER.log;
			[self makeFilteredLog];
			break;
			
		case VMPLogViewSource_System:
			//	implement later
			self.log = DEFAULTPREPROCESSOR.log;
			self.filteredLog = [[self.log copy] autorelease];
			[self.logTableView reloadData];
			break;
	}

}

- (void)postNotification:(VMString*)notificationName {
	VMHistoryLog *hl = [self itemAtRow:self.logTableView.selectedRow];
	if ( hl.type != vmObjectType_notVMObject ) {
		VMData *data = [self itemAtRow:self.logTableView.selectedRow].data;
		[VMPNotificationCenter postNotificationName:notificationName
											 object:self
										   userInfo:@{@"id":data.id}];
	}	
}

- (IBAction)clickOnRow:(id)sender {
	[self postNotification:VMPNotificationCueSelected];
}

- (IBAction)doubleClickOnRow:(id)sender {
	[self postNotification:VMPNotificationCueDoubleClicked];
}

- (void)makeFilteredLog {
	VMArray *typeArray = ARInstance(VMArray);
	NSSegmentedControl *fs = self.filterSelector;
	
	if( [fs isSelectedForSegment:0] ) [typeArray push:VMIntObj(vmObjectType_selector) ];
	if( [fs isSelectedForSegment:1] ) [typeArray push:VMIntObj(vmObjectType_sequence) ];
	if( [fs isSelectedForSegment:2] ) [typeArray push:VMIntObj(vmObjectType_audioCue) ];
	if( [fs isSelectedForSegment:3] ) [typeArray push:VMIntObj(vmObjectType_notVMObject)];
	
	self.filteredLog = ARInstance(VMLog);
	for ( VMHistoryLog *hl in self.log ) {
		if ( [typeArray position:VMIntObj( hl.type )] >= 0 ) [self.filteredLog push:hl];
	}
	[self.logTableView reloadData];
}

- (IBAction)filterSelected:(id)sender {
	[self makeFilteredLog];
}

- (IBAction)disclosureButtonClicked:(id)sender {
	VMInt row = [self.logTableView rowForView:((NSButton*)sender).superview];
	VMHistoryLog *hl = [self itemAtRow:row];
	hl.expanded = ! hl.expanded;
	
	NSIndexSet *is = [NSIndexSet indexSetWithIndex:row];
	[self.logTableView noteHeightOfRowsWithIndexesChanged:is];
//	[self.logTableView reloadDataForRowIndexes:is columnIndexes:[NSIndexSet indexSetWithIndex:0]];
	[self.logTableView reloadData];
}


#pragma mark -
#pragma mark tableview

/*---------------------------------------------------------------------------------
 
 tableview
 
 ----------------------------------------------------------------------------------*/


- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
	NSLog(@"nlumberOfRowsInTableView %ld",self.filteredLog.count);
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

	if ( logView ) {
		
		if ( self.filteredLog.count <= row ) {
			//	last row is always empty:
			NSTextField *tf = [[[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, width, 14)] autorelease];
			tf.backgroundColor = [NSColor lightGrayColor];
			tf.alignment = NSCenterTextAlignment;
			tf.stringValue = @"*";
			tf.bordered = NO;
			tf.font = [NSFont systemFontOfSize:10];
			return tf;
		}
		VMHistoryLog *hl = [self itemAtRow:row];
		
		vmObjectType type = hl.type;
		
		NSString *action = hl.action;
		if ( type != vmObjectType_notVMObject ) action = [action stringByAppendingFormat:@" %@",((VMData*)hl.data).id];
		
		logView.textField.stringValue = action;
		NSDate *date = [NSDate dateWithTimeIntervalSinceReferenceDate:hl.timestamp];
		logView.timeStampField.stringValue = [NSDateFormatter localizedStringFromDate:date
																			dateStyle:kCFDateFormatterNoStyle
																			timeStyle:kCFDateFormatterMediumStyle];
		logView.discosureButton.state = hl.isExpanded ? NSOnState : NSOffState;
		logView.backgroundColor = [NSColor backgroundColorForDataType:type];
		logView.discosureButton.hidden = (hl.subInfo == nil);
		logView.fired = ( hl.playbackTimestamp != 0 && hl.playbackTimestamp < [NSDate timeIntervalSinceReferenceDate] );
		
		if ( hl.isExpanded )  {
			//	logview is expanded:
			VMPCanvas *expansionView = [[[VMPCanvas alloc] initWithFrame:NSMakeRect(0, 0, width, 30 )] autorelease];
			expansionView.backgroundColor = [NSColor whiteColor];
			expansionView.tag = 'expv';
			[[logView viewWithTag:'expv'] removeFromSuperview];
			[logView addSubview:expansionView];
			switch ( (int)hl.type ) {
				case vmObjectType_selector: {
					
					if ( hl.subInfo ) {
						VMHash *scoreForCues = hl.subInfo;
						VMArray *keys = [scoreForCues sortedKeys];
						VMFloat sum = [[scoreForCues values] sum];
						VMFloat pixPerScore = width / sum;
						VMFloat x = 0;
						VMId *selectedCue = [scoreForCues item:@"vmlog_selected"];
						for( VMId *key in keys ) {
							if ( [key isEqualToString:@"vmlog_selected"] ) continue;
							BOOL selected = [key isEqualToString:selectedCue];
							VMFloat score = [scoreForCues itemAsFloat:key];
							VMFloat sw = score * pixPerScore;
							NSTextField *tf = [[NSTextField alloc] initWithFrame:NSMakeRect(x, 0, sw -1, 29)];
							x += sw;
							VMData *d = [DEFAULTSONG data:key];
							tf.backgroundColor = [NSColor backgroundColorForDataType:d ? d.type : 0];
							tf.drawsBackground = YES;
							tf.stringValue = key;
							tf.editable = tf.bordered = NO;
							tf.font = selected ? [NSFont boldSystemFontOfSize:9] : [NSFont systemFontOfSize:9];
							tf.toolTip = key;
							[expansionView addSubview:tf];
							[tf release];
						}
					}
					break;
				}
					
				case vmObjectType_sequence: {
					
					if ( hl.subInfo ) {
						VMArray *acList = [hl.subInfo item:@"audioCues"];
						VMFloat xvHeight = acList.count * 15;
						expansionView.frame = NSMakeRect(0, 0, width, xvHeight);
						VMFloat y = xvHeight - 15;
						if ( acList ) {
							for( VMAudioCue *ac in acList) {
								NSTextField *tf = [[NSTextField alloc] initWithFrame:NSMakeRect(12, y, width-12, 14)];
								tf.stringValue = [NSString stringWithFormat:@"AC %@", ac.id];
								tf.backgroundColor = [NSColor backgroundColorForDataType:vmObjectType_audioCue];
								tf.bordered = tf.editable = NO;
								tf.font = [NSFont systemFontOfSize:10];
								tf.drawsBackground = YES;
								[expansionView addSubview:tf];
								[tf release];
								y -= 15;
							}
						}
					}
					
				}
					
				case vmObjectType_notVMObject: {
					if ( hl.subInfo ) {
						VMString *message = [hl.subInfo item:@"message"];
						expansionView.frame = NSMakeRect(0, 0, width, hl.expandedHeight);
						if ( message ) {
							NSTextField *tf = [[NSTextField alloc] initWithFrame:expansionView.frame];
							tf.stringValue = message;
							tf.bordered = tf.editable = NO;
							tf.font = [NSFont systemFontOfSize:10];
							[expansionView addSubview:tf];
							[tf release];
						}
					}
					logView.fired = YES;
				}
			}
			
			
		} else {
			//	not expanded
			[[logView viewWithTag:'expv'] removeFromSuperview];
		}
		
		
		
		return logView;
	}

	//	fallback
	NSTextField *tf = [[[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 250, 14)] autorelease];
	tf.stringValue = @"logItem not created";
	return tf;
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row {
	VMHistoryLog *hl = [self itemAtRow:row];
	return hl.isExpanded ? hl.expandedHeight + kDefaultLogItemViewHeight : kDefaultLogItemViewHeight;
}


- (void)tableView:(NSTableView *)tableView didAddRowView:(NSTableRowView *)rowView forRow:(NSInteger)row {
	
}

- (void)tableView:(NSTableView *)tableView didRemoveRowView:(NSTableRowView *)rowView forRow:(NSInteger)row {
	
}


@end

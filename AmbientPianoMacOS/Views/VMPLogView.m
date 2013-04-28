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
		self.backgroundColor = [NSColor controlBackgroundColor];
	}
	return self;
}

- (void)dealloc {
	self.backgroundColor = nil;
	[super dealloc];
}

- (void)drawRect:(NSRect)dirtyRect {
	[self.backgroundColor setFill];
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
	[super dealloc];
}
/*
- (void)drawRect:(NSRect)dirtyRect {
    // Drawing code here.
}
*/

#pragma mark -
#pragma mark accessor

- (VMHistoryLog*)itemAtRow:(NSInteger)row {
	return [self.filteredLog item:row];
}


#pragma mark -
#pragma mark actions

/*---------------------------------------------------------------------------------
 
 action
 
 ----------------------------------------------------------------------------------*/
/*
- (void)setPlayerLogMode {
	self.log = DEFAULTSONG.log;
	[self makeFilteredLog];
	[((NSSegmentedControl*)self.sourceChooser) setSelectedSegment:0];
	self.logScrollView.verticalScroller.floatValue = 1.;
	
}
*/

- (void)locateLogWithIndex:(VMInt)index ofSource:(VMString*)source {
	if ( [source isEqualToString:@"player"] ) {
		self.log = DEFAULTSONG.log;
		[((NSSegmentedControl*)self.sourceChooser) setSelectedSegment:0];
	}

	if ( [source isEqualToString:@"statistics"] ) {
		self.log = DEFAULTANALYZER.log;
		[((NSSegmentedControl*)self.sourceChooser) setSelectedSegment:1];
	}
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


- (void)noteNewLogAdded {
	
	VMFloat scrollerPosition = self.logScrollView.verticalScroller.floatValue;
	
	[self makeFilteredLog];
	[self.logTableView noteNumberOfRowsChanged];
	
	if ( scrollerPosition == 1. ) {
		[self.logScrollView.contentView scrollToPoint:
		 NSMakePoint(0., self.logTableView.frame.size.height - self.logScrollView.contentSize.height)];
		[self.logScrollView reflectScrolledClipView:self.logScrollView.contentView];
	}
}


- (IBAction)sourceChoosen:(id)sender {
	NSSegmentedControl *sc = sender;
	switch (sc.selectedSegment) {
		case 0:
			//	song log
			self.log = DEFAULTSONG.log;
			[self makeFilteredLog];
			break;
			
		case 1:
			//	stats
			self.log = DEFAULTANALYZER.log;
			[self makeFilteredLog];
			break;
	}
	
}

- (IBAction)clickOnRow:(id)sender {
	
	NSTableView *tv = sender;
	
	NSLog(@"row %ld clicked",tv.selectedRow);
	
}

- (void)makeFilteredLog {
	VMArray *typeArray = ARInstance(VMArray);
	NSSegmentedControl *fs = self.filterSelector;
	
	if( [fs isSelectedForSegment:0] ) [typeArray push:VMIntObj(vmObjectType_selector) ];
	if( [fs isSelectedForSegment:1] ) [typeArray push:VMIntObj(vmObjectType_sequence) ];
	if( [fs isSelectedForSegment:2] ) [typeArray push:VMIntObj(vmObjectType_audioCue) ];
//	if( [fs isSelectedForSegment:3] ) [typeArray push:VMIntObj(vmObjectType_selector) ];
	if( [fs isSelectedForSegment:4] ) [typeArray push:VMIntObj(vmObjectType_notVMObject)];
	
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

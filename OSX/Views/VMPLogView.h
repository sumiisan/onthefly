//
//  VMPLogView.h
//  OnTheFly
//
//  Created by sumiisan on 2013/04/21.
//
//

#import <Cocoa/Cocoa.h>
#import "VMLog.h"
#import "VMPCanvas.h"

/*---------------------------------------------------------------------------------
 *
 *
 *	Log Item View
 *
 *
 *---------------------------------------------------------------------------------*/

@interface VMPLogItemView : NSTableCellView
@property (nonatomic, VMWeak) IBOutlet	NSTextField			*idField;
@property (nonatomic, VMWeak) IBOutlet	NSTextField			*timeStampField;
@property (nonatomic, VMWeak) IBOutlet	NSButton			*discosureButton;
@property (nonatomic, VMStrong)			NSColor				*backgroundColor;
@property (nonatomic, assign)			BOOL				fired;

@end

/*---------------------------------------------------------------------------------
 *
 *
 *	Log Panel View (table)
 *
 *
 *---------------------------------------------------------------------------------*/


@interface VMPLogView : NSView <NSTableViewDataSource, NSTableViewDelegate>


@property (nonatomic, VMWeak)	IBOutlet	NSSegmentedControl  *sourceChooser;
@property (nonatomic, VMWeak)	IBOutlet	NSSegmentedControl  *filterSelector;
@property (nonatomic, VMWeak)	IBOutlet	NSTableView			*logTableView;
@property (nonatomic, VMWeak)	IBOutlet	NSScrollView		*logScrollView;

@property (nonatomic, assign)				VMLogOwnerType		currentSource;

@property (nonatomic, VMStrong)				VMLog				*log;
@property (nonatomic, VMStrong)				VMLog				*filteredLog;

//- (void)noteNewLogAdded;
- (void)locateLogWithIndex:(VMInt)index ofSource:(VMLogOwnerType)source;
//- (void)locateLogWithIndex:(VMInt)index ofSource:(VMString*)source;

- (IBAction)sourceChoosen:(id)sender;
- (IBAction)clickOnRow:(id)sender;
- (IBAction)disclosureButtonClicked:(id)sender;
- (IBAction)filterSelected:(id)sender;


@end

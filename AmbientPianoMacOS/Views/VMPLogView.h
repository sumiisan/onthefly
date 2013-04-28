//
//  VMPLogView.h
//  GotchaP
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
@property (nonatomic, assign) IBOutlet	NSTextField			*idField;
@property (nonatomic, assign) IBOutlet	NSTextField			*timeStampField;
@property (nonatomic, assign) IBOutlet	NSButton			*discosureButton;
@property (nonatomic, retain)			NSColor				*backgroundColor;

@end

/*---------------------------------------------------------------------------------
 *
 *
 *	Log Panel View (table)
 *
 *
 *---------------------------------------------------------------------------------*/

@interface VMPLogView : NSView <NSTableViewDataSource, NSTableViewDelegate>


@property (nonatomic, assign)	IBOutlet	NSSegmentedControl  *sourceChooser;
@property (nonatomic, assign)	IBOutlet	NSSegmentedControl  *filterSelector;
@property (nonatomic, assign)	IBOutlet	NSTableView			*logTableView;
@property (nonatomic, assign)	IBOutlet	NSScrollView		*logScrollView;

@property (nonatomic, retain)				VMLog				*log;
@property (nonatomic, retain)				VMLog				*filteredLog;

- (void)noteNewLogAdded;
- (void)locateLogWithIndex:(VMInt)index ofSource:(VMString*)source;

- (IBAction)sourceChoosen:(id)sender;
- (IBAction)clickOnRow:(id)sender;
- (IBAction)disclosureButtonClicked:(id)sender;
- (IBAction)filterSelected:(id)sender;


@end

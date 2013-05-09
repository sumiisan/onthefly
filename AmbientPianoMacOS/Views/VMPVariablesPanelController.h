//
//  VMPVariablesPanelController.h
//  OnTheFly
//
//  Created by sumiisan on 2013/05/02.
//
//

#import <Cocoa/Cocoa.h>
#import "VMPrimitives.h"

@interface VMPVariablesPanelController : NSWindowController
<NSTableViewDataSource, NSTableViewDelegate> {
	BOOL tableReloadingScheduled;
}


@property (nonatomic, assign) IBOutlet NSSegmentedControl	*typeSelector;
@property (nonatomic, assign) IBOutlet NSTableView			*tableView;
@property (nonatomic, assign) IBOutlet NSTextField			*expressionInputField;
@property (nonatomic, assign) IBOutlet NSTextField			*resultField;


@property (nonatomic, retain)			VMArray				*itemsInTable;
@property (nonatomic, retain)			VMId				*selectedCueId;

- (IBAction)typeSelected:(id)sender;
- (IBAction)expressionEntered:(id)sender;

@end

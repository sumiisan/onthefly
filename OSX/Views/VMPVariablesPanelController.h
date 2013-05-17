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


@property (nonatomic, VMWeak) IBOutlet NSSegmentedControl	*typeSelector;
@property (nonatomic, VMWeak) IBOutlet NSTableView			*tableView;
@property (nonatomic, VMWeak) IBOutlet NSTextField			*expressionInputField;
@property (nonatomic, VMWeak) IBOutlet NSTextField			*resultField;


@property (nonatomic, VMStrong)			VMArray				*itemsInTable;
@property (nonatomic, VMStrong)			VMId				*selectedFragmentId;

- (IBAction)typeSelected:(id)sender;
- (IBAction)expressionEntered:(id)sender;

@end

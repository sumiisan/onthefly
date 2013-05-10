//
//  VMPSelectorEditorViewController.h
//  OnTheFly
//
//  Created by sumiisan on 2013/05/04.
//
//

#import <Cocoa/Cocoa.h>
#import "VMPObjectGraphView.h"

typedef enum {
	VMPSelectorEditor_EditorTab = 0,
	VMPSelectorEditor_BranchTab,
	VMPSelectorEditor_FrameTab
} VMPSelectorEditorTab;

@interface VMPSelectorEditorViewController : NSViewController
<NSTableViewDataSource,NSTableViewDelegate,VMPDataGraphObject,NSTabViewDelegate>

@property (nonatomic, assign) IBOutlet NSTabView	*tabView;
@property (nonatomic, assign) IBOutlet NSTableView	*chanceTableView;
@property (nonatomic, assign) IBOutlet VMPGraph		*frameView;
@property (nonatomic, assign) IBOutlet NSScrollView	*frameViewScroller;
@property (nonatomic, assign) IBOutlet VMPGraph		*branchView;
@property (nonatomic, assign) IBOutlet NSScrollView	*branchViewScroller;


@property (nonatomic, retain)			VMSelector	*selector;


- (IBAction)clickOnRow:(id)sender;
- (IBAction)clickOnFragmentCell:(id)sender;


@end

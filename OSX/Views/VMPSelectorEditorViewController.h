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

@property (nonatomic, VMWeak) IBOutlet NSTabView	*tabView;
@property (nonatomic, VMWeak) IBOutlet NSTableView	*chanceTableView;
@property (nonatomic, VMWeak) IBOutlet VMPGraph		*frameView;
@property (nonatomic, VMWeak) IBOutlet NSScrollView	*frameViewScroller;
@property (nonatomic, VMWeak) IBOutlet VMPGraph		*branchView;
@property (nonatomic, VMWeak) IBOutlet NSScrollView	*branchViewScroller;


@property (nonatomic, VMStrong)			VMSelector				*selector;
@property (nonatomic, assign)			VMPSelectorDataSource	dataSource;

- (IBAction)clickOnRow:(id)sender;
- (IBAction)clickOnFragmentCell:(id)sender;


@end

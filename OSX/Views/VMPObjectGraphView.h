//
//  VMPObjectGraphView.h
//  OnTheFly
//
//  Created by sumiisan on 2013/05/03.
//
//

#import <Cocoa/Cocoa.h>
#import "VMPGraph.h"
#import "VMPEditorWindowController.h"

#pragma mark -
#pragma mark VMPSelectorGraph
//------------------------- VMPSelectorGraph -----------------------------
@interface VMPSelectorGraph : VMPFragmentCell <VMPFragmentCellDelegate> {
	VMPStraightLine		*line;
	VMHash				*branchViewTemporary;
}
@property (nonatomic)			BOOL frameGraphMode;
@end


#pragma mark -
#pragma mark VMPSequenceGraph
//------------------------- VMPSequenceGraph -----------------------------
@interface VMPSequenceGraph : VMPSelectorGraph <VMPFragmentCellDelegate>
@end



#pragma mark -
#pragma mark VMPObjectGraphView
//------------------------ VMPObjectGraphView ----------------------------
@interface VMPObjectGraphView : VMPGraph
@property (nonatomic, VMStrong) NSViewController	*editorViewController;
@property (nonatomic, VMStrong) VMData *data;

- (void)drawGraphWith:(VMData*)data;
- (void)drawReportGraph:(VMHash*)report;

@end



#pragma mark -
#pragma mark VMPObjectInfoView
//------------------------ VMPObjectInfoView ----------------------------
@interface VMPObjectInfoView : VMPGraph

@property (nonatomic, VMStrong) VMData *data;
@property (nonatomic, VMWeak) IBOutlet NSTextField *userGeneratedIdField;
@property (nonatomic, VMWeak) IBOutlet NSTextField *vmpModifierField;
@property (nonatomic, VMWeak) IBOutlet NSTextField *typeLabel;

- (void)drawInfoWith:(VMData*)data;

@end


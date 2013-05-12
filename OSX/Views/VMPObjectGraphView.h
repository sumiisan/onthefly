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
@property (nonatomic,retain) NSViewController	*editorViewController;
@property (nonatomic, assign) VMData *data;

- (void)drawGraphWith:(VMData*)data;
- (void)drawReportGraph:(VMHash*)report;

@end



#pragma mark -
#pragma mark VMPObjectInfoView
//------------------------ VMPObjectInfoView ----------------------------
@interface VMPObjectInfoView : VMPGraph
@property (nonatomic, assign) VMData *data;
@property (assign) IBOutlet NSTextField *userGeneratedIdField;
@property (assign) IBOutlet NSTextField *vmpModifierField;
@property (assign) IBOutlet NSTextField *typeLabel;

- (void)drawInfoWith:(VMData*)data;

@end


//
//  VMPObjectGraphView.h
//  OnTheFly
//
//  Created by sumiisan on 2013/05/03.
//
//

#import <Cocoa/Cocoa.h>
#import "VMPFragmentCell.h"
#import "VMPEditorWindowController.h"

typedef enum {
	VMPSelectorGraphType_Single = 0,
	VMPSelectorGraphType_Branch,
	VMPSelectorGraphType_Frame,
	VMPSelectorGraphType_Single_noLevels		//	do not resolve child selectors.
} VMPSelectorGraphType;

typedef enum {
	VMPSelectorDataSource_StaticVMS = 0,
	VMPSelectorDataSource_Statistics
} VMPSelectorDataSource;

@class VMPBranchGraphColumnList;

#pragma mark -
#pragma mark VMPCollectionGraph
//------------------------- VMPCollectionGraph -----------------------------
@interface VMPCollectionGraph : VMPFragmentCell <VMPFragmentGraphDelegate, VMPDataGraphObject> {
@protected
	VMPStraightLine				*line;
	VMPGraph					*temporaryLineLayer;
	VMPBranchGraphColumnList	*branchGraphColumnList, *lastFrameBranchGraphColumnList;
}
@property (nonatomic, assign)	VMPSelectorGraphType	graphType;
@property (nonatomic, assign)	VMPSelectorDataSource	dataSource;
@property (nonatomic, assign)	int						animationDirection;
@end

#pragma mark -
#pragma mark VMPSelectorGraph
//------------------------- VMPSelectorGraph -----------------------------
@interface VMPSelectorGraph : VMPCollectionGraph <VMPFragmentGraphDelegate, VMPDataGraphObject>
@end

#pragma mark -
#pragma mark VMPReferrerGraph
//------------------------- VMPReferrerGraph -----------------------------
@interface VMPReferrerGraph : VMPCollectionGraph <VMPFragmentGraphDelegate, VMPDataGraphObject>
@end

#pragma mark -
#pragma mark VMPSequenceGraph
//------------------------- VMPSequenceGraph -----------------------------
@interface VMPSequenceGraph : VMPCollectionGraph <VMPFragmentGraphDelegate, VMPDataGraphObject>
@end



#pragma mark -
#pragma mark VMPObjectGraphView
//------------------------ VMPObjectGraphView ----------------------------
@interface VMPObjectGraphView : VMPGraph
@property (nonatomic, VMStrong) NSViewController		*editorViewController;
@property (nonatomic, VMStrong) VMData *data;
@property (nonatomic, assign)	VMPSelectorDataSource	selectorDataSource;

- (void)drawGraphWith:(VMData*)data animationDirection:(int)direction;
- (void)drawReportGraph:(VMHash*)report;
- (void)chaseSequence:(VMAudioFragment*)audioFragment;

@end



#pragma mark -
#pragma mark VMPObjectInfoView
//------------------------ VMPObjectInfoView ----------------------------
@interface VMPObjectInfoView : VMPGraph

@property (nonatomic, VMStrong) VMData					*data;

@property (nonatomic, VMWeak) IBOutlet NSTextField *userGeneratedIdField;
@property (nonatomic, VMWeak) IBOutlet NSTextField *vmpModifierField;
@property (nonatomic, VMWeak) IBOutlet NSTextField *typeLabel;

- (void)drawInfoWith:(VMData*)data;

@end


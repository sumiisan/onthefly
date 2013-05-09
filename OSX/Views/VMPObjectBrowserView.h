//
//  ObjectBrowserView.h
//  OnTheFly
//
//  Created by  on 13/01/28.
//  Copyright (c) 2013 __MyCompanyName__. All rights reserved.
//

#import "VMPrimitives.h"
#import "VMDataTypes.h"
#import "VMPAnalyzer.h"

//--------------------- custom field editor -----------------------------
@interface VMPFieldEditor : NSTextView
@end

//--------------------- custom table cell -----------------------------

@interface VMPObjectCell : NSTextFieldCell
@end



/*---------------------------------------------------------------------------------
 *
 *
 *	Object Browser
 *
 *
 *---------------------------------------------------------------------------------*/

@interface VMPOutlineView : NSOutlineView
@end

@protocol ObjectBrowserGraphDelegate <NSObject>
- (void)drawGraphWith:(VMData*)data;
- (void)drawReportGraph:(VMHash*)report;
@end

@protocol ObjectBrowserInfoDelegate <NSObject>
- (void)drawInfoWith:(VMData*)data;
@end

@interface VMPObjectBrowserView : NSView
<NSOutlineViewDelegate, NSOutlineViewDataSource, NSWindowDelegate, VMPAnalyzerDelegate> {
@private
	BOOL					performingAutoComplete;
	BOOL					handlingCommand;
}

- (IBAction)clickOnRow:(id)sender;
- (IBAction)updateFilter:(id)sender;
- (void)findObjectById:(VMId*)dataId;

@property (assign) IBOutlet 	VMPOutlineView		*objectTreeView;
@property (assign) IBOutlet		NSSearchField		*searchField;
@property (VMNonatomic retain)	NSTreeNode			*objectRoot;

@property (nonatomic, retain)	NSString			*currentNonCompletedSearchString;
@property (nonatomic, retain)	NSString			*currentFilterString;

@property (nonatomic, assign)	VMHash				*songData;
@property (nonatomic, retain)	VMArray				*dataIdList;
@property (nonatomic, assign)	id <ObjectBrowserGraphDelegate>	graphDelegate;
@property (nonatomic, assign)	id <ObjectBrowserInfoDelegate>	infoDelegate;
@property (nonatomic, retain)   VMId				*lastSelectedId;
@property (nonatomic, retain)	VMPFieldEditor		*fieldEditor;

@end

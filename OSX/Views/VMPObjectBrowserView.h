//
//  ObjectBrowserView.h
//  OnTheFly
//
//  Created by  on 13/01/28.
//  Copyright (c) 2013 __MyCompanyName__. All rights reserved.
//

#import "VMPAnalyzer.h"

@class VMPCodeEditorView;

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

@protocol VMPObjectBrowserGraphDelegate <NSObject>
- (void)drawGraphWith:(VMData*)data;
- (void)drawReportGraph:(VMHash*)report;
@end

@protocol VMPObjectBrowserInfoDelegate <NSObject>
- (void)drawInfoWith:(VMData*)data;
@end

/*---------------------------------------------------------------------------------
 *
 *
 *	VMP Object Browser View:
 *
 *	it's actually the view controller for editors inside.
 *
 *---------------------------------------------------------------------------------*/

@interface VMPObjectBrowserView : NSView
<NSOutlineViewDelegate, NSOutlineViewDataSource, NSWindowDelegate, VMPAnalyzerDelegate> {
@private
				BOOL	performingAutoComplete;
				BOOL	handlingCommand;
	__weak		VMHash	*_songData;
}

- (IBAction)clickOnRow:(id)sender;
- (IBAction)updateFilter:(id)sender;
- (IBAction)songPlay:(id)sender;		//	defaults firstResponder

- (void)findObjectById:(VMId*)dataId;

@property (nonatomic, assign)	IBOutlet VMPOutlineView		*objectTreeView;
@property (nonatomic, assign)	IBOutlet NSSearchField		*searchField;
@property (nonatomic, assign)	IBOutlet VMPCodeEditorView	*codeEditorView;


@property (nonatomic, retain)	NSTreeNode			*objectRoot;

@property (nonatomic, retain)	NSString			*currentNonCompletedSearchString;
@property (nonatomic, retain)	NSString			*currentFilterString;

@property (weak)				VMHash				*songData;
@property (nonatomic, retain)	VMArray				*dataIdList;
@property (nonatomic, assign)	id <VMPObjectBrowserGraphDelegate>	graphDelegate;
@property (nonatomic, assign)	id <VMPObjectBrowserInfoDelegate>	infoDelegate;
@property (nonatomic, retain)   VMId				*lastSelectedId;
@property (nonatomic, retain)	VMPFieldEditor		*fieldEditor;		//	custom field editor for searchField

@end





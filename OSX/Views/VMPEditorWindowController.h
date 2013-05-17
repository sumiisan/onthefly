//
//  VMPEditorWindowController.h
//  OnTheFly
//
//  Created by  on 13/01/28.
//  Copyright (c) 2013 sumiisan. All rights reserved.
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

/*---------------------------------------------------------------------------------
 *
 *
 *	VMP Editor Window Controller
 *
 *	recently changed his job from NSView to NSWindowController.
 *	practically doin' nothing for his window :p
 *
 *---------------------------------------------------------------------------------*/
@class VMPObjectGraphView, VMPObjectInfoView;

@interface VMPEditorWindowController : NSWindowController
<NSOutlineViewDelegate, NSOutlineViewDataSource, NSWindowDelegate, VMPAnalyzerDelegate> {
@private
	BOOL		performingAutoComplete;
	BOOL		performingSearchFilter;
	BOOL		performingHistoryMove;
	BOOL		handlingCommand;
	__weak		VMHash	*_songData;
}


//	public methods
- (BOOL)findObjectById:(VMId*)dataId;	//	display object if found. does not make editor window key.

//	history
- (IBAction)historyButtonClicked:(id)sender;
- (IBAction)moveHistoryBack:(id)sender;		//	defaults first responder
- (IBAction)moveHistoryForward:(id)sender;	//	defaults first responder

//	actions below defaults first responder
- (IBAction)songPlay:(id)sender;
- (IBAction)focusTextSearchField:(id)sender;

//	generalized zoom action
- (IBAction)zoomIn:(id)sender;
- (IBAction)zoomOut:(id)sender;

//	used internal
- (IBAction)clickOnRow:(id)sender;
- (IBAction)updateFilter:(id)sender;
- (void)applicationDidLaunch;			//	initial setup after app is launched

//	public
@property (nonatomic, retain)	VMId			*currentDisplayingDataId;


//	views
@property (nonatomic, assign)	IBOutlet NSWindow				*editorWindow;
@property (nonatomic, assign)	IBOutlet VMPObjectGraphView		*graphView;
@property (nonatomic, assign)	IBOutlet VMPObjectInfoView		*infoView;

//	browser
@property (nonatomic, assign)	IBOutlet VMPOutlineView			*objectTreeView;
@property (nonatomic, assign)	IBOutlet NSSearchField			*searchField;
@property (nonatomic, assign)	IBOutlet VMPCodeEditorView		*codeEditorView;

//	referrer
@property (nonatomic, assign)	IBOutlet NSPopUpButton			*referrerPopup;
@property (nonatomic, assign)	IBOutlet NSMenu					*referrerMenu;

//	history
@property (nonatomic, assign)	IBOutlet NSSegmentedControl		*historyArrowButtons;


@end





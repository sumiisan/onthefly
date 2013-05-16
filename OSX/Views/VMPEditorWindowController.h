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
				BOOL	performingAutoComplete;
				BOOL	handlingCommand;
	__weak		VMHash	*_songData;
}


//	public methods
- (void)findObjectById:(VMId*)dataId;	//	display object if found. does not make editor window key.

//	data structure
@property (weak)				VMHash							*songData;

//	current item
@property (nonatomic, retain)   VMId							*lastSelectedId;


//	actions below defaults first responder
- (IBAction)songPlay:(id)sender;
- (IBAction)focusTextSearchField:(id)sender;

//	generalized history action
- (IBAction)moveHistoryBack:(id)sender;
- (IBAction)moveHistoryForward:(id)sender;

//	generalized zoom action
- (IBAction)zoomIn:(id)sender;
- (IBAction)zoomOut:(id)sender;

//	used internal
- (IBAction)clickOnRow:(id)sender;
- (IBAction)updateFilter:(id)sender;
- (void)applicationDidLaunch;			//	initial setup after app is launched


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



@end





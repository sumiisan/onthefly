//
//  VMPEditorWindowController.h
//  OnTheFly
//
//  Created by  on 13/01/28.
//  Copyright (c) 2013 sumiisan. All rights reserved.
//

#import "VMPAnalyzer.h"
#import "VMPGraph.h"

@class VMPCodeEditorView;

//--------------------- custom field editor -----------------------------
@interface VMPFieldEditor : NSTextView
@end

//--------------------- custom table cell -----------------------------

@interface VMPObjectCell : NSTextFieldCell
@end


//--------------------- split view with custom horiz. divider -----------------------------
@interface VMPEditorWindowSplitter : NSSplitView
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
<NSOutlineViewDelegate, NSOutlineViewDataSource, NSWindowDelegate, VMPAnalyzerDelegate, NSSplitViewDelegate> {
@private
	BOOL					performingAutoComplete;
	BOOL					performingSearchFilter;
	BOOL					performingHistoryMove;
	BOOL					handlingCommand;
	__unsafe_unretained		VMHash	*_songData;
}

//	accessor
//- (void)setSongData:(VMHash *)inSongData;	//	needed to reset songData from outside.
- (void)clearSongData;

//	public methods
- (BOOL)findObjectById:(VMId*)dataId action:(vmp_action)action;	//	display object if found. does not make editor window key.
- (VMArray*)referrerListForId:(VMId*)dataId;


//
- (IBAction)buttonClicked:(id)sender;


//	history
- (IBAction)historyButtonClicked:(id)sender;
- (IBAction)moveHistoryBack:(id)sender;		//	defaults first responder
- (IBAction)moveHistoryForward:(id)sender;	//	defaults first responder

//----	actions below defaults first responder ----
- (IBAction)songPlay:(id)sender;
- (IBAction)focusTextSearchField:(id)sender;

//	generalized zoom action
- (IBAction)zoomIn:(id)sender;
- (IBAction)zoomOut:(id)sender;

//----	used internal ----
- (IBAction)clickOnRow:(id)sender;
- (IBAction)updateFilter:(id)sender;


- (void)applicationDidLaunch;			//	initial setup after app is launched


//	public
@property (nonatomic, VMStrong)			VMId					*currentDisplayingDataId;
@property (nonatomic, assign)			BOOL					chaseSequence;
@property (nonatomic, assign)			BOOL					useStatisticScores;

//	views
@property (nonatomic, VMWeak)	IBOutlet NSWindow				*editorWindow;
@property (nonatomic, VMWeak)	IBOutlet VMPObjectGraphView		*graphView;
@property (nonatomic, VMWeak)	IBOutlet VMPObjectInfoView		*infoView;

//	browser
@property (nonatomic, VMWeak)	IBOutlet VMPOutlineView			*objectTreeView;
@property (nonatomic, VMWeak)	IBOutlet NSSearchField			*searchField;
@property (nonatomic, VMWeak)	IBOutlet VMPCodeEditorView		*codeEditorView;

//	referrer
@property (nonatomic, VMWeak)	IBOutlet NSPopUpButton			*referrerPopup;
@property (nonatomic, VMWeak)	IBOutlet NSMenu					*referrerMenu;

//	history
@property (nonatomic, VMWeak)	IBOutlet NSSegmentedControl		*historyArrowButtons;

//	splitter
@property (nonatomic, VMWeak)	IBOutlet VMPGraph				*editorSplitterView;
@property (nonatomic, VMWeak)	IBOutlet NSButton				*playButton;
@property (nonatomic, VMWeak)	IBOutlet NSTextField			*timeIndicator;
@property (nonatomic, VMWeak)	IBOutlet NSButton				*currentFragmentIdButton;
@property (nonatomic, VMWeak)	IBOutlet NSButton				*chaseToggleButton;
@property (nonatomic, VMWeak)	IBOutlet NSButton				*scoreToggleButton;

@end





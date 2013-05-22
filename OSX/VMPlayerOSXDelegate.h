//
//  VMPlayerOSXDelegate.h
//  VariableMusicPlayer
//
//  Created by cboy on 12/10/19.
//  Copyright 2012 sumiisan (aframasda.com). All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "VMPSongPlayer.h"
#import "VMPTrackView.h"
#import "VMPEditorWindowController.h"
#import "VMPVariablesPanelController.h"
#import "VMPLogView.h"

#define kDefaultVMSFileName @"default.vms"

@interface VMPlayerOSXDelegate : NSObject
	<NSApplicationDelegate, NSWindowDelegate> {
@private
    NSPersistentStoreCoordinator *__persistentStoreCoordinator;
    NSManagedObjectModel *__managedObjectModel;
    NSManagedObjectContext *__managedObjectContext;
}

@property (nonatomic, VMStrong)	NSURL				*currentDocumentURL;
@property (nonatomic, VMStrong)	VMLog				*systemLog;
@property (nonatomic, VMStrong)	VMLog				*userLog;
@property (nonatomic, VMStrong)	VMId				*lastSelectedDataId;
@property (nonatomic, assign, getter = isDocumentModified)	BOOL documentModified;

/*---------------------------------------------------------------------------------
 *
 *
 *	user interface
 *
 *
 *---------------------------------------------------------------------------------*/

//	transport panel
@property (nonatomic, VMWeak) IBOutlet NSPanel							*transportPanel;
@property (nonatomic, VMWeak) IBOutlet NSButton							*playStopButton;
@property (nonatomic, VMWeak) IBOutlet NSTextField						*timeIndicator;

//	object browser
@property (nonatomic, VMWeak) IBOutlet VMPEditorWindowController		*editorWindowController;

//	audioplayer track view
@property (nonatomic, VMWeak) IBOutlet NSPanel							*trackPanel;
@property (nonatomic, VMWeak) IBOutlet VMPTrackView						*trackView;

//	log panel
@property (nonatomic, VMWeak) IBOutlet NSPanel							*logPanel;
@property (nonatomic, VMWeak) IBOutlet VMPLogView						*logView;

//	variables panel
@property (nonatomic, VMStrong) VMPVariablesPanelController	*variablesPanelController;

/*---------------------------------------------------------------------------------
 
 methods
 
 ----------------------------------------------------------------------------------*/

+ (VMPlayerOSXDelegate*)singleton;
- (NSError*)openVMSDocumentFromURL:(NSURL *)documentURL;

/*---------------------------------------------------------------------------------
 
 actions
 
 ----------------------------------------------------------------------------------*/

//	document			defaults firstResponder
- (IBAction)saveDocument:(id)sender;
- (IBAction)saveDocumentAs:(id)sender;
- (IBAction)revertDocument:(id)sender;
- (IBAction)reloadDataFromEditor:(id)sender;
- (IBAction)openDocument:(id)sender;


//	player control		defaults firstResponder
- (IBAction)songPlay:(id)sender;
- (IBAction)songStop:(id)sender;
- (IBAction)songFadeout:(id)sender;
- (IBAction)songReset:(id)sender;
- (IBAction)playButtonClicked:(id)sender;

//	window
- (IBAction)showWindow:(id)sender;
- (IBAction)togglePanel:(id)sender;

//	log
- (IBAction)addUserLog:(id)sender;


/*---------------------------------------------------------------------------------
 
 persistent store
 
 ----------------------------------------------------------------------------------*/
@property (nonatomic, VMStrong, readonly) NSPersistentStoreCoordinator *persistentStoreCoordinator;
@property (nonatomic, VMStrong, readonly) NSManagedObjectModel *managedObjectModel;
@property (nonatomic, VMStrong, readonly) NSManagedObjectContext *managedObjectContext;

- (NSEntityDescription*)entityDescriptionFor:(NSString*)entityName;
- (void)saveManagedObjectContext;


@end

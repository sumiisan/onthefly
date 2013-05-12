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
#import "VMPObjectBrowserView.h"
#import "VMPObjectGraphView.h"
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

@property (nonatomic, retain)	NSURL				*currentDocumentURL;
@property (nonatomic, retain)	VMLog				*systemLog;
@property (nonatomic, retain)	VMLog				*userLog;
@property (nonatomic, retain)	VMId				*lastSelectedDataId;

/*---------------------------------------------------------------------------------
 *
 *
 *	user interface
 *
 *
 *---------------------------------------------------------------------------------*/

//	transport panel
@property (assign) IBOutlet NSPanel					*transportPanel;
@property (assign) IBOutlet NSButton				*playStopButton;
@property (assign) IBOutlet NSTextField				*timeIndicator;

//	object browser
@property (assign) IBOutlet NSWindow       			*objectBrowserWindow;
@property (assign) IBOutlet VMPObjectBrowserView	*objectBrowserView;
@property (assign) IBOutlet VMPObjectGraphView		*objectGraphView;
@property (assign) IBOutlet VMPObjectInfoView		*objectInfoView;

//	audioplayer track view
@property (assign) IBOutlet NSPanel					*trackPanel;
@property (assign) IBOutlet VMPTrackView       		*trackView;

//	log panel
@property (assign) IBOutlet NSPanel					*logPanel;
@property (assign) IBOutlet VMPLogView				*logView;

//	variables panel
@property (nonatomic, retain) VMPVariablesPanelController	*variablesPanelController;

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

//	log
- (IBAction)addUserLog:(id)sender;


/*---------------------------------------------------------------------------------
 
 persistent store
 
 ----------------------------------------------------------------------------------*/
@property (nonatomic, retain, readonly) NSPersistentStoreCoordinator *persistentStoreCoordinator;
@property (nonatomic, retain, readonly) NSManagedObjectModel *managedObjectModel;
@property (nonatomic, retain, readonly) NSManagedObjectContext *managedObjectContext;

- (NSEntityDescription*)entityDescriptionFor:(NSString*)entityName;
- (void)saveManagedObjectContext;


@end

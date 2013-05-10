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

@interface VMPlayerOSXDelegate : NSObject <NSApplicationDelegate,VMPAnalyzerDelegate,NSWindowDelegate> {
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
 
 persistent data
 
 ----------------------------------------------------------------------------------*/
@property (nonatomic, retain, readonly) NSPersistentStoreCoordinator *persistentStoreCoordinator;
@property (nonatomic, retain, readonly) NSManagedObjectModel *managedObjectModel;
@property (nonatomic, retain, readonly) NSManagedObjectContext *managedObjectContext;

- (NSEntityDescription*)entityDescriptionFor:(NSString*)entityName;

/*---------------------------------------------------------------------------------
 
 methods
 
 ----------------------------------------------------------------------------------*/

+ (VMPlayerOSXDelegate*)singleton;
- (NSError*)openVMSDocumentFromURL:(NSURL *)documentURL;

/*---------------------------------------------------------------------------------
 
 actions
 
 ----------------------------------------------------------------------------------*/

- (IBAction)saveAction:(id)sender;
- (IBAction)playStart:(id)sender;
- (IBAction)playStop:(id)sender;
- (IBAction)fadeoutAndStop:(id)sender;
- (IBAction)reset:(id)sender;
- (IBAction)playButtonClicked:(id)sender;
- (IBAction)routeStatics:(id)sender;
- (IBAction)revertDocumentToSaved:(id)sender;


@end

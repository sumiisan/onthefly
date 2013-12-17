//
//  VMPlayerOSXDelegate.m
//  VariableMusicPlayer
//
//  Created by cboy on 12/10/19.
//  Copyright 2012 sumiisan (aframasda.com). All rights reserved.
//

#define TEST 0


#import "VMPlayerOSXDelegate.h"
#import "VMPAudioPlayer.h"
#import "VMPAnalyzer.h"
#import "VMPNotification.h"
#import "VMPUserDefaults.h"
#import "VMException.h"
#import "VMPCodeEditorView.h"
#import "VMScoreEvaluator.h"
#import "VMPMacros.h"
#if TEST
#import "VMPTest.h"
#endif


#pragma mark VMPlayer OSX Delegate


@implementation VMPlayerOSXDelegate

VMPlayerOSXDelegate *OnTheFly_singleton_static_ = nil;
NSDictionary		*windowNames_static_ = nil;

/*
 app launch sequence:
 
 init(delegate)
 awakeFromNib
 applicationWillFinishLaunching
 applicationWillUpdate
 applicationDidUpdate
 applicationDidFinishLaunching
 applicationWillBecomeActive
 applicationDidBecomeActive
 applicationWillUpdate
 applicationDidUpdate
 */

+ (VMPlayerOSXDelegate*)singleton {
	return OnTheFly_singleton_static_;
}

- (id)init {
	self = [super init];
	if(! self )return nil;
    
    OnTheFly_singleton_static_ = self;
	_systemLog	= [[VMLog alloc] initWithOwner:VMLogOwner_System managedObjectContext:nil];
	_userLog	= [[VMLog alloc] initWithOwner:VMLogOwner_User managedObjectContext:[self managedObjectContext]];
	
	NSString *urlString = [[NSUserDefaults standardUserDefaults] stringForKey:VMPUserDefaultsKey_LastDocumentURL];
	if ( urlString )
		self.currentDocumentURL = AutoRelease([[NSURL alloc] initFileURLWithPath:urlString] );
	
	[self.editorWindowController.window setAllowsConcurrentViewDrawing:NO];		//test 131126
	return self;
}


- (void)awakeFromNib {
	DEFAULTSONGPLAYER.trackView = _trackView;
	[self restoreWindows];
}


- (void)dealloc {
	[DEFAULTSONGPLAYER coolDown];
	VMNullify(editorWindowController);
	VMNullify(variablesPanelController);
	Release( _systemLog );
	Release( _userLog );
	VMNullify(currentDocumentURL);
	VMNullify(lastSelectedDataId);
    Release( __managedObjectContext );
    Release( __persistentStoreCoordinator );
    Release( __managedObjectModel );
    Dealloc( super );;
}

- (void)mainRunLoop {
	if ( DEFAULTSONGPLAYER.isRunning ) {
		VMTime t = DEFAULTSONGPLAYER.currentTime;
		VMString *timeString = [NSString stringWithFormat:@"%02d:%02d'%02d\"%02d",
								(int)(t/3600),((int)t/60)%60,(int)t%60,((int)(t*100))%100 ];
		if ( _transportPanel.isVisible ) {
			_playStopButton.state = 1;
			_timeIndicator.stringValue = timeString;
		}
		if ( _editorWindowController.window.isVisible ) {
			_editorWindowController.timeIndicator.stringValue = timeString;
			_editorWindowController.playButton.state = 1;
		}
	} else {
		_playStopButton.state = 0;
		_editorWindowController.playButton.state = 0;
	}
	[self performSelector:@selector(mainRunLoop) withObject:nil afterDelay:0.01];
}

#pragma mark -
#pragma mark notification - selection

- (void)dataSelected:(NSNotification*)notification {
	self.lastSelectedDataId = (notification.userInfo)[@"id"];
}

#pragma mark -
#pragma mark accessor

- (BOOL)isDocumentModified {
	//	expand here when we have temporary song data
	return ( self.editorWindowController.codeEditorView.sourceCodeModified );
}

- (void)setDocumentModified:(BOOL)documentModified {
	self.editorWindowController.codeEditorView.sourceCodeModified = documentModified;
}


#pragma mark -
#pragma mark * user actions *
#pragma mark -
#pragma mark action - player

- (IBAction)songPlay:(id)sender {
	[DEFAULTSONGPLAYER stop];
    [DEFAULTSONGPLAYER start];
	[self.logView locateLogWithIndex:-1 ofSource:VMLogOwner_MediaPlayer];
}

- (IBAction)songStop:(id)sender {
    [DEFAULTSONGPLAYER stop];
}

- (IBAction)songFadeout:(id)sender {
    [DEFAULTSONGPLAYER fadeoutAndStop:kDefaultFadeoutTime];
}

- (IBAction)songReset:(id)sender {
//	DEFAULTEVALUATOR.timeManager.shutdownTime = nil;
	[DEFAULTSONGPLAYER stopAndDisposeQueue];
	[DEFAULTSONG reset];
	[DEFAULTEVALUATOR reset];
//	[self deleteUserSavedSong];
//	[self loadSongFromVMS];
//	[[NSNotificationCenter defaultCenter] postNotificationName:PLAYERSTARTED_NOTIFICATION object:self];
    [DEFAULTSONGPLAYER reset];
}

- (IBAction)playButtonClicked:(id)sender {
	switch ( DEFAULTSONGPLAYER.isRunning ) {
		case YES:
			[DEFAULTSONGPLAYER fadeoutAndStop:0.2];
			break;
		case NO:
			[DEFAULTSONGPLAYER start];
			[self.logView locateLogWithIndex:-1 ofSource:VMLogOwner_MediaPlayer];
			break;
	}
}

#pragma mark action - window
- (void)restoreWindows {
	NSArray *openedWindows = [[NSUserDefaults standardUserDefaults] stringArrayForKey:VMPUserDefaultsKey_OpenedWindows];
//	NSLog(@"restore windows:%@", openedWindows );
	for( NSString *windowName in openedWindows )
		[self showWindowByName:windowName];
}

- (void)showWindowByName:(NSString*)name {
	if ( [name isEqualToString:@"Transport"] )			[_transportPanel makeKeyAndOrderFront:self ];
	if ( [name isEqualToString:@"Object Browser"] )		[_editorWindowController.window makeKeyAndOrderFront:self ];
	if ( [name isEqualToString:@"Statistics"] )			[DEFAULTANALYZER.statisticsWindow makeKeyAndOrderFront:self ];
	if ( [name isEqualToString:@"Tracks"] )				[_trackPanel makeKeyAndOrderFront:self ];
	if ( [name isEqualToString:@"Log"] )				[_logPanel makeKeyAndOrderFront:self ];

	if ( [name isEqualToString:@"Variables"] ) {
		if ( ! self.variablesPanelController )
			self.variablesPanelController = AutoRelease([[VMPVariablesPanelController alloc]
											  initWithWindowNibName:@"VMPVariablesPanel"] );
		[self.variablesPanelController.window makeKeyAndOrderFront:self];
	}

	VMArray *openedWindows = [VMArray arrayWithArray:
							  [[NSUserDefaults standardUserDefaults] stringArrayForKey:VMPUserDefaultsKey_OpenedWindows]];
	[openedWindows pushUnique:name];
	[[NSUserDefaults standardUserDefaults] setObject:openedWindows.array forKey:VMPUserDefaultsKey_OpenedWindows];
}

- (void)hideWindowByName:(VMString*)name {
	if ( [name isEqualToString:@"Transport"] )			[_transportPanel close];
	if ( [name isEqualToString:@"Object Browser"] )		[_editorWindowController.window close];
	if ( [name isEqualToString:@"Statistics"] )			[DEFAULTANALYZER.statisticsWindow close ];
	if ( [name isEqualToString:@"Tracks"] )				[_trackPanel  close];
	if ( [name isEqualToString:@"Log"] )				[_logPanel close];
	if ( [name isEqualToString:@"Variables"] ) if ( self.variablesPanelController ) [self.variablesPanelController.window close];
	VMArray *openedWindows = [VMArray arrayWithArray:
							  [[NSUserDefaults standardUserDefaults] stringArrayForKey:VMPUserDefaultsKey_OpenedWindows]];
	[openedWindows deleteItemWithValue:name];
	[[NSUserDefaults standardUserDefaults] setObject:openedWindows.array forKey:VMPUserDefaultsKey_OpenedWindows];

}

- (void)setWindowNames {
	Release(windowNames_static_);
	windowNames_static_ = @{
						 (_transportPanel ? _transportPanel.identifier: @"dummy1"):@"Transport",
	   (_editorWindowController.window ? _editorWindowController.window.identifier : @"dummy2" ):@"Object Browser",
	   ( DEFAULTANALYZER.statisticsWindow ? DEFAULTANALYZER.statisticsWindow.identifier : @"dummy3" ) :@"Statistics",
	   (_trackPanel ? _trackPanel.identifier : @"dummy4" ) :@"Tracks",
	   (_variablesPanelController.window ? _variablesPanelController.window.identifier : @"dummy5" ):@"Variables",
	   (_logPanel ? _logPanel.identifier : @"dummy6" ) :@"Log" };
	Retain( windowNames_static_ );
}

- (NSString*)nameOfWindow:(NSWindow*)window {
	[self setWindowNames];
	return windowNames_static_[window.identifier];
}


- (BOOL)showLogPanelIfNewSystemLogsAreAdded {
	if ( _systemLog.count > numberOfShownSystemLogItems ) {
		numberOfShownSystemLogItems = _systemLog.count;
		[VMPNotificationCenter postNotificationName:VMPNotificationLogAdded
											 object:self
										   userInfo:@{@"owner":@(VMLogOwner_System) }];
		return YES;
	}
	
	return NO;
}


- (IBAction)showWindow:(id)sender {
	if (((NSView*)sender).tag == 505 ) {
		//	SOS !
		[VMException alert:@"No help available yet. Maybe you have more luck at https://github.com/sumiisan/onthefly/wiki"];
//		[self showWindowByName:@"Help"];
	}

	VMString *windowName = ClassMatch(sender, NSMenuItem) ? ClassCast(sender, NSMenuItem).title : ClassCast(sender, NSButton).title;
	[self showWindowByName:windowName];
}

- (IBAction)togglePanel:(id)sender {
	VMString *windowName = ClassMatch(sender, NSMenuItem) ? ClassCast(sender, NSMenuItem).title : ClassCast(sender, NSButton).title;
	VMArray *openedWindows = [VMArray arrayWithArray:
							  [[NSUserDefaults standardUserDefaults] stringArrayForKey:VMPUserDefaultsKey_OpenedWindows]];
	if([openedWindows position:windowName] >= 0) {
		[self hideWindowByName:windowName];
	} else {
		[self showWindowByName:windowName];
	}
	
	
}

#pragma mark action - log

//
//	user log
//
- (IBAction)addUserLog:(id)sender {
	//	this message is sent from menu to first responder
	//	we could also handle in each active window
	[self.userLog addUserLogWithText:@"" dataId:self.lastSelectedDataId];
	[VMPNotificationCenter postNotificationName:VMPNotificationLogAdded
										 object:self
									   userInfo:@{@"owner":@(VMLogOwner_User) }];
}



#pragma mark action - load, reload(from editor), revert and save vms

- (IBAction)revertDocument:(id)sender {
	[DEFAULTSONGPLAYER stopAndDisposeQueue];
    [self openVMSDocumentFromURL:self.currentDocumentURL];
    DEFAULTSONGPLAYER.song = DEFAULTSONG;

	[self resetEverythingAfterDataIsLoaded];
}

- (IBAction)reloadDataFromEditor:(id)sender {
	[DEFAULTSONGPLAYER stopAndDisposeQueue];
	NSError *error = nil;
	if ( ![DEFAULTSONG readFromString:self.editorWindowController.codeEditorView.textView.string error:&error] )
		[self showLogPanelIfNewSystemLogsAreAdded];
	
	[self resetEverythingAfterDataIsLoaded];
}

- (IBAction)saveDocument:(id)sender {
	NSError *error = nil;
	DEFAULTSONG.vmsData = self.editorWindowController.codeEditorView.textView.string;
	[self saveVMSDocumentToURL:self.currentDocumentURL];	//	FIRST! save anyway.
	[DEFAULTSONGPLAYER stopAndDisposeQueue];				//	NEXT:  stopping audio can cause error, hang of device, etc.
															//	LAST:  validate vms, it can produce bunch of errors.
	//	set editor's songData to nil, because it attempts to display deallocated frags on json parse error.
	[self.editorWindowController clearSongData];
	if( [DEFAULTSONG readFromString:nil error:&error] )
		[self showLogPanelIfNewSystemLogsAreAdded];
	
	self.documentModified = NO;
	[self resetEverythingAfterDataIsLoaded];
}

- (IBAction)saveDocumentAs:(id)sender {
	[DEFAULTSONGPLAYER stopAndDisposeQueue];
	[VMException alert:@"Not implemented yet!"];
}


- (IBAction)closeDocument:(id)sender {
	if ( self.isDocumentModified ) {
		if ( [VMException ensure:@"%@ has unsaved changes. Close anyway ?", DEFAULTSONG.songName] == 1 ) return;
	}
	
	[DEFAULTSONGPLAYER stopAndDisposeQueue];
	[DEFAULTSONG clear];
}

- (IBAction)openDocument:(id)sender {
	[self closeDocument:self];
	
	if ( self.isDocumentModified ) {
		if ( [VMException ensure:@"%@ has unsaved changes. Close anyway ?", DEFAULTSONG.songName] == 1 ) return;
	}
	//	TODO: we might use a document controller to populate 'recent files' menu.
//	NSDocumentController *dc = [NSDocumentController sharedDocumentController];
	
	NSOpenPanel *op = [NSOpenPanel openPanel];
	op.canChooseFiles = YES;
	op.canCreateDirectories = NO;
	op.canChooseDirectories = YES;
	op.allowsMultipleSelection = NO;
	op.allowedFileTypes = @[@"vms"];
	
	if( [op runModal] == NSOKButton ) {
		NSURL *url = (op.URLs)[0];
		
		NSError *err = [self openVMSDocumentFromURL:url];
		if( !err ) {
			[self resetEverythingAfterDataIsLoaded];			
			self.currentDocumentURL = url;
			[[NSUserDefaults standardUserDefaults] setValue:[url path] forKey:VMPUserDefaultsKey_LastDocumentURL];
		}
	}
}

- (void)resetEverythingAfterDataIsLoaded {
	DEFAULTSONGPLAYER.song = DEFAULTSONG;
	[VMPNotificationCenter postNotificationName:VMPNotificationVMSDataLoaded object:self userInfo:nil];
}

#pragma mark -
#pragma mark method - load and save VMSong
//	TODO: handle error

- (NSError*)openVMSDocumentFromURL:(NSURL *)documentURL {
	NSError	*error = nil;
	if( [DEFAULTSONG readFromURL:documentURL error:&error] ) {
		[VMPNotificationCenter postNotificationName:VMPNotificationVMSDataLoaded object:self userInfo:nil];
	} else {
		//	handle error
		[VMException logError:@"Failed to load VMS" format:@"URL:%@ Error:%@ Reason:%@",
		 [documentURL absoluteString], error.localizedDescription, error.localizedFailureReason
		 ];
	}
	return error;
}

- (NSError*)saveVMSDocumentToURL:(NSURL *)documentURL {
	NSError	*error = nil;
	if ( [DEFAULTSONG saveToURL:documentURL error:&error] ) {
		[VMPNotificationCenter postNotificationName:VMPNotificationVMSDataLoaded object:self userInfo:nil];
	} else {
		//	handle error
		[VMException logError:@"Failed to load VMS" format:@"URL:%@ Error:%@ Reason:%@",
		 [documentURL absoluteString], error.localizedDescription, error.localizedFailureReason
		 ];
	}
	return error;
}



#pragma mark -
#pragma mark application delegates

//
//  app delegate
//

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
#if TEST
	[VMPTest test];
#endif
    // Startup!
	if ( self.currentDocumentURL )
		[self revertDocument:self];	//	load
	//
	[DEFAULTSONGPLAYER warmUp];
	[_editorWindowController applicationDidLaunch];
	DEFAULTSONG.showReport.current = @YES;
	[self performSelector:@selector(mainRunLoop) withObject:nil afterDelay:0.5];
	
	[self showLogPanelIfNewSystemLogsAreAdded];
	[VMPNotificationCenter addObserver:self selector:@selector(someWindowWillClose:) name:NSWindowWillCloseNotification object:nil];
	[VMPNotificationCenter addObserver:self selector:@selector(dataSelected:) name:VMPNotificationFragmentSelected object:nil];
}

- (void)applicationWillFinishLaunching:(NSNotification *)notification {
	
}

- (BOOL) applicationShouldTerminateAfterLastWindowClosed: (NSApplication *) theApplication {
    return NO;
}




- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
	
	if ( self.isDocumentModified ) {
		if ( [VMException ensure:@"%@ has unsaved changes. Quit anyway ?", DEFAULTSONG.songName] == 1 ) return NO;
	}
	
	
    // Save changes in the application's managed object context before the application terminates.
	
    if (!__managedObjectContext) {
        return NSTerminateNow;
    }
	
    if (![[self managedObjectContext] commitEditing]) {
        NSLog(@"%@:%@ unable to commit editing to terminate", [self class], NSStringFromSelector(_cmd));
        return NSTerminateCancel;
    }
	
    if (![[self managedObjectContext] hasChanges]) {
        return NSTerminateNow;
    }
	
    NSError *error = nil;
    if (![[self managedObjectContext] save:&error]) {
		
        // Customize this code block to include application-specific recovery steps.
        BOOL result = [sender presentError:error];
        if (result) {
            return NSTerminateCancel;
        }
		
        NSString *question = NSLocalizedString(@"Could not save changes while quitting. Quit anyway?", @"Quit without saves error question message");
        NSString *info = NSLocalizedString(@"Quitting now will lose any changes you have made since the last successful save", @"Quit without saves error question info");
        NSString *quitButton = NSLocalizedString(@"Quit anyway", @"Quit anyway button title");
        NSString *cancelButton = NSLocalizedString(@"Cancel", @"Cancel button title");
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:question];
        [alert setInformativeText:info];
        [alert addButtonWithTitle:quitButton];
        [alert addButtonWithTitle:cancelButton];
		
        NSInteger answer = [alert runModal];
        Release(alert);
        alert = nil;
        
        if (answer == NSAlertAlternateReturn) {
            return NSTerminateCancel;
        }
    }
	
	[VMPNotificationCenter removeObserver:self];
	
    return NSTerminateNow;
}


#pragma mark window delegates / notification
- (void)windowDidResize:(NSNotification *)notification {
	[self.trackView reLayout];
}

- (void)someWindowWillClose:(NSNotification*)notification {	
	VMArray *openedWindows = [VMArray arrayWithArray:
							  [[NSUserDefaults standardUserDefaults] stringArrayForKey:VMPUserDefaultsKey_OpenedWindows]];
	[openedWindows deleteItemWithValue:[self nameOfWindow:notification.object]];
//	NSLog(@"Close %@ : opened windows %@", [self nameOfWindow:notification.object], openedWindows);
	[[NSUserDefaults standardUserDefaults] setObject:openedWindows.array forKey:VMPUserDefaultsKey_OpenedWindows];
}

#pragma mark -
#pragma mark menu validation

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
	SEL action = menuItem.action;
	
	if ( action == @selector(showWindow:)) {
		if ( [menuItem.title isEqualToString:@"Statistics"] ) {
			if ( ! DEFAULTANALYZER.report ) return NO;
		}
	}
	
	if ( action == @selector(addUserLog:)) {
		if ( self.lastSelectedDataId.length == 0 ) return NO;
	}
	
	if ( action == @selector(reloadDataFromEditor:)) {
		if ( ! self.currentDocumentURL ) return NO;
		if ( self.editorWindowController.codeEditorView.textView.string.length == 0 ) return NO;
	}
	
	if ( action == @selector(saveDocument:)
		|| action == @selector(saveDocumentAs:)
		|| action == @selector(revertDocument:) ) {
		return ( self.currentDocumentURL != nil );
	}
	
	//	the default
	return YES;
}


#pragma mark -
#pragma mark core data stuff

/*---------------------------------------------------------------------------------
 
 core data stuff
 
 ----------------------------------------------------------------------------------*/

/**
 Returns the directory the application uses to store the Core Data store file. This code uses a directory named "OnTheFly" in the user's Library directory.
 */
- (NSURL *)applicationFilesDirectory {
	
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *libraryURL = [[fileManager URLsForDirectory:NSLibraryDirectory inDomains:NSUserDomainMask] lastObject];
    return [libraryURL URLByAppendingPathComponent:@"OnTheFly"];
}

/**
 Creates if necessary and returns the managed object model for the application.
 */
- (NSManagedObjectModel *)managedObjectModel {
    if (__managedObjectModel) {
        return __managedObjectModel;
    }
	
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"VMPEditor" withExtension:@"momd"];
    __managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    return __managedObjectModel;
}

/**
 Returns the persistent store coordinator for the application. This implementation creates and return a coordinator, having added the store for the application to it. (The directory for the store is created, if necessary.)
 */
- (NSPersistentStoreCoordinator *) persistentStoreCoordinator {
    if (__persistentStoreCoordinator) {
        return __persistentStoreCoordinator;
    }
	
    NSManagedObjectModel *mom = [self managedObjectModel];
    if (!mom) {
        NSLog(@"%@:%@ No model to generate a store from", [self class], NSStringFromSelector(_cmd));
        return nil;
    }
	
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *applicationFilesDirectory = [self applicationFilesDirectory];
    NSError *error = nil;
    
    NSDictionary *properties = [applicationFilesDirectory resourceValuesForKeys:@[NSURLIsDirectoryKey] error:&error];
	
    if (!properties) {
        BOOL ok = NO;
        if ([error code] == NSFileReadNoSuchFileError) {
            ok = [fileManager createDirectoryAtPath:[applicationFilesDirectory path] withIntermediateDirectories:YES attributes:nil error:&error];
        }
        if (!ok) {
            [[NSApplication sharedApplication] presentError:error];
            return nil;
        }
    }
    else {
        if ([properties[NSURLIsDirectoryKey] boolValue] != YES) {
            // Customize and localize this error.
            NSString *failureDescription = [NSString stringWithFormat:@"Expected a folder to store application data, found a file (%@).", [applicationFilesDirectory path]];
            
            NSMutableDictionary *dict = [NSMutableDictionary dictionary];
            [dict setValue:failureDescription forKey:NSLocalizedDescriptionKey];
            error = [NSError errorWithDomain:@"YOUR_ERROR_DOMAIN" code:101 userInfo:dict];
            
            [[NSApplication sharedApplication] presentError:error];
            return nil;
        }
    }
    
    NSURL *url = [applicationFilesDirectory URLByAppendingPathComponent:@"OnTheFly.storedata"];
    __persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:mom];
    if (![__persistentStoreCoordinator addPersistentStoreWithType:NSXMLStoreType configuration:nil URL:url options:nil error:&error]) {
        [[NSApplication sharedApplication] presentError:error];
        Release(__persistentStoreCoordinator);
		__persistentStoreCoordinator = nil;
        return nil;
    }
	
    return __persistentStoreCoordinator;
}

/**
 Returns the managed object context for the application (which is already
 bound to the persistent store coordinator for the application.)
 */
- (NSManagedObjectContext *) managedObjectContext {
    if (__managedObjectContext) {
        return __managedObjectContext;
    }
	
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (!coordinator) {
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        [dict setValue:@"Failed to initialize the store" forKey:NSLocalizedDescriptionKey];
        [dict setValue:@"There was an error building up the data file." forKey:NSLocalizedFailureReasonErrorKey];
        NSError *error = [NSError errorWithDomain:@"YOUR_ERROR_DOMAIN" code:9999 userInfo:dict];
        [[NSApplication sharedApplication] presentError:error];
        return nil;
    }
    __managedObjectContext = [[NSManagedObjectContext alloc] init];
    [__managedObjectContext setPersistentStoreCoordinator:coordinator];
	
    return __managedObjectContext;
}

/**
 Returns the NSUndoManager for the application. In this case, the manager returned is that of the managed object context for the application.
 */
- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)window {
    return [[self managedObjectContext] undoManager];
}


- (NSEntityDescription*)entityDescriptionFor:(NSString*)entityName {
	return [[self managedObjectModel] entitiesByName][entityName];
}

/**
 Performs the save action for the application, which is to send the save: message to the application's managed object context. Any encountered errors are presented to the user.
 */
- (void)saveManagedObjectContext {
    NSError *error = nil;
    
    if (![[self managedObjectContext] commitEditing]) {
        NSLog(@"%@:%@ unable to commit editing before saving", [self class], NSStringFromSelector(_cmd));
    }
	
    if (![[self managedObjectContext] save:&error]) {
        [[NSApplication sharedApplication] presentError:error];
    }
}




@end

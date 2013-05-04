//
//  VariableMediaPlayerAppDelegate.m
//  VariableMusicPlayer
//
//  Created by cboy on 12/10/19.
//  Copyright 2012 sumiisan@gmail.com. All rights reserved.
//

#import "VMPlayerOSXDelegate.h"
#import "VMPAudioPlayer.h"
#import "VMPAnalyzer.h"

VMPlayerOSXDelegate *variableMediaPlayer_singleton__ = nil;

@implementation VMPlayerOSXDelegate

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
	return variableMediaPlayer_singleton__;
}

- (id)init {
	self = [super init];
	if(! self )return nil;
    
    variableMediaPlayer_singleton__ = self;
	
    NSURL *vmsURL =	[[[NSURL alloc] initFileURLWithPath:[NSString stringWithFormat:@"%@/%@/%@",
														[[NSBundle mainBundle] resourcePath],
														kDefaultVMDirectory,
														kDefaultVMSFileName]
										   isDirectory:NO] autorelease];

    [self openVMSDocumentFromURL:vmsURL];
    DEFAULTSONGPLAYER.song = DEFAULTSONG;
	return self;
}

- (void)awakeFromNib {
	DEFAULTSONGPLAYER.trackView = _trackView;
	_objectBrowserView.songData = DEFAULTSONG.songData;
	
	[self showWindowByName:@"Variables"];	//	open it by default
	//	init popup
	//	NSMenu *menu = [
	
}

- (void)dealloc {
	[DEFAULTSONGPLAYER coolDown];
	self.variablesPanelController = nil;
    [__managedObjectContext release];
    [__persistentStoreCoordinator release];
    [__managedObjectModel release];
    [super dealloc];
}

- (void)mainRunLoop {
	_playStopButton.state = DEFAULTSONGPLAYER.isRunning ? 1 : 0;
	VMTime t = DEFAULTSONGPLAYER.currentTime;
	_timeIndicator.stringValue = [NSString stringWithFormat:@"%02d:%02d'%02d\"%1d",
								 (int)(t/3600),((int)t/60)%60,(int)t%60,((int)(t*10))%10 ];
	t = DEFAULTSONGPLAYER.nextCueTime;
	_nextCueTimeIndicator.stringValue = [NSString stringWithFormat:@"%02d:%02d'%02d\"%1d",
								 (int)(t/3600),((int)t/60)%60,(int)t%60,((int)(t*10))%10 ];
	
	[self performSelector:@selector(mainRunLoop) withObject:nil afterDelay:0.1];
}


#pragma mark -
#pragma mark application delegates

//
//  app delegate
//

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Startup!
	[DEFAULTSONGPLAYER warmUp];
	_objectBrowserView.graphDelegate = _objectGraphView;
	_objectBrowserView.infoDelegate  = _objectInfoView;
	[DEFAULTSONG showReport:YES];	//	debug report ON
	[self performSelector:@selector(mainRunLoop) withObject:nil afterDelay:0.5];
}

- (void)applicationWillFinishLaunching:(NSNotification *)notification {
	
}

- (BOOL) applicationShouldTerminateAfterLastWindowClosed: (NSApplication *) theApplication {
    return NO;
}



- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
	
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
        [alert release];
        alert = nil;
        
        if (answer == NSAlertAlternateReturn) {
            return NSTerminateCancel;
        }
    }
	
    return NSTerminateNow;
}


#pragma mark window delegates
- (void)windowDidResize:(NSNotification *)notification {
	[self.trackView reLayout];
}


#pragma mark -
#pragma mark action


//
//  menu item
//
- (IBAction)playStart:(id)sender {
	[DEFAULTSONGPLAYER stop];
    [DEFAULTSONGPLAYER start];
	[self.logView locateLogWithIndex:-1 ofSource:VMPLogViewSource_Player];
}

- (IBAction)playStop:(id)sender {
    [DEFAULTSONGPLAYER stop];
}

- (IBAction)fadeoutAndStop:(id)sender {
    [DEFAULTSONGPLAYER fadeoutAndStop:kDefaultFadeoutTime];
}

- (IBAction)reset:(id)sender {
    [DEFAULTSONGPLAYER reset];
}

- (void)showWindowByName:(NSString*)name {
	if ( [name isEqualToString:@"Transport"] ) {
		[_transportPanel makeKeyAndOrderFront:self ];
	}
	if ( [name isEqualToString:@"Object Browser"] ) {
		[_objectBrowserWindow makeKeyAndOrderFront:self ];
	}
	if ( [name isEqualToString:@"Statistics"] ) {
		[DEFAULTANALYZER.reportWindow makeKeyAndOrderFront:self ];
	}
	if ( [name isEqualToString:@"Tracks"] ) {
		[_trackPanel makeKeyAndOrderFront:self ];
	}
	if ( [name isEqualToString:@"Variables"] ) {
		if ( ! self.variablesPanelController )
			self.variablesPanelController = [[[VMPVariablesPanelController alloc]
											  initWithWindowNibName:@"VMPVariablesPanel"] autorelease];
		[self.variablesPanelController.window makeKeyAndOrderFront:self];
	}
	if ( [name isEqualToString:@"Log"] ) {
		[_logPanel makeKeyAndOrderFront:self ];
	}
}

- (IBAction)showWindow:(id)sender {
	if ( [sender isKindOfClass:[NSMenuItem class]] )
		[self showWindowByName: ((NSMenuItem*)sender).title ];
	if ( [sender isKindOfClass:[NSButton class]] )
		[self showWindowByName: ((NSButton*)sender).title ];
}


//	unused
- (IBAction)routeStatics:(id)sender {
	DEFAULTANALYZER.delegate = self;
	[DEFAULTSONGPLAYER fadeoutAndStop:5.];
    [DEFAULTANALYZER routeStatistic:/*[objectBrowserView currentObject]*/[DEFAULTSONG data:DEFAULTSONG.defaultCueId] numberOfIterations:20 until:nil];
}

//	unused
- (void)analysisFinished:(VMHash *)report {
	//	nothing to do here
}

//
//	playback control
//

- (IBAction)playButtonClicked:(id)sender {
	switch ( DEFAULTSONGPLAYER.isRunning ) {
	case YES:
		[DEFAULTSONGPLAYER fadeoutAndStop:0.2];
		break;
	case NO:
		[DEFAULTSONGPLAYER start];
			[self.logView locateLogWithIndex:-1 ofSource:VMPLogViewSource_Player];
		break;
	}
}

#pragma mark -
#pragma mark loading vms document

- (NSError*)openVMSDocumentFromURL:(NSURL *)documentURL {
	NSError	*err = nil;
	[DEFAULTSONG readFromURL:documentURL error:&err];
	return err;
}

#pragma mark -
#pragma mark saving vms document (unimplemented)

/**
    Performs the save action for the application, which is to send the save: message to the application's managed object context. Any encountered errors are presented to the user.
 */
- (IBAction) saveAction:(id)sender {
    NSError *error = nil;
    
    if (![[self managedObjectContext] commitEditing]) {
        NSLog(@"%@:%@ unable to commit editing before saving", [self class], NSStringFromSelector(_cmd));
    }

    if (![[self managedObjectContext] save:&error]) {
        [[NSApplication sharedApplication] presentError:error];
    }
}




#pragma mark -
#pragma mark core data stuff (unused)

//
//  core data stuff -- unused
//

/**
 Returns the directory the application uses to store the Core Data store file. This code uses a directory named "VariableMediaPlayer" in the user's Library directory.
 */
- (NSURL *)applicationFilesDirectory {
	
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *libraryURL = [[fileManager URLsForDirectory:NSLibraryDirectory inDomains:NSUserDomainMask] lastObject];
    return [libraryURL URLByAppendingPathComponent:@"VariableMediaPlayer"];
}

/**
 Creates if necessary and returns the managed object model for the application.
 */
- (NSManagedObjectModel *)managedObjectModel {
    if (__managedObjectModel) {
        return __managedObjectModel;
    }
	
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"VariableMediaPlayer" withExtension:@"momd"];
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
    
    NSDictionary *properties = [applicationFilesDirectory resourceValuesForKeys:[NSArray arrayWithObject:NSURLIsDirectoryKey] error:&error];
	
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
        if ([[properties objectForKey:NSURLIsDirectoryKey] boolValue] != YES) {
            // Customize and localize this error.
            NSString *failureDescription = [NSString stringWithFormat:@"Expected a folder to store application data, found a file (%@).", [applicationFilesDirectory path]];
            
            NSMutableDictionary *dict = [NSMutableDictionary dictionary];
            [dict setValue:failureDescription forKey:NSLocalizedDescriptionKey];
            error = [NSError errorWithDomain:@"YOUR_ERROR_DOMAIN" code:101 userInfo:dict];
            
            [[NSApplication sharedApplication] presentError:error];
            return nil;
        }
    }
    
    NSURL *url = [applicationFilesDirectory URLByAppendingPathComponent:@"VariableMediaPlayer.storedata"];
    __persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:mom];
    if (![__persistentStoreCoordinator addPersistentStoreWithType:NSXMLStoreType configuration:nil URL:url options:nil error:&error]) {
        [[NSApplication sharedApplication] presentError:error];
        [__persistentStoreCoordinator release], __persistentStoreCoordinator = nil;
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
@end

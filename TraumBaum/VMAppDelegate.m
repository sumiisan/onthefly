//
//  VMAppDelegate.m
//  Traumbaum
//
//  Created by sumiisan on 2013/03/22.
//
//


#import "VMAppDelegate.h"

#import "VMViewController.h"
#import "VMPAudioPlayer.h"
#import "VMPSongPlayer.h"
#import "VMPTrackView.h"
#import "VMScoreEvaluator.h"
#import "VMTraumbaumUserDefaults.h"
#import "VMVmsarcManager.h"

/*---------------------------------------------------------------------------------
 *
 *
 *	handle audio route change	--	 depreciated
 *
 *
 *---------------------------------------------------------------------------------*/

/*
void audioRouteChangeListenerCallback (
									   void                      *inUserData,
									   AudioSessionPropertyID    inPropertyID,
									   UInt32                    inPropertyValueSize,
									   const void                *inPropertyValue
									   ) {
    
    // ensure that this callback was invoked for a route change
    if (inPropertyID != kAudioSessionProperty_AudioRouteChange) return;
	
    if ( DEFAULTSONGPLAYER.isRunning ) {
        // Determines the reason for the route change, to ensure that it is not
        //      because of a category change.
        CFDictionaryRef routeChangeDictionary = inPropertyValue;
        CFNumberRef routeChangeReasonRef =
			CFDictionaryGetValue ( routeChangeDictionary, CFSTR (kAudioSession_AudioRouteChangeKey_Reason) );
		
        SInt32 routeChangeReason;
        CFNumberGetValue ( routeChangeReasonRef, kCFNumberSInt32Type, &routeChangeReason );
        if (routeChangeReason == kAudioSessionRouteChangeReason_OldDeviceUnavailable) {
			[[VMAppDelegate defaultAppDelegate] stop];
			NSLog(@"kAudioSessionRouteChangeReason_OldDeviceUnavailable");

        }
    }
}
 */


/*---------------------------------------------------------------------------------
 *
 *
 *	VMAppDelegate
 *
 *
 *---------------------------------------------------------------------------------*/

@implementation VMAppDelegate

static VMAppDelegate *appDelegate_singleton_;


+ (VMAppDelegate*)defaultAppDelegate {
	return appDelegate_singleton_;
}

- (void)setAudioBackgroundMode {
	NSError *err = nil;
	BOOL success;
	
	AVAudioSession *audioSession =[AVAudioSession sharedInstance];
	success = [audioSession setActive:YES error: &err ];
	if (!success) NSLog(@"AVAudioSession setActive error:%@", err.description);
	
	NSString *playbackCategory = ( self.isBackgroundPlaybackEnabled ?
								  AVAudioSessionCategoryPlayback :
								  AVAudioSessionCategorySoloAmbient );
	
	success = [audioSession setCategory:playbackCategory error:&err];
	if (!success)
		NSLog(@"AVAudioSession setCategory error:%@", err.description);
	
	if ( ! audioSessionInited ) {
		//	set interruption listener
		//	audioSession.delegate = self;
		[[NSNotificationCenter defaultCenter] addObserver: self
												 selector: @selector(handleInterruption:)
													 name: AVAudioSessionInterruptionNotification
												   object: audioSession ];

		//	set route change listener	-- depreciated: we use notification instead:
		
/*		OSStatus state = AudioSessionAddPropertyListener( kAudioSessionProperty_AudioRouteChange,
														 audioRouteChangeListenerCallback, self );
		NSLog(@"AudioSessionAddPropertyListener:%d",(int)state);
*/
		
		audioSessionInited = YES;	//	added 150301: audioSessionInited was never set true. BUG FIX
	}
}

- (BOOL)isBackgroundPlaybackEnabled {
	return [VMTraumbaumUserDefaults backgroundPlayback];
}

- (void)audioRouteChanged:(NSNotification*)notification {
	if ( DEFAULTSONGPLAYER.isRunning ) {
		NSInteger  reason = [[[notification userInfo] objectForKey:AVAudioSessionRouteChangeReasonKey] integerValue];
		if (reason == kAudioSessionRouteChangeReason_OldDeviceUnavailable) {
			[[VMAppDelegate defaultAppDelegate] stop];
			NSLog(@"kAudioSessionRouteChangeReason_OldDeviceUnavailable");
		}
	}
}

- (id)init {
	self = [super init];
	if(! self )return nil;
	
	appDelegate_singleton_ = self;
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(audioRouteChanged:) name:AVAudioSessionRouteChangeNotification object:nil];
	
	[[NSNotificationCenter defaultCenter]
	 addObserver:self selector:@selector(endOfSequence:)
	 name:ENDOFSEQUENCE_NOTIFICATION
	 object:nil];
	
    [DEFAULTSONGPLAYER warmUp];
	return self;
}

- (BOOL)loadSongFromVMS {
    NSError 	*outError = nil;
    NSURL 		*songURL = [[[NSURL alloc] initFileURLWithPath:[[VMVmsarcManager defaultManager] vmsFilePath]
											   isDirectory:NO] autorelease];
	return [self openVMSDocumentFromURL:songURL error:&outError];
}

- (NSURL *)userSaveDataUrl {
	return [NSURL fileURLWithPath:[[VMVmsarcManager defaultManager] userSaveFilePath]];
}

- (BOOL)loadUserSavedSong {
	self.song = [VMSong songWithDataFromUrl:[self userSaveDataUrl]];
	if( self.song ) {
		DEFAULTSONGPLAYER.song = self.song;		//	unsafe_unretained.
		NSLog(@"**** load saved song from %@", [[self userSaveDataUrl] path] );
	} else {
		NSLog(@"**** could not load saved song from %@", [[self userSaveDataUrl] path] );
	}
	return (self.song != nil);
}

- (BOOL)deleteUserSavedSong {
	NSError *error = nil;
	[[NSFileManager defaultManager] removeItemAtURL:[self userSaveDataUrl] error:&error];
	return error != nil;
}

- (BOOL)saveSong:(BOOL)forceForeground {
	NSURL *saveUrl =[self userSaveDataUrl];
	NSString *directoryPath = [[saveUrl path] stringByDeletingLastPathComponent];
	if( ![[NSFileManager defaultManager] fileExistsAtPath:directoryPath isDirectory:nil] ) {
		//	because we may not have created DOCUMENTDIRECTORY/defaultSong/ directory
		[[NSFileManager defaultManager] createDirectoryAtPath:directoryPath
								  withIntermediateDirectories:YES attributes:nil error:nil];
	}
	if (!forceForeground) {
		//	usually, we want do it in background
		[self.song performSelectorInBackground:@selector(saveToFile:) withObject:saveUrl];
	} else {
		//	on app termination, we might mave do it in foreground to ensure not to be aborted
		[self.song saveToFile:saveUrl];
	}
	NSLog(@"**** song saved to %@", [saveUrl path] );
	return YES;
}

- (BOOL)openVMSDocumentFromURL:(NSURL *)documentURL error:(NSError**)error {
	self.song = AutoRelease( [[VMSong alloc] init] );
	DEFAULTSONGPLAYER.song = self.song;		//	unsafe_unretained.
	NSLog(@"**** new song from VMS" );
	BOOL success = [self.song readFromURL:documentURL error:error];
	[DEFAULTSONGPLAYER stopAndDisposeQueue];
	return success;
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self name:AVAudioSessionRouteChangeNotification object:nil];

	[DEFAULTSONGPLAYER coolDown];
    Release(_window);
    Release(_viewController);
	appDelegate_singleton_ = nil;
    Dealloc( super );
}

- (void)savePlayerState {
	NSData *playerData = [NSKeyedArchiver archivedDataWithRootObject:DEFAULTSONG.player];
	[VMTraumbaumUserDefaults savePlayer:playerData];
	NSLog(@"Saving player state");
}

- (void)stop {
	NSLog(@"*stop");
	[self savePlayerState];
	[DEFAULTSONGPLAYER stop];
	[[NSNotificationCenter defaultCenter] postNotificationName:PLAYERSTOPPED_NOTIFICATION object:nil];
}
	
- (void)disposeQueue {
	NSLog(@"*dispose queue");
	[DEFAULTSONGPLAYER stopAndDisposeQueue];	//	player must be stopped to dispose queue.
}

- (void)pause {
	NSLog(@"*pause");
	[self savePlayerState];
	[DEFAULTSONGPLAYER fadeoutAndStop:3.];
	[self saveSong:NO];
}

- (BOOL)resume {
	if ( loadingExternalVMS ) return NO;
	NSLog(@"*resume");
	[self startup];
	return YES;
}

//
//	reset button was touched.
//
- (void)reset {
	DEFAULTEVALUATOR.timeManager.shutdownTime = nil;
	[DEFAULTSONGPLAYER stopAndDisposeQueue];
	[DEFAULTSONG reset];
	[DEFAULTEVALUATOR reset];	
	[self deleteUserSavedSong];
	if( [self loadSong] ) {
		[[NSNotificationCenter defaultCenter] postNotificationName:PLAYERSTARTED_NOTIFICATION object:self];
		[DEFAULTSONGPLAYER reset];
	}
}

- (void)endOfSequence:(NSNotification*)notification {
	//	we should clear players and save datas to disable resuming from old saved state.
	DEFAULTSONG.player = nil;
	[self savePlayerState];	
}

- (void)startup {	//	wait for warm up
	VMPSongPlayer *songplayer = DEFAULTSONGPLAYER;
	
	if ( self.song == nil || loadingExternalVMS )
		return;

	if ( ! songplayer.isWarmedUp ) {
		[self performSelector:@selector(startup) withObject:nil afterDelay:0.1];
		return;
	}
	
	//
	//
	//		startup sequence
	//
	//
	NSLog(@""
		  "SongPlayer paused:%@\n"
		  "some AudioPlayer running:%@\n"
		  "unfired frags:%ld\n",
		  
		  ( songplayer.isPaused ? @"YES" : @"NO" ),
		  ( songplayer.isRunning ? @"YES" : @"NO" ),
		  [songplayer numberOfUnfiredFragments]
		  );
		
	if ( songplayer.isPaused ) [songplayer resume];
	[songplayer setFadeFrom:-1 to:1 length:.1];	//	dummy set to prevent the player stopped in update call.
	[songplayer update];
	
	//	awake from suspension
	if ( songplayer.isRunning ) {
		if ( [songplayer numberOfUnfiredFragments] > 0 ) {
			NSLog( @"Startup: songplayer is running. no extra startup required.\n%@", songplayer.description );
			[[NSNotificationCenter defaultCenter] postNotificationName:PLAYERSTARTED_NOTIFICATION object:self];
			[songplayer setFadeFrom:-1 to:1 length:2.];
			return;
		}
	};		//	seems nothing special required.
	
	if ( [songplayer numberOfUnfiredFragments] > 0 ) {
		[songplayer adjustCurrentTimeToQueuedFragment];
		NSLog( @"Startup: songplayer has frags in queue. let them fire now!\n%@", songplayer.description );
		[[NSNotificationCenter defaultCenter] postNotificationName:PLAYERSTARTED_NOTIFICATION object:self];
		[songplayer setFadeFrom:-1 to:1 length:2.];
		return;
	}
	
	if ( DEFAULTSONG.player ) {
		if ( songplayer.isPaused ) [songplayer resume];
		NSLog( @"Startup: player data is still on memory. let's fill the queue with them.\n%@", DEFAULTSONG.player.description );
		[[NSNotificationCenter defaultCenter] postNotificationName:PLAYERSTARTED_NOTIFICATION object:self];
		[songplayer setFadeFrom:-1 to:1 length:2.];
		return;
	}
	
	//	try resume from saved data
	NSData *playerData = [VMTraumbaumUserDefaults loadPlayer];
	
	if ( playerData ) {
		VMPlayer *player = [NSKeyedUnarchiver unarchiveObjectWithData:playerData];
		if ( player.fragments.count > 0 ) {
			NSLog(@"Startup: trying to recover from saved state:%@",player.description);
			DEFAULTSONG.player = player;
			[songplayer setFadeFrom:0.01 to:1 length:3.];
			[songplayer startWithFragmentId:nil];
			[[NSNotificationCenter defaultCenter] postNotificationName:PLAYERSTARTED_NOTIFICATION object:self];
			return;
		}
	}
	NSLog(@"Startup: no data for recovery found. start new from beginning.");
	[songplayer start];
	[[NSNotificationCenter defaultCenter] postNotificationName:PLAYERSTARTED_NOTIFICATION object:self];
}
	
	
- (BOOL)loadSong {
	if( ! [self loadUserSavedSong] ) {		//	load saved song if possible
		if( ! [self loadSongFromVMS] ) {
			NSLog(@"Could not load %@", [[VMVmsarcManager defaultManager] vmsFilePath]);
			return NO;
		}
	}
	if( self.song ) {
		NSLog(@"*song loaded: %@",self.song.songName);
		[[VMVmsarcManager defaultManager] setPropertyOfCurrentVMS:VMSCacheKey_SongName to:self.song.songName];
		[[VMVmsarcManager defaultManager] setPropertyOfCurrentVMS:VMSCacheKey_Artist to:self.song.artist];
		[[VMVmsarcManager defaultManager] setPropertyOfCurrentVMS:VMSCacheKey_Website to:self.song.websiteURL];
	} else {
		NSLog(@"loadSong: no errors reported from the loader, but we have an empty song!");
		return NO;
	}
	return YES;
}
	

#pragma mark -
#pragma mark app state change
//
//	app state change
//
	
-(BOOL)application:(UIApplication *)application willFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
	if( ! [launchOptions objectForKey:UIApplicationLaunchOptionsURLKey] ) {
		// Startup!
		//	test : loading sequence moved from -init
		[self loadSong];
		[DEFAULTSONGPLAYER warmUp];
		DEFAULTSONG.showReport.current = @YES;
	}
	return YES;
}


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

	NSLog(@"\n---------------------------------\n"
		  "didFinishLaunchingWithOptions"
		  "\n---------------------------------\n");
 	[VMTraumbaumUserDefaults initializeDefaults];		//	note: we must update this to support url-scheme supplied external files.
	self.window = [[[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]] autorelease];

	self.viewController = [[[VMViewController alloc] init] autorelease];
    self.window.rootViewController = self.viewController;
    [self.window makeKeyAndVisible];
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
	NSLog(@"\n---------------------------------\n"
		  "applicationWillResignActive"
		  "\n---------------------------------\n");
	if ( ! self.isBackgroundPlaybackEnabled )
		[DEFAULTSONGPLAYER setFadeFrom:-1 to:0 length:.1];	//	prevent garbage audio at next startup.	ss1311123
	
	if ( [self.viewController.view.subviews containsObject:self.viewController.infoViewController.view] ) {
		[self.viewController.infoViewController closeView];
	}
}
	

- (void)applicationDidEnterBackground:(UIApplication *)application {
	NSLog(@"\n---------------------------------\n"
		  "applicationDidEnterBackground"
		  "\n---------------------------------\n");
	[self savePlayerState];
	if ( !self.isBackgroundPlaybackEnabled || DEFAULTSONGPLAYER.isPaused ) {
		[self saveSong:YES];
	}
	[self.viewController.infoViewController.view removeFromSuperview];

}

- (void)applicationWillEnterForeground:(UIApplication *)application {
	NSLog(@"\n---------------------------------\n"
		  "applicationWillEnterForeground"
		  "\n---------------------------------\n");
	
	if ( ! self.isBackgroundPlaybackEnabled ) {
		[DEFAULTSONGPLAYER setFadeFrom:0 to:0 length:.01];	//	set fader to zero
		[DEFAULTSONGPLAYER setGlobalVolume:1.];	//	dummy call to make sure fader volume is set.
		[self performSelector:@selector(startup) withObject:nil afterDelay:0.1];
	}
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
	NSLog(@"\n---------------------------------\n"
		  "applicationDidBecomeActive"
		  "\n---------------------------------\n");
	if ( ! self.isBackgroundPlaybackEnabled )
		[self performSelector:@selector(startup) withObject:nil afterDelay:0.1];
}

- (void)applicationWillTerminate:(UIApplication *)application {
	NSLog(@"\n---------------------------------\n"
		  "applicationWillTerminate"
		  "\n---------------------------------\n");

	[self savePlayerState];
	[self saveSong:YES];
	NSLog(@"stop player");
	[DEFAULTSONGPLAYER stop];
	[DEFAULTSONGPLAYER coolDown];
}
	
	
/*
 *
 *	external vms files
 *
 */
#pragma mark - Handle vmsarc URL scheme
	
- (BOOL)application:(UIApplication *)application
			openURL:(NSURL *)url
  sourceApplication:(NSString *)sourceApplication
		 annotation:(id)annotation {
	[VMVmsarcManager defaultManager].delegate = self;
	loadingExternalVMS = [[VMVmsarcManager defaultManager] openURL:url checkUpdatesOnly:NO];	//	asynchronous loading
	[DEFAULTSONGPLAYER stop];
	[[NSNotificationCenter defaultCenter] postNotificationName:PLAYERSTOPPED_NOTIFICATION object:nil];
	return loadingExternalVMS;
}

- (void)vmsarcLoadingFailed {
	loadingExternalVMS = NO;
}
	
- (void)vmsarcLoaded {
	NSLog(@"vmsarc loaded. archiveId:%@",[VMVmsarcManager defaultManager].currentArchiveId);
	loadingExternalVMS = false;
	if( [self loadSong] ) {
		[DEFAULTSONGPLAYER warmUp];
		DEFAULTSONG.showReport.current = @YES;
		[self startup];
	}
}

#pragma mark -
#pragma mark AVAudioSession delegate

- (void)handleInterruption:(NSNotification*)notification {
	switch ([notification.userInfo[AVAudioSessionInterruptionTypeKey] intValue]) {
		case AVAudioSessionInterruptionTypeBegan:
			[self beginInterruption];
			break;
		case AVAudioSessionInterruptionTypeEnded:
		default:
			[self endInterruptionWithFlags:0];
			break;
	}
}

//
//	AVAudioSessionDelegate
//
- (void)beginInterruption {
	NSLog(@"\n*****\nAudioSession Begin Interruption\n*****%@*************\n", DEFAULTSONGPLAYER.description );
	[self savePlayerState];
	[DEFAULTSONGPLAYER setFadeFrom:-1 to:0.01 length:0.1];
}
- (void)endInterruptionWithFlags:(NSUInteger)flags {
//	[DEFAULTSONGPLAYER resume];
	[DEFAULTSONGPLAYER flushFiredFragments];
	[DEFAULTSONGPLAYER flushFinishedFragments];
	[DEFAULTSONGPLAYER adjustCurrentTimeToQueuedFragment];
	[DEFAULTSONGPLAYER setFadeFrom:0.01 to:1. length:2.];
	[DEFAULTSONGPLAYER restartTimer];
	NSLog(@"\n*****\nAudioSession End Interruption\n*****%@*************\n", DEFAULTSONGPLAYER.description );
	[self startup];
	[self performSelector:@selector(startup) withObject:nil afterDelay:1.0];
	[self performSelector:@selector(startup) withObject:nil afterDelay:2.1];
	
}


@end

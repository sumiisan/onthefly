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

#define kDefaultVMSFileName @"default.vms"


#pragma mark Audio session callbacks_______________________

/*---------------------------------------------------------------------------------
 *
 *
 *	handle audio route change
 *
 *
 *---------------------------------------------------------------------------------*/


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
			[[NSNotificationCenter defaultCenter] postNotificationName:PLAYERSTOPPED_NOTIFICATION object:nil];

        }
    }
}


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

		//	set route change listener
		OSStatus state = AudioSessionAddPropertyListener( kAudioSessionProperty_AudioRouteChange,
														 audioRouteChangeListenerCallback, self );
		NSLog(@"AudioSessionAddPropertyListener:%ld",state);
	}
}

- (BOOL)isBackgroundPlaybackEnabled {
	return [[NSUserDefaults standardUserDefaults] boolForKey:@"doesPlayInBackground"];
}


- (id)init {
	self = [super init];
	if(! self )return nil;
	
	appDelegate_singleton_ = self;
	
	//  open document
	
	if( ! [self loadUserSavedSong] ) {		//	load saved song if possible
		[self loadSongFromVMS];
    }
	
	[[NSNotificationCenter defaultCenter]
	 addObserver:self selector:@selector(endOfSequence:)
	 name:ENDOFSEQUENCE_NOTIFICATION
	 object:nil];
	
	
    [DEFAULTSONGPLAYER warmUp];
	return self;
}

- (BOOL)loadSongFromVMS {
    NSError 	*outError = nil;
	NSString 	*resourcePath = [[NSBundle bundleForClass: [self class]] resourcePath];
    NSURL 		*songURL = [[[NSURL alloc] initFileURLWithPath:[NSString stringWithFormat:@"%@/%@/%@",
															   resourcePath,kDefaultVMDirectory,kDefaultVMSFileName]
											   isDirectory:NO] autorelease];
	return [self openVMSDocumentFromURL:songURL error:&outError];
}

- (NSURL *)userSaveDataUrl {
    NSArray *searchPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentPath = [searchPaths lastObject];
    return [NSURL fileURLWithPath:[documentPath stringByAppendingPathComponent:@"usersave.data"]];
}

- (BOOL)loadUserSavedSong {
	self.song = [VMSong songWithDataFromUrl:[self userSaveDataUrl]];
	if( self.song ) {
		DEFAULTSONGPLAYER.song = self.song;		//	unsafe_unretained.
		NSLog(@"**** load saved song");
	} else {
		NSLog(@"**** could not load saved song");
	}
	return (self.song != nil);
}

- (BOOL)deleteUserSavedSong {
	NSError *error = nil;
	[[NSFileManager defaultManager] removeItemAtURL:[self userSaveDataUrl] error:&error];
	return error != nil;
}

- (BOOL)saveSong {
	[self.song performSelectorInBackground:@selector(saveToFile:) withObject:[self userSaveDataUrl]];
	NSLog(@"**** song saved");
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
	[DEFAULTSONGPLAYER coolDown];
    Release(_window);
    Release(_viewController);
	appDelegate_singleton_ = nil;
    Dealloc( super );
}

- (void)savePlayerState {
	NSData *playerData = [NSKeyedArchiver archivedDataWithRootObject:DEFAULTSONG.player];
	[[NSUserDefaults standardUserDefaults] setObject:playerData forKey:@"lastPlayer"];
	NSLog(@"Saving player state");
}

- (void)stop {
	NSLog(@"*stop");
	[self savePlayerState];
	[DEFAULTSONGPLAYER stop];
}

- (void)pause {
	NSLog(@"*pause");
	[self savePlayerState];
	[DEFAULTSONGPLAYER fadeoutAndStop:3.];
	[self saveSong];
}

- (void)resume {
	NSLog(@"*resume");
	[self startup];
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
	[self loadSongFromVMS];
	[[NSNotificationCenter defaultCenter] postNotificationName:PLAYERSTARTED_NOTIFICATION object:self];
    [DEFAULTSONGPLAYER reset];
}


- (void)endOfSequence:(NSNotification*)notification {
	//	we should clear players and save datas to disable resuming from old saved state.
	DEFAULTSONG.player = nil;
	[self savePlayerState];	
}


- (void)startup {	//	wait for warm up
	VMPSongPlayer *songplayer = DEFAULTSONGPLAYER;
	
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
	NSData *playerData = [[NSUserDefaults standardUserDefaults] objectForKey:@"lastPlayer"];
	
	if ( playerData ) {
		VMPlayer *player = [NSKeyedUnarchiver unarchiveObjectWithData:playerData];
		if ( player.fragments.count > 0 ) {
			NSLog(@"Startup: trying to recover from saved state:%@",player.description);
			DEFAULTSONG.player = player;
			[[NSNotificationCenter defaultCenter] postNotificationName:PLAYERSTARTED_NOTIFICATION object:self];
			[songplayer setFadeFrom:0.01 to:1 length:3.];
			[songplayer startWithFragmentId:nil];
			return;
		}
	}
	NSLog(@"Startup: no data for recovery found. start new fron beginning.");
	[[NSNotificationCenter defaultCenter] postNotificationName:PLAYERSTARTED_NOTIFICATION object:self];
	[songplayer start];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Startup!
	[DEFAULTSONGPLAYER warmUp];
	DEFAULTSONG.showReport.current = @YES;
}

- (void)applicationWillFinishLaunching:(NSNotification *)notification {
}

#pragma mark -
#pragma mark app state change
//
//	app state change
//

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
 	NSLog(@"\n---------------------------------\n"
		  "didFinishLaunchingWithOptions"
		  "\n---------------------------------\n");
   self.window = [[[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]] autorelease];
    // Override point for customization after application launch.
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        self.viewController = [[[VMViewController alloc] initWithNibName:@"VMViewController_iPhone" bundle:nil] autorelease];
    } else {
        self.viewController = [[[VMViewController alloc] initWithNibName:@"VMViewController_iPad" bundle:nil] autorelease];
    }
    self.window.rootViewController = self.viewController;
    [self.window makeKeyAndVisible];
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
	NSLog(@"\n---------------------------------\n"
		  "applicationWillResignActive"
		  "\n---------------------------------\n");
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
	if ( ! self.isBackgroundPlaybackEnabled )
		[DEFAULTSONGPLAYER setFadeFrom:-1 to:0 length:.1];	//	prevent garbage audio at next startup.	ss1311123
	
	if ( [self.viewController.view.subviews containsObject:self.viewController.infoView] ) {
		[self.viewController.infoView closeView];
	}

}

- (void)applicationDidEnterBackground:(UIApplication *)application {
	NSLog(@"\n---------------------------------\n"
		  "applicationDidEnterBackground"
		  "\n---------------------------------\n");
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
	[self savePlayerState];
	if ( !self.isBackgroundPlaybackEnabled || DEFAULTSONGPLAYER.isPaused ) {
		[self saveSong];
	}
	[self.viewController.infoView removeFromSuperview];

}

- (void)applicationWillEnterForeground:(UIApplication *)application {
	NSLog(@"\n---------------------------------\n"
		  "applicationWillEnterForeground"
		  "\n---------------------------------\n");
	
	if ( ! self.isBackgroundPlaybackEnabled ) {
		[DEFAULTSONGPLAYER setFadeFrom:0 to:0 length:0];	//	set fader to zero
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
	//
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
	//[self performSelector:@selector(startup) withObject:nil afterDelay:0.1];

}

- (void)applicationWillTerminate:(UIApplication *)application {
	NSLog(@"\n---------------------------------\n"
		  "applicationWillTerminate"
		  "\n---------------------------------\n");
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
	[self savePlayerState];
	[self saveSong];
	NSLog(@"stop player");
	[DEFAULTSONGPLAYER stop];
	[DEFAULTSONGPLAYER coolDown];
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

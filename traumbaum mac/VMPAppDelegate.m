//
//  VMPAppDelegate.m
//  traumbaum mac
//
//  Created by sumiisan on 2013/08/07.
//
//



#import "VMPAppDelegate.h"
#import "VMScoreEvaluator.h"
#import "VMPSongPlayer.h"
#import "VMPRainyView.h"
#import "VMPFrontView.h"
#import "VMTraumbaumUserDefaults.h"

#define kDefaultVMSFileName @"default.vms"
static NSString *kDefaultVMDirectory __unused = @"defaultSong";
static NSString *kMainWindowId = @"MainWindow";




@implementation VMPAppDelegate

static VMPAppDelegate *singleton__static__ = nil;

@synthesize song=song_, window=window_, rainyView=rainyView_, frontView=frontView_, fogMenuItem=fogMenuItem_,
darkBackgroundMenuItem=darkBackgroundMenuItem_, backgroundImage=backgroundImage_;

+ (VMPAppDelegate*)defaultAppDelegate {
	return singleton__static__;
}

+ (void)restoreWindowWithIdentifier:(NSString *)identifier state:(NSCoder *)state completionHandler:(void (^)(NSWindow *, NSError *))completionHandler {
	
	if ([identifier isEqualToString:kMainWindowId]) {
		VMPAppDelegate *appDelegate = (VMPAppDelegate *)NSApplication.sharedApplication.delegate;
		NSWindow *myWindow = appDelegate.window;
		
		completionHandler(myWindow, nil);
	}
}

- (id)init {
	self = [super init];
	singleton__static__ = self;
	return self;
}

- (void)dealloc {
	[DEFAULTSONGPLAYER coolDown];
	[NSObject cancelPreviousPerformRequestsWithTarget:self.frontView selector:@selector(animate:) object:nil];
	self.song = nil;
	self.rainyView = nil;
	self.frontView = nil;
	NSLog(@"app dealloc");
	singleton__static__ = nil;
	[super dealloc];
}

- (void)windowWillClose:(NSNotification *)notification {
	[NSObject cancelPreviousPerformRequestsWithTarget:self.frontView selector:@selector(animate:) object:nil];
}

- (void)applicationWillTerminate:(NSNotification *)notification {
	//	save current song position
	NSLog(@"app will terminate");
	NSData *playerData = [NSKeyedArchiver archivedDataWithRootObject:CURRENTSONG.player];
	[VMTraumbaumUserDefaults savePlayer:playerData];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
	NSLog(@"applicationShouldTerminateAfterLastWindowClosed");
	return YES;
}


- (void)openDefaultSong {
	NSError 	*outError = nil;//AutoRelease([[NSError alloc] init]);
	NSString 	*resourcePath = [[NSBundle bundleForClass: [self class]] resourcePath];
	NSURL 		*songURL = [[NSURL alloc] initFileURLWithPath:[NSString stringWithFormat:@"%@/%@/%@",
															   resourcePath,kDefaultVMDirectory,kDefaultVMSFileName]
											  isDirectory:NO];
	
	[self openVMSDocumentFromURL:songURL error:&outError];
	Release(songURL);
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	[VMTraumbaumUserDefaults initializeDefaults];
	self.window.delegate = self;
	self.fogMenuItem.state	= [[VMTraumbaumUserDefaults standardUserDefaults] boolForKey:@"useFog"];
	
	[self openDefaultSong];
	
	self.frontView = AutoRelease([[VMPFrontView alloc] initWithFrame:NSMakeRect(0, 0, 320, 480)]);
	[self.window.contentView addSubview:self.frontView];
    
    DEFAULTSONGPLAYER.song = self.song;	//	unsafe_unretained.
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(endOfSequence:)
												 name:ENDOFSEQUENCE_NOTIFICATION object:nil];
    [DEFAULTSONGPLAYER warmUp];
	
	self.rainyView = [[[VMPRainyView alloc] initWithFrame:NSMakeRect(-30, -30, 380, 540)] autorelease];
	rainyView_.wantsLayer = YES;
	rainyView_.alphaValue = 0.2;
	rainyView_.enabled = [[VMTraumbaumUserDefaults standardUserDefaults] boolForKey:@"useFog"];
	
	CIFilter *filter =  [CIFilter filterWithName:@"CIGaussianBlur"];
	[filter setDefaults];	
	[rainyView_ setContentFilters:[NSArray arrayWithObject:filter]];
	 
	[self.window.contentView addSubview:rainyView_];
	
	self.window.restorationClass = self.class;
	self.window.identifier = kMainWindowId;
	
	
	[self startup];
}

- (void)endOfSequence:(NSNotification*)notification {
	//	we should clear players and save datas to disable resuming from old saved state.
	CURRENTSONG.player = nil;
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
	
	
	if (![[VMTraumbaumUserDefaults standardUserDefaults] boolForKey:VMP_PlaybackStateKey]) {
		NSLog(@"last time when app was shut down, playback was stopped.");
		return;
	}
	
	
	if ( songplayer.isPaused ) [songplayer resume];
		
	[songplayer setFadeFrom:-1 to:1 length:.1];	//	dummy set to prevent the player stopped in update call.
	[songplayer update];
	
	
	//	awake from suspension
	if ( songplayer.isRunning ) {
		if ( [songplayer numberOfUnfiredFragments] > 0 ) {
			NSLog( @"Startup: songplayer is running. no extra startup required.\n%@", songplayer.description );
			[VMTraumbaumUserDefaults setPlaying:YES];
			[[NSNotificationCenter defaultCenter] postNotificationName:PLAYERSTARTED_NOTIFICATION object:self];
			[songplayer setFadeFrom:-1 to:1 length:2.];
			return;
		}
	};		//	seems nothing special required.
	
	if ( [songplayer numberOfUnfiredFragments] > 0 ) {
		[songplayer adjustCurrentTimeToQueuedFragment];
		[VMTraumbaumUserDefaults setPlaying:YES];
		NSLog( @"Startup: songplayer has frags in queue. let them fire now!\n%@", songplayer.description );
		[[NSNotificationCenter defaultCenter] postNotificationName:PLAYERSTARTED_NOTIFICATION object:self];
		[songplayer setFadeFrom:-1 to:1 length:2.];
		return;
	}
	
	if ( CURRENTSONG.player ) {
		if ( songplayer.isPaused ) [songplayer resume];
		NSLog( @"Startup: player data is still on memory. let's fill the queue with them.\n%@", CURRENTSONG.player.description );
		[VMTraumbaumUserDefaults setPlaying:YES];
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
			CURRENTSONG.player = player;
			[VMTraumbaumUserDefaults setPlaying:YES];
			[[NSNotificationCenter defaultCenter] postNotificationName:PLAYERSTARTED_NOTIFICATION object:self];
			[songplayer setFadeFrom:0.01 to:1 length:3.];
			[songplayer startWithFragmentId:nil];
			return;
		}
	}
	NSLog(@"Startup: no data for recovery found. start new fron beginning.");
	[VMTraumbaumUserDefaults setPlaying:YES];
	[[NSNotificationCenter defaultCenter] postNotificationName:PLAYERSTARTED_NOTIFICATION object:self];
	[songplayer start];
}


- (BOOL)openVMSDocumentFromURL:(NSURL *)documentURL error:(NSError**)error {
	self.song = AutoRelease( [[VMSong alloc] init] );
	return [self.song readFromURL:documentURL error:error];
}

- (void)savePlayerState {
	NSData *playerData = [NSKeyedArchiver archivedDataWithRootObject:CURRENTSONG.player];
	[VMTraumbaumUserDefaults savePlayer:playerData];
	NSLog(@"Saving player state");
}


- (IBAction)stop:(id)sender {
	NSLog(@"*stop");
	[self savePlayerState];
	[VMTraumbaumUserDefaults setPlaying:NO];
	[DEFAULTSONGPLAYER stop];
}

- (IBAction)pause:(id)sender {
	NSLog(@"*pause");
	[self savePlayerState];
	[VMTraumbaumUserDefaults setPlaying:NO];
	[DEFAULTSONGPLAYER fadeoutAndStop:3.];
}

- (IBAction)resume:(id)sender {
	NSLog(@"*resume");
	[VMTraumbaumUserDefaults setPlaying:YES];	//	we must set the flag before we call startup()
	[self startup];
}

- (IBAction)reset:(id)sender {
	DEFAULTEVALUATOR.timeManager.shutdownTime = nil;
	[DEFAULTSONGPLAYER stopAndDisposeQueue];
	[CURRENTSONG reset];
	[DEFAULTEVALUATOR reset];

	[self savePlayerState];

	//	reset starts playback:
	[[NSNotificationCenter defaultCenter] postNotificationName:PLAYERSTARTED_NOTIFICATION object:self];
	[VMTraumbaumUserDefaults setPlaying:YES];
    [DEFAULTSONGPLAYER reset];
}


- (IBAction)resetSong:(id)sender {
	[self reset:sender];
}

- (IBAction)dimmPlayer:(id)sender {
	NSMenuItem *menuItem = sender;
	menuItem.state = NSOnState - menuItem.state;
	BOOL dimmed = menuItem.state == NSOnState;
	DEFAULTSONGPLAYER.dimmed = dimmed;
	self.frontView.alphaValue = dimmed ? 0.5 : 1.;
}

- (IBAction)openWebsite:(id)sender {
	[[NSWorkspace sharedWorkspace] openURL: [NSURL URLWithString:@"http://sumiisan.com/"]];
}

- (IBAction)toggleFog:(id)sender {
	NSMenuItem *menuItem = sender;
	menuItem.state = NSOnState - menuItem.state;
	[[VMTraumbaumUserDefaults standardUserDefaults] setBool:menuItem.state forKey:@"useFog"];
	self.rainyView.enabled = menuItem.state;
}
@end

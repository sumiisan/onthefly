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

#define kDefaultVMSFileName @"default.vms"


@implementation VMPAppDelegate

static VMPAppDelegate *singleton__static__ = nil;

@synthesize song=song_, window=window_, rainyView=rainyView_, frontView=frontView_, fogMenuItem=fogMenuItem_,
darkBackgroundMenuItem=darkBackgroundMenuItem_, backgroundImage=backgroundImage_;

+ (VMPAppDelegate*)defaultAppDelegate {
	return singleton__static__;
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
	NSData *playerData = [NSKeyedArchiver archivedDataWithRootObject:DEFAULTSONG.player];
	[[NSUserDefaults standardUserDefaults] setObject:playerData forKey:@"lastPlayer"];

}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
	NSLog(@"applicationShouldTerminateAfterLastWindowClosed");
	return YES;
}


- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {

	self.window.delegate = self;
//	BOOL darkBG = [[NSUserDefaults standardUserDefaults] boolForKey:@"useDarkBackground"];
//	self.darkBackgroundMenuItem.state = darkBG;
//	if( darkBG ) [self.backgroundImage setImage:[NSImage imageNamed:@"skin1_phone.jpg"]];
	
	self.fogMenuItem.state			  = [[NSUserDefaults standardUserDefaults] boolForKey:@"useFog"];
	
	NSError 	*outError = nil;//AutoRelease([[NSError alloc] init]);
	NSString 	*resourcePath = [[NSBundle bundleForClass: [self class]] resourcePath];
    NSURL 		*songURL = [[NSURL alloc] initFileURLWithPath:[NSString stringWithFormat:@"%@/%@/%@",
															   resourcePath,kDefaultVMDirectory,kDefaultVMSFileName]
											  isDirectory:NO];
	
	[self openVMSDocumentFromURL:songURL error:&outError];
	
	self.frontView = AutoRelease([[VMPFrontView alloc] initWithFrame:NSMakeRect(0, 0, 320, 480)]);
	[self.window.contentView addSubview:self.frontView];
    
    DEFAULTSONGPLAYER.song = self.song;	//	unsafe_unretained.
	
    Release(songURL);
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(endOfSequence:)
												 name:ENDOFSEQUENCE_NOTIFICATION object:nil];

    [DEFAULTSONGPLAYER warmUp];
	
	
	self.rainyView = [[[VMPRainyView alloc] initWithFrame:NSMakeRect(-30, -30, 380, 540)] autorelease];
	rainyView_.wantsLayer = YES;
	rainyView_.alphaValue = 0.2;
	rainyView_.enabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"useFog"];
	
	CIFilter *filter =  [CIFilter filterWithName:@"CIGaussianBlur"];
	[filter setDefaults];	
	[rainyView_ setContentFilters:[NSArray arrayWithObject:filter]];
	 
	[self.window.contentView addSubview:rainyView_];
	[self startup];
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


- (BOOL)openVMSDocumentFromURL:(NSURL *)documentURL error:(NSError**)error {
	self.song = AutoRelease( [[VMSong alloc] init] );
	return [self.song readFromURL:documentURL error:error];
}

- (void)savePlayerState {
	NSData *playerData = [NSKeyedArchiver archivedDataWithRootObject:DEFAULTSONG.player];
	[[NSUserDefaults standardUserDefaults] setObject:playerData forKey:@"lastPlayer"];
	NSLog(@"Saving player state");
}

- (IBAction)stop:(id)sender {
	NSLog(@"*stop");
	[self savePlayerState];
	[DEFAULTSONGPLAYER stop];
}

- (IBAction)pause:(id)sender {
	NSLog(@"*pause");
	[self savePlayerState];
	[DEFAULTSONGPLAYER fadeoutAndStop:3.];
}

- (IBAction)resume:(id)sender {
	NSLog(@"*resume");
	[self startup];
}

- (IBAction)reset:(id)sender {
	DEFAULTEVALUATOR.timeManager.shutdownTime = nil;
    [DEFAULTSONGPLAYER reset];
	[[NSNotificationCenter defaultCenter] postNotificationName:PLAYERSTARTED_NOTIFICATION object:self];
}

- (IBAction)resetSong:(id)sender {
	[DEFAULTSONGPLAYER reset];
}

- (IBAction)dimmPlayer:(id)sender {
	NSMenuItem *menuItem = sender;
	menuItem.state = NSOnState - menuItem.state;
	BOOL dimmed = menuItem.state == NSOnState;
	DEFAULTSONGPLAYER.dimmed = dimmed;
	self.frontView.alphaValue = dimmed ? 0.5 : 1.;
}

- (IBAction)openWebsite:(id)sender {
	[[NSWorkspace sharedWorkspace] openURL: [NSURL URLWithString:@"http://traumbaum.aframasda.com/"]];
}

- (IBAction)toggleFog:(id)sender {
	NSMenuItem *menuItem = sender;
	menuItem.state = NSOnState - menuItem.state;
	[[NSUserDefaults standardUserDefaults] setBool:menuItem.state forKey:@"useFog"];
	self.rainyView.enabled = menuItem.state;
}
/*
- (IBAction)toggleBackground:(id)sender {
	NSMenuItem *menuItem = sender;
	menuItem.state = NSOnState - menuItem.state;
	[[NSUserDefaults standardUserDefaults] setBool:menuItem.state forKey:@"useDarkBackground"];
	
	if( menuItem.state ) {
		[self.backgroundImage setImage:[NSImage imageNamed:@"s1_phone.jpg"]];
	} else {
		[self.backgroundImage setImage:[NSImage imageNamed:@"skin0_phone.jpg"]];
	}
}
 */
@end

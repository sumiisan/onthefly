//
//  VMPAppDelegate.m
//  traumbaum mac
//
//  Created by sumiisan on 2013/08/07.
//
//

#import "VMPAppDelegate.h"
#import "VMPSongPlayer.h"
#import "VMPRainyView.h"

#define kDefaultVMSFileName @"default.vms"


@implementation VMPAppDelegate

@synthesize song=song_, window=window_, rainyView=rainyView_, fogMenuItem=fogMenuItem_,
darkBackgroundMenuItem=darkBackgroundMenuItem_, backgroundImage=backgroundImage_;

- (void)dealloc {
	[DEFAULTSONGPLAYER coolDown];
	[song_ release];
	[rainyView_ release];
	[super dealloc];
}

- (void)applicationWillTerminate:(NSNotification *)notification {
	//	save current song position
	NSData *playerData = [NSKeyedArchiver archivedDataWithRootObject:DEFAULTSONG.player];
	[[NSUserDefaults standardUserDefaults] setObject:playerData forKey:@"lastPlayer"];

}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
	return YES;
}


- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	// Insert code here to initialize your application
	
	BOOL darkBG = [[NSUserDefaults standardUserDefaults] boolForKey:@"useDarkBackground"];
	self.darkBackgroundMenuItem.state = darkBG;
	if( darkBG ) [self.backgroundImage setImage:[NSImage imageNamed:@"skin1_phone.jpg"]];
	
	self.fogMenuItem.state			  = [[NSUserDefaults standardUserDefaults] boolForKey:@"useFog"];
	
	NSError 	*outError = nil;//AutoRelease([[NSError alloc] init]);
	NSString 	*resourcePath = [[NSBundle bundleForClass: [self class]] resourcePath];
    NSURL 		*songURL = [[NSURL alloc] initFileURLWithPath:[NSString stringWithFormat:@"%@/%@/%@",
															   resourcePath,kDefaultVMDirectory,kDefaultVMSFileName]
											  isDirectory:NO];
	
	[self openVMSDocumentFromURL:songURL error:&outError];
	/*
	 variableSong = [[VariableSong alloc] initWithFileURL:songURL];
	 NSData *data = [NSData dataWithContentsOfURL:songURL];
	 [variableSong loadFromContents:data ofType:@"vms" error:&outError];
	 */
    
    DEFAULTSONGPLAYER.song = self.song;	//	unsafe_unretained.
	
    Release(songURL);
	
	
    [DEFAULTSONGPLAYER warmUp];
	
	
	self.rainyView = [[[VMPRainyView alloc] initWithFrame:NSMakeRect(-30, -30, 380, 540)] autorelease];
	rainyView_.wantsLayer = YES;
	rainyView_.alphaValue = 0.2;
	rainyView_.enabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"useFog"];
	
	CIFilter *filter =  [CIFilter filterWithName:@"CIGaussianBlur"];
	[filter setDefaults];	
	[rainyView_ setContentFilters:[NSArray arrayWithObject:filter]];
	 
	[self.window.contentView addSubview:rainyView_];
	[self waitForLaunch];
}


- (void)waitForLaunch {	//	wait for warm up
	
	
	if ( DEFAULTSONGPLAYER.isWarmedUp ) {
		//
		//
		//		startup sequence
		//
		//
		NSLog(@""
			  "SongPlayer paused:%@\n"
			  "some AudioPlayer running:%@\n"
			  "unfired frags:%ld\n",
			  
			  ( DEFAULTSONGPLAYER.isPaused ? @"YES" : @"NO" ),
			  ( DEFAULTSONGPLAYER.isRunning ? @"YES" : @"NO" ),
			  [DEFAULTSONGPLAYER numberOfUnfiredFragments]
			  );
		
		
		if ( DEFAULTSONGPLAYER.isPaused ) [DEFAULTSONGPLAYER resume];
		[DEFAULTSONGPLAYER update];
		
		//	awake from suspension
		if ( DEFAULTSONGPLAYER.isRunning ) {
			if ( [DEFAULTSONGPLAYER numberOfUnfiredFragments] > 0 ) {
				NSLog( @"Startup: songplayer is running. no extra startup required.\n%@", DEFAULTSONGPLAYER.description );
				[DEFAULTSONGPLAYER setFadeFrom:-1 to:1 length:2. setDimmed:NO];
				return;
			}
		};		//	seems nothing special required.
		
		if ( [DEFAULTSONGPLAYER numberOfUnfiredFragments] > 0 ) {
			[DEFAULTSONGPLAYER adjustCurrentTimeToQueuedFragment];
			NSLog( @"Startup: songplayer has frags in queue. let them fire now!\n%@", DEFAULTSONGPLAYER.description );
			[DEFAULTSONGPLAYER setFadeFrom:-1 to:1 length:2. setDimmed:NO];
			return;
		}
		
		if ( DEFAULTSONG.player ) {
			if ( DEFAULTSONGPLAYER.isPaused ) [DEFAULTSONGPLAYER resume];
			NSLog( @"Startup: player data is still on memory. let's fill the queue with them.\n%@", DEFAULTSONG.player.description );
			[DEFAULTSONGPLAYER setFadeFrom:-1 to:1 length:2. setDimmed:NO];
			return;
		}
		
		//	try resume from saved data
		NSData *playerData = [[NSUserDefaults standardUserDefaults] objectForKey:@"lastPlayer"];
		
		if ( playerData ) {
			VMPlayer *player = [NSKeyedUnarchiver unarchiveObjectWithData:playerData];
			if ( player.fragments.count > 0 ) {
				NSLog(@"Startup: trying to recover from saved state:%@",player.description);
				DEFAULTSONG.player = player;
				[DEFAULTSONGPLAYER setFadeFrom:0.01 to:1 length:3. setDimmed:NO];
				[DEFAULTSONGPLAYER startWithFragmentId:nil];
				return;
			}
		}
		NSLog(@"Startup: no data for recovery found. start new fron beginning.");
		[DEFAULTSONGPLAYER start];
	} else {
		[self performSelector:@selector(waitForLaunch) withObject:nil afterDelay:0.1];
	}	
}


- (BOOL)openVMSDocumentFromURL:(NSURL *)documentURL error:(NSError**)error {
	self.song = AutoRelease( [[VMSong alloc] init] );
	return [self.song readFromURL:documentURL error:error];
}


- (IBAction)resetSong:(id)sender {
	[DEFAULTSONGPLAYER reset];
}

- (IBAction)dimmPlayer:(id)sender {
	NSMenuItem *menuItem = sender;
	menuItem.state = NSOnState - menuItem.state;
	DEFAULTSONGPLAYER.dimmed = menuItem.state == NSOnState;
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

- (IBAction)toggleBackground:(id)sender {
	NSMenuItem *menuItem = sender;
	menuItem.state = NSOnState - menuItem.state;
	[[NSUserDefaults standardUserDefaults] setBool:menuItem.state forKey:@"useDarkBackground"];
	
	if( menuItem.state ) {
		[self.backgroundImage setImage:[NSImage imageNamed:@"skin1_phone.jpg"]];
	} else {
		[self.backgroundImage setImage:[NSImage imageNamed:@"skin0_phone.jpg"]];
	}
}



@end

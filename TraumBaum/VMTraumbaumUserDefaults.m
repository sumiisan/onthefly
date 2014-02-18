//
//  VMPUserDefaults.m
//  OnTheFly
//
//  Created by sumiisan on 2014/01/21.
//
//

#import "VMTraumbaumUserDefaults.h"

#define VMPSUD [NSUserDefaults standardUserDefaults]

@implementation VMTraumbaumUserDefaults
	
	static NSString *VMP_BackgroundPlaybackKey = @"doesPlayInBackground";
	static NSString *VMP_LastPlayerKey = @"lastPlayer";
	static NSString *VMP_FirstTimeLauchVersionKey = @"firstTimeLauchVersion";
	static NSString *VMP_PackageListKey = @"packageList";
	static NSString *VMP_LastDismissedMessageKey = @"lastDismissedMessage";
	static NSString *VMP_VMSCacheKey = @"vmsCache";
	
	//
	static NSString *VMP_UseDarkBackground_OnlyVersion1_Key = @"useDarkBackground";
	
	+ (void)initializeDefaults {
		double firstTimeLaunchVersion;
		NSUserDefaults *vmpsud = VMPSUD;
		//
		//	determine the app version of the very first time launch.
		//
		if ( [vmpsud objectForKey:VMP_FirstTimeLauchVersionKey] == nil ) {
			if( [vmpsud objectForKey:VMP_UseDarkBackground_OnlyVersion1_Key] != nil ) {
				firstTimeLaunchVersion = 1.0;
			} else if([vmpsud objectForKey:VMP_BackgroundPlaybackKey] != nil) {
				firstTimeLaunchVersion = 1.1;
			} else {
				firstTimeLaunchVersion = [[[[NSBundle mainBundle] infoDictionary]
										   objectForKey:@"CFBundleShortVersionString"] doubleValue];
			}
			[vmpsud setDouble:firstTimeLaunchVersion forKey:VMP_FirstTimeLauchVersionKey];
		} else {
			firstTimeLaunchVersion = [vmpsud doubleForKey:VMP_FirstTimeLauchVersionKey];
		}
		
		NSDictionary *defaults = [NSDictionary dictionaryWithObjectsAndKeys:
							//	 [NSNull null], VMP_LastPlayerKey,			//	causes error
								  [NSArray array], VMP_PackageListKey,
								  [NSNumber numberWithBool:NO], VMP_BackgroundPlaybackKey,
								  [NSDictionary dictionary], VMP_VMSCacheKey,
								  nil];
		
		[vmpsud registerDefaults:defaults];

	}
	
	+ (void)setBackgroundPlayback:(BOOL)enabled {
		[VMPSUD setBool:enabled forKey:VMP_BackgroundPlaybackKey];
	}
	
	+ (BOOL)backgroundPlayback {
		return [VMPSUD boolForKey:VMP_BackgroundPlaybackKey];
	}

	+ (void)savePlayer:(id)playerObject {
		[VMPSUD setObject:playerObject forKey:VMP_LastPlayerKey];
	}
	
	+ (id)loadPlayer {
		return [VMPSUD objectForKey:VMP_LastPlayerKey];
	}
	
	+ (void)setLastDismissedMessage:(NSString*)message {
		[VMPSUD setObject:message forKey:VMP_LastDismissedMessageKey];
	}
	
	+ (BOOL)isEqualToLastDismissedMessage:(NSString*)message {
		return [[VMPSUD objectForKey:VMP_LastDismissedMessageKey] isEqualToString:message];
	}

	+ (NSDictionary*)vmsCacheTable {
		return [VMPSUD objectForKey:VMP_VMSCacheKey];
	}
	
	+ (void)setVmsCacheTable:(NSDictionary*)vmsCacheDictionary {
		[VMPSUD setObject:vmsCacheDictionary forKey:VMP_VMSCacheKey];
	}
	
	
@end

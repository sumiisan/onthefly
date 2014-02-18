//
//  VMPUserDefaults.h
//  OnTheFly
//
//  Created by sumiisan on 2014/01/21.
//
//

#import <Foundation/Foundation.h>

@interface VMTraumbaumUserDefaults : NSObject
	+ (void)initializeDefaults;
	+ (void)setBackgroundPlayback:(BOOL)enabled;
	+ (BOOL)backgroundPlayback;
	+ (void)savePlayer:(id)playerObject;
	+ (id)loadPlayer;
	+ (void)setLastDismissedMessage:(NSString*)message;
	+ (BOOL)isEqualToLastDismissedMessage:(NSString*)message;
	+ (NSDictionary*)vmsCacheTable;
	+ (void)setVmsCacheTable:(NSDictionary*)vmsCacheTable;
@end

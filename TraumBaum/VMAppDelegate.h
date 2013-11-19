//
//  VMAppDelegate.h
//  Traumbaum
//
//  Created by sumiisan on 2013/03/22.
//
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

#import "VMPInfoView.h"
#import "VMSong.h"

#define PLAYERSTARTED_NOTIFICATION @"vmplayerStarted"
#define PLAYERSTOPPED_NOTIFICATION @"vmplayerStopped"


@class VMViewController;

@interface VMAppDelegate : UIResponder <UIApplicationDelegate,AVAudioSessionDelegate> {
	BOOL audioSessionInited;
}

+ (VMAppDelegate*)defaultAppDelegate;
- (void)setAudioBackgroundMode;
- (BOOL)openVMSDocumentFromURL:(NSURL *)documentURL error:(NSError**)error;

- (void)stop;
- (void)pause;
- (void)resume;
- (void)reset;

@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) VMSong *song;
@property (strong, nonatomic) VMViewController *viewController;

@property (nonatomic, readonly) BOOL isBackgroundPlaybackEnabled;

@end

//
//  VMAppDelegate.h
//  Traumbaum
//
//  Created by sumiisan on 2013/03/22.
//
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

#import "VMPInfoViewController.h"
#import "VMSong.h"
#import "VMVmsarcManager.h"

#define PLAYERSTARTED_NOTIFICATION @"vmplayerStarted"
#define PLAYERSTOPPED_NOTIFICATION @"vmplayerStopped"


@class VMViewController;

@interface VMAppDelegate : UIResponder <UIApplicationDelegate,AVAudioSessionDelegate,VMVmsarcManagerDelegate> {
	BOOL audioSessionInited;
	BOOL loadingExternalVMS;
}

+ (VMAppDelegate*)defaultAppDelegate;
- (void)setAudioBackgroundMode;
- (BOOL)openVMSDocumentFromURL:(NSURL *)documentURL error:(NSError**)error;

- (BOOL)saveSong:(BOOL)forceForeground;
- (void)savePlayerState;
	
- (BOOL)loadSong;
	
- (void)stop;
- (void)disposeQueue;
- (void)pause;
- (BOOL)resume;
- (void)reset;

@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) VMSong *song;
@property (strong, nonatomic) VMViewController *viewController;

@property (nonatomic, readonly) BOOL isBackgroundPlaybackEnabled;

@end

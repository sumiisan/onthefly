//
//  VMPAppDelegate.h
//  traumbaum mac
//
//  Created by sumiisan on 2013/08/07.
//
//

#import <Cocoa/Cocoa.h>
#import "VMSong.h"
#import "VMPFrontView.h"
#import "VMPRainyView.h"

#define PLAYERSTARTED_NOTIFICATION @"vmplayerStarted"
#define PLAYERSTOPPED_NOTIFICATION @"vmplayerStopped"


@interface VMPAppDelegate : NSObject <NSApplicationDelegate, NSWindowDelegate> {
	NSWindow		*window_;
	NSMenuItem		*fogMenuItem_;
	NSMenuItem		*darkBackgroundMenuItem_;
	NSImageView		*backgroundImage_;
	VMPFrontView	*frontView_;
	VMSong			*song_;
	VMPRainyView	*rainyView_;
}

@property (assign)				IBOutlet NSWindow		*window;
@property (nonatomic,assign)	IBOutlet NSMenuItem		*fogMenuItem;
@property (nonatomic,assign)	IBOutlet NSMenuItem		*darkBackgroundMenuItem;
@property (nonatomic,assign)	IBOutlet NSImageView	*backgroundImage;

@property (strong, nonatomic) VMSong *song;
@property (strong, nonatomic) VMPFrontView *frontView;
@property (strong, nonatomic) VMPRainyView *rainyView;

+ (VMPAppDelegate*)defaultAppDelegate;

- (IBAction)stop:(id)sender;
- (IBAction)pause:(id)sender;
- (IBAction)resume:(id)sender;
- (IBAction)reset:(id)sender;
- (IBAction)resetSong:(id)sender;
- (IBAction)dimmPlayer:(id)sender;
- (IBAction)openWebsite:(id)sender;
- (IBAction)toggleFog:(id)sender;
//- (IBAction)toggleBackground:(id)sender;

- (BOOL)openVMSDocumentFromURL:(NSURL *)documentURL error:(NSError**)error;

@end

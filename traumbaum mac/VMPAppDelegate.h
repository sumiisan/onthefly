//
//  VMPAppDelegate.h
//  traumbaum mac
//
//  Created by sumiisan on 2013/08/07.
//
//

#import <Cocoa/Cocoa.h>
#import "VMSong.h"
#import "VMPRainyView.h"

@interface VMPAppDelegate : NSObject <NSApplicationDelegate> {
	NSWindow	*window_;
	NSMenuItem	*fogMenuItem_;
	NSMenuItem	*darkBackgroundMenuItem_;
	NSImageView	*backgroundImage_;
	VMSong		*song_;
	VMPRainyView *rainyView_;
}

@property (assign)				IBOutlet NSWindow		*window;
@property (nonatomic,assign)	IBOutlet NSMenuItem		*fogMenuItem;
@property (nonatomic,assign)	IBOutlet NSMenuItem		*darkBackgroundMenuItem;
@property (nonatomic,assign)	IBOutlet NSImageView	*backgroundImage;

@property (strong, nonatomic) VMSong *song;
@property (strong, nonatomic) VMPRainyView *rainyView;


- (IBAction)resetSong:(id)sender;
- (IBAction)dimmPlayer:(id)sender;
- (IBAction)openWebsite:(id)sender;
- (IBAction)toggleFog:(id)sender;
- (IBAction)toggleBackground:(id)sender;

- (BOOL)openVMSDocumentFromURL:(NSURL *)documentURL error:(NSError**)error;

@end

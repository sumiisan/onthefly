//
//  VMPProgressWindowController.h
//  VARI
//
//  Created by sumiisan on 2013/03/25.
//
//

#import <Cocoa/Cocoa.h>
#import "VMARC.h"

@protocol VMPProgressWindowControllerDelegate <NSObject>
- (void)progressCancelled;
@end

@interface VMPProgressWindowController : NSWindowController

/*
 progress bar
 */
@property (nonatomic, VMWeak) IBOutlet NSProgressIndicator     *progressBar;
@property (nonatomic, VMWeak) IBOutlet NSTextField             *progressLabel;
@property (nonatomic, VMWeak) NSWindow *parentWindow;
@property (unsafe_unretained) id <VMPProgressWindowControllerDelegate>	delegate;

- (IBAction)cancelClicked:(id)sender;
- (void)setProgress:(double)current ofTotal:(double)total message:(NSString*)message window:(NSWindow*)inParentWindow;
@end

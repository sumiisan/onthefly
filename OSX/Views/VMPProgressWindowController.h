//
//  VMPProgressWindowController.h
//  VARI
//
//  Created by sumiisan on 2013/03/25.
//
//

#import <Cocoa/Cocoa.h>

@protocol VMPProgressWindowControllerDelegate <NSObject>
- (void)progressCancelled;
@end

@interface VMPProgressWindowController : NSWindowController

/*
 progress bar
 */
@property (assign) IBOutlet NSProgressIndicator     *progressBar;
@property (assign) IBOutlet NSTextField             *progressLabel;
@property (assign)   id <VMPProgressWindowControllerDelegate>	delegate;
@property (assign) NSWindow *parentWindow;

- (IBAction)cancelClicked:(id)sender;
- (void)setProgress:(double)current ofTotal:(double)total message:(NSString*)message window:(NSWindow*)inParentWindow;
@end

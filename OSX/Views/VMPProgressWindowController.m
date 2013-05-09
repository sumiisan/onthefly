//
//  VMPProgressWindowController.m
//  VARI
//
//  Created by sumiisan on 2013/03/25.
//
//

#import "VMPProgressWindowController.h"

@interface VMPProgressWindowController ()

@end

@implementation VMPProgressWindowController

- (id)initWithWindow:(NSWindow *)window {
    self = [super initWithWindow:window];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
	self.progressLabel.stringValue = @"";
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}

- (void)openModal {	
	[NSApp beginSheet:self.window
	   modalForWindow:self.parentWindow
		modalDelegate:self
	   didEndSelector:nil
		  contextInfo:nil];
}

- (void)closeModal {
	[NSApp endSheet:self.window];
}

- (void)setProgress:(double)current ofTotal:(double)total message:(NSString*)message window:(NSWindow*)inParentWindow {
	
	self.parentWindow = inParentWindow;
	
    if( current < 0 || total == 0 ) {
		self.window.isVisible = NO;
        [self closeModal];
    } else {
		if ( ! self.window.isVisible ) [self openModal];
        self.window.isVisible = YES;
        self.progressBar.minValue = 0;
        self.progressBar.maxValue = total;
		
        self.progressBar.doubleValue = current;
        self.progressLabel.stringValue = [NSString stringWithFormat:@"%@ (%.2f of %.2f)",
										  message, current, total];
    }
}



- (IBAction)cancelClicked:(id)sender {
	[self.delegate progressCancelled];
}


@end

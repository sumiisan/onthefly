//
//  VMPInsertFragmentWindowController.m
//  OnTheFly
//
//  Created by sumiisan on 2013/08/25.
//
//

#import "VMPInsertFragmentWindowController.h"

@interface VMPInsertFragmentWindowController ()

@end

@implementation VMPInsertFragmentWindowController

- (id)initWithWindow:(NSWindow *)window {
    self = [super initWithWindow:window];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}

- (IBAction)insertButtonClick:(id)sender {
	NSArray *typeArray = @[ @(vmObjectType_audioFragment),
						  @(vmObjectType_sequence),
						  @(vmObjectType_selector),
						  @(vmObjectType_reference)];
	int type = ((NSNumber*)typeArray[self.insertTypePopup.selectedTag]).intValue;
	
	if (self.delegate)
		[self.delegate insertFragmentWithId: self.fragmentIdField.stringValue
							   fragmentType: type
						  numberOfFragments: self.numberOfFragsField.intValue
								 insertType: self.insertTypePopup.selectedItem.title
							 insertPosition: self.insertLocationPopup.title
								 startIndex: self.startIndexField.stringValue
						   flattenStructure:(self.flattenCheckbox.state == NSOnState) ];
}

@end

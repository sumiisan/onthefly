//
//  VMPInsertFragmentWindowController.h
//  OnTheFly
//
//  Created by sumiisan on 2013/08/25.
//
//

#import <Cocoa/Cocoa.h>
#import "VMDataTypes.h"

@protocol VMPInsertFragmentWindowControllerDelegate <NSObject>
- (void)insertFragmentWithId:(VMId*)fragId
				fragmentType:(vmObjectType)fragmentType
		   numberOfFragments:(int)numberOfFragments
				  insertType:(VMString*)insertType
			  insertPosition:(VMString*)insertPosition
				  startIndex:(VMString*)startIndex
			flattenStructure:(BOOL)flattenStructure;
@end

@interface VMPInsertFragmentWindowController : NSWindowController

@property (nonatomic, assign) IBOutlet NSTextField *numberOfFragsField;
@property (nonatomic, assign) IBOutlet NSTextField *fragmentIdField;
@property (nonatomic, assign) IBOutlet NSTextField *startIndexField;
@property (nonatomic, assign) IBOutlet NSPopUpButton *fragmentTypePopup;
@property (nonatomic, assign) IBOutlet NSPopUpButton *insertTypePopup;
@property (nonatomic, assign) IBOutlet NSPopUpButton *insertLocationPopup;
@property (nonatomic, assign) IBOutlet NSButton *flattenCheckbox;

@property (nonatomic, assign) id <VMPInsertFragmentWindowControllerDelegate> delegate;

- (IBAction)insertButtonClick:(id)sender;

@end

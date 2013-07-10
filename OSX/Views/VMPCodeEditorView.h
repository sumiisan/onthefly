//
//  VMPCodeEditorViewController.h
//  OnTheFly
//
//  Created by sumiisan on 2013/05/10.
//
//

#import <Cocoa/Cocoa.h>
#import "UKSyntaxColoredTextDocument.h"
#import "VMPrimitives.h"
#import "VMPGraph.h"

/*---------------------------------------------------------------------------------
 *
 *
 *	VMP Syntax Colored Text Document
 *
 *
 *---------------------------------------------------------------------------------*/

@interface VMPSyntaxColoredtextDocument : UKSyntaxColoredTextDocument 
@property	(nonatomic, assign)		BOOL modified;
- (void)setTextView:(NSTextView*)inTextView sourceCode:(NSString*)inSourceCode;
@end

/*---------------------------------------------------------------------------------
 *
 *
 *	VMP Code Editor View Controller
 *
 *
 *---------------------------------------------------------------------------------*/
@interface VMPCodeEditorView : VMPGraph

@property (nonatomic, VMWeak)	IBOutlet NSTextView *textView;
@property (nonatomic, VMWeak)	IBOutlet NSScrollView *scrollView;
@property (nonatomic, VMStrong)	VMString *sourceCode;
@property (nonatomic, VMStrong)	VMPSyntaxColoredtextDocument	*vmsDocument;
@property (nonatomic, getter = isSourceCodeModidied, assign)	BOOL sourceCodeModified;

- (void)selectBlockWithId:(VMId*)fragId scrollVisible:(BOOL)scrollVisible;
- (void)markBlockUsingHintsBefore:(NSString*)before
							after:(NSString*)after;
- (void)setup;
@end





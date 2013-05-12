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
- (void)setTextView:(NSTextView*)inTextView sourceCode:(NSString*)inSourceCode;
@end


/*---------------------------------------------------------------------------------
 *
 *
 *	VMP Highlight Text View
 *
 *
 *---------------------------------------------------------------------------------*/

@interface VMPHighlightTextView : NSTextView

@end


/*---------------------------------------------------------------------------------
 *
 *
 *	VMP Code Editor View Controller
 *
 *
 *---------------------------------------------------------------------------------*/
@interface VMPCodeEditorView : VMPGraph

@property (nonatomic, assign)	IBOutlet VMPHighlightTextView *textView;
@property (nonatomic, assign)	IBOutlet NSScrollView *scrollView;
@property (nonatomic, retain)	VMString *sourceCode;
@property (nonatomic, retain)	VMPSyntaxColoredtextDocument	*vmsDocument;
@property (nonatomic, retain)	NSTextFinder *textFinder;
@property (nonatomic, retain)	NSScanner *scanner;

- (IBAction)performTextFinderAction:(id)sender;
- (void)selectBlockWithId:(VMId*)fragId scrollVisible:(BOOL)scrollVisible;
- (BOOL)validateAction:(NSTextFinderAction)action;
//- (void)markBlockFromLocation:(NSUInteger)location;
- (void)markBlockUsingHintsBefore:(NSString*)before
							after:(NSString*)after;

@end





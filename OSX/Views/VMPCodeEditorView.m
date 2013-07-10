//
//  VMPCodeEditorViewController.m
//  OnTheFly
//
//  Created by sumiisan on 2013/05/10.
//
//

#import "VMPCodeEditorView.h"
#import "VMPNotification.h"
#import "VMPlayerOSXDelegate.h"
#import "VMPMacros.h"
#import "VMPreprocessor.h"


/*---------------------------------------------------------------------------------
 *
 *
 *	VMP Syntax Colored Text Document
 *
 *
 *---------------------------------------------------------------------------------*/

@implementation VMPSyntaxColoredtextDocument

- (NSString*)windowNibName {
	return nil;		//	no nibs since it's inited by the VMPEditorViewController
}

-(NSDictionary*)	defaultTextAttributes {
	NSMutableParagraphStyle *style = AutoRelease([[NSMutableParagraphStyle alloc] init] );
	[style setDefaultTabInterval:31.3];
	[style setTabStops:@[]];
	return @{
			NSFontAttributeName:[NSFont fontWithName:@"Menlo Regular" size:13],
			NSParagraphStyleAttributeName:style
		  };
}


- (void)setTextView:(NSTextView*)inTextView sourceCode:(NSString*)inSourceCode {
	
	//	we don't want unnecessary re-coloring
	if ( textView == inTextView && [textView.string isEqualToString:inSourceCode] ) return;
	
	textView = inTextView;		//	try just VMWeak
	textView.string = inSourceCode;
	textView.delegate = self;
	
	// Set up some sensible defaults for syntax coloring:
	[[self class] makeSurePrefsAreInited];
		
	// Register for "text changed" notifications of our text storage:
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(processEditing:)
												 name: NSTextStorageDidProcessEditingNotification
											   object: [textView textStorage]];
	
	// Put selection at top like Project Builder has it, so user sees it:
	[textView setSelectedRange: NSMakeRange(0,0)];
	
	// Make sure text isn't wrapped:
	[self turnOffWrapping];
	
	MakeTimestamp(begin_syntax_color);
	// Do initial syntax coloring of our file:
	[self recolorCompleteFile:nil];
	MakeTimestamp(end_syntax_color);
	LogTimeBetweenTimestamps(begin_syntax_color, end_syntax_color);
}

//	text modified
- (void)processEditing: (NSNotification*)notification {
	_modified = YES;
	[super processEditing:notification];
}

- (BOOL)textView:(NSTextView *)tv shouldChangeTextInRange:(NSRange)afcr replacementString:(NSString *)rps {	
	if ( [rps isEqualToString:@"}"] )		[self highlightCounterPart:'}' fromLocation:afcr.location];
	else if ( [rps isEqualToString:@"]"] )	[self highlightCounterPart:']' fromLocation:afcr.location];
	else if ( [rps isEqualToString:@")"] )	[self highlightCounterPart:')' fromLocation:afcr.location];
	
	return [super textView:tv shouldChangeTextInRange:afcr replacementString:rps];
}

- (void)highlightCounterPart:(unichar)closerChar fromLocation:(NSUInteger)location {

	VMStack *closedBracketsStack = ARInstance(VMStack);
	[closedBracketsStack push:[NSString stringWithFormat:@"%c",closerChar]];
	
	VMHash  *openerBracketFor = [VMHash hashWith:@{ @"}":@"{", @")":@"(", @"]":@"[" }];
	
	NSString *closeBrackets = @"})]";
	NSUInteger p = location;
	
	NSCharacterSet *bracketCharSet = [NSCharacterSet characterSetWithCharactersInString:@"{}[]()"];

	doForever {
		NSRange bracketRange = [textView.string rangeOfCharacterFromSet:bracketCharSet
																options:NSBackwardsSearch
																  range:NSMakeRange(0, p)];
		
		if ( bracketRange.length == 0 ) {
			// no matching bracket found
			//[textView showFindIndicatorForRange:NSMakeRange( location, 1 )];
			return;
		}
		p = bracketRange.location + bracketRange.length -1;
		NSString *bracket = [textView.string substringWithRange:NSMakeRange(p,1)];
				
		if ( [closeBrackets rangeOfString:bracket].length > 0 ) {
			//	one more other bracket was closed
			[closedBracketsStack push:bracket];
			continue;
		}
				
		if ( [bracket isEqualToString: [openerBracketFor item:closedBracketsStack.current]] ) {
			//	the correct opener for last closed bracket was found.
			[closedBracketsStack restore];
			if( closedBracketsStack.count == 0 ) {
				//	all brackets are nested correctly
				[textView showFindIndicatorForRange:NSMakeRange(p, 1)];
				return;
			}
			continue;
		}
		
		//	mismatched bracket
		//[textView showFindIndicatorForRange:NSMakeRange( location, 1 )];
		return;
	}
}

@end

#pragma mark -
#pragma mark VMP Code Editor View
/*---------------------------------------------------------------------------------
 *
 *
 *	VMP Code Editor View
 *
 *
 *---------------------------------------------------------------------------------*/

@interface VMPCodeEditorView ()
@property (nonatomic, VMStrong)	NSTextFinder *textFinder;
@property (nonatomic, VMStrong)	NSScanner *scanner;
@end

@implementation VMPCodeEditorView

- (id)initWithCoder:(NSCoder *)aDecoder {
	self = [super initWithCoder:aDecoder];
	return self;
}

- (id)initWithFrame:(NSRect)frameRect {	
	self = [super initWithFrame:frameRect];
	return self;
}

- (void)setup {	//	extra method for initialization, because we want do this after editorViewController was inited.
	[VMPNotificationCenter addObserver:self selector:@selector(fragmentSelectedInBrowser:)
								  name:VMPNotificationFragmentSelected object:APPDELEGATE.editorWindowController];
	[VMPNotificationCenter addObserver:self selector:@selector(reloadData:)
								  name:VMPNotificationVMSDataLoaded object:nil];
}

- (void)dealloc {
	[VMPNotificationCenter removeObserver:self];
	VMNullify(textFinder);
	VMNullify(scanner);
	VMNullify(vmsDocument);
	Dealloc( super );;
}

#pragma mark -
#pragma mark accessor

- (void)setSourceCode:(NSString*)sourceCode {	
	if ( ! self.vmsDocument )
		self.vmsDocument = AutoRelease([[VMPSyntaxColoredtextDocument alloc] init] );
	[self.vmsDocument setTextView:self.textView sourceCode:sourceCode];
	VMNullify(scanner);
}

- (NSString*)sourceCode {
	return self.textView.string;
}

- (BOOL)isSourceCodeModified {
	return self.vmsDocument.modified;
}

- (void)setSourceCodeModified:(BOOL)sourceCodeModified {
	self.vmsDocument.modified = sourceCodeModified;
}

- (void)reloadData:(NSNotification*)notification {
	[self setSourceCode:DEFAULTSONG.vmsData];
}
   
#pragma mark -
#pragma mark update editor selection


- (void)fragmentSelectedInBrowser:(NSNotification*)notification {
	if ( notification.object != APPDELEGATE.editorWindowController ) return;
	//	actually, we added a observer with this object..
	if ( self.sourceCode.length == 0 )
		[self setSourceCode:DEFAULTSONG.vmsData];
	VMId *fragId = (notification.userInfo)[@"id"];
	if(fragId);
		[self selectBlockWithId:fragId scrollVisible:YES];
}


#pragma mark -
#pragma mark locate fragment definition on editor
/*---------------------------------------------------------------------------------
 *
 *
 *	locate the definition in editor
 *
 *
 *---------------------------------------------------------------------------------*/

- (NSString*)escapeFragIdForICURegex:(NSString*)string {
	NSMutableString *escaped = AutoRelease([string mutableCopy]);
	[escaped replaceOccurrencesOfString:@"([|\\+()\\~])" withString:@"\\\\$1"
								options:NSRegularExpressionSearch
								  range:NSMakeRange(0, escaped.length)];
	return escaped;
}

- (NSRange)seekId:(NSString*)fragId inRange:(NSRange)searchRange {
	NSString *searchText = [NSString stringWithFormat:@"id:\\s*\"%@[\"]?",fragId];
	NSRange range = [self.textView.string rangeOfString:[self escapeFragIdForICURegex:searchText]
												options:NSRegularExpressionSearch range:searchRange];	
	return range;
}

- (NSRange)seekIdAndSelectIfFound:(NSString*)fragId inRange:(NSRange)searchRange {
	NSRange range = [self seekId:fragId inRange:searchRange];
	
	if( range.length > 0 ) self.textView.selectedRange = range;
	return range;
}

- (NSRange)seekIdAndSelectIfFound:(NSString*)fragId {
	return [self seekIdAndSelectIfFound:fragId
								  inRange:NSMakeRange(0, self.textView.string.length)];
}

#define IndexIsInsideRange(index,range) (((index) >= (range).location && (index) < (range).location + (range).length))

- (void)selectBlockWithId:(VMId*)fragId scrollVisible:(BOOL)scrollVisible {
	if ( !fragId ) return;
	VMFragment *fr = ARInstance(VMFragment);
	fr.id = fragId;
	VMArray *components = [VMArray arrayWithString:fr.userGeneratedId splitBy:@"_"];
	VMArray *tempComp = AutoRelease([components copy]);
	VMNullify(scanner);

	self.textView.selectedRange = NSMakeRange( self.textView.selectedRange.location , 0 );

	do {	//	dummy block
		//	try perfect match
		if ( [self seekIdAndSelectIfFound:[fr.userGeneratedId stringByAppendingString:@"\""]].length > 0 ) break;
		
		//	try head match
		if ( [self seekIdAndSelectIfFound:fr.userGeneratedId].length > 0 ) break;
		//
		//	let's seek incremental
		//
		NSString *partialId = [tempComp unshift];
		do {
			if ( [self seekIdAndSelectIfFound:partialId].length == 0 ) break;
			partialId = [partialId stringByAppendingFormat:@"_%@",[tempComp unshift]];
		} while (tempComp.count);
		
		NSRange fragmentBlockRange = [self blockRangeFromLocation:self.textView.selectedRange.location inString:nil];
		//
		//	try find # abbreviated id
		//
		tempComp = AutoRelease([components copy]);
		[tempComp unshift];
		NSString *abbreviationSign = @"#";
		NSRange result;
		NSRange searchRange;
		searchRange = NSMakeRange(0, self.textView.string.length);
		do {
			//
			//	iterate through number of abbreviated components ( #,##,### ... )
			//
			do {
				//
				//	iterate through matches in search range
				//
				NSString *abbreviatedId = [abbreviationSign stringByAppendingString:[tempComp join:@"_"]];
				result = [self seekId:abbreviatedId inRange:searchRange];
				if( result.length > 0 ) {
					//	found one matching. test if abbreviated components does match
					if ( IndexIsInsideRange( result.location, fragmentBlockRange ) ) {
						//	its inside fragmentBlock we found in last step.
						tempComp = nil;
						self.textView.selectedRange = result;
						break;
					}
					
					NSRange  block = [self blockRangeFromLocation:result.location inString:nil];
					NSString *blockId = [self idOfBlock:block inString:nil];
					
					if ( [blockId isEqualToString:fragId] ) {
						tempComp = nil;
						self.textView.selectedRange = result;
						break;
					}
					NSInteger searchLocation = block.location + block.length;
					searchRange = NSMakeRange(searchLocation, self.textView.string.length -1 - searchLocation);
				} else {
					break;	//	could not find any with this pattern.
				}
			} while ( searchRange.length > 0 );
			[tempComp unshift];
			abbreviationSign = [abbreviationSign stringByAppendingString:@"#"];
		} while (tempComp.count);

	} while (0);
	NSRange block = [self blockRangeFromLocation:self.textView.selectedRange.location inString:nil];
	VMId *idOfBlock = [self idOfBlock:block inString:nil];
	if ( [fragId isEqualToString:idOfBlock] ) {
		self.textView.selectedRange = block;
		if( scrollVisible )
			[self.textView scrollRangeToVisible:block];
		[self.textView showFindIndicatorForRange:block];
	}
}

#pragma mark -
#pragma mark block range and id

/*---------------------------------------------------------------------------------
 
 block range and id
  
 not the most beautiful algorithm in the world. maybe improve later.
 
 ----------------------------------------------------------------------------------*/

//  returns the id of the current block
- (VMId*)idOfBlock:(NSRange)blockRange inString:(NSString*)string {
	if ( !string ) string = self.textView.string;
	NSRange idKeyRange =
	[string rangeOfString:@"id\\s*:\\s*\"" options:NSRegularExpressionSearch
					range:blockRange];
	if ( idKeyRange.length == 0 ) return nil;	//	no id found.
	
	NSUInteger idStartLocation = idKeyRange.location + idKeyRange.length;
	NSRange idRange =
	[string rangeOfString:@"[^\"]+" options:NSRegularExpressionSearch
					range:NSMakeRange( idStartLocation, string.length - idStartLocation )];
	
	NSString *ident = [string substringWithRange:idRange];
	
	if ( [ident hasPrefix:@"#"] && blockRange.location > 0 ) {
		//	we are still in a block. try go one level higher in hierarchies
		VMId *parentId = [self idOfBlock:[self blockRangeFromLocation:blockRange.location-1 inString:string] inString:string];
		VMId *compId = [DEFAULTPREPROCESSOR completeId:ident withParentId:parentId];
		if ( compId ) return compId;
	}
	
	return ident;
}

// returns the start location of current block from cursor position
- (NSInteger)startLocationOfBlockFromLocation:(NSInteger)location inString:(NSString*)string {
	int nest = 1;
	NSRange searchRange = NSMakeRange(0, location);
	do {
		NSInteger openLoc	= [string rangeOfString:@"{" options:NSBackwardsSearch range:searchRange].location;
		NSInteger closeLoc	= [string rangeOfString:@"}" options:NSBackwardsSearch range:searchRange].location;
		if ( openLoc  == NSIntegerMax ) return 0;
		if ( closeLoc == NSIntegerMax ) closeLoc = -1;
		if ( closeLoc < openLoc ) {
			--nest;
			if ( nest == 0 ) return openLoc;
			searchRange = NSMakeRange(0, MAX(openLoc -1,0));
		} else {
			++nest;
			searchRange = NSMakeRange(0, MAX(closeLoc-1,0));
		}
	} while ( searchRange.length > 0 );
	return 0;
}

// returns the text range of current block from cursor position
- (NSRange)blockRangeFromLocation:(NSInteger)location inString:(NSString*)string {
	//	find out block start
	NSScanner *sc;
	if( !string) {
		string = self.textView.string;
		if( !self.scanner ) self.scanner = [NSScanner scannerWithString:string];
		sc = self.scanner;
	} else {
		sc = [NSScanner scannerWithString:string];
	}
	NSInteger blockStartLocation = [self startLocationOfBlockFromLocation:location inString:string];
	
	sc.scanLocation = blockStartLocation;
	
	int				nest = 0;
	BOOL			insideOfString = NO;
	NSCharacterSet	*charset = [NSCharacterSet characterSetWithCharactersInString:@"{}\""];
	doForever {
		[sc scanUpToCharactersFromSet:charset intoString:nil];
		if (sc.isAtEnd) break;
		unichar found = [string characterAtIndex:sc.scanLocation];
		
		if ( found == '"' )
			insideOfString = ! insideOfString;
		else if ( ! insideOfString ) {
			if ( found == '{' )
				++nest;
			else if ( found == '}' ) {
				--nest;
				if ( nest == 0 ) break;
			}
		}
		sc.scanLocation += 1;
		if ( sc.isAtEnd ) break;
	}
	NSUInteger len = sc.scanLocation - blockStartLocation +1;
	return NSMakeRange(blockStartLocation, MIN( len, string.length-blockStartLocation));
}

//
//	used for indicate the position of error occured while parsing json.
//	we have to 'guess' the position because TouchJSON do not know anything about the textual-position.
//	(it handles NSData instead)
//
- (void)markBlockUsingHintsBefore:(NSString*)before 
							after:(NSString*)after {
	//	after is not used
	NSRange block = [self blockRangeFromLocation:before.length-1 inString:before];
	VMId *fragId = [self idOfBlock:block inString:before];
	NSLog(@"fragId:%@",fragId);
	if (self.sourceCode.length == 0)
		[self setSourceCode:DEFAULTSONG.vmsData];

	[self selectBlockWithId:fragId scrollVisible:YES];
}

@end

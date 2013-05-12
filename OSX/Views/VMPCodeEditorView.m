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
	return nil;		//	no nibs since it's automatically by the VMPObjectBrowserView
}

-(NSDictionary*)	defaultTextAttributes {
	NSMutableParagraphStyle *style = [[[NSMutableParagraphStyle alloc] init] autorelease];
	[style setDefaultTabInterval:31.3];
	[style setTabStops:[NSArray array]];
	return @{
			NSFontAttributeName:[NSFont fontWithName:@"Menlo Regular" size:13],
			NSParagraphStyleAttributeName:style
		  };
}


- (void)setTextView:(NSTextView*)inTextView sourceCode:(NSString*)inSourceCode {
	
	textView = inTextView;		//	try just assign
	textView.string = inSourceCode;
	
	// Set up some sensible defaults for syntax coloring:
	[[self class] makeSurePrefsAreInited];
		
	// Set up our progress indicator:
	[progress setStyle: NSProgressIndicatorSpinningStyle];	// NIB forgets that :-(
	[progress setDisplayedWhenStopped:NO];
	[progress setUsesThreadedAnimation:YES];
	
	[status setStringValue: @"Finished."];
	
	// Register for "text changed" notifications of our text storage:
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(processEditing:)
												 name: NSTextStorageDidProcessEditingNotification
											   object: [textView textStorage]];
	
	// Put selection at top like Project Builder has it, so user sees it:
	[textView setSelectedRange: NSMakeRange(0,0)];
	
	// Make sure text isn't wrapped:
	[self turnOffWrapping];
	
	// Do initial syntax coloring of our file:
	[self recolorCompleteFile:nil];
	
	// Make sure we can use "find" if we're on 10.3:
	if( [textView respondsToSelector: @selector(setUsesFindPanel:)] )
		[textView setUsesFindPanel: YES];
	
}


@end

/*---------------------------------------------------------------------------------
 
 VMPHighlightTextView
 
 ----------------------------------------------------------------------------------*/

#pragma mark -
#pragma mark VMPHighlightTextView

@implementation VMPHighlightTextView

- (void) drawViewBackgroundInRect:(NSRect)rect {
	[super drawViewBackgroundInRect:rect];
	NSRange sel = [self selectedRange];
	if ( sel.length == 0 ) return;
	NSString *str = [self string];
	if (sel.location <= [str length]) {
		NSRange lineRange = [str lineRangeForRange:NSMakeRange(sel.location,0)];
		NSRect lineRect = [self highlightRectForRange:lineRange];
		NSColor *highlightColor = [NSColor colorWithCalibratedRed:.5 green:.8 blue:.5 alpha:.5];
		[highlightColor set];
		[NSBezierPath fillRect:lineRect];
	}
}

// Returns a rectangle suitable for highlighting a background rectangle for the given text range.
- (NSRect) highlightRectForRange:(NSRange)aRange {
	NSRange r = aRange;
	NSRange startLineRange = [[self string] lineRangeForRange:NSMakeRange(r.location, 0)];
	NSInteger er = NSMaxRange(r)-1;
	NSString *text = [self string];
	
	if (er >= [text length]) {
		return NSZeroRect;
	}
	if (er < r.location) {
		er = r.location;
	}
	
	NSRange endLineRange = [[self string] lineRangeForRange:NSMakeRange(er, 0)];
	
	NSRange gr = [[self layoutManager] glyphRangeForCharacterRange:NSMakeRange(startLineRange.location, NSMaxRange(endLineRange)-startLineRange.location-1)
											  actualCharacterRange:NULL];
	NSRect br = [[self layoutManager] boundingRectForGlyphRange:gr inTextContainer:[self textContainer]];
	NSRect b = [self bounds];
	CGFloat h = br.size.height;
	CGFloat w = b.size.width;
	CGFloat y = br.origin.y;
	NSPoint containerOrigin = [self textContainerOrigin];
	NSRect aRect = NSMakeRect(0, y, w, h);
	// Convert from view coordinates to container coordinates
	aRect = NSOffsetRect(aRect, containerOrigin.x, containerOrigin.y);
	return aRect;
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

@end

@implementation VMPCodeEditorView

- (id)initWithCoder:(NSCoder *)aDecoder {
	self = [super initWithCoder:aDecoder];
	[self setupNotificationListeners];
	return self;
}

- (id)initWithFrame:(NSRect)frameRect {
	self = [super initWithFrame:frameRect];
	[self setupNotificationListeners];
	return self;
}

- (void)setupNotificationListeners {
	[VMPNotificationCenter addObserver:self selector:@selector(fragmentSelectedInBrowser:)
								  name:VMPNotificationFragmentSelected object:APPDELEGATE.objectBrowserView];
	[VMPNotificationCenter addObserver:self selector:@selector(reloadData:)
								  name:VMPNotificationVMSDataLoaded object:nil];
}

- (void)dealloc {
	[VMPNotificationCenter removeObserver:self];
	self.textFinder = nil;
	self.scanner = nil;
	self.vmsDocument = nil;
	[super dealloc];
}

#pragma mark -
#pragma mark update editor selection

- (void)setSourceCode:(NSString*)sourceCode {
	if ( ! self.vmsDocument )
		self.vmsDocument = [[[VMPSyntaxColoredtextDocument alloc] init] autorelease];
	[self.vmsDocument setTextView:self.textView sourceCode:sourceCode];
}

- (NSString*)sourceCode {
	return self.textView.string;
}

- (void)reloadData:(NSNotification*)notification {
	[self setSourceCode:DEFAULTSONG.vmsData];
}

- (void)fragmentSelectedInBrowser:(NSNotification*)notification {
	if ( notification.object != APPDELEGATE.objectBrowserView ) return;
	//	actually, we added a observer with this object..
	if ( self.sourceCode.length == 0 )
		[self setSourceCode:DEFAULTSONG.vmsData];
	VMId *fragId = [notification.userInfo objectForKey:@"id"];
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
	NSMutableString *escaped = [[string mutableCopy] autorelease];
	[escaped replaceOccurrencesOfString:@"([|+()])" withString:@"\\\\$1"
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
	
	if( range.length > 0 ) {
	//	NSLog(@"found: %ld(%ld) = %@", (unsigned long)range.location, (unsigned long)range.length, [self.textView.string substringWithRange:range] );
		self.textView.selectedRange = range;
	} else {
	//		(@"not found: %@", fragId );
	}
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
	VMArray *tempComp = [[components copy] autorelease];
	self.scanner = nil;

	self.textView.selectedRange = NSMakeRange( self.textView.selectedRange.location , 0 );

	do {	//	dummy block
		//	perfect match
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
		tempComp = [[components copy] autorelease];
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
					//	now find out parent's id
					NSRange parentBlock = [self blockRangeFromLocation:
										   [self startLocationOfBlockFromLocation:result.location
																		 inString:self.textView.string] -1	// up one level
															  inString:nil ];
					//	note that we don't resolve the parentId hierarchical. (support in future maybe)
					//	we just exit hierarchies until we have found a complete (unabbreviated) id.
					VMId *parentId = [self idOfBlock:parentBlock inString:nil];
					
					NSString *completedId = [DEFAULTPREPROCESSOR completeId:abbreviatedId withParentId:parentId];
					if ( [completedId isEqualToString:fragId] ) {
						tempComp = nil;
						self.textView.selectedRange = result;
						break;
					}
					NSInteger searchLocation = parentBlock.location+parentBlock.length;
					searchRange = NSMakeRange(searchLocation, self.textView.string.length -1 - searchLocation);
				} else {
					break;	//	could not found any with this pattern.
				}
			} while ( searchRange.length > 0 );
			[tempComp unshift];
			abbreviationSign = [abbreviationSign stringByAppendingString:@"#"];
		} while (tempComp.count);

	} while (0);
	self.textView.selectedRange = [self blockRangeFromLocation:self.textView.selectedRange.location inString:nil];
	if( scrollVisible )
		[self.textView scrollRangeToVisible:self.textView.selectedRange];
}

#pragma mark -
#pragma mark block range and id

/*---------------------------------------------------------------------------------
 
 block range and id
 
 returns the text range of the block of cursor position
 
 not the most beautiful algorithm in the world. maybe improve later.
 
 ----------------------------------------------------------------------------------*/

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
		return [self idOfBlock:[self blockRangeFromLocation:blockRange.location-1 inString:string] inString:string];
	}
	
	return ident;
}

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
		NSString *found = [string substringWithRange:NSMakeRange(sc.scanLocation, 1)];
		
		if ( [found isEqualToString:@"\""] )
			insideOfString = ! insideOfString;
		else if ( ! insideOfString ) {
			if ( [found isEqualToString:@"{"] )
				++nest;
			else if ( [found isEqualToString:@"}"] ) {
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

- (void)markBlockUsingHintsBefore:(NSString*)before 
							after:(NSString*)after {
	NSRange block = [self blockRangeFromLocation:before.length-1 inString:before];
	VMId *fragId = [self idOfBlock:block inString:before];
	NSLog(@"fragId:%@",fragId);
	if (self.sourceCode.length == 0)
		[self setSourceCode:DEFAULTSONG.vmsData];

	[self selectBlockWithId:fragId scrollVisible:YES];
}
/*
- (void)markBlockFromLocation:(NSUInteger)location {
	NSLog(@"markLoc: %@", [self.textView.string substringWithRange:NSMakeRange(location, 100)]);
	
	
	NSRange block = [self blockRangeFromLocation:location inString:nil];
	self.textView.selectedRange = block;
	[self.textView scrollRangeToVisible:block];
}*/

#pragma mark -
#pragma mark menu validation and find bar

- (IBAction)performTextFinderAction:(id)sender {
	self.textFinder = ARInstance(NSTextFinder);
	//self.textFinder.client = (NSTextView*)self.textView;
}

- (BOOL)validateAction:(NSTextFinderAction)action {
	return YES;
}


@end

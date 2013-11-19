//
//  VMPEditorWindowController.m
//  OnTheFly
//
//  Created by  on 13/01/28.
//  Copyright (c) 2013 sumiisan. All rights reserved.
//

#import "VMPEditorWindowController.h"
#import "VMPMacros.h"
#import "VMPSongPlayer.h"
#import "VMPreprocessor.h"
#import "VMPAnalyzer.h"
#import "VMPGraph.h"
#import "KeyCodes.h"
#import "VMPNotification.h"
#import "VMPCodeEditorView.h"
#import "VMPObjectGraphView.h"

#define FormString NSString stringWithFormat:

/*---------------------------------------------------------------------------------
 *
 *
 *	vmp field editor
 *
 *
 *---------------------------------------------------------------------------------*/
#pragma mark -
#pragma mark VMPFieldEditor
#pragma mark -
@implementation VMPFieldEditor

- (id)init {
	self = [super init];
	self.fieldEditor = YES;
	return self;
}

- (void)insertCompletion:(NSString *)word forPartialWordRange:(NSRange)charRange movement:(NSInteger)movement isFinal:(BOOL)flag {
	
    // suppress completion if user types a space
    if (movement == NSRightTextMovement) return;
	
    // show full replacements
    if (charRange.location != 0) {
        charRange.length += charRange.location;
        charRange.location = 0;
    }
	
    [super insertCompletion:word forPartialWordRange:charRange movement:movement isFinal:flag];
}

@end

/*---------------------------------------------------------------------------------
 
 VMPObjectCell
 
 ----------------------------------------------------------------------------------*/

#pragma mark -
#pragma mark VMPObjectCell
#pragma mark -

@implementation VMPObjectCell

- (NSColor*)highlightColorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
	return [NSColor alternateSelectedControlColor];
}
/*
- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
	[self.backgroundColor set];
	NSRectFill(cellFrame);
	
	[super drawInteriorWithFrame:cellFrame inView:controlView];
}
*/
- (void)dealloc {
	Dealloc( super );;
}
@end


/*---------------------------------------------------------------------------------
 
 VMPEditorWindowSplitter
 
 ----------------------------------------------------------------------------------*/

#pragma mark -
#pragma mark VMPEditorWindowSplitter

@implementation VMPEditorWindowSplitter

- (void)drawDividerInRect:(NSRect)rect {
	NSGradient *gr = [[NSGradient alloc] initWithColorsAndLocations:
					  [NSColor colorWithCalibratedWhite:0.6  alpha:1.], 0.0,
					  [NSColor colorWithCalibratedWhite:0.9  alpha:1.], 0.1,
					  [NSColor colorWithCalibratedWhite:0.75 alpha:1.], 1.,
					  nil
					  ];
	
	[gr drawInRect:rect angle:90];
	Release(gr);
}


- (CGFloat)dividerThickness {
	return 20.0;
}


@end


/*---------------------------------------------------------------------------------
 
 outline view
 
 ----------------------------------------------------------------------------------*/


@implementation VMPOutlineView

@end




/*---------------------------------------------------------------------------------
 *
 *
 *	editor view controller
 *
 *
 *---------------------------------------------------------------------------------*/
@interface VMPEditorWindowController()

//	cache
@property (nonatomic, VMStrong)	NSTreeNode						*objectRoot;
@property (nonatomic, VMStrong)	VMArray							*dataIdList;
@property (nonatomic, VMStrong)	VMHash							*referrerList;

//	incremental search
@property (nonatomic, VMStrong)	VMPFieldEditor					*fieldEditor;		//	custom field editor for searchField
@property (nonatomic, VMStrong)	NSString						*currentNonCompletedSearchString;
@property (nonatomic, VMStrong)	NSString						*currentFilterString;

//	data structure
@property (weak)				VMHash			*songData;

//	current item
@property (nonatomic, VMStrong)	VMHistory		*history;

@end


#pragma mark -
#pragma mark ** editor view controller **
#pragma mark -

@implementation VMPEditorWindowController

static VMPObjectCell		*genericCell = nil;
static VMPObjectCell		*typeColumnCell = nil;

- (id)initWithWindowNibName:(NSString *)windowNibName {
//	self = [super initWithWindowNibName:windowNibName];
	assert(0);		//	designated initializer is init
	return nil;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
	assert(0);		//	designated initializer is init
	return nil;
}

- (id)init {
	self = [super init];
	if ( self ) {
		[VMPNotificationCenter addObserver:self
								  selector:@selector(doubleClickOnFragment:)
									  name:VMPNotificationFragmentDoubleClicked
									object:nil];
		
		[VMPNotificationCenter addObserver:self
								  selector:@selector(vmsDataLoaded:)
									  name:VMPNotificationVMSDataLoaded
									object:nil];
		[VMPNotificationCenter addObserver:self
								selector:@selector(updateCurrentFragmentId:)
									  name:VMPNotificationAudioFragmentFired
									object:nil];
		[VMPNotificationCenter addObserver:self
								  selector:@selector(audioFragmentFired:)
									  name:VMPNotificationAudioFragmentFired
									object:nil];
		// Initialization code
		genericCell = [[VMPObjectCell alloc] init];
		genericCell.drawsBackground	= YES;
		genericCell.font = [NSFont systemFontOfSize:11];
		
		typeColumnCell						= [[VMPObjectCell alloc] init];
		typeColumnCell.textColor			= [NSColor whiteColor];
		typeColumnCell.drawsBackground		= YES;
		typeColumnCell.lineBreakMode		= NSLineBreakByClipping;
		typeColumnCell.font = [NSFont systemFontOfSize:11];

	}
	return self;
}

- (void)applicationDidLaunch {
	((NSView*)self.window.contentView).wantsLayer = kUseCoreAnimationLayerForEditor;
	self.objectTreeView.doubleAction = @selector(doubleClickOnRow:);
	self.history = ARInstance(VMHistory);
	
	self.editorSplitterView.flippedYCoordinate = NO;
	[self.window.contentView addSubview:self.editorSplitterView];
	self.editorSplitterView.x = 0;
	self.editorSplitterView.width = self.window.frame.size.width;
	[self splitViewDidResizeSubviews:nil];	//adjust editorSplitterView position

	self.infoView.backgroundColor = [NSColor colorForDataType:vmObjectType_unknown];
	self.infoView.needsDisplay = YES;
	
	[self.codeEditorView setup];
	[self reloadData:self];
}


- (void)dealloc {
	[VMPNotificationCenter removeObserver:self];
	VMNullify(currentDisplayingDataId);
	VMNullify(referrerList);
	VMNullify(objectRoot);
    VMNullify(history);
	VMNullify(dataIdList);
	VMNullify(fieldEditor);
	VMNullify(currentNonCompletedSearchString);
	VMNullify(currentFilterString);
	Dealloc( super );
}

#pragma mark -
#pragma mark set song data and prepare tree data
/*---------------------------------------------------------------------------------
 
 Accessor
 
 ---------------------------------------------------------------------------------*/

- (void)push:(id)data intoMember:(id)key ofHash:(VMHash*)hash {
	VMArray *arr = [hash item:key];
	if( !arr ) {
		arr = ARInstance(VMArray);
		[hash setItem:arr for:key?key:@"?"];
	}
	[arr push:( data ? data : @"?" )];
}

- (void)addChildNodesToNode:(NSTreeNode *)node children:(VMArray*)children {
    for( id child in children ) {
		VMData *childObj = nil;
		if( ClassMatch(child, VMId) ) childObj = [_songData item:child];
        [node.mutableChildNodes addObject:
		 [NSTreeNode treeNodeWithRepresentedObject:
		  childObj ? childObj : child ]];
	}
}


- (void)clearSongData {
	_songData = nil;	//	unsafe_unretained
	self.objectRoot = [NSTreeNode treeNodeWithRepresentedObject:@"ROOT"];
	
	[self.objectTreeView reloadData];
	self.referrerList = ARInstance(VMHash);
	VMNullify(dataIdList);	//	reset id cache for auto-complete
}

- (void)vmsDataLoaded:(id)sender {
	[self reloadData:self];
	if( ![self findObjectById:[self.history currentItem] action:vmp_action_select_on_reload] )
		[self selectRowAndRedrawViews:-1 withAction:vmp_action_select_on_reload];
}

- (void)reloadData:(id)sender {
	_songData = DEFAULTSONG.songData;
	self.editorWindow.title = DEFAULTSONG.songName ? DEFAULTSONG.songName : @"Untitled";
	
	VMArray *ids = [_songData sortedKeys];
	VMHash *parts = ARInstance(VMHash);
	
	for ( VMId *dataId in ids ) {
		
		if ( dataId.length > 3 && [[dataId substringToIndex:4] isEqualToString: @"VMP|"] ) continue;		//	no VMData
		
		VMData		*d = [_songData item:dataId];
		VMFragment  *f = ClassCastIfMatch(d, VMFragment);
		
		if ( f ) {
			if ( f.type == vmObjectType_audioInfo )		continue;		//	hide audioInfo.
			if ( [f.id rangeOfString:@"|"].length > 0 )	continue;		//	hide autogenerated.
			
			VMId *partId=nil, *sectionId=nil;
			[f idComponentsForPart:&partId section:&sectionId track:nil];
			
			VMHash *partHash = [parts item:partId];
			if( ! partHash ) {
				partHash = ARInstance(VMHash);
				[parts setItem:partHash for:partId ? partId : @"?"];
			}
			
			[self push:dataId intoMember:sectionId ofHash:partHash];
		}
	}
	
	//	make object tree
	self.objectRoot = [NSTreeNode treeNodeWithRepresentedObject:@"ROOT"];
	
	VMArray *partIds = [parts sortedKeys];
	for( VMId *partId in partIds ) {
		VMHash	*partHash 		= [parts item:partId];
		VMArray *sectionArray 	= [partHash sortedKeys];
		NSTreeNode *sections = [NSTreeNode treeNodeWithRepresentedObject:partId];
		for( VMId *sectionId in sectionArray ) {
			VMArray *dataArray = [partHash item:sectionId];
			if ( dataArray.count > 1 ) {
				NSTreeNode *tracks = [NSTreeNode treeNodeWithRepresentedObject:sectionId];
				[self addChildNodesToNode:tracks children:dataArray];
				[sections.mutableChildNodes addObject:tracks];
			} else {
				VMData *data = [_songData item:[dataArray item:0]];
				[sections.mutableChildNodes addObject:[NSTreeNode treeNodeWithRepresentedObject:( data ? data : [dataArray item:0] )]];
			}
		}
		[self.objectRoot.mutableChildNodes addObject:sections];
	}
	[self.objectTreeView reloadData];
	self.referrerList = [DEFAULTANALYZER collectReferrer];
	
	VMNullify(dataIdList);	//	reset id cache for auto-complete
	
}

#pragma mark -

/*---------------------------------------------------------------------------------
 
 auto complete id
 
 ----------------------------------------------------------------------------------*/
#pragma mark search: fieldEditor

//	NSWindow delegate for a custom FieldEditor (don't commit completion on tying space, _ ; etc)
- (id)windowWillReturnFieldEditor:(NSWindow *)sender toObject:(id)anObject {
	if (! self.fieldEditor )
		self.fieldEditor = ARInstance( VMPFieldEditor );
	return self.fieldEditor;
}

- (void)controlTextDidChange:(NSNotification *)obj {
	NSTextView* searchFieldEditor = [obj userInfo][@"NSFieldEditor"];

    if ( !performingAutoComplete && !handlingCommand) {	// prevent calling "complete" too often
		[self updateFilterWithString:self.currentNonCompletedSearchString
							  action:vmp_action_select_during_textSearch
			  selectWhenPartialMatch:NO];
        performingAutoComplete = YES;
        [searchFieldEditor complete:nil];
        performingAutoComplete = NO;
    }
}

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector {
    BOOL result = NO;
	
	if ([textView respondsToSelector:commandSelector]) {
        handlingCommand = YES;
        [textView performSelector:commandSelector withObject:nil];
        handlingCommand = NO;
		result = YES;
		
		if ( commandSelector == @selector(insertNewline:) )
			[self updateFilterWithString:textView.string action:vmp_action_select_on_textSearch selectWhenPartialMatch:NO];
    }
    return result;
}


- (NSArray *)control:(NSControl *)control textView:(NSTextView *)textView completions:(NSArray *)words
 forPartialWordRange:(NSRange)charRange indexOfSelectedItem:(int*)index {
    NSMutableArray	*matches = NULL;
    NSArray			*keywords;
    NSInteger		i,count;
    NSString*		string;
	
	self.currentNonCompletedSearchString = textView.string;
	NSString *searchString = textView.string;
		
	if ( ! self.dataIdList ) self.dataIdList = [self.songData sortedKeys];
    keywords      = self.dataIdList.array;
    count         = [keywords count];
    matches       = [NSMutableArray array];
	
    // find any match in our keyword array against what was typed -
	for (i=0; i< count; i++) {
        string = keywords[i];
        if ([string rangeOfString:searchString
						  options:NSAnchoredSearch | NSCaseInsensitiveSearch
							range:NSMakeRange(0, [string length])].location != NSNotFound)
		{
            [matches addObject:string];
        }
    }
    [matches sortUsingSelector:@selector(compare:)];
		
	return matches;
}

/*---------------------------------------------------------------------------------
 
 search object
 
 ----------------------------------------------------------------------------------*/
#pragma mark search: treenode
- (id)seekId:(VMId*)inId inNode:(NSTreeNode*)inNode matchedExact:(BOOL*)outMatchedExact {
	if ( inId.length == 0 ) return nil;
		
	NSTreeNode *result = nil;
	*outMatchedExact = NO;
	VMString *compareString = [inId stringByAppendingString:@"*"];
	VMArray *nodes = [VMArray arrayWithArray:inNode.childNodes];
	
	for ( id d in nodes ) {
		NSTreeNode *tn = ClassCastIfMatch( d, NSTreeNode );
		if ( !tn ) continue;
		VMId *ident = (ClassMatch( tn.representedObject, VMId) ? tn.representedObject : ((VMData*)tn.representedObject).id );
		
		if ( ! [ident isCaseInsensitiveLike:compareString] ) continue;
		result = tn;
		if ( [ident isEqualToString:inId] ) {
			*outMatchedExact = YES;
			break;
		}
	}
	return result;
}


- (id)seekPartialIdMatch:(VMId*)inId inNode:(NSTreeNode*)inNode matchedExact:(BOOL*)outMatchedExact {
	VMInt len = inId.length;
	if ( len == 0 ) return nil;
	
	NSTreeNode *result = nil;
	*outMatchedExact = NO;
	VMArray *nodes = [VMArray arrayWithArray:inNode.childNodes];
	
	for ( id d in nodes ) {
		NSTreeNode *tn = ClassCastIfMatch( d, NSTreeNode );
		if ( tn ) {
			VMId *ident = (ClassMatch( tn.representedObject, VMId) ? tn.representedObject : ((VMData*)tn.representedObject).id );
			
			if ( ident.length > len ) continue;
			VMString *compareString = [inId substringToIndex:ident.length];
			if ( [ident isCaseInsensitiveLike:compareString] ) {
				result = tn;
				*outMatchedExact = [ident isEqualToString:inId];
				break;
			}
		}
	}
	return result;
}

//
//	operations on outline view
//
#pragma mark search: outline view

//
//	just select item in object browser without updating editors
//
- (void)selectItemInObjectBrowser:(id)item {
	NSInteger row = [self.objectTreeView rowForItem:item];
	if (row==NSNotFound || row==-1) return;
	[self.objectTreeView selectRowIndexes:[NSIndexSet indexSetWithIndex:row]
					 byExtendingSelection:NO];
	[self.objectTreeView scrollRowToVisible:row];
	[self.objectTreeView reloadItem:item];

	//if( ClassMatch(item, NSTreeNode)) item = ((NSTreeNode*)item).representedObject;
}

- (void)updateButtonStates {
	[self.historyArrowButtons setEnabled:[self.history canMove:-1] forSegment:0];
	[self.historyArrowButtons setEnabled:[self.history canMove: 1] forSegment:1];
}

- (void)referrerSelected:(id)sender {
	NSMenuItem *mi = sender;
	if ( mi.tag > 0 )
		[self findObjectById:mi.title action:vmp_action_select_on_referrerList];
}

- (BOOL)expand:(id)item {
	if ( [self.objectTreeView isExpandable:item] ) {
		if (! [self.objectTreeView isItemExpanded:item] ) {
			[self.objectTreeView expandItem:item];
			[self.objectTreeView reloadData];
		}
		return YES;
	}
	return NO;
}


- (void)expandOrSelect:(id)item {
	if ( ![self expand:item] )
		[self selectItemInObjectBrowser:item];
}

/*---------------------------------------------------------------------------------
 
 incremental search
 
 ----------------------------------------------------------------------------------*/

- (IBAction)updateFilter:sender {
	NSRange  selection = self.searchField.currentEditor.selectedRange;

	NSString *searchString  = selection.location == 0
							? [self.searchField stringValue]
							: [[self.searchField stringValue] substringToIndex:selection.location];
	
	if ( ! [searchString isEqualToString:self.currentFilterString] && searchString.length > 0 )
		[self updateFilterWithString:searchString action:vmp_action_select_during_textSearch selectWhenPartialMatch:NO];
}

- (void)doubleClickOnFragment:(NSNotification*)notification {
	[self findObjectById:(notification.userInfo)[@"id"] action:vmp_action_select_on_graph];
	[self.window makeKeyAndOrderFront:self];
}

//	returns YES if some matched.
- (BOOL)findObjectById:(VMId*)dataId action:(vmp_action)action {	//	public
	return [self updateFilterWithString:dataId action:action selectWhenPartialMatch:YES];
}

//	returns YES if some matched.
- (BOOL)updateFilterWithString:(NSString*)searchString action:(vmp_action)action selectWhenPartialMatch:(BOOL)selectWhenPartialMatch {
	performingSearchFilter = YES;
	
	self.currentFilterString = searchString;
	
	NSCharacterSet *delimiterSet = [NSCharacterSet characterSetWithCharactersInString:@"_|;="];
	VMArray *comp = [VMArray arrayWithArray: [searchString componentsSeparatedByCharactersInSet:delimiterSet ]];
	
	BOOL		part_matchedExact = NO, section_matchedExact = NO, whole_matchedExact = NO, matchedExact = NO;
	VMId		*partId, *sectionId;
	NSTreeNode	*partNode = nil, *branchNode = nil;
	id			sectionNode = nil, leafData = nil;
	
	//
	//	select part
	//
	partId		= [comp unshift];
	partNode	= [self seekId:partId inNode:self.objectRoot matchedExact:&part_matchedExact];
	if ( !partNode ) goto filterStringNotFound;

	sectionId	= [comp unshift];

	if ( !sectionId ) {		//	only part id was specified
		[self selectItemInObjectBrowser:partNode];
		goto filterStringNotFound;
	}

	if ( part_matchedExact ) [self expandOrSelect:partNode];
	
	sectionNode	= [self seekId:sectionId inNode:partNode matchedExact:&section_matchedExact];
	if ( !sectionNode )
		sectionNode = [self seekId:searchString inNode:partNode matchedExact:&whole_matchedExact];
	if ( !sectionNode )
		sectionNode = [self seekId:[partId stringByAppendingFormat:@"_%@", sectionId] inNode:partNode matchedExact:&section_matchedExact];
	
	
	if ( !sectionNode ) goto filterStringNotFound;

	if ( comp.count == 0 || whole_matchedExact ) {
		//	we already have a matching section node, but check whether we have a leaf node with same id inside the node.
		leafData	= [self seekId:searchString inNode:sectionNode matchedExact:&matchedExact];
		if ( matchedExact ) {
			[self expand:sectionNode];
			[self selectItemInObjectBrowser:leafData];
			whole_matchedExact = YES;
		} else
			[self selectItemInObjectBrowser:sectionNode];

		
		goto filterStringExit;
	}
	
	if ( section_matchedExact )
		[self expandOrSelect:sectionNode];
	
	branchNode = sectionNode;
	doForever {
		leafData	= [self seekId:searchString inNode:branchNode matchedExact:&whole_matchedExact];
		if ( ! leafData )
			leafData = [self seekPartialIdMatch:searchString inNode:branchNode matchedExact:&whole_matchedExact];

		if ( !ClassMatch( leafData, NSTreeNode ) ) break;
		branchNode = leafData;
		[self expand:branchNode];
		if ( whole_matchedExact || selectWhenPartialMatch ) {
			[self selectItemInObjectBrowser:leafData];
			break;
		}
	}
filterStringExit:
	performingSearchFilter = NO;
	if ( whole_matchedExact || selectWhenPartialMatch ) [self selectRowAndRedrawViews:self.objectTreeView.selectedRow withAction:action];
	return whole_matchedExact;
	
filterStringNotFound:
	performingSearchFilter = NO;
	return NO;
}

#pragma mark -
#pragma mark data access util
/*---------------------------------------------------------------------------------
 
 NSOutlineViewDataSource
 
 ---------------------------------------------------------------------------------*/

/*
 Subs
 */

- (VMData*)dataOfRow:(VMInt)row {
	id item = [self.objectTreeView itemAtRow:row];
	
	if ( ClassMatch(item, NSTreeNode) ) {
		item = [((NSTreeNode*)item) representedObject];
	}
	VMData *d = ClassCastIfMatch(item, VMData);
	if ( ClassMatch(item, VMId) ) d = [_songData item:item];
	return d;
}

//	item can be NSTreeNode or VMData object. if nil was passed, it will be recognized as root object.
- (VMArray*)childrenOfItem:(id)item {
	
	if ( ! item ) return [VMArray arrayWithArray:self.objectRoot.childNodes];
	
	if ( ClassMatch(item, NSTreeNode)) {
		id ro = [((NSTreeNode*)item) representedObject];
		if ( ! ClassMatch( ro, VMData ) )	//	represented object is not VMData, assume some string: (branch node)
			return [VMArray arrayWithArray:((NSTreeNode*)item).childNodes];
			
		item = ro;
	}
	
	if ( ClassMatch(item, VMReference) ) {
		return [VMArray arrayWithObject:((VMReference*)item).referenceId];
	}
	if ( ClassMatch(item, VMCollection) ) {
		VMArray *arr = [VMArray arrayWithArray:((VMCollection*)item).fragments];
		if ( ClassMatch(item, VMSequence) && ((VMSequence*)item).subsequent)
			[arr push:((VMSequence*)item).subsequent];
		return arr;
	}
	if ( ClassMatch(item, VMAudioFragment)) {
		return [VMArray arrayWithObject:((VMAudioFragment*)item).audioInfoRef];
	}
	if ( ClassMatch(item, VMArray) ) {
		return item;
	}
	
	return nil;
}


- (VMString*)descriptionForData:(VMData*)data {
	
	switch ((int)data.type) {
		case vmObjectType_reference:
		case vmObjectType_unresolved:	{
			MakeVarByCast(d, data, VMReference)
			return [FormString @"->%@",d.referenceId]; 
			break;
		}
		case vmObjectType_audioInfo: {
			MakeVarByCast(d, data, VMAudioInfo)
			return [FormString 
					@"fileId:\"%@\" (dur:%@%@)%@%@",
					d.fileId,
					d.cuePoints.lengthDescriptor,
					(d.cuePoints.locationDescriptor
					 ? [FormString @" ofs:%@",
						d.cuePoints.locationDescriptor]
					 : @"" ),
					((d.regionRange.location != 0 || d.regionRange.length != 0 )
					 ?	[FormString @" playback:(%@ - %@)",
						 d.regionRange.locationDescriptor,
						 d.regionRange.lengthDescriptor]
					 : @"" ),
					(d.instructionList 
					 ? [FormString @" inst:[%@]",
						[d.instructionList join:@","]]
					 : @"" )
					]; 
			break;
		}
		case vmObjectType_audioFragment: {
			MakeVarByCast(d, data, VMAudioFragment)
			return [FormString
					@"%@",
					(d.instructionList 
					 ? [FormString @" inst:[%@]",
						[d.instructionList join:@","]]
					 : @"" )
					];
		}
		case vmObjectType_chance: {
			MakeVarByCast(d, data, VMChance)
			return [FormString
					@"score: %@ -> %@",
					d.scoreDescriptor ? d.scoreDescriptor : @"*",
					d.targetId
					];
		}
		case vmObjectType_selector: {
			MakeVarByCast(d, data, VMSelector)
			return [FormString
					@"%ldfragment%@%@",
					d.length,
					(d.length > 1 ? @"s" : @""),
					(d.instructionList 
					 ? [FormString @" inst:[%@]",
						[d.instructionList join:@","]]
					 : @"" )
					];
		}
		case vmObjectType_sequence: {
			MakeVarByCast(d, data, VMSequence)
			return [FormString
					@"%ldfragment%@%@",
					d.length,
					(d.length > 1 ? @"s" : @""),
					(d.instructionList 
					 ? [FormString @" inst:[%@]",
						[d.instructionList join:@","]]
					 : @"" )
					];
		}
		default: {
			VMArray *arr = [VMArray arrayWithString:[data description] 
											splitBy:@">"];
			return [arr item:1];
		}
	}	
	return @"";
	
}

#pragma mark -
#pragma mark chase sequence
- (void)audioFragmentFired:(NSNotification*)notification {
	if( ! self.chaseSequence ) return;
	[self.graphView chaseSequence:(notification.userInfo)[@"audioFragment"]];
}

#pragma mark -
#pragma mark splitter view

- (BOOL)splitView:(NSSplitView *)splitView canCollapseSubview:(NSView *)subview {
	//if ( subview == self.graphView ) return YES;
	return YES;
}

- (BOOL)splitView:(NSSplitView *)splitView shouldCollapseSubview:(NSView *)subview
forDoubleClickOnDividerAtIndex:(NSInteger)dividerIndex  {
//	if ( subview == self.graphView ) return YES;
	return YES;
}

- (void)splitViewDidResizeSubviews:(NSNotification *)notification {
	CGFloat graphViewHeight = ([((VMPEditorWindowSplitter*)notification.object) isSubviewCollapsed:self.graphView ]
							   ? 0
							   : self.graphView.height );
	self.editorSplitterView.y = ((NSView*)self.window.contentView).frame.size.height - graphViewHeight - 47;
}

- (void)updateCurrentFragmentId:(NSNotification*)notification {
	self.currentFragmentIdButton.title = ((VMAudioFragment*)(notification.userInfo)[@"audioFragment"]).id;
}

- (IBAction)buttonClicked:(id)sender {
	if ( sender == self.currentFragmentIdButton ) {
		[self findObjectById:((NSButton*)sender).title action:vmp_action_select_current_fragment];
	}
	
	if ( sender == self.scoreToggleButton ) {
		self.useStatisticScores = ( self.scoreToggleButton.state == 1 );
		vmObjectType type = ((VMData*)[DEFAULTSONG data:self.currentDisplayingDataId]).type;
		if ( type == vmObjectType_selector || type == vmObjectType_sequence ) {
			self.graphView.selectorDataSource =
				( self.useStatisticScores ? VMPSelectorDataSource_Statistics : VMPSelectorDataSource_StaticVMS );
			[self.graphView redraw];
		}
	}
	
	if ( sender == self.chaseToggleButton ) {
		self.chaseSequence = ( self.chaseToggleButton.state == 1 );
		if ( self.chaseSequence && DEFAULTSONGPLAYER.lastFiredFragment ) {
			[VMPNotificationCenter postNotificationName:VMPNotificationStartChaseSequence
												 object:self
											   userInfo:@{@"audioFragment":DEFAULTSONGPLAYER.lastFiredFragment  } ];
		}
	}
	
}


#pragma mark -
#pragma mark outlineview datasorce and delegate

/* 
 Required methods
 */
- (id)outlineView:(NSOutlineView *)outlineView 
			child:(NSInteger)index 
		   ofItem:(id)item {
	if ( ! _songData ) return nil;
	
	VMArray	*children = ( !item ) ? [VMArray arrayWithArray: _objectRoot.childNodes] : [self childrenOfItem:item];
	id		childObj  = children ? [children item:index] : nil;
	
	//	child is reference
	if ( ! ClassMatch( childObj, NSTreeNode ) ) {
		//	try to convert children into NSTreeNodes:
		NSTreeNode *node = ClassCastIfMatch(item, NSTreeNode);
		if (node) {
			[self addChildNodesToNode:node children:children];
			childObj = (node.childNodes)[index];
		} else {
			//	no parent node : return bare VMData			//	should not happen: just a fallback // remove in future
			if ( ClassMatch( childObj, VMId ))
				childObj = [_songData item:childObj];		//	convert ref into object
		}
	}
	
	return childObj;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
	return ( [self childrenOfItem:item] != nil );
}

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item {
	return ( [[self childrenOfItem:item] count] );
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn
		   byItem:(id)item {
	if (ClassMatch(item, NSTreeNode) ) 
		item = [((NSTreeNode*)item) representedObject];
	
	
	VMInt col = [tableColumn.identifier intValue];
	switch (col) {
		case 1: {	//	id column
			if ( ClassMatch(item, VMId) )
				return item;
			if ( ClassMatch(item, VMReference))
				return [NSString stringWithFormat:@"->%@", ((VMReference*)item).referenceId];
			if ( ClassMatch(item, VMData ) )
				return ((VMData*)item).id;
			break;
		}

		case 2: {	//	description column
			VMData *d = ClassCastIfMatch(item, VMData);
			if ( ClassMatch(item, VMId) ) d = [_songData item:item];
			return [self descriptionForData:d];
		}

		case 3: {	//	comments column
			if ( ClassMatch(item, VMId) ) return @"";
			VMData *d = ClassCastIfMatch(item, VMData);
			if ( ClassMatch(item, VMId) ) d = [_songData item:item];
			if ( d ) return d.comment;
			break;
		}
			
		case 4:	{	//	type column
			VMData *d = ClassCastIfMatch(item, VMData);
			if ( ClassMatch(item, VMId) ) d = [_songData item:item];
			if ( d ) {
				return [DEFAULTPREPROCESSOR->shortTypeStringForType 
						item:VMIntObj(d.type)]; 
			} else {
				return @"";
			}
		}

	}
	
	return @"(unavailable)";
}

- (void)outlineView:(NSOutlineView *)outlineView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn byItem:(id)item {
	VMInt col = [tableColumn.identifier intValue];
	switch (col) {
		case 3: {	//	comments row	
			if (ClassMatch(item, NSTreeNode) ) item = [((NSTreeNode*)item) representedObject];
			VMData *d = ClassCastIfMatch(item, VMData);
			if( d ) d.comment = object;
		}
	}
}

- (NSCell *)outlineView:(NSOutlineView *)outlineView dataCellForTableColumn:(NSTableColumn *)tableColumn item:(id)item {
	if ( ! tableColumn ) return nil;
	VMInt col = [tableColumn.identifier intValue];
	
	if (ClassMatch(item, NSTreeNode) ) item = [((NSTreeNode*)item) representedObject];
	VMData *d = ClassCastIfMatch(item, VMData);
	if ( ClassMatch(item, VMId) ) d = [_songData item:item];
	vmObjectType type = d ? d.type : 0;	
	
	if (col == 4) {	//	type row
		NSColor *bgColor 				= [NSColor colorForDataType:type];
		typeColumnCell.backgroundColor	= bgColor ? bgColor : outlineView.backgroundColor;
		return typeColumnCell;
	} else {
		NSColor *bgColor				= [NSColor backgroundColorForDataType:type];
		genericCell.backgroundColor		= bgColor ? bgColor : outlineView.backgroundColor;
		return genericCell;
	}
}

#pragma mark -
#pragma mark actions

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
	SEL action = menuItem.action;
	
	if ( action == @selector(zoomIn:) || action == @selector(zoomOut:) ) {
		VMData *selectedFrag = [DEFAULTSONG data:[self.history currentItem]];
		if ( !selectedFrag ) return NO;
		if (   selectedFrag.type != vmObjectType_audioFragment
			&& selectedFrag.type != vmObjectType_audioFragmentPlayer
			&& selectedFrag.type != vmObjectType_audioInfo
			) return NO;
	}
	
	if ( action == @selector(moveHistoryBack:)) {
		return [self.history canMove:-1];
	} else if ( action == @selector(moveHistoryForward:)) {
		return [self.history canMove: 1];
	}
		
	return YES;	//	the default
}

- (IBAction)focusTextSearchField:(id)sender {
	[self.window makeKeyAndOrderFront:sender];
	[self.searchField becomeFirstResponder];
}


/*---------------------------------------------------------------------------------
 
 selectRowAndRedrawViews - internally set the row selected and update editors accordingly.
 
 ----------------------------------------------------------------------------------*/

- (void)selectRowAndRedrawViews:(VMInt)row withAction:(vmp_action)action {

	VMData *d = ( row >= 0 ? [self dataOfRow:row] : nil );
	if ( d || row < 0 ) {
		//
		// row with VMData was selected.
		//
		if ( [self.currentDisplayingDataId isEqualToString:d.id] )
			return;	//	don't select twice.

		self.currentDisplayingDataId = d.id;
		//
		//	memory and notify selected id.
		//
		//	notify
		if( d.id ) {	//	chances may not have id
			[VMPNotificationCenter postNotificationName:VMPNotificationFragmentSelected object:self userInfo:@{@"id":d.id}];
			if ( ! performingHistoryMove )
				[self.history push:d.id];
		}
		
		//
		//	update editors
		//
		signed char direction = action & 0xff;
		[_graphView drawGraphWith:((d.type != vmObjectType_chance)
								   ? d
								   : [DEFAULTSONG data:((VMChance*)d).targetId] )
			   animationDirection:direction
		 ];
		[_infoView drawInfoWith:d];
		[self updateReferrerPullDown:d.id];

	} else {
		//
		// row with NSTreeNode was selected. 
		//
		id item = [self.objectTreeView itemAtRow:row];
		if ( ClassMatch(item, NSTreeNode))
			item = ((NSTreeNode*)item).representedObject;
		
		if ( ClassMatch( item, VMString ) ) {
			[self.history push:item];
			self.currentDisplayingDataId = item;
		}
	}
	
	[self updateButtonStates];
}

- (void)updateReferrerPullDown:(VMId*)dataId {
	//
	//	referrer pulldown
	//
	[self.referrerMenu removeAllItems];
	NSMenuItem *menuItem = AutoRelease([[NSMenuItem alloc] initWithTitle:@"-- referrer --"
													   action:@selector(referrerSelected:)
												keyEquivalent:@""] );
	[self.referrerMenu addItem:menuItem];
	VMArray *keys = [self referrerListForId:dataId];
	int p = 0;
	for( VMId *fid in keys ) {
		menuItem = AutoRelease([[NSMenuItem alloc] initWithTitle:fid
											   action:@selector(referrerSelected:)
										keyEquivalent:@""] );
		menuItem.target = self;
		menuItem.tag = ++p;
		[self.referrerMenu addItem:menuItem];
	}
}

- (VMArray*)referrerListForId:(VMId*)dataId {	
	return [[self.referrerList itemAsHash:dataId] sortedKeys];
}

- (IBAction)clickOnRow:(id)sender {
	[self selectRowAndRedrawViews:self.objectTreeView.clickedRow withAction:vmp_action_select_on_browser];
}

- (IBAction)doubleClickOnRow:(id)sender {
	VMInt row = self.objectTreeView.clickedRow;
	VMData *d = [self dataOfRow:row];
	if (d) {
		if ( d.type == vmObjectType_chance) {
			VMId *targetId = ((VMChance*)d).targetId;
			[self.objectTreeView collapseItem:[self.objectTreeView itemAtRow:row]];
			[self findObjectById:targetId action:vmp_action_select_on_browser];
		}
	}
}


- (IBAction)historyButtonClicked:(id)sender {
	NSSegmentedCell *sc = sender;
	if ( sc.selectedSegment == 0 )
		[self moveHistoryBack:self];
	if ( sc.selectedSegment == 1 )
		[self moveHistoryForward:self];
}

- (IBAction)moveHistoryBack:(id)sender {
	[self.history move:-1];
	performingHistoryMove = YES;
	if ( ![self findObjectById:[self.history currentItem] action:vmp_action_move_back] ) {
		[self selectItemInObjectBrowser:[self.history currentItem]];
	}
	performingHistoryMove = NO;
	[self updateButtonStates];
}

- (IBAction)moveHistoryForward:(id)sender {
	[self.history move: 1];
	performingHistoryMove = YES;
	if ( ![self findObjectById:[self.history currentItem] action:vmp_action_move_next] ) {
		[self selectItemInObjectBrowser:[self.history currentItem]];
	}
	performingHistoryMove = NO;
	[self updateButtonStates];
}

//	generalized zoom action		--	defaults firstResponder
- (IBAction)zoomIn:(id)sender {}
- (IBAction)zoomOut:(id)sender {}


//	insert fragment
- (IBAction)insertFragment:(id)sender {}

//	toggle iOSAppState
- (IBAction)toggleIOSAppState:(id)sender {
	NSMenuItem *mi = sender;
	mi.state = NSOnState - mi.state;
	DEFAULTSONGPLAYER.simulateIOSAppBackgroundState = ( mi.state == NSOnState );
}


#pragma mark type select

- (NSString*)outlineView:(NSOutlineView *)outlineView typeSelectStringForTableColumn:(NSTableColumn *)tableColumn item:(id)item {
	VMInt col = [tableColumn.identifier intValue];
	if ( col != 1 ) return nil;
	
	if (ClassMatch(item, NSTreeNode) )
		item = [((NSTreeNode*)item) representedObject];
	
	if ( ClassMatch(item, VMId	 ))	return item;
	if ( ClassMatch(item, VMData ))	return ((VMData*)item).id;

	return nil;
}

- (IBAction)songPlay:(id)sender {
	VMId *dataId = [self.history currentItem];
	if ( [dataId rangeOfString:@"_"].length == 0 )
		dataId = [dataId stringByAppendingString:@"_sel"];	//	assume part id.

	VMData *d = [DEFAULTSONG data:dataId];
	if (d.type == vmObjectType_sequence ||
		d.type == vmObjectType_selector ||
		d.type == vmObjectType_audioFragment ||
		d.type == vmObjectType_audioFragmentPlayer
		) {
		[DEFAULTSONGPLAYER startWithFragmentId:d.id];
	}

}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldTypeSelectForEvent:(NSEvent *)event withCurrentSearchString:(NSString *)searchString {
	if ( event.type == NSKeyDown && event.keyCode == kVK_Space ) {
		[self songPlay:self];
		return NO;
	}
	
	if ( [searchString hasPrefix:@" "]) return NO;
	return YES;
}

- (void)outlineViewSelectionDidChange:(NSNotification *)notification {
	if ( ! performingSearchFilter && ! performingHistoryMove )
		[self selectRowAndRedrawViews:self.objectTreeView.selectedRow withAction:vmp_action_move_browser_row];
	
}

#pragma mark -
#pragma mark VMPAnalyzer delegate
//	VMPAnalyzer delegate
- (void)analysisFinished:(VMHash*)report {
	[_graphView drawReportGraph:report];
}








@end

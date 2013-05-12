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
	[super dealloc];
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
								  selector:@selector(reloadData:)
									  name:VMPNotificationVMSDataLoaded
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
	self.objectTreeView.doubleAction = @selector(doubleClickOnRow:);
	[self.codeEditorView setup];
	[self reloadData:self];
	
	return;
	//test
	
	[self.infoView removeFromSuperview];
	[self.graphView removeFromSuperview];
	self.infoView = nil;
	self.graphView = nil;
}


- (void)dealloc {
	[VMPNotificationCenter removeObserver:self];
	self.referrerList = nil;
	self.objectRoot = nil;
    self.lastSelectedId = nil;
	self.dataIdList = nil;
	self.fieldEditor = nil;
	self.currentNonCompletedSearchString = nil;
	self.currentFilterString = nil;
	[super dealloc];
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

- (VMHash*)songData {
	return _songData;
}

- (void)setSongData:(VMHash *)inSongData {
	_songData = inSongData;	//	weak ref
	[self reloadData:self];
}

- (void)reloadData:(id)sender {
	_songData = DEFAULTSONG.songData;
	self.editorWindow.title = DEFAULTSONG.songName ? DEFAULTSONG.songName : @"Untitled";
	
	VMArray *ids = [_songData sortedKeys];
	VMHash *parts = ARInstance(VMHash);
	
	for ( VMId *dataId in ids ) {
		
		if ( [[dataId substringToIndex:4] isEqualToString: @"VMP|"] ) continue;		//	no VMData
		
		VMData *d   = [_songData item:dataId];
		VMFragment  *c   = ClassCastIfMatch(d, VMFragment);
		
		if( d ) {
			if ( c ) {
				if ( c.type == vmObjectType_audioInfo ) continue;		//	hide audioInfo.
				if ( c.VMPModifier )					continue;		//	hide autogenerated.
				
				VMId *partId 	= c.partId;
				VMId *sectionId = c.sectionId;
				
				VMHash *partHash = [parts item:partId];
				if( ! partHash ) {
					partHash = ARInstance(VMHash);
					[parts setItem:partHash for:partId?partId:@"?"];
				}
				
				[self push:dataId intoMember:sectionId ofHash:partHash];
				
			}
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
	NSTextView* textView = [[obj userInfo] objectForKey:@"NSFieldEditor"];

    if ( !performingAutoComplete && !handlingCommand) {	// prevent calling "complete" too often
		[self updateFilterWithString:self.currentNonCompletedSearchString];
        performingAutoComplete = YES;
        [textView complete:nil];
        performingAutoComplete = NO;
    } else {
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
			[self updateFilterWithString:textView.string];
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
        string = [keywords objectAtIndex:i];
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
		if ( tn ) {
			VMId *ident = (ClassMatch( tn.representedObject, VMId) ? tn.representedObject : ((VMData*)tn.representedObject).id );

			if ( [ident isCaseInsensitiveLike:compareString] ) {
				result = tn;
				*outMatchedExact = [ident isEqualToString:inId];
				break;
			}
		}
	}
	return result;
}


- (id)reverseSeekId:(VMId*)inId inNode:(NSTreeNode*)inNode matchedExact:(BOOL*)outMatchedExact {
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
- (void)selectItem:(id)item {
	NSInteger row = [self.objectTreeView rowForItem:item];
	if (row==NSNotFound || row==-1) return;
	[self.objectTreeView selectRowIndexes:[NSIndexSet indexSetWithIndex:row]
					 byExtendingSelection:NO];
	[self.objectTreeView scrollRowToVisible:row];
	[self.objectTreeView reloadItem:item];

	if( ClassMatch(item, NSTreeNode)) item = ((NSTreeNode*)item).representedObject;
	
	VMData *d = ClassCastIfMatch( item, VMData );
	if ( d )
		self.lastSelectedId = d.id;
}

- (void)referrerSelected:(id)sender {
	NSMenuItem *mi = sender;
	if ( mi.tag > 0 )
		[self updateFilterWithString:mi.title];
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
		[self selectItem:item];
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
		[self updateFilterWithString:searchString];
}

- (void)doubleClickOnFragment:(NSNotification*)notification {
	[self findObjectById:[ notification.userInfo objectForKey:@"id"]];
}

- (void)findObjectById:(VMId*)dataId {	//	public
	[self updateFilterWithString:dataId];
	[self.window makeKeyAndOrderFront:self];
}

- (void)updateFilterWithString:(NSString*)searchString {
	self.currentFilterString = searchString;
	
	NSCharacterSet *delimiterSet = [NSCharacterSet characterSetWithCharactersInString:@"_|;="];
	VMArray *comp = [VMArray arrayWithArray: [searchString componentsSeparatedByCharactersInSet:delimiterSet ]];
	
	BOOL		part_matchedExact = NO, section_matchedExact = NO, whole_matchedExact = NO;
	VMId		*partId, *sectionId;
	NSTreeNode	*partNode = nil;
	id			sectionNode = nil, leafData = nil;
	
	//
	//	select part
	//
	partId		= [comp unshift];
	partNode	= [self seekId:partId inNode:self.objectRoot matchedExact:&part_matchedExact];
	if ( !partNode ) return;

	sectionId	= [comp unshift];

	if ( !sectionId ) {		//	only part id was specified
		[self selectItem:partNode];
		return;
	}

	if ( part_matchedExact ) [self expandOrSelect:partNode];
	
	sectionNode	= [self seekId:sectionId inNode:partNode matchedExact:&section_matchedExact];
	if ( !sectionNode )
		sectionNode = [self seekId:searchString inNode:partNode matchedExact:&whole_matchedExact];
	if ( !sectionNode )
		sectionNode = [self seekId:[partId stringByAppendingFormat:@"_%@", sectionId] inNode:partNode matchedExact:&section_matchedExact];
	
	
	if ( !sectionNode ) return;

	if ( comp.count == 0 || whole_matchedExact ) [self selectItem:sectionNode];
	
	if ( section_matchedExact || whole_matchedExact ) [self expandOrSelect:sectionNode];
	
	if ( ClassMatch(sectionNode, VMData) ) {
		assert(0);
		return;	//	do not seek inside bare VMData.	should not happen since we create NSTreeNodes on the fly
	}

	NSTreeNode *branchNode = sectionNode;
	doForever {
		leafData	= [self seekId:searchString inNode:branchNode matchedExact:&whole_matchedExact];
		if ( ! leafData )
			leafData = [self reverseSeekId:searchString inNode:branchNode matchedExact:&whole_matchedExact];

		if ( !ClassMatch( leafData, NSTreeNode ) ) break;
		branchNode = leafData;
		[self expand:branchNode];
		if ( whole_matchedExact ) [self selectItem:leafData];
	}
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

//	item can be NSTreeNode or VMData object.
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
			childObj = [node.childNodes objectAtIndex:index];
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
		case 1: {	//	id row
			if ( ClassMatch(item, VMId) )
				return item;
			if ( ClassMatch(item, VMReference))
				return [NSString stringWithFormat:@"->%@", ((VMReference*)item).referenceId];
			if ( ClassMatch(item, VMData ) )
				return ((VMData*)item).id;
			break;
		}

		case 2: {	//	description row
			VMData *d = ClassCastIfMatch(item, VMData);
			if ( ClassMatch(item, VMId) ) d = [_songData item:item];
			return [self descriptionForData:d];
		}

		case 3: {	//	comments row
			if ( ClassMatch(item, VMId) ) return @"";
			VMData *d = ClassCastIfMatch(item, VMData);
			if ( ClassMatch(item, VMId) ) d = [_songData item:item];
			if ( d ) return d.comment;
			break;
		}
			
		case 4:	{	//	type row
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
		vmObjectType type = ((VMData*)[DEFAULTSONG data:self.lastSelectedId]).type;
		if ( type != vmObjectType_audioFragment && type != vmObjectType_audioInfo ) return NO;
	}
	
	if ( action == @selector(moveHistoryBack:) || action == @selector(moveHistoryForward:)) {
		return NO;	//	currently not supported
	}
		
	return YES;	//	the default
}

- (IBAction)focusTextSearchField:(id)sender {
	[self.window makeKeyAndOrderFront:sender];
	[self.searchField becomeFirstResponder];
}


/*---------------------------------------------------------------------------------
 
 selectRow - internally set the row selected and update editors accordingly.
 
 ----------------------------------------------------------------------------------*/

- (void)selectRow:(VMInt)row {
	VMData *d = [self dataOfRow:row];
	if (d) {
		//
		// row with VMData was selected.
		//
		if ( [self.lastSelectedId isEqualToString:d.id] )
			return;	//	don't select twice.
		
		//
		//	memory and notify selected id.
		//
        self.lastSelectedId = d.id;
		//	notify
		if( d.id )	//	chances may not have id
			[VMPNotificationCenter postNotificationName:VMPNotificationFragmentSelected object:self userInfo:@{@"id":d.id}];
		
		//
		//	update editors
		//
		[_graphView drawGraphWith:((d.type != vmObjectType_chance)
										   ? d
										   : [DEFAULTSONG data:((VMChance*)d).targetId] )];
		[_infoView drawInfoWith:d];
		
		//
		//	referrer pulldown
		//
		[self.referrerMenu removeAllItems];
		NSMenuItem *menuItem = [[[NSMenuItem alloc] initWithTitle:@"-- referrer --"
														   action:@selector(referrerSelected:)
													keyEquivalent:@""] autorelease];
		[self.referrerMenu addItem:menuItem];
		VMArray *keys = [[self.referrerList itemAsHash:d.id] sortedKeys];
		int p = 0;
		for( VMId *fid in keys ) {
			menuItem = [[[NSMenuItem alloc] initWithTitle:fid
												   action:@selector(referrerSelected:)
											keyEquivalent:@""] autorelease];
			menuItem.target = self;
			menuItem.tag = ++p;
			[self.referrerMenu addItem:menuItem];
		}

	} else {
		//
		// row with NSTreeNode was selected. 
		//
		id item = [self.objectTreeView itemAtRow:row];
		if ( ClassMatch(item, NSTreeNode))
			item = ((NSTreeNode*)item).representedObject;
		
		if ( ClassMatch( item, VMString ) )
			self.lastSelectedId = item;
	}
}


- (IBAction)clickOnRow:(id)sender {
	[self selectRow:self.objectTreeView.clickedRow];
}

- (IBAction)doubleClickOnRow:(id)sender {
	VMInt row = self.objectTreeView.clickedRow;
	VMData *d = [self dataOfRow:row];
	if (d) {
		if ( d.type == vmObjectType_chance) {
			VMId *targetId = ((VMChance*)d).targetId;
			[self.objectTreeView collapseItem:[self.objectTreeView itemAtRow:row]];
			[self updateFilterWithString:targetId];
		}
	}
}


//	unimplemented

- (IBAction)moveHistoryBack:(id)sender {}
- (IBAction)moveHistoryForward:(id)sender {}

//	generalized zoom action		--	defaults firstResponder
- (IBAction)zoomIn:(id)sender {}
- (IBAction)zoomOut:(id)sender {}

#pragma mark type select

- (NSString*)outlineView:(NSOutlineView *)outlineView typeSelectStringForTableColumn:(NSTableColumn *)tableColumn item:(id)item {
	if (ClassMatch(item, NSTreeNode) )
		item = [((NSTreeNode*)item) representedObject];
	
	VMInt col = [tableColumn.identifier intValue];
	if ( col != 1 ) return nil;
	
	if ( ClassMatch(item, VMId	 ))	return item;
	if ( ClassMatch(item, VMData ))	return ((VMData*)item).id;

	return nil;
}

- (IBAction)songPlay:(id)sender {
	if (sender != self)
		NSLog(@"just wanted to know");
	VMData *d = [DEFAULTSONG data:self.lastSelectedId];
	if ( d.type == vmObjectType_sequence || d.type == vmObjectType_selector || d.type == vmObjectType_audioFragment ) {
		[DEFAULTSONGPLAYER startWithFragmentId:self.lastSelectedId];
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
	[self selectRow:self.objectTreeView.selectedRow];
}	

#pragma mark -
#pragma mark VMPAnalyzer delegate
//	VMPAnalyzer delegate
- (void)analysisFinished:(VMHash*)report {
	[_graphView drawReportGraph:report];
}








@end

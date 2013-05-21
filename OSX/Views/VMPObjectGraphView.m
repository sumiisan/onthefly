//
//  VMPObjectGraphView.m
//  OnTheFly
//
//  Created by sumiisan on 2013/05/03.
//
//

#import "VMPObjectGraphView.h"
#import "VMSong.h"
#import "VMPAudioInfoEditorViewController.h"
#import "VMPSelectorEditorViewController.h"
#import "VMPNotification.h"
#import "VMScoreEvaluator.h"
#import "VMPMacros.h"
#import "VMPreprocessor.h"
#import "VMPlayerOSXDelegate.h"






/*---------------------------------------------------------------------------------
 *
 *
 *	selector graph
 *
 *
 *---------------------------------------------------------------------------------*/

#pragma mark -
#pragma mark *** Selector Graph ***
#pragma mark -

@implementation VMPSelectorGraph

- (id)initWithFrame:(NSRect)frameRect {
	self = [super initWithFrame:frameRect];
	if (self ) {
		line = [[VMPStraightLine alloc] initWithFrame:NSMakeRect(0, 0, 0, 0)];
		line.foregroundColor = [NSColor grayColor];
		line.backgroundColor = [NSColor redColor];
	}
	return self;
}

- (void)dealloc {
	Release(branchViewTemporary);
	Release(line);
	Dealloc( super );;
}

/*---------------------------------------------------------------------------------
 
 branch graph
 
 ----------------------------------------------------------------------------------*/
#pragma mark branch graph
//	TODO: statistics mode / use statistical scores

- (CGFloat)gapBetweenTypes:(int)type1 and:(int)type2 {
	//if( type1 == vmObjectType_selector && type2 == vmObjectType_selector ) return 10.;
	//return 55.;
	return 50;
}

- (void)collectBranchData:(VMFragment*)frag x:(CGFloat)x gapX:(CGFloat)gapX height:(VMFloat)height {
	//NSLog(@"%@ \tx:%.2f",frag.id,x);
	x += gapX + vmpCellWidth;
	if (( x >= (self.frame.size.width - vmpCellWidth) ) || height < 1 ) return;
	
	VMHash *hashAtX = [branchViewTemporary item:@( x )];
	if ( ! hashAtX ) {
		hashAtX = ARInstance(VMHash);
		[branchViewTemporary setItem:hashAtX for:@( x )];
	}
	[hashAtX add:height ontoItem:frag.id];

	vmObjectType parentType = frag.type;
	frag = [self selectSubsequentFragmentOf:frag];

	if ( frag.type == vmObjectType_selector ) {
		
		VMLiveData *liveDataCache = nil;
		VMSelector *sel = nil;
		
		if ( _dataSource == VMPSelectorDataSource_StaticVMS ) {
			//	use static vms data
			sel	= (VMSelector*)frag;
			liveDataCache = AutoRelease([sel.liveData copy]);
			sel.liveData = nil;	//	TEST	reset liveData before evaluation
		} else {
			//	use statistics
			sel = [DEFAULTANALYZER makeSelectorFromStatistics:frag.id];
		}
		
		[sel prepareSelection];
		if ( [sel sumOfInnerScores] == 0 ) return;
		
		for( VMChance *ch in sel.fragments ) {
			if ( ch.cachedScore == 0 ) continue;
			VMFragment *c = [DEFAULTSONG data:ch.targetId];
			if( c )
				[self collectBranchData:c
									  x:x
								   gapX:[self gapBetweenTypes:c.type and:parentType]
								 height:height / sel.sumOfInnerScores * ch.cachedScore ];
		}
		
		if ( liveDataCache )
			sel.liveData = liveDataCache;
	}
}




- (void)drawBranchGraph:(VMFragment*)frag
		   parentPartId:(VMId*)parentPartId
					  x:(CGFloat)x
					  y:(CGFloat)y
				   gapX:(CGFloat)gapX
		  parentCenterY:(CGFloat)parentCenterY
				 height:(CGFloat)summedHeight {
	x += gapX + vmpCellWidth;
	if ( x >= (self.frame.size.width - vmpCellWidth) ) return;

	VMHash		*hashAtX = [branchViewTemporary item:@( x )];
	VMString	*yPositionKey = [frag.id stringByAppendingString:@"_y"];
	CGFloat		yAlreadyDrawn = [hashAtX itemAsFloat:yPositionKey];
	BOOL		drawChildren = NO;

	if ( yAlreadyDrawn == 0 ) {
		if ( summedHeight < 3 ) return;
		CGFloat moddedYBase = [hashAtX itemAsFloat:@"moddedYBase"];
		if ( moddedYBase == 0 )
			yAlreadyDrawn = y + 0.01;
		else
			yAlreadyDrawn = moddedYBase + 0.01;
		
		[hashAtX setItem:VMFloatObj(yAlreadyDrawn + summedHeight) for:@"moddedYBase"];
		[hashAtX setItem:VMFloatObj(yAlreadyDrawn) for:[frag.id stringByAppendingString:@"_y"]];
	
		[self addSubview:[VMPFragmentCell fragmentCellWithFragment:frag
															  frame:CGRectMake(x, yAlreadyDrawn, vmpCellWidth, summedHeight)
														   delegate:self]];
		drawChildren = YES;
	}
	
	CGFloat myCenterY = (int)(yAlreadyDrawn + summedHeight * 0.5);
	line.point1 = NSMakePoint(x - gapX, parentCenterY );
	line.point2 = NSMakePoint(x, myCenterY);
	line.foregroundColor = [frag.partId isEqualToString:parentPartId] ? [NSColor darkGrayColor] : [NSColor redColor];
	[self addSubview:[line clone]];
	
	if ( ! drawChildren ) return;
	
	vmObjectType parentType = frag.type;
	frag = [self selectSubsequentFragmentOf:frag];
	
	if ( frag.type == vmObjectType_selector ) {
		VMSelector *sel = (VMSelector*)frag;
		CGFloat currentY = y;
		for( VMChance *ch in sel.fragments ) {
			VMFragment *fr = [DEFAULTSONG data:ch.targetId];
			VMFloat nextGapX = [self gapBetweenTypes:fr.type and:parentType];
			VMHash *hashAtNextX = [branchViewTemporary item:@( x + nextGapX + vmpCellWidth )];
			summedHeight = [hashAtNextX itemAsFloat:fr.id];
			
			[self drawBranchGraph:fr
					 parentPartId:frag.partId
								x:x
								y:currentY
							 gapX:nextGapX
					parentCenterY:myCenterY
						   height:summedHeight];
			currentY += summedHeight;
		}
	}
}

- (VMFragment*)selectSubsequentFragmentOf:(VMFragment*)frag {
	VMFragment *subseq = nil;
	if ( frag.type == vmObjectType_reference )
		frag = [DEFAULTSONG data:((VMReference*)frag).referenceId];
	if ( frag.type == vmObjectType_sequence ) {
		subseq = ((VMSequence*)frag).subsequent;
		if ( ((VMSelector*)subseq).isDeadEnd ) {
			//	search sel inside seq
			for( VMId *fragId in ((VMSequence*)frag).fragments ) {
				VMFragment *subsubseq = [self selectSubsequentFragmentOf:[DEFAULTSONG data:fragId]];
				if ( subsubseq && (![self checkDeadEnd:subsubseq]) )
					return subsubseq;
			}
		}
	}
	
	if ( frag.type == vmObjectType_selector ) 
		subseq = frag;
	
	return subseq;
}

- (BOOL)checkDeadEnd:(VMFragment*)frag {
	switch ((int)frag.type) {
		case vmObjectType_selector:
			return ((VMSelector*)frag).isDeadEnd;
			break;
		case vmObjectType_sequence:
			if ( ! ((VMSequence*)frag).subsequent.isDeadEnd ) return NO;
			for ( VMId *fragId in ((VMSequence*)frag).fragments ) {
				if (! [self checkDeadEnd:[DEFAULTSONG data:fragId]] ) return NO;
			}
			break;
		case vmObjectType_reference:
			return [self checkDeadEnd:[DEFAULTSONG data:((VMReference*)frag).referenceId]];
			break;
	}
	return YES;
}

/*---------------------------------------------------------------------------------
 
 single selector graph with header
 
 ----------------------------------------------------------------------------------*/
#pragma mark single selector graph
- (void)drawSelectorGraph:(VMSelector*)selector rect:(NSRect)rect position:(int)position {
	VMHash *scoreForFragmentIds;
	
	if ( VMPSelectorGraphType_Single_noLevels ) {
		scoreForFragmentIds = ARInstance(VMHash);
		[selector prepareSelection];
		for ( VMChance *ch in selector.fragments ) {
			[scoreForFragmentIds setItem:VMFloatObj(ch.cachedScore) for:ch.targetId];
		}
	} else {
		scoreForFragmentIds = [selector collectScoresOfFragments:0 frameOffset:0 normalize:NO];
	}
	
	[self buildSelectorCellForFrame:0
				scoreForFragmentIds:scoreForFragmentIds
				   sumOfInnerScores:selector.sumOfInnerScores
				highlightFragmentId:nil
				 fragIdsInLastFrame:nil
							   rect:NSMakeRect(rect.origin.x   + vmpHeaderThickness + vmpCellMargin, rect.origin.y,
											   rect.size.width - vmpHeaderThickness - vmpCellMargin, rect.size.height)];
	
	if ( selector.id ) {
		VMPFragmentHeader *head = [[VMPFragmentHeader alloc]
								   initWithFrame:NSMakeRect(rect.origin.x,
															rect.origin.y + vmpShadowBlurRadius /*dunno why it needs offset*/,
															vmpHeaderThickness,
															rect.size.height)];
		[head setData:selector];
		head.position = position;
		head.delegate = self;
		[self addSubview:head];
		Release(head);
	}
}


//
//	stack options vertically
//
- (void)buildSelectorCellForFrame:(int)offset
				   scoreForFragmentIds:(VMHash*)scoreForFragmentIds
				 sumOfInnerScores:(VMFloat)sumOfInnerScores
				   highlightFragmentId:(VMId*)highlightFragmentId
				fragIdsInLastFrame:(VMHash *)fragIdsInLastFrame
							 rect:(NSRect)rect {
	
    VMArray *fragIds = [scoreForFragmentIds sortedKeys];
    CGFloat pixPerScore = rect.size.height / sumOfInnerScores;
    CGFloat currentY = self.contentRect.origin.y + rect.origin.y;
    
    for ( VMId *fragId in fragIds ) {
        VMFloat score 		= [[scoreForFragmentIds item:fragId] floatValue];
        if (score <= 0) continue;
        CGFloat height  	= score * pixPerScore;
        CGRect	cellRect 	= CGRectMake(rect.origin.x,
                                         currentY,
                                         rect.size.width,
                                         height);
        VMPFragmentCell *cc = [VMPFragmentCell fragmentCellWithFragment:[DEFAULTSONG data:fragId] frame:cellRect delegate:self];
		cc.selected = [fragId isEqualToString:highlightFragmentId];
        cc.alphaValue = ([fragIdsInLastFrame item:fragId] ? 0.5 : 1. );
        [self addSubview:cc];
        currentY += height;
    }
}


/*---------------------------------------------------------------------------------
 
 frame graph
 
 ----------------------------------------------------------------------------------*/
#pragma mark frame graph
- (void)drawFrameGraph {
	[self removeAllSubviews];
	if ( self.fragment.type != vmObjectType_selector ) return;
	VMSelector *selector = ((VMSelector*)self.fragment);
	
	VMLiveData *saved_livedata = AutoRelease([selector.liveData copy]);
	
	int base = 0;
	int num = self.frame.size.width / (vmpCellWidth+vmpCellMargin);
	
	CGFloat labelHeight		= 13;
	CGFloat testHeight		= 0;
	CGFloat marginHeight	= 5;
	CGFloat contentHeight 	= self.frame.size.height - labelHeight - testHeight - marginHeight - 10;
	VMHash *fragIdsInLastFrame = nil;
	
	for ( int frame = 0; frame < num; ++frame ) {
		
		CGFloat x = frame * (vmpCellWidth+vmpCellMargin)+vmpShadowBlurRadius;
		
		//	frame label
		NSTextField *tf = [NSTextField labelWithText:[NSString stringWithFormat:@"frame: %d", frame+1+base]
											   frame:CGRectMake(x, 0, vmpCellWidth, labelHeight )];
		tf.font = [NSFont systemFontOfSize:11];
		[self addSubview:tf];
		
		//	collect prior probability
		VMHash *scoreForFragmentIds = [selector collectScoresOfFragments:0 frameOffset:(frame+base) normalize:NO];
		VMFloat sumOfInnerScores =selector.sumOfInnerScores;
		
		//	make selection
		DEFAULTEVALUATOR.shouldLog = NO;
		VMFragment *selectedFragment = [selector selectOne];
		DEFAULTEVALUATOR.shouldLog = YES;
		
		//	build
		[self buildSelectorCellForFrame:frame + base
						 scoreForFragmentIds:scoreForFragmentIds
					   sumOfInnerScores:sumOfInnerScores
						 highlightFragmentId:selectedFragment.id
					  fragIdsInLastFrame:fragIdsInLastFrame
								   rect:CGRectMake(x, labelHeight,
												   vmpCellWidth, contentHeight)];
		fragIdsInLastFrame = AutoRelease([scoreForFragmentIds copy]);
		
	}
	
	selector.liveData = saved_livedata;
	
}

/*---------------------------------------------------------------------------------
 
 set cue and draw graph
 
 ----------------------------------------------------------------------------------*/

- (void)setFragment:(VMFragment *)frag {	//	override
	//	TODO: level 0 = the frag before = @F{}
	if ( [ frag.id isEqualToString:self.fragment.id ]) return;
	
	[super setFragment:frag];
	
	if ( !frag || frag.type != vmObjectType_selector ) return;		//	because this method gets called from it's heirs.
	
	switch (self.graphType) {
		case VMPSelectorGraphType_Single:
		case VMPSelectorGraphType_Single_noLevels:
			[self drawSelectorGraph:(VMSelector*)self.fragment rect:self.bounds position:0];
			break;
		case VMPSelectorGraphType_Frame:
			[self drawFrameGraph];
			break;
		case VMPSelectorGraphType_Branch: {
			ReleaseAndNewInstance( branchViewTemporary, VMHash );
			VMSelector *sel = (VMSelector*)self.fragment;
			
			DEFAULTEVALUATOR.shouldNotify = NO;
			VMLiveData *saved_liveData	= AutoRelease([sel.liveData copy]);
			sel.liveData = nil;	//	empty livedata before eval. this does reset @LC, @LS, @C
			//	TODO: vms data mode /	reset @D, @PT, @F (denote branch)

			[self collectBranchData:sel x:vmpCellWidth gapX:0 height:self.frame.size.height-10];
			
			sel.liveData = saved_liveData;
			DEFAULTEVALUATOR.shouldNotify = YES;
			
			[self drawBranchGraph:self.fragment
					 parentPartId:nil
								x:vmpCellWidth
								y:5.
							 gapX:0.
					parentCenterY:self.frame.size.height * 0.5 - 5
						   height:self.frame.size.height-10];
			ReleaseAndNil( branchViewTemporary );
		}
	}
}

#pragma mark -
#pragma mark fragment graph delegate
//	delegate
- (void)fragmentCellClicked:(VMPFragmentGraphBase *)fragCell {
	for( NSView *v in self.subviews ) {
		if( ClassMatch(v, VMPFragmentGraphBase ) && fragCell != v ) ((VMPFragmentGraphBase*)v).selected = NO;
	}
	[VMPNotificationCenter postNotificationName:VMPNotificationFragmentSelected object:self userInfo:@{@"id":fragCell.fragment.id}];
}

#pragma mark drawing
- (void)drawRect:(NSRect)rect {
}


@end






/*---------------------------------------------------------------------------------
 *
 *
 *	referrer graph
 *
 *
 *---------------------------------------------------------------------------------*/

#pragma mark -
#pragma mark *** Referrer Graph ***
#pragma mark -

@implementation VMPReferrerGraph
- (void)setData:(id)data {
	VMData *d = ClassCastIfMatch(data, VMData);
	if ( !d ) return;
	VMArray *idList = [APPDELEGATE.editorWindowController referrerListForId:d.id];
	VMSelector *sel = ARInstance(VMSelector);
	sel.id = @"Referrer";
	[sel setWithData:idList];
	self.graphType = VMPSelectorGraphType_Single_noLevels;
	self.fragment = sel;
}

@end




/*---------------------------------------------------------------------------------
 *
 *
 *	sequence graph
 *
 *
 *---------------------------------------------------------------------------------*/

#pragma mark -
#pragma mark *** Sequence Graph ***
#pragma mark -

@implementation VMPSequenceGraph

- (void)drawSequenceGraphInRect:(CGRect)rect {
	CGFloat x = rect.origin.x + 5;
	//
	//	sequence content
	//
	CGFloat y = rect.origin.y + 5 + vmpHeaderThickness + vmpCellMargin * 0.5;
	[self removeAllSubviews];
	
	if ( self.fragment.type != vmObjectType_sequence ) return;

	VMSequence *sequence = ((VMSequence*)self.fragment);
	
	VMInt num = sequence.length;
	
	CGFloat contentHeight 	= self.contentRect.size.height - y;
	
	for ( int position = 0; position < num; ++position ) {
		
		CGFloat graphWidth = vmpCellWidth;
		
		VMFragment *fragmentAtPosition = [sequence fragmentAtIndex:position];
		if ( fragmentAtPosition.type == vmObjectType_selector ) {
			//
			//	draw selector cell
			//
			graphWidth += vmpHeaderThickness + vmpCellMargin;
			[self drawSelectorGraph:((VMSelector*)fragmentAtPosition)
							   rect:CGRectMake(x, y, graphWidth, contentHeight)
						   position:position+1];
		} else {
			//
			//	draw plain fragment cell
			//
			VMPFragmentCell * fragCell = AutoRelease([[VMPFragmentCell alloc]
													  initWithFrame:CGRectMake(x, y + vmpShadowBlurRadius,
																			   graphWidth, contentHeight )] );
			fragCell.fragment = fragmentAtPosition;
			fragCell.position = position+1;
			fragCell.delegate = self;
			[self addSubview:fragCell];
		}
		x += graphWidth + vmpCellMargin + vmpShadowBlurRadius;
	}
	
	CGFloat sequenceWidth = x - vmpCellMargin;
	
	//
	//	header
	//
	VMPFragmentHeader *head = [[VMPFragmentHeader alloc]
							   initWithFrame:NSMakeRect(rect.origin.x, rect.origin.y + 5,
														sequenceWidth, vmpHeaderThickness)];
	[head setData:self.fragment];
	head.delegate = self;
	[self addSubview:head];
	
	//
	//	subseq
	//
	//
	//	draw selector cell
	//
	CGFloat subseqWidth = vmpCellWidth + vmpHeaderThickness + vmpCellMargin;
	[self drawSelectorGraph:sequence.subsequent
					   rect:CGRectMake(x, rect.origin.y +5, subseqWidth, rect.size.height - vmpCellMargin )
				   position:-1 /*-1 indicates subseq*/];

	
	self.width = sequenceWidth + subseqWidth;
}

- (void)setFragment:(VMFragment *)frag {	//	override
	[super setFragment:frag];
	[self drawSequenceGraphInRect:self.bounds];
}

#pragma mark drawing
- (void)drawRect:(NSRect)rect {
	;	//	override to do nothing.
}


@end










/*---------------------------------------------------------------------------------
 *
 *
 *	Object Graph View (the top level view of object graphs)
 *
 *
 *---------------------------------------------------------------------------------*/

#pragma mark -
#pragma mark *** Object Graph View ***
#pragma mark -

@implementation VMPObjectGraphView

- (void)dealloc {
	[self removeAllSubviews];
	VMNullify(data);
	VMNullify(editorViewController);
	Dealloc( super );;
}

- (void)redraw {
	
	if ( self.data.type == vmObjectType_chance ) return;
	
	[self removeAllSubviews];
	
	switch (self.data.type) {
			//
			// selector editor
			//
		case vmObjectType_selector: {
			
			VMPSelectorEditorViewController *sle;
			if( ClassMatch( self.editorViewController, VMPSelectorEditorViewController )) {
				sle = (VMPSelectorEditorViewController*)self.editorViewController;
			} else {
				sle = AutoRelease([[VMPSelectorEditorViewController alloc] initWithNibName:@"VMPSelectorEditorView" bundle:nil] );
			}
			[self addSubview:sle.view];
			sle.view.frame = self.frame;
			[sle setData: self.data];
			self.editorViewController = sle;
			break;
		}
			//
			//
			//	sequence view
			//
			//
		case vmObjectType_sequence: {
			CGFloat referrerGraphWidth = vmpCellWidth*2;
			CGFloat sequenceGraphWidth = self.width = referrerGraphWidth;
			//
			//	referrer graph
			//
			VMPReferrerGraph *refGraph = [[VMPReferrerGraph alloc]
										  initWithFrame:CGRectMake(10, 10,
																   vmpCellWidth + vmpHeaderThickness,
																   self.height -20 )];
			[refGraph setData: self.data];
			VMPGraph *refGraphBG = [[VMPGraph alloc] initWithFrame:CGRectMake(0, 1, refGraph.width + 20, self.height-1)];
			refGraphBG.backgroundColor = VMPColorBy(.7, .7, .7, 1.);
			
			//
			//	sequence graph
			//
			VMPSequenceGraph *seqGraph = [[VMPSequenceGraph alloc]
										  initWithFrame:CGRectMake(referrerGraphWidth, 10,
																   sequenceGraphWidth, self.height -15 )];
			[seqGraph setData: self.data];
			
			if( seqGraph.width <= sequenceGraphWidth ) {	//	seqGraph resizes itself after setData:
				seqGraph.x = ( sequenceGraphWidth - seqGraph.width ) *0.5 + referrerGraphWidth;
			} else {
				//TODO: we need a scroll view.
				
			}
			
			[self addSubview: refGraphBG];
			[self addSubview: refGraph];
			[self addSubview: seqGraph];
			Release(refGraphBG);
			Release(refGraph);
			Release(seqGraph);
			break;
		}
			
			//
			//	audio info editor
			//
		case vmObjectType_audioFragment:
		case vmObjectType_audioFragmentPlayer:
		case vmObjectType_audioInfo: {
			VMPAudioInfoEditorViewController *aie;
			if( ClassMatch( self.editorViewController, VMPAudioInfoEditorViewController )) {
				aie = (VMPAudioInfoEditorViewController*)self.editorViewController;
			} else {
				aie = AutoRelease([[VMPAudioInfoEditorViewController alloc] initWithNibName:@"VMPAudioInfoEditorView" bundle:nil] );
			}
			[self addSubview:aie.view];
			aie.view.frame = self.frame;
			[aie setData: self.data.type == vmObjectType_audioInfo ? self.data : ((VMAudioFragment*)self.data).audioInfoRef ];
			self.editorViewController = aie;
			break;
		}
		
		case vmObjectType_chance: {
			//	nothing
			
			break;
		}
			//
			//	frag cell view
			//
		default: {
			VMPFragmentCell *fragCell = [[VMPFragmentCell alloc] initWithFrame:
					   CGRectPlaceInTheMiddle(CGRectMake(0, 0, vmpCellWidth, MIN(self.frame.size.height - 10, 100)),
											  CGPointMiddleOfRect(CGRectZeroOrigin(self.frame)))];
			[fragCell setData: self.data];
			[self addSubview: fragCell];
			Release(fragCell);
			break;
		}
	}
	

}

//	TODO:	make SEL compatible with SEQ-SUBSEQ
//	TODO:	animated transition
- (void)chaseSequence:(VMAudioFragmentPlayer*)audioFragmentPlayer {
	VMLog *log = DEFAULTSONG.log;
	VMInt p = log.count -1;
	VMLogRecord *lr;
	for ( ;p > 0; --p) {
		lr = [log item:p];
		if ( lr.type != vmObjectType_audioFragmentPlayer ) continue;
		if ( ((VMAudioFragmentPlayer*)lr.data).firedTimestamp == audioFragmentPlayer.firedTimestamp )
			break;
	}
	for ( ;p > 0; --p ) {
		lr = [log item:p];
		if ( lr.type == self.data.type ) break;
	}
	self.data = lr.VMData;
	[self redraw];
}

- (void)drawGraphWith:(VMData*)data {
	self.data = data;
	[self redraw];
}


/*---------------------------------------------------------------------------------

	report graph
 
 *---------------------------------------------------------------------------------*/
- (void)drawReportGraph:(VMHash*)report {
	[self removeAllSubviews];
	int frameWidth = (vmpCellWidth+vmpCellMargin);
	int numberOfColumns = (int)(self.frame.size.width / frameWidth) -1;
	
	double percentPerRow = ( 100. / numberOfColumns );
	
	int dataIndex = 0;
	
	VMArray *frags  = [report item:@"frags"];
	VMArray *exits = [report item:@"parts"];
	
	double pixPerPercent = self.frame.size.height / 100;
	double percentsDisplayed = 0;
	
	for( int exitIdx = 0; exitIdx < exits.count; ++exitIdx ) {
		VMPReportRecord *data = [exits item:exitIdx];
		double percent = [data.percent doubleValue];
		VMPFragmentCell *cc = [[VMPFragmentCell alloc] initWithFrame:
						  CGRectMake(0,
									 percentsDisplayed * pixPerPercent,
									 vmpCellWidth,
									 percent * pixPerPercent
									 )];
		cc.fragment = ARInstance(VMFragment);
		cc.fragment.id = data.ident;
		percentsDisplayed += percent;
		[self addSubview:cc];
		Release(cc);
	}
	
	pixPerPercent = self.frame.size.height / percentPerRow * 0.7;
	
	for( int column = 0; column < numberOfColumns; ++column ) {
		percentsDisplayed = 0;
		for (;;) {
			VMPReportRecord *data = [frags item:dataIndex];
			
			double percent = [data.percent doubleValue];
			VMPFragmentCell *cc = [[VMPFragmentCell alloc] initWithFrame:
							  CGRectMake(column * frameWidth + frameWidth,
										 percentsDisplayed * pixPerPercent,
										 vmpCellWidth,
										 percent * pixPerPercent
										 )];
			cc.fragment = AutoRelease([[VMAudioFragment alloc] init] );
			cc.fragment.id = data.ident;
			[self addSubview:cc];
			Release(cc);
			++dataIndex;
			if ( dataIndex >= frags.count ) break;
			
			percentsDisplayed += percent;
			if ( percentsDisplayed > percentPerRow ) break;
			
		}
	}
}

@end


/*---------------------------------------------------------------------------------
 *
 *
 *	object info view
 *
 *		actually, this should be moved into VMPEditorWindowController related files
 *
 *---------------------------------------------------------------------------------*/

#pragma mark -
#pragma mark *** Object Info View ***
#pragma mark -

@implementation VMPObjectInfoView
@synthesize userGeneratedIdField=tf1_,vmpModifierField=tf2_,typeLabel=tf3_;

- (void)awakeFromNib {
	self.flippedYCoordinate = NO;
	self.userGeneratedIdField.stringValue = @"";
	self.vmpModifierField.stringValue = @"";
	self.typeLabel.stringValue = @"";
}

- (void)drawRect:(NSRect)dirtyRect {
	NSGradient *gr = AutoRelease([[NSGradient alloc]
								  initWithStartingColor:[self.backgroundColor colorModifiedByHueOffset:0.01
																					  saturationFactor:1.1
																					  brightnessFactor:0.8]
								  endingColor:[self.backgroundColor colorModifiedByHueOffset:-0.01
																			saturationFactor:0.9
																			brightnessFactor:1.0] ]);

	[gr drawInRect:dirtyRect angle:90];
}


- (void)redraw {
	if ( ! self.data ) return;
	if ( [self.data isKindOfClass:[VMFragment class]] ) {
		VMFragment *c = (VMFragment*)self.data;
		self.userGeneratedIdField.stringValue 	= c.userGeneratedId;
		self.vmpModifierField.stringValue		= c.VMPModifier ? c.VMPModifier : @"";
		self.userGeneratedIdField.bezeled		= YES;
		self.userGeneratedIdField.drawsBackground
			= self.userGeneratedIdField.editable
			= ( !c || c.VMPModifier.length == 0 );
		self.userGeneratedIdField.hidden		= NO;
		self.userGeneratedIdField.textColor =  ( !c || c.VMPModifier.length == 0 ) ? [NSColor controlTextColor] : [NSColor disabledControlTextColor];
	} else {
		self.userGeneratedIdField.stringValue 	= self.data.id ? self.data.id : @"";
		self.vmpModifierField.stringValue 		= @"";
		
		self.userGeneratedIdField.hidden		= (!self.data.id);
	}
	
	self.typeLabel.stringValue = [VMPreprocessor shortTypeStringForType:self.data.type];
	self.typeLabel.backgroundColor = self.backgroundColor = [NSColor colorForDataType:self.data.type];
	self.needsDisplay = YES;
}

- (void)drawInfoWith:(VMData*)data {
	self.data = data;
	[self redraw];
}


- (void)dealloc {
	VMNullify(data);
	[super dealloc];
}

@end


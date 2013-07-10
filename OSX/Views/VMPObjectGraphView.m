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


#pragma mark -
#pragma mark ** branch graph data models **
/*---------------------------------------------------------------------------------
 *	branch graph item
 *---------------------------------------------------------------------------------*/
#pragma mark -
#pragma mark branch graph item
@interface VMPBranchGraphItem : NSObject {
@public
	VMFloat y;
	VMFloat height;
}
@property (nonatomic, VMStrong)	VMPFragmentGraphBase	*graph;
@end

@implementation VMPBranchGraphItem
- (id)init {
	self = [super init];
	y = -1;
	return self;
}
- (void)dealloc {
	VMNullify( graph );
	Dealloc(super);
}
- (NSString*)description {
	return [NSString stringWithFormat:@"w:%.2f h:%.2f y:%.2f",
			(_graph?_graph.width:0), height, y];
}
@end

/*---------------------------------------------------------------------------------
 *  branch graph column
 *---------------------------------------------------------------------------------*/
#pragma mark -
#pragma mark branch graph column

@interface VMPBranchGraphColumn : VMHash {
@public
	VMFloat	x;
	VMFloat	y;
	VMFloat itemGap;
	BOOL	isSelectorColumn;
}
- (void)addHeight:(CGFloat)height ontoItem:(VMId*)dataId;
- (void)resetItems;
- (VMPBranchGraphItem*)branchGraphItem:(VMHashKeyType)key;
@end

@implementation VMPBranchGraphColumn
- (void)addHeight:(CGFloat)height ontoItem:(VMId*)dataId {
	VMPBranchGraphItem *bgi = [self item:dataId];
	if ( !bgi ) {
		bgi = ARInstance(VMPBranchGraphItem);
		[self setItem:bgi for:dataId];
	}
	bgi->height +=height;
}
- (void)resetItems {
	VMArray *keys = [self keys];
	for( VMId *dataId in keys ) {
		VMPBranchGraphItem *bgi = [self item:dataId];
		bgi->y = -1;
		bgi->height = 0;
	}
}
- (VMPBranchGraphItem*)branchGraphItem:(VMHashKeyType)key {
	VMPBranchGraphItem *bgi = [self item:key];
	if (!bgi) {
		bgi = ARInstance(VMPBranchGraphItem);
		[self setItem:bgi for:key];
	}
	return bgi;
}
- (void)setItemGapForHeight:(CGFloat)columnHeight {
	CGFloat h = 0;
	VMInt c = self.count;
	VMArray *keys = [self keys];
	if ( c <= 1 ) {
		itemGap = 0;
		if ( c == 1 ) {	//	center
			VMPBranchGraphItem *bgi = [self item:[keys item:0]];
			y = ( columnHeight - bgi->height ) * 0.5;
			if ( y < 0 ) y = 0;
		}
	} else {			//	distribute
		for( VMId *dataId in keys ) {
			VMPBranchGraphItem *bgi = [self item:dataId];
			h += bgi->height;
		}
		itemGap = (columnHeight-h) / (self.count-1);
	}
}
- (NSString*)description {
	return [NSString stringWithFormat:@"[%@] x:%.2f cy:%.2f: \n%@",
			isSelectorColumn ? @"S" : @"F", x, y, [super description]];
}
@end

#pragma mark -
#pragma mark branch graph column list
/*---------------------------------------------------------------------------------
 *	branch graph column list
 *---------------------------------------------------------------------------------*/
@interface VMPBranchGraphColumnList : VMHash
@property (nonatomic, VMStrong) VMArray *cachedKeys;
- (VMPBranchGraphColumn*)column:(int)index;
- (VMPBranchGraphColumn*)findColumnHavingFragment:(VMId*)fragmentId inColumns:(int)direction index:(int)columnIndex;
- (void)cleanupViews;
@end

@implementation VMPBranchGraphColumnList
- (void)dealloc {
    VMNullify(cachedKeys);
	Dealloc(super);
}

- (VMPBranchGraphColumn*)column:(int)index {
	VMPBranchGraphColumn *bgc = [self item:@(index)];
	if ( !bgc ) {
		bgc = ARInstance(VMPBranchGraphColumn);
		[self setItem:bgc for:@(index)];
		self.cachedKeys = nil;
	}
	return bgc;
}

- (VMPBranchGraphColumn*)findColumnHavingFragment:(VMId*)fragmentId inColumns:(int)direction index:(int)columnIndex {
	if ( ! _cachedKeys ) self.cachedKeys = [self sortedKeys];
	
	VMInt p = [_cachedKeys position:@(columnIndex)];
	p += direction;
	VMInt c = self.count;
	
	while( p >= 0 && p < c ) {
		VMPBranchGraphColumn *bgc = [self item:[_cachedKeys item:p]];
		if ( [bgc item:fragmentId] ) return bgc;
		if ( direction == 0 ) break;
		p += direction;
	}
	return nil;
}

- (void)cleanupViews {
	if ( ! _cachedKeys ) self.cachedKeys = [self sortedKeys];
	for ( NSNumber *pos in _cachedKeys ) {
		VMPBranchGraphColumn *bgc = [self item:pos];
		VMArray *keys = [bgc keys];
		for ( VMId *dataId in keys ) {
			VMPBranchGraphItem *bgi = [bgc item:dataId];
			[bgi.graph removeFromSuperview];
		}
		[self removeItem:pos];
	}
}

- (id)copyWithZone:(NSZone *)zone {
	VMPBranchGraphColumnList *bgcl = [VMPBranchGraphColumnList allocWithZone:zone];
	[bgcl initWithHash: ((VMHash*)[self deepCopy]).hash];
	return bgcl;
}

@end





/*---------------------------------------------------------------------------------
 *
 *
 *
 *	collection graph
 *
 *
 *
 *---------------------------------------------------------------------------------*/

#pragma mark -
#pragma mark *** Collection Graph ***
#pragma mark -

@implementation VMPCollectionGraph

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
	Release(branchGraphColumnList);
	Release(lastFrameBranchGraphColumnList);
	Release(line);
	Dealloc( super );;
}

- (void)setGraphType:(VMPSelectorGraphType)graphType {
	_graphType = graphType;
	[self removeAllSubviews];
	self.fragment = nil;	//	force redraw
}

/*---------------------------------------------------------------------------------
 
 branch graph
 
 ----------------------------------------------------------------------------------*/
#pragma mark branch graph

- (void)collectBranchData:(VMFragment*)fragment index:(int)index height:(VMFloat)height {
	if ( index > 100 ||  height < 1 ) return;
	
	BOOL isSelectorColumn = ( fragment.type == vmObjectType_selector );
	VMId *fragId = fragment.id;
	
	VMPBranchGraphColumn *bgColumn = [branchGraphColumnList column:index];
/*	
	pending: we should skip column if column type doesn't match
 
	while ( bgColumn.isSelectorColumn != isSelectorColumn ) {		//	column doesn't match
		++index;
		bgColumn = [branchViewTemporary item:@( index )];
	}
*/
	VMPBranchGraphItem *bgItem = [bgColumn item:fragId];
	if ( ! bgItem ) {
		//	look if we have a resusable bgItem in last frame
		VMPBranchGraphColumn *lfColumn = [lastFrameBranchGraphColumnList findColumnHavingFragment:fragId
																						inColumns:_animationDirection
																							index:index];
		if ( lfColumn ) {
			//	reuse
			bgItem = [lfColumn item:fragId];
			bgItem->y = -1;
			bgItem->height = 0;
			[bgColumn setItem:bgItem for:fragId];
			[lfColumn removeItem:fragId];
		} else {
			//	create new
			bgItem = [bgColumn branchGraphItem:fragId];		//	generates autonmatically if not found.
		}
	}
	bgItem->height += height;
	bgColumn->isSelectorColumn = isSelectorColumn;

	VMFragment *subsequent = [self collectSubsequentFragmentsFrom:fragment];
	
	if ( subsequent.type == vmObjectType_selector ) {
		
		VMLiveData *liveDataCache = nil;
		VMSelector *sel = nil;
		
		if ( _dataSource == VMPSelectorDataSource_StaticVMS ) {
			//	use static vms data
			sel	= (VMSelector*)subsequent;
			liveDataCache = AutoRelease([sel.liveData copy]);
			sel.liveData = nil;	//	TEST	reset liveData before evaluation
		} else {
			//	use statistics
			sel = [DEFAULTANALYZER makeSelectorFromStatistics:subsequent.id];
		}
		
		[sel prepareSelection];
		if ( [sel sumOfInnerScores] == 0 ) return;
		
		for( VMChance *ch in sel.fragments ) {
			if ( ch.cachedScore == 0 ) continue;
			VMFragment *c = [DEFAULTSONG data:ch.targetId];
			if ( !c ) {
				//	placeholder for undefined frag:
				c = ARInstance(VMFragment);
				c.id = ch.targetId;
			}
			[self collectBranchData:c
							  index:(( c.type == vmObjectType_selector ) ? index +1 : ((int)(index / 10)+1)*10 )
							 height:height / sel.sumOfInnerScores * ch.cachedScore ];
		}
		
		if ( liveDataCache )
			sel.liveData = liveDataCache;
	}
}



- (void)layoutBranchGraph {
	VMArray *keys = [branchGraphColumnList sortedKeys];
	int x = 0;
	
	for ( NSNumber *p in keys ) {
		int						index = p.intValue;
		VMPBranchGraphColumn	*bgColumn = [branchGraphColumnList column:index];
		bgColumn->x = x;
		[bgColumn setItemGapForHeight:self.frame.size.height-10];
		x += ( bgColumn->isSelectorColumn ? vmpHeaderThickness : vmpCellWidth );
		x += vmpSelectorGap;
	}
}



- (void)drawBranchGraph:(VMFragment*)fragment
		   parentPartId:(VMId*)parentPartId
				  index:(int)index
		   parentRightX:(CGFloat)parentRightX
		  parentCenterY:(CGFloat)parentCenterY
				 height:(CGFloat)summedHeight {
	
	VMPBranchGraphColumn	*bgColumn =		[branchGraphColumnList column:index];
	VMPBranchGraphItem		*bgItem =		[bgColumn branchGraphItem:fragment.id];
	BOOL					drawChildren =	NO;
	CGFloat					graphRightX =	0;
	
	if ( bgItem->y < 0 ) {	//	not drawn yet.
		bgItem->y	=	bgColumn->y;
		bgColumn->y +=	summedHeight + bgColumn->itemGap;
		
		CGFloat farX = self.width * 0.5 * _animationDirection;
		
		if ( ! bgItem.graph ) {	//	if we reuse a branch graph item, we already wave a graph assigned.
			if ( fragment.type != vmObjectType_selector ) {
				bgItem.graph = [VMPFragmentCell fragmentCellWithFragment:fragment
																   frame:CGRectMake(bgColumn->x + farX,
																					bgItem->y + summedHeight * 0.5,
																					vmpCellWidth, 1)
																delegate:self];
			} else {
				bgItem.graph = [VMPFragmentHeader fragmentHeaderWithFragment:fragment
																	   frame:CGRectMake(bgColumn->x + farX,
																						bgItem->y + summedHeight * 0.5,
																						vmpHeaderThickness, 1)
																	delegate:self];
			}
		}
		[self addSubview:bgItem.graph];
		[bgItem.graph moveToRect:NSMakeRect(bgColumn->x, bgItem->y,
											bgItem.graph.contentRect.size.width, summedHeight)
						duration:0.5];
		graphRightX = bgColumn->x + bgItem.graph.contentRect.size.width;
		drawChildren = YES;
	}
	
	CGFloat myCenterY = (int)( bgItem->y + summedHeight * 0.5 );
	line.point1 = NSMakePoint( parentRightX,	parentCenterY );
	line.point2 = NSMakePoint( bgColumn->x,		myCenterY );
	line.foregroundColor = [fragment.partId isEqualToString:parentPartId] ? [NSColor darkGrayColor] : [NSColor redColor];
	[temporaryLineLayer addSubview:[line clone]];
	if ( ! drawChildren ) return;
	
	VMFragment *subsequent = [self collectSubsequentFragmentsFrom:fragment];
	
	if ( subsequent.type == vmObjectType_selector ) {
		VMSelector *sel = (VMSelector*)subsequent;
		
		for( VMChance *ch in sel.fragments ) {
			int	nextIndex = index;
			VMFragment *childFragment = [DEFAULTSONG data:ch.targetId];
			if ( !childFragment ) {
				if ( [ch.targetId isEqualToString:@"*"] ) continue;	//	undefined sequel
				//	placeholder for undefined frag:
				childFragment = ARInstance(VMFragment);
				childFragment.id = ch.targetId;
			}
			
			if ( childFragment.type != vmObjectType_selector ) {
				nextIndex = ((int)(nextIndex / 10) +1)*10;
				summedHeight = [[branchGraphColumnList column:nextIndex] branchGraphItem:childFragment.id]->height;
			} else {
				do {
					++nextIndex;
					summedHeight = [[branchGraphColumnList column:nextIndex] branchGraphItem:childFragment.id]->height;
				} while ( summedHeight <= 0 && (( nextIndex % 10 ) != 0 ));
			}
			if ( nextIndex > 100 || summedHeight < 3 ) continue;
			
			[self drawBranchGraph:childFragment
					 parentPartId:subsequent.partId
							index:nextIndex
					 parentRightX:graphRightX
					parentCenterY:myCenterY
						   height:summedHeight];
		}
	}
}


- (VMSelector*)collectSubsequentFragmentsFrom:(VMFragment*)frag {
	VMFloat activeRatio = 1;
	if ( frag.type == vmObjectType_selector && (! [((VMSelector*)frag) isDeadEnd] )) return (VMSelector*)frag;
	
	return [self collectSubsequentFragmentsFrom:frag activeRatio:&activeRatio];
}

- (VMSelector*)collectSubsequentFragmentsFrom:(VMFragment*)frag activeRatio:(VMFloat*)activeRatioP {
	//LLog(@"collect subseqs from %@ active:%.3f", frag.id, *activeRatioP );
	VMSelector *subseq = nil;
	if ( frag.type == vmObjectType_reference )
		frag = [DEFAULTSONG data:((VMReference*)frag).referenceId];
	if ( frag.type == vmObjectType_sequence ) {
		subseq = ((VMSequence*)frag).subsequent;
		if ( ((VMSelector*)subseq).isDeadEnd ) {
			//	collect branches inside sequence
			subseq = ARInstance(VMSelector);
			subseq.id = [NSString stringWithFormat:@"%@|tempSelector", frag.id];
			for( VMId *fragId in ((VMSequence*)frag).fragments ) {
				[subseq addFragmentsWithData:[self collectSubsequentFragmentsFrom:[DEFAULTSONG data:fragId]
																	  activeRatio:activeRatioP].fragments ];
			}
		}
	}
	
	if ( frag.type == vmObjectType_selector ) {
		VMSelector *sel = ClassCast(frag, VMSelector);
		
		//	choose non-dead-end branches inside selector
		subseq = ARInstance(VMSelector);
		subseq.id = [NSString stringWithFormat:@"%@|tempSelector", frag.id];
		[sel prepareSelection];
		VMFloat subActiveRatio = 1;
		for( VMChance *ch in sel.fragments ) {
			if ( ! [DEFAULTSONG isFragmentDeadEnd:ch.targetId] ) {
				VMFloat normalizedScore = ch.cachedScore / sel.sumOfInnerScores;
				subActiveRatio -= normalizedScore;
				VMChance *tempChance = [ch copy];
				tempChance.scoreDescriptor = [NSString stringWithFormat:@"%.3f", normalizedScore * (*activeRatioP) ];
				[subseq addFragmentsWithData:tempChance];
				//LLog(@"adding chance: %@",tempChance.description);
				Release( tempChance );
			}
		}
		(*activeRatioP) *= subActiveRatio;
	}
	
	//LLog(@"subseq: %@",subseq.description);
	return subseq;
}


/*---------------------------------------------------------------------------------
 
 single selector graph with header
 
 ----------------------------------------------------------------------------------*/
#pragma mark single selector graph
- (VMHash *)drawSelectorGraph:(VMSelector*)selector rect:(NSRect)rect position:(int)position {
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
	return scoreForFragmentIds;
}


//
//	stack items vertically
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
		VMFragment *frag = [DEFAULTSONG data:fragId];
		if ( ! frag ) {	//	placeHolder for undefined fragments
			frag = ARInstance(VMFragment);
			frag.id = fragId;
		}
        VMPFragmentCell *cc = [VMPFragmentCell fragmentCellWithFragment:frag frame:cellRect delegate:self];
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

- (void)showLines:(id)something {
	temporaryLineLayer.hidden = NO;
}

/*---------------------------------------------------------------------------------
 *
 *
 *	sequence graph
 *
 *
 *---------------------------------------------------------------------------------*/

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
	VMFloat ratioLeft = 1.;
	
	CGFloat activeHeight = contentHeight * ratioLeft;
	
	for ( int position = 0; position < num; ++position ) {
		CGFloat graphWidth = vmpCellWidth;
		
		VMFragment *fragmentAtPosition = [sequence fragmentAtIndex:position];
		if ( fragmentAtPosition.type == vmObjectType_selector ) {
			//
			//	draw selector cell
			//
			VMSelector *sel = ClassCast( fragmentAtPosition, VMSelector );
			graphWidth += vmpHeaderThickness + vmpCellMargin;
			VMHash *scoreForIds = [self drawSelectorGraph:sel
													 rect:CGRectMake(x, y, graphWidth, activeHeight)
												 position:position+1];
			
			if ( sequence.subsequent.useSubsequentOfBranchFragments ) {
				//	check if some branch did exit sequence
				
				VMFloat deadEndRatio = [sel ratioOfDeadEndBranchesWithScores:scoreForIds sumOfScores:sel.sumOfInnerScores];
				activeHeight *= deadEndRatio;
			}
			
		} else {
			//
			//	draw plain fragment cell
			//
			VMPFragmentCell * fragCell = AutoRelease([[VMPFragmentCell alloc]
													  initWithFrame:CGRectMake(x, y + vmpShadowBlurRadius,
																			   graphWidth, activeHeight )] );
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


#pragma mark -
#pragma mark fragment graph delegate
//	delegate
- (void)fragmentCellClicked:(VMPFragmentGraphBase *)fragCell {
	if ( !fragCell.fragment ) return;	//	can be nil
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
 *	VMPSelectorGraph
 *
 *
 *---------------------------------------------------------------------------------*/

#pragma mark -
#pragma mark VMPSelectorGraph

@implementation VMPSelectorGraph

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
			//	prepare layer
			temporaryLineLayer = [self viewWithTag:'linL'];
			if ( ! temporaryLineLayer ) {
				temporaryLineLayer = [[[VMPGraph alloc] initWithFrame:self.frame] taggedWith:'linL'];
				temporaryLineLayer.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
				[self addSubview:AutoRelease(temporaryLineLayer)];
			}
			[temporaryLineLayer removeAllSubviews];
			temporaryLineLayer.hidden = YES;
			//
			Release( lastFrameBranchGraphColumnList );
			lastFrameBranchGraphColumnList = [branchGraphColumnList copy];
			Release( branchGraphColumnList );
			branchGraphColumnList = NewInstance( VMPBranchGraphColumnList );
			
			//
			VMSelector *sel = (VMSelector*)self.fragment;
			
			DEFAULTEVALUATOR.shouldNotify = NO;
			VMLiveData *saved_liveData	= AutoRelease([sel.liveData copy]);
			sel.liveData = nil;	//	empty livedata before eval. this does reset @LC, @LS, @C
			//	TODO: vms data mode /	reset @D, @PT, @F (denote branch)
			
			[self collectBranchData:sel index:0 height:self.frame.size.height-10];
			[self layoutBranchGraph];
			sel.liveData = saved_liveData;
			DEFAULTEVALUATOR.shouldNotify = YES;
			
			[self drawBranchGraph:self.fragment
					 parentPartId:nil
							index:0
					 parentRightX:0
					parentCenterY:self.frame.size.height * 0.5 - 5
						   height:self.frame.size.height-10];
			
			[lastFrameBranchGraphColumnList cleanupViews];
			[self performSelector:@selector(showLines:) withObject:nil afterDelay:0.6];
		}
	}
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
	[self redrawWithAnimationDirection:vmp_action_no_move];
}

- (void)redrawWithAnimationDirection:(int)direction {
	
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
				sle.selectorGraph.animationDirection = direction;
			} else {
				sle = AutoRelease([[VMPSelectorEditorViewController alloc] initWithNibName:@"VMPSelectorEditorView" bundle:nil] );
			}
			[self addSubview:sle.view];
			sle.view.frame = self.frame;
			sle.dataSource = self.selectorDataSource;
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
			seqGraph.dataSource = self.selectorDataSource;
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

//	TODO:	animated transition
- (void)chaseSequence:(VMAudioFragmentPlayer*)audioFragmentPlayer {
	VMLog *log = DEFAULTSONG.log;
	VMInt p = log.count -1;
	VMLogRecord *lr = nil;
	VMData *d = nil;
	vmObjectType type = self.data.type;
	int skipSelectorCounter = 1;
	
	for ( ;p > 0; --p) {
		lr = [log item:p];
		if ( lr.type != vmObjectType_audioFragmentPlayer ) continue;
		if ( ((VMAudioFragmentPlayer*)lr.data).firedTimestamp <= audioFragmentPlayer.firedTimestamp )
			break;
	}
	for ( ;p > 0; --p ) {
		lr = [log item:p];
		d  = lr.VMData;
		
		//	switch graph type automatically:
		if ( lr.type == vmObjectType_sequence ) {
			if ( type == vmObjectType_selector && ((VMSequence*)d).length > 1 ) {
				type = vmObjectType_sequence;
			} else if ( type == vmObjectType_sequence && ((VMSequence*)d).length < 2 ) {
				type = vmObjectType_selector;
				skipSelectorCounter = 0;
			}
		}
		
		if ( lr.type == type ) {
			if (d) {
				if ( type != vmObjectType_selector ) break;
				if ( skipSelectorCounter <= 0 ) {
					if ( ! [ClassCast(d, VMSelector) isDeadEnd] ) break;	//	do not display dead-ended sel.
				}
			}
			--skipSelectorCounter;	//	assume d was empty because it was a subsequence (which is not registered)
		}
	}
		
	if ( d && ( ! [self.data.id isEqualToString:d.id] ) ) {
		self.data = d;
		[self redrawWithAnimationDirection:vmp_action_move_next_by_player & 0xff];	
	}
}

- (void)drawGraphWith:(VMData*)data animationDirection:(int)direction {
	self.data = data;
	[self redrawWithAnimationDirection:direction];
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


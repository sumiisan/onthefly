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

/*---------------------------------------------------------------------------------
 
 selector graph
 
 ----------------------------------------------------------------------------------*/

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
	[branchViewTemporary release];
	[line release];
	[super dealloc];
}

/*---------------------------------------------------------------------------------
 
 branch graph
 
 ----------------------------------------------------------------------------------*/
#pragma mark branch graph

- (CGFloat)gapBetweenTypes:(int)type1 and:(int)type2 {
	if( type1 == vmObjectType_selector && type2 == vmObjectType_selector ) return 10.;
	return 55.;
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
	if ( frag.type == vmObjectType_reference ) frag = [DEFAULTSONG data:((VMReference*)frag).referenceId];
	int parentType = frag.type;
	if ( parentType == vmObjectType_sequence ) frag = ((VMSequence*)frag).subsequent;
	if ( frag.type == vmObjectType_selector ) {
		VMSelector *sel				= (VMSelector*)frag;
		VMLiveData *saved_liveData	= [[sel.liveData copy] autorelease];
		[sel prepareSelection];
		if ( sel.sumOfInnerScores == 0 ) return;
		for( VMChance *ch in sel.fragments ) {
			if ( ch.cachedScore == 0 ) continue;
			VMFragment *c = [DEFAULTSONG data:ch.targetId];
			if( c )
				[self collectBranchData:c
									  x:x
								   gapX:[self gapBetweenTypes:c.type and:parentType]
								 height:height / sel.sumOfInnerScores * ch.cachedScore ];
		}
		sel.liveData = saved_liveData;
	}
}

// TODO:handle sequences with subseq = *
- (void)drawBranchGraph:(VMFragment*)frag
					  x:(CGFloat)x
					  y:(CGFloat)y
				   gapX:(CGFloat)gapX
		  parentCenterY:(CGFloat)parentCenterY
				 height:(CGFloat)summedHeight {
	x += gapX + vmpCellWidth;
	if ( x >= (self.frame.size.width - vmpCellWidth) ) return;

//	NSLog(@"%@ %.2f %.2f", frag.id, x, y);
	VMHash *hashAtX = [branchViewTemporary item:@( x )];
	VMString *yPositionKey = [frag.id stringByAppendingString:@"_y"];
	CGFloat yAlreadyDrawn = [hashAtX itemAsFloat:yPositionKey];
	BOOL drawChildren = NO;

	//VMFloat summedHeight = [hashAtX itemAsFloat:frag.id];
	if ( yAlreadyDrawn == 0 ) {
		if ( summedHeight < 3 ) return;
		CGFloat moddedYBase = [hashAtX itemAsFloat:@"moddedYBase"];
		if ( moddedYBase == 0 )
			yAlreadyDrawn = y + 0.01;
		else
			yAlreadyDrawn = moddedYBase + 0.01;
		
		[hashAtX setItem:VMFloatObj(yAlreadyDrawn + summedHeight) for:@"moddedYBase"];
	//	[[branchViewTemporary itemAsHash:@(x+55)] setItem:VMFloatObj(yAlreadyDrawn + summedHeight) for:@"moddedBase"];
		[hashAtX setItem:VMFloatObj(yAlreadyDrawn) for:[frag.id stringByAppendingString:@"_y"]];
	
		VMPFragmentCell *cc = [VMPFragmentCell fragmentCellWithFragment:frag
											  frame:CGRectMake(x, yAlreadyDrawn, vmpCellWidth, summedHeight)
										   delegate:self];
		[self addSubview:cc];
		drawChildren = YES;
	}
	
	CGFloat myCenterY = yAlreadyDrawn + summedHeight * 0.5;
	line.point1 = NSMakePoint(x - gapX, parentCenterY );//myCenterY - ( (myCenterY - parentCenterY) * 0.5 ) );
	line.point2 = NSMakePoint(x, myCenterY);
	[self addSubview:[line clone]];
	
	if ( ! drawChildren ) return;	//	do not draw children
	if ( frag.type == vmObjectType_reference ) frag = [DEFAULTSONG data:((VMReference*)frag).referenceId];
	int parentType = frag.type;
	if ( parentType == vmObjectType_sequence ) frag = ((VMSequence*)frag).subsequent;
	if ( frag.type == vmObjectType_selector ) {
		VMSelector *sel = (VMSelector*)frag;
		CGFloat currentY = y;
		for( VMChance *ch in sel.fragments ) {
			VMFragment *c = [DEFAULTSONG data:ch.targetId];
			VMFloat nextGapX = [self gapBetweenTypes:c.type and:parentType];
			VMHash *hashAtNextX = [branchViewTemporary item:@( x + nextGapX + vmpCellWidth )];
			summedHeight = [hashAtNextX itemAsFloat:ch.targetId];
			
			[self drawBranchGraph:c
								x:x
								y:currentY
							 gapX:nextGapX
					parentCenterY:myCenterY
						   height:summedHeight];
			currentY += summedHeight;
		}
	}
}

/*---------------------------------------------------------------------------------
 
 single selector graph
 
 ----------------------------------------------------------------------------------*/
#pragma mark single selector graph
- (void)drawSelectorGraph:(VMSelector*)selector rect:(NSRect)rect {
	VMHash *scoreForFragmentIds = [selector collectScoresOfFragments:0 frameOffset:0 normalize:NO];
	[self buildSelectorCellForFrame:0
					 scoreForFragmentIds:scoreForFragmentIds
				   sumOfInnerScores:selector.sumOfInnerScores
					 highlightFragmentId:nil
				  fragIdsInLastFrame:nil
						  rect:rect];

}

- (void)buildSelectorCellForFrame:(int)offset
				   scoreForFragmentIds:(VMHash*)scoreForFragmentIds
				 sumOfInnerScores:(VMFloat)sumOfInnerScores
				   highlightFragmentId:(VMId*)highlightFragmentId
				fragIdsInLastFrame:(VMHash *)fragIdsInLastFrame
							 rect:(NSRect)rect {
	
    VMArray *fragIds = [scoreForFragmentIds sortedKeys];
    CGFloat pixPerScore = rect.size.height / sumOfInnerScores;
    CGFloat currentY = self.cellRect.origin.y + rect.origin.y;
    
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
	
	VMLiveData *saved_livedata = [[selector.liveData copy] autorelease];
	
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
		fragIdsInLastFrame = [[scoreForFragmentIds copy] autorelease];
		
	}
	
	selector.liveData = saved_livedata;
	
}

/*---------------------------------------------------------------------------------
 
 set cue and draw graph
 
 ----------------------------------------------------------------------------------*/

- (void)setFragment:(VMFragment *)frag {	//	override
	//	TODO: level 0 = the frag before = @F{}
	
	[super setFragment:frag];
	if ( self.frameGraphMode )
		[self drawFrameGraph];
	else {
		ReleaseAndNewInstance( branchViewTemporary, VMHash );
		DEFAULTEVALUATOR.shouldNotify = NO;
		[self collectBranchData:self.fragment x:vmpCellWidth gapX:0 height:self.frame.size.height-10];
		DEFAULTEVALUATOR.shouldNotify = YES;
		
		[self drawBranchGraph:self.fragment
							x:vmpCellWidth
							y:5.
						 gapX:0.
				parentCenterY:self.frame.size.height * 0.5 - 5
					   height:self.frame.size.height-10];
		ReleaseAndNil( branchViewTemporary );
	}
}


//	delegate
- (void)fragmentCellClicked:(VMPFragmentCell *)fragCell {
	for( NSView *v in self.subviews ) {
		if( ClassMatch(v, VMPFragmentCell ) && fragCell != v ) ((VMPFragmentCell*)v).selected = NO;
	}
	[VMPNotificationCenter postNotificationName:VMPNotificationFragmentSelected object:self userInfo:@{@"id":fragCell.fragment.id}];
}

#pragma mark drawing
- (void)drawRect:(NSRect)rect {
}


@end



/*---------------------------------------------------------------------------------
 
 sequence graph
 
 ----------------------------------------------------------------------------------*/

#pragma mark -
#pragma mark *** Sequence Graph ***
#pragma mark -

@implementation VMPSequenceGraph

- (void)redrawLocal {
	[self removeAllSubviews];
	if (self.fragment.type == vmObjectType_sequence) {
		VMSequence *sequence = ((VMSequence*)self.fragment);
		
		VMInt num = sequence.length + 1;
		
		CGFloat labelHeight		= 20;
		CGFloat contentHeight 	= self.cellRect.size.height - labelHeight;
		
		for ( int position = 0; position < num; ++position ) {
			
			CGFloat x = position * ( vmpCellWidth + vmpCellMargin ) + vmpShadowBlurRadius;
			
			NSTextField *tf = [NSTextField labelWithText: (position < sequence.length
                                                           ? [NSString stringWithFormat:@"position: %d", position +1]
                                                           : @"subsequent")
												   frame:CGRectMake(x, 0, vmpCellWidth, labelHeight )];
			[self addSubview:tf];
			
			VMFragment *fragmentAtPosition = [sequence fragmentAtIndex:position];
			if ( fragmentAtPosition.type == vmObjectType_selector ) {
				[self drawSelectorGraph:((VMSelector*)fragmentAtPosition)
								   rect:CGRectMake(x, labelHeight, vmpCellWidth, contentHeight)];
			} else {
				VMPFragmentCell * fragCell = [[[VMPFragmentCell alloc]initWithFrame:CGRectMake(x, labelHeight + vmpShadowBlurRadius, vmpCellWidth, contentHeight )] autorelease];
				fragCell.fragment = fragmentAtPosition;
				fragCell.delegate = self;
				[self addSubview:fragCell];
			}
		}
	}
	
}

- (void)setFragment:(VMFragment *)frag {	//	override
	[super setFragment:frag];
	[self redrawLocal];
}

#pragma mark drawing
- (void)drawRect:(NSRect)rect {
	;	//	override to do nothing.
}


@end











/*---------------------------------------------------------------------------------
 
 object graph view
 
 ----------------------------------------------------------------------------------*/

#pragma mark -
#pragma mark *** Object Graph View ***
#pragma mark -

@implementation VMPObjectGraphView
//@synthesize data=data_;

- (void)dealloc {
	[self removeAllSubviews];
	self.editorViewController = nil;
	[super dealloc];
}

- (void)redraw {
	
	if ( ! self.data || self.data.type == vmObjectType_chance ) return;
	
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
				sle = [[[VMPSelectorEditorViewController alloc] initWithNibName:@"VMPSelectorEditorView" bundle:nil] autorelease];
			}
			[self addSubview:sle.view];
			sle.view.frame = self.frame;
			[sle setData: self.data];
			self.editorViewController = sle;
		}
			
			//
			//	sequence view
			//
		case vmObjectType_sequence: {
			int width = ( vmpCellWidth + vmpCellMargin ) * (((VMSequence*)self.data).length +1 ) - vmpCellMargin;
			VMPFragmentCell *fragCell = [[VMPSequenceGraph alloc]initWithFrame:
					   CGRectPlaceInTheMiddle(CGRectMake(0,
														 0,
														 width,
														 self.frame.size.height - 10),
											  CGPointMiddleOfRect(CGRectZeroOrigin(self.frame)))];
			[fragCell setData: self.data];
			[self addSubview: [fragCell taggedWith:vmpg_background]];
			[fragCell release];
			break;
		}
			
			//
			//	audio info editor
			//
		case vmObjectType_audioFragment:
		case vmObjectType_audioInfo: {
			VMPAudioInfoEditorViewController *aie;
			if( ClassMatch( self.editorViewController, VMPAudioInfoEditorViewController )) {
				aie = (VMPAudioInfoEditorViewController*)self.editorViewController;
			} else {
				aie = [[[VMPAudioInfoEditorViewController alloc] initWithNibName:@"VMPAudioInfoEditorView" bundle:nil] autorelease];
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
			[self addSubview: [fragCell taggedWith:vmpg_background]];
			[fragCell release];
			break;
		}
	}
	

}

- (void)drawGraphWith:(VMData*)data {
	self.data = data;
	[self redraw];
}

/*---------------------------------------------------------------------------------
 
 report graph
 
 ----------------------------------------------------------------------------------*/

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
		cc.fragment = [[[VMFragment alloc] init] autorelease];
		cc.fragment.id = data.ident;
		percentsDisplayed += percent;
		[self addSubview:cc];
		[cc release];
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
			cc.fragment = [[[VMAudioFragment alloc] init] autorelease];
			cc.fragment.id = data.ident;
			[self addSubview:cc];
			[cc release];
			++dataIndex;
			if ( dataIndex >= frags.count ) break;
			
			percentsDisplayed += percent;
			if ( percentsDisplayed > percentPerRow ) break;
			
		}
	}
}

@end



/*---------------------------------------------------------------------------------
 
 object info view
 
 ----------------------------------------------------------------------------------*/

#pragma mark -
#pragma mark *** Object Info View ***
#pragma mark -

@implementation VMPObjectInfoView
@synthesize data=data_;
@synthesize userGeneratedIdField=tf1_,vmpModifierField=tf2_,typeLabel=tf3_;

- (void)awakeFromNib {
	self.flippedYCoordinate = NO;
	self.userGeneratedIdField.stringValue = @"";
	self.vmpModifierField.stringValue = @"";
	self.typeLabel.stringValue = @"";
}

- (void)drawRect:(NSRect)dirtyRect {
	[super drawRect:dirtyRect];
	[[self.backgroundColor colorModifiedByHueOffset:0 saturationFactor:1.1 brightnessFactor:0.7] setStroke];
	[NSBezierPath strokeLineFromPoint:NSMakePoint(0,1.5) toPoint:NSMakePoint(self.width, 1.5)];
	[[self.backgroundColor colorModifiedByHueOffset:0 saturationFactor:0.7 brightnessFactor:1.2] setStroke];
	[NSBezierPath strokeLineFromPoint:NSMakePoint(0,self.height-0.5) toPoint:NSMakePoint(self.width, self.height-0.5)];
	
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

@end


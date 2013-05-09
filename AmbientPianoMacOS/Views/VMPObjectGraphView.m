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

- (void)collectBranchData:(VMCue*)cue x:(CGFloat)x gapX:(CGFloat)gapX height:(VMFloat)height {
	//NSLog(@"%@ \tx:%.2f",cue.id,x);
	x += gapX + vmpCellWidth;
	if (( x >= (self.frame.size.width - vmpCellWidth) ) || height < 1 ) return;
	
	VMHash *hashAtX = [branchViewTemporary item:@( x )];
	if ( ! hashAtX ) {
		hashAtX = ARInstance(VMHash);
		[branchViewTemporary setItem:hashAtX for:@( x )];
	}
	[hashAtX add:height ontoItem:cue.id];
	if ( cue.type == vmObjectType_reference ) cue = [DEFAULTSONG data:((VMReference*)cue).referenceId];
	int parentType = cue.type;
	if ( parentType == vmObjectType_sequence ) cue = ((VMSequence*)cue).subsequent;
	if ( cue.type == vmObjectType_selector ) {
		VMSelector *sel				= (VMSelector*)cue;
		VMLiveData *saved_liveData	= [[sel.liveData copy] autorelease];
		[sel prepareSelection];
		if ( sel.sumOfInnerScores == 0 ) return;
		for( VMChance *ch in sel.cues ) {
			if ( ch.cachedScore == 0 ) continue;
			VMCue *c = [DEFAULTSONG data:ch.targetId];
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
- (void)drawBranchGraph:(VMCue*)cue
					  x:(CGFloat)x
					  y:(CGFloat)y
				   gapX:(CGFloat)gapX
		  parentCenterY:(CGFloat)parentCenterY
				 height:(CGFloat)summedHeight {
	x += gapX + vmpCellWidth;
	if ( x >= (self.frame.size.width - vmpCellWidth) ) return;

//	NSLog(@"%@ %.2f %.2f", cue.id, x, y);
	VMHash *hashAtX = [branchViewTemporary item:@( x )];
	VMString *yPositionKey = [cue.id stringByAppendingString:@"_y"];
	CGFloat yAlreadyDrawn = [hashAtX itemAsFloat:yPositionKey];
	BOOL drawChildren = NO;

	//VMFloat summedHeight = [hashAtX itemAsFloat:cue.id];
	if ( yAlreadyDrawn == 0 ) {
		if ( summedHeight < 3 ) return;
		CGFloat moddedYBase = [hashAtX itemAsFloat:@"moddedYBase"];
		if ( moddedYBase == 0 )
			yAlreadyDrawn = y + 0.01;
		else
			yAlreadyDrawn = moddedYBase + 0.01;
		
		[hashAtX setItem:VMFloatObj(yAlreadyDrawn + summedHeight) for:@"moddedYBase"];
	//	[[branchViewTemporary itemAsHash:@(x+55)] setItem:VMFloatObj(yAlreadyDrawn + summedHeight) for:@"moddedBase"];
		[hashAtX setItem:VMFloatObj(yAlreadyDrawn) for:[cue.id stringByAppendingString:@"_y"]];
	
		VMPCueCell *cc = [VMPCueCell cueCellWithCue:cue
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
	if ( cue.type == vmObjectType_reference ) cue = [DEFAULTSONG data:((VMReference*)cue).referenceId];
	int parentType = cue.type;
	if ( parentType == vmObjectType_sequence ) cue = ((VMSequence*)cue).subsequent;
	if ( cue.type == vmObjectType_selector ) {
		VMSelector *sel = (VMSelector*)cue;
		CGFloat currentY = y;
		for( VMChance *ch in sel.cues ) {
			VMCue *c = [DEFAULTSONG data:ch.targetId];
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
	VMHash *scoreForCueIds = [selector collectScoresOfCues:0 frameOffset:0 normalize:NO];
	[self buildSelectorCellForFrame:0
					 scoreForCueIds:scoreForCueIds
				   sumOfInnerScores:selector.sumOfInnerScores
					 highlightCueId:nil
				  cueIdsInLastFrame:nil
						  rect:rect];

}

- (void)buildSelectorCellForFrame:(int)offset
				   scoreForCueIds:(VMHash*)scoreForCueIds
				 sumOfInnerScores:(VMFloat)sumOfInnerScores
				   highlightCueId:(VMId*)highlightCueId
				cueIdsInLastFrame:(VMHash *)cueIdsInLastFrame
							 rect:(NSRect)rect {
	
    VMArray *cueIds = [scoreForCueIds sortedKeys];
    CGFloat pixPerScore = rect.size.height / sumOfInnerScores;
    CGFloat currentY = self.cellRect.origin.y + rect.origin.y;
    
    for ( VMId *cueId in cueIds ) {
        VMFloat score 		= [[scoreForCueIds item:cueId] floatValue];
        if (score <= 0) continue;
        CGFloat height  	= score * pixPerScore;
        CGRect	cellRect 	= CGRectMake(rect.origin.x,
                                         currentY,
                                         rect.size.width,
                                         height);
        VMPCueCell *cc = [VMPCueCell cueCellWithCue:[DEFAULTSONG data:cueId] frame:cellRect delegate:self];
		cc.selected = [cueId isEqualToString:highlightCueId];
        cc.alphaValue = ([cueIdsInLastFrame item:cueId] ? 0.5 : 1. );
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
	if ( self.cue.type != vmObjectType_selector ) return;
	VMSelector *selector = ((VMSelector*)self.cue);
	
	VMLiveData *saved_livedata = [[selector.liveData copy] autorelease];
	
	int base = 0;
	int num = self.frame.size.width / (vmpCellWidth+vmpCellMargin);
	
	CGFloat labelHeight		= 13;
	CGFloat testHeight		= 0;
	CGFloat marginHeight	= 5;
	CGFloat contentHeight 	= self.frame.size.height - labelHeight - testHeight - marginHeight - 10;
	VMHash *cueIdsInLastFrame = nil;
	
	for ( int frame = 0; frame < num; ++frame ) {
		
		CGFloat x = frame * (vmpCellWidth+vmpCellMargin)+vmpShadowBlurRadius;
		
		//	frame label
		NSTextField *tf = [NSTextField labelWithText:[NSString stringWithFormat:@"frame: %d", frame+1+base]
											   frame:CGRectMake(x, 0, vmpCellWidth, labelHeight )];
		tf.font = [NSFont systemFontOfSize:11];
		[self addSubview:tf];
		
		//	collect prior probability
		VMHash *scoreForCueIds = [selector collectScoresOfCues:0 frameOffset:(frame+base) normalize:NO];
		VMFloat sumOfInnerScores =selector.sumOfInnerScores;
		
		//	make selection
		DEFAULTEVALUATOR.shouldLog = NO;
		VMCue *selectedCue = [selector selectOne];
		DEFAULTEVALUATOR.shouldLog = YES;
		
		//	build
		[self buildSelectorCellForFrame:frame + base
						 scoreForCueIds:scoreForCueIds
					   sumOfInnerScores:sumOfInnerScores
						 highlightCueId:selectedCue.id
					  cueIdsInLastFrame:cueIdsInLastFrame
								   rect:CGRectMake(x, labelHeight,
												   vmpCellWidth, contentHeight)];
		cueIdsInLastFrame = [[scoreForCueIds copy] autorelease];
		
	}
	
	selector.liveData = saved_livedata;
	
}

/*---------------------------------------------------------------------------------
 
 set cue and draw graph
 
 ----------------------------------------------------------------------------------*/

- (void)setCue:(VMCue *)cue {	//	override
	//	TODO: level 0 = the cue before = @F{}
	
	[super setCue:cue];
	if ( self.frameGraphMode )
		[self drawFrameGraph];
	else {
		ReleaseAndNewInstance( branchViewTemporary, VMHash );
		DEFAULTEVALUATOR.shouldNotify = NO;
		[self collectBranchData:self.cue x:vmpCellWidth gapX:0 height:self.frame.size.height-10];
		DEFAULTEVALUATOR.shouldNotify = YES;
		
		[self drawBranchGraph:self.cue
							x:vmpCellWidth
							y:5.
						 gapX:0.
				parentCenterY:self.frame.size.height * 0.5 - 5
					   height:self.frame.size.height-10];
		ReleaseAndNil( branchViewTemporary );
	}
}


//	delegate
- (void)cueCellClicked:(VMPCueCell *)cueCell {
	for( NSView *v in self.subviews ) {
		if( ClassMatch(v, VMPCueCell ) && cueCell != v ) ((VMPCueCell*)v).selected = NO;
	}
	[VMPNotificationCenter postNotificationName:VMPNotificationCueSelected object:self userInfo:@{@"id":cueCell.cue.id}];
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
	if (self.cue.type == vmObjectType_sequence) {
		VMSequence *sequence = ((VMSequence*)self.cue);
		
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
			
			VMCue *cueAtPosition = [sequence cueAtIndex:position];
			if ( cueAtPosition.type == vmObjectType_selector ) {
				[self drawSelectorGraph:((VMSelector*)cueAtPosition)
								   rect:CGRectMake(x, labelHeight, vmpCellWidth, contentHeight)];
			} else {
				VMPCueCell * cueCell = [[[VMPCueCell alloc]initWithFrame:CGRectMake(x, labelHeight + vmpShadowBlurRadius, vmpCellWidth, contentHeight )] autorelease];
				cueCell.cue = cueAtPosition;
				cueCell.delegate = self;
				[self addSubview:cueCell];
			}
		}
	}
	
}

- (void)setCue:(VMCue *)cue {	//	override
	[super setCue:cue];
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
			VMPCueCell *cueCell = [[VMPSequenceGraph alloc]initWithFrame:
					   CGRectPlaceInTheMiddle(CGRectMake(0,
														 0,
														 width,
														 self.frame.size.height - 10),
											  CGPointMiddleOfRect(CGRectZeroOrigin(self.frame)))];
			[cueCell setData: self.data];
			[self addSubview: [cueCell taggedWith:vmpg_background]];
			[cueCell release];
			break;
		}
			
			//
			//	audio info editor
			//
		case vmObjectType_audioCue:
		case vmObjectType_audioInfo: {
			VMPAudioInfoEditorViewController *aie;
			if( ClassMatch( self.editorViewController, VMPAudioInfoEditorViewController )) {
				aie = (VMPAudioInfoEditorViewController*)self.editorViewController;
			} else {
				aie = [[[VMPAudioInfoEditorViewController alloc] initWithNibName:@"VMPAudioInfoEditorView" bundle:nil] autorelease];
			}
			[self addSubview:aie.view];
			aie.view.frame = self.frame;
			[aie setData: self.data.type == vmObjectType_audioInfo ? self.data : ((VMAudioCue*)self.data).audioInfoRef ];
			self.editorViewController = aie;
			break;
		}
		
		case vmObjectType_chance: {
			//	nothing
			
			break;
		}
			//
			//	cue cell view
			//
		default: {
			VMPCueCell *cueCell = [[VMPCueCell alloc] initWithFrame:
					   CGRectPlaceInTheMiddle(CGRectMake(0, 0, vmpCellWidth, MIN(self.frame.size.height - 10, 100)),
											  CGPointMiddleOfRect(CGRectZeroOrigin(self.frame)))];
			[cueCell setData: self.data];
			[self addSubview: [cueCell taggedWith:vmpg_background]];
			[cueCell release];
			break;
		}
	}
	

}

#pragma mark object browser delegate
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
	
	VMArray *cues  = [report item:@"cues"];
	VMArray *exits = [report item:@"parts"];
	
	double pixPerPercent = self.frame.size.height / 100;
	double percentsDisplayed = 0;
	
	for( int exitIdx = 0; exitIdx < exits.count; ++exitIdx ) {
		VMPReportRecord *data = [exits item:exitIdx];
		double percent = [data.percent doubleValue];
		VMPCueCell *cc = [[VMPCueCell alloc] initWithFrame:
						  CGRectMake(0,
									 percentsDisplayed * pixPerPercent,
									 vmpCellWidth,
									 percent * pixPerPercent
									 )];
		cc.cue = [[[VMCue alloc] init] autorelease];
		cc.cue.id = data.ident;
		percentsDisplayed += percent;
		[self addSubview:cc];
		[cc release];
	}
	
	pixPerPercent = self.frame.size.height / percentPerRow * 0.7;
	
	for( int column = 0; column < numberOfColumns; ++column ) {
		percentsDisplayed = 0;
		for (;;) {
			VMPReportRecord *data = [cues item:dataIndex];
			
			double percent = [data.percent doubleValue];
			VMPCueCell *cc = [[VMPCueCell alloc] initWithFrame:
							  CGRectMake(column * frameWidth + frameWidth,
										 percentsDisplayed * pixPerPercent,
										 vmpCellWidth,
										 percent * pixPerPercent
										 )];
			cc.cue = [[[VMAudioCue alloc] init] autorelease];
			cc.cue.id = data.ident;
			[self addSubview:cc];
			[cc release];
			++dataIndex;
			if ( dataIndex >= cues.count ) break;
			
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
@synthesize userGeneratedIdField=tf1_,vmpModifierField=tf2_,dataInfoField=tf3_;

- (void)awakeFromNib {
	self.flippedYCoordinate = NO;
	self.userGeneratedIdField.stringValue = @"";
	self.vmpModifierField.stringValue = @"";
	self.dataInfoField.stringValue = @"";
}

- (void)redraw {
	
	//	self.userGeneratedIdField.frame =	CGRectMake( 8, 10, self.frame.size.width - 16, 40 );
	//	self.vmpModifierField.frame =	 	CGRectMake( 8, 50, self.frame.size.width - 16, 16 );
	
	//	self.dataInfoField.frame =	 		CGRectMake( 8, 65, self.frame.size.width - 16, MAX( self.frame.size.height - 70 - 70, 0 ) );
	
	if ( [self.data isKindOfClass:[VMCue class]] ) {
		VMCue *c = (VMCue*)self.data;
		self.userGeneratedIdField.stringValue 	= c.userGeneratedId;
		self.vmpModifierField.stringValue		= c.VMPModifier ? c.VMPModifier : @"";
		self.userGeneratedIdField.editable
		= self.userGeneratedIdField.bezeled
		= self.userGeneratedIdField.drawsBackground
		= ( !c || c.VMPModifier.length == 0 );
		self.userGeneratedIdField.hidden		= NO;
	} else {
		self.userGeneratedIdField.stringValue 	= self.data.id ? self.data.id : @"";
		self.vmpModifierField.stringValue 		= @"";
		
		self.userGeneratedIdField.hidden		= (!self.data.id);
	}
	
	self.dataInfoField.stringValue = @"";
	
	if ( [self.data isKindOfClass:[VMSelector class] ] ) {
		VMSelector *s = (VMSelector*)self.data;
		self.dataInfoField.stringValue = [NSString stringWithFormat:@"counter: %ld\n",
										  s.counter
										  ];
		
	}
	
}

#pragma mark object info delegate
- (void)drawInfoWith:(VMData*)data {
	self.data = data;
	[self redraw];
}

@end


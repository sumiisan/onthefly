//
//  VMPObjectGraphView.m
//  GotchaP
//
//  Created by sumiisan on 2013/05/03.
//
//

#import "VMPObjectGraphView.h"
#import "VMSong.h"
#import "VMPAudioInfoEditorViewController.h"
#import "VMPNotification.h"
#import "VMPMacros.h"

/*---------------------------------------------------------------------------------
 
 selector graph
 
 ----------------------------------------------------------------------------------*/

#pragma mark -
#pragma mark *** Selector Graph ***
#pragma mark -

@implementation VMPSelectorGraph

- (VMHash *)buildSelectorCell:(int)offset
					 selector:(VMSelector *)selector
				contentHeight:(CGFloat)contentHeight
				  labelHeight:(CGFloat)labelHeight
			lastFrameCueStack:(VMHash *)lastFrameCueStack
							x:(CGFloat)x {
	
    VMHash *scoreForCueIds = [selector collectScoresOfCues:0 frameOffset:offset normalize:NO];
    VMArray *keys = [scoreForCueIds sortedKeys];
    CGFloat pixPerScore = contentHeight / selector.sumOfInnerScores;
    CGFloat currentY = self.cellRect.origin.y + labelHeight;
    
    for ( VMId *key in keys ) {
        VMFloat score 		= [[scoreForCueIds item:key] floatValue];
        if (score == 0) continue;
        CGFloat height  	= score * pixPerScore;
        CGRect	cellRect 	= CGRectMake(x,
                                         currentY,
                                         vmpCellWidth,
                                         height);
        VMPCueCell *cc = [[VMPCueCell alloc] initWithFrame: cellRect];
        cc.cue = [DEFAULTSONG data:key];
        cc.alphaValue = ([lastFrameCueStack item:key] ? 0.3 : 1. );
		cc.delegate = self;
        [self addSubview:cc];
        [cc release];
        currentY += height;
    }
    return scoreForCueIds;
}

- (void)redrawLocal {
	[self removeAllSubviews];
	if (self.cue.type == vmObjectType_selector) {
		VMSelector *selector = ((VMSelector*)self.cue);
		
		int base = 0;
		int num = self.frame.size.width / (vmpCellWidth+vmpCellMargin);
		
		CGFloat labelHeight		= 20;
		CGFloat testHeight		= 30;
		CGFloat marginHeight	= 5;
		CGFloat contentHeight 	= self.cellRect.size.height - labelHeight - testHeight - marginHeight;
		VMHash *lastFrameCueStack = nil;
		
		for ( int frame = 0; frame < num; ++frame ) {
			
			CGFloat x = frame * (vmpCellWidth+vmpCellMargin)+vmpShadowBlurRadius;
			
			//	frame label
			NSTextField *tf = [NSTextField labelWithText:[NSString stringWithFormat:@"frame: %d", frame+1+base]
												   frame:CGRectMake(x, 0, vmpCellWidth, labelHeight )];
			[self addSubview:tf];
			
			//	selector for frame
			VMHash *scoreForCueIds = [self buildSelectorCell:frame + base
													selector:selector
											   contentHeight:contentHeight
												 labelHeight:labelHeight
										   lastFrameCueStack:lastFrameCueStack
														   x:x];
			lastFrameCueStack = [[scoreForCueIds copy] autorelease];
			
			//	test selection
			VMCue *c = [selector selectOneTemporaryUsingScores:scoreForCueIds sumOfScores:0];
			VMPCueCell *cc = [[VMPCueCell alloc] initWithFrame: CGRectMake(x, labelHeight + contentHeight + marginHeight*2, vmpCellWidth, testHeight )];
			cc.cue = c;
			cc.delegate = self;
			[self addSubview:cc];
			[cc release];
		}
	}
}

- (void)setCue:(VMCue *)cue {	//	override
	[super setCue:cue];
	[self redrawLocal];
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
				[self buildSelectorCell:0
							   selector:(VMSelector*)cueAtPosition
						  contentHeight:contentHeight
							labelHeight:labelHeight
					  lastFrameCueStack:nil
									  x:x];
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
	[self removeAllSubviews];
	
	if ( ! self.data ) return;
	
	VMPCueCell *cueCell = nil;
	switch (self.data.type) {
		case vmObjectType_selector: {
			int frameWidth = (vmpCellWidth+vmpCellMargin);
			cueCell = [[VMPSelectorGraph alloc]initWithFrame:
					   CGRectPlaceInTheMiddle(CGRectMake(0,
														 0,
														 (int)(self.frame.size.width / frameWidth) * frameWidth,
														 self.frame.size.height - 10),
											  CGPointMiddleOfRect(CGRectZeroOrigin(self.frame)))];
			break;
			
		}
		case vmObjectType_sequence: {
			int width = ( vmpCellWidth + vmpCellMargin ) * (((VMSequence*)self.data).length +1 ) - vmpCellMargin;
			cueCell = [[VMPSequenceGraph alloc]initWithFrame:
					   CGRectPlaceInTheMiddle(CGRectMake(0,
														 0,
														 width,
														 self.frame.size.height - 10),
											  CGPointMiddleOfRect(CGRectZeroOrigin(self.frame)))];
			break;
		}
			
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
			
		default:
			cueCell = [[VMPCueCell alloc] initWithFrame:
					   CGRectPlaceInTheMiddle(CGRectMake(0, 0, vmpCellWidth, MIN(self.frame.size.height - 10, 100)),
											  CGPointMiddleOfRect(CGRectZeroOrigin(self.frame)))];
			break;
	}
	
	[cueCell setData: self.data];
	[self addSubview: [cueCell taggedWith:vmpg_background]];
	[cueCell release];
	
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


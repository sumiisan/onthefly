//
//  VMPGraph.m
//  VariableMediaPlayer
//
//  Created by  on 13/02/06.
//  Copyright (c) 2013 __MyCompanyName__. All rights reserved.
//

#import "VMPGraph.h"
#import "MultiPlatform.h"
#import "VMSong.h"
#import "VMPMacros.h"

CGRect CGRectMakeFromOriginAndSize( CGPoint origin, CGSize size ) {
	return CGRectMake(origin.x, origin.y, size.width, size.height );
}

CGRect CGRectZeroOrigin( CGRect rect ) {
	return CGRectMake(0, 0, rect.size.width, rect.size.height);
}

CGRect CGRectOffsetByPoint( CGRect rect, CGPoint offset ) {
	return CGRectOffset(rect, offset.x, offset.y);
}

CGRect CGRectPlaceInTheMiddle( CGRect rect, CGPoint offset ) {
	return CGRectOffset( CGRectOffsetByPoint( rect, offset ), -rect.size.width * 0.5, -rect.size.height * 0.5 );
}

CGPoint CGPointMiddleOfRect( CGRect rect ) {
	return CGPointMake( rect.size.width * 0.5 + rect.origin.x, 
					   rect.size.height * 0.5 + rect.origin.y );
}

//	private macros and funcs

#define GradientWithColors(c1,c2) \
[[[NSGradient alloc] initWithStartingColor:c1 endingColor:c2] autorelease]

#define BeginGC \
	NSGraphicsContext* context = [NSGraphicsContext currentContext];
#define SaveGC \
	[context saveGraphicsState];
#define RestoreGC \
	[context restoreGraphicsState];

#define LogColor(col) NSLog(@"R:%.2f G:%.2f B:%.2f H:%.2f S:%.2f B:%.2f",\
col.redComponent,col.greenComponent,col.blueComponent,col.hueComponent,col.saturationComponent,col.brightnessComponent);

#define LogRect(rect) NSLog(@"origin(%.2f,%.2f) size:(%.2f,%.2f)",\
rect.origin.x, rect.origin.y, rect.size.width, rect.size.height );


//	constants

static const CGFloat kCellWidth 	= 100.;
static const CGFloat kCellMargin	= 10.;

@implementation NSView (VMPExtension)

@end

/*---------------------------------------------------------------------------------
 *
 *
 *	NSColor extension
 *
 *
 *---------------------------------------------------------------------------------*/

@implementation NSColor (VMPExtension)

#define colorForType(type,r,g,b)\
[NSColor colorWithCalibratedRed:r green:g blue:b alpha:1],	VMIntObj( vmObjectType_##type     ),\
[[NSColor colorWithCalibratedRed:r green:g blue:b alpha:1]\
colorModifiedByHueOffset:0 saturationFactor:0.3 brightnessFactor:1.7],	VMIntObj( vmObjectType_##type * -1),

#define clipRange0to1(x) ((x)>1?1:((x)<0?0:(x)))

static 	VMHash *bgColorForType__ = nil;


- (NSColor*)colorModifiedByRedFactor:(const CGFloat)red greenFactor:(const CGFloat)green blueFactor:(const CGFloat)blue {
	CGFloat r 	= red 	* self.redComponent;
	CGFloat g 	= green * self.greenComponent;
	CGFloat b 	= blue	* self.blueComponent;
	return [NSColor colorWithCalibratedRed:( clipRange0to1(r) )
									 green:( clipRange0to1(g) )
									  blue:( clipRange0to1(b) )
									 alpha:self.alphaComponent
			];
}

- (NSColor*)colorModifiedByHueOffset:(const CGFloat)hue saturationFactor:(const CGFloat)saturation brightnessFactor:(const CGFloat)brightness {
	CGFloat h = self.hueComponent + hue;
	if ( h < 0. || h > 1. ) h = fmod( h + 1000, 1. );
	CGFloat s = self.saturationComponent * saturation;
	CGFloat b = self.brightnessComponent * brightness;
	return [NSColor colorWithCalibratedHue:h
								saturation: clipRange0to1( s )
								brightness: clipRange0to1( b )
									 alpha:self.alphaComponent
			];
}

+ (NSColor*)colorForDataType:(vmObjectType)type {
	if ( ! bgColorForType__ )
		bgColorForType__ = [[VMHash hashWithObjectsAndKeys:
							 colorForType( cue, 		0.3, 0.3, 0.45 )
							 colorForType( selector, 	0.2, 0.5, 0.0 )
							 colorForType( sequence, 	0.1, 0.3, 0.7 )
							 colorForType( audioCue, 	0.5, 0.0, 0.5 )
							 colorForType( audioInfo, 	0.5, 0.1, 0.0 )
							 colorForType( chance, 		0.5, 0.5, 0.0 )
							 colorForType( reference,	0.4, 0.4, 0.4 )
							 nil] retain];
	[bgColorForType__ setItem:[NSColor colorWithCalibratedWhite:0.9 alpha:1.] for:VMIntObj(0)];
	NSColor *c = (NSColor*)[bgColorForType__ item:VMIntObj(type)];

	return ( c ? c : [NSColor grayColor]);
}

+ (NSColor*)backgroundColorForDataType:(vmObjectType)type {
	if ( ! bgColorForType__ ) [NSColor colorForDataType:0];	//	dummy call
	NSColor *c = (NSColor*)[bgColorForType__ item:VMIntObj(((int)type)*-1)];
	return ( c ? c : [NSColor colorWithCalibratedWhite:.9 alpha:1.]);
}

@end

@implementation  NSTextField (VMPExtension)
+ (NSTextField*)labelWithText:(NSString *)text frame:(CGRect)frame {
	NSTextField *tf = [[[NSTextField alloc] initWithFrame:frame] autorelease];
	tf.stringValue = text;
	[tf setEditable:NO];
	[tf setBordered:NO];
	[tf setDrawsBackground:NO];
	return tf;
}
@end

/*---------------------------------------------------------------------------------
 
 graph base
 
 ----------------------------------------------------------------------------------*/

#pragma mark -
#pragma mark *** Graph Base ***
#pragma mark -

const CGFloat	vmpShadowOffset 	= 2.;
const CGFloat	vmpShadowBlurRadius = 3.;

@implementation VMPGraph
@synthesize tag=tag_;


- (id)taggedWith:(NSInteger)aTag {
	self.tag = aTag;
	return self;
}

- (NSShadow*)defaultShadow {
	NSShadow* aShadow = [[[NSShadow alloc] init] autorelease];
	[aShadow setShadowOffset:NSMakeSize(vmpShadowOffset, -vmpShadowOffset)];
	[aShadow setShadowBlurRadius:vmpShadowBlurRadius];	
	[aShadow setShadowColor:[[NSColor blackColor] colorWithAlphaComponent:0.5]];
	return aShadow;
}

- (void)removeAllSubviews {
	RemoveAllSubViews
}

- (void)redraw {
	//	virtual
}

-(void)viewDidMoveToWindow {
    [self redraw];
}

-(void)viewDidUnhide {
    [self redraw];
}

-(void)viewDidEndLiveResize {
    [self redraw];
}

#if ! TARGET_OS_IPHONE
- (BOOL)isFlipped {     //  matches NSView's coordinates to UIView
    return YES;
}
#endif


@end


/*---------------------------------------------------------------------------------
 
 cue cell
 
 ----------------------------------------------------------------------------------*/

#pragma mark -
#pragma mark *** Cue Cell ***
#pragma mark -

@implementation VMPCueCell
/*
@synthesize cue=cue_, score=score_, cellRect=cellRect_, 
			backgroundGradient=backgroundGradient_;
*/
- (void)setDelegate:(id<VMCueCellDelegate>)delegate {
	delegate_ = delegate;
}

- (id<VMCueCellDelegate>)delegate {
	return delegate_;
}

- (void)setCue:(VMCue *)cue {
	[_cue release];
	
	if (!cue) {
		_cue = nil;
		return;
	}
	
	_cue = [cue retain];
	NSColor *c0 = [NSColor backgroundColorForDataType:cue.type];
	NSColor *c1 = [c0 colorModifiedByHueOffset:-.05 saturationFactor:1. brightnessFactor:1.];
	NSColor *c2 = [c0 colorModifiedByHueOffset: .05 saturationFactor:1. brightnessFactor:1.];
	self.backgroundGradient = GradientWithColors(c1,c2);
}

#pragma mark private
- (void)initCell {
	button_ = [[NSButton alloc] init];
	[button_ setTarget:self];
	[button_ setAction:@selector(click:)];
	[button_ setTransparent:YES];
	[self addSubview:button_];
	
	//	default bg gradient
	self.backgroundGradient = GradientWithColors(VMPColorBy(.9, .9, .9, 1.), 
												 VMPColorBy(.7, .7, .7, 1.));
}

- (void)click:(id)sender {
	if ( self.delegate ) 
		[self.delegate cueCellClicked:self.cue.id];
}

#pragma mark init / dealloc
- (id)initWithFrame:(NSRect)frameRect {
	self = [super initWithFrame:frameRect];	
	if (self) {
		[self initCell];
		self.frame = frameRect;
	}
	return self;
}

- (id)init {
	self = [super init];
	if (self) {
		[self initCell];
	}
	return self;
}

- (void)dealloc {
	[button_ release];
	[_cue release];
	self.backgroundGradient = nil;
	[super dealloc];
}


#pragma mark accessor
- (void)setFrame:(NSRect)frameRect {
	self.cellRect = CGRectOffset( CGRectZeroOrigin(frameRect), vmpShadowBlurRadius, vmpShadowBlurRadius );
	frameRect = CGRectMake(frameRect.origin.x - vmpShadowBlurRadius,
						   frameRect.origin.y - vmpShadowBlurRadius,
						   frameRect.size.width + vmpShadowOffset + vmpShadowBlurRadius *2, 
						   frameRect.size.height + vmpShadowOffset + vmpShadowBlurRadius *2 );
	[super setFrame:frameRect];
	[button_ setFrame:self.cellRect];
}

#pragma mark public

#pragma mark drawing
- (void)drawRect:(NSRect)rect {
	
	if ( self.cellRect.size.width == 0 || self.cellRect.size.height == 0 ) return;
	
	BeginGC
	
	SaveGC {
		[[self defaultShadow] set];
		[VMPColorBy(.2, .2, .2, 1.) setStroke];
		NSBezierPath* cell = 
		[NSBezierPath bezierPathWithRoundedRect: self.cellRect xRadius:3. yRadius:3.];		
		[cell setLineWidth:0.5];
		[cell stroke];
		[self.backgroundGradient drawInBezierPath:cell angle:60];
	} RestoreGC
	
	SaveGC {
		
		NSDictionary *attr = [NSDictionary dictionaryWithObjectsAndKeys:
							  [NSColor blackColor], NSForegroundColorAttributeName,
							  [NSFont systemFontOfSize:10], NSFontAttributeName,
							  nil];

		[self.cue.id drawInRect:NSMakeRect(self.cellRect.origin.x +6.,
									  self.cellRect.origin.x +2.,
									  self.cellRect .size.width - 12.,
									  self.cellRect .size.height - 4. )
			withAttributes:attr];
		
		
	} RestoreGC
}

@end

/*---------------------------------------------------------------------------------
 
 selector cell
 
 ----------------------------------------------------------------------------------*/

#pragma mark -
#pragma mark *** Selector Cell ***
#pragma mark -

@implementation VMPSelectorCell

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
                                         kCellWidth, 
                                         height);
        VMPCueCell *cc = [[VMPCueCell alloc] initWithFrame: cellRect];
        cc.cue = [DEFAULTSONG data:key];
        cc.alphaValue = ([lastFrameCueStack item:key] ? 0.3 : 1. );
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
		int num = self.frame.size.width / (kCellWidth+kCellMargin);
		
		CGFloat labelHeight		= 20;
		CGFloat testHeight		= 30;
		CGFloat marginHeight	= 5;
		CGFloat contentHeight 	= self.cellRect.size.height - labelHeight - testHeight - marginHeight;
		VMHash *lastFrameCueStack = nil;
		
		for ( int frame = 0; frame < num; ++frame ) {
			
			CGFloat x = frame * (kCellWidth+kCellMargin)+vmpShadowBlurRadius;
			
			//	frame label
			NSTextField *tf = [NSTextField labelWithText:[NSString stringWithFormat:@"frame: %d", frame+1+base]
												   frame:CGRectMake(x, 0, kCellWidth, labelHeight )];
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
			VMPCueCell *cc = [[VMPCueCell alloc] initWithFrame: CGRectMake(x, labelHeight + contentHeight + marginHeight*2, kCellWidth, testHeight )];
			cc.cue = c;
			[self addSubview:cc];
			[cc release];
		}
	}	
}

- (void)setCue:(VMCue *)cue {	//	override
	[super setCue:cue];
	[self redrawLocal];
}


#pragma mark drawing
- (void)drawRect:(NSRect)rect {
/*	BeginGC
	
	SaveGC {
		[[self defaultShadow] set];
		[VMPColorBy(.2, .2, .2, 1.) setStroke];
		NSBezierPath* cell = 
		[NSBezierPath bezierPathWithRoundedRect: self.cellRect xRadius:3. yRadius:3.];		
		[cell setLineWidth:0.5];
		[cell stroke];
	} RestoreGC
*/	
}


@end



/*---------------------------------------------------------------------------------
 
 sequence cell
 
 ----------------------------------------------------------------------------------*/

#pragma mark -
#pragma mark *** Sequence Cell ***
#pragma mark -

@implementation VMPSequenceCell

- (void)redrawLocal {
	[self removeAllSubviews];
	if (self.cue.type == vmObjectType_sequence) {
		VMSequence *sequence = ((VMSequence*)self.cue);
		
		VMInt num = sequence.length + 1;
		
		CGFloat labelHeight		= 20;
		CGFloat contentHeight 	= self.cellRect.size.height - labelHeight;
		
		for ( int position = 0; position < num; ++position ) {
			
			CGFloat x = position * ( kCellWidth + kCellMargin ) + vmpShadowBlurRadius;
			
			NSTextField *tf = [NSTextField labelWithText: (position < sequence.length
                                                           ? [NSString stringWithFormat:@"position: %d", position +1]
                                                           : @"subsequent")
												   frame:CGRectMake(x, 0, kCellWidth, labelHeight )];
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
				VMPCueCell * cueCell = [[[VMPCueCell alloc]initWithFrame:CGRectMake(x, labelHeight + vmpShadowBlurRadius, kCellWidth, contentHeight )] autorelease];
				cueCell.cue = cueAtPosition;
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
@synthesize data=data_;

- (void)redraw {
	[self removeAllSubviews];

	if ( ! self.data ) return;
	
	VMPCueCell *cueCell;
	switch (self.data.type) {
		case vmObjectType_selector: {
			int frameWidth = (kCellWidth+kCellMargin);
			cueCell = [[VMPSelectorCell alloc]initWithFrame:
					   CGRectPlaceInTheMiddle(CGRectMake(0, 
														 0, 
														 (int)(self.frame.size.width / frameWidth) * frameWidth, 
														 self.frame.size.height - 10), 
											  CGPointMiddleOfRect(CGRectZeroOrigin(self.frame)))];
			break;
			
		}
		case vmObjectType_sequence: {
			int width = ( kCellWidth + kCellMargin ) * (((VMSequence*)self.data).length +1 ) - kCellMargin;
			cueCell = [[VMPSequenceCell alloc]initWithFrame:
					   CGRectPlaceInTheMiddle(CGRectMake(0, 
														 0, 
														 width, 
														 self.frame.size.height - 10), 
											  CGPointMiddleOfRect(CGRectZeroOrigin(self.frame)))];
			break;			
		}
		default:
			cueCell = [[VMPCueCell alloc] initWithFrame:
					   CGRectPlaceInTheMiddle(CGRectMake(0, 0, kCellWidth, MIN(self.frame.size.height - 10, 100)),
											  CGPointMiddleOfRect(CGRectZeroOrigin(self.frame)))];
			break;
	}
	
	cueCell.cue = (VMCue*)self.data;
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
	int frameWidth = (kCellWidth+kCellMargin);
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
									 kCellWidth,
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
										 kCellWidth,
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

- (void)redraw {
	
	self.userGeneratedIdField.frame =	CGRectMake( 8, 10, self.frame.size.width - 16, 40 );
	self.vmpModifierField.frame =	 	CGRectMake( 8, 50, self.frame.size.width - 16, 16 );
	
	self.dataInfoField.frame =	 		CGRectMake( 8, 65, self.frame.size.width - 16, MAX( self.frame.size.height - 70 - 70, 0 ) );
	
	if ( [self.data isKindOfClass:[VMCue class]] ) {
		VMCue *c = (VMCue*)self.data;
		self.userGeneratedIdField.stringValue 	= c.userGeneratedId;
		self.vmpModifierField.stringValue		= c.VMPModifier ? c.VMPModifier : @"";
	} else {	
		self.userGeneratedIdField.stringValue 	= self.data.id ? self.data.id : @"";
		self.vmpModifierField.stringValue 		= @"";
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





















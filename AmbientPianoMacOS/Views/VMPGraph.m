//
//  VMPGraph.m
//  OnTheFly
//
//  Created by  on 13/02/06.
//  Copyright (c) 2013 __MyCompanyName__. All rights reserved.
//

#import "VMPGraph.h"
#import "MultiPlatform.h"
#import "VMPNotification.h"
#import "VMPMacros.h"

CGSize CGSizeAdd( CGSize size1, CGSize size2 ) {
	return CGSizeMake( size1.width + size2.width, size1.height + size2.height );
}

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


#pragma mark -
#pragma mark VMPButton (double-clickable)

/*---------------------------------------------------------------------------------
 *
 *
 *	VMPButton
 *
 *
 *---------------------------------------------------------------------------------*/
@implementation VMPButton

- (id)init {
	assert(0);
	return self;
}

- (id)initWithFrame:(NSRect)frameRect {
	self = [super initWithFrame:frameRect];
	self.title = @"";
	self.bordered = NO;
	return self;
}

- (void)mouseDown:(NSEvent *)event {
	
	//
	//	because NSButton begins it's own event-loop when mouseDown,
	//	we can't receive mouseUp events unless we modify the mouseDown handler
	//
    NSInteger clickCount = [event clickCount];
	NSLog(@"click count:%ld",clickCount);
	if ( self.doubleAction && clickCount == 2 )
		[self.target performSelector:self.doubleAction withObject:event];
	else
		[super mouseDown:event];
}

@end


/*---------------------------------------------------------------------------------
 *
 *
 *	VMP TextField
 *
 *
 *---------------------------------------------------------------------------------*/

@implementation VMPTextField

- (BOOL)needsPanelToBecomeKey {
	return YES;
}

- (BOOL)becomeFirstResponder {
    BOOL result = [super becomeFirstResponder];
    if(result)
        [self performSelector:@selector(selectText:) withObject:self afterDelay:0];
    return result;
}

@end


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
[NSColor colorWithCalibratedRed:r green:g blue:b alpha:1],	@( vmObjectType_##type     ),\
[[NSColor colorWithCalibratedRed:r green:g blue:b alpha:1]\
colorModifiedByHueOffset:0 saturationFactor:0.3 brightnessFactor:1.7],	@( vmObjectType_##type * -1),

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
	[bgColorForType__ setItem:[NSColor colorWithCalibratedRed:0.9 green:0.9 blue:0.9 alpha:1.] for:@(0)];
	NSColor *c = (NSColor*)[bgColorForType__ item:@(type)];

	return ( c ? c : [NSColor grayColor]);
}

+ (NSColor*)backgroundColorForDataType:(vmObjectType)type {
	if ( ! bgColorForType__ ) [NSColor colorForDataType:0];	//	dummy call
	NSColor *c = (NSColor*)[bgColorForType__ item:@(((int)type)*-1)];
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

@implementation VMPGraph 

- (id)init {
	self = [super init];
#if VMP_DESKTOP
	self.flippedYCoordinate = YES;
#endif
	return self;
}

- (id)initWithFrame:(NSRect)frameRect {
	self = [super initWithFrame:frameRect];
#if VMP_DESKTOP
	self.flippedYCoordinate = YES;
#endif
	return self;
}

- (void)dealloc {
	self.topOverlay = nil;
	self.backgroundColor = nil;
	self.foregroundColor = nil;
	[super dealloc];
}

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

- (void)drawRect:(NSRect)dirtyRect{
	if (self.backgroundColor) {
		[self.backgroundColor set];
		NSRectFill(dirtyRect);
	}
	if (_graphDelegate) [_graphDelegate drawRect:dirtyRect ofView:(NSView *)self];
}

- (void)addTopOverlay {
	self.topOverlay = [[[VMPGraph alloc] initWithFrame:CGRectZeroOrigin(self.frame)] autorelease];
	self.topOverlay.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
	[self addSubview:self.topOverlay];
	if ( _graphDelegate) self.topOverlay.graphDelegate = _graphDelegate;
}

- (void)setNeedsDisplay:(BOOL)flag {
	[self.topOverlay setNeedsDisplay:flag];
	[super setNeedsDisplay:flag];
}

- (void)setGraphDelegate:(id<VMPGraphDelegate>)graphDelegate {
	[self.topOverlay setGraphDelegate:graphDelegate];
	_graphDelegate = graphDelegate;
}

- (id<VMPGraphDelegate>)graphDelegate {
	return _graphDelegate;
}

- (BOOL)isFlipped {
	return self.flippedYCoordinate;
}


- (CGFloat)x {
	return self.frame.origin.x;
}
- (CGFloat)y {
	return self.frame.origin.y;
}
- (CGFloat)width {
	return self.frame.size.width;
}
- (CGFloat)height {
	return self.frame.size.height;
}


- (id)clone {
	//
	// we're not using <NSCopying> because NSView doesn't support it.
	//
	id g = [[[[self class]  alloc] initWithFrame:self.frame] autorelease];
	//	autorelease because method name doesn't start with copy (or alloc)
	((VMPGraph*)g).flippedYCoordinate = self.flippedYCoordinate;
	((VMPGraph*)g).tag =self.tag;
	((VMPGraph*)g).backgroundColor = self.backgroundColor;
	((VMPGraph*)g).topOverlay = self.topOverlay;
	((VMPGraph*)g).graphDelegate = self.graphDelegate;
	return g;
}

/*
- (id)initWithCoder:(NSCoder *)aDecoder {
	self = [super initWithCoder:aDecoder];
#if VMP_DESKTOP
	self.flippedYCoordinate = YES;
#endif
	return self;
}
*/

//	NSCoding

- (id)initWithCoder:(NSCoder *)decoder {
	if ((self = [super initWithCoder:decoder])) {
		Deserialize(flippedYCoordinate, Bool )
		Deserialize(tag, Integer);
		Deserialize(backgroundColor, Object);
		Deserialize(foregroundColor, Object);
		Deserialize(topOverlay, Object);
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
	[super encodeWithCoder:encoder];
	Serialize(flippedYCoordinate, Bool )
	Serialize(tag, Integer);
	Serialize(backgroundColor, Object);
	Serialize(foregroundColor, Object);
	Serialize(topOverlay, Object);
}

@end

/*---------------------------------------------------------------------------------
 
 VMPStraightLine
 
 ----------------------------------------------------------------------------------*/

#pragma mark -
#pragma mark VMPStraightLine


@implementation VMPStraightLine

- (void)setPoint1:(NSPoint)point1 {
	_point1 = point1;
	self.frame = NSMakeRect(SMIN( _point1.x, _point2.x ),
							SMIN( _point1.y, _point2.y ),
							SMAX( SMAX(_point1.x, _point2.x ), 1. ),
							SMAX( SMAX(_point1.y, _point2.y ), 1. ));
}

- (void)setPoint2:(NSPoint)point2 {
	_point2 = point2;
	self.frame = NSMakeRect(SMIN( _point1.x, _point2.x ),
							SMIN( _point1.y, _point2.y ),
							SMAX( SMAX(_point1.x, _point2.x ), 1. ),
							SMAX( SMAX(_point1.y, _point2.y ), 1. ));
}

- (void)drawRect:(NSRect)dirtyRect{
	[self.foregroundColor setStroke];
	CGPoint localP1 = CGPointMake( _point1.x - self.frame.origin.x, _point1.y - self.frame.origin.y );
	CGPoint localP2 = CGPointMake( _point2.x - self.frame.origin.x, _point2.y - self.frame.origin.y );
	
	[NSBezierPath strokeLineFromPoint:localP1 toPoint:localP2];
}

- (id)clone {
	id sl = [super clone];
	((VMPStraightLine*)sl).point1 = self.point1;
	((VMPStraightLine*)sl).point2 = self.point2;
	return sl;
}

//	NSCoding

- (id)initWithCoder:(NSCoder *)decoder {
	if ((self = [super initWithCoder:decoder])) {
		Deserialize(point1, Point)
		Deserialize(point1, Point);
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
	[super encodeWithCoder:encoder];
	Serialize(point1, Point)
	Serialize(point1, Point);
}



@end



/*---------------------------------------------------------------------------------
 
 cue cell
 
 ----------------------------------------------------------------------------------*/

#pragma mark -
#pragma mark *** Cue Cell ***
#pragma mark -

@implementation VMPCueCell

+ (VMPCueCell*)cueCellWithCue:(VMCue*)cue frame:(NSRect)frame delegate:(id<VMPCueCellDelegate>)delegate {
	VMPCueCell *cc = [[[VMPCueCell alloc] initWithFrame:frame] autorelease];
	cc.cue = cue;
	cc.delegate = delegate;
	return cc;
}

- (void)setDelegate:(id<VMPCueCellDelegate>)delegate {
	delegate_ = delegate;
}

- (void)setData:(id)data {
	self.cue = data;
}

- (void)setSelected:(BOOL)selected {
	self.needsDisplay = ( _selected != selected );
	_selected = selected;
}

- (id<VMPCueCellDelegate>)delegate {
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
	[button_ release];
	button_ = [[VMPButton alloc] initWithFrame:self.cellRect];
	button_.target=self;
	button_.action=@selector(click:);
	button_.doubleAction=@selector(doubleClick:);
	[button_ setTransparent:YES];
	[self addSubview:button_];
	
	//	default bg gradient
	self.backgroundGradient = GradientWithColors(VMPColorBy(.9, .9, .9, 1.), 
												 VMPColorBy(.7, .7, .7, 1.));
}

- (void)click:(id)sender {
	self.selected = !self.selected;
	if ( self.delegate )
		[self.delegate cueCellClicked:self];
	[VMPNotificationCenter postNotificationName:VMPNotificationCueSelected
										 object:self
									   userInfo:@{@"id":self.cue.id} ];
	self.needsDisplay = YES;
}

- (void)doubleClick:(id)sender {
	[VMPNotificationCenter postNotificationName:VMPNotificationCueDoubleClicked
										 object:self
									   userInfo:@{@"id":self.cue.id}];
}

- (void)selectIfIdDoesMatch:(VMId*)cueId exclusive:(BOOL)exclusive {
	if ( [cueId isEqualToString:self.cue.id] ) {
		self.needsDisplay &= ( ! self.selected );
		self.selected = YES;
	} else if (exclusive) {
		self.needsDisplay &= ( self.selected );
		self.selected = NO;
	}
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
		[cell setLineWidth:self.isSelected ? 3.0 : 0.5];
		[cell stroke];
		[self.backgroundGradient drawInBezierPath:cell angle:60];
	} RestoreGC
	
	if ( self.cellRect.size.height > 10 && self.cue ) {
		SaveGC {
			NSMutableParagraphStyle *ps = ARInstance(NSMutableParagraphStyle);
			ps.lineBreakMode = NSLineBreakByCharWrapping;
			NSDictionary *attr = @{	NSForegroundColorAttributeName:[NSColor blackColor],
									NSFontAttributeName:[NSFont systemFontOfSize:10],
						   NSParagraphStyleAttributeName:ps};
			
			NSAttributedString *str = [[NSAttributedString alloc] initWithString:self.cue.id attributes:attr];
			NSSize textFrameSize = NSMakeSize( self.cellRect.size.width - 12, CGFLOAT_MAX );
			NSRect textFrameRect = [str boundingRectWithSize:textFrameSize options:NSStringDrawingUsesLineFragmentOrigin|NSStringDrawingUsesFontLeading];
			//NSLog(@"textFrameRectFor:%@ = %@", str.string, NSStringFromRect(textFrameRect));
			CGFloat verticalOffset = ( self.cellRect.size.height - textFrameRect.size.height ) * 0.5;
			if ( verticalOffset < 0 ) verticalOffset = 0;

			[self.cue.id drawInRect:NSMakeRect(self.cellRect.origin.x + 6.,
											   self.cellRect.origin.y + verticalOffset,
											   self.cellRect.size.width  - 12.,
											   self.cellRect.size.height - verticalOffset )
					 withAttributes:attr];
			
			[str release];
			
		} RestoreGC
	}
}

@end




















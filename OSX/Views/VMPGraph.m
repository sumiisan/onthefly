//
//  VMPGraph.m
//  OnTheFly
//
//  Created by  on 13/02/06.
//  Copyright (c) 2013 sumiisan. All rights reserved.
//

#import "VMPGraph.h"
#import "MultiPlatform.h"
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

/*---------------------------------------------------------------------------------
 *
 *
 *	NSString + Rotation
 *
 *
 *---------------------------------------------------------------------------------*/

@implementation NSString (VMPRotate)
//
//	code based on KoNEW's post on stackoverflow:
//	http://stackoverflow.com/questions/10289898/drawing-rotated-text-with-nsstring-drawinrect
//
- (void)drawVerticalInRect:(CGRect)rect withAttributes:(NSDictionary*)attributes {

	BeginGC
	SaveGC {
		CGAffineTransform t	= CGAffineTransformMakeTranslation(rect.origin.x + rect.size.width * 0.,
															   rect.origin.y + rect.size.height* 1. );
		CGAffineTransform r	= CGAffineTransformMakeRotation(4.71238898038/*angle/57.2957795131*/);	//290degrees
		
		CGContextRef cgContext = [context graphicsPort];
		CGContextConcatCTM( cgContext, t );
		CGContextConcatCTM( cgContext, r );
		
	//	[self drawAtPoint:rect.origin withAttributes:attributes];
		[self drawInRect:CGRectMake(rect.origin.y, rect.origin.x, rect.size.height, rect.size.width) withAttributes:attributes];
		
		//	maybe just restore GC ?
		CGContextConcatCTM( cgContext, CGAffineTransformInvert(r) );
		CGContextConcatCTM( cgContext, CGAffineTransformInvert(t) );
	}	RestoreGC
}
@end


/*---------------------------------------------------------------------------------
 *
 *
 *	NSColor + DataColors
 *
 *
 *---------------------------------------------------------------------------------*/

@implementation NSColor (VMPDataColors)

#define colorForType(type,r,g,b)\
[NSColor colorWithCalibratedRed:r green:g blue:b alpha:1],	@( vmObjectType_##type     ),\
[[NSColor colorWithCalibratedRed:r green:g blue:b alpha:1]\
colorModifiedByHueOffset:0 saturationFactor:0.3 brightnessFactor:1.7],	@( vmObjectType_##type * -1),

#define clipRange0to1(x) ((x)>1?1:((x)<0?0:(x)))

static 	VMHash *bgColorForType_static_ = nil;


- (VMPColor*)colorModifiedByRedFactor:(const CGFloat)red greenFactor:(const CGFloat)green blueFactor:(const CGFloat)blue {
	CGFloat r 	= red 	* self.redComponent;
	CGFloat g 	= green * self.greenComponent;
	CGFloat b 	= blue	* self.blueComponent;
	return [VMPColor colorWithCalibratedRed:( clipRange0to1(r) )
									 green:( clipRange0to1(g) )
									  blue:( clipRange0to1(b) )
									 alpha:self.alphaComponent
			];
}

- (VMPColor*)colorModifiedByHueOffset:(const CGFloat)hue saturationFactor:(const CGFloat)saturation brightnessFactor:(const CGFloat)brightness {
	CGFloat h = self.hueComponent + hue;
	if ( h < 0. || h > 1. ) h = fmod( h + 1000, 1. );
	CGFloat s = self.saturationComponent * saturation;
	CGFloat b = self.brightnessComponent * brightness;
	return [VMPColor colorWithCalibratedHue:h
								saturation: clipRange0to1( s )
								brightness: clipRange0to1( b )
									 alpha:self.alphaComponent
			];
}

+ (VMPColor*)colorForDataType:(vmObjectType)type {
	if ( ! bgColorForType_static_ )
		bgColorForType_static_ = Retain([VMHash hashWithObjectsAndKeys:
										 colorForType( fragment,			0.3, 0.3, 0.45 )
										 colorForType( selector,			0.2, 0.5, 0.0  )
										 colorForType( sequence,			0.1, 0.3, 0.7  )
										 colorForType( audioFragment,		0.5, 0.0, 0.5  )
										 colorForType( audioFragmentPlayer, 0.4, 0.0, 0.6  )	
										 colorForType( audioInfo,			0.5, 0.1, 0.0  )
										 colorForType( chance,				0.5, 0.5, 0.0  )
										 colorForType( reference,			0.4, 0.4, 0.4  )
										 colorForType( unknown,				0.8, 0.8, 0.8  )
										 nil]);
	[bgColorForType_static_ setItem:[VMPColor colorWithCalibratedRed:0.9 green:0.9 blue:0.9 alpha:1.] for:@(0)];
	VMPColor *c = (VMPColor*)[bgColorForType_static_ item:@(type)];

	return ( c ? c : [VMPColor grayColor]);
}

+ (NSColor*)backgroundColorForDataType:(vmObjectType)type {
	if ( ! bgColorForType_static_ ) [NSColor colorForDataType:0];	//	dummy call
	NSColor *c = (NSColor*)[bgColorForType_static_ item:@(((int)type)*-1)];
	return ( c ? c : [NSColor colorWithCalibratedWhite:.9 alpha:1.]);
}

@end

/*---------------------------------------------------------------------------------
 *
 *
 *	NSTextField + Label Creation
 *
 *
 *---------------------------------------------------------------------------------*/

@implementation  NSTextField (VMPLabelCreation)
+ (NSTextField*)labelWithText:(NSString *)text frame:(CGRect)frame {
	NSTextField *tf = AutoRelease([[NSTextField alloc] initWithFrame:frame]);
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
@synthesize graphDelegate = _graphDelegate;
@synthesize animating = _animating;
@synthesize tag = _tag;


- (void)init_internal {
#if VMP_OSX
	self.flippedYCoordinate = YES;
#endif
}

- (id)init {
	self = [super init];
	[self init_internal];
	return self;
}

- (id)initWithFrame:(NSRect)frameRect {		//	designated initializer
	self = [super initWithFrame:frameRect];
	[self init_internal];
	return self;
}

- (void)dealloc {
	VMNullify(topOverlay);
	VMNullify(backgroundColor);
	VMNullify(foregroundColor);
	Dealloc( super );;
}

//	override

- (void)setTag:(NSInteger)tag {
	_tag =tag;
}

- (NSInteger)tag {
	return _tag;
}

- (id)taggedWith:(NSInteger)aTag {
	self.tag = aTag;
	return self;
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

- (BOOL)isAnimating {
	return _animating;
}

- (void)drawRect:(NSRect)dirtyRect{
	if (self.backgroundColor) {
		[self.backgroundColor set];
		NSRectFill(dirtyRect);
	}
	if (_graphDelegate) [_graphDelegate drawRect:dirtyRect ofView:(NSView *)self];
}

- (void)addTopOverlay {
	self.topOverlay = AutoRelease([[VMPGraph alloc] initWithFrame:CGRectZeroOrigin(self.frame)] );
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

- (void)setX:(CGFloat)x {
	self.frame = CGRectMakeFromOriginAndSize( CGPointMake(x, self.frame.origin.y ), self.frame.size );
}

- (void)setY:(CGFloat)y {
	self.frame = CGRectMakeFromOriginAndSize( CGPointMake( self.frame.origin.x, y ), self.frame.size );
}

- (void)setWidth:(CGFloat)width {
	self.frame = CGRectMakeFromOriginAndSize( self.frame.origin, CGSizeMake( width, self.frame.size.height ));
}

- (void)setHeight:(CGFloat)height {
	self.frame = CGRectMakeFromOriginAndSize( self.frame.origin, CGSizeMake( self.frame.size.width, height ));
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
	id g = AutoRelease([[[self class]  alloc] initWithFrame:self.frame] );
	//	autorelease because method name doesn't start with copy (or alloc)
	((VMPGraph*)g).flippedYCoordinate = self.flippedYCoordinate;
	((VMPGraph*)g).tag =self.tag;
	((VMPGraph*)g).backgroundColor = self.backgroundColor;
	((VMPGraph*)g).foregroundColor = self.foregroundColor;
	((VMPGraph*)g).topOverlay = self.topOverlay;
	((VMPGraph*)g).graphDelegate = self.graphDelegate;
	return g;
}

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

//
//	animation
//
- (void)moveToRect:(NSRect)frameRect duration:(VMTime)duration {
	NSDictionary *dict = @{
						NSViewAnimationTargetKey: self,
	  NSViewAnimationStartFrameKey: [NSValue valueWithRect:self.frame],
	  NSViewAnimationEndFrameKey:   [NSValue valueWithRect:frameRect],
	  };
	
    NSViewAnimation *anim = [[NSViewAnimation alloc]
                             initWithViewAnimations:[NSArray arrayWithObject:dict]];
	//anim.animationBlockingMode = NSAnimationNonblockingThreaded;	//	test ss131123
	[anim setDuration:duration];
	_animating = YES;
    [anim startAnimation];
    [anim release];
	
	[self performSelector:@selector(endAnimation:) withObject:nil afterDelay:duration];
}

- (void)endAnimation:(id)something {
	_animating = NO;
	self.needsDisplay = YES;
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
	self.frame = NSMakeRect(MIN( _point1.x, _point2.x ),
							MIN( _point1.y, _point2.y ),
							MAX( fabs(_point1.x - _point2.x ), 1. ),
							MAX( fabs(_point1.y - _point2.y ), 1. ));
}

- (void)setPoint2:(NSPoint)point2 {
	_point2 = point2;
	self.frame = NSMakeRect(MIN( _point1.x, _point2.x ),
							MIN( _point1.y, _point2.y ),
							MAX( fabs(_point1.x - _point2.x ), 1. ),
							MAX( fabs(_point1.y - _point2.y ), 1. ));
}

- (void)drawRect:(NSRect)dirtyRect{
	[self.foregroundColor set];
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

- (id)initWithFrame:(NSRect)frameRect {
	self = [super initWithFrame:frameRect];
	self.tag = 'line';
	return self;
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


















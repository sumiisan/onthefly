//
//  VMPGraph.h
//  OnTheFly
//
//  Created by  on 13/02/06.
//  Copyright (c) 2013 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "VMDataTypes.h"

#ifndef VMPGraphMacros
#define VMPGraphMacros

#define GradientWithColors(c1,c2) \
AutoRelease([[NSGradient alloc] initWithStartingColor:c1 endingColor:c2])

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

#endif

//-------------------------	CGGeometry extension -------------------------
#ifndef CGGEOMETRY_EXTENSION_
#define CGGEOMETRY_EXTENSION_
CGSize CGSizeAdd( CGSize size1, CGSize size2 );
CGRect CGRectMakeFromOriginAndSize( CGPoint origin, CGSize size );
CGRect CGRectZeroOrigin( CGRect rect );
CGRect CGRectOffsetByPoint( CGRect rect, CGPoint offset );
CGRect CGRectPlaceInTheMiddle( CGRect rect, CGPoint offset );
CGPoint CGPointMiddleOfRect( CGRect rect );


#endif




#pragma mark -
#pragma mark conventional tag for views
//--------------------- conventional tag for views -----------------------------
enum {
	vmpg_background			=	'bg__',
} vmpg_conventional_tags;


#pragma mark -
#pragma mark NSColor (VMPDataColors)
//------------------------- NSColor (VMPDataColors) -----------------------------
@interface NSColor (VMPDataColors)
- (NSColor*)colorModifiedByRedFactor:(const CGFloat)red 
						 greenFactor:(const CGFloat)green 
						  blueFactor:(const CGFloat)blue;
- (NSColor*)colorModifiedByHueOffset:(const CGFloat)hue 
					saturationFactor:(const CGFloat)saturation
					brightnessFactor:(const CGFloat)brightness;
+ (NSColor*)colorForDataType:(vmObjectType)type;
+ (NSColor*)backgroundColorForDataType:(vmObjectType)type;
@end


#pragma mark -
#pragma mark NSString (VMPRotate)
//--------------------- NSString (VMPRotate) -----------------------------
@interface NSString (VMPRotate)
- (void)drawVerticalInRect:(CGRect)rect withAttributes:(NSDictionary*)attributes;
/*
- (void)drawInRect:(CGRect)rect
			 withAngle:(CGFloat)angle
		attributes:(NSDictionary*)attributes;*/
@end

#pragma mark -
#pragma mark NSTextField (LabelCreation)
//--------------------- NSTextField (LabelCreation) -------------------------
@interface NSTextField (VMPLabelCreation)
+ (NSTextField*)labelWithText:(NSString*)text frame:(CGRect)frame;
@end


#pragma mark -
#pragma mark VMPButton (double clickable)

//--------------------- VMPButton (double clickable) -----------------------------
@interface VMPButton : NSButton
@property (nonatomic, assign) SEL doubleAction;
@end

//--------------------- VMPTextField -----------------------------
#pragma mark -
#pragma mark VMPTextField (editable on first click)
@interface VMPTextField : NSTextField
@end




//--------------------- protocol graph-object -----------------------------

#pragma mark -
#pragma mark VMPDataGraphObject
@protocol VMPDataGraphObject <NSObject>
@required
- (void)setData:(id)data;
@end


#pragma mark -
#pragma mark VMPGraph

@protocol VMPGraphDelegate <NSObject>
- (void)drawRect:(NSRect)dirtyRect ofView:(NSView*)view;
@end

//------------------------- VMGraph (base) -----------------------------
@interface VMPGraph : NSView

@property (nonatomic, assign)	BOOL					flippedYCoordinate;
@property (nonatomic, assign)	NSInteger				tag;
@property (nonatomic, VMStrong)	NSColor					*backgroundColor;
@property (nonatomic, VMStrong)	NSColor					*foregroundColor;	//	unused, subclass may use it
@property (nonatomic, VMStrong)	VMPGraph				*topOverlay;
@property (nonatomic, assign)	id <VMPGraphDelegate>	graphDelegate;
@property (nonatomic, assign)	CGFloat					x;
@property (nonatomic, assign)	CGFloat					y;
@property (nonatomic, assign)	CGFloat					width;
@property (nonatomic, assign)	CGFloat					height;

- (void)redraw;
- (void)addTopOverlay;
- (void)removeAllSubviews;
- (id)taggedWith:(NSInteger)aTag;
- (id)clone;
- (void)moveToRect:(NSRect)frameRect duration:(VMTime)duration;

- (CGFloat)x;
- (CGFloat)y;
- (CGFloat)width;
- (CGFloat)height;

@end

@interface VMPStraightLine : VMPGraph
@property (nonatomic)			NSPoint					point1;
@property (nonatomic)			NSPoint					point2;

@end












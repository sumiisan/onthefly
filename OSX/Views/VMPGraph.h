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


typedef enum {
	vmp_actionby_user			=  1 << 16,
	vmp_actionby_half_automated	=  2 << 16,
	vmp_actionby_mediaPlayer	=  3 << 16,
	vmp_actionby_analyzer		=  4 << 16,
	vmp_actionby_system			=  8 << 16
} vmp_actionby;

typedef enum {
	vmp_action_move_next				= vmp_actionby_user				| 0x01,
	vmp_action_no_move					= vmp_actionby_user				| 0x00,
	vmp_action_move_back				= vmp_actionby_user				| 0xff,
	vmp_action_move_next_by_player		= vmp_actionby_mediaPlayer		| 0x01,
	
	vmp_action_select_on_browser		= vmp_actionby_user				| 0x10 << 8,
	vmp_action_move_browser_row			= vmp_actionby_user				| 0x11 << 8,
	vmp_action_select_during_textSearch = vmp_actionby_half_automated	| 0x18 << 8,
	vmp_action_select_on_textSearch 	= vmp_actionby_user				| 0x19 << 8,
	vmp_action_select_current_fragment	= vmp_actionby_user				| 0x1a << 8,
	vmp_action_select_on_referrerList	= vmp_actionby_user				| 0x1b << 8	| 0xff,		//	usual it's backward
	vmp_action_select_on_subWindow		= vmp_actionby_user				| 0x1c << 8,
	vmp_action_select_on_graph			= vmp_actionby_user				| 0x20 << 8 | 0x01,		//	assume forward.
	vmp_action_select_by_player			= vmp_actionby_mediaPlayer		| 0x30 << 8 | 0x01,		//	can only forward
	vmp_action_select_on_error			= vmp_actionby_system			| 0x80 << 8,
	vmp_action_select_on_reload			= vmp_actionby_system			| 0x81 << 8,
} vmp_action;



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












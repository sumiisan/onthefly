//
//  VMPGraph.h
//  OnTheFly
//
//  Created by  on 13/02/06.
//  Copyright (c) 2013 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "VMPrimitives.h"
#import "VMPObjectBrowserView.h"
#import "VMDataTypes.h"



//--------------------- constants -----------------------------

static const CGFloat	vmpCellWidth		= 100.;
static const CGFloat	vmpCellMargin		= 10.;
static const CGFloat	vmpShadowOffset 	= 2.;
static const CGFloat	vmpShadowBlurRadius = 3.;


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
#pragma mark NSView (VMPExtension)
//------------------------- NSView (VMPExtension) -----------------------------
@interface NSView (VMPExtension)
@end



#pragma mark -
#pragma mark NSColor (VMPExtension)
//------------------------- NSColor (VMPExtension) -----------------------------
@interface NSColor (VMPExtension)
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
#pragma mark NSTextField (VMPExtension)
//--------------------- NSTextField (VMPExtension) -------------------------
@interface NSTextField (VMPExtension)
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


@class VMPFragmentCell;

#pragma mark -
#pragma mark VMPFragmentCellDelegate
//------------------- protocol VMPFragmentCellDelegate -----------------------
@protocol VMPFragmentCellDelegate <NSObject>
- (void)fragmentCellClicked:(VMPFragmentCell*)fragCell;
@end



#pragma mark -
#pragma mark VMPGraph

@protocol VMPGraphDelegate <NSObject>
- (void)drawRect:(NSRect)dirtyRect ofView:(NSView*)view;
@end

//------------------------- VMGraph (base) -----------------------------
@interface VMPGraph : NSView {
	__weak id <VMPGraphDelegate> _graphDelegate;
}

@property (nonatomic, assign)	BOOL					flippedYCoordinate;
@property (nonatomic, assign)	NSInteger				tag;
@property (nonatomic, retain)	NSColor					*backgroundColor;
@property (nonatomic, retain)	NSColor					*foregroundColor;	//	unused, subclass may use it
@property (nonatomic, retain)	VMPGraph				*topOverlay;
@property (weak)				id <VMPGraphDelegate>	graphDelegate;

- (void)redraw;
- (void)addTopOverlay;
- (void)removeAllSubviews;
- (id)taggedWith:(NSInteger)aTag;
- (id)clone;


- (CGFloat)x;
- (CGFloat)y;
- (CGFloat)width;
- (CGFloat)height;

@end

@interface VMPStraightLine : VMPGraph
@property (nonatomic)			NSPoint					point1;
@property (nonatomic)			NSPoint					point2;

@end




#pragma mark -
#pragma mark VMPFragmentCell
//---------------------------- VMPFragmentCell -------------------------------
@interface VMPFragmentCell : VMPGraph <VMPDataGraphObject> {
@private
	VMPButton	*button_;
	__weak id <VMPFragmentCellDelegate> delegate_;
}
@property (nonatomic)							CGRect					cellRect;
@property (nonatomic,retain)					VMFragment 				*fragment;
@property (nonatomic)							VMFloat 				score;				//	not used internally
@property (nonatomic,retain)					NSGradient				*backgroundGradient;
@property (nonatomic,getter = isSelected)		BOOL					selected;
@property (nonatomic,weak)						id <VMPFragmentCellDelegate>	delegate;

- (void)selectIfIdDoesMatch:(VMId*)fragId exclusive:(BOOL)exclusive;
+ (VMPFragmentCell*)fragmentCellWithFragment:(VMFragment*)frag frame:(NSRect)frame delegate:(id<VMPFragmentCellDelegate>)delegate;
@end














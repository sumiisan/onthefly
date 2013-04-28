//
//  VMPGraph.h
//  VariableMediaPlayer
//
//  Created by  on 13/02/06.
//  Copyright (c) 2013 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "VMPrimitives.h"
#import "VMPObjectBrowserView.h"
#import "VMDataTypes.h"




//-------------------------	CGGeometry extension -------------------------
#ifndef CGGEOMETRY_EXTENSION_
#define CGGEOMETRY_EXTENSION_
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
#pragma mark VMCueCellDelegate
//------------------- protocol VMCueCellDelegate -----------------------
@protocol VMCueCellDelegate <NSObject>
- (void)cueCellClicked:(VMId*)cueId;
@end




#pragma mark -
#pragma mark VMPGraph
//------------------------- VMGraph (base) -----------------------------
@interface VMPGraph : NSView
- (void)redraw;
- (void)removeAllSubviews;
- (id)taggedWith:(NSInteger)aTag;
@property (assign)			NSInteger			tag;
@end





#pragma mark -
#pragma mark VMPCueCell
//---------------------------- VMPCueCell -------------------------------
@interface VMPCueCell : VMPGraph {
@private
	NSButton	*button_;
	__weak id <VMCueCellDelegate> delegate_;
}
@property (nonatomic,assign) CGRect					cellRect;
@property (nonatomic,retain) VMCue 					*cue;
@property (nonatomic,assign) VMFloat 				score;
@property (nonatomic,retain) NSGradient				*backgroundGradient;
@property (weak)			 id <VMCueCellDelegate>	delegate;
@end



#pragma mark -
#pragma mark VMPSelectorCell
//------------------------- VMPSelectorCell -----------------------------
@interface VMPSelectorCell : VMPCueCell
@end


#pragma mark -
#pragma mark VMPSequenceCell
//------------------------- VMPSequenceCell -----------------------------
@interface VMPSequenceCell : VMPSelectorCell
@end



#pragma mark -
#pragma mark VMPObjectGraphView
//------------------------ VMPObjectGraphView ----------------------------
@interface VMPObjectGraphView : VMPGraph <ObjectBrowserGraphDelegate>
@property (nonatomic, assign) VMData *data;
@end



#pragma mark -
#pragma mark VMPObjectGraphView
//------------------------ VMPObjectInfoView ----------------------------
@interface VMPObjectInfoView : VMPGraph <ObjectBrowserInfoDelegate>
@property (nonatomic, assign) VMData *data;
@property (assign) IBOutlet NSTextField *userGeneratedIdField;
@property (assign) IBOutlet NSTextField *vmpModifierField;
@property (assign) IBOutlet NSTextField *dataInfoField;
@end













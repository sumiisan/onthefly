//
//  VMPFragmentCell.h
//  OnTheFly
//
//  Created by sumiisan on 2013/05/18.
//
//

#import "VMPGraph.h"


//--------------------- constants -----------------------------

static const CGFloat	vmpCellWidth		= 100.;
static const CGFloat	vmpCellMargin		= 10.;
static const CGFloat	vmpShadowOffset 	= 2.;
static const CGFloat	vmpShadowBlurRadius = 3.;
static const CGFloat	vmpHeaderThickness	= 20.;
static const CGFloat	vmpCellCornerRadius	= 3.;



@class VMPFragmentGraphBase;

#pragma mark -
#pragma mark VMPFragmentCellDelegate
//------------------- protocol VMPFragmentCellDelegate -----------------------
@protocol VMPFragmentGraphDelegate <NSObject>
- (void)fragmentCellClicked:(VMPFragmentGraphBase*)fragCell;
@end

#pragma mark -
#pragma mark VMPFragmentGraphBase
@interface VMPFragmentGraphBase : VMPGraph <VMPDataGraphObject>
@property (nonatomic, VMStrong)					VMFragment				*fragment;
@property (nonatomic)							CGRect					contentRect;
@property (nonatomic, assign)					int						position;
@property (nonatomic, getter = isSelected)		BOOL					selected;
@property (nonatomic, getter = isPlaying)		BOOL					playing;
@property (nonatomic, VMStrong)					NSGradient				*backgroundGradient;
@property (nonatomic, unsafe_unretained)		id <VMPFragmentGraphDelegate>	delegate;

- (void)selectIfIdDoesMatch:(VMId*)fragId exclusive:(BOOL)exclusive;

@end

#pragma mark -
#pragma mark VMPFragmentHeader
//--------------------- VMPFragmentHeader -----------------------------
@interface VMPFragmentHeader : VMPFragmentGraphBase <VMPDataGraphObject>

@end



#pragma mark -
#pragma mark VMPFragmentCell
//---------------------------- VMPFragmentCell -------------------------------
@interface VMPFragmentCell : VMPFragmentGraphBase <VMPDataGraphObject>
//@property (nonatomic)							VMFloat 				score;				//	not used internally

+ (VMPFragmentCell*)fragmentCellWithFragment:(VMFragment*)frag
									   frame:(NSRect)frame
									delegate:(id<VMPFragmentGraphDelegate>)delegate;
@end




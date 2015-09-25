//
//  VMPFrontView.h
//  OnTheFly
//
//  Created by sumiisan on 2013/10/06.
//
//

#include "MultiPlatform.h"
#if VMP_IPHONE
#import <UIKit/UIKit.h>
#else
#import <QuartzCore/QuartzCore.h>
#import "VMPCanvas.h"
#endif
#import "VMPTimeManager.h"




@interface VMPFrontView :
#if VMP_OSX
VMPCanvas
#else
UIView
#endif
{
	VMPSize	screenSize;
	BOOL	useCALayer;
	
#if SUPPORT_32BIT_MAC
	BOOL	frontViewWasVisibleAtLastCall_;
	
	CGPoint		holeCenter_;
	CGFloat		dragOffsetY_;
	CGFloat		angle_;
	CGFloat		standardRadius_;
	CGFloat		hueOffset_;
	CGFloat		speed_;
	CGFloat		velocity_;
	CGFloat		targetVelocity_;
	
	NSMutableArray	*circles_;
	CGBlendMode		blendMode_;
	CAShapeLayer	*stem_;
	VMPLabel		*timeIndicator_;
	VMPPoint		touchBeginPoint_;
	CGFloat			stemLength_;
	
	VMDayPhase		lastDayPhase_;
	BOOL			shouldRecognizeTap_;
	VMInt			refreshScreenCounter_;
#if VMP_OSX
	VMPColor	*transitionColor_;
	VMTime		transitionRemain_;
#endif
#endif

}

@property (nonatomic)			CGPoint		holeCenter;
@property (nonatomic)			CGFloat		dragOffsetY;
@property (nonatomic)			CGFloat		angle;
@property (nonatomic)			CGFloat		standardRadius;
@property (nonatomic)			CGFloat		hueOffset;
@property (nonatomic)			CGFloat		speed;
@property (nonatomic)			CGFloat		velocity;
@property (nonatomic)			CGFloat		targetVelocity;

@property (nonatomic,retain)	NSMutableArray	*circles;

@property (nonatomic)			BOOL			frontViewWasVisibleAtLastCall;
@property (nonatomic,retain)	VMPLabel		*timeIndicator;
@property (nonatomic,retain)	CAShapeLayer	*stem;

@property (nonatomic)			CGBlendMode	blendMode;

@property (nonatomic)			VMDayPhase	lastDayPhase;
@property (nonatomic)			VMInt		refreshScreenCounter;

@property (nonatomic)			VMPPoint	touchBeginPoint;
@property (nonatomic)			CGFloat		stemLength;
@property (nonatomic)			BOOL		shouldRecognizeTap;

#if VMP_OSX
@property (nonatomic,retain)	VMPColor	*transitionColor;
@property (nonatomic)			VMTime		transitionRemain;
#endif

- (void)calculateDimensions:(CGSize)size;

@end

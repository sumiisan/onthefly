//
//  VMPFrontView.h
//  OnTheFly
//
//  Created by sumiisan on 2013/10/06.
//
//

#import <UIKit/UIKit.h>
#import "VMPTimeManager.h"

@interface VMPFrontView : UIView

@property (nonatomic)			CGPoint		holeCenter;
@property (nonatomic)			CGFloat		dragOffsetY;
@property (nonatomic)			CGFloat		angle;
@property (nonatomic)			CGFloat		standardRadius;
@property (nonatomic)			CGFloat		hueOffset;
@property (nonatomic)			CGFloat		speed;
@property (nonatomic)			CGFloat		velocity;
@property (nonatomic)			CGFloat		targetVelocity;
@property (nonatomic,retain)	NSMutableArray	*circles;
@property (nonatomic,retain)	CAShapeLayer	*stem;
@property (nonatomic,retain)	UILabel		*timeIndicator;
@property (nonatomic)			VMDayPhase	lastDayPhase;
@property (nonatomic)			UIApplicationState	lastAppState;
@property (nonatomic)			VMInt		refreshScreenCounter;

@property (nonatomic)			CGPoint		touchBeginPoint;
@property (nonatomic)			CGFloat		stemLength;
@property (nonatomic)			BOOL		shouldRecognizeTap;

@end

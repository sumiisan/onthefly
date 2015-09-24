//
//  VMPVineView.h
//  OnTheFly
//
//  Created by sumiisan on 2015/02/05.
//
//

#import <UIKit/UIKit.h>
#import <QuartzCore/CALayer.h>
#import "VMPrimitives.h"
#import "VMPSongPlayer.h"
#import "VMSong.h"

@interface VMPVinePart : CAShapeLayer

@end

@interface VMPLeaf : VMPVinePart

@end

@interface VMPCane : VMPVinePart
@property (nonatomic)			CGPoint topPoint;
@property (nonatomic)			VMFloat topAngle;
@property (nonatomic, retain)	VMId *fragId;
@property (nonatomic)			VMFloat angleOffset;

- (id)initWithId:(VMId*)inId
		   angle:(VMFloat)inAngle
		duration:(VMFloat)inDuration
		  weight:(VMFloat)inWeight
		selected:(BOOL)selected
			 hue:(VMFloat)hue;
- (void)calculatePointsForTime:(VMTime)elapsed;

@end

@interface VMPVineView : UIView



@end

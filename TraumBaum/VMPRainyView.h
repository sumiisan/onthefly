//
//  VMPDrippyButton.h
//  OnTheFly
//
//  Created by sumiisan on 2013/08/07.
//
//
#import "MultiPlatform.h"
#import "VMPCanvas.h"

#if VMP_IPHONE
#import <UIKit/UIKit.h>
#endif

@interface VMPDripParticle : NSObject {
	CGPoint	position_;
	CGFloat progress_;
	CGFloat maxsize_;
	CGFloat luminousity_;
}
@property (nonatomic)		CGPoint		position;
@property (nonatomic)		CGFloat		progress;
@property (nonatomic)		CGFloat		maxsize;
@property (nonatomic)		CGFloat		luminousity;

@end


@interface VMPRainyView : VMPCanvas {
	NSMutableArray *particles_;
	BOOL			enabled_;
}

@property (nonatomic,retain)				NSMutableArray *particles;
@property (nonatomic,getter = isEnabled)	BOOL			enabled;

@end

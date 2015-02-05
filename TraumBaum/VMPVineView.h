//
//  VMPVineView.h
//  OnTheFly
//
//  Created by sumiisan on 2015/02/05.
//
//

#import <UIKit/UIKit.h>
#import "VMPrimitives.h"
#import "VMPSongPlayer.h"

@interface VMPVine : CAShape

@property (nonatomic, retain) VMFragment *fragment;
@property (nonatomic) VMTime startTime;
@property (nonatomic) VMFloat angle;

@end

@interface VMPVineView : UIView {
	static VMPSongPlayer *songPlayer;
}

@property (nonatomic, retain) UIView *basePane;

- (void)setBranches;


@end

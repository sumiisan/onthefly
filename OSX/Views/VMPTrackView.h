//
//  VMPTrackView.h
//  OnTheFly
//
//  Created by cboy on 10/04/18.
//  Copyright 2010 sumiisan (sumiisan.com). All rights reserved.
//

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#endif

#import <QuartzCore/QuartzCore.h>
#import "VMPAudioPlayer.h"
#import "VMPCanvas.h"
#import "VMPTrackStrip.h"

@interface VMPTrackView : VMPCanvas {
    VMPTrackStrip   *tracks[ kNumberOfAudioPlayers ];
}

- (void)redraw: (int)idx player:(VMPAudioPlayer*)audioPlayer;
- (void)reLayout;
@end

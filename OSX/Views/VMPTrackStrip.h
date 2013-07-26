//
//  TrackView.h
//  VariableMusicPlayer
//
//  Created by cboy on 12/10/26.
//  Copyright 2012 sumiisan (aframasda.com). All rights reserved.
//

#import <Foundation/Foundation.h>
#import "VMPGraph.h"
#import "VMPCanvas.h"


@interface VMPTrackStrip : VMPCanvas {
@public
    NSTimeInterval	loading;
	NSTimeInterval	playing;
    NSTimeInterval  duration;
    NSTimeInterval  offset;
}

#if VMP_OSX
@property (nonatomic, VMStrong) NSTextField *caption;
#elif VMP_IPHONE
@property (nonatomic, VMStrong) UILabel *caption;
#endif
@property (nonatomic, VMStrong) NSString *audioFragmentId;

- (void)setInfoString:(NSString *)infoString;

@end

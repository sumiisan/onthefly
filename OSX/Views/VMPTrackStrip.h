//
//  TrackView.h
//  VariableMusicPlayer
//
//  Created by cboy on 12/10/26.
//  Copyright 2012 sumiisan (sumiisan.com). All rights reserved.
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

@property (nonatomic, VMStrong) VMPLabel *caption;
@property (nonatomic, VMStrong) NSString *audioFragmentId;

- (void)setInfoString:(NSString *)infoString;

@end


@interface VMPCoolTrackStrip : VMPTrackStrip {
}

@end
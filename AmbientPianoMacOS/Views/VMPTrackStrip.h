//
//  TrackView.h
//  VariableMusicPlayer
//
//  Created by cboy on 12/10/26.
//  Copyright 2012 sumiisan@gmail.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "VMPCanvas.h"


@interface VMPTrackStrip : VMPCanvas {
@public
    NSTimeInterval	loading;
	NSTimeInterval	playing;
    NSTimeInterval  duration;
    NSTimeInterval  offset;
}

@property (nonatomic, retain) NSTextField *caption;
@property (nonatomic, retain) NSString *audioCueId;

- (void)setInfoString:(NSString *)infoString;

@end

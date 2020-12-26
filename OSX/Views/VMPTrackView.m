//
//  VMPTrackView.m
//  OnTheFly
//
//  Created by cboy on 10/04/18.
//  Copyright 2010 sumiisan (sumiisan.com). All rights reserved.
//

#import "VMPTrackView.h"
#import "MultiPlatform.h"
#import "VMPMacros.h"
//#import "traumbaum_for_iOS-Swift.h"


@implementation VMPTrackView

- (id)initWithFrame:(VMPRect)frame {
    if ((self = [super initWithFrame:frame])) {
        // Initialization code
		CGFloat h = (int)( self.frame.size.height / kNumberOfAudioPlayers );
        for( int i = 0; i < kNumberOfAudioPlayers; ++i ) {
            tracks[i] = Retain([[VMPTrackStrip alloc] initWithFrame:
						  VMPMakeRect(1, i * h + 1, self.frame.size.width-2, h-1)]);
            [self addSubview:tracks[i]];
#ifdef VMP_OSX
            [tracks[i] setAutoresizingMask:NSViewWidthSizable];
#else
            [tracks[i] setAutoresizingMask:UIViewAutoresizingFlexibleWidth];
#endif
        }
   }
   return self;
}

#if ! TARGET_OS_IPHONE
- (BOOL)isFlipped {     //  matches NSView's coordinates to UIView
    return YES;
}
#endif

-(void)reLayout {
    CGFloat h = (int)( self.frame.size.height / kNumberOfAudioPlayers );
	for( int i = 0; i < kNumberOfAudioPlayers; ++i ) {
		tracks[i].infoString = [NSString stringWithFormat:@"[%i]",i+1];
        [tracks[i] setFrame:VMPMakeRect(1, i * h +1, self.frame.size.width-2, h -1 )];
    }
}

#if TARGET_OS_IPHONE
- (void)didMoveToWindow {
    self.backgroundColor = [UIColor blackColor];
    [self reLayout];
}
#endif

- (void)viewDidEndLiveResize {
    [self reLayout];
}

- (void)viewDidUnhide {
    [self reLayout];
}

- (void)viewDidMoveToSuperview {
    [self reLayout];
}

- (void)dealloc {
	for( int i = 0; i < kNumberOfAudioPlayers; ++i ) {
		Release( tracks[i] );
    }
    Dealloc( super );;
}

- (void)redraw: (int)idx player:(VMPlayerType*)audioPlayer {
    tracks[idx]->playing    = [audioPlayer currentTime] / audioPlayer.fileDuration;
	tracks[idx]->loading    = [audioPlayer loadedRatio];
    tracks[idx]->duration   = audioPlayer.fragDuration / audioPlayer.fileDuration;
    tracks[idx]->offset     = ( audioPlayer.offset / audioPlayer.fileDuration );
	if( [audioPlayer fragId] && [audioPlayer isBusy] && ( [audioPlayer currentTime] > -10. ) ) {
		tracks[idx].audioFragmentId = audioPlayer.fragId;
        tracks[idx].infoString = [NSString stringWithFormat:@"[%i]  %@ (%2.2f)",
                                    idx+1,
                               [audioPlayer fragId], 
                               [audioPlayer currentTime]];
        [tracks[idx] VMPSetAlpha:([audioPlayer isPlaying] ? 1. : 0.7 )];
	} else {
		tracks[idx].infoString = [NSString stringWithFormat:@"[%i]",idx+1];
        tracks[idx]->duration   = 0;
        [tracks[idx] VMPSetAlpha:0.7];
	}
    VMPSetNeedsDisplay(tracks[idx]);
}



@end

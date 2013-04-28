//
//  debugview.m
//  ambientPiano2
//
//  Created by cboy on 10/04/18.
//  Copyright 2010 sumiisan@gmail.com. All rights reserved.
//

#import "VMPTrackView.h"
#import "MultiPlatform.h"

@implementation VMPTrackView

- (id)initWithFrame:(VMPRect)frame {
    if ((self = [super initWithFrame:frame])) {
        // Initialization code
        for( int i = 0; i < kNumberOfAudioPlayers; ++i ) {
            tracks[i] = [[[VMPTrackStrip alloc] init] retain];
            [self addSubview:tracks[i]];
#ifdef VMP_OSX
            [tracks[i] setAutoresizingMask:NSViewMinXMargin+NSViewMaxXMargin+NSViewWidthSizable];
#else
            [tracks[i] setAutoresizingMask:UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleRightMargin|UIViewAutoresizingFlexibleWidth];
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
    CGFloat h = self.frame.size.height / kNumberOfAudioPlayers;
	for( int i = 0; i < kNumberOfAudioPlayers; ++i ) {
        
        tracks[i]->infoString = @"";
        [tracks[i] setFrame:VMPMakeRect(0, (int)(i*h), self.frame.size.width, (int)(h-5) )];
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
		[tracks[i] release];
    }
    [super dealloc];
}

- (void)redraw: (int)idx player:(VMPAudioPlayer*)audioPlayer {
    tracks[idx]->playing    = [audioPlayer currentTime] / audioPlayer.fileDuration;
	tracks[idx]->loading    = [audioPlayer loadedRatio];
    tracks[idx]->duration   = audioPlayer.cueDuration / audioPlayer.fileDuration;
    tracks[idx]->offset     = ( audioPlayer.offset / audioPlayer.fileDuration );
    [tracks[idx]->infoString release];
	if( [audioPlayer cueId] && [audioPlayer isBusy] && ( [audioPlayer currentTime] > -10. ) ) {
        tracks[idx]->infoString = [[NSString stringWithFormat:@"[%i]  %@ (%2.2f)", 
                                    idx+1,
                               [audioPlayer cueId], 
                               [audioPlayer currentTime]] retain];
        [tracks[idx] VMPSetAlpha:([audioPlayer isPlaying] ? 1. : 0.7 )];
	} else {
		tracks[idx]->infoString = [[NSString stringWithFormat:@"[%i]",idx+1] retain];
        tracks[idx]->duration   = 0;
        [tracks[idx] VMPSetAlpha:0.3];
	}
    VMPSetNeedsDisplay(tracks[idx]);
}


- (void)drawRect:(VMPRect)rect {
    [super drawRect:rect];
}



@end

//
//  SongPlayer.h
//  OnTheFly
//
//  Created by cboy on 10/02/26.
//  Copyright 2010 sumiisan (sumiisan.com). All rights reserved.
//

#import <Foundation/Foundation.h>
#import "VMSong.h"

#import "VMPAudioPlayer.h"

#import "VMPTrackView.h"
#import "VMPlayerBase.h"

#define DEFAULTSONGPLAYER [VMPSongPlayer defaultPlayer]



/*---------------------------------------------------------------------------------
 *
 *
 *	Play time accumulator
 *
 *
 *---------------------------------------------------------------------------------*/
@interface VMPPlayTimeAccumulator : VMHash {
#if SUPPORT_32BIT_MAC
	VMTime	playingTimeOfCurrentPart_;
	VMId	*currentPartId_;
#endif
}
@property (nonatomic, assign)			VMTime				playingTimeOfCurrentPart;
@property (nonatomic, VMStrong)			VMId				*currentPartId;

- (void)addAudioFragment:(VMAudioFragment*)audioFragent;
@end

/*---------------------------------------------------------------------------------
 *
 *
 *	Queued Cue
 *
 *
 *---------------------------------------------------------------------------------*/


@interface VMPQueuedFragment : NSObject {
@public
	__strong	VMAudioFragmentPlayer	*audioFragmentPlayer;
				VMTime					cueTime;
				VMTimeRange				cuePoints;		//	store modulated dur / offs
	__unsafe_unretained		VMPlayerType			*player;
}
@end


@interface VMPAutoFader : NSObject {
	//	fade
@public
    VMTime					fadeDuration;
    VMTime					fadeStartPoint;
	VMFloat					fadeStartVolume;
	VMFloat					fadeEndVolume;

}
- (VMTime)fadeTimeElapsedAt:(VMTime)time;
- (VMVolume)currentFaderVolume:(VMTime)time;
- (void)setFadeFrom:(VMFloat)startVolume to:(VMFloat)endVolume length:(VMTime)seconds currentTime:(VMTime)time;
- (BOOL)isActive;
@end

/*---------------------------------------------------------------------------------
 *
 *
 *	Song Player
 *
 *	Media player for audio.
 *
 *---------------------------------------------------------------------------------*/

@interface VMPSongPlayer : VMPlayerBase {	
	//	audio players
	VMArray					*audioPlayerList;
	//	cue queueing
	VMArray					*fragQueue;
	VMAudioFragmentPlayer	*lastFiredFragment_;
	
	//	volume
    VMVolume				globalVolume;

	BOOL					startPlayAfterSetFragment;

	//	view
	UInt64					frameCounter;
  __weak        VMSong *song_;
//	__unsafe_unretained		VMSong		*song_;
	
	
#if SUPPORT_32BIT_MAC
	BOOL					engineIsWarm_;
	BOOL					dimmed_;
	VMTime					nextCueTime_;
	VMPPlayTimeAccumulator	*playTimeAccumulator_;
	VMPTrackView			*trackView_;
	VMPAutoFader			*mainFader_;
	VMPAutoFader			*dimmer_;
	BOOL					simulateIOSAppBackgroundState_;
	
#endif

}

@property (weak)							VMSong 				*song;				//	the Variable Music Data
@property (atomic, assign)					VMTime				nextCueTime;
@property (nonatomic, getter = isDimmed)	BOOL				dimmed;				//	volume dimmer
@property (readonly, getter = isWarmedUp)	BOOL				engineIsWarm;		//
@property (nonatomic, VMReadonly)			VMAudioFragment		*lastFiredFragment;
@property (nonatomic, VMStrong)				VMPAutoFader		*mainFader;
@property (nonatomic, VMStrong)				VMPAutoFader		*dimmer;

@property (nonatomic)						BOOL				simulateIOSAppBackgroundState;

//	for calculating playing time of part
@property (nonatomic, VMStrong)				VMPPlayTimeAccumulator	*playTimeAccumulator;


//	displaying
@property (VMWeak)							VMPTrackView 		*trackView;			//	tracks view
@property (nonatomic, readonly)             BOOL isRunning;

+ (VMPSongPlayer*)defaultPlayer;

//	audio player
- (int)numberOfAudioPlayers;
- (VMPlayerType*)audioPlayerForFileId:(VMId*)fileId;

//	player control
- (void)warmUp;
- (void)coolDown;

- (void)start;
- (void)startWithFragmentId:(VMId*)fragId;
- (void)stop;
- (void)stopAndDisposeQueue;
- (void)reset;
- (void)fadeoutAndStop:(VMTime)duration;
- (void)setFadeFrom:(VMFloat)startVolume to:(VMFloat)endVolume length:(VMTime)seconds;// setDimmed:(BOOL)dimmerState;

- (void)setGlobalVolume:(VMFloat)volume;

- (void)setFragmentId:(VMId*)fragId fadeOut:(BOOL)fadeFlag restartAfterFadeOut:(BOOL)inRestartAfterFadeOut;
- (void)setNextFragmentId:(VMId*)fragId;

- (void)setLimiterState:(BOOL)state;
- (VMPView*)limiterIndicator;

//	queue
- (void)flushFiredFragments;	
- (void)flushUnfiredFragments;
- (void)flushFinishedFragments;
- (void)adjustCurrentTimeToQueuedFragment;
- (VMInt)numberOfUnfiredFragments;

- (void)update;	//	force call runloop

//	util
- (VMString*)filePathForFileId:(VMString*)fileId;

@end

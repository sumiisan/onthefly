//
//  SongPlayer.h
//  OnTheFly
//
//  Created by cboy on 10/02/26.
//  Copyright 2010 sumiisan (aframasda.com). All rights reserved.
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
@interface VMPPlayTimeAccumulator : VMHash
@property (nonatomic, assign)				VMTime				playingTimeOfCurrentPart;
@property (nonatomic, retain)				VMId				*currentPartId;

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
	VMAudioFragment		*audioFragment;
	VMTime				cueTime;
	VMTimeRange			cuePoints;		//	store modulated dur / offs
	VMPAudioPlayer		*player;
}
@end

/*---------------------------------------------------------------------------------
 *
 *
 *	Song Player
 *
 *
 *---------------------------------------------------------------------------------*/

@interface VMPSongPlayer : VMPlayerBase {	
	//	audio players
	VMArray				*audioPlayerList;
	//	cue queueing
	VMArray				*fragQueue;
	
	//	volume
    VMVolume         	globalVolume;

	//	fade
    VMTime  			fadeDuration;
    VMTime			  	fadeStartPoint;
	VMFloat				fadeStartVolume;
	VMFloat				fadeEndVolume;
	BOOL				startPlayAfterSetFragment;

	//	view
	UInt64				frameCounter;
	__weak VMSong		*song_;
}

@property (weak)							VMSong 				*song;				//	the Variable Music Data
@property (atomic, assign)					VMTime				nextCueTime;
@property (nonatomic, getter = isDimmed)	BOOL				dimmed;				//	volume dimmer
@property (readonly,getter = isWarmedUp)	BOOL				engineIsWarm;		//

//	for calculating playing time of part
@property (nonatomic, retain)				VMPPlayTimeAccumulator	*playTimeAccumulator;


//	displaying
@property (assign)							VMPTrackView 		*trackView;			//	tracks view

+ (VMPSongPlayer*)defaultPlayer;

//	audio player
- (int)numberOfAudioPlayers;
- (VMPAudioPlayer*)audioPlayerForFileId:(VMId*)fileId;

//	player control
- (void)warmUp;
- (void)coolDown;

- (void)start;
- (void)startWithFragmentId:(VMId*)fragId;
- (void)stop;
- (void)reset;
- (void)fadeoutAndStop:(VMTime)duration;
- (void)setFadeFrom:(VMFloat)startVolume to:(VMFloat)endVolume length:(VMTime)seconds setDimmed:(BOOL)dimmerState;

- (void)setGlobalVolume:(VMFloat)volume;

- (void)setFragmentId:(VMId*)fragId fadeOut:(BOOL)fadeFlag restartAfterFadeOut:(BOOL)inRestartAfterFadeOut;
- (void)setNextFragmentId:(VMId*)fragId;

//	queue
- (void)flushFiredFragments;	
- (void)flushUnfiredFragments;
- (void)flushFinishedFragments;
- (void)adjustCurrentTimeToQueuedFragment;
- (VMInt)numberOfUnfiredFragments;

- (void)update;	//	force call runloop
- (BOOL)isRunning;


//	util
- (VMString*)filePathForFileId:(VMString*)fileId;

@end

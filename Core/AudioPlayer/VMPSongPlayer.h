//
//  SongPlayer.h
//  OnTheFly
//
//  Created by cboy on 10/02/26.
//  Copyright 2010 sumiisan (aframasda.com). All rights reserved.
//

#import <Foundation/Foundation.h>
#import "VMPAudioPlayer.h"
#import "VMPrimitives.h"
#import "VMDataTypes.h"
#import "VMSong.h"

#import "VMPTrackView.h"
#import "VMPlayerBase.h"

#define DEFAULTSONGPLAYER [VMPSongPlayer defaultPlayer]

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
	VMTime			cueTime;
	VMTimeRange		cuePoints;		//	store modulated dur / offs
	VMPAudioPlayer	*player;
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
}

@property (VMNonatomic retain)				VMSong 				*song;				//	the Variable Music Data
@property (assign)							VMPTrackView 		*trackView;			//	tracks view
@property (atomic)							VMTime				nextCueTime;
@property (nonatomic, getter = isDimmed)	BOOL				dimmed;
@property (readonly,getter = isWarmedUp)	BOOL				engineIsWarm;		//

+ (VMPSongPlayer*)defaultPlayer;

- (int)numberOfAudioPlayers;


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

- (void)flushFiredFragments;	
- (void)flushUnfiredFragments;
- (void)flushFinishedFragments;
- (void)adjustCurrentTimeToQueuedFragment;
- (VMInt)numberOfUnfiredFragments;

- (void)update;
- (BOOL)isRunning;


//	util
- (VMString*)filePathForFileId:(VMString*)fileId;

@end

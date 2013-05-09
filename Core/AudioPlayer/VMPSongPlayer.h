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


@interface VMPQueuedCue : NSObject {
@public
	VMAudioCue		*audioQue;
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
	VMArray				*cueQueue;
	
	//	volume
    VMVolume         	globalVolume;

	//	fade
    VMTime  			fadeDuration;
    VMTime			  	fadeStartPoint;
	VMFloat				fadeStartVolume;
	VMFloat				fadeEndVolume;
	BOOL				startPlayAfterSetCue;

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
- (void)startWithCueId:(VMId*)cueId;
- (void)stop;
- (void)reset;
- (void)fadeoutAndStop:(VMTime)duration;
- (void)setFadeFrom:(VMFloat)startVolume to:(VMFloat)endVolume length:(VMTime)seconds setDimmed:(BOOL)dimmerState;

- (void)setGlobalVolume:(VMFloat)volume;

- (void)setCueId:(VMId*)cueId fadeOut:(BOOL)fadeFlag restartAfterFadeOut:(BOOL)inRestartAfterFadeOut;
- (void)setNextCueId:(VMId*)cueId;

- (void)flushFiredCues;	
- (void)flushUnfiredCues;
- (void)flushFinishedCues;
- (void)adjustCurrentTimeToQueuedCue;
- (VMInt)numberOfUnfiredCues;

- (void)update;
- (BOOL)isRunning;


//	util
- (VMString*)filePathForFileId:(VMString*)fileId;

@end

//
//  SongPlayer.m
//  OnTheFly
//
//  Created by cboy on 10/02/26.
//  Copyright 2010 sumiisan (aframasda.com). All rights reserved.
//

#import "VMPSongPlayer.h"
#import "MultiPlatform.h"
#import "VMException.h"
#import "VMPMacros.h"
#import "VMScoreEvaluator.h"
#import "VMPNotification.h"

#if VMP_DESKTOP
#import "VMPlayerOSXDelegate.h"
#endif

//#include <math.h>

#pragma mark -
#pragma mark VMPQueue

//	VMPQueuedCue
@implementation VMPQueuedCue
- (NSString*)description {
	return [NSString stringWithFormat:@"QC<%@> %.2f-%.2f (%@)", 
			audioQue ? audioQue.id : @"no que",
			cueTime - cuePoints.start,
			cueTime - cuePoints.start + cuePoints.end,
			player ? player.description : @"no player"
			];
}
@end


@interface VMPSongPlayer(private)
-(void)setCue;
@end


/*---------------------------------------------------------------------------------
 *
 *
 *	VMP Song Player
 *
 *
 *---------------------------------------------------------------------------------*/

#pragma mark -
#pragma mark VMPSongPlayer

@implementation VMPSongPlayer

@synthesize trackView=trackView_;
@synthesize engineIsWarm=engineIsWarm_;
@synthesize dimmed=dimmed_;
@synthesize song=song_;

@synthesize nextCueTime;

static const VMFloat	secondsPreroll			= 0.3;
static const VMFloat	secondsPreparePlayer	= 3.;
static const VMFloat	secondsLookAhead		= secondsPreparePlayer + 0.5;
static const VMFloat	secondsAutoFadeOut		= 0.5;
static VMPSongPlayer 	*songPlayer_singleton__ = nil;


- (void)watchNextCueTimeForDebug {
	if ( self.nextCueTime < 0 || self.nextCueTime > 99999 )
		NSLog(@"debug1");
}

#pragma mark -
#pragma mark volume and fade


- (VMTime)fadeTimeElapsed {
	return self.currentTime - fadeStartPoint;
}

- (VMVolume)currentFaderVolume {
    float faderVolume = fadeEndVolume;
    if( fadeStartPoint > 0 && fadeDuration > 0 ) {
        NSTimeInterval elapsed = [self fadeTimeElapsed];
        if( elapsed < fadeDuration ) {
			VMFloat elapsedRatio = ( elapsed / fadeDuration );
			VMFloat exponential = ( exp( elapsedRatio ) -1 ) / 1.71828182845904523536028747135266250;	//	M_E -1
			VMFloat range = ( fadeEndVolume - fadeStartVolume );
            faderVolume = fadeStartVolume + range * exponential;
		//	NSLog(@"range = %.3f, elapsed = %.3f, exp = %.3f, fader = %.3f", range, elapsedRatio, exponential, faderVolume );
		} else {
			fadeStartPoint = -1;
			fadeDuration = -1;
		}
		VMVolume max = MAX( fadeStartVolume, fadeEndVolume );
		VMVolume min = MIN( fadeStartVolume, fadeEndVolume );
		faderVolume = ( faderVolume > max ? max : ( faderVolume < min ? min : faderVolume ));
    }
	return faderVolume;
}

- (VMVolume)currentVolume {
    return [self currentFaderVolume] * globalVolume;
}

- (void)setFadeFrom:(VMFloat)startVolume to:(VMFloat)endVolume length:(VMTime)seconds setDimmed:(BOOL)dimmerState {
	NSLog(@"beginsetfade");
	VMTime fadeTimeRemain = fadeDuration - [self fadeTimeElapsed];
	dimmed_ = dimmerState;
	VMFloat dimmFactor = dimmed_ ? 0.1 : 1.0;
		
	fadeStartVolume = startVolume >= 0 ? startVolume * dimmFactor : [self currentFaderVolume];
	fadeEndVolume   = endVolume * dimmFactor;
	if( fadeTimeRemain < seconds ) {
		fadeDuration = seconds;
		fadeStartPoint = self.currentTime;
	}	
	NSLog(@"end setfade from:%.3f to %.3f", fadeStartVolume, fadeEndVolume );
}

- (void)setDimmed:(BOOL)dimmed {
	if( dimmed_ == dimmed ) return;	//	no change
	dimmed_ = dimmed;
	[self setFadeFrom:-1 to:1 length:1. setDimmed:dimmed_];
}

#pragma mark -
#pragma mark queue related

- (VMPQueuedCue*)queue:(VMAudioCue*)audioQue at:(VMTime)cueTime {
	if ( ! audioQue ) {
		[VMException raise:@"Attempted to queue an empty cue." format:@"at %f", cueTime ];
	}
	
	if ( Pittari( audioQue.fileId, @"*" ) ) return nil;	//	ignore empty file.
	
	VMPQueuedCue *c = ARInstance(VMPQueuedCue);
	c->cueTime 	= cueTime;
	c->audioQue = audioQue;
	
	//	copy modulated duration and offset.
	c->cuePoints.start = audioQue.modulatedOffset;
	c->cuePoints.end = audioQue.modulatedDuration;
	
	[cueQueue push:c];
	return c;
}

- (void)flushFiredCues {
	VMInt c = [cueQueue count];
	for ( int i = 0; i < c; ++i ) {
		VMPQueuedCue *cue = [cueQueue item:i];
		if ( cue->player && cue->player.didPlay ) {
			[cueQueue deleteItem:i];
			--i;
			--c;
		}
	}	
}

- (void)flushUnfiredCues {
	VMInt c = [cueQueue count];
	for ( int i = 0; i < c; ++i ) {
		VMPQueuedCue *cue = [cueQueue item:i];
		if ( (!cue->player) || ( !cue->player.didPlay) ) {
			[cueQueue deleteItem:i];
			--i;
			--c;
		}
	}	
}


- (void)flushFinishedCues {
	VMInt c = [cueQueue count];
	for ( int i = 0; i < c; ++i ) {
		VMPQueuedCue *cue = [cueQueue item:i];
		if ( !cue || ( cue->player && (!cue->player.isBusy) ) ) {
			[cueQueue deleteItem:i];
			--i;
			--c;
		}
	}	
}


- (VMInt)numberOfUnfiredCues {
	[self flushFinishedCues];
	return cueQueue.count;
}

- (void)disposeCueHavingPlayer:(VMPAudioPlayer*)player {
	VMInt c = [cueQueue count];
	for ( int i = 0; i < c; ++i ) {
		VMPQueuedCue *cue = [cueQueue item:i];
		if ( cue->player == player ) {
			[cueQueue deleteItem:i];
			--i;
			--c;
		}
	}
}

- (VMTime)startTimeOfFirstCue {
	VMTime t = INFINITE_TIME;
	for ( VMPQueuedCue *cue in cueQueue ) 
		if ( cue->cueTime < t ) t = cue->cueTime - cue->cuePoints.start;
	
	return t;
}

- (VMTime)endTimeOfLastCue {
	VMTime t = RESET_TIME;
	for ( VMPQueuedCue *cue in cueQueue ) {
		VMTime endTime = cue->cueTime + LengthOfVMTimeRange(cue->cuePoints);
		if ( endTime > t ) t = endTime;
	}
	return t;
}

#pragma mark -
#pragma mark utils and internal funcs

-(VMPAudioPlayer*)seekFreePlayer {
	for ( VMPAudioPlayer *ap in audioPlayerList )
		if ( ! ap.isBusy )
			return ap;
	return nil;
}

-(void) stopAllPlayers {
	for ( VMPAudioPlayer *ap in audioPlayerList )
		[ap stop];
}

- (void)adjustCurrentTimeToQueuedCue {
    VMTime startTimeOfFirstCue = [self startTimeOfFirstCue];
	if ( startTimeOfFirstCue != INFINITE_TIME )
		self.currentTime = startTimeOfFirstCue - secondsPreroll;
}

- (void)resetNextCueTime {
	
	self.nextCueTime = self.currentTime + secondsPreroll;
#ifdef DEBUG
	[self watchNextCueTimeForDebug];
#endif
}


#pragma mark -
#pragma mark accessor
//
//  accessor
//

-(int)numberOfAudioPlayers {
	return kNumberOfAudioPlayers;
}

-(VMPAudioPlayer*)audioPlayer:(int)playeridx {
	return [audioPlayerList item: playeridx];
}

-(void)setGlobalVolume:(VMFloat)volume {
    globalVolume = volume;
	for ( VMPAudioPlayer *ap in audioPlayerList )
		[ap setVolume:[self currentVolume]];
}

- (BOOL)isRunning {
	BOOL running = NO;
	for ( VMPAudioPlayer *ap in audioPlayerList )
		running |= [ap isPlaying];
	
	return running;
}

#pragma mark -
#pragma mark queueing


//
//  prepare audioPlayer
//
-(void)setCueIntoAudioPlayer:(VMPQueuedCue*)cue {
	VMPAudioPlayer *player = [self seekFreePlayer];
	if ( ! player ) {
		NSLog( @"No Free player!" );
		[self performSelector:@selector(setCueIntoAudioPlayer:) withObject:cue afterDelay:1.];
		return;
	}
	[self disposeCueHavingPlayer:player];
	
	// prepare audiofile
	NSString *fileId 	= nil;
	float timeOffset = 0;
	
	if ( cue ) {
		cue->player = player;
		player.cueId		= cue->audioQue.cueId;
		player.offset 		= cue->cuePoints.start;
		player.cueDuration	= cue->cuePoints.end;
		fileId				= cue->audioQue.fileId;
		timeOffset			= self.currentTime - cue->cueTime - cue->cuePoints.start;
	}
	
	[player preloadAudio:[self filePathForFileId:fileId] atTime:timeOffset];
}

- (VMString*)filePathForFileId:(VMString*)fileId {
	NSString *filePath;
	NSString *soundDir = song_.audioFileDirectory;

#if VMP_IPHONE
	filePath = [[NSBundle bundleForClass: [self class]] pathForResource:fileId ofType:typeExt inDirectory:kDefaultVMDirectory];
	
#elif VMP_OSX
	NSString *typeExt  = song_.audioFileExtension;
	filePath = [[NSBundle mainBundle] pathForResource:fileId ofType:typeExt inDirectory:soundDir ];
/*
 do not check files at run-time !
 instead, use 'check missing audio files' in utility menu. 
 
	if ( ! filePath ) {
		[VMException raise:@"Could not open audio file."
					format:@"\"%@.%@\" in directory \"%@\" was not found.", fileId, typeExt, soundDir];
	}
 */
#else
#warning - unsupported platform -
#endif
	return filePath;
}

//
//	fire cues when the time has come
//
- (void)fireCue:(VMPQueuedCue*)queuedCue {	
	VMPAudioPlayer *player = queuedCue->player;
	assert(player);
	
	if ( self.currentTime > queuedCue->cueTime + LengthOfVMTimeRange( queuedCue->cuePoints ) ) {
		//	much too late
		[player stop];
		return;
	}
	
	[queuedCue->audioQue interpreteInstructionsWithData:queuedCue->audioQue action:vmAction_play];
	
	[player setVolume:[self currentVolume]];
	[player play];
	
	if(kUseNotification)
		[VMPNotificationCenter postNotificationName:VMPNotificationAudioCueFired
											 object:self
										   userInfo:@{ @"audioCue":queuedCue->audioQue } ];
//	NSLog(@"fired:%@\n%@",queuedCue->audioQue.id,self.description);	
}

/*---------------------------------------------------------------------------------
 
 fill queue with audio cues
 
 ----------------------------------------------------------------------------------*/

- (BOOL)fillQueueAt:(VMTime)time {
	VMAudioCue *nextAudioCue = [song_ nextAudioCue];
	
	if ( nextAudioCue && (! Pittari( nextAudioCue.fileId, @"*" ))) {
		if ( time < self.currentTime ) time = self.currentTime + secondsPreroll;
		VMPQueuedCue *qc = [self queue:nextAudioCue at:time];
		self.nextCueTime = time + ( qc ? LengthOfVMTimeRange( qc->cuePoints) : 0 );
#ifdef DEBUG
		[self watchNextCueTimeForDebug];
#endif

		if ( kUseNotification )
			[VMPNotificationCenter postNotificationName:VMPNotificationAudioCueQueued
												 object:self
											   userInfo:@{@"audioCue":nextAudioCue} ];

		[self flushFinishedCues];
	}
	
	return ( nextAudioCue != nil );
}


#pragma mark -
#pragma mark *** runloop ***
#pragma mark -
//
//  runloop
//
-(void)timerCall:(NSTimer*)theTimer {
	if ( self.isPaused ) return;
	++frameCounter;
	
	VMTime 			endTimeOfLastCue 	= RESET_TIME;
#if 0 //VMP_DESKTOP
	VMPlayer 		*currentPlayer 		= [song.player retain];
#endif
	//VMPQueuedCue	*newlyFiredCue		= nil;
	VMPQueuedCue	*nextUpcomingCue	= nil;
		
	for ( VMInt i = 0; i < cueQueue.count; ++i ) {
		VMPQueuedCue *cue = [cueQueue item:i];
		VMTime actualCueTime = cue->cueTime - cue->cuePoints.start;
		
		if ( actualCueTime < ( self.currentTime + secondsPreparePlayer ) && ( ! cue->player ) ) {
			//	prepare player		
			[self setCueIntoAudioPlayer:cue];
		}
		
		if ( actualCueTime <= self.currentTime ) {
			//	fire !
			if ( ( cue->player ) && ( ! cue->player.didPlay ) ) {
				[self fireCue:cue];
			//	newlyFiredCue = cue;
			}
		} else {
			if ( ! nextUpcomingCue || cue->cueTime <= nextUpcomingCue->cueTime )
				nextUpcomingCue = cue;
		}
		
		VMTime endTime = actualCueTime + cue->cuePoints.end;
		if ( endTime > endTimeOfLastCue ) {
		//	NSLog(@"endTimeOfLastCue:%@ %f", cue->audioQue.id, endTime );	
			endTimeOfLastCue = endTime;
		}
	}
	
	int numberOfPlayersRunnning = 0;
	if ( endTimeOfLastCue < self.currentTime ) endTimeOfLastCue = self.currentTime + secondsPreroll;

	//	fill cueue
	if ( endTimeOfLastCue < ( [self currentTime] + secondsLookAhead ) ) {
		[self fillQueueAt:endTimeOfLastCue ];
	}
	
	//	manage fade out / count running players.
	float volume = [self currentVolume];
	for ( VMPAudioPlayer *ap in audioPlayerList ) {
		if ( ap.isBusy ) {
	   		if( fadeStartPoint > 0 && fadeDuration > 0 )
				[ap setVolume:volume];	    //  manage fade out

			numberOfPlayersRunnning++;
		}
    }
	
	//	stop if no active player or queue
	if (( numberOfPlayersRunnning == 0 && cueQueue.count == 0 ) || volume == 0 ) {
		[self stop];
	}
	
    //  track view update
	if( trackView_ && ( frameCounter % kDebugViewRedrawInterval ) == 1 ) {
		int i=0;
		for ( VMPAudioPlayer *ap in audioPlayerList )
			[trackView_ redraw:i++ player:ap];
        
        VMPSetNeedsDisplay(trackView_);
	}

#if 0 //VMP_DESKTOP
	//	sequence view update
	if ( newlyFiredCue && nextUpcomingCue ) {
		[sequenceView_ setCurrentPart:currentPlayer
						 currentCueId:newlyFiredCue->audioQue.id
							nextCueId:nextUpcomingCue->audioQue.id 
							  advance:YES];
	}
	[currentPlayer release];
#endif
	
}

- (void)update {
	[self timerCall:nil];
}


#pragma mark -
#pragma mark player control

/*
-(void)cancelNextPart {
    [nextPlayer stop];
}
*/
-(void)start {
	[self startWithCueId:song_.defaultCueId];
}

- (void)startWithCueId:(VMId*)cueId {
//	[self setFadeFrom:0 to:1 length:0.01 setDimmed:NO];
	fadeStartPoint = 0;

	if ( ! self.isWarmedUp ) [self warmUp];
	
	if ( cueId ) {
		[self setCueId:cueId fadeOut:NO restartAfterFadeOut:YES];
		NSLog(@"--- song player set cue id %@ ---\n", cueId );
	} else if ( cueQueue.count == 0 ) {
		//	try to resume from current song
		if ( ! [self fillQueueAt:-9999 ] ) {
			//	failed: set default cue.
			[self setCueId:song_.defaultCueId fadeOut:NO restartAfterFadeOut:NO];
			NSLog(@"--- song player set default cue id ---\n" );
		} else {
			NSLog(@"--- song player restored queues---%@\n---------\n",self.description);
		}
	}
	
	[self flushFiredCues];
	[self resume];
	NSLog(@"SongPlayer resumed");
	[self adjustCurrentTimeToQueuedCue];
}

-(void)stop {
    fadeStartPoint = 0;
	//cueQueue clear];
	[self flushFiredCues];
	[self pause];
    [self stopAllPlayers];
}

-(void)reset {
	[self stopAllPlayers];
	[DEFAULTSONG reset];
	[DEFAULTEVALUATOR reset];
    [self setCueId:song_.defaultCueId fadeOut:NO restartAfterFadeOut:YES];
}

-(void)fadeoutAndStop:(VMTime)duration {
	[self setFadeFrom:-1 to:0. length:duration setDimmed:self.isDimmed];
}


#pragma mark -
#pragma mark cue/part set


- (VMAudioCue *)queueCueId:(VMId*)cueId {
	
	[song_ setCueId:cueId];
	VMAudioCue *nextAudioCue = [song_ nextAudioCue];
	
	if ( nextAudioCue ) {
		VMPQueuedCue *qc = [self queue:nextAudioCue at:self.nextCueTime];
		if (qc) {
			[self setCueIntoAudioPlayer:qc];
			self.nextCueTime += LengthOfVMTimeRange( qc->cuePoints );
#ifdef DEBUG
			[self watchNextCueTimeForDebug];
#endif
		}
		else
		{	//	no cue queued ( maybe an empty file or so.. )
			self.nextCueTime += ( nextAudioCue.modulatedDuration - nextAudioCue.modulatedOffset );
#ifdef DEBUG
			[self watchNextCueTimeForDebug];
#endif
		}
		if ( startPlayAfterSetCue && self.isPaused ) {
			[self setFadeFrom:0. to:1. length:0. setDimmed:NO];
			[self resume];
		}
		startPlayAfterSetCue = NO;
	}
	return nextAudioCue;
}

//
//  stop player and set cueId
//
- (void)stopAndSetCueId:(VMId*)cueId {
	[self stop];
	[self resetNextCueTime];
	[self queueCueId:cueId];// at:self.currentTime + secondsPreroll];
}

//
//	set next cueId while playing.
//
- (void)setNextCueId:(VMId*)cueId {
	[self flushUnfiredCues];
		
	VMTime etolc = [self endTimeOfLastCue];
	if ( etolc != RESET_TIME ) {
		nextCueTime = ( etolc > self.currentTime ? etolc : self.currentTime + secondsPreroll );
#ifdef DEBUG
		[self watchNextCueTimeForDebug];
#endif
	}
	else 
		[self resetNextCueTime];
	
	[self flushFinishedCues];
    
#if 0 //VMP_DESKTOP
	VMAudioCue *nextAudioCue = [self queueCueId:cueId];// at:nextCueTime];
    [sequenceView_ setCurrentPart:nil
					 currentCueId:nil
						nextCueId:nextAudioCue.cueId 
						  advance:NO];
#endif
}



//
//	jump to certain position of song:
//
- (void)setCueId:(VMId*)cueId fadeOut:(BOOL)fadeFlag restartAfterFadeOut:(BOOL)inStartPlayAfterSetCue {
	startPlayAfterSetCue = inStartPlayAfterSetCue;
    if( fadeFlag && ( ! self.isPaused ) ) {        
        [self fadeoutAndStop:secondsAutoFadeOut];
        [self performSelector:@selector(setNextCueId:) withObject:cueId afterDelay:secondsAutoFadeOut+0.5];
    } else {
        [self stopAndSetCueId:cueId];
    }
}

#pragma mark -
#pragma mark launch

//
//  cold start
//
-(void)warmUp {
	if ( self.isWarmedUp ) return;
	
	if( audioPlayerList ) [audioPlayerList release];
	audioPlayerList = NewInstance(VMArray);
	
    for( int i = 0; i < [self numberOfAudioPlayers]; ++i )
		[audioPlayerList push:[[[VMPAudioPlayer alloc] initWithId: i] autorelease]];
    
	[self startTimer:@selector(timerCall:)];
    
	frameCounter = 0;
	self.currentTime = 0;
	self.nextCueTime = 0;
    //
    //  dummy cue to warm up audio engine
    //
	DEFAULTEVALUATOR.testMode = YES;
	VMPQueuedCue *cue = [self queue:[song_ resolveDataWithId:song_.defaultCueId
											 untilReachType:vmObjectType_audioCue]
								 at:0];	
    [self setCueIntoAudioPlayer:cue];
	VMPAudioPlayer *firstAP = [self audioPlayer:0];
	[firstAP setVolume:0.0];
	NSLog(@"warming up...");
    [firstAP play];
    [firstAP stop];
	NSLog(@"warm up done");
	DEFAULTEVALUATOR.testMode = NO;
    
    //
    //
    //
	[self stop];
    engineIsWarm_ = YES;
}


- (void)coolDown {
	[self stopAllPlayers];
	[self stopTimer];
	for( VMPAudioPlayer *ap in audioPlayerList ) [ap stopTimer];
	engineIsWarm_ = NO;
}


#pragma mark -
#pragma mark init and finalize

//
//  init and finalize
//

- (id)init {
    self = [super init];
	if( self ) {
		engineIsWarm_	= NO;
		cueQueue 		= NewInstance(VMArray);
		dimmed_			= NO;
		globalVolume	= 1.;
		fadeStartPoint  = 0;
		fadeStartVolume = 1;
		fadeEndVolume   = 1;
		fadeDuration    = 0;
	}
    return self;
}

- (void)dealloc {
	[audioPlayerList release];
	[cueQueue release];
	self.song = nil;
	[super dealloc];
}

+ (VMPSongPlayer*)defaultPlayer {
	if ( songPlayer_singleton__ == nil ) {
		songPlayer_singleton__ = [[VMPSongPlayer alloc] init];
	}
	return songPlayer_singleton__;
}

//	description
#pragma mark description
- (NSString*)description {
	VMArray *queueDesc = ARInstance(VMArray);
	for( VMPQueuedCue *c in cueQueue ) 
		[queueDesc push:[c description]];
	
	return [NSString stringWithFormat:@"\n\nSP time:%.2f\n -%@\n\n", 
			self.currentTime,
			[queueDesc join:@"\n -"]
			];
}

@end

//
//  SongPlayer.m
//  OnTheFly
//
//  Created by cboy on 10/02/26.
//  Copyright 2010 sumiisan (sumiisan.com). All rights reserved.
//



#import "VMPSongPlayer.h"
#import "VMException.h"
#import "VMPMacros.h"
#import "VMScoreEvaluator.h"
#import "VMPNotification.h"

#if VMP_EDITOR
#import "VMOnTheFlyEditorAppDelegate.h"
#endif

#if VMP_IPHONE
	#import "VMVmsarcManager.h"
#endif


//#include <math.h>

/*---------------------------------------------------------------------------------
 
 VMPPlayTimeAccumulator
 
 ----------------------------------------------------------------------------------*/

#pragma mark -
#pragma mark VMPPlayTimeAccumulator

@implementation VMPPlayTimeAccumulator

@synthesize currentPartId=currentPartId_, playingTimeOfCurrentPart=playingTimeOfCurrentPart_;

- (void)startNewPart:(VMId*)partId {
	self.playingTimeOfCurrentPart = 0;
	self.currentPartId = partId;
}

- (void)addAudioFragment:(VMAudioFragment*)audioFramgent {
	VMId *partId = audioFramgent.partId;
	
	if ( ! [self.currentPartId isEqualToString:partId] )
		[self startNewPart:partId];
	self.playingTimeOfCurrentPart += audioFramgent.duration;
	[self add:audioFramgent.duration ontoItem:partId];
}

- (void)clear { // override	
	[super clear];
	[self startNewPart:nil];
}

- (void)dealloc {
    VMNullify(currentPartId);
	Dealloc( super );
}


@end



#pragma mark -
#pragma mark VMPQueuedFragment

/*---------------------------------------------------------------------------------
 *
 *
 *	Queued Fragment (container obj)
 *
 *
 *---------------------------------------------------------------------------------*/

@implementation VMPQueuedFragment

- (void)dealloc {
	Release( audioFragmentPlayer );		// it's retained since it's a dynamic data for playback.
	Dealloc( super );
}


- (NSString*)description {
	return [NSString stringWithFormat:@"QC<%@> %.2f-%.2f (%@)", 
			audioFragmentPlayer ? audioFragmentPlayer.id : @"no que",
			cueTime - cuePoints.start,
			cueTime - cuePoints.start + cuePoints.end,
			player ? player.description : @"no player"
			];
}
@end

/*---------------------------------------------------------------------------------
 
 VMPAutoFader
 
 ----------------------------------------------------------------------------------*/

#pragma mark -
#pragma mark VMPAutoFader

@implementation VMPAutoFader

- (id)init {
	self = [super init];
	if( self ) {
		fadeStartPoint  = 0;
		fadeStartVolume = 1;
		fadeEndVolume   = 1;
		fadeDuration    = 0;
	}
	return self;
}

- (VMTime)fadeTimeElapsedAt:(VMTime)time {
	return time - fadeStartPoint;
}

- (VMVolume)currentFaderVolume:(VMTime)time {
    float faderVolume = fadeEndVolume;
    if( fadeStartPoint > 0 && fadeDuration > 0 ) {
        NSTimeInterval elapsed = [self fadeTimeElapsedAt:time];
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


- (void)setFadeFrom:(VMFloat)startVolume to:(VMFloat)endVolume length:(VMTime)seconds currentTime:(VMTime)time {
	VMTime fadeTimeRemain = fadeDuration - [self fadeTimeElapsedAt:time];
	
	fadeStartVolume = startVolume >= 0 ? startVolume : [self currentFaderVolume:time];
	fadeEndVolume   = endVolume;
	if( fadeTimeRemain < seconds ) {
		fadeDuration = seconds;
		fadeStartPoint = time;
	}
}

- (BOOL)isActive {
	return fadeStartPoint > 0 && fadeDuration > 0;
}
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
	@synthesize dimmed=dimmed_, mainFader=mainFader_, dimmer=dimmer_;
	@synthesize song=song_;
	@synthesize playTimeAccumulator=playTimeAccumulator_;
	@synthesize simulateIOSAppBackgroundState=simulateIOSAppBackgroundState_;
	@synthesize nextCueTime=nextCueTime_;

	static const VMFloat	secondsPreroll			= 0.3;
	static const VMFloat	secondsPreparePlayer	= 3.;
	static const VMFloat	secondsLookAhead		= secondsPreparePlayer + 0.5;//7.;//	0.5;	changed ss131215
												//	seems to have some bug: if you set this value higher, the player may
												//	schedule multiple frags at once at the same time.	(review ss140101)
	static const VMFloat	secondsAutoFadeOut		= 0.5;
	static VMPSongPlayer 	*songPlayer_singleton_static_ = nil;


- (void)watchNextCueTimeForDebug {
	if ( self.nextCueTime < 0 || self.nextCueTime > 99999 )
		NSLog(@"debug1");
}

#pragma mark -
#pragma mark volume and fade




- (VMVolume)currentVolume {
	VMTime time = self.currentTime;
    return    [self.mainFader currentFaderVolume:time]
			* [self.dimmer currentFaderVolume:time]
			* globalVolume;
}

- (void)setFadeFrom:(VMFloat)startVolume to:(VMFloat)endVolume length:(VMTime)seconds {// setDimmed:(BOOL)dimmerState {
	[self.mainFader setFadeFrom:startVolume to:endVolume length:seconds currentTime:self.currentTime];
}

- (void)setDimmed:(BOOL)dimmed {
	if( dimmed_ == dimmed ) return;	//	no change
	dimmed_ = dimmed;
//	[self setFadeFrom:-1 to:1 length:1. setDimmed:dimmed_];
	[self.dimmer setFadeFrom:-1 to:dimmed_ ? .3 : 1. length:1. currentTime:self.currentTime];
}

#pragma mark -
#pragma mark queue related

- (VMPQueuedFragment*)queue:(VMAudioFragment*)audioFragment at:(VMTime)cueTime {
	if ( ! audioFragment ) {
		[VMException raise:@"Attempted to queue an empty frag." format:@"at %f", cueTime ];
	}
	
	if ( [audioFragment.fileId isEqualToString: @"*"] ) return nil;	//	ignore empty file.
	
	VMPQueuedFragment *c = ARInstance(VMPQueuedFragment);
	c->cueTime 	= cueTime;
	
	VMAudioFragmentPlayer *afp = [[VMAudioFragmentPlayer alloc] initWithProto:audioFragment];
	c->audioFragmentPlayer = afp;	//	retained.
	
	//	copy modulated duration and offset.
	c->cuePoints.start = afp.modulatedOffset;
	c->cuePoints.end   = afp.modulatedDuration;
	
#if VMP_EDITOR
	[CURRENTSONG.log record:[VMArray arrayWithObject:afp] filter:NO];
#endif
	
	[fragQueue push:c];
	return c;
}

- (void)flushFiredFragments {
	VMInt c = [fragQueue count];
	for ( int i = 0; i < c; ++i ) {
		VMPQueuedFragment *frag = [fragQueue item:i];
		if ( frag->player && frag->player.didPlay ) {
			[fragQueue deleteItem:i];
			--i;
			--c;
		}
	}	
}

- (void)flushUnfiredFragments {
	VMInt c = [fragQueue count];
	for ( int i = 0; i < c; ++i ) {
		VMPQueuedFragment *frag = [fragQueue item:i];
		if ( (!frag->player) || ( !frag->player.didPlay) ) {
			[fragQueue deleteItem:i];
			--i;
			--c;
		}
	}	
}


- (void)flushFinishedFragments {
	VMInt c = [fragQueue count];
	for ( int i = 0; i < c; ++i ) {
		VMPQueuedFragment *frag = [fragQueue item:i];
		if ( !frag || ( frag->player && (!frag->player.isBusy) ) ) {
			[fragQueue deleteItem:i];
			--i;
			--c;
		}
	}	
}


- (VMInt)numberOfUnfiredFragments {
	[self flushFinishedFragments];
	return fragQueue.count;
}

- (void)disposeCueHavingPlayer:(VMPlayerType*)player {
	VMInt c = [fragQueue count];
	for ( int i = 0; i < c; ++i ) {
		VMPQueuedFragment *frag = [fragQueue item:i];
		if ( frag->player == player ) {
			[fragQueue deleteItem:i];
			--i;
			--c;
		}
	}
}

- (VMPlayerType*)audioPlayerForFileId:(VMId*)fileId {
	for ( VMPQueuedFragment *frag in fragQueue )
		if ( [frag->audioFragmentPlayer.fileId isEqualToString:fileId] ) return frag->player;
	return nil;
}

- (VMTime)startTimeOfFirstFragment {
	VMTime t = INFINITE_TIME;
	for ( VMPQueuedFragment *frag in fragQueue ) 
		if ( frag->cueTime < t ) t = frag->cueTime - frag->cuePoints.start;
	
	return t;
}

- (VMTime)endTimeOfLastFragment {
	VMTime t = 0;
	for ( VMPQueuedFragment *frag in fragQueue ) {
		VMTime endTime = frag->cueTime + LengthOfVMTimeRange(frag->cuePoints);
		if ( endTime > t ) t = endTime;
	}
	return t;
}

#pragma mark -
#pragma mark utils and internal funcs

-(VMPlayerType*)seekFreePlayer {
	for ( VMPlayerType *ap in audioPlayerList )
		if ( ! ap.isBusy )
			return ap;
	return nil;
}

-(void) stopAllPlayers {
	for ( VMPlayerType *ap in audioPlayerList )
		[ap stop];
}

- (void)adjustCurrentTimeToQueuedFragment {
    VMTime startTimeOfFirstFragment = [self startTimeOfFirstFragment];
	if ( startTimeOfFirstFragment != INFINITE_TIME )
		self.currentTime = startTimeOfFirstFragment - secondsPreroll;
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

-(VMPlayerType*)audioPlayer:(int)playeridx {
	return [audioPlayerList item: playeridx];
}

-(void)setGlobalVolume:(VMFloat)volume {
    globalVolume = volume;
	for ( VMPlayerType *ap in audioPlayerList )
		[ap setVolume:[self currentVolume]];
}

- (BOOL)isRunning {
	BOOL running = NO;
	for ( VMPlayerType *ap in audioPlayerList )
		running |= [ap isPlaying];
	return running;
}

- (VMAudioFragment*)lastFiredFragment {
	return lastFiredFragment_;
}

#pragma mark -
#pragma mark queueing


//
//  prepare audioPlayer
//
-(void)setFragmentIntoAudioPlayer:(VMPQueuedFragment*)frag {
	VMPlayerType *player = [self seekFreePlayer];
	if ( ! player ) {
		NSLog( @"No Free player! at %.2f", self.currentTime );
		[self performSelector:@selector(setFragmentIntoAudioPlayer:) withObject:frag afterDelay:1.];
		return;
	}
	[self disposeCueHavingPlayer:player];
	
	// prepare audiofile
	NSString *fileId 	= nil;
	float timeOffset = 0;
	
	if ( frag ) {
		frag->player = player;
		player.fragId		= frag->audioFragmentPlayer.fragId;
		player.offset 		= frag->cuePoints.start;
		player.fragDuration	= frag->cuePoints.end;
		fileId				= frag->audioFragmentPlayer.fileId;
		timeOffset			= self.currentTime - frag->cueTime - frag->cuePoints.start;
	}
	
	[player preloadAudio:[self filePathForFileId:fileId] atTime:timeOffset];
}

- (VMString*)filePathForFileId:(VMString*)fileId {
	/*
	 we do not throw any exceptions for missing files at runtime !
	 use 'check missing audio files' in OnTheFly Editor's utility menu to prevent error.
	 */
	
	NSString *filePath;

#if VMP_IPHONE
	NSString *dataDirectory = [[VMVmsarcManager defaultManager] dataDirectory];
	
	filePath = [[[dataDirectory stringByAppendingPathComponent:song_.audioFileDirectory]
				 stringByAppendingPathComponent:fileId]
				stringByAppendingPathExtension:song_.audioFileExtension];
/*
	filePath = [[NSBundle bundleForClass: [self class]]
				pathForResource:fileId
				ofType:song_.audioFileExtension
				inDirectory:[dataDirectory stringByAppendingPathComponent:song_.audioFileDirectory]];
*/
#elif VMP_OSX
	//filePath = [[NSBundle mainBundle] pathForResource:fileId ofType:song_.audioFileExtension inDirectory:kDefaultVMDirectory];
	//
	filePath = [[[[[song_.fileURL 
					path] stringByDeletingLastPathComponent]
				  stringByAppendingPathComponent:song_.audioFileDirectory]
				 stringByAppendingPathComponent:fileId]
				stringByAppendingPathExtension:song_.audioFileExtension];

#endif
	return filePath;
}

//
//	fire frags when the time has come
//
- (void)fireCue:(VMPQueuedFragment*)queuedFragment {	
	VMPlayerType *player = queuedFragment->player;
	assert(player);
	
	if ( self.currentTime > queuedFragment->cueTime + LengthOfVMTimeRange( queuedFragment->cuePoints ) ) {
		//	much too late
		[player stop];
		return;
	}
	
	VMAudioFragmentPlayer *af = queuedFragment->audioFragmentPlayer;
	[af interpreteInstructionsWithAction:vmAction_play];
	
	[player setVolume:[self currentVolume]];
	[player play];
	
	[CURRENTSONG.songStatistics addAudioFrag:af];			//	runtime statistics.
	LLog(@"(%.2f):%@ (%.2f)",self.currentTime, af.id, af.duration);
	
	af.firedTimestamp = [NSDate timeIntervalSinceReferenceDate];
	[self.playTimeAccumulator addAudioFragment:af];
	
	Release( lastFiredFragment_ );
	lastFiredFragment_ = Retain( af );
	if( kUseNotification )
		[self performSelector:@selector(sendAudioFragmentFiredNotification:)
				   withObject:queuedFragment afterDelay:0.];

}

- (void)sendAudioFragmentFiredNotification:(VMPQueuedFragment*)queuedFragment {
	[VMPNotificationCenter postNotificationName:VMPNotificationAudioFragmentFired
										 object:self
									   userInfo:@{
	 @"audioFragment":queuedFragment->audioFragmentPlayer,
	 @"player":NSNullIfNil( queuedFragment->player ) } ];

}

/*---------------------------------------------------------------------------------
 
 fill queue with audio frags
 
 ----------------------------------------------------------------------------------*/

- (BOOL)fillQueueAt:(VMTime)time {
	VMAudioFragment *nextAudioFragment = [song_ nextAudioFragment];
	
	if ( nextAudioFragment && (! [nextAudioFragment.fileId isEqualToString: @"*"] )) {
	//	NSLog(@"Queue Audio Frag : %@ %p", nextAudioFragment.id, nextAudioFragment );
		
		if ( time < self.currentTime ) time = self.currentTime + secondsPreroll;
		VMPQueuedFragment *qc = [self queue:nextAudioFragment at:time];
		self.nextCueTime = time + ( qc ? LengthOfVMTimeRange( qc->cuePoints) : 0 );
#ifdef DEBUG
		[self watchNextCueTimeForDebug];
#endif

		if ( kUseNotification )
			[VMPNotificationCenter postNotificationName:VMPNotificationAudioFragmentQueued
												 object:self
											   userInfo:@{@"audioFragment":nextAudioFragment} ];

		[self flushFinishedFragments];
	}
	
	return ( nextAudioFragment != nil );
}


#pragma mark -
#pragma mark *** runloop ***
#pragma mark -
//
//  runloop
//
-(void)timerCall:(NSTimer*)theTimer {	//	TODO: replace NSTimer with GCD.
	if ( self.isPaused ) return;
	++frameCounter;
	
	VMTime				endTimeOfLastFragment 	= 0;
	VMPQueuedFragment	*nextUpcomingFragment	= nil;
		
	for ( VMInt i = 0; i < fragQueue.count; ++i ) {
		VMPQueuedFragment *frag = [fragQueue item:i];
		VMTime actualCueTime = frag->cueTime - frag->cuePoints.start;
		
		if ( actualCueTime < ( self.currentTime + secondsPreparePlayer ) && ( ! frag->player ) ) {
			//	prepare player		
			[self setFragmentIntoAudioPlayer:frag];
		}
		
		if ( actualCueTime <= self.currentTime ) {
			//	fire !
			if ( ( frag->player ) && ( ! frag->player.didPlay ) ) {
				[self fireCue:frag];
			//	newlyFiredFragment = frag;
			}
		} else {
			if ( ! nextUpcomingFragment || frag->cueTime <= nextUpcomingFragment->cueTime )
				nextUpcomingFragment = frag;
		}
		
		VMTime endTime = actualCueTime + frag->cuePoints.end;
		if ( endTime > endTimeOfLastFragment ) {
			endTimeOfLastFragment = endTime;
		}
	}
	
	int numberOfPlayersRunnning = 0;
	if ( endTimeOfLastFragment < self.currentTime )
		endTimeOfLastFragment = self.currentTime + secondsPreroll;

	//	fill cueue
	if ( endTimeOfLastFragment < ( [self currentTime] + secondsLookAhead ) ) {
		[self fillQueueAt:endTimeOfLastFragment ];
	}
	
	//	manage fade out / count running players.
	float volume = [self currentVolume];
	BOOL faderActive = mainFader_.isActive || dimmer_.isActive;
	VMTime remainTime = 0;
	
	for ( VMPlayerType *ap in audioPlayerList ) {
		if ( ap.isBusy ) {
			if( faderActive )
				[ap setVolume:volume];	    //  manage fade out
			
			numberOfPlayersRunnning++;
			remainTime = ap.fileDuration - ap.currentTime;
		}
	}
	
	BOOL fadeOutFinished = volume == 0 && mainFader_->fadeEndVolume == 0;
	BOOL timerExecuted = DEFAULTEVALUATOR.timeManager.timerExecuted;
	
#if VMP_IPHONE
	
	//
	//	if the mobile app is background mode, and the last audioPlayer is going to stop,
	//	we must play an emergency audioFile to prevent the app terminatated by the system.
	//
	if ( numberOfPlayersRunnning <= 1 && remainTime < 0.5 ) {
		UIApplicationState appState = [[UIApplication sharedApplication] applicationState];
		if (( appState == UIApplicationStateBackground || appState == UIApplicationStateInactive )
			&& (!fadeOutFinished) && (!timerExecuted) ) {
			LLog(@"OOPS ! app gonna quit !");
			[self emergencyFire];
		}
	}
	if ( fadeOutFinished ) [self stop];
#else
	
	if ( self.simulateIOSAppBackgroundState ) {
		
		if ((( numberOfPlayersRunnning == 1 && remainTime < 0.5 ) || ( numberOfPlayersRunnning == 0 ) )
			&& (!fadeOutFinished) && (!timerExecuted) ) {
			LLog(@"OOPS ! app gonna quit !");
			[self emergencyFire];
		}
		
	} else if (( numberOfPlayersRunnning == 0 && fragQueue.count == 0 ) || fadeOutFinished ) {
		//	stop if no active player or queue
		[self stop];
	}
#endif
	
	//  track view update
	if( trackView_ && ( frameCounter % kTrackViewRedrawInterval ) == 1 ) {
		int i=0;
		for ( VMPlayerType *ap in audioPlayerList )
			[trackView_ redraw:i++ player:ap];
		
		VMPSetNeedsDisplay(trackView_);
	}
}

- (void)setLimiterState:(BOOL)state {
    // not implemented
}

- (VMPView*)limiterIndicator {
	return nil;
}

- (void)emergencyFire {
	VMAudioFragment *ambient = [CURRENTSONG data:@"ambient"];
	VMPQueuedFragment *q = [self queue:ambient at:self.currentTime+0.2];
	if (q) {
		[self setFragmentIntoAudioPlayer:q];
		[self fireCue:q];
	}
}

- (void)update {
	[self timerCall:nil];
}


#pragma mark -
#pragma mark player control

-(void)start {
	[self startWithFragmentId:song_.defaultFragmentId];
}

- (void)startWithFragmentId:(VMId*)fragId {
//	[self setFadeFrom:0 to:1 length:0.01 setDimmed:NO];
	self.mainFader->fadeStartPoint = 0;
	
	if ( ! self.isWarmedUp ) [self warmUp];
	
	if ( fragId ) {
		[self setFragmentId:fragId fadeOut:NO restartAfterFadeOut:YES];
		NSLog(@"--- song player set frag id %@ ---\n", fragId );
	} else if ( fragQueue.count == 0 ) {
		//	try to resume from current song
		if ( ! [self fillQueueAt:-9999 ] ) {
			//	failed: set default frag.
			[self setFragmentId:song_.defaultFragmentId fadeOut:NO restartAfterFadeOut:NO];
			NSLog(@"--- song player set default frag id = %@ ---\n", song_.defaultFragmentId );
		} else {
			NSLog(@"--- song player restored queues---%@\n---------\n", self.description);
		}
	}
	
	[self flushFiredFragments];
	[self resume];
	NSLog(@"SongPlayer resumed");
	[self adjustCurrentTimeToQueuedFragment];
	[DEFAULTEVALUATOR.timeManager resetTimer];
}

-(void)stop {
    self.mainFader->fadeStartPoint = 0;
	self.dimmer->fadeStartPoint = 0;

	[self flushFiredFragments];
	[self pause];
    [self stopAllPlayers];
}

- (void)stopAndDisposeQueue {
	[self stop];
	if( fragQueue.count > 0 ) {
		[fragQueue clear];
		NSLog(@"empty audio queue.");
	}
}

-(void)reset {
	[self stopAndDisposeQueue];
	[self.playTimeAccumulator clear];
    [self setFragmentId:song_.defaultFragmentId fadeOut:NO restartAfterFadeOut:YES];
}

-(void)fadeoutAndStop:(VMTime)duration {
	//[self setFadeFrom:-1 to:0. length:duration setDimmed:self.isDimmed];
	[self.mainFader setFadeFrom:-1 to:0 length:duration currentTime:self.currentTime];
}


#pragma mark -
#pragma mark frag/part set


- (VMAudioFragment *)queueFragmentId:(VMId*)fragId {
	
	[song_ setFragmentId:fragId];
	VMAudioFragment *nextAudioFragment = [song_ nextAudioFragment];
	
	if ( nextAudioFragment ) {
		VMPQueuedFragment *qc = [self queue:nextAudioFragment at:self.nextCueTime];
		if (qc) {
			[self setFragmentIntoAudioPlayer:qc];
			self.nextCueTime += LengthOfVMTimeRange( qc->cuePoints );
#ifdef DEBUG
			[self watchNextCueTimeForDebug];
#endif
		}
		else
		{	//	no frag queued ( maybe an empty file or so.. )
			self.nextCueTime += ( nextAudioFragment.modulatedDuration - nextAudioFragment.modulatedOffset );
#ifdef DEBUG
			[self watchNextCueTimeForDebug];
#endif
		}
		if ( startPlayAfterSetFragment && self.isPaused ) {
			[self setFadeFrom:0. to:1. length:0.];
			[self resume];
		}
		startPlayAfterSetFragment = NO;
	}
	return nextAudioFragment;
}

//
//  stop player and set fragId
//
- (void)stopAndSetFragmentId:(VMId*)fragId {
	[self stop];
	[self resetNextCueTime];
	[self queueFragmentId:fragId];// at:self.currentTime + secondsPreroll];
}

//
//	set next fragment's id while playing.
//
- (void)setNextFragmentId:(VMId*)fragId {
	[self flushUnfiredFragments];
		
	VMTime etolc = [self endTimeOfLastFragment];
	if ( etolc != 0 ) {
		self.nextCueTime = ( etolc > self.currentTime ? etolc : self.currentTime + secondsPreroll );
#ifdef DEBUG
		[self watchNextCueTimeForDebug];
#endif
	}
	else 
		[self resetNextCueTime];
	
	[self flushFinishedFragments];
}



//
//	jump to certain position of song:
//
- (void)setFragmentId:(VMId*)fragId fadeOut:(BOOL)fadeFlag restartAfterFadeOut:(BOOL)inStartPlayAfterSetFragment {
	startPlayAfterSetFragment = inStartPlayAfterSetFragment;
    if( fadeFlag && ( ! self.isPaused ) ) {
        [self fadeoutAndStop:secondsAutoFadeOut];
        [self performSelector:@selector(setNextFragmentId:) withObject:fragId afterDelay:secondsAutoFadeOut+0.5];
    } else {
        [self stopAndSetFragmentId:fragId];
    }
}

#pragma mark -
#pragma mark launch

//
//  cold start
//
-(void)warmUp {
	if ( self.isWarmedUp ) return;
	DEFAULTEVALUATOR.testMode = YES;
	VMAudioFragment *af = [song_ resolveDataWithId:song_.defaultFragmentId
									untilReachType:vmObjectType_audioFragment];
	if ( ! af ) {
		DEFAULTEVALUATOR.testMode = NO;
		return;
	}
	
	VMPQueuedFragment *frag = [self queue:af at:0];
	
	if( audioPlayerList ) Release(audioPlayerList);
	audioPlayerList = NewInstance(VMArray);
	
    for( int i = 0; i < [self numberOfAudioPlayers]; ++i )
		[audioPlayerList push:AutoRelease([[VMPlayerType alloc] initWithId: i] )];
	
	[self startTimer:@selector(timerCall:)];
    
	frameCounter = 0;
	self.currentTime = 0;
	self.nextCueTime = 0;
    //
    //  dummy cue to warm up audio engine
    //
    [self setFragmentIntoAudioPlayer:frag];
	VMPlayerType *firstAP = [self audioPlayer:0];
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
#if ! VMP_IPHONE
	for( VMPlayerType *ap in audioPlayerList ) [ap stopTimer];
#endif
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
		self.playTimeAccumulator = ARInstance(VMPPlayTimeAccumulator);
		engineIsWarm_	= NO;
		fragQueue 		= NewInstance(VMArray);
		dimmed_			= NO;
		globalVolume	= 1.;
		self.mainFader	= ARInstance(VMPAutoFader);
		self.dimmer		= ARInstance(VMPAutoFader);
	}
    return self;
}

- (void)dealloc {
	VMNullify(playTimeAccumulator);
#if ! VMP_IPHONE
	Release(audioPlayerList);
#endif
	Release(fragQueue);
	Release(lastFiredFragment_);
	VMNullify(mainFader);
	VMNullify(dimmer);
	VMNullify(song);
	Dealloc(super);
}

+ (VMPSongPlayer*)defaultPlayer {
	if ( songPlayer_singleton_static_ == nil ) {
		songPlayer_singleton_static_ = [[VMPSongPlayer alloc] init];
	}
	return songPlayer_singleton_static_;
}

//	description
#pragma mark description
- (NSString*)description {
	VMArray *queueDesc = ARInstance(VMArray);
	for( VMPQueuedFragment *c in fragQueue ) 
		[queueDesc push:[c description]];
	
	return [NSString stringWithFormat:@"\n\nSP time:%.2f\n -%@\n\n", 
			self.currentTime,
			[queueDesc join:@"\n -"]
			];
}

@end

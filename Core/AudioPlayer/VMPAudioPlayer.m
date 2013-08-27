//
//  AudioPlayer.m
//  OnTheFly
//
//  Created by cboy on 10/02/25.
//  Copyright 2010 sumiisan (aframasda.com). All rights reserved.
//

#import "VMPAudioPlayer.h"
#include "MultiPlatform.h"
#import "VMException.h"
#import "VMPrimitives.h"
#import "VMPMacros.h"

@interface VMPAudioPlayer (InternalMethods)
static void BufferCallback(void *inUserData, AudioQueueRef inAQ, AudioQueueBufferRef inBuffer);
@end

@implementation VMPAudioPlayer
@synthesize fragId;
@synthesize playerId;
@synthesize fragDuration, fileDuration, offset;

#if enableDSP
@synthesize audioObject = audioObject_;
#endif

static VMHash *processPhaseNames_static_ = nil;

#pragma mark -
#pragma mark accessor

-(Float32)loadedRatio {
#if enableDSP
	if( audioObject_ ) {
//		LLog(@"framesLoaded:%.2f",(double)audioObject_.framesLoaded / (double)audioObject_.numberOfFrames);
		
		return (double)audioObject_.framesLoaded / (double)audioObject_.numberOfFrames;
	}
	else
		return 0;
#else
	return packetIndex / (Float32) numTotalPackets;
#endif
}

- (void)setVolume:(Float32)volume {
	AudioQueueSetParameter(queue, kAudioQueueParam_Volume, volume);
}

- (BOOL)isBusy {
	return ( processPhase != pp_idle );
}

- (BOOL)isPlaying {
	return ( processPhase == pp_play );
}

- (BOOL)didPlay {
	return ( processPhase == pp_play || processPhase == pp_idle );
}

#pragma mark -
#pragma mark init and finalize

#define processPhaseEntry(phase) @"" #phase, VMIntObj( pp_##phase ),

- (void)initInternal {
    processPhase = pp_idle;
	if (! processPhaseNames_static_) {
		processPhaseNames_static_ = Retain([VMHash hashWithObjectsAndKeys:
								processPhaseEntry( idle )
								processPhaseEntry( warmUp )
								processPhaseEntry( fileOpened )
								processPhaseEntry( preLoad )
								processPhaseEntry( waitCue )
								processPhaseEntry( play )
								processPhaseEntry( locked )
								nil] );
	}
	[self startTimer:@selector(timerCall:)];	
    shiftTime = 0;
}

- (id)init {
    self = [super init];
	[self initInternal];
    return self;
}

- (id)initWithId:(int)identifier {
    self = [super init];
    playerId = identifier;
	[self initInternal];
    
    return self;
}

- (void)close {
	// it is preferrable to call close first, before dealloc if there is a problem waiting for
	// an autorelease
	if (trackClosed)
		return;
	trackClosed = YES;
	AudioQueueStop(queue, YES);
	AudioQueueDispose(queue, YES);

#if enableDSP
	[self.audioObject close];
#else
	AudioFileClose(audioFile);
	audioFile = nil;
#endif
	processPhase = pp_idle;
}

- (void)dealloc {
	Release(timer);
#if enableDSP
	VMNullify(audioObject);
#endif
	timer = nil;
	if ( filePathToRead ) Release(filePathToRead);
	[self close];
	if( packetDescs )   free( packetDescs );
    if( channelLayout ) free( channelLayout );
	Dealloc( super );
}

- (void) reallocBuffer {
#if enableDSP
	numPacketsToRead = kAudioPlayer_BufferSize / audioObject_->cachedAudioFormat.mBytesPerPacket;
#else
	UInt32	size;
	UInt32	maxPacketSize;
	
	if( packetDescs ) free( packetDescs );
	// calculate number of packets to read and allocate space for packet descriptions if needed
	if (dataFormat.mBytesPerPacket == 0 || dataFormat.mFramesPerPacket == 0) {
		// since we didn't get sizes to work with, then this must be VBR data (Variable BitRate), so
		// we'll have to ask Core Audio to give us a conservative estimate of the largest packet we are
		// likely to read with kAudioFilePropertyPacketSizeUpperBound
		size = sizeof(maxPacketSize);
		AudioFileGetProperty(audioFile, kAudioFilePropertyPacketSizeUpperBound, &size, &maxPacketSize);
		if (maxPacketSize > kAudioPlayer_BufferSize) {
			// hmm... well, we don't want to go over our buffer size, so we'll have to limit it I guess
			NSLog(@"apAudioPlayer Warning - maxPacketSize was limited.%u -> %u",
				  (unsigned int)maxPacketSize,
				  kAudioPlayer_BufferSize );
			maxPacketSize = kAudioPlayer_BufferSize;
		}
		numPacketsToRead = kAudioPlayer_BufferSize / maxPacketSize;
	//	NSLog( @"*%i VBR %u", playerId, (unsigned int)numPacketsToRead );
		
		// will need a packet description for each packet since this is VBR data, so allocate space accordingly
		packetDescs = (AudioStreamPacketDescription*)
                    malloc(sizeof(AudioStreamPacketDescription) * numPacketsToRead);
	} else {
		// for CBR data (Constant BitRate), we can simply fill each buffer with as many packets as will fit
		numPacketsToRead = kAudioPlayer_BufferSize / dataFormat.mBytesPerPacket;
	//	NSLog( @"*%i CBR %u", playerId, (unsigned int)numPacketsToRead );
		
		// don't need packet descriptsions for CBR data
		packetDescs = nil;
	}
	
    //  set ACL into queue data
    if ( channelLayout ) {
        AudioQueueSetProperty(queue, kAudioQueueProperty_ChannelLayout, channelLayout, channelLayoutSize );
    }
#endif
    
	// allocate buffers
	for ( int i = 0; i < kNumberOfQueueBuffers; ++i ) {
		OSStatus status = AudioQueueAllocateBuffer( queue, kAudioPlayer_BufferSize, &buffers[i] );
		if (status)
			LLog(@"AudioQueueAllocateBuffer returned status %ld", status);
        buffers[i]->mUserData = (void*)i;   //  set the index of buffer
	}
}

- (void) createNewQueue {		
	// create a new playback queue using the specified data format and buffer callback
	OSStatus status = AudioQueueNewOutput(
#if enableDSP
						&(audioObject_->cachedAudioFormat),
#else
                        &dataFormat,
#endif
                        BufferCallback,
                        (VMBridge void *)(self),
                        CFRunLoopGetCurrent(), 
                        kCFRunLoopCommonModes, 
                        0, 
                        &queue);
    assert( queue != nil );
	if( status ) LLog(@"AudioQueueNewOutput returned status %ld",status);
	
	[self reallocBuffer];
	

#if VMP_IPHONE
	//	decoder policy
	UInt32 hardwarePolicy = ( playerId == 0 )
							? kAudioQueueHardwareCodecPolicy_PreferHardware
							: kAudioQueueHardwareCodecPolicy_PreferSoftware;	//	only player #0 can use hardwre decoder
																				//	since we have only one on board.
	status= AudioQueueSetProperty( queue, kAudioQueueProperty_HardwareCodecPolicy, &hardwarePolicy, sizeof(hardwarePolicy));
	
	//
	//	NOTE:	setting all players to kAudioQueueHardwareCodecPolicy_PreferHardware worked for my iPhone 4S with iOS6.1.3
	//			but not for my iPad (1st gen) with iOS5.1.1. didn't switch to software decoder when OSStatus = 'hwiu' (hardware in use)
	//
	
	
	if(status)LLog(@"HardwareCodecPolicy set returned status:%ld",status);
#endif
	
}

#pragma mark -
#pragma mark audio file

- (void)openAudio:(NSString *)path {
	OSStatus	status;
	NSURL		*url;

	if (path == nil)
        return;

#if enableDSP
	if ( self.audioObject ) {
		VMNullify(audioObject);
		self.audioObject = ARInstance(VMAudioObject);
	}
	status = [self.audioObject open:path];
	url = self.audioObject.url;
#else
	if( audioFile ) {
		AudioFileClose( audioFile );
		audioFile = nil;
	}
	url =		[NSURL URLWithString:[path stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];	//	escape
	status =	AudioFileOpenURL( (VMBridge CFURLRef)url, 0x01, 0, &audioFile );
#endif
	
	// try to open up the file using the specified path
	
	if ( status ) {
		[VMException alert:@"Failed to open audio file." format:@"Audio file at path %@ status=%d", url, status];
#if ! enableDSP
		audioFile = nil;
#endif
		return;
	}

#if enableDSP
	fileDuration = audioObject_.fileDuration;
#else
	// get the data format of the file
	UInt32 size = sizeof(dataFormat);
	AudioFileGetProperty( audioFile, kAudioFilePropertyDataFormat, &size, &dataFormat );

	// get the length of the file
	size = sizeof( fileDuration );
	AudioFileGetProperty( audioFile, kAudioFilePropertyEstimatedDuration, &size, &fileDuration );
	//waveformSampleInterval = ( fileDuration * dataFormat.mSampleRate ) / kWaveFormCacheFrames;
#endif
	if ( fragDuration == 0 ) fragDuration = fileDuration;
}

- (void)preloadAudio:(NSString *)path atTime:(float)inTime {
    assert( path != nil );
#if ! enableDSP
	if( queue && audioFile ) [self close];
#endif
	processPhase = pp_warmUp;
	Release(filePathToRead);
	filePathToRead = Retain([NSString stringWithString:path]);
	packetIndex = 0;
	trackClosed = NO;
	self.currentTime = inTime;
}

-(void)openAudioAndReadInfo {
    
    processPhase = pp_locked;
	if ( ! filePathToRead ) {
		[self stop];
		return;
	}
	
	
#if enableDSP
	
	if ( self.audioObject ) {
		VMNullify(audioObject);
	}
	self.audioObject = ARInstance(VMAudioObject);
	OSStatus status = [audioObject_ open:filePathToRead];

	int totalBytes = audioObject_.numberOfFrames * audioObject_.bytesPerFrame;
	numTotalPackets = totalBytes / audioObject_->cachedAudioFormat.mBytesPerPacket;

	if (numTotalPackets == 0) {
		processPhase = pp_idle;
		return;	//	failed
	}
	// try to open up the file using the specified path
	
	if ( noErr != status ) {
		[VMException alert:@"Failed to open audio file." format:@"Audio file at path %@ status=%d", audioObject_.url, status];
		return;
	}
	fileDuration = audioObject_.fileDuration;
	if ( fragDuration == 0 ) fragDuration = fileDuration;
	
#else
	char		*cookie;
	UInt32		size;
	[self openAudio:filePathToRead];
    
    //  read packet count
    size = sizeof(numTotalPackets);
    AudioFileGetProperty(audioFile, kAudioFilePropertyAudioDataPacketCount, &size, &numTotalPackets );
	
	if (size == 0) {
		processPhase = pp_idle;
		return;	//	failed
	}
    
	// see if file uses a magic cookie (a magic cookie is meta data which some formats use)
	AudioFileGetPropertyInfo( audioFile, kAudioFilePropertyMagicCookieData, &size, nil );	
	if (size > 0) {
		// copy the cookie data from the file into the audio queue
		cookie = (char*)malloc(sizeof(char) * size);
		AudioFileGetProperty(audioFile, kAudioFilePropertyMagicCookieData, &size, cookie );
		AudioQueueSetProperty(queue, kAudioQueueProperty_MagicCookie, cookie, size );
		free( cookie );
	}
    
    // see if there is a channel layout (multichannel file) not sure whether we need this ss121021
    channelLayoutSize = sizeof( AudioChannelLayout );
    AudioFileGetPropertyInfo( audioFile, kAudioFilePropertyChannelLayout, &channelLayoutSize, NULL);
    if ( channelLayout ) free( channelLayout );
    channelLayout = nil;
    if ( channelLayoutSize > 0 ) {
        channelLayout = (AudioChannelLayout *)malloc( channelLayoutSize );
        AudioFileGetProperty(audioFile, kAudioFilePropertyChannelLayout, &channelLayoutSize, channelLayout);
    }
#endif

	[self createNewQueue];
    processPhase = pp_fileOpened;
}

#pragma mark buffering

//static int logDone = 0;

- (UInt32)readPacketsIntoBuffer:(AudioQueueBufferRef)inBuffer queue:(AudioQueueRef)inAQ {
	
	// read packets into buffer from file
	UInt32 packetsToRead = numPacketsToRead;

#if enableDSP
	UInt32 playedFrames = packetIndex * audioObject_->cachedAudioFormat.mFramesPerPacket;
	UInt32 framesToPlay = audioObject_.numberOfFrames - playedFrames;
	
	if( playedFrames < audioObject_.numberOfFrames ) {
		size_t copyBytes = MIN(framesToPlay * audioObject_->cachedAudioFormat.mBytesPerFrame,
							   inBuffer->mAudioDataBytesCapacity );
		if ( playedFrames > audioObject_.framesLoaded ) {
			LLog(@"attempted to play unloaded frames %ld / %ld", playedFrames, audioObject_.framesLoaded);
		}
		
		const char *source = [audioObject_ dataAtFrame:playedFrames];
		if( source ) {
			memcpy((char*)inBuffer->mAudioData, source, copyBytes );
			inBuffer->mAudioDataByteSize = copyBytes;
		
			AudioQueueEnqueueBuffer(queue, inBuffer, 0, nil );
			packetIndex += copyBytes / audioObject_->cachedAudioFormat.mBytesPerPacket;
		}
	}
	
#else
	UInt32 bytesRead;
	
	AudioFileReadPackets
	(
	 audioFile, 
	 NO,
	 &bytesRead,
	 packetDescs, 
	 packetIndex, 
	 &packetsToRead,
	 inBuffer->mAudioData );

    if (packetsToRead > 0)	{
        // - End Of File has not been reached yet since we read some packets, so enqueue the buffer we just read into
        // the audio queue, to be played next
        // - (packetDescs ? numPackets : 0) means that if there are packet descriptions (which are used only for Variable
        // BitRate data (VBR)) we'll have to send one for each packet, otherwise zero
        inBuffer->mAudioDataByteSize = bytesRead;
        AudioQueueEnqueueBuffer(queue, inBuffer, (packetDescs ? packetsToRead : 0), packetDescs);
        
        // move ahead to be ready for next time we need to read from the file
        packetIndex += packetsToRead;
    }
#endif
	return packetsToRead;
}

#if enableDSP
- (void)beginLoadFile {
	[audioObject_ beginLoad:nil];
	skipCounter = 0;
}
#endif

- (void)enqueueBuffers {
    processPhase = pp_locked;
    
	for ( int i = 0; i < kNumberOfQueueBuffers; ++i )
        if( [self readPacketsIntoBuffer: buffers[i] queue:queue ] == 0 ) break;
	
    processPhase = pp_preLoad;
}

-(void)primeBuffers {
    processPhase = pp_locked;
    
	UInt32 preparedFrames;
    UInt32 primeFrames = 0x200;
	OSStatus status = AudioQueuePrime( queue, primeFrames, &preparedFrames );
#if TARGET_OS_IPHONE
	/*
	 
	 switching hardware codec policy after calling AudioQueuePrime() seems not to work.
	 
	if( status == 'hwiu' ) {
		//	seems like hardware audio decoder is in use. let's try software decoder instead.
		UInt32 hardwarePolicy = kAudioQueueHardwareCodecPolicy_UseSoftwareOnly;
		status = AudioQueueSetProperty( queue, kAudioQueueProperty_HardwareCodecPolicy, &hardwarePolicy, sizeof(hardwarePolicy));
			
		AudioQueueGetProperty(queue, kAudioQueueProperty_HardwareCodecPolicy, &hardwarePolicy, nil);
		LLog(@"hardware is in use: switch to software decoder. status= %ld set result: %ld", status, hardwarePolicy);
		
		
		if ( !status ) status = AudioQueuePrime( queue, primeFrames, &preparedFrames );
	}	*/
#endif
	if( status ) {
		LLog(@"AudioQueuePrime %@ OSStatus:%ld", fragId, (long)status);
	} /*else {
		LLog(@"AudioQueuePrime %@ prepared:%ld", fragId, (long)preparedFrames);
	}*/
	if ( preparedFrames > 0 )
		processPhase = pp_prime;
	else {
		shiftTime += 0.05;
		processPhase = pp_preLoad;	//	try again
	}
}

#pragma mark -
#pragma mark timer handler

-(void)timerCall:(NSTimer*)theTimer {
	
#if enableDSP
	if (audioObject_ && audioObject_.framesLeft > 0 ) {
		skipCounter = (++skipCounter) % 3;
		if ( skipCounter == 1 ) [audioObject_ continueLoad];
	}
#endif
	
    switch ( processPhase ) {
        case pp_locked:         //  currently processing something.
        case pp_idle:           //  nothing to do. ( playback has ended )
            return;
            break;
            
        case pp_warmUp:
            if( self.currentTime > 1 )              [self stop];        //  too late.
            if( self.currentTime > -2.5+shiftTime ) {
				[self openAudioAndReadInfo];
#if enableDSP
				[self beginLoadFile];
#endif
			}
            break;
            
        case pp_fileOpened:
			if( self.currentTime > -1.8+shiftTime ) {
				processPhase = pp_preLoad;
				[self enqueueBuffers];
			}
            break;
            
        case pp_preLoad:
            if( self.currentTime > -1.5+shiftTime ) [self primeBuffers];
            break;
        
        case pp_prime:
            if( self.currentTime > -1.1+shiftTime ) processPhase = pp_waitCue;
            break;
            
        case pp_waitCue:        //  waiting for the start time 
            //  firing is handled by the songplayer
/*            if ( self.currentTime >= 0 && self.currentTime < 1 )
                                                    [self playWithVolume:-1];
*/            break;

        default:
            break;
    }
#if enableDSP
	
	/* for debug
	if ( queue ) {
		UInt32 size;
		AudioQueueGetPropertySize(queue, kAudioQueueProperty_IsRunning, &size);
		UInt32 running;
		OSStatus status = AudioQueueGetProperty( queue, kAudioQueueProperty_IsRunning, &running, &size);
		LLog(@"queue  %@ is running:%d / status:%ld, %d",fragId,(unsigned int)running, status, (unsigned int)size);
	}*/
/*
	AudioTimeStamp *ats_p = NULL;
	OSStatus status = AudioQueueGetCurrentTime(queue, nil, ats_p, nil);
	if( ats_p )
		LLog(@"CurrentTime:%.2f",ats_p->mSampleTime / audioObject_->cachedAudioFormat.mSampleRate);
	if (status)
		LLog(@"AudioQueueGetCurrentTime retured status:%ld",status);
*/
#endif
/*	if( self.currentTime > fileDuration -0.2 )
		AudioQueueStop(queue, NO );*/
	if( self.currentTime > fileDuration +1.0 )
		[self stop];
}	

#pragma mark -
#pragma mark play control

- (void)play {	
	if( processPhase < pp_fileOpened )  [self openAudioAndReadInfo];	
	if ( !queue )return;		//	not inited
	
	if( processPhase < pp_preLoad )     [self enqueueBuffers];
    if( processPhase < pp_prime )       [self primeBuffers];
    if( processPhase == pp_play )       return;
	
	processPhase = pp_play;
	self.currentTime = 0;
	OSStatus __unused status = AudioQueueStart(queue, nil);
	//LLog(@"start:%@ at %.2f, status:%ld",self.fragId,self.currentTime,status);

}

- (void)pause {
	NSLog( @"*%i Pause", playerId );
	AudioQueuePause(queue);
}

- (void)stop {
    UInt32 running;
	if ( queue ) {
		AudioQueueGetProperty( queue, kAudioQueueProperty_IsRunning, &running, nil);
#if enableDSP
		if( audioObject_->audioFile) AudioQueueStop( queue, YES );
		[audioObject_ close];
	//	LLog(@"stop:%@ at %.2f",self.fragId,self.currentTime);
#else
		if( /*running &&*/ audioFile) AudioQueueStop( queue, YES );
#endif
	}
	processPhase = pp_idle;
	self.currentTime = RESET_TIME;
	packetIndex = 0;
}

#pragma mark -
#pragma mark Callback

static void BufferCallback(void *inUserData, AudioQueueRef inAQ, AudioQueueBufferRef inBuffer) {
	// redirect back to the class to handle it there instead, so we have direct access to the instance variables
	[(VMBridge VMPAudioPlayer *)inUserData readPacketsIntoBuffer:inBuffer queue:inAQ];
}


- (NSString*)description {
	return [NSString stringWithFormat:
			@"AP<%d> time:%.2f phase:%@ dur(frag:%.2f file:%.2f)", 
			playerId, 
			self.currentTime,
			[processPhaseNames_static_ item:VMIntObj( processPhase )],
			fragDuration,
			fileDuration
			];
}

@end

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
static VMHash *processPhaseNames_static_ = nil;

#pragma mark -
#pragma mark accessor

-(Float32)loadedRatio {
	return packetIndex / (Float32) numTotalPackets;
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
	AudioFileClose(audioFile);
	audioFile = nil;
	processPhase = pp_idle;
}

- (void)dealloc {
	Release(timer);
	timer = nil;	
	[self close];
	if( packetDescs )   free( packetDescs );
    if( channelLayout ) free( channelLayout );
	Dealloc( super );
}

- (void) reallocBuffer {
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
    
	// allocate buffers
	for ( int i = 0; i < kNumberOfQueueBuffers; ++i ) {
		AudioQueueAllocateBuffer( queue, kAudioPlayer_BufferSize, &buffers[i] );
        buffers[i]->mUserData = (void*)i;   //  set the index of buffer
	}
}

- (void) createNewQueue {		
	// create a new playback queue using the specified data format and buffer callback
	AudioQueueNewOutput(
                        &dataFormat, 
                        BufferCallback, 
                        (VMBridge void *)(self),
                        CFRunLoopGetCurrent(), 
                        kCFRunLoopCommonModes, 
                        0, 
                        &queue);
    assert( queue != nil );
	[self reallocBuffer];

#if TARGET_OS_IPHONE
	//	prefer hardware decoder
	UInt32 hardwarePolicy = kAudioQueueHardwareCodecPolicy_PreferHardware;
	AudioQueueSetProperty( queue, kAudioQueueProperty_HardwareCodecPolicy, &hardwarePolicy, sizeof(hardwarePolicy));
#endif
	
}

#pragma mark -
#pragma mark audio file

- (void)openAudio:(NSString *)path {
	UInt32		size;

	if (path == nil)
        return;

	if( audioFile ) {
		AudioFileClose( audioFile );
		audioFile = nil;
	}
	
	// try to open up the file using the specified path
	NSURL		*url = [NSURL URLWithString:path];
	OSStatus	status;
	status =	AudioFileOpenURL( (VMBridge CFURLRef)url, 0x01, 0, &audioFile );
	if ( noErr != status ) {
		[VMException alert:@"Failed to open audio file." format:@"Audio file at path %@ status=%d", url, status];
		audioFile = nil;
		return;
	}
	
	// get the data format of the file
	size = sizeof(dataFormat);
	AudioFileGetProperty( audioFile, kAudioFilePropertyDataFormat, &size, &dataFormat );

	// get the length of the file
	size = sizeof( fileDuration );
	AudioFileGetProperty( audioFile, kAudioFilePropertyEstimatedDuration, &size, &fileDuration );
	
	if ( fragDuration == 0 ) fragDuration = fileDuration;
	//waveformSampleInterval = ( fileDuration * dataFormat.mSampleRate ) / kWaveFormCacheFrames;
}

- (void)preloadAudio:(NSString *)path atTime:(float)inTime {
    assert( path != nil );
    
	if( queue && audioFile ) [self close];
	processPhase = pp_warmUp;
	Release(filePathToRead);
	filePathToRead = Retain([NSString stringWithString:path]);
	packetIndex = 0;
	trackClosed = NO;
	self.currentTime = inTime;
}

-(void)openAudioAndReadInfo {
	char		*cookie;
	UInt32		size;
    
    processPhase = pp_locked;
	if ( ! filePathToRead ) {
		[self stop];
		return;
	}
	[self openAudio:filePathToRead];
    
    //  read packet count
    size = sizeof(numTotalPackets);
    AudioFileGetProperty(audioFile, kAudioFilePropertyAudioDataPacketCount, &size, &numTotalPackets );
	
    
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

	[self createNewQueue];
    processPhase = pp_fileOpened;
}

#pragma mark buffering

//static int logDone = 0;

- (UInt32)readPacketsIntoBuffer:(AudioQueueBufferRef)inBuffer queue:(AudioQueueRef)inAQ {
	UInt32		numBytes, numPackets;
	
	// read packets into buffer from file
	numPackets = numPacketsToRead;
	
	AudioFileReadPackets
	(
	 audioFile, 
	 NO,
	 &numBytes, 
	 packetDescs, 
	 packetIndex, 
	 &numPackets,
	 inBuffer->mAudioData );

    if (numPackets > 0)	{
        // - End Of File has not been reached yet since we read some packets, so enqueue the buffer we just read into
        // the audio queue, to be played next
        // - (packetDescs ? numPackets : 0) means that if there are packet descriptions (which are used only for Variable
        // BitRate data (VBR)) we'll have to send one for each packet, otherwise zero
        inBuffer->mAudioDataByteSize = numBytes;
        AudioQueueEnqueueBuffer(queue, inBuffer, (packetDescs ? numPackets : 0), packetDescs);
        
        // move ahead to be ready for next time we need to read from the file
        packetIndex += numPackets;
    }
	return numPackets;
}

-(void)enqueueBuffers {
    processPhase = pp_locked;
    
	for ( int i = 0; i < kNumberOfQueueBuffers; ++i )
        if( [self readPacketsIntoBuffer: buffers[i] queue:nil ] == 0 ) break;
	
    processPhase = pp_preLoad;
}

-(void)primeBuffers {
    processPhase = pp_locked;
    
	UInt32 preparedFrames;
    UInt32 primeFrames = 0x200;
	
	OSErr status = AudioQueuePrime( queue, primeFrames, &preparedFrames );
	if( status )
		NSLog(@"AudioQueuePrime Error:%d",status);
    processPhase = pp_prime;
}

#pragma mark -
#pragma mark timer handler

-(void)timerCall:(NSTimer*)theTimer {
    switch ( processPhase ) {
        case pp_locked:         //  currently processing something.
        case pp_idle:           //  nothing to do. ( playback has ended )
            return;
            break;
            
        case pp_warmUp:
            if( self.currentTime > 1 )              [self stop];        //  too late.
            if( self.currentTime > -2.5+shiftTime ) [self openAudioAndReadInfo];
            break;
            
        case pp_fileOpened:
            if( self.currentTime > -1.8+shiftTime ) [self enqueueBuffers];
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
	
	if( self.currentTime > fileDuration -0.2 )      AudioQueueStop(queue, NO );	// <- makes more noise?!
	if( self.currentTime > fileDuration +1.0 )      [self stop];
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
	AudioQueueStart(queue, nil);
	self.currentTime = 0;
}

- (void)pause {
	NSLog( @"*%i Pause", playerId );
	AudioQueuePause(queue);
}

- (void)stop {
    UInt32 running;
	if ( queue ) {
		AudioQueueGetProperty( queue, kAudioQueueProperty_IsRunning, &running, nil);
		
		if( /*running &&*/ audioFile) AudioQueueStop( queue, YES );
	}
	processPhase = pp_idle;
	self.currentTime = RESET_TIME;
	packetIndex = 0;
}

#pragma mark -
#pragma mark Callback
/*
- (void)callbackForBuffer:(AudioQueueBufferRef)inBuffer {
	[self readPacketsIntoBuffer:inBuffer];
}
*/
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

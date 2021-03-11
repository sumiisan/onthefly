//
//  VMAudioObject.m
//  OnTheFly
//
//  Created by sumiisan on 2013/05/03.
//
//

#import "VMAudioObject.h"
#import "VMPrimitives.h"
#import "VMException.h"
#import "VMPMacros.h"
#import <AudioToolbox/AudioToolbox.h>

@implementation VMAudioObject

@synthesize framesLoaded=framesLoaded_, numberOfFrames=numberOfFrames_, url=url_;
@synthesize waveData=waveData_, streamingMode=streamingMode_;

- (void)dealloc {
	VMNullify(url);
	if ( audioFile ) ExtAudioFileDispose( audioFile );
    if ( waveData_ ) free( waveData_ );
	Dealloc( super );
}


- (OSStatus)open:(NSString*)path {
	//	variables
	OSStatus status = noErr;
	UInt32 size;
    audioFile = nil;
	
	//	open in file
    self.url = [NSURL fileURLWithPath:path];
	
	if ( audioFile ) ExtAudioFileDispose( audioFile );
    status = ExtAudioFileOpenURL((VMBridge CFURLRef)self.url, &audioFile);
	if (status) return status;
	
	//	read format
    size = sizeof( audioFileFormat );
    status = ExtAudioFileGetProperty( audioFile, kExtAudioFileProperty_FileDataFormat, &size, &audioFileFormat );
	if (status) return status;
	
	//  read packet count
    size = sizeof( numberOfFrames_ );
    status = ExtAudioFileGetProperty( audioFile, kExtAudioFileProperty_FileLengthFrames, &size, &numberOfFrames_ );
	if (status) return status;
	
	
	//	client format
    cachedAudioFormat.mSampleRate		= audioFileFormat.mSampleRate;
    cachedAudioFormat.mFormatID			= kAudioFormatLinearPCM;
    cachedAudioFormat.mFormatFlags		= kAudioFormatFlagsNativeFloatPacked;
    cachedAudioFormat.mBitsPerChannel	= 32;	// VMPAudioSample = double
    cachedAudioFormat.mChannelsPerFrame	= audioFileFormat.mChannelsPerFrame;
    cachedAudioFormat.mFramesPerPacket	= 1;
    cachedAudioFormat.mBytesPerFrame	= cachedAudioFormat.mBitsPerChannel / 8 * cachedAudioFormat.mChannelsPerFrame;
    cachedAudioFormat.mBytesPerPacket	= cachedAudioFormat.mBytesPerFrame * cachedAudioFormat.mFramesPerPacket;
	
    status = ExtAudioFileSetProperty( audioFile,
								  kExtAudioFileProperty_ClientDataFormat,
								  sizeof( cachedAudioFormat ),
								  &cachedAudioFormat);
	
	return status;
}

- (OSStatus)load:(NSString *)path frames:(UInt32*)numberOfFramesToLoad {
	OSStatus status;
	//	open
	if ( ! audioFile ) {
		if ( !path ) return -1;
		status = [self open:path];
		if ( status ) return status;
	}
	
	//	alloc buffers
	size_t dataSize = (size_t)( numberOfFrames_ * cachedAudioFormat.mBytesPerFrame );
	
	if ( waveData_ )
		free( waveData_ );
    waveData_ = malloc( dataSize );
    if ( ! waveData_ ) {
		[VMException raise:@"Could not allocate memory."
					format:@"VMAudioObject could not allocate memory (%.2fkbytes) for reading file %@ ", dataSize / 1024., path ];
	}
	
    audioBufferList.mNumberBuffers = 1;	//	we will read the entire wavedata into one single buffer.
    audioBufferList.mBuffers[0].mNumberChannels = cachedAudioFormat.mChannelsPerFrame;
    audioBufferList.mBuffers[0].mDataByteSize = (UInt32)dataSize;
    audioBufferList.mBuffers[0].mData = waveData_;

	//	read
    if ( *numberOfFramesToLoad > numberOfFrames_ ) *numberOfFramesToLoad = (UInt32)numberOfFrames_;
	status = ExtAudioFileRead( audioFile, numberOfFramesToLoad, &audioBufferList );

//	LLog(@"ExtAudioFileRead loaded %ld",*numberOfFramesToLoad);
	return status;
}

- (OSStatus)load:(NSString*)path {
	UInt32 frames = UINT32_MAX;
	return [self load:path frames:&frames];
}

- (UInt32)framesToLoad {
	return (UInt32)numberOfFrames_;	//	TEST to read at once
	
	//	code below doesn't work yet
	int bytesPerFrame = cachedAudioFormat.mBytesPerFrame;
	int framesToLoad = (int) MIN( kAudioPlayer_BufferSize / bytesPerFrame,
						   numberOfFrames_ - framesLoaded_ );
	
	if ( framesToLoad <= 0 ) return 0;
	return (UInt32)framesToLoad;
}

- (OSStatus)beginLoad:(NSString*)path {
	UInt32 frames = [self framesToLoad];
	if ( frames == 0 ) return 0;

	OSStatus status = [self load:path frames:&frames];
	if( !status )
		framesLoaded_ += frames;
	
	return status;
}

- (OSStatus)continueLoad {
	int bytesPerFrame = cachedAudioFormat.mBytesPerFrame;
	UInt32 frames = [self framesToLoad];
	if ( frames == 0 || (!waveData_)) return 0;
	
	//	shift buffer start address
	audioBufferList.mBuffers[0].mData = waveData_ + framesLoaded_ * bytesPerFrame;
	audioBufferList.mBuffers[0].mDataByteSize = frames * bytesPerFrame;

	OSStatus status = ExtAudioFileRead( audioFile, &frames, &audioBufferList );
	if( !status )
		framesLoaded_ += frames;
	else
		LLog(@"continueLoad status:%d",(int)status);

	return status;
}

- (UInt32)framesLeft {
	if ( ! waveData_ ) return 0;
	return (UInt32)numberOfFrames_ - framesLoaded_;
}

- (void)close {
	if ( audioFile ) ExtAudioFileDispose( audioFile );
    if ( waveData_ ) free( waveData_ );
	waveData_ = nil;
}


- (int)bytesPerFrame {
	return cachedAudioFormat.mBytesPerFrame;
}

- (int)numberOfChannels {
	return cachedAudioFormat.mChannelsPerFrame;
}

- (int)framesPerSecond {
	return cachedAudioFormat.mSampleRate;
}

- (void*)dataAtFrame:(NSInteger)frame {
	if ( numberOfFrames_ <= frame )
		return nil;
	return waveData_ + frame * cachedAudioFormat.mBytesPerFrame;
}

- (void*)waveDataBorder {
	return waveData_ + self.bytesPerFrame * numberOfFrames_;
}

- (VMTime)fileDuration {
	return numberOfFrames_ / cachedAudioFormat.mSampleRate;
}


/*
 
	deprecated
 
//
//	note: this method draws the entire wave-form at once. use VMPWaveView to draw only the visible rect
//
- (NSImage*)drawWaveImageWithSize:(NSSize)size foreColor:(NSColor*)foreColor backColor:(NSColor*)backColor {
	NSImage *image = AutoRelease([[NSImage alloc] initWithSize:size]);
	if ( size.height > 0 && size.width > 0 ) {
		VMFloat pixelPerFrame =  size.width / _numberOfFrames;
		VMFloat currentX = 0;
		int x = 0;
		VMFloat m = size.height * 0.5;
		Float32 *waveDataBorder = self.waveDataBorder;
		Float32 min = 0;
		Float32 max = 0;
		
		[image lockFocus];
		[backColor set];
		NSRectFill(NSMakeRect(0, 0, size.width, size.height));
		[foreColor setStroke];
		for( Float32 *p = _waveData; p < waveDataBorder; ) {
			Float32 l = *p++;
			Float32 r = *p++;
			max = ( l > max ? l : ( r > max ? r : max ));
			min = ( l < min ? l : ( r < min ? r : min ));
			currentX += pixelPerFrame;
			if ( ((int)currentX) > x ) {
				[NSBezierPath strokeLineFromPoint:NSMakePoint(x+0.5, m + m * min) toPoint:NSMakePoint(x+0.5, m + m * max )];
				min = max = 0;
				++x;
			}
		}
		[image unlockFocus];
	}
	return image;
}
*/

/*
 */

@end

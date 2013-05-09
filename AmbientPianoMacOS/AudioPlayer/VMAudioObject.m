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
#import <AudioToolbox/AudioToolbox.h>

@implementation VMAudioObject

- (void)dealloc {
	if ( audioFile ) ExtAudioFileDispose( audioFile );
    if ( waveData ) free( waveData );
	[super dealloc];
}

/*
 based on code taken from mr. yasoshima's website 
 http://objective-audio.jp/2008/05/-extendedaudiofile.html
 */

- (OSErr)load:(NSString*)path {
	//	variables
	OSStatus err = noErr;
	UInt32 size;
    audioFile = nil;
	
	//	open in file
    NSURL *inUrl = [NSURL fileURLWithPath:path];
	
	if ( audioFile ) ExtAudioFileDispose( audioFile );
    err = ExtAudioFileOpenURL((CFURLRef)inUrl, &audioFile);
	if (err) return err;
	
	//	read format
    size = sizeof( audioFileFormat );
    err = ExtAudioFileGetProperty( audioFile, kExtAudioFileProperty_FileDataFormat, &size, &audioFileFormat );
	if (err) return err;
	
	//  read packet count
    size = sizeof( _numberOfFrames );
    err = ExtAudioFileGetProperty( audioFile, kExtAudioFileProperty_FileLengthFrames, &size, &_numberOfFrames );
	if (err) return err;
	
	
	//	client format
    cachedAudioFormat.mSampleRate		= audioFileFormat.mSampleRate;
    cachedAudioFormat.mFormatID			= kAudioFormatLinearPCM;
    cachedAudioFormat.mFormatFlags		= kAudioFormatFlagsNativeFloatPacked;
    cachedAudioFormat.mBitsPerChannel	= 32;
    cachedAudioFormat.mChannelsPerFrame	= audioFileFormat.mChannelsPerFrame;
    cachedAudioFormat.mFramesPerPacket	= 1;
    cachedAudioFormat.mBytesPerFrame	= cachedAudioFormat.mBitsPerChannel / 8 * cachedAudioFormat.mChannelsPerFrame;
    cachedAudioFormat.mBytesPerPacket	= cachedAudioFormat.mBytesPerFrame * cachedAudioFormat.mFramesPerPacket;
	
    err = ExtAudioFileSetProperty( audioFile, kExtAudioFileProperty_ClientDataFormat, sizeof( cachedAudioFormat ), &cachedAudioFormat);
	if (err) return err;
	
	//	alloc buffers
	UInt64	dataSize = _numberOfFrames * cachedAudioFormat.mBytesPerFrame;
	
	if ( waveData ) free( waveData );
    waveData = malloc( dataSize );
    if ( !waveData ) {
		[VMException raise:@"Could not allocate memory."
					format:@"VMAudioObject could not allocate memory (%.2fkbytes) for reading file %@ ", dataSize / 1024., path ];
	}
	
    AudioBufferList audioBufferList;
    audioBufferList.mNumberBuffers = 1;
    audioBufferList.mBuffers[0].mNumberChannels = cachedAudioFormat.mChannelsPerFrame;
    audioBufferList.mBuffers[0].mDataByteSize = (UInt32)dataSize;
    audioBufferList.mBuffers[0].mData = waveData;
	UInt32 frames = (UInt32)_numberOfFrames;
		
	//	read
	err = ExtAudioFileRead( audioFile, &frames, &audioBufferList );
		
	return err;
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
	if ( _numberOfFrames <= frame ) return nil;
	return waveData + frame * cachedAudioFormat.mBytesPerFrame;
}

- (NSImage*)drawWaveImageWithSize:(NSSize)size foreColor:(NSColor*)foreColor backColor:(NSColor*)backColor {
	NSImage *image = [[[NSImage alloc] initWithSize:size] autorelease];
	VMFloat pixelPerFrame =  size.width / _numberOfFrames;
	VMFloat currentX = 0;
	int x = 0;
	VMFloat m = size.height * 0.5;
	Float32 *waveDataBorder = waveData + self.bytesPerFrame * _numberOfFrames;
	Float32 min = 0;
	Float32 max = 0;
	
	[image lockFocus];
	[backColor set];
	NSRectFill(NSMakeRect(0, 0, size.width, size.height));
	[foreColor setStroke];
	for( Float32 *p = waveData; p < waveDataBorder; ) {
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
	return image;
}


@end

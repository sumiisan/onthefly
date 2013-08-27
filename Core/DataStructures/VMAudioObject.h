//
//  VMAudioObject.h
//  OnTheFly
//
//  Created by sumiisan on 2013/05/03.
//
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "MultiPlatform.h"
#import "VMPrimitives.h"

@interface VMAudioObject : NSObject {
	//  Core Audio file info
@public
	ExtAudioFileRef					audioFile;
	AudioStreamBasicDescription		audioFileFormat;
	AudioStreamBasicDescription		cachedAudioFormat;
	AudioBufferList					audioBufferList;

	void							*waveData_;
	UInt32							framesLoaded_;
}

@property (nonatomic)				UInt32 framesLoaded;		//	async load support
@property (nonatomic, readonly)		UInt32 framesLeft;
@property (nonatomic, readonly)		void *waveData;
@property (nonatomic, readonly)		void *waveDataBorder;
@property (nonatomic)				UInt64 numberOfFrames;
@property (nonatomic, retain)		NSURL *url;


- (OSStatus)open:(NSString*)path;
- (OSStatus)load:(NSString*)path;
- (OSStatus)beginLoad:(NSString*)path;
- (OSStatus)continueLoad;
- (void)close;

- (int)bytesPerFrame;
- (int)numberOfChannels;
- (int)framesPerSecond;
- (void*)dataAtFrame:(NSInteger)frame;
- (VMTime)fileDuration;

//	depreciated
//- (NSImage*)drawWaveImageWithSize:(NSSize)size foreColor:(NSColor*)foreColor backColor:(NSColor*)backColor;

@end

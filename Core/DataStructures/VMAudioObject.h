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

#if SUPPORT_32BIT_MAC
@protected
	NSURL							*url_;
	void							*waveData_;
	UInt32							framesLoaded_;
	UInt64							numberOfFrames_;
	BOOL							streamingMode_;
#endif
}

@property (nonatomic)				UInt32 framesLoaded;		//	async load support
@property (nonatomic, readonly)		UInt32 framesLeft;
@property (nonatomic, readonly)		void *waveData;
@property (nonatomic, readonly)		void *waveDataBorder;
@property (nonatomic)				UInt64 numberOfFrames;
@property (nonatomic, retain)		NSURL *url;
@property (nonatomic, getter = isStreamingMode ) BOOL streamingMode;


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

//- (NSImage*)drawWaveImageWithSize:(NSSize)size foreColor:(NSColor*)foreColor backColor:(NSColor*)backColor;

@end

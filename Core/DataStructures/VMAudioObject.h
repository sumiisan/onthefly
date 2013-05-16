//
//  VMAudioObject.h
//  OnTheFly
//
//  Created by sumiisan on 2013/05/03.
//
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "VMPrimitives.h"

@interface VMAudioObject : NSObject {
	//  Core Audio file info
	ExtAudioFileRef					audioFile;
	AudioStreamBasicDescription		audioFileFormat;
	AudioStreamBasicDescription		cachedAudioFormat;
	void							*_waveData;
}

@property (nonatomic, readonly)		void *waveData;
@property (nonatomic, readonly)		void *waveDataBorder;
@property (nonatomic)				UInt64 numberOfFrames;

- (OSErr)load:(NSString*)path;
- (int)bytesPerFrame;
- (int)numberOfChannels;
- (int)framesPerSecond;
- (void*)dataAtFrame:(NSInteger)frame;

- (NSImage*)drawWaveImageWithSize:(NSSize)size foreColor:(NSColor*)foreColor backColor:(NSColor*)backColor;

@end

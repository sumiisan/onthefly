//
//  MultiPlatform.h
//  VariableMusicPlayer
//
//  Created by cboy on 12/10/20.
//  Copyright 2012 sumiisan (aframasda.com) All rights reserved.
//

#ifndef _multiplatformh_
#define _multiplatformh_



#if TARGET_OS_IPHONE
//-------------------------------------------------------------
//
//  iphone
// 
//-------------------------------------------------------------
#define VMP_MOBILE 1
#define VMP_IPHONE 1
#define VMP_LOGGING 0
static const float kTimerInterval = 0.01;			//  1/1000 sec interruption for audio
static const int kTrackViewRedrawInterval = 10;		//  0.01 * 10   = 0.1sec
static const int kAudioPlayer_BufferSize = 0x8000;	//  32k buffer
static const int kNumberOfQueueBuffers = 3;			//  this is for CoreAudio's AudioQueueAllocateBuffer
static const int kNumberOfAudioPlayers = 10;		//  number of sound players
static const int kWaveFormCacheFrames = 0;			//	do not cache waveform

static const BOOL kUseNotification = NO;

#define Is4InchIPhone ( [[UIScreen mainScreen] bounds].size.height == 568 )


//
//  32k(buffer) x 3(buffer per player) x 4(players total) = 384k (x 2 (stereo??) not sure.. )
//
#define kEstimatedMemorySize ( kAudioPlayer_BufferSize * kNumberOfQueueBuffers * kNumberOfAudioPlayers )

//  aliases
#define VMPDocument UIDocument
#define VMPRect  CGRect
#define VMPFont  UIFont
#define VMPView  UIView
#define VMPColor UIColor
#define VMPColorBy(r,g,b,a) [UIColor colorWithRed:(CGFloat)(r) green:(CGFloat)(g) blue:(CGFloat)(b) alpha:(CGFloat)(a)] 
#define VMPSize  CGSize
#define VMPSetNeedsDisplay(instance)   [instance setNeedsDisplay]
#define VMPMakeRect(x,y,w,h) CGRectMake(x,y,w,h)
#define VMPSetAlpha setAlpha
#define RemoveAllSubViews [[self subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)]


#elif TARGET_OS_MAC
//-------------------------------------------------------------
//
//  osx
// 
//-------------------------------------------------------------
#define VMP_EDITOR 1
#define VMP_OSX 1
#define VMP_LOGGING 1
static const float kTimerInterval = 0.005;			//  1/2000 sec interruption for audio
static const int kTrackViewRedrawInterval = 6;		//  0.005 * 6   = 0.03sec
static const int kAudioPlayer_BufferSize =  0x20000;//  128k buffer
static const int kNumberOfQueueBuffers = 3;			//  this is for CoreAudio's AudioQueueAllocateBuffer
static const int kNumberOfAudioPlayers = 10;         //  number of sound players
static const int kWaveFormCacheFrames = 0x1000;		//	4k
//
//  128k(buffer) x 3(buffer per player) x 6(players total) = 2.25M (x 2 (stereo??) not sure.. )
//
#define kEstimatedMemorySize ( kAudioPlayer_BufferSize * kNumberOfQueueBuffers * kNumberOfAudioPlayers )

static const BOOL kUseNotification = YES;

#define APPDELEGATE	[VMPlayerOSXDelegate singleton]

//  aliases
#define VMPDocument NSDocument
#define VMPRect  NSRect
#define VMPFont  NSFont
#define VMPView  NSView
#define VMPColor NSColor
#define VMPColorBy(r,g,b,a) [NSColor colorWithCalibratedRed:(CGFloat)(r) green:(CGFloat)(g) blue:(CGFloat)(b) alpha:(CGFloat)(a)] 
#define VMPSize  NSSize
#define VMPSetNeedsDisplay(instance)   [instance setNeedsDisplay:YES]
#define VMPMakeRect(x,y,w,h) NSMakeRect(x,y,w,h)
#define VMPSetAlpha setAlphaValue
#define RemoveAllSubViews  [self setSubviews:[NSArray array]];



#else

#error OS TARGET NOT SUPPORTED

#endif


//-------------------------------------------------------------
//
//  common
//
//-------------------------------------------------------------
static const Float32 kDefaultFadeoutTime = 5.;
static NSString *kDefaultVMDirectory __unused = @"defaultSong";

#endif //_multiplatformh_

#import "VMARC.h"



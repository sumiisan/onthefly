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
 
	depreciated
 
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
 
 //
 //
 //
 
 
 //
 //  Created by Harry-Chris Stamatopoulos on 11/23/12.
 //
 
 
 This is an example of a hilbert transformer using
 Apple's VDSP fft/ifft & other VDSP calls.
 Output signal has a PI/2 phase shift.
 COMPLEX_SPLIT vector "B" was used to cross-check
 real and imaginary parts coherence with the original vector "A"
 that is obtained straight from the fft.
 Tested and working.
 Cheers!
 * /

#include <iostream>
#include <Accelerate/Accelerate.h>
#define PI 3.14159265
#define DEBUG_PRINT 1

int main(int argc, const char * argv[])
{
	
	
    float fs = 44100;           //sample rate
    float f0 = 440;             //sine frequency
    uint32_t i = 0;
	
	
    uint32_t L = 1024;
	
    /* vector allocations* /
    float *input = new float [L];
    float *output = new float[L];
    float *mag = new float[L/2];
    float *phase = new float[L/2];
	
	
    for (i = 0 ; i < L; i++)
    {
        input[i] = cos(2*PI*f0*i/fs);
    }
	
    uint32_t log2n = log2f((float)L);
    uint32_t n = 1 << log2n;
    //printf("FFT LENGTH = %lu\n", n);
	
	
    FFTSetup fftSetup;
    COMPLEX_SPLIT A;
    COMPLEX_SPLIT B;
    A.realp = (float*) malloc(sizeof(float) * L/2);
    A.imagp = (float*) malloc(sizeof(float) * L/2);
	
    B.realp = (float*) malloc(sizeof(float) * L/2);
    B.imagp = (float*) malloc(sizeof(float) * L/2);
	
	
    fftSetup = vDSP_create_fftsetup(log2n, FFT_RADIX2);
	
    /* Carry out a Forward and Inverse FFT transform. * /
    vDSP_ctoz((COMPLEX *) input, 2, &A, 1, L/2);
    vDSP_fft_zrip(fftSetup, &A, 1, log2n, FFT_FORWARD);
	
	
    mag[0] = sqrtf(A.realp[0]*A.realp[0]);
	
	
    //get phase
    vDSP_zvphas (&A, 1, phase, 1, L/2);
    phase[0] = 0;
	
	
    //get magnitude;
    for(i = 1; i < L/2; i++){
        mag[i] = sqrtf(A.realp[i]*A.realp[i] + A.imagp[i] * A.imagp[i]);
    }
	
	
    //after done with possible phase and mag processing re-pack the vectors in VDSP format
    B.realp[0] = mag[0];
    B.imagp[0] = mag[L/2 - 1];;
	
    //unwrap, process & re-wrap phase
    for(i = 1; i < L/2; i++){
        phase[i] -= 2*PI*i * fs/L;
        phase[i] -= PI / 2 ;
        phase[i] += 2*PI*i * fs/L;
    }
	
    //construct real & imaginary part of the output packed vector (input to ifft)
    for(i = 1; i < L/2; i++){
        B.realp[i] = mag[i] * cosf(phase[i]);
        B.imagp[i] = mag[i] * sinf(phase[i]);
    }
	
	
#if DEBUG_PRINT
    for (i = 0 ; i < L/2; i++)
    {
		printf("A REAL = %f \t A IMAG = %f \n", A.realp[i], A.imagp[i]);
		printf("B REAL = %f \t B IMAG = %f \n", B.realp[i], B.imagp[i]);
    }
#endif
    //ifft
    vDSP_fft_zrip(fftSetup, &B, 1, log2n, FFT_INVERSE);
	
    //scale factor
    float scale = (float) 1.0 / (2*L);
	
    //scale values
    vDSP_vsmul(B.realp, 1, &scale, B.realp, 1, L/2);
    vDSP_vsmul(B.imagp, 1, &scale, B.imagp, 1, L/2);
	
    //unpack B to real interleaved output
    vDSP_ztoc(&B, 1, (COMPLEX *) output, 2, L/2);
	
	
    // print output signal values to console
    printf("Shifted signal x = \n");
    for (i = 0 ; i < L/2; i++)
        printf("%f\n", output[i]);
	
	
	
    //release resources
    free(input);
    free(output);
    free(A.realp);
    free(A.imagp);
    free(B.imagp);
    free(B.realp);
    free(mag);
    free(phase);
	
}

*/

@end

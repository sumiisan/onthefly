//
//  VMAudioFFT.mm
//  OnTheFly
//
//  Created by sumiisan on 2013/12/26.
//
//

#include "VMAudioFFT.h"
#include <iostream>
#include <Accelerate/Accelerate.h>

#if __FLT_MANT_DIG__ != 24
#error float seems not to be 32bits
#endif



//
//
//	prototype
//
//
struct VMAudioFFT {
	VMAudioFFT();
	~VMAudioFFT();
public:
	void fft(float	inSamoleRate,
			 void	*inInterleavedStereoFloat32Audio,
			 long	inFrames,
			 long	offset
			 );
	void fft();
	
	
	float			*magnitude;
	float			*phase;
	
private:
	int				sampleRate;
	float			*interleavedStereoFloat32Audio;
	long			frames;
	float			*input;
	
	COMPLEX_SPLIT	work;
};


struct VMAudioFFTOpaque {
	VMAudioFFT	*fft;
};


@implementation VMAudioFFTWrapper

- (id)init {
    self = [super init];
    if (self) {
        self->cpp = new VMAudioFFTOpaque();
		self->cpp->fft = new VMAudioFFT;
    }
    return self;
}

- (void)dealloc {
    delete self->cpp;
    self->cpp = NULL;
    [super dealloc];
}

- (void)fft:(void *)interleavedFloat32Audio sampleRate:(int)inSampleRate frames:(long)frames offset:(long)offset {
	self->cpp->fft->fft(inSampleRate, interleavedFloat32Audio, frames, offset);
}

- (float*)magnitude {
	return self->cpp->fft->magnitude;
}

- (NSDictionary*)features {
	return @{};
}


@end



//
//
//	implementation
//
//
VMAudioFFT::VMAudioFFT() {
	input = new float[kHalfFFTLength];
	work.realp =	(float*) malloc(sizeof(float) * kHalfFFTLength);
	work.imagp =	(float*) malloc(sizeof(float) * kHalfFFTLength);
	magnitude =		new float[kHalfFFTLength];
	phase =			new float[kHalfFFTLength];
}


VMAudioFFT::~VMAudioFFT() {
	free( work.realp );
	free( work.imagp );
	delete [] input;
	delete [] magnitude;
	delete [] phase;
}


void VMAudioFFT::fft(float	inSampleRate,
					 void	*inInterleavedStereoFloat32Audio,
					 long	inFrames,
					 long	offset
					 ) {
						 
	sampleRate = inSampleRate;
	interleavedStereoFloat32Audio = (float*)inInterleavedStereoFloat32Audio;
	frames = inFrames;
	
//	NSLog(@"audio:%p frames:%ld offset:%ld",inInterleavedStereoFloat32Audio,inFrames,offset);
	
	//	deinterleave
	float *p = interleavedStereoFloat32Audio + offset *2;
	int i = 0;
	long framesToProcess = frames - offset;
	if ( framesToProcess > kHalfFFTLength ) framesToProcess = kHalfFFTLength;
	for (; i < framesToProcess; ++i) {
		float a = *p;
		++p;
		a += *p;
		++p;
		input[i] = a * 0.5;
	//	NSLog(@"%.2f",a*0.5);
	}
	for (; i<kHalfFFTLength; ++i) {
		input[i] = 0;
	}
	
	
	
	this->fft();
}

void VMAudioFFT::fft() {
	uint32_t i = 0;
	uint32_t log2n = log2f((float)kHalfFFTLength*2.);
	
	FFTSetup fftSetup;
	fftSetup = vDSP_create_fftsetup(log2n, FFT_RADIX2);
	NSLog(@"fftSetup:%p",fftSetup);
	
	/* Carry out a Forward and Inverse FFT transform. */
	vDSP_ctoz((COMPLEX *) input, 2, &work, 1, kHalfFFTLength);
	vDSP_fft_zrip(fftSetup, &work, 1, log2n, FFT_FORWARD);
	
	magnitude[0] = sqrtf( work.realp[0] * work.realp[0] );
	
	//get phase
	vDSP_zvphas ( &work, 1, phase, 1, kHalfFFTLength );		//	necessary?
	phase[0] = 0;
	
	//get magnitude;
	for( i = 1; i < kHalfFFTLength; i++ ) {
		float m =sqrtf( work.realp[i] * work.realp[i] + work.imagp[i] * work.imagp[i] );
		//NSLog(@"%d %f",i,m);
		magnitude[i] = m;
	}
	
	//unwrap, process & re-wrap phase
	/*
	 we do not need phase
	 for(i = 1; i < kHalfFFTLength; i++){
	 phase[i] -= 2*PI*i * fs/(kHalfFFTLength*2);
	 phase[i] -= PI / 2 ;
	 phase[i] += 2*PI*i * fs/(kHalfFFTLength*2);
	 }
	 
	 */
	vDSP_destroy_fftsetup(fftSetup);
}

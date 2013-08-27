//
//  VMPDSP.m
//  OnTheFly
//
//  Created by sumiisan on 2013/08/25.
//
//

#import "VMPDSP.h"

@implementation VMPDSP
- (id)initWithStream:(AudioStreamBasicDescription*)streamDescription {
	self = [super init];
	if ( self ) {
		self.audioFileFormat = streamDescription;
		self.parameter = AutoRelease( [[VMHash alloc] init] );
	}
	return self;
}

- (BOOL)process:(void*)samplePointer frames:(NSInteger)numberOfFrames {
	return NO;	//	virtual
}

- (void)dealloc {
	VMNullify(parameter);
	Dealloc(super);
}

@end


/*---------------------------------------------------------------------------------
 
 VMPBiquadFilter
 
 ----------------------------------------------------------------------------------*/

#pragma mark -
#pragma mark VMPBiquadFilter

@implementation VMPBiquadFilter

- (id)initWithStream:(AudioStreamBasicDescription*)streamDescription {
	self = [super initWithStream:streamDescription];
	if( self ) {
		[self.parameter setItem:@"BiquadFilter" for:@"name"];
	}
	return self;
}


//	biquad
- (BOOL)process:(void*)samplePointer frames:(NSInteger)numberOfFrames {	//	override
	
	const int channelsPerFrame = self.audioFileFormat->mChannelsPerFrame;
	const int bytesPerChannel = self.audioFileFormat->mBitsPerChannel / 8.;	//	ie. 32 / 8 = 4bytes
	
	while ( numberOfFrames ) {
		for ( int c = 0; c < channelsPerFrame; ++c ) {
			VMPAudioSample sample = *((VMPAudioSample*)samplePointer);
			VMPAudioSample result = a0 * sample + a1 * x1 + a2 * x2 - a3 * y1 - a4 * y2;
	
			x2 = x1;
			x1 = sample;
			y2 = y1;
			y1 = result;
			
			*((VMPAudioSample*)samplePointer) = result;	//	byterPerChannel must be equal to sizeof( VMPAudioSample )
			
			samplePointer += bytesPerChannel;
		}
		--numberOfFrames;
	}

	return YES;
}



- (void)setParameters:(vmp_FilterType)type
				 gain:(double)decibel
			frequency:(double)frequency
			bandwidth:(double)bandwidth {

    VMPAudioSample A, omega, sn, cs, alpha, beta;
    VMPAudioSample a0_, a1_, a2_, b0, b1, b2;
	
	/* setup variables */
    A = pow(10, decibel /40);
    omega = 2 * M_PI * frequency / self.audioFileFormat->mSampleRate;
    sn = sin(omega);
    cs = cos(omega);
    alpha = sn * sinh(M_LN2 /2 * bandwidth * omega /sn);
    beta = sqrt(A + A);
	
    switch (type) {
		case vmpFilter_LPF:
			b0 = (1 - cs) /2;
			b1 = 1 - cs;
			b2 = (1 - cs) /2;
			a0_ = 1 + alpha;
			a1_ = -2 * cs;
			a2_ = 1 - alpha;
			break;
		case vmpFilter_HPF:
			b0 = (1 + cs) /2;
			b1 = -(1 + cs);
			b2 = (1 + cs) /2;
			a0_ = 1 + alpha;
			a1_ = -2 * cs;
			a2_ = 1 - alpha;
			break;
		case vmpFilter_BPF:
			b0 = alpha;
			b1 = 0;
			b2 = -alpha;
			a0_ = 1 + alpha;
			a1_ = -2 * cs;
			a2_ = 1 - alpha;
			break;
		case vmpFilter_NOTCH:
			b0 = 1;
			b1 = -2 * cs;
			b2 = 1;
			a0_ = 1 + alpha;
			a1_ = -2 * cs;
			a2_ = 1 - alpha;
			break;
		case vmpFilter_PEQ:
			b0 = 1 + (alpha * A);
			b1 = -2 * cs;
			b2 = 1 - (alpha * A);
			a0_ = 1 + (alpha /A);
			a1_ = -2 * cs;
			a2_ = 1 - (alpha /A);
			break;
		case vmpFilter_LSH:
			b0 = A * ((A + 1) - (A - 1) * cs + beta * sn);
			b1 = 2 * A * ((A - 1) - (A + 1) * cs);
			b2 = A * ((A + 1) - (A - 1) * cs - beta * sn);
			a0_ = (A + 1) + (A - 1) * cs + beta * sn;
			a1_ = -2 * ((A - 1) + (A + 1) * cs);
			a2_ = (A + 1) + (A - 1) * cs - beta * sn;
			break;
		case vmpFilter_HSH:
			b0 = A * ((A + 1) + (A - 1) * cs + beta * sn);
			b1 = -2 * A * ((A - 1) + (A + 1) * cs);
			b2 = A * ((A + 1) + (A - 1) * cs - beta * sn);
			a0_ = (A + 1) - (A - 1) * cs + beta * sn;
			a1_ = 2 * ((A - 1) - (A + 1) * cs);
			a2_ = (A + 1) - (A - 1) * cs - beta * sn;
			break;
		default:
			return;
    }
	
    /* precompute the coefficients */
    a0 = b0  / a0_;
    a1 = b1  / a0_;
    a2 = b2  / a0_;
    a3 = a1_ / a0_;
    a4 = a2_ / a0_;
	
    /* zero initial samples */
    x1 = x2 = 0;
    y1 = y2 = 0;
}


@end

//
//  VMPDSP.h
//  OnTheFly
//
//  Created by sumiisan on 2013/08/25.
//
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

#import "VMPrimitives.h"

@interface VMPDSP : NSObject
@property (nonatomic) AudioStreamBasicDescription *audioFileFormat;
@property (nonatomic, VMStrong) VMHash *parameter;

- (BOOL)process:(void*)samplePointer frames:(NSInteger)numberOfFrames;
- (id)initWithStream:(AudioStreamBasicDescription*)streamDescription;

@end



/*---------------------------------------------------------------------------------
 
 Biquad filter
 translation of biquadfilter taken from MusicDSP.org
 
 see the original comment below.
 
 ----------------------------------------------------------------------------------*/

	/* Simple implementation of Biquad filters -- Tom St Denis
	 *
	 * Based on the work
	 
	 Cookbook formulae for audio EQ biquad filter coefficients
	 ---------------------------------------------------------
	 by Robert Bristow-Johnson, pbjrbj@viconet.com  a.k.a. robert@audioheads.com
	 
	 * Available on the web at
	 
	 http://www.smartelectronix.com/musicdsp/text/filters005.txt
	 
	 * Enjoy.
	 *
	 * This work is hereby placed in the public domain for all purposes, whether
	 * commercial, free [as in speech] or educational, etc.  Use the code and please
	 * give me credit if you wish.
	 *
	 * Tom St Denis -- http://tomstdenis.home.dhs.org
	 */



typedef enum {
    vmpFilter_LPF, /* low pass filter */
    vmpFilter_HPF, /* High pass filter */
    vmpFilter_BPF, /* band pass filter */
    vmpFilter_NOTCH, /* Notch Filter */
    vmpFilter_PEQ, /* Peaking band EQ filter */
    vmpFilter_LSH, /* Low shelf filter */
    vmpFilter_HSH /* High shelf filter */
} vmp_FilterType;

@interface VMPBiquadFilter : VMPDSP {
    VMPAudioSample a0, a1, a2, a3, a4;
    VMPAudioSample x1, x2, y1, y2;
}

- (void)setParameters:(vmp_FilterType)type
				 gain:(double)decibel
			frequency:(double)frequency
			bandwidth:(double)bandwidth;






@end

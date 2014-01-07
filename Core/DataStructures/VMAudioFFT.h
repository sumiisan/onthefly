//
//  VMAudioFFT.h
//  OnTheFly
//
//  Created by sumiisan on 2013/12/26.
//
//

#ifndef __OnTheFly__VMAudioFFT__
#define __OnTheFly__VMAudioFFT__

#ifndef PI
#define PI 3.14159265
#endif

#define kHalfFFTLength 512


struct VMAudioFFTOpaque;
@interface VMAudioFFTWrapper : NSObject {
    struct VMAudioFFTOpaque *cpp;
}

- (void)fft:(void*)interleavedFloat32Audio
 sampleRate:(int)inSamoleRate
	 frames:(long)frames
	 offset:(long)offset;

- (NSDictionary*)features;
- (float*)magnitude;


@end
#endif /* defined(__OnTheFly__VMAudioFFT__) */

//
//  VMWavFileLoader.m
//  OnTheFly Editor OSX
//
//  Created by cboy mbp m1 on 2021/03/11.
//

#import "VMWavFileLoader.h"
#import "VMWavFile.h"

@interface VMWavFileLoader() {
    WaveFile waveFile;
}


@end

@implementation VMWavFileLoader

- (void)open:(NSURL*)url {
    const char *path = [url.path cStringUsingEncoding:NSUTF8StringEncoding];
    waveFile = newWaveFile(path);
    readWavfile(&waveFile);
    
}


@end

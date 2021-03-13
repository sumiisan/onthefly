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

@property (nonatomic) NSMutableArray<VMAudioFileCue*>* cues;

@end

@implementation VMWavFileLoader


- (void)open:(NSURL*)url {
    const char *path = [url.path cStringUsingEncoding:NSUTF8StringEncoding];
    waveFile = newWaveFile(path);
    readWavfile(&waveFile);
    
    self.cues = [NSMutableArray array];
    
    for (int i = 0; i < waveFile.numberOfCuePoints; ++i) {
        VMAudioFileCue *cue = [VMAudioFileCue new];
        [self.cues addObject:cue];
        cue.fileId = url.path.pathComponents.lastObject.stringByDeletingPathExtension;
        
        CuePoint *cuePoint = waveFile.cueChunk.cuePoints + i;
        
        cue.frameOffset = littleEndianBytesToUInt32(cuePoint->frameOffset);
        cue.cuePointId = littleEndianBytesToUInt32(cuePoint->cuePointID);
        ListLabelNote *label = findLabelById(&waveFile, cuePoint->cuePointID);
        if (label) {
            cue.id = [NSString stringWithCString:label->data encoding:NSUTF8StringEncoding];
        }
        ListLabeledText *ltext = findLabeledTextById(&waveFile, cuePoint->cuePointID);
        if (ltext) {
            if (strncmp(ltext->purposeIDBytes, "rgn ", 4) == 0) {
                cue.sampleLength = littleEndianBytesToUInt32(ltext->sampleLengthBytes);
            }
        }

        NSLog(@"cue read: %@", cue);
    }
    
    freeWaveFile(&waveFile);
}


@end

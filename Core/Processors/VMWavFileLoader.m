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
        
        if (cue.sampleLength == 0) {    // not specified: determine using next cue
            CuePoint *nextCuePoint;
            if (i + 1 < waveFile.numberOfCuePoints) {
                nextCuePoint = waveFile.cueChunk.cuePoints + i + 1;
                if (nextCuePoint) {
                    cue.sampleLength = littleEndianBytesToUInt32(nextCuePoint->frameOffset) - cue.frameOffset;     // everyting between frameOffsets
                } else {
                    cue.sampleLength = waveFile.fileSize - cue.frameOffset;  // may have reached the end of file
                }
            } else if (cue.sampleLength == 0) {  // reached the end of file
                cue.sampleLength = waveFile.fileSize - cue.frameOffset;
            }
        }

        NSLog(@"cue read: %@", cue);
    }
    
    freeWaveFile(&waveFile);
}


@end

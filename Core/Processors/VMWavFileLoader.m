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
@property (nonatomic) NSMutableArray<VMFragment*>* frags;

@end

@implementation VMWavFileLoader


- (VMArray*)open:(NSURL*)url {
    const char *path = [url.path cStringUsingEncoding:NSUTF8StringEncoding];
    waveFile = newWaveFile(path);
    readWavfile(&waveFile);
    
    self.cues = [NSMutableArray array];
    self.frags = [NSMutableArray array];

    double SR = waveFile.sampleRate;

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
        
        // create frag:
        if ([cue.id hasPrefix:@"_"]) {
            continue; // skip instruction cue
        }

        NSString *cueInst = cue.id;
        VMId *seqId = [cueInst componentsSeparatedByString:@"_"][0];
        
        // rename audio cue
        cue.id = [NSString stringWithFormat:@"%@|cue", seqId];
        
        // convert frame-offset/sampleLength to range
        cue.regionRange.locationDescriptor = [NSString stringWithFormat:@"%3.3f", cue.frameOffset / SR];
        cue.regionRange.lengthDescriptor = [NSString stringWithFormat:@"%3.3f", cue.sampleLength / SR];
        
        // set cue points to fill region
        cue.offsetAndDuration.locationDescriptor = @"0";    // no offset
        cue.offsetAndDuration.lengthDescriptor = [NSString stringWithFormat:@"%3.3f", cue.sampleLength / SR];

        // audio fragment
        VMAudioFragment *frag = [VMAudioFragment new];
        frag.id = [NSString stringWithFormat:@"%@|frag", seqId];
        frag.audioInfoId = cue.id;
        frag.audioInfoRef = cue;
        
        // sequence
        VMSequence *seq = [VMSequence new];
        seq.id = seqId;
        seq.fragments = [VMArray arrayWithObject: frag.id];
        VMSelector *next = [VMSelector new];
        next.id = [NSString stringWithFormat:@"%@|next", seqId];
        next.fragments = [VMArray new];
        seq.subsequent = next;
        
        NSArray *insts = [cueInst componentsSeparatedByString:@"_"];
        for (NSString *inst in insts) {
            if (![inst hasPrefix:@"~"]) continue;
            NSArray *qs = [[inst substringFromIndex:1] componentsSeparatedByString:@","];
            for (NSString *q in qs) {
                VMChance *ch = [VMChance new];
                NSArray *cs = [q componentsSeparatedByString:@"="];
                ch.targetId = [cs[0] componentsSeparatedByString:@"_"][0];
                ch.scoreDescriptor = cs.count > 1 ? cs[1] : @"1";
                [next.fragments push:ch];
            }
        }
        
        [self.frags addObject:seq];     // the sequence must be registered at the very begin of frags to indicate the entry point
        [self.frags addObject:frag];
        [self.frags addObject:cue];
    }
    
    freeWaveFile(&waveFile);
    
    VMArray *array;
    
    array = [VMArray arrayWithArray:self.frags];
    return array;
}


@end

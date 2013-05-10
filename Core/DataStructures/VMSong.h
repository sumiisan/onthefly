//
//  NLSong.h
//  VariableMusicPlayer
//
//  Created by cboy on 12/10/30.
//  Copyright 2012 sumiisan (aframasda.com). All rights reserved.
//

#import <Foundation/Foundation.h>
#import "VMDataTypes.h"
#import "VMLog.h"
#import "MultiPlatform.h"


#define DEFAULTSONG [VMSong defaultSong]

@interface VMSong : NSObject

//	song data structure
@property (VMNonatomic retain)	VMHash	 *songData;

//	static song properties
@property (nonatomic, readonly)	VMString *songName;
@property (nonatomic, retain)	VMString *audioFileExtension;
@property (nonatomic, retain)	VMString *vsFilePath;
@property (nonatomic, retain)	VMString *audioFileDirectory;
@property (nonatomic, retain)	VMArray	 *entryPoints;
@property (nonatomic, readonly)	VMString *defaultFragmentId;

//	runtime properties
@property (VMNonatomic retain)	VMPlayer *player;
@property (VMNonatomic retain)	VMArray	 *history;
@property (nonatomic, retain)	VMStack	 *showReport;

//	log
#if VMP_LOGGING
@property (VMNonatomic retain)	VMLog	 *log;
#endif




+ (VMSong*)defaultSong;
- (void)setByHash:(VMHash*)hash;
- (id)data:(VMId*)dataId;
- (VMAudioFragment*)nextAudioFragment;

- (NSString*)callStackInfo;
- (BOOL)isVerbose;

- (void)reset;
//	history
- (void)record:(VMArray*)fragIds;
- (VMInt)distanceToLastRecordOf:(VMId*)fragId;

- (void)setFragmentId:(VMId*)fragId;
- (VMPlayer*)playerFrom:(id)someObj;
- (id)resolveDataWithId:(VMId*)dataId untilReachType:(int)mask;


- (BOOL)readFromURL:(NSURL *)url error:(NSError **)outError;
- (BOOL)readFromData:(NSData *)data error:(NSError **)outError;

@end

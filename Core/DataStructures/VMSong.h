//
//  VMSong
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

@interface VMSong : NSObject {
#if SUPPORT_32BIT_MAC
	NSURL		*fileURL_;
	VMHash		*songData_;
	VMString	*vmsData_;
	
	VMString	*songName_;
	VMString	*audioFileExtension_;
	VMString	*audioFileDirectory_;
	VMId		*defaultFragmentId_;

	VMPlayer	*player_;
	VMArray		*history_;
	VMStack		*showReport_;
#endif

}

@property (nonatomic, VMStrong)	NSURL	*fileURL;

//	song data structure
@property (nonatomic, VMStrong)		VMHash	 *songData;
@property (nonatomic, VMStrong)		VMString *vmsData;

//	static song properties
@property (nonatomic, VMStrong)		VMString *songName;
@property (nonatomic, VMStrong)		VMString *audioFileExtension;
//@property (nonatomic, VMStrong)		VMString *vsFilePath;

@property (nonatomic, VMStrong)		VMString *audioFileDirectory;
@property (nonatomic, VMStrong)		VMId	 *defaultFragmentId;

//	runtime properties
@property (VMNonatomic VMStrong)	VMPlayer *player;
@property (VMNonatomic VMStrong)	VMArray	 *history;
@property (nonatomic, VMStrong)		VMStack	 *showReport;

//	log
#if VMP_LOGGING
@property (VMNonatomic VMStrong)	VMLog	 *log;
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


- (BOOL)isFragmentDeadEnd:(VMId*)fragId;

//
//	read and save
//
- (void)clear;
- (BOOL)readFromURL:(NSURL *)url error:(NSError **)outError;
- (BOOL)readFromData:(NSData *)data error:(NSError **)outError;
- (BOOL)readFromString:(VMString *)string error:(NSError **)outError;
- (BOOL)saveToURL:(NSURL *)url error:(NSError **)outError;

@end

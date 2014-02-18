//
//  VMVmsarcManager.h
//  OnTheFly
//
//  Created by sumiisan on 2014/02/15.
//
//

#import <Foundation/Foundation.h>
#import "VMPProgressView.h"

@protocol VMVmsarcManagerDelegate<NSObject>
	- (void)vmsarcLoaded;
	- (void)vmsarcLoadingFailed;
@end

@protocol VMVmsarcManagerUpdateDelegate <NSObject>
	- (void)archiveUpdateAvailable:(NSString*)archiveId;
@end

FOUNDATION_EXPORT NSString *const VMSCacheKey_DataVersion;
FOUNDATION_EXPORT NSString *const VMSCacheKey_VmsId;
FOUNDATION_EXPORT NSString *const VMSCacheKey_ArchiveId;
FOUNDATION_EXPORT NSString *const VMSCacheKey_Enabled;
FOUNDATION_EXPORT NSString *const VMSCacheKey_SongName;
FOUNDATION_EXPORT NSString *const VMSCacheKey_BuiltIn;
FOUNDATION_EXPORT NSString *const VMSCacheKey_DataUrl;
FOUNDATION_EXPORT NSString *const VMSCacheKey_Website;
FOUNDATION_EXPORT NSString *const VMSCacheKey_Downloaded;
FOUNDATION_EXPORT NSString *const VMSCacheKey_Artist;


@interface VMVmsarcManager : NSObject<NSURLConnectionDelegate,NSURLConnectionDataDelegate> {
	NSUInteger dataSize;
	NSUInteger bytesRead;
	BOOL checkUpdateOnly;
}
	+ (VMVmsarcManager*)defaultManager;
	- (BOOL)openURL:(NSURL*)url checkUpdatesOnly:(BOOL)checkUpdatesOnly;
	- (void)checkUpdatesForCacheId:(NSString*)cacheId;
	- (void)reloadCacheId:(NSString*)cacheId;
	- (void)makeCurrent:(NSString*)cacheId;
	- (NSString*)builtInCacheId;
	
	- (NSString*)zippedDataPath;
	- (NSString*)dataDirectory;
	- (NSString*)vmsFilePath;
	- (NSString*)userSaveFilePath;
	
	- (NSString*)artworkPathForCacheId:(NSString*)cacheId;
	
	- (BOOL)externalVMSMode;
	- (id)property:(NSString*)propertyName ofCacheId:(NSString*)cacheId;
	- (id)propertyOfCurrentVMS:(NSString*)propertyName;
	- (void)setPropertyOfCurrentVMS:(NSString*)propertyName to:(id)data;
	- (void)deleteArchive:(NSString*)archiveId;
	- (NSString*)currentCacheId;
	
	@property (nonatomic,assign) id<VMVmsarcManagerDelegate> delegate;
	@property (nonatomic,assign) id<VMVmsarcManagerUpdateDelegate> updateDelegate;
	@property (nonatomic,retain) NSString *currentArchiveId;
	@property (nonatomic,retain) NSString *currentVmsId;
	@property (nonatomic,retain) NSMutableDictionary *vmsCacheTable;

@end
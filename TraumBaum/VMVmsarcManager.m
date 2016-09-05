//
//  VMVmsarcManager.m
//  OnTheFly
//
//  Created by sumiisan on 2014/02/15.
//
//

#import "VMVmsarcManager.h"
#import "VMTraumbaumUserDefaults.h"
#import "SSZipArchive.h"

#if VMP_IPHONE
#import "VMAppDelegate.h"
#endif

#import "VMViewController.h"

NSString *const VMSCacheKey_DataVersion	= @"DataVersion";
NSString *const VMSCacheKey_VmsId		= @"VmsId";
NSString *const VMSCacheKey_ArchiveId	= @"ArchiveId";
NSString *const VMSCacheKey_Enabled		= @"Enabled";
NSString *const VMSCacheKey_BuiltIn		= @"BuiltIn";
NSString *const VMSCacheKey_SongName	= @"SongName";
NSString *const VMSCacheKey_DataUrl		= @"DataUrl";
NSString *const VMSCacheKey_Website		= @"Website";
NSString *const VMSCacheKey_Downloaded	= @"Downloaded";
NSString *const VMSCacheKey_Artist		= @"Artist";

#define BUILTIN_VMS_ID @"traumbaum"

@interface VMVmsarcManager()
	//	internal
	@property (nonatomic,retain) NSURL *vmsURL;
	@property (nonatomic,retain) NSURLConnection *urlConnection;
	@property (nonatomic,retain) NSFileHandle *localFile;
	@property (nonatomic,retain) VMPProgressView *progressView;

	@property (nonatomic,retain) NSString *cacheIdToCheckUpdate;
@end

@implementation VMVmsarcManager
@synthesize delegate,vmsCacheTable;
	
static VMVmsarcManager *vmsarcmanager_singleton__ = nil;
	

+ (VMVmsarcManager*)defaultManager {
	if( ! vmsarcmanager_singleton__ ) vmsarcmanager_singleton__ = [[VMVmsarcManager alloc] init];
	return vmsarcmanager_singleton__;
}
	
- (id)init {
	self = [super init];
	if( self ) {
		//	the default
		self.vmsURL = [[[NSURL alloc] initFileURLWithPath:[NSString stringWithFormat:@"%@/%@",
														   [[NSBundle bundleForClass: [VMAppDelegate class]] resourcePath],
														   @"defaultSong"] isDirectory:YES] autorelease];
		

		self.delegate = [VMAppDelegate defaultAppDelegate];	//	by the default.
		self.vmsCacheTable = [[[VMTraumbaumUserDefaults vmsCacheTable] mutableCopy] autorelease];
		if( ! self.vmsCacheTable ) {
			self.vmsCacheTable = [NSMutableDictionary dictionary];
			[self.vmsCacheTable setObject:@{ VMSCacheKey_SongName:BUILTIN_VMS_ID,
											 VMSCacheKey_ArchiveId:BUILTIN_VMS_ID,
											 VMSCacheKey_VmsId:@"default",
											 VMSCacheKey_Enabled:@YES,
											 VMSCacheKey_DataVersion:@"",
											 VMSCacheKey_BuiltIn:@YES,
											 } forKey:BUILTIN_VMS_ID];
			[VMTraumbaumUserDefaults setVmsCacheTable:self.vmsCacheTable];
		}
		[self makeCurrent:BUILTIN_VMS_ID];
	}
	return self;
}
	
- (void)dealloc {
	self.vmsCacheTable = nil;
	self.vmsURL = nil;
	[self.urlConnection cancel];
	self.urlConnection = nil;
	self.localFile = nil;
	[self.progressView removeFromSuperview];
	self.progressView = nil;
	self.currentArchiveId = nil;
	self.currentVmsId = nil;
	self.cacheIdToCheckUpdate = nil;
	[super dealloc];
}

- (BOOL)openURL:(NSURL*)url checkUpdatesOnly:(BOOL)checkUpdatesOnly {
	checkUpdateOnly = checkUpdatesOnly;
	//
	//	check extension
	//
	self.vmsURL = nil;
	
	NSString *ext = [url.pathExtension lowercaseString];
	if(![ext isEqualToString:@"vmsarc"]
	   &&
	   ![ext isEqualToString:@"zip"] ) {
		NSLog(@"invalid vmsarc file");
		return NO;
	}
	
	//
	//	make http url
	//
	NSString *path;
	if( url.query.length > 0 ) {
		path = [url.path stringByAppendingFormat:@"?%@", url.query];
	} else {
		path = url.path;
	}
	
	NSURL *httpURL = [[[NSURL alloc] initWithScheme:@"http" host:url.host path:path] autorelease];
	
	if( ! checkUpdatesOnly ) {
		self.vmsURL = httpURL;
		self.currentArchiveId = [url.lastPathComponent stringByDeletingPathExtension];
		[self prepareCacheForCurrentVMS];
		[self setPropertyOfCurrentVMS:VMSCacheKey_DataUrl to:url.absoluteString];
		self.cacheIdToCheckUpdate = [self currentCacheId];
	}
	[self startDownload:httpURL];
	return YES;
}
	
- (void)checkUpdatesForCacheId:(NSString*)cacheId {
	self.cacheIdToCheckUpdate = cacheId;
	[self openURL:[NSURL URLWithString:[self property:VMSCacheKey_DataUrl ofCacheId:cacheId]] checkUpdatesOnly:YES];
}
	
- (void)reloadCacheId:(NSString*)cacheId {
	[self openURL:[NSURL URLWithString:[self property:VMSCacheKey_DataUrl ofCacheId:cacheId]] checkUpdatesOnly:NO];
}
	
- (BOOL)externalVMSMode {
	return ! [self.currentArchiveId isEqualToString:BUILTIN_VMS_ID];
}
	
#pragma mark - path and directory

- (NSURL*)applicationDocumentsDirectory {
	return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory
												   inDomains:NSUserDomainMask] lastObject];
}

- (NSString*)localPathBase {
	return [[self applicationDocumentsDirectory].path stringByAppendingPathComponent:self.currentArchiveId];
}
	
- (NSString*)zippedDataPath {
	return [[self localPathBase] stringByAppendingString:@".download"];
}
	
- (NSString*)dataDirectory {
	if ( [self externalVMSMode] ) {
		return [[self localPathBase] stringByAppendingString:@"/"];
	} else {
		return [[[NSBundle bundleForClass: [VMAppDelegate class]] resourcePath] stringByAppendingPathComponent:@"defaultSong/"];
	}
}
	
- (NSString*)dataDirectoryForCacheId:(NSString*)cacheId {
	if ( ![cacheId isEqualToString:BUILTIN_VMS_ID] ) {
		return [[[self applicationDocumentsDirectory].path stringByAppendingPathComponent:cacheId] stringByAppendingString:@"/"];
	} else {
		return [[[NSBundle bundleForClass: [VMAppDelegate class]] resourcePath] stringByAppendingPathComponent:@"defaultSong/"];
	}
}
	
- (NSString*)artworkPathForCacheId:(NSString*)cacheId {
	return [[self dataDirectoryForCacheId:cacheId] stringByAppendingPathComponent:@"artwork.jpg"];
}
	
- (NSString*)vmsFilePath {
	NSString *pc = [NSString stringWithFormat:@"%@.vms", self.currentVmsId];
	return [[self dataDirectory] stringByAppendingPathComponent: pc];
}
	
- (NSString*)userSaveFilePath {
	NSString *pc = [NSString stringWithFormat:@"%@_%@.usersave", self.currentArchiveId, self.currentVmsId];
	return [[self applicationDocumentsDirectory].path stringByAppendingPathComponent: pc];
}

#pragma mark - vms cache access

/*
 *
 *	vmsCache access
 *
 */

- (NSString*)currentCacheId {
	if( [self.currentVmsId isEqualToString:@"default"] ) {
		return self.currentArchiveId;
	} else {
		return [NSString stringWithFormat:@"%@ %@", self.currentArchiveId, self.currentVmsId];
	}
}
	
- (NSString*)builtInCacheId {
	NSArray *keys = [self.vmsCacheTable allKeys];
	for( NSString *key in keys ) {
		NSDictionary *d = self.vmsCacheTable[key];
		if ( [d[VMSCacheKey_BuiltIn] boolValue] ) {
			return key;
		}
	}
	return nil;
}
	
- (void)makeCurrent:(NSString*)cacheId {
	NSDictionary *d = self.vmsCacheTable[cacheId];
	self.currentArchiveId = d[VMSCacheKey_ArchiveId];
	self.currentVmsId = d[VMSCacheKey_VmsId];
	NSLog(@"make %@ current: %@ / %@", cacheId, self.currentArchiveId, self.currentVmsId);
	[self prepareCacheForCurrentVMS];
}
	 
- (id)property:(NSString*)propertyName ofCacheId:(NSString*)cacheId {
	return self.vmsCacheTable[cacheId][propertyName];
}

- (id)propertyOfCurrentVMS:(NSString*)propertyName {
	return [self property:propertyName ofCacheId:[self currentCacheId]];
}

- (void)setPropertyOfCurrentVMS:(NSString*)propertyName to:(id)data {
	NSString *cacheId = [self currentCacheId];
	NSMutableDictionary *d = [self.vmsCacheTable objectForKey:cacheId];
	if( data )
		[d setObject:data forKey:propertyName];
	[VMTraumbaumUserDefaults setVmsCacheTable:self.vmsCacheTable];
}

- (void)prepareCacheForCurrentVMS {
	NSString *cacheId = [self currentCacheId];
	NSMutableDictionary *cache = [self.vmsCacheTable objectForKey:cacheId];
	if( ! cache ) {
		//1st time initalization
		cache = [NSMutableDictionary dictionaryWithObjectsAndKeys:
				 self.currentVmsId,				VMSCacheKey_VmsId,
				 self.currentArchiveId,			VMSCacheKey_ArchiveId,
				 @"",							VMSCacheKey_DataVersion,
				 @YES,							VMSCacheKey_Enabled,
				 self.currentArchiveId,			VMSCacheKey_SongName,	//	temporary. should be set by VMSong when vms parsed.
				 @NO,							VMSCacheKey_BuiltIn,
				 nil];
		[self.vmsCacheTable setObject:cache forKey:cacheId];
	} else if( ! [cache isMemberOfClass: [NSMutableDictionary class]] ) {
		cache = [NSMutableDictionary dictionaryWithDictionary:cache];
		[self.vmsCacheTable setObject:cache forKey:cacheId];
	}
}
	
- (void)deleteArchive:(NSString*)archiveId {
	NSString *archiveDirectory = [[self applicationDocumentsDirectory].path stringByAppendingPathComponent:archiveId];
	[[NSFileManager defaultManager] removeItemAtPath:archiveDirectory error:nil];
	NSArray *keys = [self.vmsCacheTable allKeys];
	for( NSString *key in keys ) {
		NSDictionary *d = [self.vmsCacheTable objectForKey:key];
		if ( [[d objectForKey:VMSCacheKey_ArchiveId] isEqualToString:archiveId] ) {
			[self.vmsCacheTable removeObjectForKey:key];
		}
	}
	[VMTraumbaumUserDefaults setVmsCacheTable:self.vmsCacheTable];
}

#pragma mark - *** download ***
/*
 *
 *	download
 *
 */
- (void)startDownload:(NSURL*)url {
	bytesRead = 0;
	dataSize = 0;
	self.urlConnection = [[NSURLConnection alloc] initWithRequest:[NSURLRequest requestWithURL:url]
														 delegate:self
												 startImmediately:YES];
}
	
#pragma mark - NSURLConnection, NSURLConnectionData delegates
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
	NSLog(@"external vms load failed:%@", error.description);
	[self.delegate vmsarcLoadingFailed];

}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
	NSDictionary *allHeaderFields = [(NSHTTPURLResponse *)response allHeaderFields];
	
	dataSize = [[allHeaderFields objectForKey:@"Content-Length"] integerValue];
	
	NSString *dataversion = [allHeaderFields objectForKey:VMSCacheKey_DataVersion];
	if( ! dataversion ) {
		dataversion = [allHeaderFields objectForKey:@"Etag"];
	}
	
	NSString *cachedDataVersion = [self property:VMSCacheKey_DataVersion ofCacheId:self.cacheIdToCheckUpdate];
	
	if( [cachedDataVersion isEqualToString: dataversion] ) {
		//	the local file is up-to-date!
		[connection cancel];
		NSLog(@"file is up-to-date! data version =%@",dataversion);
		if( ! checkUpdateOnly ) {
			[self finishDownload:YES];
		}
	} else {
		if( ! checkUpdateOnly ) {
			[self setPropertyOfCurrentVMS:VMSCacheKey_DataVersion to:dataversion];
			NSLog(@"set data version=%@",dataversion);
		} else {
			[connection cancel];
			[self.updateDelegate archiveUpdateAvailable:self.cacheIdToCheckUpdate];
		}
	}
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
	if ( checkUpdateOnly ) return;
	if ( ! self.localFile ) {
		NSString *tempPath = [self zippedDataPath];
		[[NSFileManager defaultManager] createFileAtPath:tempPath contents:nil attributes:nil];
		self.localFile = [NSFileHandle fileHandleForWritingAtPath:tempPath];
	}
	if ( ! self.progressView ) {
		self.progressView = [[VMAppDelegate defaultAppDelegate].viewController showProgressView];
	}
	
	bytesRead += data.length;
	NSLog(@"Download progress %lul/%lul",(unsigned long)bytesRead,(unsigned long)dataSize);
	
	if( dataSize > 0 ) {
		self.progressView.progress = (double)bytesRead / (double)dataSize;
	} else {
		self.progressView.progress = 0;
	}
	[self.localFile writeData:data];
}
	
- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
	[self finishDownload:NO];
}

- (void)finishDownload:(BOOL)downloadWasCancelled {
	[[VMAppDelegate defaultAppDelegate].viewController hideProgressView];
	self.progressView = nil;

	[self.localFile closeFile];		//	in case we have already started to write
	self.localFile = nil;
	
	BOOL isDirectory;
	if( [[NSFileManager defaultManager] fileExistsAtPath:[self dataDirectory] isDirectory:&isDirectory] ) {
		if( isDirectory && downloadWasCancelled ) {
			//	no need to unzip
			NSLog(@"No need to unzip");
			[self.delegate vmsarcLoaded];
			return;
		}
	}
	
	[[NSFileManager defaultManager] removeItemAtPath:[self dataDirectory] error:nil];
	
	NSLog(@"Unzip vmsarc");
	
	if( ! [SSZipArchive unzipFileAtPath:[self zippedDataPath] toDestination:[self applicationDocumentsDirectory].path] ) {
		UIAlertView *av = [[UIAlertView alloc] initWithTitle:@"Error"
													 message:@"Could not decompress file"
													delegate:self
										   cancelButtonTitle:@"OK"
										   otherButtonTitles:nil];
		[av show];
		[av release];
		[[NSFileManager defaultManager] removeItemAtPath:[self dataDirectory] error:nil];
		[self.delegate vmsarcLoadingFailed];
		return;
	}
	[self setPropertyOfCurrentVMS:VMSCacheKey_Downloaded to:[NSDateFormatter localizedStringFromDate:[NSDate date] dateStyle:NSDateFormatterShortStyle timeStyle:NSDateFormatterShortStyle]];
	[self.delegate vmsarcLoaded];
}
		
	
@end

//
//  VariableSong.m
//  c
//
//  Created by cboy on 12/11/01.
//  Copyright 2012 sumiisan@gmail.com. All rights reserved.
//

#import "VariableSong.h"
#import "VMPreprocessor.h"
#import "VMSong.h"
//#import "CJSONDeserializer.h"
//#import "JSONifier.h"


@implementation VariableSong
@synthesize song;

- (id)init
{
    self = [super init];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}

- (void)dealloc
{
    [song release];
    [super dealloc];
}

- (NSString *)windowNibName
{
    // Implement this to return a nib to load OR implement -makeWindowControllers to manually create your controllers.
    return @"Variable Song";
}


- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError
{
    // Insert code here to write your document to data of the specified type. If the given outError != NULL, ensure that you set *outError when returning nil.

    // You can also choose to override -fileWrapperOfType:error:, -writeToURL:ofType:error:, or -writeToURL:ofType:forSaveOperation:originalContentsURL:error: instead.

    // For applications targeted for Panther or earlier systems, you should use the deprecated API -dataRepresentationOfType:. In this case you can also choose to override -fileWrapperRepresentationOfType: or -writeToFile:ofType: instead.

    return nil;
}


#ifdef VMP_MOBILE
- (BOOL)loadFromContents:(id)contents ofType:(NSString *)typeName error:(NSError **)outError {

    return [self readFromData:(NSData *)contents ofType:typeName error:outError];
}
#endif

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError {
    // Insert code here to read your document from the given data of the specified type.  If the given outError != NULL, ensure that you set *outError when returning NO.

    // You can also choose to override -readFromFileWrapper:ofType:error: or -readFromURL:ofType:error: instead. 
    
    // For applications targeted for Panther or earlier systems, you should use the deprecated API -loadDataRepresentation:ofType. In this case you can also choose to override -readFromFile:ofType: or -loadFileWrapperRepresentation:ofType: instead.
    NSString *vmsText = [[NSString alloc] initWithData:data encoding:vmFileEncoding];
	assert(vmsText);
	song = DEFAULTSONG;
	[VMPreprocessor defaultPreprocessor].song = song;
	 
	[[VMPreprocessor defaultPreprocessor] preprocess:vmsText];
	
	[vmsText release];
    return YES;
}

- (BOOL)readFromURL:(NSURL *)url ofType:(NSString *)type error:(NSError **)outError {
    NSData *data = [NSData dataWithContentsOfURL:url options:NSDataReadingUncached error:outError];
    return [self readFromData:data ofType:@"vs" error:outError];
}

@end

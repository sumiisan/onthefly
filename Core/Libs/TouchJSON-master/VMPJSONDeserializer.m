//
//  VMPJSONDeserializer.m
//

#import "VMPJSONDeserializer.h"
#import "VMPJSONScanner.h"

@implementation VMPJSONDeserializer

- (void)dealloc
    {
    [scanner release];
    scanner = NULL;
    //
    [super dealloc];
    }

#pragma mark -

- (CJSONScanner *)scanner	//	override
    {
    if (scanner == NULL)
        {
        scanner = [[VMPJSONScanner alloc] init];		//	initialize with VMPJSONScanner
        }
    return(scanner);
    }

- (id)deserializeAsDictionary:(NSData *)inData error:(NSError **)outError	//	override
    {
    if (inData == NULL || [inData length] == 0)
        {
        if (outError)
            *outError = [NSError errorWithDomain:kJSONDeserializerErrorDomain code:kJSONScannerErrorCode_NothingToScan userInfo:NULL];

        return(NULL);
        }
    if ([self.scanner setData:inData error:outError] == NO)
        {
        return(NULL);
        }
    NSDictionary *theDictionary = NULL;
	[self.scanner skipWhitespace];	//	added ss122117
    if ([self.scanner scanJSONDictionary:&theDictionary error:outError] == YES)
        return(theDictionary);
    else
        return(NULL);
    }
@end

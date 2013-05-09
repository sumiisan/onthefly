//
//  VMPJSONScanner.h
//  

#import "CDataScanner.h"
#import "CJSONScanner.h"

@interface VMPJSONScanner : CJSONScanner
@property (nonatomic, retain) NSString *lastKey;
@end
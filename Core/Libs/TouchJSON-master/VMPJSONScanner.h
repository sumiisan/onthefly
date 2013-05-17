//
//  VMPJSONScanner.h
//  

#import "CDataScanner.h"
#import "CJSONScanner.h"
#import "VMARC.h"


@interface VMPJSONScanner : CJSONScanner
@property (nonatomic, VMStrong) NSString *lastKey;
@end
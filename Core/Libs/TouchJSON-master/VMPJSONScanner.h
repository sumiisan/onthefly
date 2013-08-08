//
//  VMPJSONScanner.h
//  

#import "CDataScanner.h"
#import "CJSONScanner.h"
#import "VMARC.h"


@interface VMPJSONScanner : CJSONScanner {
	NSString *lastKey_;
}
@property (nonatomic, VMStrong) NSString *lastKey;
@end
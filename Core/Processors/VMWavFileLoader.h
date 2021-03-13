//
//  VMWavFileLoader.h
//  OnTheFly Editor OSX
//
//  Created by cboy mbp m1 on 2021/03/11.
//

@import Foundation;
#import "VMDataTypes.h"

NS_ASSUME_NONNULL_BEGIN

@interface VMWavFileLoader : NSObject
- (void)open:(NSURL*)url;
@end

NS_ASSUME_NONNULL_END

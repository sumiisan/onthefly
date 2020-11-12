//
//  NSRegularExpression+String.h
//  OnTheFly
//
//  Created by CBoy on 2020/11/10.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSRegularExpression (String)

- (NSArray*)arrayOfCaptureComponentsMatchIn:(NSString*)string;

@end

NS_ASSUME_NONNULL_END

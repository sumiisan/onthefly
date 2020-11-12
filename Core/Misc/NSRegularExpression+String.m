//
//  NSRegularExpression+String.m
//  OnTheFly
//
//  Created by CBoy on 2020/11/10.
//

#import "NSRegularExpression+String.h"

@implementation NSRegularExpression (String)

- (NSArray*)arrayOfCaptureComponentsMatchIn:(NSString*)string {
  NSTextCheckingResult *match = [self firstMatchInString:string options:NSRegularExpressionSearch range:NSMakeRange(0, string.length)];
  NSMutableArray *result = [NSMutableArray array];
  for (int i = 0; i < match.numberOfRanges; ++i) {
    NSRange matchRange = [match rangeAtIndex:i];
    NSString *matchStr = nil;
    if(matchRange.location != NSNotFound) {
        matchStr = [string substringWithRange:matchRange];
    } else {
        matchStr = @"";
    }
    [result addObject:matchStr];
  }
  return result;
}


/* regexkit's method rewritten using NSRegularExpression
 
- (NSArray *) arrayOfCaptureComponentsOfString:(NSString *)data matchedByRegex:(NSString *)regex {
    NSError *error = NULL;
    NSRegularExpression *regExpression = [NSRegularExpression regularExpressionWithPattern:regex options:NSRegularExpressionCaseInsensitive error:&error];
    
    NSMutableArray *test = [NSMutableArray array];
    
    NSArray *matches = [regExpression matchesInString:data options:NSRegularExpressionSearch range:NSMakeRange(0, data.length)];
    
    for(NSTextCheckingResult *match in matches) {
        NSMutableArray *result = [NSMutableArray arrayWithCapacity:match.numberOfRanges];
        for(NSInteger i=0; i<match.numberOfRanges; i++) {
            NSRange matchRange = [match rangeAtIndex:i];
            NSString *matchStr = nil;
            if(matchRange.location != NSNotFound) {
                matchStr = [data substringWithRange:matchRange];
            } else {
                matchStr = @"";
            }
            [result addObject:matchStr];
        }
        [test addObject:result];
    }
    return test;
}
 */

@end

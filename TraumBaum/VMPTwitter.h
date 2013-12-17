//
//  VMPTwitter.h
//  OnTheFly
//
//  Created by sumiisan on 2013/11/27.
//
//

//#import <Foundation/Foundation.h>
#import "VMPMultiLanguage.h"

#define TWITTERTIMELINEFETCHED_NOTIFICATION @"vmpTwitterTimelineFetched"


@interface VMPTwitter : NSObject
- (void)fetchTLforUser:(NSString *)username language:(VMPLanguageCode)languageCode;

@property (nonatomic, retain) NSDictionary *timelineData;
@end

//
//  VMPDeviceSettings.h
//  OnTheFly
//
//  Created by sumiisan on 2013/11/27.
//
//

#import <Foundation/Foundation.h>

typedef enum {
	VMPLanguageCode_english = 0,
	VMPLanguageCode_japanese,
	VMPLanguageCode_german,
	VMPLanguageCode_french,
	VMPLanguageCode_spanish
} VMPLanguageCode;

@interface VMPMultiLanguage : NSObject


+ (NSString*)language;
+ (VMPLanguageCode)languageCode;
+ (NSString*)reallyRestartMessage;
+ (NSString*)oopsMessage;
+ (NSString*)needUpdateMessage;
+ (NSString*)yesString;
+ (NSString*)noString;
+ (NSString*)confirmTitle;
+ (NSString*)songlistTitle;
	+ (NSString*)updateArchiveMessage;
	+ (NSString*)downloadingMessage;

@end

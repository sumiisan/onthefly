//
//  VMPDeviceSettings.m
//  OnTheFly
//
//  Created by sumiisan on 2013/11/27.
//
//

#import "VMPMultiLanguage.h"

@implementation VMPMultiLanguage


+ (NSString*)confirmTitle {
	NSDictionary *m = [NSDictionary dictionaryWithObjectsAndKeys:
					   @"Confirmation",@"en",
					   @"確認",@"ja",
					   @"Bestätigung",@"de",
					   @"Confirmation",@"fr",
					   @"Confirmación",@"es",
					   nil];
	return [m objectForKey:[self language]];
}

+ (NSString*)yesString {
	NSDictionary *m = [NSDictionary dictionaryWithObjectsAndKeys:
					   @"Yes",@"en",
					   @"はい",@"ja",
					   @"Ja",@"de",
					   @"Oui",@"fr",
					   @"Sí",@"es",
					   nil];
	return [m objectForKey:[self language]];
}


+ (NSString*)noString {
	NSDictionary *m = [NSDictionary dictionaryWithObjectsAndKeys:
					   @"No",@"en",
					   @"いいえ",@"ja",
					   @"Nein",@"de",
					   @"Non",@"fr",
					   @"No",@"es",
					   nil];
	return [m objectForKey:[self language]];
}

+ (NSString*)reallyRestartMessage {
	NSDictionary *m = [NSDictionary dictionaryWithObjectsAndKeys:
					   @"Do you really want to reset?",@"en",
					   @"本当にリセットしますか？",@"ja",
					   @"Wollen Sie wirklich neustarten?",@"de",
					   @"Voulez-vous vraiment réinitialiser?",@"fr",
					   @"Realmente desea reiniciar?",@"es",
					   nil];
	return [m objectForKey:[self language]];
}

+ (VMPLanguageCode)languageCode {
	NSString *l = [VMPMultiLanguage language];
	if ( [l isEqualToString:@"en" ] )
		return VMPLanguageCode_english;
	if ( [l isEqualToString:@"ja" ] )
		return VMPLanguageCode_japanese;
	if ( [l isEqualToString:@"de" ] )
		return VMPLanguageCode_german;
	if ( [l isEqualToString:@"fr" ] )
		return VMPLanguageCode_french;
	if ( [l isEqualToString:@"es" ] )
		return VMPLanguageCode_spanish;
	
	return VMPLanguageCode_english;
}

+ (NSString*)language {
	return [[[NSBundle mainBundle] preferredLocalizations] objectAtIndex:0];
	/*
	 
	 en
	 ja
	 de
	 fr
	 es
	 
	 
	 */
}
@end

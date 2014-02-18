//
//  VMPDeviceSettings.m
//  OnTheFly
//
//  Created by sumiisan on 2013/11/27.
//
//

#import "VMPMultiLanguage.h"

@implementation VMPMultiLanguage

+ (NSString*)songlistTitle {
	NSDictionary *m = [NSDictionary dictionaryWithObjectsAndKeys:
					   @"Song List",@"en",
					   @"曲のリスト",@"ja",
					   @"Song-Liste",@"de",
					   @"Liste de Plages Musicales",@"fr",
					   @"Lista de Canciones",@"es",
					   nil];
	return [m objectForKey:[self language]];
}
	
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

+ (NSString*)oopsMessage {
	NSDictionary *m = [NSDictionary dictionaryWithObjectsAndKeys:
					   @"Oops!",@"en",
					   @"あれま!",@"ja",
					   @"Hoppla!",@"de",
					   @"Oups!",@"fr",
					   @"¡Vaya!",@"es",
					   nil];
	return [m objectForKey:[self language]];
}

+ (NSString*)needUpdateMessage {
	NSDictionary *m = [NSDictionary dictionaryWithObjectsAndKeys:
					   @"Please update the app to latest version.",@"en",
					   @"アプリを最新バージョンにアップデートしてください。",@"ja",
					   @"Bitte aktualisieren Sie die App auf neueste Version.",@"de",
					   @"S'il vous plaît mettre à jour l'application à la dernière version.",@"fr",
					   @"Por favor, actualice la aplicación a la última versión.",@"es",
					   nil];
	return [m objectForKey:[self language]];
}
	
+ (NSString*)updateArchiveMessage {
	NSDictionary *m = [NSDictionary dictionaryWithObjectsAndKeys:
					   @"Download New Version",@"en",
					   @"新しいバージョンをダウンロードする",@"ja",
					   @"Neue Version Herunterladen",@"de",
					   @"Télécharger la Nouvelle Version",@"fr",
					   @"Descarga la Nueva Versión",@"es",
					   nil];
	return [m objectForKey:[self language]];
}

+ (NSString*)downloadingMessage {
	NSDictionary *m = [NSDictionary dictionaryWithObjectsAndKeys:
					   @"downloading vms archive...",@"en",
					   @"vmsアーカイブをダウンロード中...",@"ja",
					   @"vms Archiv herunterladen...",@"de",
					   @"téléchargeons archive de vms...",@"fr",
					   @"descargando archivo de vms...",@"es",
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
	NSArray *supportedLanguages = [NSArray arrayWithObjects:
								   @"en",
								   @"ja",
								   @"de",
								   @"fr",
								   @"es",
								   nil];
	
	NSArray *localizations = [[NSBundle mainBundle] preferredLocalizations];
	
	//
	//	find out the first supported language from preferred localization
	//
	for( NSString *localization in localizations ) {
		for( NSString *lang in supportedLanguages ) {
			if ( [localization isEqualToString:lang] ) {
				return localization;
			}
		}
	}
	
	
	return @"en";
}
@end

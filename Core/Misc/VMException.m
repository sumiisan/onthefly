//
//  VMException.m
//  OnTheFly
//
//  Created by  on 13/02/04.
//  Copyright (c) 2013 sumiisan. All rights reserved.
//

#import "VMException.h"
#import "MultiPlatform.h"
#if VMP_EDITOR
#import "VMPlayerOSXDelegate.h"
#import "VMPNotification.h"
#endif
#import "VMPMacros.h"

@implementation VMException

/*---------------------------------------------------------------------------------
 *
 *
 *	VM Exception
 *
 *
 *---------------------------------------------------------------------------------*/

#define parseMessageFromArg(containerDeclaration) \
va_list args;\
va_start(args, format);\
containerDeclaration = AutoRelease([[NSString alloc] initWithFormat:format arguments:args]);\
va_end(args)



+ (void)logError:(NSString*)name format:(NSString *)format, ... {
	//
	// only OSX supported.
	//	maybe we can use notification on iOS
	//
#if VMP_EDITOR
	parseMessageFromArg(NSString *message);
	
	[APPDELEGATE.systemLog logError:message withData:nil];
	[VMPNotificationCenter postNotificationName:VMPNotificationLogAdded
										 object:self
									   userInfo:@{@"owner":@( VMLogOwner_System )}];
#endif
}


+ (void)raise:(NSString *)name format:(NSString *)format, ... {
	parseMessageFromArg(NSString *message);
	
#if VMP_OSX
	NSAlert *al = [NSAlert alertWithMessageText:name 
								 defaultButton:@"OK" 
							   alternateButton:nil
								   otherButton:nil
					 informativeTextWithFormat:@"%@",message];
	[al runModal];
#else
    UIAlertView *al = [[[UIAlertView alloc] initWithTitle:name message:message delegate:nil cancelButtonTitle:nil otherButtonTitles: nil] autorelease];
    [al show];
    
#endif

	LLog(@"%@",message);
	
#ifdef DEBUG
	va_start(args, format);
	[super raise:name format:format arguments:args];
	va_end(args);
#endif
	
#if VMP_OSX
	[NSApp terminate:self];
#endif
}

+ (void)alert:(NSString *)format, ...  {
	parseMessageFromArg(NSString *message);
	LLog(@"%@",message);
#if VMP_OSX
	NSAlert *al = [NSAlert alertWithMessageText:@"Alert:"
								  defaultButton:@"OK"
								alternateButton:nil
									otherButton:nil
					  informativeTextWithFormat:@"%@",message];
	[al runModal];
#else
	UIAlertView * av = [[UIAlertView alloc] initWithTitle:@"Alert:"
												  message:message
												 delegate:nil
										cancelButtonTitle:nil
										otherButtonTitles:nil ];
	[av show];
#endif
}

+ (void)alert:(NSString *)name format:(NSString*)format, ...  {
	parseMessageFromArg(NSString *message);
	LLog(@"%@ %@",name, message);

#if VMP_OSX
	NSAlert *al = [NSAlert alertWithMessageText:name
								  defaultButton:@"OK"
								alternateButton:nil
									otherButton:nil
					  informativeTextWithFormat:@"%@",message];
	[al runModal];
#else
	UIAlertView * av = [[UIAlertView alloc] initWithTitle:name
												  message:message
												 delegate:nil
										cancelButtonTitle:nil
										otherButtonTitles:nil ];
	[av show];
#endif
}

#if VMP_OSX
static NSTextView *textViewForSpeak_static_ = nil;
#endif

+ (void)speak:(NSString*)message {
#if VMP_OSX
	if ( ! textViewForSpeak_static_ ) textViewForSpeak_static_ = [[NSTextView alloc] init];
	textViewForSpeak_static_.string = message;
	[textViewForSpeak_static_ startSpeaking:self];
#endif
}

//	on iOS, this method always return NO - hook up delegate ... implement LATER
+ (BOOL)ensure:(NSString *)format, ...  {
	parseMessageFromArg(NSString *message);

#if VMP_OSX
	NSAlert *al = [NSAlert alertWithMessageText:@"Confirm:"
								  defaultButton:@"Cancel"
								alternateButton:@"OK"
									otherButton:nil
					  informativeTextWithFormat:@"%@",message];
	NSInteger result = [al runModal];
	
	return result==1;
#else
	UIAlertView * av = [[UIAlertView alloc] initWithTitle:@"Confirm"
												  message:message
												 delegate:nil
										cancelButtonTitle:@"Cancel"
										otherButtonTitles:nil ];
	[av show];
	return NO;
#endif
}

#if VMP_IPHONE 
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
	BOOL canceled __unused = ( buttonIndex == alertView.cancelButtonIndex );
	
}
#endif



@end

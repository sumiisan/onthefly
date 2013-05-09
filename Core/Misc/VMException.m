//
//  VMException.m
//  OnTheFly
//
//  Created by  on 13/02/04.
//  Copyright (c) 2013 __MyCompanyName__. All rights reserved.
//

#import "VMException.h"
#import "MultiPlatform.h"

@implementation VMException


+ (void)raise:(NSString *)name format:(NSString *)format, ... {
	va_list args;
	va_start(args, format);
	NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
	va_end(args);
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

	
#ifdef DEBUG
	NSLog(@"%@\n%@",name,message);
	va_start(args, format);
	[super raise:name format:format arguments:args];
	va_end(args);
#endif
	[message release];
	
#if VMP_OSX
	[NSApp terminate:self];
#endif
}

+ (void)alert:(NSString*)message {
	NSAlert *al = [NSAlert alertWithMessageText:@"Alert:"
								  defaultButton:@"OK"
								alternateButton:nil
									otherButton:nil
					  informativeTextWithFormat:@"%@",message];
	[al runModal];
}

+ (BOOL)ensure:(NSString*)message {
	NSAlert *al = [NSAlert alertWithMessageText:@"Confirm:"
								  defaultButton:@"Cancel"
								alternateButton:@"OK"
									otherButton:nil
					  informativeTextWithFormat:@"%@",message];
	NSInteger result = [al runModal];
	
	NSLog(@"alert result:%ld",result);
	return result==1;
}



@end

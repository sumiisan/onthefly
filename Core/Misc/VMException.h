//
//  VMException.h
//  OnTheFly
//
//  Created by  on 13/02/04.
//  Copyright (c) 2013 sumiisan. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MultiPlatform.h"

@interface VMException : NSException
#if VMP_OSX
	<NSAlertDelegate>
#else
	<UIAlertViewDelegate>
#endif
+ (BOOL)ensure:(NSString *)format, ...;	//	not actually an exception. maybe make a separate class later.
+ (void)alert:(NSString *)format, ...;
+ (void)alert:(NSString *)name format:(NSString*)format, ...;

//	override
+ (void)raise:(NSString *)name format:(NSString *)format, ...;
+ (void)logError:(NSString*)name format:(NSString *)format, ...;

@end

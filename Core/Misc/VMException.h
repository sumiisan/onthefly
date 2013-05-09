//
//  VMException.h
//  OnTheFly
//
//  Created by  on 13/02/04.
//  Copyright (c) 2013 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface VMException : NSException <NSAlertDelegate>
+ (BOOL)ensure:(NSString*)message;	//	not actually an exception. maybe make a separate class later.
+ (void)alert:(NSString*)message;

//	overridw
+ (void)raise:(NSString *)name format:(NSString *)format, ... ;
@end

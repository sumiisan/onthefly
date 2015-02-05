//
//  VMTextPreprocessor.h
//  VariableMusicPlayer
//
//  Created by cboy on 12/11/03.
//  Copyright 2012 sumiisan (sumiisan.com). All rights reserved.
//

#import <Foundation/Foundation.h>
#import "VMPrimitives.h"

@interface VMTextPreprocessor : NSObject

+ (void)replaceKeyNamesIn:(NSMutableString*)data with:(VMHash*)table;
+ (void)stripCommentsAndCRLF:(NSMutableString*)data;
+ (void)putPropertyNames:(VMArray*)propNames IntoDoubleQuote:(NSMutableString*)data;
@end

//
//  VMTextPreprocessor.m
//  VariableMusicPlayer
//
//  Created by cboy on 12/11/03.
//  Copyright 2012 sumiisan (aframasda.com). All rights reserved.
//

#import "VMTextPreprocessor.h"
#import "RegexKitLite.h"

@implementation VMTextPreprocessor

+ (void)replaceKeyNamesIn:(NSMutableString*)data with:(VMHash*)table {
	VMArray *keys = [table keys];
	for( NSString *key in keys ) {
        [data replaceOccurrencesOfRegex:[NSString stringWithFormat:@"([,\\s\\{\\[])%@:",key] 
							 withString:[NSString stringWithFormat:@"$1%@:",[table item:key]]];
    }
}

+ (void)stripCommentsAndCRLF:(NSMutableString*)data {
	
	return;

	//
	//	not necessary with TouchJSON since TREAT_COMMENTS_AS_WHITESPACE is set in CJSONScanner.m 
	//
	
//    [data replaceOccurrencesOfRegex:@"//.*?\\n" withString:@" "];		//  strip comments(1)	//
//    [data replaceOccurrencesOfRegex:@"\r\n|\n|\r" withString:@" "]; 	//	strip CR/LF//
//    [data replaceOccurrencesOfRegex:@"/\\*.*?\\*/" withString:@""];  	//  strip comments(2) /* */
}

+ (void)putPropertyNames:(VMArray*)propNames IntoDoubleQuote:(NSMutableString*)data {
    for( NSString *p in propNames ) {   //  put prop names into ""
        [data replaceOccurrencesOfRegex:[NSString stringWithFormat:@"\\s%@:",p] 
							 withString:[NSString stringWithFormat:@" \"%@\":",p]];
    }
	[data replaceOccurrencesOfRegex:@"\t" withString:@""]; 		//	strip TAB
}


- (id)init {
    self = [super init];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}

- (void)dealloc
{
    [super dealloc];
}

@end

//
//  VMRouteComputer.h
//  OnTheFly
//
//  Created by sumiisan on 2013/12/18.
//
//

#import <Foundation/Foundation.h>
#import "VMDataTypes.h"

@interface VMRouteComputer : NSObject

	- (void)recollectPrecedents;
	- (VMArray*)precedentOfFragment:(VMId*)fragId;
	
@end

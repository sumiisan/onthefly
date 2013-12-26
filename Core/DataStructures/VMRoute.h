//
//  VMRoute.h
//  OnTheFly
//
//  Created by sumiisan on 2013/12/21.
//
//

#import <Foundation/Foundation.h>
#import "VMPrimitives.h"
#import "VMDataTypes.h"

@interface VMRoute : NSObject
@property (nonatomic, retain)	VMId	*id;
@property (nonatomic, retain)	VMArray	*route;
@property (nonatomic)			VMTime	length;

+ (VMRoute*)routeWithId:(VMId*)fragId;
- (void)addFragment:(VMFragment*)fragment;
@end

//
//  VMRoute.m
//  OnTheFly
//
//  Created by sumiisan on 2013/12/21.
//
//

#import "VMRoute.h"
#import "VMDataTypes.h"
#import "VMPMacros.h"

/*---------------------------------------------------------------------------------
 
 VMRoute
 
 ----------------------------------------------------------------------------------*/

#pragma mark - VMPRoute

@implementation VMRoute
- (id)initWithId:(VMId*)fragId {
	self = [super init];
	if ( ! self ) return nil;
	self.id = fragId;
	self.route = ARInstance( VMArray );
	return self;
}

- (void)dealloc {
	VMNullify( id );
	VMNullify( route );
	Dealloc(super);
}

- (void)addFragment:(VMFragment *)fragment {
	[self.route push:fragment.id];
	//	self.length += fragment;
}

+ (VMRoute*)routeWithId:(NSString *)fragId {
	return AutoRelease([[VMRoute alloc] initWithId:fragId]);
}
@end

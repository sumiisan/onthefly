//
//  VMRouteComputer.m
//  OnTheFly
//
//  Created by sumiisan on 2013/12/18.
//
//

#import "VMRoute.h"
#import "VMRouteComputer.h"
#import "VMSong.h"
#import "MultiPlatform.h"
#import "VMPMacros.h"


/*---------------------------------------------------------------------------------
 
 VMPRouteComputer
 
 ----------------------------------------------------------------------------------*/
#pragma mark - VMPRouteComputer

@interface VMRouteComputer()
	@property (nonatomic, retain)	VMHash  *distanceOfFragment;
	@property (nonatomic, retain)	VMStack *routeStack;
	@property (nonatomic, retain)	VMHash	*precedents;
@end


@implementation VMRouteComputer
	

	@synthesize routeStack=routeStack_, distanceOfFragment=distanceOfFragment_;
	@synthesize precedents=precedents_;
	

	
	//
	//	collect referrer for all fragments
	//
	
	
	
			
	- (void)recollectPrecedents {
		VMArray *idList	= [DEFAULTSONG.songData keys];
		self.precedents = ARInstance(VMHash);
		
		for( VMId* dataId in idList ) {
			VMData *data = [DEFAULTSONG.songData item:dataId];
			VMInt c;
			switch ( (int)data.type) {
				case vmObjectType_sequence: {
					c = ((VMSequence*)data).subsequent.length;
					for ( int i = 0; i < c; ++i ) {
						VMFragment *target = [((VMSequence*)data).subsequent fragmentAtIndex:i];
						if ( ![target.id isEqualToString:@"*"] ) {
							VMHash *precedentOfFragment = [precedents_ itemAsHash:target.id];
							if ( ! precedentOfFragment ) {
								precedentOfFragment = ARInstance(VMHash);
								[precedents_ setItem:precedentOfFragment for:target.id];
							}
							[precedentOfFragment setItem:@(YES) for:dataId];\
						}
					}
					break;
				}
				case vmObjectType_selector: {
					c = ((VMSelector*)data).fragments.count;
					for ( int i = 0; i < c; ++i ) {
						VMFragment *target = [((VMSequence*)data).subsequent fragmentAtIndex:i];
						if ( ![target.id isEqualToString:@"*"] ) {
							VMHash *precedentOfFragment = [precedents_ itemAsHash:target.id];
							if ( ! precedentOfFragment ) {
								precedentOfFragment = ARInstance(VMHash);
								[precedents_ setItem:precedentOfFragment for:target.id];
							}
							[precedentOfFragment setItem:@(YES) for:dataId];\
						}
					}
					break;
				}
			}
		}
	}

	//
	//	referrer
	//
	
	- (VMArray*)precedentOfFragment:(VMId *)fragId {
		return [precedents_ item:fragId];
	}
	
	//
	//	compute!
	//
	- (void)computeRouteFrom:(VMId*)startId to:(VMId*)destinationId {
		self.routeStack = ARInstance(VMStack);
		self.distanceOfFragment = ARInstance(VMHash);
		[routeStack_ push:[VMRoute routeWithId:startId]];
		while( routeStack_.count > 0 ) {
			VMRoute *route = [self routeTo:destinationId];
			if ( route )
				break;
		}
		
	}
		
	- (VMRoute *)routeTo:(VMId*)needle {
		VMRoute *route = nil;
		VMHash *nextIdList = ARInstance(VMHash);
		for( VMRoute *route1 in routeStack_ ) {
			if ( [needle isEqualToString:route1.id] ) {
				return route1;
			} else {
				VMRoute *route2 = [distanceOfFragment_ item:route.id ];
				if( route2 && route2.length > route1.length ) {
					//
					//	if there is a longer route in cache ... replace it.
					//
					[distanceOfFragment_ setItem:route1 for:route.id];
				}
				VMArray *precedentList = [self precedentOfFragment:route.id];
				for( VMData *referrerId in precedentList ) {
					[nextIdList setItem:VMBoolObj(YES) for:referrerId];
				}
			}
		}
		
		return route;
	}
	
	
	- (id)init {
		self = [super init];
		if ( !self ) return nil;
		[self recollectPrecedents];
		return self;
	}
	
	- (void)dealloc {
		VMNullify(routeStack);
		VMNullify(distanceOfFragment);
		VMNullify(precedents);
		Dealloc(super);
	}

@end

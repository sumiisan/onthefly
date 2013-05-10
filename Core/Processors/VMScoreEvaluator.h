//
//  ScoreEvaluator.h
//  OnTheFly
//
//  Created by  on 13/02/02.
//  Copyright (c) 2013 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "VMPrimitives.h"
#import "VMDataTypes.h"
#import "MultiPlatform.h"

enum {
	vmOperatorType_undefined = 0,
	vmOperatorType_equal,
	vmOperatorType_notequal,
	vmOperatorType_add,
	vmOperatorType_subtract,
	vmOperatorType_multiply,
	vmOperatorType_divide,
	vmOperatorType_modulo,
	vmOperatorType_grater,
	vmOperatorType_less,
	vmOperatorType_graterOrEqual,
	vmOperatorType_lessOrEqual,
	vmOperatorType_leftParent,
	vmOperatorType_rightParent,
	vmOperatorType_and,
	vmOperatorType_or,
	vmOperatorType_not,
};

enum  {
	vmSEFunction_LC,
	vmSEFunction_LS,
	vmSEFunction_F,
	vmSEFunction_D
};

#define DEFAULTEVALUATOR [VMScoreEvaluator defaultEvaluator]

@interface VMScoreEvaluator : NSObject {
	BOOL	trackingPathIsReturning;
}

+ (VMScoreEvaluator*)defaultEvaluator;
- (VMFloat)evaluate:(NSString*)expression;

/**
 special variables and functions ( in consideration )
 variables are set by the environment before evaluation
 functions() are evaluated dynamically
 
name		description											responsible setter		implemented
 @A			current audio frag 's id								song					YES
 @ABS(x)	|x|																			NO
 @C			parent selector's playback counter 					parent selector			YES
 @COS(x)	x = 0..1																	NO
 @D			alias for @D{@T}															YES
 @D{id}		distance to last appearance of fragId in frames								YES
 @DC		alias for @DC(@T)															NO
 @DC{id}	1 - ( 1 / @D{id} )			( for dist n = 0, 0.5, 0.666667, 0.75, 			NO
 @Eg		number of played frags since the first launch 		song					NO
 @Ec		number of played frags since launched this time		song					NO
 @Eh		hours played										song					NO
 @ID		id of caller VMData object							data					YES
 @F{x}		1 if the last fragId was x, otherwise 0				-						YES
 @INT(x)	(int)x												-						NO
 @L			last audio frag's id									song					NO
 @LL		audio frag before last audio frag -'s id				song					NO
 @LS		alias for @LS{@T}														YES
 @LS{id}	distance to last selection (inside selector) of fragId in frames				NO
 @LC		alias for @LC{@T}									parent selector			YES
 @LC{id}	1 - ( 1 / @LS{id} )			( for dist n = 0, 0.5, 0.666667, 0.75, 			NO
 @MAX(x,y)																				NO
 @MIN(x,y)																				NO
 @NEG(x)	(0-x)																		NO
 @RCP(x)	(1/x)																		NO
 @RU		uniform random value 0..1							scoreEvaluator			NO
 @RS		uniform random value 0 or 1							scoreEvaluator			NO
 @RG		gaussian random value (sigma = 3)					scoreEvaluator			NO 
 @T			target of caller VMChance object					chance					YES
 @TYPE		type of caller VMData object						data					YES
 
 
internal
 @selectorHistory	used for evaluating LAST,LC
 */
- (VMArray*)parseFunction:(VMString*)expression;	//	made public for test purpose.

- (void)setFragmentId:(VMId*)fragId;
- (void)setValue:(id)value forVariable:(VMString*)variableName;
- (id)valueForVariable:(VMString*)variableName;

- (VMFloat)primaryFactor:(VMString*)scoreDescriptor;
- (VMString*)setPrimaryFactor:(VMFloat)value forDescriptor:(VMString*)scoreDescriptor;
- (void)reset;

//	resolvepath related
- (id)resolveDataWithTracking:(VMData*)data toType:(int)type;
- (void)trackObjectOnResolvePath:(id)data;

@property	(nonatomic,	retain)		NSNumberFormatter	*numberFormatter;
@property	(VMNonatomic retain)	VMHash				*variables;
@property	(VMNonatomic retain)	VMArray				*pathTrackerArray;


@property	(VMNonatomic retain)	VMArray				*objectsWaitingToBeProcessed;
@property	(retain)				VMArray				*objectsWaitingToBeLogged;


@property	(nonatomic, getter = isTestMode)	BOOL	testMode;
@property	(nonatomic)							BOOL	shouldNotify;
@property	(nonatomic)							BOOL	shouldLog;


@end

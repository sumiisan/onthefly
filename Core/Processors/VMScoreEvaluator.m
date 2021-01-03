//
//  ScoreEvaluator.m
//  OnTheFly
//
//  Created by  on 13/02/02.
//  Copyright (c) 2013 sumiisan. All rights reserved.
//

/*
 TODO:	maybe implement operator precedence
 1:	eval *,/ and %
 2:	eval +,-
 3:	eval =,!=,<,>,>=,<=
 4:	eval &,|
 */

#import "MultiPlatform.h"
#import "VMPMacros.h"

#import "VMScoreEvaluator.h"
#import "VMSong.h"
#import "VMPSongPlayer.h"
#import "VMException.h"
#import "VMPNotification.h"
#import "NSRegularExpression+String.h"

@implementation VMScoreEvaluator

static VMHash *operatorTable_static_ = nil;
static VMHash *seFunctionTable_static_ = nil;
static BOOL verbose = NO;

@synthesize numberFormatter=numberFormatter_;
@synthesize variables=variables_, pathTrackerArray=pathTrackerArray_, testMode=testMode_;
@synthesize objectsWaitingToBeProcessed=objectsWaitingToBeProcessed_, objectsWaitingToBeLogged=objectsWaitingToBeLogged_,
shouldLog=shouldLog_,shouldNotify=shouldNotify_;
@synthesize timeManager = timeManager_;

#define BoolAsFloat(expr) ((expr)?1.:0.)
#define SetTypeForOp(type,string) VMIntObj( vmOperatorType_##type ),@"" string,
#define OperatorCase(type,_code_) case vmOperatorType_##type : { return _code_; }
	
#define SEFunctionMethod(type)			seFunction_##type
#define SEFunctionEntry(type)			[NSValue valueWithPointer:@selector( SEFunctionMethod(type): )],	@"" #type,
#define SEFunctionDefinition(type)		- (id)SEFunctionMethod(type):(id)parameter
	
	static VMScoreEvaluator *se_singleton_static_ = nil;
	
#pragma mark -
#pragma mark creation / termination
	
+ (VMScoreEvaluator*)defaultEvaluator {
	if ( ! se_singleton_static_ ) se_singleton_static_ = [[VMScoreEvaluator alloc] init];
	return se_singleton_static_;
}
	
- (id)init {
	if (( self = [super init] )) {
		self.numberFormatter = ARInstance(NSNumberFormatter);
		self.numberFormatter.locale	= AutoRelease([[NSLocale alloc] initWithLocaleIdentifier:@"ja_JA"] );
		
		if ( ! operatorTable_static_ )
		operatorTable_static_ = Retain([VMHash hashWithObjectsAndKeys:
										SetTypeForOp( equal, "=" )
										SetTypeForOp( notequal, "!=" )
										SetTypeForOp( add, "+" )
										SetTypeForOp( subtract, "-" )
										SetTypeForOp( multiply, "*" )
										SetTypeForOp( divide, "/" )
										SetTypeForOp( modulo, "%" )
										SetTypeForOp( grater, ">" )
										SetTypeForOp( less, "<" )
										SetTypeForOp( graterOrEqual, ">=" )
										SetTypeForOp( lessOrEqual, "<=" )
										SetTypeForOp( leftParent, "(" )
										SetTypeForOp( rightParent, ")" )
										SetTypeForOp( and, "&" )
										SetTypeForOp( or, "|" )
										SetTypeForOp( not, "!" )
										nil] );
		
		if ( ! seFunctionTable_static_ )
		seFunctionTable_static_ = Retain([VMHash hashWithObjectsAndKeys:
										  SEFunctionEntry( LC )
										  SEFunctionEntry( LS )
										  SEFunctionEntry( F )
										  SEFunctionEntry( D )
										  SEFunctionEntry( PT )
										  SEFunctionEntry( TN )
										  SEFunctionEntry( TD )
										  SEFunctionEntry( TS )
										  nil] );
		
		[self reset];
		
		self.timeManager = [[[VMPTimeManager alloc] init] autorelease];
		
		self.shouldLog = YES;
		self.shouldNotify = YES;
	}
	return self;
}
	
- (void)reset {
	self.variables 			= [VMHash hashWithObjectsAndKeys:	//	built in	constants
							   VMFloatObj(1e30f),	@"INF",		//	don't use INFINITY because it makes INF * 0 = nan
							   nil];
	self.pathTrackerArray	= ARInstance(VMArray);
}
	
- (void)dealloc {
	VMNullify(variables);
	VMNullify(timeManager);
	VMNullify(numberFormatter);
	VMNullify(pathTrackerArray);
	
	VMNullify(objectsWaitingToBeProcessed);
	VMNullify(objectsWaitingToBeLogged);
	
	Dealloc( super );;
}
	
#pragma mark -
#pragma mark internal methods
	
- (VMFloat)valueAsFloat:(NSString*)value {
	NSNumber *num =	[self.numberFormatter numberFromString:value];
	if (num) return [num floatValue];
	return NAN;
}
	
- (VMFloat)variableAsFloat:(VMString*)key {
	id obj = [self valueForVariable:key];
	if( ClassMatch(obj, NSNumber) )
	return [obj floatValue];
	return NAN;
}
	
- (VMFloat)evaluateSingleValue:(NSString *)value {
    VMFloat fv = [self valueAsFloat:value];
    if ( ! isnan(fv) ) return fv;
    return [self variableAsFloat:value];
}
	
- (VMFloat)evalOperator:(VMInt)opType withLvalue:(VMFloat)lvalue andRvalue:(VMFloat)rvalue {
	
	if( isnan(lvalue) || isnan(rvalue) ) return NAN;
	
	switch ( opType ) {
		OperatorCase( equal, 			BoolAsFloat( lvalue == rvalue ) )
		OperatorCase( notequal,			BoolAsFloat( lvalue != rvalue ) )
		OperatorCase( add, 				lvalue + rvalue )
		OperatorCase( subtract, 		lvalue - rvalue )
		OperatorCase( multiply, 		lvalue * rvalue )
		OperatorCase( divide, 			lvalue / rvalue )
		OperatorCase( modulo, 			fmodf( lvalue, rvalue ) )
		OperatorCase( grater, 			BoolAsFloat( lvalue > rvalue ) )
		OperatorCase( less, 			BoolAsFloat( lvalue < rvalue ) )
		OperatorCase( graterOrEqual, 	BoolAsFloat( lvalue >= rvalue ) )
		OperatorCase( lessOrEqual, 		BoolAsFloat( lvalue <= rvalue ) )
		OperatorCase( and,				BoolAsFloat( ( lvalue * rvalue ) != 0 ) )
		OperatorCase( or,				BoolAsFloat( ( lvalue != 0 ) || ( rvalue != 0 ) ) )
		OperatorCase( not,				BoolAsFloat( ( lvalue != 0 ) != ( rvalue != 0 ) ) )
	}
	return NAN;
}
	
- (VMArray*)dissolute:(VMString*)expression {
  NSError *error = nil;
  NSRegularExpression *regex = [NSRegularExpression
                                regularExpressionWithPattern:
                                @""
                                "^"              //  begin of expression
                                "("              //  $1 -->
                                "[^\\+\\-\\/\\*%><=&|!]"  //  not operator chars
                                "+"              //  match 1 or more times
                                ")"              //  $1 <--
                                "("              //  $2 -->
                                "[\\+\\-\\/\\*%><=&|!]"    //  operator chars
                                "*"              //  match 0 or more times
                                ")"              //  $2 <--
                                "("              //  $3 -->
                                "[^\\+\\-\\/\\*%><=&|!]"  //  not operator chars
                                "*"              //  match 0 or more times
                                ")"              //  $3 <--
                                "(.*)$"          //  everything else till end of expression: $4
                                options:0
                                error:&error];
  
  return [VMArray arrayWithObject:[regex arrayOfCaptureComponentsMatchIn:expression]];
/*
  NSTextCheckingResult *match = [regex firstMatchInString:expression options:0 range:NSMakeRange(0, expression.length)];
  NSMutableArray *result = [NSMutableArray array];
  for (int i = 0; i < match.numberOfRanges; ++i){
    [result addObject:[expression substringWithRange:[match rangeAtIndex:i]]];
  }
  
  return [VMArray arrayWithObject:result];
 */
  
  /*
	return [VMArray arrayWithArray:
			[expression arrayOfCaptureComponentsMatchedByRegex:
			 @""
			 "^"							//	begin of expression
			 "("							//	$1 -->
			 "[^\\+\\-\\/\\*%><=&|!]"	//	not operator chars
			 "+"							//	match 1 or more times
			 ")"							//	$1 <--
			 "("							//	$2 -->
			 "[\\+\\-\\/\\*%><=&|!]"		//	operator chars
			 "*"							//	match 0 or more times
			 ")"							//	$2 <--
			 "("							//	$3 -->
			 "[^\\+\\-\\/\\*%><=&|!]"	//	not operator chars
			 "*"							//	match 0 or more times
			 ")"							//	$3 <--
			 "(.*)$"						//	everything else till end of expression: $4
			 ]];
   */
}
	
- (VMArray*)parseFunction:(VMString*)expression {
  NSError *error = nil;
  
  NSRegularExpression *regex = [NSRegularExpression
                                regularExpressionWithPattern:@""
                                "^@"            //  begin of function
                                "("            //  $1 -->
                                "[A-Za-z0-9]"      //  function name
                                "+"            //  match 1 or more times
                                ")"            //  $1 <--
                                "\\{?"            //  { may appear
                                "("            //  $2 -->
                                "[^}]"        //  until }
                                "*"            //  match 0 or more times
                                ")"            //  $2 <--
                                "\\}?"            //  } may appear
                                "$"            //  end
                                options:0
                                error:&error];
  
  return [VMArray arrayWithObject:[regex arrayOfCaptureComponentsMatchIn:expression]];

  /*
	return [VMArray arrayWithArray:
			[expression arrayOfCaptureComponentsMatchedByRegex:
			 @""
			 "^@"						//	begin of function
			 "("						//	$1 -->
			 "[A-Za-z0-9]"			//	function name
			 "+"						//	match 1 or more times
			 ")"						//	$1 <--
			 "\\{?"						//	{ may appear
			 "("						//	$2 -->
			 "[^}]"				//	until }
			 "*"						//	match 0 or more times
			 ")"						//	$2 <--
			 "\\}?"						//	} may appear
			 "$"						//	end
			 ]];
   */
}
	
#pragma mark -
#pragma mark variables and functions (internal subs)
	//
	//	score-evaluator function (SEFunction) subs
	//
	
	
	//
	//	D / F
	//
	SEFunctionDefinition( D ) {
		vmObjectType type = [self.variables itemAsFloat:@"@TYPE"];
		if ( type != vmObjectType_selector ) return nil;
        VMId *target = parameter ? parameter : [self.variables item:@"@T"];
        VMInt distance = [DEFAULTSONG distanceToLastRecordOf:target];
		return VMIntObj( distance );
	}
	
	SEFunctionDefinition( F ) {
		VMId *lastFragmentId = [self valueForVariable:@"@A"];	//	this is the last frag when before the next frag is selected.
		if ( ! lastFragmentId || (!ClassMatch(lastFragmentId, VMId))) return VMBoolObj( NO );
		
		BOOL t = NO;
		
		VMArray *comparatorArray = [VMArray arrayWithString:parameter splitBy:@","];
		
		for( VMString *comparator in comparatorArray ) {
			BOOL match = (	[lastFragmentId rangeOfString:comparator].location != NSNotFound );
			t |= match;
		}
        /*
        NSLog(@"@F{%@} (lastFragId:%@) = %@", parameter, lastFragmentId, t ? @"YES" : @"NO");*/
		return VMIntObj( t ? 1. : 0. );
	}
	
	//
	// 	LS / LC
	//
	//	sub
- (VMFloat)distanceToLastSelectionOfFragment:(VMId*)fragId {
	VMArray *history = [variables_ item:@"@selectorHistory"];
	if ( ! history ) return 1e30f;
	VMInt p = [history position:fragId];
	if ( p < 0 ) return 1e30f;					//	return a very big number if not found
	return p;
}
	
	SEFunctionDefinition( LS ) {
		vmObjectType type = [variables_ itemAsFloat:@"@TYPE"];
		if ( type != vmObjectType_selector )
		return nil;
		return VMFloatObj( [self distanceToLastSelectionOfFragment:( parameter ? parameter : [self.variables item:@"@T"] )] );
	}
	
	SEFunctionDefinition( LC ) {
		vmObjectType type = [variables_ itemAsFloat:@"@TYPE"];
		if ( type != vmObjectType_selector )
		return nil;
		VMFloat dist = [self distanceToLastSelectionOfFragment:( parameter ? parameter : [self.variables item:@"@T"] )] +1;
		if ( dist == 0 ) return VMFloatObj( 1. );
		VMFloat recip = 1.001 - ( 1 / dist );
		/*	dist = 0
		 dist = 1	1 - ( 1 / 1 ) = 0
		 dist = 2    1 - ( 1 / 2 ) = 0.5
		 dist = 3    1 - ( 1 / 3 ) = 0.6667
		 
		 */
		return VMFloatObj( recip );
	}
	
	//
	//	PT			playing time of part
	//
	SEFunctionDefinition( PT ) {
		vmObjectType type = [variables_ itemAsFloat:@"@TYPE"];
		if ( type != vmObjectType_selector )
		return nil;
		return VMFloatObj( DEFAULTSONGPLAYER.playTimeAccumulator.playingTimeOfCurrentPart );
	}
	
	//
	//	TD/TN		dayness, nightness
	//
	SEFunctionDefinition( TD ) {
		return VMFloatObj( timeManager_.dayNess );
	}
	
	SEFunctionDefinition( TN ) {
		return VMFloatObj( timeManager_.nightNess );
	}
	
	//
	//	TS			shall we end sequence ??
	//
	SEFunctionDefinition( TS ) {
		VMTime secondsRemain = timeManager_.remainTimeUntilShutdown;
		//
		//	end sequence if remaining time is less than 5 minutes.
		//
		VMFloat secondsForFinalCall				= 1.0 * 60;
		VMFloat secondsForPrepareTermination	= 3.0 * 60;
		
		VMFloat ts;
		
		if ( secondsRemain > secondsForFinalCall + secondsForPrepareTermination ) {
			ts = 0.;
		} else if ( secondsRemain < secondsForFinalCall ) {
			ts = 1.;
		} else {
			ts = 1 - (( secondsRemain - secondsForFinalCall ) / secondsForPrepareTermination );
		}
		//NSLog( @"@TS check from %@ = %.2f", [self.variables item:@"@T"], ts );
		return VMFloatObj( ts );
	}
	
	
#pragma mark -
#pragma mark variables and functions (public)
- (void)setValue:(id)value forVariable:(VMString*)variableName {
	[variables_ setItem:value for:variableName];
	if (kUseNotification && shouldNotify_)
	[VMPNotificationCenter postNotificationName:VMPNotificationVariableValueChanged
										 object:self
									   userInfo:@{}];
}
	
- (void)setFragmentId:(VMId*)fragId {
	[self setValue:[self valueForVariable:@"@L"]		forVariable:@"@LL"];
	[self setValue:[self valueForVariable:@"@A"]		forVariable:@"@L"];
	[self setValue:fragId 								forVariable:@"@A"];
}
	
	//
- (id)valueForVariable:(VMString*)variableName {
	id result;
	if ( [variableName hasPrefix:@"@"] ) {
		NSArray *ar = [((VMArray*)[self parseFunction:variableName]) item:0];
		VMString *type = 		[ar objectAtIndex:1];
		VMString *parameter = 	[ar objectAtIndex:2];
		
		SEL sel = [[seFunctionTable_static_ item:type] pointerValue];
		if ( sel ) {
			if (! [self respondsToSelector:sel] )
			[VMException raise:@"ScoreEvaluator function not found."
						format:@"for function:%@ \ncalled with parameter:%@", variableName, parameter ];
			
			return [self performSelector:sel withObject:(parameter.length > 0 ? parameter : nil)];
		}
	}
	result = [variables_ item:variableName];
	if (!result) result = VMFloatObj(0);		//	undefined vars are 0
	return result;
}
	
- (VMFloat)evaluate:(NSString*)expression {
  NSError *error = nil;
  
	//strip space & tab first
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\\s|\\t" options:0 error:&error];
    expression = [regex stringByReplacingMatchesInString:expression options:0 range:NSMakeRange(0, expression.length) withTemplate:@""];
	              
	//	replace @func() -> @func{()}	so that we can evaluate the function later
	//	*unimplemented
	
	
	//	eval inside () first
  
    __block NSMutableString *exp = [NSMutableString stringWithString:expression];
  
	doForever {
		__block BOOL matched = NO;
    regex = [NSRegularExpression regularExpressionWithPattern:@"(\\([^(]*?\\))" options:0 error:&error];
    [regex enumerateMatchesInString:exp options:0 range:NSMakeRange(0, exp.length) usingBlock:^(NSTextCheckingResult * _Nullable result, NSMatchingFlags flags, BOOL * _Nonnull stop) {
      if (!result || result.range.location == NSNotFound) {
        *stop = YES;
      } else {
        matched = YES;
        NSRange range = [result rangeAtIndex:0];
          /*
        NSLog(@"[%@] range: %d, %d = %@,%@,%@", exp, range.location, range.length, [exp substringToIndex:range.location], [exp substringWithRange:NSMakeRange(range.location+1, range.length-2)], [exp substringFromIndex:range.location + range.length]);
           */
        [exp setString:[NSString stringWithFormat:@"%@%2.2f%@",
                        [exp substringToIndex:range.location],
                        [self evaluate:[exp substringWithRange:NSMakeRange(range.location+1, range.length-2)]],
                        [exp substringFromIndex:range.location + range.length]
                        ]];
      }
      *stop = YES;  // always eval only the first match
    }];
    
    /*
		expression = [expression stringByReplacingOccurrencesOfRegex:@"(\\([^(]*?\\))"
														  usingBlock:
					  ^NSString *(NSInteger capCount, NSString *const VMUnsafe *capStrings, const NSRange *capRanges, volatile BOOL *const stop) {
						  matched = YES;
						  return	[NSString stringWithFormat:@"%f",
									 [self evaluate:[capStrings[1] substringWithRange: NSMakeRange(1, [capStrings[1] length]-2)]]
									 ];
					  }];
     */
    if ( !matched ) break;
	}
  
  expression = exp; // copy it back
	
	VMFloat lValf,rValf,result;
	NSString *lval, *op, *rval, *relict;
	
	doForever {
		VMArray *arr = [self dissolute:expression];
		VMInt	opType;
		
		NSArray *fm = [arr item:0];
        if (fm.count == 0) {
            // no need to dissolute:
            result = expression.floatValue;
            break;
        }
        
		lval = [fm objectAtIndex:1];
		op   = [fm objectAtIndex:2];
		rval = [fm objectAtIndex:3];
		
		lValf 	= lval.length	? [self evaluateSingleValue:lval ] : 0;
		opType 	= op.length		? [operatorTable_static_ itemAsInt:op ] : vmOperatorType_undefined;
		rValf 	= rval.length 	? [self evaluateSingleValue:rval ] : 0;
		relict 	= Default( [fm objectAtIndex:4], nil );
		if ( opType == vmOperatorType_undefined )
		return lValf;
		result = [self evalOperator:opType withLvalue:lValf andRvalue:rValf];
		//	NSLog(@"eval:%@(%.3f) %@ %@(%.3f) = %.3f", lval, lValf, op, rval, rValf, result );
		if ( relict.length == 0 || isnan(result) )
		break;
		
		expression = [NSString stringWithFormat:@"%.3f%@", result, relict];
	}
	if ( isnan( result ) )
	[VMException raise:@"Could not evaluate an expression"
				format:@"eval:%@(%.3f) %@ %@(%.3f) = %.3f", lval, lValf, op, rval, rValf, result ];
	
	return result;
}
	
	
- (VMFloat)primaryFactor:(VMString*)scoreDescriptor {
	VMArray *arr = [self dissolute:scoreDescriptor];
	NSArray *fm = [arr item:0];
	return [self valueAsFloat:[fm objectAtIndex:1]];
}
	
	
- (VMString*)setPrimaryFactor:(VMFloat)value forDescriptor:(VMString*)scoreDescriptor {
	//
	//	note:
	//
	//	this function has a problem: i can't remember what a primary factor is good for,
	//	and score descriptors i wrote on my vms files are not compilant :/  (SS)
	
	//
	//	ps: i've found out that primary factor was designed to modify score by expanding (or overwriting) vms
	//	with another vms file.
	//	we have to find out an another way to merging multiple score descriptors for one selector option.
	//
	//	probably, we should not add scores, but multiply them. in this case, scores inside a selector
	//	must be normalized before multiplication.
	//
	
	NSString *modded;
	if ( scoreDescriptor ) {
		VMArray *arr = [self dissolute:scoreDescriptor];
		NSArray *fm = [arr item:0];
		modded = [NSString stringWithFormat:@"%f%@%@%@",
				  value,				//	replace first lvalue (primaryFactor)
				  [fm objectAtIndex:2],	//	op
				  [fm objectAtIndex:3],	//	rvalue
				  [fm objectAtIndex:4]	//	relict
				  ];
	} else {
		modded = [NSString stringWithFormat:@"%f",  value];
	}
	return modded;
}
	
	
#pragma mark -
#pragma mark resolve path tracking
	
	/*---------------------------------------------------------------------------------
	 *
	 *
	 *	resolve path tracking (RPT)
	 *
	 *		track the resolving path to process objects on succeeding to resolve.
	 *
	 *---------------------------------------------------------------------------------*/
	
- (id)resolveDataWithTracking:(VMData*)data toType:(int)type {
	[self beginTrackingOfResolvePath];
	id r = [data resolveUntilType:type];
	[self endTrackingOfResolvePath:(r != nil )];
	return r;
}
	
	//
	// begin tracking
	//
- (void)beginTrackingOfResolvePath {
	trackingPathIsReturning = NO;
	if (verbose) NSLog(@"     RPT : begin track:[%ld]", self.pathTrackerArray.count);
	[self.pathTrackerArray push: ARInstance(VMArray)];
}
	
	//
	// do track
	//
- (void)trackObjectOnResolvePath:(id)data {
	if ( self.pathTrackerArray.count > 0 && ( ! trackingPathIsReturning )) {
		if (verbose) NSLog(@"     RPT : track:[%ld] %@",
						   self.pathTrackerArray.count-1,
						   ( ClassMatch(data, VMData) ? ((VMData*)data).id : @"Hash Data" )  );
		[[self.pathTrackerArray lastItem] push:data];	//	only if objectsOnResolvePath != nil
	}
}
	
	//
	// end tracking
	//
- (void)endTrackingOfResolvePath:(BOOL)success {
	trackingPathIsReturning = YES;
	VMArray *objectsOnResolvePath = [self.pathTrackerArray pop];
	if (verbose) NSLog(@"     RPT : end track:[%ld]", self.pathTrackerArray.count);
	if ( success && (!self.testMode) ) {
		if ( ! objectsWaitingToBeProcessed_ )	self.objectsWaitingToBeProcessed = ARInstance(VMArray);
		if ( ! objectsWaitingToBeLogged_ )		self.objectsWaitingToBeLogged = ARInstance(VMArray);
		//
		//	count up counters on objects on resolvepath ( resolving succeed )
		//	execute functions on selectors on the path.r
		//
		VMArray *objectsToLog		= ARInstance(VMArray);
		VMArray *objectsToProcess	= ARInstance(VMArray);
		for ( id data in objectsOnResolvePath ) {
			[objectsToLog push:data];
			VMData *d = ClassCastIfMatch( data, VMData );
			if ( !d ) continue;
			switch ((int) d.type ) {
				case vmObjectType_selector:
//				case vmObjectType_sequence;
				case vmObjectType_audioFragment:				{
					[objectsToProcess push:d];
					break;
					
				}
			}
		}
		[objectsWaitingToBeLogged_		appendBefore:objectsToLog];
		[objectsWaitingToBeProcessed_	appendBefore:objectsToProcess];
	}
	if ( self.pathTrackerArray.count == 0 ) [self processObjects];
}
	
	/*---------------------------------------------------------------------------------
	 
	 process objects on succeeded resolve path
	 
	 ----------------------------------------------------------------------------------*/
- (void)processObjects {
	for ( VMData *d in self.objectsWaitingToBeProcessed ) {
		switch ((int) d.type ) {
			case vmObjectType_selector: {
				VMSelector *sel = ClassCast(d, VMSelector);
				if (!sel.liveData) [sel prepareLiveData];
				sel.liveData.counter++;
				[sel interpreteInstructionsWithAction:vmAction_play];	//	for executing 'set' instructions
				
				
#if VMP_VISUALIZER
				[VMPNotificationCenter postNotificationName:VMPNotificationProcessObject
													 object:self userInfo:@{@"fragment":d}];
				
#endif
				break;
				
			case vmObjectType_audioFragment:
#if VMP_VISUALIZER
				[VMPNotificationCenter postNotificationName:VMPNotificationProcessObject
													 object:self userInfo:@{@"fragment":d}];
#endif
				break;
			}
		}
	}
	VMNullify(objectsWaitingToBeProcessed);
	
	VMArray *objectIds = ARInstance(VMArray);
	
	if ( objectsWaitingToBeLogged_ ) {
		
		for( id data in objectsWaitingToBeLogged_ ) {
			if( ClassMatch( data, VMData ) ) [objectIds push:((VMData*)data).id];
		}
		if (verbose) NSLog(@"     RPT : record:%@",[objectIds description]);
		if ( objectIds.count > 0 )
		[DEFAULTSONG record:objectIds];
		else
		NSLog(@"empty");
		
#if VMP_LOGGING
		if ( shouldLog_ )
		[DEFAULTSONG.log record:objectsWaitingToBeLogged_ filter:YES];
#endif
		VMNullify(objectsWaitingToBeLogged);
	}
}
	
	
#pragma mark - collecting referrers
	
#define addReferrer(targetId) {\
if ( ![targetId isEqualToString:@"*"] ) {\
VMHash *referrerOfData = [referrer itemAsHash:targetId];\
if ( ! referrerOfData ) {\
referrerOfData = ARInstance(VMHash);\
[referrer setItem:referrerOfData for:targetId];\
}\
[referrerOfData setItem:@(YES) for:dataId];\
}\
}
	
#define addReferrerForSubData(subData) {\
if( ClassMatch(subData, VMId)) \
addReferrer( subData ) \
else if( ClassMatch(subData, VMChance )) \
addReferrer( ((VMChance*)subData).targetId ) \
}
	
	//
	//	collect referrer for all fragments
	//
	
	- (VMHash*)collectReferrer {
		VMArray *idList	= [DEFAULTSONG.songData keys];
		VMHash *referrer = ARInstance(VMHash);
		
		for( VMId* dataId in idList ) {
			VMData *data = [DEFAULTSONG.songData item:dataId];
			
			switch ( (int)data.type) {
				case vmObjectType_audioFragment: {
					addReferrer( ((VMAudioFragment*)data).audioInfoId );
					break;
				}
				case vmObjectType_reference:
				case vmObjectType_chance: {
					addReferrer(((VMReference*)data).referenceId );
					break;
				}
				case vmObjectType_collection:
				case vmObjectType_selector:
				case vmObjectType_sequence: {
					for( id subData in ((VMCollection*)data).fragments ) {
						addReferrerForSubData( subData );
					}
					if ( data.type == vmObjectType_sequence ) {
						for( id subData in ((VMSequence*)data).subsequent.fragments ) {
							addReferrerForSubData( subData );
						}
					}
					break;
				}
			}
		}
		return referrer;
	}

	
@end

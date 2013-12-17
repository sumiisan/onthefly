//
//  VMFunction.m
//  VariableMusicPlayer
//
//  Created by  on 13/02/08.
//  Copyright (c) 2013 sumiisan. All rights reserved.
//

#import "VMDataTypes.h"
#import "VMPrimitives.h"
#import "VMPMacros.h"
#import "VMDataTypesMacros.h"
#import "VMScoreEvaluator.h"
#import "VMException.h"

//------------------------ Function -----------------------------
/*
 defining an function in instructions
 */
#pragma mark -
#pragma mark *** VMFunction ***

@implementation VMFunction
@synthesize functionName=functionName_,parameter=parameter_;

static VMHash 	*ProcessorTable_static_ = nil;
static VMArray 	*fragOrderChangingFunctions_static_ = nil;

#pragma mark public
- (id)valueForParameter:(VMString*)parameterName {
	return [self.parameter item:parameterName];
}

- (id)firstParameterValue {	//	if function has only one (i.e unnamed) parameter
	return [self valueForParameter:self.functionName];
}

- (BOOL)isEqualToFunction:(VMFunction*)aFunc {
	return [self.parameter allKeysAndValuesAreEqual:aFunc.parameter];
}

- (id)processWithData:(id)data action:(VMActionType)action {
	SEL sel = [[ProcessorTable_static_ item:self.functionName] pointerValue];
	if (! sel)return nil;
	if (! [self respondsToSelector:sel] ) 
		[VMException raise:@"Function processor not found." 
					format:@"for function:%@ \ncalled with data:%@",[self description],data];
	id result = [self performSelector:sel withObject:data withObject:VMIntObj(action)];
	
	if (! result )
		[VMException raise:@"Failed to process function." 
					format:@"for function:%@ \ncalled with data:%@",[self description],data];
	
	return result;
}

- (BOOL)doesChangeFragmentsOrder {
	VMInt p = [fragOrderChangingFunctions_static_ position:self.functionName];
	//NSLog(@"xxx %@ changes frag order:%@", self.functionName, ( p >= 0 ) ? @"YES" : @"NO" );
	return p >= 0; 
}

#pragma mark private

- (void)setByString:(VMString*)data {
	VMArray *comps = [VMArray arrayWithString:ClassCast(data, VMString) splitBy:@" "];
	if ( ! self.parameter ) self.parameter = ARInstance(VMHash);
	for ( VMString *comp in comps ) {
		VMString *name;
		VMString *val;
		VMArrayToList2([VMArray arrayWithString:comp splitBy:@"="], name, val )
		[self.parameter setItem:val for:name];
		if ( ! self.functionName ) self.functionName = name;
	}
}

#define ProcessorMethod(proc)			processor_##proc
#define ProcessorEntry(proc)			[NSValue valueWithPointer:@selector( ProcessorMethod(proc): action:)],	@"" #proc,
#define ProcessorDefinition(proc)		- (id)ProcessorMethod(proc):(id)data action:(NSNumber*)action

- (void)initProcessorTable {
	if ( ! ProcessorTable_static_ ) {
		ProcessorTable_static_ = Retain([VMHash hashWithObjectsAndKeys:		//	valid target		evaluated at action:
							 ProcessorEntry(random)				//	fragments collection		vmAction_prepare
							 ProcessorEntry(shuffle)			//	fragments collection		vmAction_prepare
							 ProcessorEntry(reverse)			//	fragments collection		vmAction_prepare
							 ProcessorEntry(schedule)			//	selector			vmAction_prepare
							 ProcessorEntry(flattenScore)		//	selector			vmAction_prepare
//							 ProcessorEntry(fluctuate)			//	audioInfo			get duration, offset etc
							 ProcessorEntry(set)				//	meta				vmAction_play
							 nil] );
	}
	
	if ( ! fragOrderChangingFunctions_static_ ) {
		fragOrderChangingFunctions_static_ = [VMArray arrayWithObjects:
									   @"random",
									   @"shuffle",
									   @"reverse",
									   @"schedule",
									   nil ];
		Retain(fragOrderChangingFunctions_static_);
	}
}

#pragma mark processors

/*-----------------------------------------------------------------------------------
 
 function processor definition
 
 -----------------------------------------------------------------------------------*/

/**
 reverse order of frags in collection
 
 param name		value
 "reverse"		-
 */
ProcessorDefinition(reverse) {
	if ( action.intValue != vmAction_prepare ) return VMBoolObj(NO);
	if( ClassMatch(data, VMSelector) ) data = ClassCast(data, VMSelector).liveData;
	VMCollection *cc = ClassCastIfMatch(data, VMCollection);
	if ( cc ) {
		[cc.fragments reverse];										return VMBoolObj(YES);
	}
	return nil;
}

/**
 shuffle frags in collection
 
 param name		value
 "shuffle"		range (0..1)
 */
ProcessorDefinition(shuffle) {
	if ( action.intValue != vmAction_prepare ) return VMBoolObj(NO);
	if( ClassMatch(data, VMSelector) ) data = ClassCast(data, VMSelector).liveData;
	VMCollection *cc = ClassCastIfMatch(data, VMCollection);
	if ( cc ) {
		VMInt c = cc.length;
		int range = c * [[self firstParameterValue] floatValue];
		
		for ( VMInt p = 0; p < c; ++p ) {
			VMInt ofs = VMRand(range*2+1)-range;
			VMInt swp = p+ofs;
			if (swp < 0) swp = -swp;
			if (swp >= c ) swp = c-(c-swp)-1;
			if (swp > 0 && swp < c && p != swp ) [cc.fragments swapItem:p withItem:swp];
		}
		return VMBoolObj(YES);
	}
	return nil;
}

/**
 randomize frags in collection
 
 param name		value
 "random"		( alias for "shuffle=1" )
 */
ProcessorDefinition(random) {
	if ( action.intValue != vmAction_prepare ) return VMBoolObj(NO);
	if( ClassMatch(data, VMSelector) ) data = ClassCast(data, VMSelector).liveData;
	VMCollection *cc = ClassCastIfMatch(data, VMCollection);
	if ( cc ) {
		[self.parameter setItem:VMFloatObj(1.) for:self.functionName];	//	do shuffle 100%
		return [self ProcessorMethod(shuffle):cc action:action];
	}
	return nil;
}


/**
 schedule frags in selector
 
 optimize frag selection. 
 it is useful if you have conditions allowing to play a frag only in limited frames like xxx=@C%7=1.
 
 scheduiling in advance is recommended only if all conditions (except @C) are static. 
 example:
 xxx=2			...	OK. a static condition definition. 
 xxx=@LC 		...	BAD because @LC depends on last played frag, which means the condition changes dynamically.
 xxx=@C>1 		... OK. @C (selector counter) is the only variable we can estimate at scheduling phase.
 
 param name		value
 "schedule"		-
 "frames" 		number of frames to schedule ( if omitted, default is 4 x number of frags )
 */

#define schedule_verbose 0
//	subs
- (void)removeFragmentOptionIfScoreIsLessThanZero:(VMId *)fragId
							 totalScoreOfFragment:(VMHash *)totalScoreOfFragment 
							   scoreForFrame:(VMArray *)scoreForFrame {
    //	remove choice option if score < 0
    VMFloat scoreForFragment = [totalScoreOfFragment itemAsFloat:fragId];
    if ( scoreForFragment < 0 )
        for ( VMHash *scoreForFragments in scoreForFrame )
            [scoreForFragments removeItem:fragId];
}

- (void)setFragment:(VMId *)fragId 
			at:(VMInt)framePosition
	   ofArray:(VMArray *)frames 
totalScoreOfFragments:(VMHash *)totalScoreOfFragments 
  framesLeft_p:(VMInt *)framesLeft_p
 scoreForFrame:(VMArray *)scoreForFrame {
	
    [frames setItem:fragId at:framePosition];
    [totalScoreOfFragments add:-1 ontoItem:fragId];
    --(*framesLeft_p);
    [self removeFragmentOptionIfScoreIsLessThanZero:fragId 
                               totalScoreOfFragment:totalScoreOfFragments 
                                 scoreForFrame:scoreForFrame];
#if schedule_verbose
	VMArray *setFrames = ARInstance(VMArray);
	int i = 0;
	for ( id obj in frames ) {
		[setFrames push: ( obj ? [NSString stringWithFormat:@"%03d", i] : @"---" )];
		++i;
	}
	NSLog(@"setFragmentFor %d=%@ %@", framePosition, fragId, [frames join:@","]);
#endif
}

ProcessorDefinition(schedule) {
	if ( action.intValue != vmAction_prepare ) VMBoolObj(NO);
	if( ! ClassMatch(data, VMSelector) ) VMBoolObj(NO);
	
	VMSelector 	*selector 			= ClassCast(data, VMSelector);			
	id 			frameParam 			= [self valueForParameter:@"frames"];
	VMInt 		framesToSchedule 	= frameParam ? [frameParam intValue] : selector.length * 4;
	
	VMArray		*frames				= [VMArray nullFilledArrayWithSize:framesToSchedule];
	VMHash 		*totalScoreOfFragments 	= ARInstance(VMHash);
	VMArray 	*scoreForFrame 		= ARInstance(VMArray);
	
	int framePosition;
	//	collect score for frags		
	for (framePosition = 0; framePosition < framesToSchedule; ++framePosition) {
#if schedule_verbose
		NSLog(@"---------------- phase: 1 / frame: %d -----------------",framePosition);
#endif
		VMHash *scoreForFragment = [selector collectScoresOfFragments:0. frameOffset:framePosition normalize:YES];
		[scoreForFrame push:AutoRelease([scoreForFragment copy])];
		VMArray *fragIds = [scoreForFragment keys];
		for ( VMId *fragId in fragIds )
			[totalScoreOfFragments add:[scoreForFragment itemAsFloat:fragId] ontoItem:fragId];
	}
	
	//	scheduling
	VMInt 	framesLeft = framesToSchedule;
	BOOL 	didSomething;
	while ( framesLeft ) {
#if schedule_verbose	
		NSLog(@"---------------- phase: 2 / frames left: %d -----------------\n%@",
			  framesLeft,
			  [totalScoreOfFragments description]);
#endif

		//	scan frames with only one choice
		do {
			didSomething = NO;
			for ( framePosition = 0; framePosition < framesToSchedule; ++framePosition ) {
				if ( [frames item:framePosition] ) continue;					//	already scheduled.
				VMHash *scoreForFragments = [scoreForFrame item:framePosition];
				if ( scoreForFragments.count == 1 ) {
					[self setFragment:[[scoreForFragments keys] item:0] at:framePosition ofArray:frames 
				totalScoreOfFragments:totalScoreOfFragments
					framesLeft_p:&framesLeft 
				   scoreForFrame:scoreForFrame];
					didSomething = YES;
				}
			}
		} while ( didSomething );
		
		if ( ! framesLeft ) break;

		//	resolve randomly selected frame.
		framePosition = -1;
		do {
			int randomFrame = VMRand(framesToSchedule);
			if ( ! [frames item:randomFrame] ) framePosition = randomFrame;
		} while ( framePosition < 0 ); 
		
		VMFragment *c = [selector selectOneTemporaryUsingScores:[scoreForFrame item:framePosition] sumOfScores:0.];
		[self setFragment:c.id at:framePosition ofArray:frames 
	totalScoreOfFragments:totalScoreOfFragments
		framesLeft_p:&framesLeft 
	   scoreForFrame:scoreForFrame];
	}
	
	selector.liveData.fragments = frames;
	NSLog(@"---------------- schedule end -----------------\n%@",[frames description]);

	return VMBoolObj(YES);
}


/**
 set one or more variable(s)
 
 param name	
 *(variable name)	= 	(value)
 */

ProcessorDefinition(set) {
	if ( action.intValue != vmAction_play ) return VMBoolObj(NO);
	
	VMArray *paramNames = [self.parameter keys];
	for ( VMString *paramName in paramNames ) {
		if ( [paramName isEqualToString: self.functionName ] ) continue;
		VMString *val = [self valueForParameter:paramName];
		VMFloat f = [DEFAULTEVALUATOR evaluate:val];
		if ( ! isnan(f) ) 
			[DEFAULTEVALUATOR setValue:VMFloatObj(f) forVariable:paramName];
		else
			[DEFAULTEVALUATOR setValue:val forVariable:paramName];
	//	NSLog(@"++++ set:%@=%@",paramName, [DEFAULTEVALUATOR valueForVariable:paramName] );
	}
	return VMBoolObj(YES);	
}


#pragma mark obligatory
VMObligatory_resolveUntilType()
VMOBLIGATORY_init(vmObjectType_function, NO, [self initProcessorTable]; )
VMOBLIGATORY_setWithProto(
						  CopyPropertyIfExist( functionName )
						  CopyPropertyIfExist( parameter )
						  )
VMOBLIGATORY_setWithData
(	
 if ( ClassMatch(data, VMHash)) {
	 MakeHashFromData
	 SetPropertyIfKeyExist( functionName, itemAsObject )
	 SetPropertyIfKeyExist( parameter, itemAsObject )
 } else if ( ClassMatch(data, VMString)) {
	 [self setByString:data];	 
 }
 
 )

- (void)dealloc {
	VMNullify(functionName);
	VMNullify(parameter);
    Dealloc( super );;
}

- (NSString*)description {
	VMArray *descs = ARInstance(VMArray);
	VMArray *keys = [self.parameter sortedKeys];
	for( VMString *key in keys ) {
		if ( [self.parameter item:key] )
			[descs push:[NSString stringWithFormat:@"%@=%@", key, [self.parameter item:key]]];
		else
			[descs push:[NSString stringWithFormat:@"%@", key ]];
	}
	return [NSString stringWithFormat:@"(%@)", [descs join:@","]];
}

VMObligatory_initWithCoder
(
 [self initProcessorTable];
 Deserialize(functionName, Object)
 Deserialize(parameter, Object)
 )

VMObligatory_encodeWithCoder
(
 Serialize(functionName, Object)
 Serialize(parameter, Object)
 )

@end



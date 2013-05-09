//
//  VMFunction.m
//  VariableMusicPlayer
//
//  Created by  on 13/02/08.
//  Copyright (c) 2013 __MyCompanyName__. All rights reserved.
//

#import "VMDataTypes.h"
#import "VMPrimitives.h"
#import "VMException.h"
#import "VMPMacros.h"
#import "VMDataTypesMacros.h"
#import "VMScoreEvaluator.h"

//------------------------ Function -----------------------------
/*
 defining an function in instructions
 */
#pragma mark -
#pragma mark *** VMFunction ***

@implementation VMFunction
@synthesize functionName=functionName_,parameter=parameter_;

static VMHash 	*ProcessorTable__ = nil;
static VMArray 	*cueOrderChangingFunctions__ = nil;

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
	SEL sel = [[ProcessorTable__ item:self.functionName] pointerValue];
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

- (BOOL)doesChangeCueOrder {
	VMInt p = [cueOrderChangingFunctions__ position:self.functionName];
	//NSLog(@"xxx %@ changes cue order:%@", self.functionName, ( p >= 0 ) ? @"YES" : @"NO" );
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
	if ( ! ProcessorTable__ ) {
		ProcessorTable__ = [[VMHash hashWithObjectsAndKeys:		//	valid target		evaluated at action:
							 ProcessorEntry(random)				//	cue collection		vmAction_prepare
							 ProcessorEntry(shuffle)			//	cue collection		vmAction_prepare
							 ProcessorEntry(reverse)			//	cue collection		vmAction_prepare
							 ProcessorEntry(schedule)			//	selector			vmAction_prepare
							 ProcessorEntry(flattenScore)		//	selector			vmAction_prepare
//							 ProcessorEntry(fluctuate)			//	audioInfo			get duration, offset etc
							 ProcessorEntry(set)				//	meta				vmAction_play
							 nil] retain];
	}
	
	if ( ! cueOrderChangingFunctions__ ) {
		cueOrderChangingFunctions__ = [[VMArray arrayWithObjects:
									   @"random",
									   @"shuffle",
									   @"reverse",
									   @"schedule",
									   nil ] retain];
	}
}

#pragma mark processors

/*-----------------------------------------------------------------------------------
 
 function processor definition
 
 -----------------------------------------------------------------------------------*/

/**
 reverse order of cues in cue-collection
 
 param name		value
 "reverse"		-
 */
ProcessorDefinition(reverse) {
	if ( action.intValue != vmAction_prepare ) return VMBoolObj(NO);
	if( ClassMatch(data, VMSelector) ) data = ClassCast(data, VMSelector).liveData;
	VMCueCollection *cc = ClassCastIfMatch(data, VMCueCollection);
	if ( cc ) {
		[cc.cues reverse];										return VMBoolObj(YES);
	}
	return nil;
}

/**
 shuffle cues in cue-collection
 
 param name		value
 "shuffle"		range (0..1)
 */
ProcessorDefinition(shuffle) {
	if ( action.intValue != vmAction_prepare ) return VMBoolObj(NO);
	if( ClassMatch(data, VMSelector) ) data = ClassCast(data, VMSelector).liveData;
	VMCueCollection *cc = ClassCastIfMatch(data, VMCueCollection);
	if ( cc ) {
		VMInt c = cc.length;
		int range = c * [[self firstParameterValue] floatValue];
		
		for ( VMInt p = 0; p < c; ++p ) {
			VMInt ofs = VMRand(range*2+1)-range;
			VMInt swp = p+ofs;
			if (swp < 0) swp = -swp;
			if (swp >= c ) swp = c-(c-swp)-1;
			if (swp > 0 && swp < c && p != swp ) [cc.cues swapItem:p withItem:swp];
		}
		return VMBoolObj(YES);
	}
	return nil;
}

/**
 randomize cues in cue-collection
 
 param name		value
 "random"		( alias for "shuffle=1" )
 */
ProcessorDefinition(random) {
	if ( action.intValue != vmAction_prepare ) return VMBoolObj(NO);
	if( ClassMatch(data, VMSelector) ) data = ClassCast(data, VMSelector).liveData;
	VMCueCollection *cc = ClassCastIfMatch(data, VMCueCollection);
	if ( cc ) {
		[self.parameter setItem:VMFloatObj(1.) for:self.functionName];	//	do shuffle 100%
		return [self ProcessorMethod(shuffle):cc action:action];
	}
	return nil;
}


/**
 schedule cues in selector
 
 optimize cue selection. 
 it is useful if you have conditions allowing to play a cue only in limited frames like xxx=@C%7=1.
 
 scheduiling in advance is recommended only if all conditions (except @C) are static. 
 example:
 xxx=2			...	OK. a static condition definition. 
 xxx=@LC 		...	BAD because @LC depends on last played cue, which means the condition changes dynamically.
 xxx=@C>1 		... OK. @C (selector counter) is the only variable we can estimate at scheduling phase.
 
 param name		value
 "schedule"		-
 "frames" 		number of frames to schedule ( if omitted, default is 4 x number of cues )
 */

#define schedule_verbose 0
//	subs
- (void)removeCueOptionIfScoreIsLessThanZero:(VMId *)cueId 
							 totalScoreOfCue:(VMHash *)totalScoreOfCue 
							   scoreForFrame:(VMArray *)scoreForFrame {
    //	remove choice option if score < 0
    VMFloat scoreForCue = [totalScoreOfCue itemAsFloat:cueId];
    if ( scoreForCue < 0 )
        for ( VMHash *scoreForCues in scoreForFrame )
            [scoreForCues removeItem:cueId];
}

- (void)setCue:(VMId *)cueId 
			at:(VMInt)framePosition
	   ofArray:(VMArray *)frames 
totalScoreOfCues:(VMHash *)totalScoreOfCues 
  framesLeft_p:(VMInt *)framesLeft_p
 scoreForFrame:(VMArray *)scoreForFrame {
	
    [frames setItem:cueId at:framePosition];
    [totalScoreOfCues add:-1 ontoItem:cueId];
    --(*framesLeft_p);
    [self removeCueOptionIfScoreIsLessThanZero:cueId 
                               totalScoreOfCue:totalScoreOfCues 
                                 scoreForFrame:scoreForFrame];
#if schedule_verbose
	VMArray *setFrames = ARInstance(VMArray);
	int i = 0;
	for ( id obj in frames ) {
		[setFrames push: ( obj ? [NSString stringWithFormat:@"%03d", i] : @"---" )];
		++i;
	}
	NSLog(@"setCueFor %d=%@ %@", framePosition, cueId, [frames join:@","]);
#endif
}

ProcessorDefinition(schedule) {
	if ( action.intValue != vmAction_prepare ) VMBoolObj(NO);
	if( ! ClassMatch(data, VMSelector) ) VMBoolObj(NO);
	
	VMSelector 	*selector 			= ClassCast(data, VMSelector);			
	id 			frameParam 			= [self valueForParameter:@"frames"];
	VMInt 		framesToSchedule 	= frameParam ? [frameParam intValue] : selector.length * 4;
	
	VMArray		*frames				= [VMArray nullFilledArrayWithSize:framesToSchedule];
	VMHash 		*totalScoreOfCues 	= ARInstance(VMHash);
	VMArray 	*scoreForFrame 		= ARInstance(VMArray);
	
	int framePosition;
	//	collect score for cues		
	for (framePosition = 0; framePosition < framesToSchedule; ++framePosition) {
#if schedule_verbose
		NSLog(@"---------------- phase: 1 / frame: %d -----------------",framePosition);
#endif
		VMHash *scoreForCue = [selector collectScoresOfCues:0. frameOffset:framePosition normalize:YES];
		[scoreForFrame push:[[scoreForCue copy] autorelease]];
		VMArray *cueIds = [scoreForCue keys];
		for ( VMId *cueId in cueIds )
			[totalScoreOfCues add:[scoreForCue itemAsFloat:cueId] ontoItem:cueId];
	}
	
	//	scheduling
	VMInt 	framesLeft = framesToSchedule;
	BOOL 	didSomething;
	while ( framesLeft ) {
#if schedule_verbose	
		NSLog(@"---------------- phase: 2 / frames left: %d -----------------\n%@",
			  framesLeft,
			  [totalScoreOfCues description]);
#endif

		//	scan frames with only one choice
		do {
			didSomething = NO;
			for ( framePosition = 0; framePosition < framesToSchedule; ++framePosition ) {
				if ( [frames item:framePosition] ) continue;					//	already scheduled.
				VMHash *scoreForCues = [scoreForFrame item:framePosition];
				if ( scoreForCues.count == 1 ) {
					[self setCue:[[scoreForCues keys] item:0] at:framePosition ofArray:frames 
				totalScoreOfCues:totalScoreOfCues
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
		
		VMCue *c = [selector selectOneTemporaryUsingScores:[scoreForFrame item:framePosition] sumOfScores:0.];
		[self setCue:c.id at:framePosition ofArray:frames 
	totalScoreOfCues:totalScoreOfCues
		framesLeft_p:&framesLeft 
	   scoreForFrame:scoreForFrame];
	}
	
	selector.liveData.cues = frames;
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
		if ( Pittari(paramName, self.functionName )) continue;
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
	self.functionName = nil;
	self.parameter = nil;
    [super dealloc];
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
 Deserialize(functionName, Object)
 Deserialize(parameter, Object)
 )

VMObligatory_encodeWithCoder
(
 Serialize(functionName, Object)
 Serialize(parameter, Object)
 )

@end



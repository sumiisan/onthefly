//
//  VMPreprocessor.m
//  VariableMusicPlayer
//
//  Created by  on 12/11/19.
//  Copyright (c) 2012 sumiisan@gmail.com. All rights reserved.
//

#import "VMPreprocessor.h"
#import "VMTextPreprocessor.h"
#import "VMPJSONDeserializer.h"
#import "VMScoreEvaluator.h"
#import "VMException.h"
#include "VMPMacros.h"

#define VMPP VMPreprocessor

static	VMPreprocessor	*vmpp__singleton__ = nil;

@interface VMPreprocessor(internal)

//--------------------------------------------------------------------------
//
//				the variable music preprocessor
//
//--------------------------------------------------------------------------

//------ text-file formatting phase (1) ------------------------------------
- (VMHash*)				preprocessPhase1:(NSString*)data;

//	(1.00) 	vmp file must be json-ified. 	#1: strip comments
//	(1.01)	shorten key-names like selector: or sequence: to sel: and seq:
//	(1.02) 	vmp file must be json-ified.	#2:	put property names into double quote
//	(1.90) 	scan json and make hash.
- (VMHash*)				scanJSON:(NSString*)data;

//----- hash formatting phase (2) -----------------------------------
- (void)preprocessPhase2:(VMArray*)dataArray;

//	(2.00) 	data array must be mutable

//	(2.10) 	all data must have it's own type
- (vmObjectType) 		guessType:(VMHash*)hash;
//	(2.20) 	remove type specific dialects like selector: or layer: and replace with cues:  (leave alternatives in sequence and layer)
- (id)					guessTypeAndCleanUpTypeSpecificDialects:(id)inObject;

//	(2.40)	flatten tree-formed object structure (i.e cues)
- (void)				flattenTreeStructure:(VMHash*)hash into:(VMArray**)flattened;

//	(2.50) resolve shortcuts in	arrays 'cues', 'alt' and 'subseq'  
- (void)				completeIdsInsideHash:(VMHash*)hash;

//	(2.80)	add myself into alternatives		abolished
//- (void)				addMyselfIntoAlternatives:(VMHash*)hash;
//	(2.90)	scan song properties

//----- object creation phase (3) ------------------------------------------
- (void)				preprocessPhase3:(VMArray*)dataArray;
//	utils
- (VMId*)				completeId:(VMId*)dataId withParentId:(VMId*)parentId;
- (void)				registerData:(VMData*)cue;
- (void)				unRegister:(VMId*)dataId;
- (void)				registerAliasOfCue:(VMData*)cue as:(VMId*)aliasId;
- (void)				makeAlias:(VMData*)data changeIdTo:(VMId*)newId;

//	(3.10)	if tags was specified as array, convert them into tagList
- (VMTagList*)			convertTagsIntoTagList:(VMHash*)dict;
//	(3.11)	register tagList for non-chance objects. (this will be added later to chance)
- (void)				cacheTagListIdForCueId:(VMId*)cueId tagListId:(VMId*)tlId;

//	(3.31)	if a sequence or layer has no cueCollection, create one from id.
- (void)				createCollectionIfItDoesNotHave:(VMCueCollection*)collection;
//	(3.35) 	all ids inside cues should be completed with the owner's id
//- (void)				completeIdsInsideCues:(VMData*)data;				//	done in phase 2.0

//	(3.36)		
//	(3.40)	if audioInfo related key is supplied, create audioInfo
- (VMAudioInfo*) 		createAudioInfoFromCue:(VMData*)data ifInfoProvidedBy:(VMHash*)hash;
//	(3.41) 	if audioInfoId was supplied, a cue (cue obj or cue inside sequence) should be audioCue
- (VMCue*)				convertCue:(VMData**)data withAudioInfoIdIntoAudioCues:(VMHash*)hash;
//	(3.42)	if an audioInfo is placed naked in a sequence or selector, wrap it by an audioCue
- (void)				wrapAudioInfoInsideCueCollectionByAudioCue:(VMCueCollection*)cc;

//	(3.50)	if the object has "alt" (alternatives), 
//			it has to wrapped by a selector.
//			for each alternative, 
//			clone myself and register to make it ready for overwrite.
- (VMSelector*)			wrapCue:(VMData*)data withSelectorIfNeeded:(VMHash*)hash;

//	(3.55)	all id's in a selector must be converted into chances.	btw, selectors should have instruction
- (void)				convertCuesToChances:(VMSelector*)selector;

//	(3.60)	all chance-targets (don't forget sequence's subsequent) should be registered at least as Unresolved
- (void)				markUnresolvedChanceTargets:(VMSelector*)sel;

//	(3.90)	register entrypoints
- (void)				registerEntryPoint:(VMCue*)cue;


//----- object optimization phase (4) ------------------------------------------
- (void)				preprocessPhase4;

//	(4.05)	if a sequence has no subseq, shift the last cue in sequence into subseq.	//	abolished
//- (void)				fillSubseqWithLastCueIfEmpty:(VMSequence*)seq;

//	(4.10)	copy tagLists attached to non-chance objects to chances targeting it.
- (void)				copyTagListsOfTargets:(VMSelector*)selector;
//	(4.30)	set audioInfoRef in audioCue-s
- (void)				setAudioInfoRefInAudioCues:(VMAudioCue*)audioCue;

//	(4.80)	check unresolved objects
- (void)				throwErrorIfUnresolved:(VMData*)d;

@end

@implementation VMPreprocessor
@synthesize log=log_, song;

#pragma mark -
#pragma mark *** utilities and misc ***
#pragma mark -

#pragma mark singleton

+ (VMPreprocessor*)defaultPreprocessor {
	if( ! vmpp__singleton__ ) vmpp__singleton__ = [[VMPP alloc] init];
	return vmpp__singleton__;
}

#pragma mark type

+ (Class)classForType:(vmObjectType)inType {
	return [[VMPP defaultPreprocessor]->classForType item:VMIntObj(inType)];
}

+ (NSString*)shortTypeStringForType:(vmObjectType)typ {
	return [[VMPP defaultPreprocessor]->shortTypeStringForType item:VMIntObj(typ)];
}

+ (NSString*)typeStringForType:(vmObjectType)typ {
	return [[VMPP defaultPreprocessor]->stringForType item:VMIntObj(typ)];
}


#pragma mark universal data creator
+ (id)dataWithType:(vmObjectType)inType {
	Class cls = [VMPP classForType:inType];
	if( cls ) return ARInstance(cls);
	[[self defaultPreprocessor] logError:@"Could not create data (Unknown type) "
								withData:[NSString stringWithFormat:@"%d",inType] ];
	return nil;
}

/*
 universal data creator for all VMData inheriting classes
 */
+(id)dataWithData:(id)data {
	VMData *d = nil;
	IfClassMatch(data, VMData) {
		//	make new VMData type object from VMData
		VMData *proto = ClassCast(data, VMData);
		
		d = [VMPP dataWithType:proto.type];
		[d setWithProto:proto];
		
	} else IfClassMatch(data, VMHash) {
		//	make new VMData from dict
		vmObjectType typ = [[self defaultPreprocessor]
							guessType:ClassCast(data, VMHash)];
		d = [VMPP dataWithType:typ];
		[d setWithData:data];
		
	} else IfClassMatch(data, NSString) {
		//	assume data is id
		vmObjectType typ = [[self defaultPreprocessor]
							guessType:ClassCast(data, VMHash)];
		if( typ == vmObjectType_chance ) {
			d = ARInstance(VMChance);
			[d setWithData:data];
			return d;
		} else {
			d = ARInstance(VMData);
			d.id = data;
			return d;
		}
	}
	
	return d;
}

- (BOOL)is:(vmObjectType)newType upperCompatibleOf:(vmObjectType)oldType {
	VMFloat newOrder 	= [self->compatibilityOrder itemAsFloat:VMIntObj(newType)];
	VMFloat oldOrder	= [self->compatibilityOrder itemAsFloat:VMIntObj(oldType)];
	return ( newOrder > oldOrder );
}

- (VMData*)findOrCreateNewObjectWithHash:(VMHash*)hash {
	
	VMData 			*data;
	
	//  try to find existing object
	VMId *dataId = HashItem(id);
	
	if ( [hash itemAsInt:@"type"] != vmObjectType_reference ) {
		data = [self data:dataId];
	} else {
		data = [self rawData:dataId];
	}
	
	if( !data ) {
		//  if not found, allocate one and add to dataList
		data = [VMPP dataWithData:hash];
		if (data.shouldRegister) [self registerData:data];
		
	} else {
		vmObjectType 	typ = AsVMInt( HashItem(type) );		
		if ( [data isKindOfClass:[VMPP classForType:typ]] ) {
			//	type matched: go on!
			[data setWithData:hash];
		} else {
			//	type mismatch: re-allocate with correct type.
			//	when upper-compatible
			BOOL isUpperCompatible = [self is:typ upperCompatibleOf:data.type];
			
			NSLog(@"---ConvertTypeOf:%@ %@ - > %@ %@", 
				  dataId,
				  [self->shortTypeStringForType item:VMIntObj(data.type)],
				  [self->shortTypeStringForType item:VMIntObj(typ)],
				  isUpperCompatible ? @"OK" : @"incompatible"
				  );
			if ( isUpperCompatible) {
				VMData *d = [VMPP dataWithType:typ];
				[d setWithProto:data];		//	copy original data (with wrong type) into d
				[d setWithData:hash];		//	then override with new given hash.
				[song.songData removeItem:dataId];
				if( d.shouldRegister ) {
					[self registerData:d];
					data = [self rawData:dataId]; 
				} else {
					data = d;
				}
			} else {
				//	type up-conversion:
				//	TODO: implement exceptions
				[data setWithData:hash];
			}
		}
	}
	return data;
}

#pragma mark chance inside selector

+ (VMChance*)createOrModifyChanceWithId:(VMSelector*)		selector
								 target:(VMId*)				targetId 
								  score:(VMFloat)			score
								tagList:(VMId*)				tagListId {
	
	VMChance 	*reader = ARInstance(VMChance);	
	[reader setWithData:targetId];
	
	VMId *chanceId
	= [self idWithVMPModifier:selector.id 
						  tag:@"chance"
						 info:[NSString stringWithFormat:@"%@-%@",
							   reader.targetId,	reader.scoreDescriptor ]];
	
	//	remove original targetId entry
	if ( chanceId != targetId )
		[selector.cues deleteItemWithValue:targetId];
	
	//	
	[selector feedEvaluator];
	
	VMChance *ch = [selector chanceWithId:chanceId];
	if (!ch) {
		VMString *newScoreDescriptor = (score 
										? [NSString stringWithFormat:@"%3.3f",score] 
										: reader.scoreDescriptor );
		ch = ARInstance(VMChance);
		[ch setWithData:
		 [VMHash hashWithObjectsAndKeys:
		  VMIntObj(vmObjectType_chance),		@"type",
		  chanceId,								@"id",
		  reader.targetId,						@"targetId",
		  newScoreDescriptor,					@"score",
		  nil]];
		if ( ! selector.cues ) selector.cues = ARInstance(VMArray);
		[selector.cues push:ch];
	} else {
		[DEFAULTPREPROCESSOR logWarning:@"Modifying score." withData:[ch description]];
		if( isnan( ch.primaryFactor ) ) 
			ch.primaryFactor = score;
		else
			ch.primaryFactor += score;
	}
	return ch;
}


/*
 id related
 */

#pragma mark dataId related utils

//
//	returns new id with VMPModifier attached
//
+ (VMId*)idWithVMPModifier:(NSString*)dataId tag:(NSString*)tag info:(NSString*)info {
	if( info )
		return [NSString stringWithFormat:@"%@|%@_%@", dataId, tag, info];
	else {
		return [NSString stringWithFormat:@"%@|%@",	dataId, tag];
	}
}

- (void)separateIdAndScoreDescriptor:(VMId*)cueId
							   outId:(VMId**)outId 
				  outScoreDescriptor:(VMId**)outScoreDescriptor {
	VMArray *comp = [VMArray arrayWithString:cueId splitBy:@"="];
	*outId = [comp unshift];
	if ( comp.count > 0 )
		*outScoreDescriptor = [comp join:@"="];
}

- (VMId*)purifiedId:(VMId*)cueId {
	VMId *purifiedId;
	
	if ( ! self->vmReservedCharacterSet ) {
		self->vmReservedCharacterSet 
		= [[NSCharacterSet characterSetWithCharactersInString:@""
			//
			//		".()@&+-~!^"						characters explicitly admitted to use.
			
			/**		guideline for using signs in id:		example:
			 *
			 *				+		extended				a_phrase+ (only accessible from same branch)
			 *				-		reduced					a_phrase- (smaller set)
			 *				+x		with					a_phrase+break
			 *				-i		index					a_phrase-2
			 *				~x		(bridge) to				a_phrase_~b_theme
			 *				~!x		(bridge) not to			a_phrase_~!b_theme
			 *				x~		(bridge) from			a_phrase_b_theme~
			 *				~~i		continued				a_phrase~~1
			 *				x&y		and						a_phrase~b&c
			 *				(xxx)	remark					a_phrase(provisory)
			 *				(x-y) 	route					a_phrase(aa-ab)
			 *				^x		optional				a_phrase^extension
			 *
			 *		following charcters are not useable as a filename in windows system:	< > : " / \ | ? *
			 *		: and / are not useable in osx.
			 *
			 *		btw, automatic generated sel/seq will be named in following format:
			 *				SEL	selector #					a_phrase_SEL1
			 *				SEQ	sequence #					a_phrase_SEQ1
			 *
			 *
			 */
			
			//		" "							space can be useful, but not always recommended, since you can't 
			//									specify ids with spaces included inside of a score-descriptor.
			//		":?/*"						characters you can use as id, but not for filename.
			//	    "_;|"						characters used for delimiting components of parts. ( therefore part of id )
			//	    "#"							'#'	is part of id unless it appears at the beginning of an id. ( abbreviation )	
			"="								//	character used for delimiting id and score descriptor. also used inside the score descriptor.
			"%><"							//	characters which appears in score descriptor but not allowed in id.
		    ",$[]{}'"						//	reserved for future use.
			] retain];
	}
	
	if ( Equal( [cueId substringToIndex:1], @"#" ) )	//	can not complete #
		[VMException raise:@"Can't purify abbreviated id." format:@"id: %@",cueId];
	
	NSScanner *sc = [NSScanner scannerWithString:cueId];
	[sc scanUpToCharactersFromSet:self->vmReservedCharacterSet intoString:&purifiedId];
	if ( purifiedId.length != cueId.length ) return purifiedId;
	return nil;
}

- (BOOL)isAutogenaratedId:(VMId*)cueId {	
	VMArray *c = [VMArray arrayWithString:cueId splitBy:@"|"];
	return [c count] > 1;
}

- (VMId*)completeId:(VMId*)dataId withParentId:(VMId*)parentId {
	if( ! [dataId hasPrefix:@"#"] ) return nil;
	
	VMString *idPart, *scoreDescriptor = nil;
	
	[self separateIdAndScoreDescriptor:dataId outId:&idPart outScoreDescriptor:&scoreDescriptor];
	
	VMCue *data = ARInstance(VMCue);
	data.id = idPart;
	
	VMCue *parent = ARInstance(VMCue);
	parent.id = parentId;
	
	if ( ! data.partId     ) 
		data.partId 	= parent.partId;
	
	if ( ! data.sectionId  ) 
		data.sectionId	= parent.sectionId;
	
	if ( [ data.trackId hasPrefix:@"_" ] ) 
		data.trackId = [parent.trackId stringByAppendingString:( data.trackId.length > 1 ? data.trackId : @"" ) ];
	
	return scoreDescriptor ? [data.id stringByAppendingFormat:@"=%@", scoreDescriptor] : data.id;
}



/*
 accessor
 */

#pragma mark database accessor

- (id)data:(VMId*)dataId {
	return [song data:dataId];	
}

- (id)rawData:(VMId*)dataId {
	return [song.songData item:dataId];
}

- (void)setData:(id)data withId:(VMId*)dataId {
	VMId *purifiedId = [self purifiedId:dataId];
	if ( purifiedId ) {
		[VMException raise:@"Attempted to set data with un-purified id into songData." 
					format:@"id: %@ (should be %@)", dataId, purifiedId ];
	}
	[song.songData setItem:data for:dataId];
}

- (void)renameData:(VMData*)data newId:(VMId*)newId {
	VMId *oldId = [data.id copy];
	[song.songData renameKey:oldId to:newId];
	data.id = newId;
	[oldId release];
}

//--------------------------------------------------------------------------
//
//				the variable music preprocessor
//
//--------------------------------------------------------------------------

#pragma mark -
#pragma mark *** the variable music preprocessor ***
#pragma mark -

#pragma mark preprocessor utils
/*
 preprocessor utils
 */


//------------ Register Data and Alias, mark Unresolved ----------------

- (void)registerData:(VMData*)d {
	if( !d ) return;
	[self setData:d withId:d.id];
}

- (void)unRegister:(NSString *)dataId {
	[song.songData removeItem:dataId];
}

- (void)registerAliasOfCue:(VMData*)d as:(VMId*)aliasId {
	if ([self rawData:aliasId]) {
		[self logError:@"The dataId specified for alias was already registered."
			  withData:aliasId];
	} else {
		VMReference *alias = ARInstance(VMReference);
		alias.id = aliasId;
		alias.referenceId = d.id;
		[self registerData:alias];
	}
}

- (void)makeAlias:(VMData*)data changeIdTo:(VMId*)newId {
	VMId *oldId = [data.id copy];
	[self renameData:data newId:newId];
	[self registerAliasOfCue:data as:oldId];
	[oldId release];
}

- (void)markUnresolved:(NSString*)key {
	if ( [self rawData:key] ) return;	//	data already registered.
	VMUnresolved *u = ARInstance(VMUnresolved);
	u.id = key;
	[self setData:u withId:key];
}



//----------------------- Logging and Alert ------------------------------

#pragma mark -
#pragma mark log and alerts
- (void)addLog:(id)logPart {
	IfClassMatch(logPart, VMArray) {
		[self->log_ append:logPart];
	} else {
		if ( ! self->log_ ) self->log_ = ARInstance(VMArray);
		if(logPart) [self->log_ push:logPart];
	}
}

- (void)logWarning:(NSString *)messageFormat withData:(NSString *)data {
	NSString* message = [NSString stringWithFormat: @"Warning: %@:%@", messageFormat, data];
	[self addLog:message];
}

- (void)logError:(NSString*)messageFormat withData:(NSString*)data {
	NSString* message = [NSString stringWithFormat: @"Error: %@:%@\n", messageFormat, data];
	[self addLog:message];
	++fatalErrors;
}



//	-----------------	data dump   -----------------

#pragma mark -
#pragma mark data dump

- (NSString*)detailedDescription:(VMData*)data 
					 indentDepth:(int)indentDepth 
			   skipAutogenerated:(BOOL)skipAutogenerated {
	NSString *result = nil;
	
	NSString *indentString = [@"                                          " substringToIndex:indentDepth * 2];
	VMCue *cue = ClassCastIfMatch( data, VMCue );
	
	switch ( data.type ) {
		case vmObjectType_audioInfo: {
			if( [self isAutogenaratedId:data.id] && skipAutogenerated ) break;
			VMAudioInfo *ai = ClassCast( data, VMAudioInfo );
			result = [NSString stringWithFormat:@"%@%@",
					  indentString, [ai description]];
			break;
		}
			
		case vmObjectType_audioCue: {
			if ( cue.VMPModifier && skipAutogenerated ) break;
			VMAudioCue  *ac = ClassCast( cue, VMAudioCue );
			VMAudioInfo *ai = [self data:ac.audioInfoId];
			result = [NSString stringWithFormat:@"%@%@\n%@  %@",
					  indentString, [ac description], 
					  indentString, [ai description]];
			break;
		}
			
		case vmObjectType_sequence: {
			
			VMSequence *seq = ClassCast( cue, VMSequence );
			VMArray *descArr = ARInstance(VMArray);
			
			for ( id subCue in seq.cues ) {
				VMCue *d = ( ClassMatch( subCue, VMId ) 
							? [self data: subCue] 
							: subCue );
				
				if ( ! d.VMPModifier ) {
					[descArr push:[NSString stringWithFormat:@"%@  %@", indentString, d.id]];
				} else {
					[descArr push:[self detailedDescription:d indentDepth:indentDepth +1 skipAutogenerated:NO]];
				}
			}
			result = [NSString stringWithFormat:@"%@SEQ<%@>(%ld) {\n%@\n} -> %@",
					  indentString, 
					  seq.id, seq.length,
					  [descArr join:@"\n"],
					  [[seq subsequent] description]
					  ];
			
			break;
		}
			
		default:
			result = [NSString stringWithFormat:@"%@%@",
					  indentString, [data description]];
			break;
	}	
	return result;
}


- (void)dataDump {
	//	data dump
	NSLog(@"---------------- DATA DUMP ----------------");
	
	VMArray *lines = NewInstance(VMArray);
	VMArray *keys = [self.song.songData sortedKeys];
	for ( NSString *key in keys ) {
		id val = [self.song.songData item:key];
		VMData *data = ClassCastIfMatch( val, VMData );
		if( data ) {
//			if ( [ data.id isEqualToString:@"r_sel_A" ] )
//				NSLog(@"!!!");

			val = [self detailedDescription:data indentDepth:0 skipAutogenerated:YES];
		} else if( ClassMatch(val, VMHash) || ClassMatch(val, VMArray )) {
			val = [val description];
		}
		if( val ) [lines push:[NSString stringWithFormat:@"%@",val]];
	}
	NSLog( @"\n%@", [lines join:@",\n"] );
	[lines release];	
}

/*-------------------------------------------------------------------------
 
 pre-processing  vms data
 
 -------------------------------------------------------------------------*/
#pragma mark -
#pragma mark ---> preprocess entry <---

- (void)preprocess:(NSString*)vmsText {
	
	
	
	/*	test code for score evaluator * /
	 VMScoreEvaluator *se = [[[VMScoreEvaluator alloc] init] autorelease];
	 
	 NSLog(@"%@", [[se parseFunction:@"@F{abc}"] description] );
	 NSLog(@"%@", [[se parseFunction:@"@FC"] description] );
	 
	 VMHash *vars = [VMHash hashWithObjectsAndKeys:VMFloatObj(3),@"C",VMFloatObj(0.5),@"tagA",nil];
	 se.variables = vars;
	 
	 VMFloat result = [se evaluate:@"(1+(2*(3+1)))*2"];
	 
	 NSLog(@"result:%f",result);
	 */
	
	
	//
	//	(1.00)	format text-file and make json
	//
	VMHash *vmsHash = [self preprocessPhase1:vmsText];	
	VMArray *dataArray = [VMArray arrayWithArray: [vmsHash item:@"data"]];
	
	//
	//	(2.00)	pre-process hash 
	//
	[self preprocessPhase2:dataArray];
	//
	//	(2.90)	scan song properties
	//
	[song setByHash:vmsHash];
	
	[self preprocessPhase3:dataArray];
	
	//	(4.30)	set audioInfoRef in audioCue-s
	[self preprocessPhase4];
	
#ifdef DEBUG
	//[self dataDump];
	
	if ([self.log count] > 0) {
		NSLog(@"---------------- LOG ----------------");
		for ( VMString *line in self.log ) {
			NSLog( @"%@",line );
		}
		
		if ( fatalErrors > 0 ) {
			[VMException raise:@"VMPreprocoessor error:"
						format:@"Error while preprocessing. see log out for details."];			
		}
		NSLog(@"-------------------------------------");
		
	}
	NSLog(@"\n\n\n\n\n");
#endif
}

#pragma mark -
#pragma mark (1) text-file formatting phase 

//------ text-file formatting phase (1) ------------------------------------
- (VMHash*) preprocessPhase1:(NSString*)data {
	
	NSMutableString *ms = [NSMutableString stringWithString:data];
	
	//
	//	(1.00) 	vmp file must be json-ified. 	#1: strip comments
	//
	//	[VMTextPreprocessor stripCommentsAndCRLF:ms];		done by VMPJSON scanner ss121210
	
	//
	//	(1.01)	shorten key-names like selector: or sequence: to sel: and seq:
	//
	[VMTextPreprocessor replaceKeyNamesIn:ms with:shortKeyword];
	
	//
	//	(1.02) 	vmp file must be json-ified.	#2:	put property names into double quote
	//
	//	[VMTextPreprocessor putPropertyNames:propNames IntoDoubleQuote:ms];		VMPJSONScanner does accept string constants without double quotes. ss121210
	
	//
	//	(1.90) 	scan json and make dictionary.
	//
	return [self scanJSON:ms];
}

- (VMHash*) scanJSON:(NSString*)data {
	NSError *outError = [[[NSError alloc] init] autorelease];
    VMPJSONDeserializer *decoder = [[VMPJSONDeserializer alloc] init];
    NSDictionary *dict = [decoder deserializeAsDictionary:[data dataUsingEncoding:vmFileEncoding] error:&outError];
	[decoder release];
	return [VMHash hashWithDictionary:dict];
}


#pragma mark -
#pragma mark (2) hash formatting phase 
//----- hash formatting phase (2) ----------------------------------- 
- (void)preprocessPhase2:(VMArray*)dataArray {
	
	VMInt c = [dataArray count];
	for( int p = 0; p < c; ++p ) {
		//
		//	(2.00) 	data array must be mutable
		//
		id d = [dataArray item:p];
		if ( ClassMatch(d, NSDictionary)) {
			d = [VMHash hashWithDictionary:d];
			[dataArray setItem:d at:p];
		}
		VMHash *hash = d;
	
		
		//
		//	(2.10) 	all data must have it's own type
		//	(2.20) 	remove type specific dialects like selector: or layer: 
		//	and replace with cues:  
		//	(except alternatives in sequence and layer)
		//	scan cues recursively
		//
		[self guessTypeAndCleanUpTypeSpecificDialects:hash];
		
		
		//	(2.40)	flatten tree-formed object structure (i.e cues)
		VMArray *flattened = nil;
		[self flattenTreeStructure:hash into:&flattened];
		if( flattened ) {
			[dataArray insertArray:flattened at:p];
			--p;	//	want to process the fresh inserted data.
			c += [flattened count];
		}
		
		//
		//	(2.50) resolve shortcuts in	arrays 'cues', 'alt' and 'subseq'  
		//
		[self completeIdsInsideHash:hash];
		//
		//	(2.80)	add myself into alternatives
		//
		//[self addMyselfIntoAlternatives:hash];	abolished
	}
	
}

//	(2.10) 	all data must have it's own type

#define GuessTypeFromHash(prop,type) if (HashItem(prop)) { typ=vmObjectType_##type;	break;	}


- (vmObjectType) guessType:(VMHash*)hash {
	
	//	read type if specified
	IfHashItemExist(type, 
					IfClassMatch(HASHITEM, VMString) {
						return AsVMInt([self->typeForTypeString item:HASHITEM]);
					} else {
						return AsVMInt(HASHITEM);
					}
					)
	
	//	guess type
	
	vmObjectType typ = vmObjectType_unknown;
	
	for(;;) {	//	dummy block
		//	runtime types
		GuessTypeFromHash(cuePosition, player)	//	NOTE: currently, there is no way to sort out VMLiveData from VMPlayer
		
		//	static song structures
		GuessTypeFromHash(sel, selector)	//	prefer sel before seq.
		GuessTypeFromHash(subseq, sequence)
		GuessTypeFromHash(seq, sequence)
		GuessTypeFromHash(lay, layerList)
		GuessTypeFromHash(cues, cueCollection)
		
		//	chances and modifiers
		GuessTypeFromHash(targetId, chance)
		GuessTypeFromHash(parameter, function)
		GuessTypeFromHash(audioInfoId, audioCue)
		GuessTypeFromHash(modifiers, stimulator)
		GuessTypeFromHash(factor, scoreModifier)
		GuessTypeFromHash(tag, tagList)
		
		//	audio
		GuessTypeFromHash(original, audioModifier)
		GuessTypeFromHash(dur, audioInfo)
		GuessTypeFromHash(ofs, audioInfo)
		GuessTypeFromHash(volume, audioInfo)
		
		//	meta
		GuessTypeFromHash(instruction, metaCue)
		
		//	base
		GuessTypeFromHash(ref, reference)
		GuessTypeFromHash(id, data)
		break;
	}
	
	if( typ != vmObjectType_unknown ) 
		SetHashItem(type, VMIntObj(typ));
	else {
		[self logError:@"Could not resolve object type for:%@" 
			  withData:[hash description]];
		VMId *did = HashItem(id);
		if (did) [self markUnresolved:did];
	}
	
	return typ;
}

//	(2.20)	remove type specific dialects like selector: or layer: and replace with cues:  
//	(leave alternatives in sequence and layer)
- (id) guessTypeAndCleanUpTypeSpecificDialects:(id)inObject {
	VMArray	*arrObj 	= ReadAsVMArray(inObject);
	VMHash 	*hashObj 	= ReadAsVMHash(inObject);
	
	if ( arrObj ) {
		VMInt c = [arrObj count];
		for ( VMInt i = 0; i <c; ++i ) {
			//	look for nested data
			id p = [self guessTypeAndCleanUpTypeSpecificDialects:[arrObj item:i]];
			if (p) [arrObj setItem:p at:i];
		}
		return arrObj;
		
	} else if ( hashObj ) {
		[self guessType:hashObj];
		VMArray *keys = [hashObj keys];
		for ( NSString *key in keys ) {			
			//	look for nested data
			id p = [self guessTypeAndCleanUpTypeSpecificDialects:[hashObj item:key]];
			if (p) [hashObj setItem:p for:key];
			
			//	remove dialects
			if ( [dialects item:key] )
				[hashObj renameKey:key to:[dialects item:key]];
		}
		return hashObj;
	}
	return nil;
}


//	(2.40)	flatten tree structure (cues)

//	subs
- (VMId *)generateOrCompleteId:(VMHash *)hash
					  parentId:(VMId *)parentId 
					  position:(VMInt)position 
						  type:(vmObjectType)type {
	
    VMId *objId = HashItem(id);
	
    if ( ! objId ) {			//	autogenerate id for unnamed objects
		if ( Equal( HashItem(fileId), @"space" ) ) 
			objId = [NSString stringWithFormat:@"%@_%@%ld", parentId, @"SPC", 									(position+1)];
		else
			objId = [NSString stringWithFormat:@"%@_%@%ld", parentId, [shortTypeStringForType item:VMIntObj(type)], (position+1)];
		SetHashItem(id, objId);
    } else if( parentId ) {		//	try to complete:
        VMId *comp = [self completeId:objId withParentId:parentId];
        if( comp ) {
            objId = comp;
            SetHashItem(id, objId);
        }
    }
    return objId;
}

/*----------------------------
 type specific exceptions:
 ----------------------------*/
- (void)typeSpecificExceptions:(VMHash *)hash 
						type_p:(vmObjectType *)type_p 
			  parentDataToCopy:(VMHash *)parentDataToCopy {
    //	don't place bare audioInfo in a selector/sequence
    if ( *type_p == vmObjectType_audioInfo ) {
		*type_p = vmObjectType_audioCue;
		SetHashItem(type, VMIntObj(*type_p));
	}
    
    //	upgrade selector or audioCue to sequence if subseq was supplied.
    if ( [parentDataToCopy item:@"subseq"] 
        && ( *type_p==vmObjectType_selector || *type_p == vmObjectType_audioCue )) {
        *type_p = vmObjectType_sequence;
		SetHashItem(type, VMIntObj(*type_p));
    }
}

- (VMArray*)flattenObjectsIn:(VMArray*)array 
						  to:(VMArray**)flattened 
				withParentId:(VMId*)parentId 
			  copyParentData:(VMHash*)parentDataToCopy {
	VMInt c = [array count];
	for( VMInt i = 0; i < c; ++i ) {
		id obj = [array item:i];
		if ( ClassMatch( obj, VMId )) {
			continue;	//	* discussion:	shall we copy parentDataToCopy to the referred object ??
		}
		
		VMArray *rawArray 	= ReadAsVMArray(obj);
		VMHash 	*hash 		= ReadAsVMHash(obj);
		
		if ( rawArray ) {
			//	assume raw array inside cues as selector
			hash = ARInstance( VMHash );
			SetHashItem(sel, rawArray);
			SetHashItem(type, VMIntObj(vmObjectType_selector));
		}
		
		if ( hash ) {
			
			//	add parentDataToCopy to hash.
			[hash deepMerge:parentDataToCopy];
			
			vmObjectType type = [self guessType:hash];
			
			//	process type specific exceptions
            [self typeSpecificExceptions:hash type_p:&type parentDataToCopy:parentDataToCopy];
			
			//	new id
            VMId *objId = [self generateOrCompleteId:hash parentId:parentId position:i type:type];
			
			SetHashItem(id, objId);
			
			//	move obj into flattened and replace array member with object id.
			if( ! *flattened ) *flattened = ARInstance(VMArray);
			[*flattened push:hash];
			
			
			if( HashItem(score) )	
				objId = [NSString stringWithFormat:@"%@=%@", objId, HashItem(score) ];		//	
			
			[array setItem:objId at:i];
			
			//	note: the flattened hash will be re-scanned in the next iteration of pre-process phase 2
		}
	}
	return array;
}

//	main
- (void) flattenTreeStructure:(VMHash*)hash into:(VMArray**)flattened {
	
	VMHash *parentDataToCopy = ARInstance(VMHash);
	vmObjectType type = [self guessType:hash];
	
	VMId *objId = HashItem(id);
	
/*	if ( Equal(objId, @"a_14_~F;sel") )
		NSLog(@"dd");
*/	
	if (HashItem(cues)) {
		if( type==vmObjectType_selector && HashItem(subseq) ) {//	if a selector has subseq data, distribute them into sub-cues
			if( ! Equal( HashItem(subseq),@"*" )) CopyHashItem(subseq, hash, parentDataToCopy);
		}
		SetHashItem(cues, 
					[self flattenObjectsIn:ConvertToVMArray( HashItem(cues) ) 
										to:flattened 
							  withParentId:objId
							copyParentData:parentDataToCopy ]);	
	}
	if (HashItem(alt)) {
		CopyHashItem(instruction, 	hash, 	parentDataToCopy);	//	alternatives will have the same instructions
		CopyHashItem(subseq, 		hash, parentDataToCopy);	//	distribute parent's subseq into alt
		SetHashItem(alt, 
					[self flattenObjectsIn:ConvertToVMArray( HashItem(alt) )
										to:flattened 
							  withParentId:objId
							copyParentData:parentDataToCopy ]);
	}
	if (HashItem(subseq)) {
		SetHashItem(subseq, 
					[self flattenObjectsIn:ConvertToVMArray( HashItem(subseq) )
										to:flattened 
							  withParentId:objId
							copyParentData:nil ]);
	}
}


//	(2.50) resolve shortcuts in	arrays 'cues', 'alt' and 'subseq'  

//	sub
- (VMArray *)completeIdsInsideArray:(VMArray *)ary withId:(VMId*)parentId {
	VMInt c = [ary count];
	for ( int i = 0; i < c; ++i ) {
		id oid = [ary item:i];
		IfClassMatch(oid,VMId) {
			VMId *cmp = [self completeId:oid withParentId:parentId];
			if( cmp ) 
				[ary setItem:cmp at:i];
		}
		IfClassMatch(oid, VMCue) {
			VMId *cmp = [self completeId:ClassCast(oid,VMCue).id withParentId:parentId];
			if( cmp ) ClassCast(oid,VMCue).id = cmp;
		}
	}
	return ary;
}

//	main
- (void)completeIdsInsideHash:(VMHash*)hash {
	VMId *objid = HashItem(id);
	VMId *compId;
	
	IfHashItemExist(ref,
					compId = [self completeId:HASHITEM withParentId:objid];
					if( compId ) SetHashItem(ref,	compId );
					)
	IfHashItemExist(clone,
					compId = [self completeId:HASHITEM withParentId:objid];
					if( compId ) SetHashItem( clone, compId );
					)
	
	IfHashItemExist(cues, 	SetHashItem(cues, 	[self completeIdsInsideArray:ConvertToVMArray( HASHITEM ) withId:objid] );)
	IfHashItemExist(alt, 	SetHashItem(alt, 	[self completeIdsInsideArray:ConvertToVMArray( HASHITEM ) withId:objid] );)
	IfHashItemExist(subseq,	SetHashItem(subseq, [self completeIdsInsideArray:ConvertToVMArray( HASHITEM ) withId:objid] );)
	IfHashItemExist(seq,	SetHashItem(seq, 	[self completeIdsInsideArray:ConvertToVMArray( HASHITEM ) withId:objid] );)
	IfHashItemExist(layer,	SetHashItem(kayer, 	[self completeIdsInsideArray:ConvertToVMArray( HASHITEM ) withId:objid] );)
}

#pragma mark -
#pragma mark (3) object creation phase


//----- object creation phase (3) ------------------------------------------
- (void)preprocessPhase3:(VMArray*)cueArray {
	
	//	---------------	iteration 3.0 -------------------
	for ( VMHash *hash in cueArray ) {
		VMData *data = nil;
		vmObjectType typ = vmObjectType_unknown;
		if ( [ HashItem(id) isEqualToString:@"r_sel_A" ] )
			NSLog(@"!!!");
		
		VMId *cloneTarget = HashItem(clone);
		if ( cloneTarget ) {
			//
			//	clone another object and overwrite.
			//
			data = [VMPreprocessor dataWithData: [self rawData:cloneTarget]];
			if ( !data ) 
				[VMException raise:@"Could not clone object" format:@"No data found for %@.", cloneTarget];
			[data setWithData:hash];
			if (data.shouldRegister) [self registerData:data];
			typ = data.type;
		} else {
			typ = AsVMInt( HashItem(type));
			if ( typ == vmObjectType_unknown ) continue;	//	just ignore data of unknown type. we have already thrown an error at phase 2.
			
			//
			//	find or create object.
			//
			data = [self findOrCreateNewObjectWithHash:hash];
		}
		
				
		//
		//	(3.10)	if tag was specified as an array, convert them into tagList
		//
		VMTagList *tl =
		[self convertTagsIntoTagList:hash];
		
		//	
		//	(3.11)	register tagList for non-chance objects.
		//	(this will be added later to chance)
		
		VMId *tagListId = Default(HashItem(tagListId), ( tl ? tl.id : nil ));
		
		if( tagListId && typ != vmObjectType_chance ) 
			[self cacheTagListIdForCueId:data.id tagListId:tagListId];
		
		
		//
		//	(3.31)	if a sequence or layer has no cueCollection, create one from id.
		//
		if ( typ == vmObjectType_sequence || typ == vmObjectType_layerList ) {
			[self createCollectionIfItDoesNotHave:ClassCast(data, VMCueCollection)];
		}
		
		//
		//	(3.40)	if audioInfo related key is supplied, create audioInfo and set audioInfoId
		//
		[self createAudioInfoFromCue:data ifInfoProvidedBy:hash];
		
		//
		//	(3.41) 	if audioInfoId was supplied, a cue (cue obj or cue inside sequence) should be audioCue
		//
		[self convertCue:&data withAudioInfoIdIntoAudioCues:hash];
		
		//
		//	(3.42)	if an audioInfo is placed bare in a sequence or selector, wrap it by an audioCue
		//
		if ( ClassMatch(data, VMCueCollection) ) 
			[self wrapAudioInfoInsideCueCollectionByAudioCue:ClassCast(data, VMCueCollection)];
		
		//
		//	(3.50)	if the object has "alt" (alternatives), it has to wrapped by a selector.
		//			for each alternative, clone myself and register to make it ready for overwrite.
		//
		VMSelector *sel = [self wrapCue:data withSelectorIfNeeded:hash];
		
		//
		//	(3.55)	all id's in a selector must be converted into chances, btw, selectors should have instructions
		//
		if( ClassMatch(data, VMSelector) ) [self convertCuesToChances:ClassCast(data, VMSelector)];
		if( ClassMatch(data, VMSequence) ) [self convertCuesToChances:ClassCast(data, VMSequence).subsequent];
		if(sel) [self convertCuesToChances:sel];	
		
		//
		//	(3.60)	all chance-targets (don't forget sequence's subsequent) should be registered at least as Unresolved
		//
		//[self markUnresolvedChanceTargets:(VMSelector*)sel];		IMPLEMENT LATER
		
		//
		//	(3.90)	register entrypoints
		//
		VMString *entryPoint = HashItem(entryPoint);
		if( Equal(entryPoint,@"YES" )) {
			VMCue *c = ClassCastIfMatch( data, VMCue );
			if( c ) { 
				[self registerEntryPoint:c];
			} else {
				[self logError:@"Invalid entryPoint" withData:data.description];
			}
		}
		
		// - (void)					markUnresolvedChanceTargets:(VMSelector):sel;
		//	(3.90)	check unresolved objects
    }
}

//	
//	(3.10)	if tags was specified as array, convert them into tagList
- (VMTagList*) convertTagsIntoTagList:(VMHash*)hash {
	VMTagList *tl = nil;
	id tags = ConvertToVMArray(HashItem(tags));
	if ( tags ) {
		tl = ARInstance(VMTagList);
		tl.tagArray = tags;
		tl.id = [VMPP idWithVMPModifier:HashItem(id)
									tag:@"tagList" info:nil];
		[self registerData:tl];
	}
	return tl;
}


//
//	tagListId cache
//
- (VMHash*)tagListIdCache {
	VMHash *d = [self rawData:@"VMP|TagListCache"];
	if (!d) {
		d = ARInstance(VMHash);
		[self setData:d withId:@"VMP|TagListCache"];
	}
	return d;
}

//	(3.11)	register tagList for non-chance objects. (this will be added later to chance)
- (void)cacheTagListIdForCueId:(VMId*)cueId tagListId:(VMId*)tlId {
	[[self tagListIdCache] setItem:tlId for:cueId];
}

- (VMId*)tagListIdForCueId:(VMId*)cueId {
	return [[self tagListIdCache] valueForKey:cueId];
}

//
//	(3.31)	if a sequence or layer has no cueCollection, create one from id.
//
- (void) createCollectionIfItDoesNotHave:(VMCueCollection*)collection {
	if( collection.cues && [collection.cues count] > 0 ) return;
	collection.cues = ARInstance(VMArray);
	VMId *cueId 	= [VMPP idWithVMPModifier:collection.id tag:@"cue" info:nil];
	
	//	make cue
	[collection.cues push:cueId];
	VMCue *cue		= ARInstance( VMCue );
	cue.id = cueId;
	[self registerData:cue];
}

//
//	(3.40)	if audioInfo related key is supplied, create audioInfo
//
- (VMAudioInfo*)createAudioInfoFromCue:(VMData*)data ifInfoProvidedBy:(VMHash*)hash {
	VMCue *c  = ClassCastIfMatch(data, VMCue);
	if( ! c || c.type == vmObjectType_audioInfo ) return nil;
	
	if ( HashItem(audioInfo)) {
		id aiObj = HashItem(audioInfo);
		IfClassMatch(aiObj, NSString) {
			[hash renameKey:@"audioInfo" to:@"audioInfoId"];
		} else {
			hash = ReadAsVMHash( aiObj );
		}
	}
	
	if ( ! ( HashItem(dur) || HashItem(ofs) || HashItem(volume) || HashItem(fileId))  ) return nil;
	
	VMId *aiId = Default( HashItem(audioInfoId),
						 [VMPP idWithVMPModifier:[c userGeneratedId] tag:@"audioInfo" info:nil]);
	
	VMAudioInfo *ai = [self data:aiId];
	if( ! ai ) 
		ai = ARInstance(VMAudioInfo);
	else {
		//	overwrite warning.		
		[self logWarning:@"Overwriting audioInfoId: %@" withData:aiId];
	}
	
	[ai setWithData:hash];	//	overwrite.
	ai.id = aiId;
	
	//	register audioInfo
	[self registerData:ai];
	
	//	set audioInfoId and cleanUp hash.	
	SetHashItem(audioInfoId, ai.id );
	if (HasMethod(data, audioInfoId)) [((id)data) setAudioInfoId:aiId];
	
	[hash removeItem:@"dur"];
	[hash removeItem:@"ofs"];
	[hash removeItem:@"fileId"];
	[hash removeItem:@"volume"];
	
	return ai;
}

//
//	(3.41) 	if audioInfoId was supplied, a cue (cue obj or cue inside sequence) should be audioCue
//
- (void)convertCue:(VMData**)data_p withAudioInfoIdIntoAudioCues:(VMHash*)hash {
	VMId *aiId = HashItem(audioInfoId);
	if( aiId ) {	
		//	(3.41) 	if audioInfoId was supplied, a cue (cue obj or cue inside sequence) should be audioCue
		VMArray *cueIdsToConvert = nil;
		
		if( (*data_p).type == vmObjectType_cue )
			cueIdsToConvert = [VMArray arrayWithObject:(*data_p).id];
		else
			if( (*data_p).type == vmObjectType_sequence )
				cueIdsToConvert = [ClassCast(*data_p, VMSequence) cues];
		
		if(! cueIdsToConvert ) return;
		
		for ( id idObj in cueIdsToConvert ) {
			VMCue 		*cue 	= [self data:ReadAsVMId(idObj)];
			VMAudioCue 	*ac		= ClassCastIfMatch(cue, VMAudioCue);
			if( ! ac ) {
				//	check if it is compatible
				if ( ! [self is:vmObjectType_audioInfo upperCompatibleOf:cue.type] ) {
					[VMException raise:@"Can not convert into audioInfo." 
								format:@"%@ has audioInfo related data %@, but not compatible with them.",
					 cue.id,
					 [hash description]
					 ];
				}
				
				//	make audioCue.
				ac = ARInstance( VMAudioCue );
				[ac setWithProto:cue];
				ac.id = ReadAsVMId(idObj);
			}
			ac.audioInfoId = aiId;	//	we use the same audioInfoId for all cues in sequence.	when overvrite, we must make a copy of them.
			[self registerData:ac];
			if ( Equal( (*data_p).id, cue.id ) ) data_p = &cue;	//	replace data with audioCue
		}
	}
}

//
//	(3.42)	if an audioInfo is placed bare in a sequence or selector, wrap it by an audioCue
//
- (void)wrapAudioInfoInsideCueCollectionByAudioCue:(VMCueCollection*)cc {
	VMInt c = cc.cues.count;
	for ( VMInt i = 0; i < c; ++i ) {
		id d = [cc.cues item:i];
		if ( ClassMatch( d, VMId ) ) d = [self data:d];
		if ( ! ClassMatch( d, VMAudioInfo ) ) continue;
		
		VMAudioCue 	*ac = ARInstance( VMAudioCue );
		VMAudioInfo *ai = d;
		ac.audioInfoId = ai.id;
		ac.id = [VMPreprocessor idWithVMPModifier:ai.userGeneratedId tag:@"cue" info:nil];
		[self registerData:ac];
		[cc.cues setItem:ac.id at:i];
	}
}




//
//	(3.50)	if the object has "alt" (alternatives), it has to wrapped by a selector.
//			for each alternative, clone myself and register to make it ready to overwrite.
//


//	subs:

- (VMCue*)cloneCue:(VMCue*)cue newId:(VMId*)newId {
	VMCue *clone = [VMPP dataWithData:cue];
	clone.id = newId;
	return clone;
}

- (void)cloneAudioInfo:(VMCue *)cue newId:(VMId *)newId {
	VMAudioCue *ac = ClassCastIfMatch( cue, VMAudioCue );
	if ( ! ac ) return;
	
	VMId *cloneId = [VMPP idWithVMPModifier:newId tag:@"audioInfo" info:nil];
	if ( [self data:cloneId] ) return;	//	audioInfo already exist.
	
	//	code below should safe when subAudioInfo is nil.
	VMAudioInfo	*originalAI = [self data:ac.audioInfoId];
	VMAudioInfo *clonedAI	= [VMPP dataWithData:originalAI];
	clonedAI.id = cloneId;
	[self registerData:clonedAI];
	ac.audioInfoId = clonedAI.id;
}

- (VMCue*)cloneAutogeneratedCue:(VMCue*)cue newId:(VMId*)newId {
	VMCue *clonedCue = [self cloneCue:cue 
								newId:[VMPP idWithVMPModifier:newId 
														  tag:@"cue" 
														 info:nil]];
	
	IfClassMatch( clonedCue, VMAudioCue ) 
	[self cloneAudioInfo:clonedCue newId:newId];
	
	[self registerData:clonedCue];
	return clonedCue;
}

//	wrap cue main:

- (VMSelector*)	wrapCue:(VMData*)original withSelectorIfNeeded:(VMHash*)hash {
	id 		alt;
	if( original.type == vmObjectType_selector || (! ( alt = HashItem(alt) ) )) return nil;
	
	VMSelector *sel = ARInstance( VMSelector );	
	VMId *originalId 	= original.id;
	VMId *wrappedId 	= [VMPP idWithVMPModifier:originalId 
										   tag:@"selWrapped"
										  info:nil];
	sel.id = originalId;
	
	//	change data's id
	[self makeAlias:original changeIdTo:wrappedId];	//	alias will be overwritten later.
	
	//	for each alt: clone myself and register
	VMArray 	*alternatives 		= ConvertToVMArray( alt );
	BOOL 		needToAddMyself 	= YES;
	VMChance 	*chance;
	
	for ( id obj in alternatives ) {
		if (!ClassMatch(obj, VMId)) {	//	should not happen since we have flatten the data structure in phase 2.
			[VMException raise:@"Error while preprocessing vms." format:@"Unrecognizeable member(%@) found in alternatives of %@.", obj, originalId];
		}
		
		chance = NewInstance(VMChance);		
		[chance setWithData:ReadAsVMId(obj)];
		
		VMId *cueId 	= chance.targetId;		
		if ( Equal(cueId, originalId) ) {
			[sel.cues deleteItemWithValue:cueId];	//	remove from selector
			cueId = wrappedId;						//	change original's id
			needToAddMyself = NO;
		}
		
		VMCue *cue = [self data:cueId];				//	this is the alternative cue-object
		VMAudioInfo *audioInfo = ClassCastIfMatch(cue, VMAudioInfo);
		if( audioInfo ) {				//	it can happen that in-line specified cue has been interpreted as AudioInfo.
			//	generally, no AudioInfo should be placed bare in a cue container.
			[self renameData:cue newId:[VMPP idWithVMPModifier:cue.userGeneratedId tag:@"audioInfo" info:nil]];
			cue = nil;
		}
		
		if( !cue ) {
			VMAudioCue *audioCue = ClassCastIfMatch( original, VMAudioCue );
			if ( audioCue ) {
				if ( [self isAutogenaratedId:audioCue.id ] )
					cue = [self cloneAutogeneratedCue:audioCue newId:cueId];
			} 
			
			else 
				
			{
				
				cue = [VMPP dataWithData:original];		//	clone original
				
				VMSequence *sequence = ClassCastIfMatch( cue, VMSequence );
				if ( sequence ) {
					BOOL cueIsAutogenerated = ( [self isAutogenaratedId:[sequence cueAtIndex:0].id ] );
					
					if ( cueIsAutogenerated ) {	
						//	alt stands for alternate the original sequence itself:
						//	autogenerated audiocues inside sequence has to be cloned
						sequence.id = cueId;
						int p = 0;
						
						while( p < sequence.length ) {			//	for each sequence member in alternative.
							id aSequenceMember = [sequence.cues item:p];	//	don't use [sequence cueAtIndex] since it resolves dataObject.
							BOOL isObjRef = ClassMatch( aSequenceMember, VMData );
							VMId  *subCueId = isObjRef 
							? ClassCast( aSequenceMember, VMData ).id 
							: ClassCast( aSequenceMember, VMId ); 
							
							if ( [self isAutogenaratedId:subCueId] ) {
								VMCue *clonedCue;
								if( isObjRef )
									clonedCue = [self cloneAutogeneratedCue:aSequenceMember newId:cueId];	//should not happen, since we have flattened the data structure.
								else 
									clonedCue = [self cloneAutogeneratedCue:[self data:aSequenceMember] newId:cueId];
								
								//	we always set VMId into sequence menber. even if there was set an object before.
								[sequence.cues setItem:clonedCue.id at:p];
							}
							++p;
						}
					} else {
						//	alt stands for alternate the cue inside sequence:
						//	non-autogenarated audiocues inside sequence has to be replaced by alt
						sequence.id = [VMPP idWithVMPModifier:cueId tag:@"seqWrap" info:nil];
						sequence.cues = [VMArray arrayWithObject:cueId];
					}
				}
				[self registerData:cue];
			}
			
			
		}	//	end if ( ! cue )
		
		chance.targetId = cue.id;
		[sel addCuesWithData:chance];	//	add cue
		[chance release];
	}
	if ( needToAddMyself ) {
		chance = ARInstance(VMChance);
		VMArray *cues = ConvertToVMArray( HashItem(cues) );
		if (cues) {	//	try to read from cues arr
			[chance setWithData:ReadAsVMId( [cues item:0] ) ]; 
		} else {
			chance.scoreDescriptor=@"1";	//	nothing specified
		}
		chance.targetId = wrappedId;
		[sel addCuesWithData:chance];	//	add myself		
	}
	
	[self convertCuesToChances:sel];
	
	[self registerData:sel];	//	overwrite alias of original
	
	return sel;
}


//
//	(3.55)	all id's in selector must be converted into chances
//
- (void)convertCuesToChances:(VMSelector*) selector {
	for ( id obj in selector.cues ) {
		IfClassMatch(obj, VMChance) continue;
		VMId *cueId = ReadAsVMId(obj);
		[VMPP createOrModifyChanceWithId:selector 
								  target:cueId
								   score:0
								 tagList:nil];
	}
}

//	(3.90)	register entrypoints
- (void)registerEntryPoint:(VMCue*)cue {
	[song.entryPoints pushUnique:cue.id];
}


#pragma mark -
#pragma mark (4) object optimization phase 

//----- object optimization phase (4) ------------------------------------------

- (void)preprocessPhase4 {
	
	VMArray *keys = [song.songData keys];
	for ( VMId *did in keys ) {
		if ( Equal( [did substringToIndex:4], @"VMP|" )) continue;	//	no VMData
		VMData *c = [self data:did];
		
		//	(4.30)	set audioInfoRef in audioCue-s
		if ( c.type == vmObjectType_audioCue ) {
			[self setAudioInfoRefInAudioCues:ClassCast(c, VMAudioCue)];
		}
	}
}

//	(4.10)	copy tagLists attached to non-chance objects to chances targeting it.
- (void)copyTagListsOfTargets:(VMSelector*)selector {
	//	IMPLEMENT LATER
}


//	(4.30)	set audioInfoRef in audioCue-s
- (void)setAudioInfoRefInAudioCues:(VMAudioCue*)audioCue {
	VMAudioInfo *ai = [self data:audioCue.audioInfoId];
	if (ai) 
		audioCue.audioInfoRef = ai;
	else
		[self logError:@"AudioInfo not found for:" withData:[audioCue description]];
}



//	(4.80)	check unresolved objects
- (void) throwErrorIfUnresolved:(VMData*)d {
	//	IMPLEMENT LATER
}

#pragma mark -
#pragma mark init and dealloc

#define SetClassTable(cls,type,shortString,order) \
[self->classForType 			setItem:[cls class] for:VMIntObj( vmObjectType_##type )];\
[self->typeForTypeString		setItem:VMIntObj( vmObjectType_##type ) for:@"" #type ];\
[self->stringForType			setItem:@"" #type for:VMIntObj( vmObjectType_##type )];\
[self->shortTypeStringForType	setItem:@"" #shortString for:VMIntObj( vmObjectType_##type )];\
[self->compatibilityOrder		setItem:VMFloatObj(order) for:VMIntObj( vmObjectType_##type ) ];

/**
 *	the data class tree
 *
 * level/layer
 *	1/base		2/category		3/meta			4/static media		5/concrete		6/collection	7/dynamic 		8/runtime
 *
 *	[VMData]---- [VMCue]--------- [VMMetaCue]------------------------ [VMAudioCue] ------------------ [VMAudioCuePlayer]
 *			|							|	└---- [VMAudioInfo]	----- [VMAudioModifier]
 *			|							└ [VMCueCollection]---------- [VMLayerList]
 *			|														└---------------- [VMSelector]
 *			|														└---------------- [VMSequence]
 *			|														└-------------------------------- [VMLiveData]--- [VMPlayer]
 *			|---[VMReference]---- [VMChance]
 *			|				   └- [VMUnresolved]
 *			|------------------------------------ [VMStimulator]
 *			|-------------------- [VMTaglist]
 *			|-------------------------------------------------------- [VMScoreModifier]
 *			└-------------------- [VMFunction]
 */

- (void)initClassTable {
	self->classForType 				= NewInstance(VMHash);
	self->typeForTypeString			= NewInstance(VMHash);
	self->stringForType				= NewInstance(VMHash);
	self->shortTypeStringForType 	= NewInstance(VMHash);
	self->compatibilityOrder		= NewInstance(VMHash);
	
	//				class			type			short	order
	//	primitive
	SetClassTable( VMData, 			data,			D,		1.0 )
	//	category
	SetClassTable( VMReference,		reference,		REF,	2.0 )
	SetClassTable( VMCue,			cue,			CUE,	2.1 )
	//	meta
	SetClassTable( VMUnresolved,	unresolved,		UNR,	3.0 )
	SetClassTable( VMMetaCue,		metaCue,		MC,		3.1 )
	SetClassTable( VMFunction,		function,		FNC,	3.2 )
	SetClassTable( VMTagList,		tagList,		TAG,	3.4 )
	SetClassTable( VMChance,		chance,			CH,		3.5 )
	SetClassTable( VMCueCollection,	cueCollection,	COL,	3.9 )
	//	static media
	SetClassTable( VMAudioInfo,		audioInfo,		AI,		4.5 )
	SetClassTable( VMStimulator,	stimulator,		STM,	4.6 )
	//	concrete instanization
	SetClassTable( VMAudioModifier,	audioModifier,	AM,		5.1 )
	SetClassTable( VMLayerList,		layerList,		LAY,	5.3 )
	SetClassTable( VMAudioCue,		audioCue,		AC,		5.4 )
	SetClassTable( VMScoreModifier,	scoreModifier,	SCM,	5.5 )
	//	collection
	SetClassTable( VMSelector,		selector,		SEL,	6.1 )
	SetClassTable( VMSequence,		sequence,		SEQ,	6.5 )
	//	dynamic song object
	SetClassTable( VMLiveData,		liveData,		LD,		7.0 )
	//	runtime
	SetClassTable( VMPlayer,		player,			PLY,	8.0 )
}

- (void)initShortKeyword {
	shortKeyword
	= [[VMHash hashWithObjectsAndKeys:
		@"ref",			@"referenceId",
		@"ref",			@"reference",
		@"alt",			@"alternatives",
		@"dur",			@"duration",
		@"sel",			@"selector",
		@"seq",   		@"sequence",
		@"ofs",			@"offset",
		@"tags",   		@"tagList",
		@"tags",   		@"tag",
		@"subseq", 		@"next",
		@"subseq",		@"subsequence",
		@"original",	@"originalAudioInfoId",
		@"original",	@"originalId",
		nil] retain];
}

- (void)initDialects {
	dialects
	= [[VMHash hashWithObjectsAndKeys:
		@"cues", 		@"sel",
		@"cues",	 	@"layer",
		@"cues",		@"seq",
		@"instruction",	@"instructions",
		nil] retain];
}

- (void)initConversionTables {
	[self initClassTable];
	[self initShortKeyword];
	[self initDialects];
}

- (id)init {
	debugCounter = 1000;
	if((self=[super init])) {
		self.log = ARInstance(VMArray);
		[self initConversionTables];
		
		
		fatalErrors = 0;
	}
	return self;
}

- (void)releaseConversionTables {
	[self->classForType release];
	[self->stringForType release];
	[self->typeForTypeString release];
	[self->shortTypeStringForType release];
	[self->compatibilityOrder release];
	[self->dialects release];
	[self->shortKeyword release];
}

- (void)dealloc {
	self.log = nil;
	[self releaseConversionTables];
	[self->vmReservedCharacterSet release];
	[super dealloc];
}

@end

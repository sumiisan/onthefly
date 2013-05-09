//
//  VSDataTypes.m
//  VariableMusicPlayer
//
//  Created by cboy on 12/11/07.
//  Copyright 2012 sumiisan (aframasda.com). All rights reserved.
//

#import "VMDataTypes.h"
#import "VMScoreEvaluator.h"
#import "VMPreprocessor.h"
#import "VMException.h"
#import "VMPAnalyzer.h"
#import "VMDataTypesMacros.h"

#include "VMPMacros.h"

static const int kMaxSelectorHistoryNumber = 100;


/*---------------------------------------------------------------------------------
 
 VMTimeRangeDescriptor
 
 ----------------------------------------------------------------------------------*/

#pragma mark -
#pragma mark VMTimeRangeDescriptor

@implementation VMTimeRangeDescriptor
@synthesize lengthDescriptor=lengthDescriptor_, locationDescriptor=locationDescriptor_;

- (void)dealloc {
	self.locationDescriptor = nil;
	self.lengthDescriptor = nil;
	[super dealloc];
}

- (VMTime)location {
	return [VMTimeRangeDescriptor secondsFromTimeDescriptor:self.locationDescriptor];
}
- (VMTime)length {
	return [VMTimeRangeDescriptor secondsFromTimeDescriptor:self.lengthDescriptor];
}
- (VMTime)start {
	return self.location;
}
- (VMTime)end {
	return self.location + self.length;
}
- (VMFloat)bpm {
	VMFloat bpm;
	[VMTimeRangeDescriptor splitTimeDescriptor:self.lengthDescriptor numerator:nil denominator:nil bpm:&bpm];
	if (bpm) return bpm;
	[VMTimeRangeDescriptor splitTimeDescriptor:self.locationDescriptor numerator:nil denominator:nil bpm:&bpm];
	return bpm;
}

- (void)setLengthDescriptor:(NSString *)lengthDescriptor {
	if ( ClassMatch(lengthDescriptor, NSNumber ) ) lengthDescriptor = ((NSNumber*)lengthDescriptor).stringValue;
	[lengthDescriptor_ release];
	lengthDescriptor_ = [lengthDescriptor retain];
}

- (void)setLocationDescriptor:(NSString *)locationDescriptor {
	if ( ClassMatch(locationDescriptor, NSNumber ) ) locationDescriptor = ((NSNumber*)locationDescriptor).stringValue;
	[locationDescriptor_ release];
	locationDescriptor_ = [locationDescriptor retain];
}

#pragma mark utils
+ (void)splitTimeDescriptor:(NSString*)descriptor
				  numerator:(VMFloat*)outNumerator
				denominator:(VMInt  *)outDenominator
						bpm:(VMFloat*)outBPM {
	VMArray *c = [VMArray arrayWithString:descriptor splitBy:@"@"];
    if( [c count] > 1 ) {
        //  we have @ .. assume bpm syntax
		VMArray *nd = [VMArray arrayWithString:[c item:0] splitBy:@"/"];
		if( outNumerator )
			*outNumerator   =			[nd itemAsFloat:0];
		if ( outDenominator )
			*outDenominator = Default(	[nd itemAsInt:  1], 4 );
		if ( outBPM )
			*outBPM			= [[VMArray arrayWithString:[((VMString*)[c item:1]) lowercaseString] splitBy:@"bpm"] itemAsFloat:0];
    } else {
		if ( outNumerator )
			*outNumerator	= [[VMArray arrayWithString:[descriptor lowercaseString] splitBy:@"sec"] itemAsFloat:0];
		if ( outDenominator )
			*outDenominator = 1;
		if ( outBPM )
			*outBPM			= 0;
	}
}

+ (VMTime)secondsFromTimeDescriptor:(NSString*)descriptor {
	VMFloat numerator;
	VMInt   denominator;
	VMFloat	bpm;
	
	[self splitTimeDescriptor:descriptor numerator:&numerator denominator:&denominator bpm:&bpm];
	
    if( bpm ) {
		return	240. /* bpm = number of 1/4 notes in 60secs == number of 1/1 notes in 240 secs. */
		/ bpm
		* ( numerator / denominator );
    }
	return numerator;
}

#pragma mark NSCopying NSCoding

- (id)copyWithZone:(NSZone *)zone {
	VMTimeRangeDescriptor *trd = [[VMTimeRangeDescriptor allocWithZone:zone] init];
	trd.locationDescriptor = self.locationDescriptor;
	trd.lengthDescriptor = self.lengthDescriptor;
	return trd;
}

- (id)initWithCoder:(NSCoder *)decoder {
	if ((self = [super init])) {
		Deserialize(locationDescriptor, Object )
		Deserialize(lengthDescriptor, Object )
	}
	return self;	
}

- (void)encodeWithCoder:(NSCoder *)encoder {
	Serialize(locationDescriptor, Object )
	Serialize(lengthDescriptor, Object )
}

@end



//------------------------ Data -----------------------------
/*
 the base class (identifier)
 */
#pragma mark -
#pragma mark *** VMData ***

@implementation VMData
@synthesize id=id_, type=type_, comment=comment_, shouldRegister=shouldRegister_;

- (VMId*)id {
	return id_;
}

- (void)setId:(VMId *)inId {
	[id_ release];
	id_ = [inId copy];
	if( Pittari([inId substringToIndex:1],@"#") ) {
		[VMException raise:@"UnCompleted Id set" format:@"at %@", [self description]];
	}
}

#pragma mark public methods

- (id)matchMask:(int)mask {
	[DEFAULTEVALUATOR trackObjectOnResolvePath:self];
	if( mask & vmObjectMatch_type ) {	//	type match
		if ( self.type == mask ) return self;
	} else { 							//	category match
		if ( self.type &  mask ) return self;
	}
	return nil;
}

- (void)feedEvaluator {	//	base
	[DEFAULTEVALUATOR setValue:self.id forVariable:@"@ID"];
	[DEFAULTEVALUATOR setValue:VMIntObj(self.type) forVariable:@"@TYPE"];
}

- (VMString*)stringExpression {
	return id_;
}

#pragma mark obligatory

VMObligatory_resolveUntilType()

VMOBLIGATORY_init(vmObjectType_data,NO,)


//	NSCoding not fully implemented: TODO: implement NSCoding for each class
VMObligatory_initWithCoder(
 Deserialize(id,Object)
 Deserialize(comment,Object);
)

VMObligatory_encodeWithCoder(
 Serialize(id,Object)
 Serialize(comment,Object)
)

//	NSCopying
/*
 TODO: override copyWithZone method if needed.
 	some private properties may not copied with initWithProto (which calls setWithProto ) method.
*/

- (id)copyWithZone:(NSZone *)zone {
	id copy = [[[self class] allocWithZone:zone] initWithProto:self];
	((VMData*)copy).type = self.type;	//	not set by setWithProto method.
	return copy;
}

- (id)initWithProto:(id)proto {
	if ((self = [self init] )) [self setWithProto:proto];
	return self;
}

- (void)setWithProto:(id)proto {
	//CopyPropertyIfExist( dataType )	don't copy type
	if(HasMethod(proto, shouldRegister)) shouldRegister_ = [proto shouldRegister];
	CopyPropertyIfExist( id )
	CopyPropertyIfExist( comment )
}

- (void)setWithData:(id)data {
	if ( ClassMatch(data, VMData))
		[self setWithProto:data];
	else {
		if ( ClassMatch(data, VMHash)) {
			MakeHashFromData
			SetPropertyIfKeyExist( id, itemAsString)
			//SetPropertyIfKeyExist( type,	itemAsInt)	//don't set type by hash
			SetPropertyIfKeyExist( comment, itemAsString )
		}
	}
}

- (void)dealloc {
	self.id = nil;
	self.comment = nil;
    [super dealloc];
}

- (NSString*)description {
	return [NSString stringWithFormat:@"%@<%@>%@",
			[VMPreprocessor shortTypeStringForType:type_],
			Default(self.id, @"?"),
			PropertyDescriptionString(comment,@"(%@)")
			];
}
@end


//------------------------ Reference (abstract) ---------------------
/*
 reference to other object
 */
#pragma mark -
#pragma mark *** VMReference ***

@implementation VMReference
@synthesize referenceId=referenceId_;

VMObligatory_resolveUntilType(
	if(self.referenceId)
		return [[DEFAULTPREPROCESSOR rawData:self.referenceId] resolveUntilType:mask];
							  
)

VMOBLIGATORY_init(vmObjectType_reference, YES,)
VMOBLIGATORY_initWithProto
VMOBLIGATORY_setWithProto(
CopyPropertyIfExist(referenceId)
)
VMOBLIGATORY_setWithData(
	 if ( ClassMatch(data,VMHash)) {
		 MakeHashFromData
		 if(HashItem(ref))
			 self.referenceId=[hash itemAsString:@"ref"];
	 }
)

VMObligatory_initWithCoder(
 Deserialize(referenceId,Object)
)

VMObligatory_encodeWithCoder(
 Serialize(referenceId,Object)
)

- (NSString*)description {
	return [NSString stringWithFormat:@"%@ -> %@",[super description],self.referenceId];
}
@end


//------------------------ Unresolved (abstract) ---------------------
/*
 marking unresolved objects
 */
#pragma mark -
#pragma mark *** VMUnresolved ***

@implementation VMUnresolved
VMObligatory_resolveUntilType()
VMOBLIGATORY_init(vmObjectType_unresolved, YES, )
VMOBLIGATORY_initWithProto
VMOBLIGATORY_setWithProto()
VMOBLIGATORY_setWithData()
@end

//------------------------ Cue (abstract) -----------------------
/*
 everything cue-able
 */
#pragma mark -
#pragma mark *** VMCue ***

@implementation VMCue


- (void)setId:(VMId *)inId { 	// override	
	if( [inId hasPrefix:@"#"] ) {
		unsigned long splitPos = MIN( [inId length], 3 );
		inId = [[[VMArray arrayWithString:[inId substringToIndex:splitPos] 
								  splitBy:@"#"] join:@"_"] 
				stringByAppendingString:[inId substringFromIndex:splitPos]];
	}
	[super setId:inId];
}


-(NSString*)sectionIdComponentPart {
    return (self.sectionId) ? [NSString stringWithFormat: @"_%@", self.sectionId] : @"_";
}

-(NSString*)trackIdComponentPart { 
    return (self.trackId) ? [NSString stringWithFormat: @"_%@", self.trackId] : @"";
}

-(NSString*)variantIdComponentPart {
    return (self.variantId) ? [NSString stringWithFormat: @";%@", self.variantId] : @"";
}

-(NSString*)VMPModifierComponentPart {
    return (self.VMPModifier) ? [NSString stringWithFormat: @"|%@", self.VMPModifier] : @"";
}

#pragma mark accessor
/*
 id scheme:
 
 partId_sectionId_trackId;variantId|VMPModifier
 |_______ fileId ________|
 |_______ userGeneratedId _________|
 */

- (NSString*)userGeneratedId {
	return [[self.id componentsSeparatedByString:@"|"] objectAtIndex:0];
}

- (NSString*)fileId_internal {	/*protected*/
	return [[[self userGeneratedId] componentsSeparatedByString:@";"] objectAtIndex:0];
}

- (VMId*)cueId {
	return self.id;
}

- (void)setCueId:(VMId *)cueId {
	self.id = cueId;
}

- (VMId*)partId {	/*public*/
	VMId *pid = [[VMArray arrayWithString:[self fileId_internal] splitBy:@"_"] item:0];
	return Pittari(pid,@"") ? nil : pid;
}

- (VMId*)sectionId {	/*public*/
	VMId *sid = [[VMArray arrayWithString:[self fileId_internal] splitBy:@"_"] item:1];
	return Pittari(sid,@"") ? nil : sid;
}

- (VMId*)trackId {	/*public*/
	VMArray *arr = [VMArray arrayWithString:[self fileId_internal] splitBy:@"_"];
	if ( [arr count] > 2 ) {
		[arr unshift];
		[arr unshift];
		VMId *tid = [arr join:@"_"];
		return Pittari(@"",tid) ? nil : tid;
	}
	return nil;
}

- (VMId*)variantId {
	return [[VMArray arrayWithString:[self userGeneratedId] splitBy:@";"] item:1];
}

- (VMId*)VMPModifier {
	return [[VMArray arrayWithString:self.id splitBy:@"|"] item:1];
}

-(void)setPartId:(VMId *)partId {
    self.id = [NSString stringWithFormat:@"%@%@%@%@%@", 
				  partId, 
				  [self sectionIdComponentPart], 
				  [self trackIdComponentPart], 
				  [self variantIdComponentPart],
				  [self VMPModifierComponentPart] ];
}

-(void)setSectionId:(VMId *)sectionId {
    self.id = [NSString stringWithFormat:@"%@_%@%@%@%@", 
				  self.partId, 
				  sectionId, 
				  [self trackIdComponentPart], 
				  [self variantIdComponentPart],
				  [self VMPModifierComponentPart] ];
}

-(void)setTrackId:(VMId *)trackId {
    self.id = [NSString stringWithFormat:@"%@%@_%@%@%@", 
				  self.partId, 
				  [self sectionIdComponentPart], 
				  trackId, 
				  [self variantIdComponentPart],
				  [self VMPModifierComponentPart] ];
}

-(void)setVariantId:(VMId *)variantId {
    self.id = [NSString stringWithFormat:@"%@%@%@;%@%@", 
			   self.partId, 
			   [self sectionIdComponentPart], 
			   [self trackIdComponentPart], 
			   variantId,
			   [self VMPModifierComponentPart] ];
}

-(void)setVMPModifier:(VMId *)VMPModifier {
    self.id = [NSString stringWithFormat:@"%@%@%@%@|%@", 
			   self.partId, 
			   [self sectionIdComponentPart], 
			   [self trackIdComponentPart], 
			   [self variantIdComponentPart],
			   VMPModifier ];
}


#pragma mark obligatory
VMObligatory_resolveUntilType()

VMOBLIGATORY_init(vmObjectType_cue, NO,)
VMOBLIGATORY_initWithProto
VMOBLIGATORY_setWithProto()
VMOBLIGATORY_setWithData(
	if ( ClassMatch(data,VMHash)) {
		MakeHashFromData
		SetPropertyIfKeyExist(partId, 		itemAsString);
		SetPropertyIfKeyExist(sectionId,	itemAsString);
		SetPropertyIfKeyExist(trackId, 		itemAsString);
		IfHashItemExist(variantId, 		 [self setVariantId:HASHITEM];)
		IfHashItemExist(VMPModifier,	 [self setVMPModifier:HASHITEM];)
	} else if ( ClassMatch(data,VMId)) {
		self.id = ClassCast(data,VMId);
	}
						 
)

- (void)dealloc {    [super dealloc];
}

- (NSString*)description {
	return [super description];
}

@end


//-------------------- MetaCue -----------------------------
/*
 a cue with instruction
 */

#pragma mark -
#pragma mark *** VMMetaCue ***

@implementation VMMetaCue
@synthesize instructionList=instructionList_;		//	array of functions


#pragma mark public methods

- (void)interpreteInstructionsWithAction:(VMActionType)action {
	[self interpreteInstructionsWithData:self action:action];	
}

- (void)interpreteInstructionsWithData:(VMData*)data action:(VMActionType)action {	//	virtual
	;
}

- (VMFunction*)functionWithName:(VMString*)functionName {
	for( VMFunction *func in self.instructionList )
		if ( Pittari( func.functionName, functionName )) return func;
	return nil;
}

- (BOOL)hasFunction:(VMString*)functionName {
	return [self functionWithName:functionName] != nil;
}

- (BOOL)seekForSameFunction:(VMFunction*)aFunc {
	for( VMFunction *func in self.instructionList ) {
		if ( [func isEqualToFunction:aFunc] ) return YES;
	}
	return NO;
}

- (BOOL)shouldSelectTemporary {
	for( VMFunction *func in self.instructionList )
		if ( [func doesChangeCueOrder] ) return NO;
	return YES;
}

- (void)setInstructionsByString:(VMString*)instString {
	VMArray *instList = [VMArray arrayWithString:instString splitBy:@","];
	if( ! self.instructionList ) self.instructionList = ARInstance( VMArray );
	for( VMString *inst in instList ) {
		VMFunction *func = ARInstance( VMFunction );
		
		[func setWithData:inst];
		func.id = [VMPreprocessor idWithVMPModifier:self.id 
												tag:@"function" 
											   info:[NSString stringWithFormat:@"%ld",
													 [self.instructionList count]]
				   ];
		if( ! [self seekForSameFunction:func] )	[self.instructionList push:func];
	}
}

#pragma mark obligatory
VMObligatory_resolveUntilType()	//	unresolbeable for now. maybe possible after implementing some instructions.

VMOBLIGATORY_init(vmObjectType_metaCue, YES,)
VMOBLIGATORY_setWithProto(
  CopyPropertyIfExist(instructionList)
  )

VMOBLIGATORY_setWithData(
 if ( ClassMatch(data, VMHash)) {
	 MakeHashFromData
	 IfHashItemExist(instruction, [self setInstructionsByString:ClassCast(HASHITEM, VMString)] )
 }
)

VMObligatory_initWithCoder(
 Deserialize(instructionList, Object)
)

VMObligatory_encodeWithCoder(
 Serialize(instructionList, Object)
)

- (void)dealloc {
	self.instructionList = nil;
	[super dealloc];
}

- (NSString*)description {
	return [NSString stringWithFormat:@"%@%@",
			[super description],
			self.instructionList 
			?[NSString stringWithFormat:@" func[%@]",[self.instructionList join:@","]] 
									 : @""
			];
}


@end


//------------------------ AudioInfo ---------------------------------
/*
 information about audio file
 */
#pragma mark -
#pragma mark *** VMAudioInfo ***

@implementation VMAudioInfo
@synthesize cuePoints=cuePoints_, regionRange=regionRange_, volume=volume_;

#pragma mark accessor

- (VMId*)fileId {
	if( ! fileId_ ) {
		// the default for fileId
		return [[VMArray arrayWithString:
				 [[VMArray arrayWithString:self.id splitBy:@"|"] itemAsString:0]
								 splitBy:@";"] itemAsString:0];
	}
	return fileId_;
}

- (BOOL)hasExplicitlySpecifiedFileId {
	return ( fileId_ != nil );
}

- (void)setFileId:(NSString *)inFileId {
	[fileId_ release];
	fileId_ = [inFileId copy];
}

- (VMTime)duration {
	return self.cuePoints.length;
}

- (VMTime)offset {
	return self.cuePoints.location;
}

//	with modulator
- (VMTime)modulatedDuration {
	VMFunction *fluctuator 	= [self functionWithName:@"fluct"];
	VMFloat	   sigma 		= [[fluctuator valueForParameter:@"dur"] floatValue];
	VMFunction *modifier   	= [self functionWithName:@"modify"]; 
	VMFloat	   amount 		= [[modifier valueForParameter:@"dur"] floatValue];
	float mod;
	if( modifier || fluctuator ) {
		mod = SNDRand( 0, sigma );
		//		NSLog(@"duration_modifier: %3.3f offset:%3.3f",mod,ofs);
		return self.duration + mod + amount;
	}
	return self.duration;
}

- (VMTime)modulatedOffset {
	VMFunction *fluctuator 	= [self functionWithName:@"fluct"];
	VMFloat	   sigma 		= [[fluctuator valueForParameter:@"ofs"] floatValue];
	VMFunction *modifier   	= [self functionWithName:@"modify"]; 
	VMFloat	   amount 		= [[modifier valueForParameter:@"ofs"] floatValue];
	float mod;
	if( modifier || fluctuator ) {
		mod = SNDRand( 0, sigma );
		//		NSLog(@"duration_modifier: %3.3f offset:%3.3f",mod,ofs);
		return self.offset + mod + amount;
	}
	return self.offset;
}


#pragma mark obligatory
VMObligatory_resolveUntilType()
VMOBLIGATORY_init(vmObjectType_audioInfo, YES,
				  self.cuePoints=ARInstance(VMTimeRangeDescriptor);
				  self.regionRange=ARInstance(VMTimeRangeDescriptor);
				  self.volume=1.;
				  )
VMOBLIGATORY_initWithProto
VMOBLIGATORY_setWithProto(
	VMAudioInfo *ai = ClassCastIfMatch(proto, VMAudioInfo);
	if( ai ) fileId_ = ai->fileId_;
						  
	CopyPropertyIfExist( cuePoints )
	CopyPropertyIfExist( regionRange )
	CopyPropertyIfExist( volume )
)

VMOBLIGATORY_setWithData(
if ( ClassMatch(data, VMHash)) {
	MakeHashFromData
	IfHashItemExist(ofs,			cuePoints_.locationDescriptor = HASHITEM )
	IfHashItemExist(dur,			cuePoints_.lengthDescriptor = HASHITEM )
	IfHashItemExist(regionStart,	regionRange_.locationDescriptor = HASHITEM )
	IfHashItemExist(regionLength,	regionRange_.lengthDescriptor = HASHITEM )
	SetPropertyIfKeyExist( volume, itemAsFloat )
	SetPropertyIfKeyExist( fileId, itemAsString )
}
)

VMObligatory_initWithCoder(
 Deserialize(cuePoints, Object )
 Deserialize(regionRange, Object )
 Deserialize(volume, Float)
 VMId *tempId=[decoder decodeObjectForKey:@"fileId"];
 if( tempId ) fileId_ = [tempId copy];
)

VMObligatory_encodeWithCoder(
 Serialize(cuePoints, Object )
 Serialize(regionRange, Object )
 Serialize(volume, Float)
 if( fileId_ ) [encoder encodeObject:fileId_ forKey:@"fileId"];
)


- (void)dealloc {
	self.fileId = nil;
	self.cuePoints = nil;
	self.regionRange = nil;
    [super dealloc];
}

- (NSString*)description {
	return [NSString stringWithFormat:@"%@ %@%@%@",
			[super description],
			(fileId_ ? [NSString stringWithFormat:@" fileId:%@", fileId_ ] : @" fileId:(*)" ),
			PropertyDescriptionString(duration,@" duration:%3.2f"),
			PropertyDescriptionString(offset,@" offset:%3.2f")
			];
}

@end

//------------------------ AudioModifier -----------------------------
/*
 information about audio playback
 */
#pragma mark -
#pragma mark *** VMAudioModifier ***

@implementation VMAudioModifier
@synthesize originalId=originalId_;
VMObligatory_resolveUntilType(
if (self.originalId) [[DEFAULTPREPROCESSOR rawData:self.originalId] resolveUntilType:mask];
)
VMOBLIGATORY_init(vmObjectType_audioModifier, YES,)
VMOBLIGATORY_setWithProto(
  CopyPropertyIfExist(originalId)
)
VMOBLIGATORY_setWithData( 
/*not implemented yet*/
)
@end

//------------------------ TagList -----------------------------
/*
 tags
 */
#pragma mark -
#pragma mark *** VMTagList ***
@implementation VMTagList
@synthesize tagArray=tagArray_;
VMObligatory_resolveUntilType()
VMOBLIGATORY_init(vmObjectType_tagList, YES,)
VMOBLIGATORY_initWithProto
VMOBLIGATORY_setWithProto(
  CopyPropertyIfExist(tagArray)
)
VMOBLIGATORY_setWithData( 
/*not implemented yet*/
)
@end

//------------------------ ScoreModifier --------------------------
/*
 define the amount of a tag affects the score
 */
#pragma mark -
#pragma mark *** VMScoreModifier ***
@implementation VMScoreModifier
@synthesize factor=factor_,tagName=tagName_;
VMObligatory_resolveUntilType()
VMOBLIGATORY_init(vmObjectType_scoreModifier, YES,)
VMOBLIGATORY_initWithProto
VMOBLIGATORY_setWithProto(
  CopyPropertyIfExist(factor)
  CopyPropertyIfExist(tagName)
)
VMOBLIGATORY_setWithData( 
/*not implemented yet*/
)
- (void)dealloc {
	self.tagName = nil;
	[super dealloc];
}
@end

//------------------------ Stimulator --------------------------
/*
 interraction source which affects the scores of tagged chances
 */
#pragma mark -
#pragma mark *** VMStimulator ***
@implementation VMStimulator
@synthesize source=source_,modifiers=modifiers_;
VMObligatory_resolveUntilType()
VMOBLIGATORY_init(vmObjectType_stimulator, YES,)
VMOBLIGATORY_initWithProto
VMOBLIGATORY_setWithProto(
  CopyPropertyIfExist(source)
  CopyPropertyIfExist(modifiers)
)
VMOBLIGATORY_setWithData(
/*not implemented yet*/
)
- (void)dealloc {
	self.source = nil;
	self.modifiers = nil;
	[super dealloc];
}

@end

//------------------------ AudioCue -----------------------------
/*
 cue with audio
 */
#pragma mark -
#pragma mark *** VMAudioCue ***

@implementation VMAudioCue
@synthesize audioInfoId=audioInfoId_,audioInfoRef=audioInfoRef_;

#pragma mark private utils

#pragma meta cue
- (void)interpreteInstructionsWithData:(VMData*)data action:(VMActionType)action {	//	override
	for ( VMFunction *func in self.instructionList )
		[func processWithData:data action:action];
}


#pragma mark obligatory
VMObligatory_resolveUntilType(
if(self.audioInfoRef) return [self.audioInfoRef resolveUntilType:mask];
if(self.audioInfoId) return [[DEFAULTPREPROCESSOR rawData:self.audioInfoId] resolveUntilType:mask];
)
VMOBLIGATORY_init(vmObjectType_audioCue, YES,)
VMOBLIGATORY_setWithProto(
	CopyPropertyIfExist(audioInfoId);
)
VMOBLIGATORY_setWithData(
if ( ClassMatch(data, VMHash)) {
	MakeHashFromData
	SetPropertyIfKeyExist( audioInfoId, itemAsString );
}
)

VMObligatory_initWithCoder
(
 Deserialize(audioInfoId, Object )
 )

VMObligatory_encodeWithCoder
(
	Serialize(audioInfoId, Object)
)

//	NSCopying (override)
- (id)copyWithZone:(NSZone *)zone {
	id copy = [super copyWithZone:zone];
	((VMAudioCue*)copy).audioInfoRef = self.audioInfoRef;		//	not copied by initWithProto method.
	return copy;
}

- (void)dealloc {
	self.audioInfoId = nil;
    [super dealloc];
}

- (NSString*)description {
	return [NSString stringWithFormat:@"%@ %@",
			[super description],
			PropertyDescriptionString(audioInfoId, @" audioInfoId:%@")
			];
}

@end

@implementation VMAudioCue(publicMethods)
#pragma mark accessor
RedirectPropGetterToObject(VMId*,	fileId, 			self.audioInfoRef)
RedirectPropGetterToObject(VMTime, 	duration, 			self.audioInfoRef)
RedirectPropGetterToObject(VMTime, 	offset, 			self.audioInfoRef)
RedirectPropGetterToObject(VMVolume,volume, 			self.audioInfoRef)
RedirectPropGetterToObject(VMTime, 	modulatedDuration, 	self.audioInfoRef)
RedirectPropGetterToObject(VMTime, 	modulatedOffset, 	self.audioInfoRef)

RedirectPropSetterToObject(VMId*,	setFileId, 	fileId,	 self.audioInfoRef)
RedirectPropSetterToObject(VMFloat,	setVolume, 	volume,  self.audioInfoRef)

- (VMTime)durationBetweenCuePoints {
	return self.duration - self.offset;
}

@end

//------------------------ Chance -----------------------------
/*
 a cue with probability
 */
#pragma mark -
#pragma mark *** VMChance ***

@implementation VMChance
@synthesize scoreDescriptor=scoreDescriptor_;



#pragma mark accessor

- (void)setScoreDescriptor:(NSString *)inScoreDescriptor {
	[scoreDescriptor_ release];
	scoreDescriptor_ = [inScoreDescriptor copy];
}

- (VMString*)scoreDescriptor {
	return scoreDescriptor_;
}


- (VMId*)targetId {
	return self.referenceId;
}

- (void)setTargetId:(NSString *)targetId {
	self.referenceId = targetId;
}

- (VMFloat)evaluatedScore {
	[DEFAULTEVALUATOR setValue:self.targetId forVariable:@"@T"];
	VMFloat s	 = [DEFAULTEVALUATOR evaluate:self.scoreDescriptor];
	cachedScore_ = ( s > 0 ? s : 0 );	//	score must be grataer than zero. ( at least now, when we cache. )
										//	DISCUSSION: consider disabling a selector option (=chance) by decrementing the score value
										//				when we overwrite the vms data to expand song. 
										//				but probably, this should be done by the preprocessor.
	return cachedScore_; 
}

- (VMFloat)cachedScore {
	if ( isnan( cachedScore_ ) ) [self evaluatedScore];
	return cachedScore_;
}

- (VMFloat)primaryFactor {
	return [DEFAULTEVALUATOR primaryFactor:self.scoreDescriptor];
}

- (void)setPrimaryFactor:(VMFloat)value {
	self.scoreDescriptor = [DEFAULTEVALUATOR setPrimaryFactor:value forDescriptor:self.scoreDescriptor ];
}

- (VMString*)stringExpression {
	return [NSString stringWithFormat:@"%@=%@", self.targetId, self.scoreDescriptor];
}


#pragma mark obligatory
VMObligatory_resolveUntilType(
	return [[DEFAULTSONG data:self.targetId] resolveUntilType:mask];	
)
VMOBLIGATORY_init(vmObjectType_chance, NO, cachedScore_ = NAN;)
VMOBLIGATORY_setWithProto(
	CopyPropertyIfExist( targetId )
	CopyPropertyIfExist( scoreDescriptor )
)

- (void)setByString:(NSString *)str {
    VMArray *c = [VMArray arrayWithString:str splitBy:@"="];
    if ( [c count] >= 2 ) {
        self.targetId = [c unshift];
        self.scoreDescriptor = [c join:@"="];
    } else {
        self.targetId = [c item:0];
        self.scoreDescriptor = @"1";
    }
}

- (void)dealloc {
	self.scoreDescriptor = nil;
	self.targetId = nil;	
    [super dealloc];
}

- (NSString*)description {
	return [NSString stringWithFormat:@"%@ score=%@",
			[super description],
			self.scoreDescriptor
			];
}

VMObligatory_initWithCoder
(
 Deserialize(targetId, Object)
 Deserialize(scoreDescriptor, Object)
 )

VMObligatory_encodeWithCoder
(
 Serialize(targetId, Object)
 Serialize(scoreDescriptor, Object)
 )

#define ScoreValueToString(v) [NSString stringWithFormat: @"%3.3f",v]		//	workaround

VMOBLIGATORY_setWithData(
if ( ClassMatch(data, VMHash)) {
	MakeHashFromData
	id sd = HashItem(score);
	if ( sd ) {
		if ( ClassMatch(sd, NSString) )
			self.scoreDescriptor = sd;
		else
			self.scoreDescriptor = ScoreValueToString([sd floatValue]);
	}
	SetPropertyIfKeyExist( targetId, itemAsString )
}
if ( ClassMatch(data, NSString)) {
	[self setByString:data];
}
)

@end


//------------------------ CueCollection -----------------------------
/*
 generic collection of cues
 */
#pragma mark -
#pragma mark *** VMCueCollection ***

@implementation VMCueCollection
@synthesize cues=cues_;

#pragma mark accessor
- (VMChance*)chanceWithId:(VMId*)dataId {
	for( id ch in cues_ ) {
		VMId *did = ReadAsVMId(ch);
		if( Pittari( dataId, did ) ) return ch;
	}
	return nil;
}

- (VMChance*)chanceWithTargetId:(VMId*)targetId {
	for( VMChance *c in cues_ ) 
		if( Pittari(targetId, c.targetId) ) return c;
	return nil;
}

- (VMCue*)cueAtIndex:(VMInt)pos {
	id c = [cues_ item:pos];
	if ( ClassMatch(c, VMId)) c = [DEFAULTSONG data: c];
	return c;
}

-  (VMInt)length {
	return [cues_ count];
}

- (VMArray*)cueIdList {
	VMArray *cueIds = ARInstance(VMArray);
	for( id c in cues_ ) 
		[cueIds push:ReadAsVMId(c)];
	return cueIds;
}

#pragma mark public methods

/*
 adding cues included in data
 we allways *append* cues to make the song extensible.
 */
- (void)addCuesWithData:(id)data {	
	if ( ClassMatch( data, VMCueCollection )) {
		[self setWithProto:data];
		return;
	} 
	
	if ( ClassMatch( data, VMHash )) {
		MakeHashFromData
		if( HashItem(cues) ) 
			data = HashItem(cues);
		else
		// if no cues exist:
		//	there is no cue-collection data. maybe we can resolve it later.
			return;
	}
	
	VMArray *arr = ConvertToVMArray(data);
	
	if( ! self.cues ) self.cues = ARInstance(VMArray);
	
    for ( id obj in arr ) {
		if( ClassMatch(obj, NSString)) {
			//
			//	create VMChance if i'm a VMSelector
			//
			if (self.type==vmObjectType_selector) {				
				[VMPreprocessor 
				   createOrModifyChanceWithId:ClassCast(self, VMSelector)
				   target:obj
				   score:0
				   tagList:nil
				];
			} else {
				//	strip off scoreDescriptor.
				//	although, if this collection has to be converted to selector later,
				//	the selWrapper will automatically add score information again.
				VMId *purified	= [DEFAULTPREPROCESSOR purifiedId:obj];
				if (purified) obj = purified;

				[self.cues push:obj];
			}
		} else if ( ClassMatch( obj, VMChance )) {
			[self.cues push:obj];
		} else {
			[VMException raise:@"Could not set cues because some Objects was in data" format:@"%@", [arr description]];
		}
    }
}

- (void)convertCueObjectsToReference {
	VMInt c = self.length;
	for( int i = 0; i < c; ++i ) {
		id d = [cues_ item:i];
		if ( ClassMatch( d, VMData )) [cues_ setItem:((VMData*)d).stringExpression at:i];
	}
}

#pragma mark obligatory
VMObligatory_resolveUntilType(
#ifdef DEBUG
	[VMException raise:@"Unable to resolve cue." 
				format:@"abstract type VMCueCollection cannot be resolved." ];
#endif
	return [[self.cues item:0] resolveUntilType:mask];
)

VMOBLIGATORY_init(vmObjectType_cueCollection, NO,)
VMOBLIGATORY_setWithProto(
	if(HasMethod(proto, cues)) [self addCuesWithData:[proto cues]];
)

- (void)setWithData:(id)data {
	if ( ClassMatch(data, [self class])) [self setWithProto:data];
	else {
		[super setWithData:data];
		[self addCuesWithData:data];
	}
}

VMObligatory_initWithCoder
(
 Deserialize(cues, Object)
 )

VMObligatory_encodeWithCoder
(
 [self convertCueObjectsToReference];
 Serialize(cues, Object)
 )

- (void)dealloc {
	self.cues = nil;
	[super dealloc];
}

- (NSString*)description {
	VMArray *cueDescList = ARInstance(VMArray);
	for ( id cue in self.cues ) {
		if ( ClassMatch( cue, VMChance )) {
			VMChance *ch = ClassCast( cue, VMChance );
			[cueDescList push:[NSString stringWithFormat:@"%@(%@=%.2f)",ch.targetId,Default(ch.scoreDescriptor,@"?"),ch.cachedScore]]; 
		} else 
			[cueDescList push:ReadAsVMId(cue) ];
	}
	
	return [NSString stringWithFormat:@"%@[%@](%ld)",
			[super description],
			[cueDescList join:@","],
			self.cues ? [self.cues count] : 0
			];
}

@end


//------------------------ Selector -----------------------------
/*
 cue collection selector
 */
#pragma mark -
#pragma mark *** VMSelector ***

@implementation VMSelector
@synthesize liveData=liveData_;

static VMHash *scoreForCue__ = nil;

#pragma meta cue
- (void)interpreteInstructionsWithData:(VMData*)data action:(VMActionType)action {	//	override
	for ( VMFunction *func in self.instructionList )
		[func processWithData:data action:action];
}

#pragma mark private methods

- (void)prepareLiveData {
	self.liveData = ARInstance(VMLiveData);
	[self.liveData setWithProto:self];
	self.liveData.history = ARInstance(VMArray);
}

- (VMInt)counter {
	return self.liveData ? self.liveData.counter : 0;
}

- (void)setCounter:(VMInt)number {
	if (!self.liveData) [self prepareLiveData];
	self.liveData.counter = number;
}

- (void)feedEvaluator {	//	override
	[super feedEvaluator];
	[DEFAULTEVALUATOR setValue:VMFloatObj([self counter]) forVariable:@"@C"];
	
	//	environment
	[DEFAULTEVALUATOR setValue:self.liveData.history forVariable:@"@selectorHistory"];
}

#define prepareSelection_verbose 0

//	internal sub for preparing selection ( evaluate and cache scores )
- (void)prepareSelection {
	[self feedEvaluator];
	sumOfInnerScores_cache_ = 0;
#if prepareSelection_verbose
	VMArray *log = NewInstance(VMArray);
#endif
	VMInt c = self.length;
	for ( int i = 0; i < c; ++i ) {
		id d = [self.cues item:i];
		if ( ClassMatch(d, VMString ))  {
			[VMException raise:@"Type mismatch." format:@"Id found where chance expected. in %@",self.description];
			//	should be chance
/*			VMChance *ch = [[VMChance alloc] init];
			[ch setByString:d];
			[self.cues setItem:ch at:i];
			d = ch;
			[ch release];*/
		}
		
		sumOfInnerScores_cache_ += ((VMChance*)d).evaluatedScore;	// just evaluate.
#if prepareSelection_verbose
		[log push:[NSString stringWithFormat:@"%@=%@(%.3f)",
				   ((VMChance*)d).targetId,
				   ((VMChance*)d).scoreDescriptor,
				   ((VMChance*)d).cachedScore]];
#endif
	}
#if prepareSelection_verbose
	NSLog(@"*prepare selection(%@):[ %@ ] sum:%.2f",self.id,[log join:@", "],sumOfInnerScores_cache_);
	[log release];
#endif
}

//	


#pragma mark public methods

- (VMHash*)collectScoresOfCues:(VMFloat)parentScore frameOffset:(VMInt)counterOffset normalize:(BOOL)normalize {
	//	add an offset to counter if supplied and evaluate
	if( counterOffset != 0 ) {
		VMInt stack = [self counter];
		[self setCounter:stack + counterOffset];
		[self prepareSelection];
		[self setCounter:stack];
	} else {
		[self prepareSelection];
	}
	
	BOOL rootNode = ( parentScore == 0 );
	if ( rootNode ) {
		//	init if i'm root.
		ReleaseAndNewInstance(scoreForCue__, VMHash);
		parentScore = normalize ? 1 : sumOfInnerScores_cache_;
	}
	
	VMFloat soi = [self sumOfInnerScores];
	if ( soi == 0 ) return scoreForCue__;	//	sumOfInnerScores = 0;	no choice.
	double scoreFactor = parentScore / soi;
	
	for ( VMChance *chance in self.cues ) {
		VMFloat score = chance.cachedScore * scoreFactor;
		
		if ( isnan(score) ) [VMException raise:@"Could not evaluate score." format:@"score of %@ in %@", chance.targetId, self.id];
		if (score == 0 ) continue;
		VMCue *cue = [DEFAULTSONG data:chance.targetId];
		
		if( cue.type == vmObjectType_sequence ) {
			//	if encoutered a seq, just choose the first cue in sequence.
			cue = [ClassCast(cue, VMSequence) cueAtIndex:0];
		}
		if( cue.type == vmObjectType_selector ) {
			//	internal node: collect recursive
			[ClassCast(cue, VMSelector) collectScoresOfCues:score
						frameOffset:counterOffset normalize:normalize];
		} else {
			//	leaf node: increment score
			[scoreForCue__ add:score ontoItem:chance.targetId];
		}
	}
	
	if ( rootNode ) {
		//	clean up score
		VMArray *keys = [scoreForCue__ keys];
		for ( VMId *key in keys ) 
			if ( [scoreForCue__ itemAsFloat:key] == 0 ) [scoreForCue__ removeItem:key];
	}
	return scoreForCue__;
}


- (VMChance*)chanceAtIndex:(VMInt)pos {
	return ClassCast([super cueAtIndex:pos], VMChance);
}

-(VMCue*)cueAtIndex:(VMInt)pos {	/*override*/
    return [[super cueAtIndex:pos] resolveUntilType:vmObjectCategory_cue];	//	because they are chances.
}


-(VMFloat)sumOfInnerScores {
    if ( [self.cues count] > 0 ) {
		return sumOfInnerScores_cache_;
    } else {
        return 1.;
    }
}

//	NOTE:
//	set scoreForCues = nil to use cached score of latest evaluation.
//


- (VMCue*)selectOneTemporaryUsingScores:(VMHash*)scoreForCues sumOfScores:(VMFloat)sum {
	if( [self.cues count] <= 0 ) return nil;
	BOOL verbose = DEFAULTSONG.isVerbose;

	VMCue *cue = nil;
	int retryLeft = 10;	

	if ( ! scoreForCues ) {
		[self prepareSelection];
		if ( sum == 0 ) sum = sumOfInnerScores_cache_;
	} else {
		if ( sum == 0 ) { //	needs re-calculated
			VMArray *ids = [scoreForCues keys];
			for ( VMId* cueId in ids ) sum += [scoreForCues itemAsFloat:cueId];
		}
	}
	
	while (  ( !cue ) && retryLeft-- ) {
		double xi = VMRand1 * sum;
		double s = 0;
		
		if ( scoreForCues ) {
			//	use extern supplied data
			VMArray *cueIds = [scoreForCues keys];
			for ( VMId *cueId in cueIds ) {
				s += [scoreForCues itemAsFloat:cueId];
				if ( s > xi ) {
					VMCue *c = [DEFAULTSONG data:cueId];
					//NSLog(@"- selected using ext data: %@", c.id);
					cue = [DEFAULTEVALUATOR resolveDataWithTracking:c toType:vmObjectCategory_cue];
					if( cue ) break;
					else [DEFAULTANALYZER addUnresolveable:cueId];
				}
			}
		} else {
			//	use default internal cues and cached score
			
			for ( VMChance *c in self.cues ) {
				s += c.cachedScore;
				if ( s > xi ) { 
					//if (verbose) NSLog(@"    SEL %@ : -> selected: CHA targ:%@, resolve cue -->", self.id, c.targetId );
#if VMP_LOGGING
					
					//
					// collect score for logging
					//
					VMHash *scoreForLog = ARInstance(VMHash);
					[scoreForLog setItem:@"scores" for:@"vmlog_type"];
					for( VMChance *ch in self.cues ) {
						if( !ClassMatch(ch, VMChance)) continue;
						[scoreForLog setItem:VMFloatObj(ch.cachedScore) for:ch.targetId];
					}
					[DEFAULTEVALUATOR trackObjectOnResolvePath:scoreForLog];	//	for debug
					
					//
#endif
					selectedChance_ = c;
					cue = [DEFAULTEVALUATOR resolveDataWithTracking:c toType:vmObjectCategory_cue];
					if( cue ) break;
					else [DEFAULTANALYZER addUnresolveable:c.targetId];
					if (verbose) NSLog(@"    SEL: unresolveable, retry. %@", c.targetId );
				}
			}
		}
	}
	
	if (cue==nil) {
		NSLog(@"empty cue");
		//[self selectOneTemporaryUsingScores:scoreForCues sumOfScores:sum];
	}
	
	return cue;
}



- (VMCue*)selectOne {
	BOOL isTemporary = [self shouldSelectTemporary];
	
	if ( ! self.liveData ) {
		[self prepareLiveData];
		[self.liveData interpreteInstructionsWithAction:vmAction_prepare];
	}
	
	VMCue *cue;
	
	if ( isTemporary ) {
		cue = [self selectOneTemporaryUsingScores:nil sumOfScores:0];
	} else {
		cue = self.liveData.currentCue;
		[self.liveData advance];
		if( [self.liveData finished] ) {
			self.liveData.cues = [[self.cues copy] autorelease];
			[self.liveData interpreteInstructionsWithAction:vmAction_prepare];
		}
	}
	
	[self.liveData.history shift:selectedChance_.targetId];
//	NSLog(@"shift chance:%@",selectedChance_.targetId);
	if ( self.liveData.history.count > ( kMaxSelectorHistoryNumber * 1.5 ) ) {
		[self.liveData.history truncateLast:kMaxSelectorHistoryNumber];
	}
	return cue;
}

- (VMArray*)cueIdList {	/*override*/
	VMArray *cueIds = ARInstance(VMArray);
	for( VMChance *ch in self.cues )
		[cueIds push:ch.targetId];
	return cueIds;
}

#pragma mark obligatory
VMObligatory_resolveUntilType(
	return [[self selectOne] resolveUntilType:mask];
)
VMOBLIGATORY_init(vmObjectType_selector,YES,)
VMOBLIGATORY_setWithProto()
VMOBLIGATORY_setWithData()

- (void)dealloc {
    [super dealloc];
}

@end

//------------------------ LayerList -----------------------------
/*
 cue collection layer
 */
#pragma mark -
#pragma mark *** VMLayerList ***

@implementation VMLayerList

#pragma mark obligatory
VMObligatory_resolveUntilType(
  return [[[[VMLayerList alloc] initWithProto:self] autorelease] resolveUntilType:mask];
)
VMOBLIGATORY_init(vmObjectType_layerList, YES,)
VMOBLIGATORY_setWithProto()
VMOBLIGATORY_setWithData()

- (void)dealloc {
    [super dealloc];
}

@end

//------------------------ Sequence -----------------------------
/*
 cue collection sequence
 */
#pragma mark -
#pragma mark *** VMSequence ***

@implementation VMSequence
@synthesize subsequent=subsequent_;

- (void)convertCueObjectsToReference {
	[super convertCueObjectsToReference];
	[self.subsequent convertCueObjectsToReference];
}

#pragma mark private method

- (VMCue*)cueAtIndex:(VMInt)pos {	//override VMSelector's method. if pos is at the maximal index, return next.
	if( pos < self.length ) return [super cueAtIndex:pos];
	if( pos == self.length ) return self.subsequent;
    return nil;
}

#pragma mark obligatory
VMObligatory_resolveUntilType(
	return [[[[VMPlayer alloc] initWithProto:self] autorelease] resolveUntilType:mask]; 
)
VMOBLIGATORY_init(vmObjectType_sequence, YES,)
VMOBLIGATORY_setWithProto(
	CopyPropertyIfExist(subsequent)
)
VMOBLIGATORY_setWithData(
if ( ClassMatch(data, VMHash)) {
	MakeHashFromData
	IfHashItemExist(subseq, 
		self.subsequent = ARInstance(VMSelector);
		[self.subsequent setWithData:HASHITEM];
		self.subsequent.id = [VMPreprocessor idWithVMPModifier:self.id 
														   tag:@"subseq" 
														  info:nil];
	)
}
)

VMObligatory_initWithCoder
(
// self.subsequent = [[VMSelector alloc] initWithCoder:decoder];
 Deserialize(subsequent, Object)
)

VMObligatory_encodeWithCoder
(
 [self convertCueObjectsToReference];
 Serialize(subsequent, Object)
)

- (void)dealloc {
	self.subsequent = nil;
    [super dealloc];
}

- (NSString*)description {
return [NSString stringWithFormat:@"%@\n   next:%@",
		[super description],
		[self.subsequent description]
		];
}
@end

//------------------------ LiveData -----------------------------
/*
 runtime properties
 */
#pragma mark -
#pragma mark *** VMLiveData ***

@implementation VMLiveData
@synthesize counter=counter_,cuePosition=cuePosition_,history=history_;

#pragma mark accessor

- (void)setCuePosition:(VMInt)cuePosition {
	cuePosition_ = cuePosition;
	if ( cuePosition > self.cues.count )
		NSLog(@"cuePosition beyond cue array bound");
}

- (VMInt)cuePosition {
	return cuePosition_;
}

- (VMCue*)currentCue {
	return [self cueAtIndex:self.cuePosition];
}

- (VMCue*)nextCue {
	return [self cueAtIndex:self.cuePosition+1];
}

- (void)advance {
	++self.cuePosition;
}

- (BOOL)finished {
   return self.cuePosition >= self.length;
}

- (void)reset {
	self.cuePosition = 0;
	self.counter = 0;
	self.history = nil;
}

#pragma mark instruction
/**----------------------------- player design ------------------------------
 
 player has n(n>1) buckets(=cues), a reference to next player, play instructions and counter
 
 say				subseq		instructions	counter
 [a][b][c]			[s]			<xxx>			0
 
 
 a sequence player (top level) will be:
 [a][b][c]			[subseq]	<>
 
 a sequence player (called from another sequence) will be:
 [a][b][c]			[caller]	<>
 
 *	sequence instruction options:
 <reverse>					reverse order
 (common)
 <returnAfterOneBucket=NO>	this is NO by default. 		( this instruction was designed to make players sequence and selector compatible - pending )
 <shuffle=n%>				shuffles cues at given amont %
 
 a selector player is normally
 [a=1][b=3][c=2]	[self]		<shuffle=100%>
 which is internal expanded like:
 [b][c][a][b][b][c]	[self]
 and played in sequential order.
 
 
 *	selector (randomize) instruction options:
 <temporary>				do not cache buckets, choose each time.	(ignores other instructions)
 <flattenScore>				treat every score as 1
 <doNotRepeatWithin=n>		prevent repeat of same cueId (with last played cueId) if possible
 (common)
 <returnAfterOneBucket=YES>	this is YES by default.		( this instruction was designed to make players sequence and selector compatible - pending )
 <shuffle=n%>				shuffles cues at given amount %
 
 the counter counts the number of playback times of this player. 
 some cues only appear after a certian count of playback. (evolving)
 this can be defined as stimulation input = playerId-counter
 
 */

- (void)interpreteInstructionsWithData:(VMData *)data action:(VMActionType)action {
	self.cuePosition = 0;	//	reset
	for ( VMFunction *func in self.instructionList )
		[func processWithData:data action:action];
}

#pragma mark obligatory
VMObligatory_resolveUntilType
(
 return [[self currentCue] resolveUntilType:mask];
 )
VMOBLIGATORY_init(vmObjectType_player, NO,)

VMOBLIGATORY_setWithProto(
 CopyPropertyIfExist( cuePosition )
 CopyPropertyIfExist( counter )
 CopyPropertyIfExist( history )
 self.type = vmObjectType_liveData;
)

VMOBLIGATORY_setWithData(
 if ( ClassMatch(data, VMHash)) {
	 MakeHashFromData
	 SetPropertyIfKeyExist( cuePosition, itemAsInt )
	 SetPropertyIfKeyExist( counter, itemAsInt )
	 SetPropertyIfKeyExist( history, itemAsObject )
 }
)

VMObligatory_initWithCoder
(
 Deserialize(cuePosition, Int64)
 Deserialize(counter, Int64)
 Deserialize(history, Object)
 )

VMObligatory_encodeWithCoder
(
 Serialize(cuePosition, Int64)
 Serialize(counter, Int64)
 Serialize(history, Object)
 )

- (void)dealloc {
	self.history = nil;
    [super dealloc];
}

- (NSString*)description {
	return [NSString stringWithFormat:@"%@ pos:%ld count:%ld history:%@",
			[super description],
			self.cuePosition,
			self.counter,
			self.history.description
			];
}


@end



//------------------------ Player -----------------------------
/*
 dynamic data while playing a sequence
 */
#pragma mark -
#pragma mark *** VMPlayer ***

@implementation VMPlayer
@synthesize staticDataId=staticDataId_, nextPlayer=nextPlayer_;


#pragma mark private method

-(VMCue*)cueAtIndex:(VMInt)pos {	//override VMSequence's method. if pos is at the maximal index and there is no parent, return next.
	if( pos < self.length ) 
		return [super cueAtIndex:pos];
	else if( pos == self.length ) 
		return self.nextPlayer;
    return nil;
}

#pragma mark public method
- (VMCue*)currentCue {	//	override
	VMCue *c = [self cueAtIndex:self.cuePosition];
	if ( Pittari( c.id, self.staticDataId )) {
		[VMException raise:@"Possibility of circular reference." 
					format:@"current cue %ld in %@", self.cuePosition, self.description ];
		//	possibility of circular reference.
	}
	return c;
}

/*
- (VMCue*)resolveAudioCueOrPlayer {
	id cue = self.currentCue;
	if (! [self finished] ) {
		//	is current member in sequence a sequenceObj? try to resolve
		id seq = [cue resolveUntilType:vmObjectType_sequence];
		if ( ! seq ) {
			//	no: no sequence. try resolve an audioCue
			cue = [cue resolveUntilType:vmObjectType_audioCue];
			return cue;
		}
	}
	//	return new sequencePlayer
	return [cue resolveUntilType:vmObjectType_player];
}*/

- (BOOL)finished {
	return self.cuePosition >= self.length;
}

#pragma mark obligatory
VMObligatory_resolveUntilType(
	return [[self currentCue] resolveUntilType:mask];
)
VMOBLIGATORY_init(vmObjectType_player, NO,)

/*
VMOBLIGATORY_setWithProto(
)*/


- (void)setWithProto:(id)proto {
	[super setWithProto:proto]; 
	CopyPropertyIfExist( staticDataId )
	CopyPropertyIfExist( nextPlayer )
	//	set with VMSequence
//
//	we can not resolve subseq here, because it will chain endlessly
//	subseq->subseq->subseq ... 
//
//	if ( HasMethod(proto, subsequent) ) self.nextPlayer 
//		= [[((VMSequence*)proto) subsequent] resolveUntilType:vmObjectType_player];
	if ( HasMethod(proto, subsequent)) self.nextPlayer = (VMCue*) ((VMSequence*)proto).subsequent;
	if (!ClassMatch(proto, VMPlayer)) self.staticDataId = ((VMCue*)proto).id;
	self.type = vmObjectType_player;
}

VMOBLIGATORY_setWithData(
if ( ClassMatch(data, VMHash)) {
	MakeHashFromData
	SetPropertyIfKeyExist( staticDataId, itemAsString )
	//	nextplayer has to be resolved by loader/preprocessor since it's a object reference.
}
)

VMObligatory_initWithCoder
(
 Deserialize(staticDataId, Object)
 Deserialize(nextPlayer, Object)
)

VMObligatory_encodeWithCoder
(
 [self convertCueObjectsToReference];
 Serialize(staticDataId, Object)
 Serialize(nextPlayer, Object)
)

- (void)dealloc {
	self.nextPlayer = nil;
	self.staticDataId = nil;
    [super dealloc];
}

- (NSString*)description {
	return [NSString stringWithFormat:@"%@ current:%@ next:%@",
			[super description],
			self.currentCue.cueId,
			Default( self.nextPlayer.cueId, @"?" )
			];
}

@end





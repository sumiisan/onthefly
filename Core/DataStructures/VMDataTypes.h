//
//  VSDataTypes.h
//  VariableMusicPlayer
//
//  Created by cboy on 12/11/07.
//  Copyright 2012 sumiisan (aframasda.com). All rights reserved.
//

#import <Foundation/Foundation.h>
#import "VMPrimitives.h"

/*
 
 	VMObject protocol
 
 */
@protocol VMObjectInitialization <NSObject>
//	initialization
- (id)initWithProto:(id)proto;	//	formerly initWithCue
- (void)setWithProto:(id)proto;
- (void)setWithData:(id)data;
@end

/*
 
 	VMObject types and catrgories
 
 */
typedef enum {	
	vmObjectCategory_unresolveable	=	1 <<  7,
	vmObjectCategory_base			=	1 <<  8,
	vmObjectCategory_reference		=	1 <<  9,
	vmObjectCategory_abstract		=	1 << 10,
	vmObjectCategory_media			=	1 << 11,
	vmObjectCategory_function		=	1 << 12,
	vmObjectCategory_songStruture	=	1 << 13,
	vmObjectCategory_cue			=	1 << 14,
	vmObjectCategory_runtime		=	1 << 15,
	vmObjectCategory_any			=	0x0FF80,	
	vmObjectMatch_type				= 	0x0007F		//	if one of 7 LSBits is set, perform type match, otherwise do category match.
} vmObjectCategory;

typedef enum {
	vmObjectType_notVMObject		=	0,
	//	base
	vmObjectType_data				=	vmObjectCategory_base		| 	0x1		|	vmObjectCategory_unresolveable,
	vmObjectType_reference			= 	vmObjectCategory_reference	|	0x1,
	vmObjectType_unresolved			=	vmObjectCategory_abstract	|	0x2		|	vmObjectCategory_unresolveable,
	vmObjectType_unknown			=   vmObjectCategory_abstract	|	0x3		|	vmObjectCategory_unresolveable,
	
	//	functions 
	vmObjectType_function			=	vmObjectCategory_function	|	0x11	|	vmObjectCategory_unresolveable,
	
	//	chance and tags
	vmObjectType_tag /*unused*/		=	vmObjectCategory_function	|	0x21	|	vmObjectCategory_unresolveable,
	vmObjectType_tagList			=	vmObjectCategory_function	|	0x22	|	vmObjectCategory_unresolveable,
	vmObjectType_chance				=	vmObjectCategory_function	|	0x41,
	vmObjectType_scoreModifier		=	vmObjectCategory_function	|	0x42	|	vmObjectCategory_unresolveable,
	vmObjectType_stimulator			=	vmObjectCategory_function	|	0x43	|	vmObjectCategory_unresolveable,
	
	//	audio
	vmObjectType_audioInfo			=	vmObjectCategory_media		|	0x11,
	vmObjectType_audioModifier		=	vmObjectCategory_media		| 	0x12,
	
	//	static song structure
	vmObjectType_cue				=	vmObjectCategory_cue		|	vmObjectCategory_songStruture	|	0x01	|	vmObjectCategory_unresolveable,
	vmObjectType_audioCue			=	vmObjectCategory_cue		|	vmObjectCategory_songStruture	|	0x03,
	vmObjectType_visualCue			=	vmObjectCategory_cue		|	vmObjectCategory_songStruture	|	0x04,	/*unused*/
	vmObjectType_textCue			=	vmObjectCategory_cue		|	vmObjectCategory_songStruture	|	0x05,	/*unused*/
	vmObjectType_voiceCue			=	vmObjectCategory_cue		|	vmObjectCategory_songStruture	|	0x06,	/*unused*/
	vmObjectType_genericCue			=	vmObjectCategory_cue		|	vmObjectCategory_songStruture	|	0x11,	/*unused*/
	vmObjectType_metaCue			=	vmObjectCategory_cue		|	vmObjectCategory_songStruture	|	0x12,

	vmObjectType_cueCollection		=	vmObjectCategory_abstract	|	vmObjectCategory_songStruture	|	0x21	|	vmObjectCategory_unresolveable,
	vmObjectType_layerList			=	vmObjectCategory_cue		|	vmObjectCategory_songStruture	|	0x22,
	vmObjectType_selector			=	vmObjectCategory_abstract	|	vmObjectCategory_songStruture	|	0x23,
	vmObjectType_sequence			=	vmObjectCategory_cue		|	vmObjectCategory_songStruture	|	0x24,
	
	//	dynamic song objects
	vmObjectType_liveData			=	vmObjectCategory_abstract	|	vmObjectCategory_runtime		|	0x01,
	vmObjectType_player				=	vmObjectCategory_cue		|	vmObjectCategory_runtime		|	0x02,
} vmObjectType;

typedef union {
	vmObjectType		objectType;
	vmObjectCategory	objectCategory;
} vmObjectTypeDescriptor;

typedef enum {
	vmAction_play	 = 0,
	vmAction_prepare
} VMActionType;

@interface VMTimeRangeDescriptor : NSObject <NSCoding, NSCopying>
@property (nonatomic, retain) VMString *locationDescriptor;
@property (nonatomic, retain) VMString *lengthDescriptor;

- (VMTime)location;
- (VMTime)length;
- (VMTime)start;	//	alias for location
- (VMTime)end;
- (VMFloat)bpm;
+ (void)splitTimeDescriptor:(NSString*)descriptor
				  numerator:(VMFloat*)outNumerator
				denominator:(VMInt  *)outDenominator
						bpm:(VMFloat*)outBPM;
+ (VMTime)secondsFromTimeDescriptor:(NSString*)descriptor;

@end



#pragma mark -
#pragma mark Data Structure
#pragma mark -

//--------------------------------------------------------------------------
//
//		Data Structure
//
//--------------------------------------------------------------------------

/**
 *    the data class tree
 *
 * level/layer
 *    1/base        2/category      3/meta            4/static media     5/concrete      6/collection    7/dynamic       8/runtime
 *
 *    [VMData]┬--- [VMCue]--------- [VMMetaCue]-------------------------- [VMAudioCue] ----------------- [VMAudioCuePlayer]
 *            |                            |    └---- [VMAudioInfo]------ [VMAudioModifier]
 *            |                            └ [VMCueCollection]---------┬- [VMLayerList]
 *            |                                                        ├---------------- [VMSelector]
 *            |                                                        ├---------------- [VMSequence]
 *            |                                                        └-------------------------------- [VMLiveData]--- [VMPlayer]
 *            ├---[VMReference]--┬- [VMChance]
 *            |                  └- [VMUnresolved]
 *            |
 *            └- (uncatecorized) ---[VMStimulator]
 *                            ├---- [VMTaglist]
 *                            ├---------------------------------------- [VMScoreModifier]
 *                            └---- [VMFunction]
 */

//------------------------ Data -----------------------------
/*
 the base class (identifier)
 */
@interface VMData : NSObject <VMObjectInitialization, NSCoding, NSCopying> {
@protected
	vmObjectType	type_;
	BOOL			shouldRegister_;
#ifdef DEBUG
	VMId			*id_;
#endif
}
@property 	(VMNonatomic copy)			VMId			*id;
@property	(VMNonatomic assign)		vmObjectType	type;
@property	(VMNonatomic readonly)		BOOL			shouldRegister;
@property	(VMNonatomic copy)			NSString		*comment;
@end

//------------------------ Reference (abstract) ---------------------
/*
 reference to other object
 */
@interface VMReference : VMData
@property	(VMNonatomic copy)			VMId			*referenceId;
@end

//------------------------ Unresolved (abstract) ---------------------
/*
 marking unresolved objects (reference = nil)
 */
@interface VMUnresolved : VMReference
@end


//------------------------ Cue (abstract) -----------------------
/*
 everything cue-able
 */
@interface VMCue : VMData
@end

//------------------------ Function -----------------------------
/*
 a static function definition	
 */
@interface VMFunction : VMData {
	SEL		processor_;
#ifdef DEBUG
	VMId			*functionName_;
	VMHash			*parameter_;
#endif
}
@property	(VMNonatomic retain)	VMId			*functionName;
@property	(VMNonatomic retain)	VMHash			*parameter;
@end

//------------------------- MetaCue -----------------------------
/*
 a cue with instruction
 */
@interface VMMetaCue : VMCue 
@property	(VMNonatomic retain)	VMArray			*instructionList;
@end

//------------------------ AudioInfo -----------------------------
/*
 information about audio file
 */
@interface VMAudioInfo : VMMetaCue {
	VMId	*fileId_;
}
@property	(VMNonatomic copy)		VMId						*fileId;
@property	(VMNonatomic)			VMVolume					volume;
@property	(VMNonatomic retain)	VMTimeRangeDescriptor		*cuePoints;
@property	(VMNonatomic retain)	VMTimeRangeDescriptor		*regionRange;
@end

//------------------------ AudioModifier ------------------------
/*
 information about audio playback
 */
@interface VMAudioModifier : VMAudioInfo
@property	(VMNonatomic copy)		VMId				*originalId;
@end

//------------------------ TagList -----------------------------
/*
 tags
 */
@interface VMTagList : VMData
@property	(VMNonatomic retain)	VMArray	/*<VMId>*/	*tagArray;
@end

//------------------------ ScoreModifier --------------------------
/*
 define the amount of a tag affects the score
 */
@interface VMScoreModifier : VMData
@property	(VMNonatomic copy)		VMId 				*tagName;
@property	(VMNonatomic)			VMFloat				factor;
@end


//------------------------ Stimulator --------------------------
/*
 interraction source which affects the scores of tagged chances
 */
@interface VMStimulator : VMData
@property	(VMNonatomic copy)		VMId				*source;
@property	(VMNonatomic retain)	VMArray /*<ScoreModifier>*/ *modifiers;
@end




/**----------------------------- stimulator relation ------------------------------

 
 the relation between stimulator, modifier and tagList should look like:
 
 //--- stimulators including modifiers ---
 
 {	source:"cameraGreen",
 modifiers:["forest*3","ocean*0.3"] }
 {	source:"cameraBlue",
 modifiers:["forest*0.6","ocean*2"] }
 
 //--- tagList-s ---
 
 {	id:"gotoWood",	tag:["forest"]	}
 {	id:"gotoCoast",	tag:["ocean"] }
 {	id:"gotoPlain",	tag:["forest","ocean"] }
 
 //--- selector ---
 
 {	selector:["wood_001;gotoWood","coast_001;gotoCoast","plain_001;gotoPlain"]	}
 
 
 */



//------------------------ AudioCue -----------------------------
/*
 cue with audio
 */
@interface VMAudioCue : VMMetaCue {
	__weak VMAudioInfo	*audioInfoRef_;
}
@property	(nonatomic, copy)		VMId			*audioInfoId;

//	audioInfoReference 
//	note: 	this is defined here just for runtime convenience, 
//			actually not a part of static song stucture.
//			set by the preprocessor, but not copied with setWithData: or setWithProto:
@property 	(weak)					VMAudioInfo		*audioInfoRef;
@end

//------------------------ AudioCuePlayer -----------------------------
/*
 dynamic data while playing 
 */
@interface VMAudioCuePlayer : VMAudioCue
@property	(VMNonatomic assign)	VMAudioCue		*nextLayer;
@end



//------------------------ Chance -----------------------------
/*
 a cue with probability
 */
@interface VMChance : VMReference {
@private
	VMFloat		cachedScore_;
}
@property	(VMNonatomic copy)		VMString		*scoreDescriptor;
@property	(VMNonatomic copy)		VMId			*targetId;

@property	(VMNonatomic)			VMFloat			primaryFactor;
@property	(nonatomic, readonly)	VMFloat			evaluatedScore;
@property 	(nonatomic, readonly)	VMFloat			cachedScore;

@end

/**----------------------------- chance instruction ------------------------------
 
 chance string should look like:
 
 targetCueId=scoreDescriptor	ex:	a_001_forest=3*greenTL
 or
 targetCueId					ex:	a_001
 
 a score descriptor looks like:
 
primary factor expressed in decimal value		ex:		1	or 	1.3
 or
 expression 									ex:		C>1		or		someTagList		or		(C>1)*someTagList
 or
 combination of these.							ex:		2*(C>1)*someTagList
 
 */

//-------------------- CueCollection (abstract) -----------------------------
/*
 generic collection of cues (abstract)
 */
@interface VMCueCollection : VMMetaCue 
@property	(VMNonatomic retain)	VMArray			*cues;
@property	(VMNonatomic readonly)	VMInt			length;		
@end

//------------------------ LiveData -----------------------------
/*
 runtime properties
 */
@interface VMLiveData : VMCueCollection
@property	(VMNonatomic assign)	VMInt		counter;
@property 	(VMNonatomic assign)	VMInt		cuePosition;
@property	(VMNonatomic retain)	VMArray		*history;
//	accessor
@property 	(VMNonatomic readonly)	VMCue		*currentCue;	
@property	(VMNonatomic readonly)	VMCue		*nextCue;
@end



//------------------------ Selector -----------------------------
/*
 cue collection selector
 */
@interface VMSelector : VMCueCollection {
	VMFloat			sumOfInnerScores_cache_;	//	for improve performance
	VMChance		*selectedChance_;			//	for internal temporaly use
}
- (VMChance*)chanceAtIndex:(VMInt)pos;
@property	(VMNonatomic retain)	VMLiveData	*liveData;
@end


//-------------------- Player -----------------------------
/*
 generic player
 */
@interface VMPlayer : VMLiveData {
@private
#ifdef DEBUG
	VMPlayer 	*nextPlayer_;
	VMId		*staticDataId_;
#endif
	
}
@property	(VMNonatomic retain)	VMCue	 	*nextPlayer;
@property	(VMNonatomic copy)		VMId		*staticDataId;
@end

//------------------------ LayerList -----------------------------
/*
 cue collection layer
 */
@interface VMLayerList : VMCueCollection
@end


//------------------------ Sequence -----------------------------
/*
 cue collection sequence
 */
@interface VMSequence : VMCueCollection
//	the cue which should be set after finishing sequence.
//	only used if sequence has no parent sequence
@property 	(VMNonatomic retain)	VMSelector		*subsequent;	
@end




#pragma mark -
#pragma mark Methods
#pragma mark -

//--------------------------------------------------------------------------
//
//		Methods
//
//--------------------------------------------------------------------------

//------------------------ Data -----------------------------
@interface VMData(publicMethods)
//	type
- (id)matchMask:(int)mask;
- (id)resolveUntilType:(int)mask;
- (VMString*)stringExpression;
- (void)feedEvaluator;
@end

//------------------------ Function --------------------------
@interface VMFunction(publicMethods)
- (id)firstParameterValue;
- (id)valueForParameter:(VMString*)parameterName;
- (BOOL)isEqualToFunction:(VMFunction*)aFunc;
- (id)processWithData:(id)data action:(VMActionType)action;
- (BOOL)doesChangeCueOrder;
@end




//------------------------ Cue -----------------------------
@interface VMCue(publicMethods)
//	dataId components accessor
@property	(VMNonatomic retain)	VMId		*cueId;
@property 	(VMNonatomic assign)	VMId		*partId;
@property 	(VMNonatomic assign)	VMId		*sectionId;
@property 	(VMNonatomic assign)	VMId		*trackId;
@property	(VMNonatomic assign)	VMId		*variantId;
@property	(VMNonatomic assign)	VMId		*VMPModifier;
//	util
- (NSString*)userGeneratedId;
//- (VMCue*)resolve;
@end

//------------------------ MetaCue --------------------------
@interface VMMetaCue(publicMethods)
- (void)interpreteInstructionsWithAction:(VMActionType)action;
- (void)interpreteInstructionsWithData:(VMData*)data action:(VMActionType)action;
- (VMFunction*)functionWithName:(VMString*)functionName;
- (BOOL)hasFunction:(VMString*)functionName;
- (BOOL)shouldSelectTemporary;
@end


//------------------------ AudioInfo -----------------------------
@interface VMAudioInfo(publicMethods2)
//	cue points alias
@property	(VMNonatomic readonly)	VMTime			duration;
@property	(VMNonatomic readonly)	VMTime			offset;

- (BOOL)hasExplicitlySpecifiedFileId;

@end


//------------------------ AudioCue -----------------------------
/*
 cue with audio info
 */
@interface VMAudioCue(publicMethods)
//	audioInfoWrapper
@property	(VMNonatomic readonly)	VMId			*fileId;
@property	(VMNonatomic readonly)	VMTime			duration;
@property	(VMNonatomic readonly)	VMTime			offset;
@property	(VMNonatomic readonly)	VMVolume		volume;
@property	(VMNonatomic readonly)	VMTime			modulatedDuration;
@property	(VMNonatomic readonly)	VMTime			modulatedOffset;
//@property	(VMNonatomic readonly)	VMTime			durationBetweenCuePoints;


@end

//------------------------- MetaCue ------------------------------
@interface VMMetaCue(publicMethods2)
- (void)interpreteInstructions;
- (void)setInstructionsByString:(VMString*)instString;
@end

//------------------------ CueCollection -----------------------------
/*
 generic collection of cues
 */
@interface VMCueCollection (publicMethods)
- (VMChance*)chanceWithId:(VMId*)dataId;
- (VMChance*)chanceWithTargetId:(VMId*)targetId;
- (VMCue*)cueAtIndex:(VMInt)pos;
//- (VMInt)cueCount;
- (VMArray*)cueIdList;
- (void)addCuesWithData:(id)data;
- (void)convertCueObjectsToReference;
@end

//------------------------ LiveData -----------------------------
/*
 runtime properties
 */
@interface VMLiveData (publicMethods)
- (void)advance;
- (BOOL)finished;
- (void)reset;
@end


//------------------------ Selector -----------------------------
/*
 cue collection selector
*/
@interface VMSelector (publicMethods)
- (VMCue*)selectOne;
- (VMCue*)selectOneTemporaryUsingScores:(VMHash*)scoreForCues sumOfScores:(VMFloat)sum;
- (VMFloat)sumOfInnerScores;
- (VMInt)counter;
- (void)prepareLiveData;
- (void)prepareSelection;

//	return value is reference to a static VMHash.	copy if you want hold the result.
- (VMHash*)collectScoresOfCues:(VMFloat)parentScore frameOffset:(VMInt)counterOffset normalize:(BOOL)normalize;	
@end

//------------------------ Player -----------------------------
/*
 player 
 (needs to be instanized at playback because it has a dynamic property)
 actually, not a data-type.
 */


@interface VMPlayer (publicMethods)
- (BOOL)finished;

//- (VMCue*)resolveAudioCueOrPlayer;

@end












//
//  VMDataTypes.h
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
- (id)initWithProto:(id)proto;
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
	vmObjectCategory_fragment		=	1 << 14,
	vmObjectCategory_runtime		=	1 << 15,
	vmObjectCategory_any			=	0x0FF80,	
	vmObjectMatch_type				= 	0x0007F		//	if one of 7 LSBits is set, perform type match, otherwise do category match.
} vmObjectCategory;

typedef enum {
	vmObjectType_notVMObject	=	0,
	//	base
	vmObjectType_data			=	vmObjectCategory_base		| 	0x1		|	vmObjectCategory_unresolveable,
	vmObjectType_reference		= 	vmObjectCategory_reference	|	0x1,
	vmObjectType_unresolved		=	vmObjectCategory_abstract	|	0x2		|	vmObjectCategory_unresolveable,
	vmObjectType_unknown		=   vmObjectCategory_abstract	|	0x3		|	vmObjectCategory_unresolveable,
	
	//	functions 
	vmObjectType_function		=	vmObjectCategory_function	|	0x11	|	vmObjectCategory_unresolveable,
	
	//	chance and tags
	vmObjectType_tag /*unused*/	=	vmObjectCategory_function	|	0x21	|	vmObjectCategory_unresolveable,
	vmObjectType_chance			=	vmObjectCategory_function	|	0x41,
	vmObjectType_transformer	=	vmObjectCategory_function	|	0x42	|	vmObjectCategory_unresolveable,
	vmObjectType_stimulator		=	vmObjectCategory_function	|	0x43	|	vmObjectCategory_unresolveable,
	
	//	audio
	vmObjectType_audioInfo		=	vmObjectCategory_media		|	0x11,
	vmObjectType_audioModifier	=	vmObjectCategory_media		| 	0x12,
	
	//	static song structure
	vmObjectType_fragment		=	vmObjectCategory_fragment	|	vmObjectCategory_songStruture	|	0x01	|	vmObjectCategory_unresolveable,
	vmObjectType_audioFragment  =	vmObjectCategory_fragment	|	vmObjectCategory_songStruture	|	0x03,
	vmObjectType_imageFragment  =	vmObjectCategory_fragment	|	vmObjectCategory_songStruture	|	0x04,	/*unused*/
	vmObjectType_textFragment	=	vmObjectCategory_fragment	|	vmObjectCategory_songStruture	|	0x05,	/*unused*/
	vmObjectType_voiceFragment	=	vmObjectCategory_fragment	|	vmObjectCategory_songStruture	|	0x06,	/*unused*/
	vmObjectType_genericFragment=	vmObjectCategory_fragment	|	vmObjectCategory_songStruture	|	0x11,	/*unused*/
	vmObjectType_metaFragment	=	vmObjectCategory_fragment	|	vmObjectCategory_songStruture	|	0x12,

	vmObjectType_collection		=	vmObjectCategory_abstract	|	vmObjectCategory_songStruture	|	0x21	|	vmObjectCategory_unresolveable,
	vmObjectType_layerList		=	vmObjectCategory_fragment	|	vmObjectCategory_songStruture	|	0x22,
	vmObjectType_selector		=	vmObjectCategory_abstract	|	vmObjectCategory_songStruture	|	0x23,
	vmObjectType_sequence		=	vmObjectCategory_fragment	|	vmObjectCategory_songStruture	|	0x24,
	
	//	dynamic song objects
	vmObjectType_liveData		=	vmObjectCategory_abstract	|	vmObjectCategory_runtime		|	0x01,
	vmObjectType_player			=	vmObjectCategory_fragment	|	vmObjectCategory_runtime		|	0x02,
	vmObjectType_audioFragmentPlayer
								=	vmObjectCategory_fragment	|	vmObjectCategory_runtime		|	0x03,
} vmObjectType;

typedef enum {
	vmAction_play	 = 0,
	vmAction_prepare
} VMActionType;

@interface VMTimeRangeDescriptor : NSObject <NSCoding, NSCopying> {
#if SUPPORT_32BIT_MAC
	VMString *locationDescriptor_;
	VMString *lengthDescriptor_;
#endif
}
@property (nonatomic, VMStrong) VMString *locationDescriptor;
@property (nonatomic, VMStrong) VMString *lengthDescriptor;

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
 *    1/base        2/category      3/            4/static media     5/concrete      6/collection    7/dynamic       8/runtime
 *
 *    [VMData]┬--- [VMFragment]---- [VMMetaFragment]--------------------- [VMAudioFragment] --------- [VMAudioFragmentPlayer]
 *            |                            |    └---- [VMAudioInfo]------ [VMAudioModifier]
 *            |                            └ [VMCollection]------------┬- [VMLayerList]
 *            |                                                        ├---------------- [VMSelector]
 *            |                                                        ├---------------- [VMSequence]
 *            |                                                        └----------------------------- [VMLiveData]--- [VMPlayer]
 *            ├---[VMReference]--┬- [VMChance]
 *            |                  └- [VMUnresolved]
 *            |
 *            └- (uncatecorized) -- [VMStimulator]
 *                            ├---- [VMTransformer]
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
	VMId			*id_;
#if SUPPORT_32BIT_MAC
	VMString		*comment_;
#endif
}
@property 	(nonatomic, copy)			VMId			*id;
@property	(nonatomic, assign)			vmObjectType	type;
@property	(nonatomic, readonly)		BOOL			shouldRegister;
@property	(nonatomic, copy)			NSString		*comment;
@end

//------------------------ Reference (abstract) ---------------------
/*
 reference to other object
 */
@interface VMReference : VMData {
#if SUPPORT_32BIT_MAC
	VMId			*referenceId_;
#endif
}
@property	(nonatomic, copy)			VMId			*referenceId;
@end

//------------------------ Unresolved (abstract) ---------------------
/*
 marking unresolved objects (reference = nil)
 */
@interface VMUnresolved : VMReference
@end


//------------------------ Fragment (abstract) -----------------------
/*
 a fragment of some media
 */
@interface VMFragment : VMData
@end

//------------------------ Function -----------------------------
/*
 a static function definition	
 */
@interface VMFunction : VMData {
#if SUPPORT_32BIT_MAC
	VMId	*functionName_;
	VMHash	*parameter_;
#endif
	SEL		processor_;
}
@property	(nonatomic, VMStrong)	VMId			*functionName;
@property	(nonatomic, VMStrong)	VMHash			*parameter;
@end

//------------------------- MetaFragment -----------------------------
/*
 a fragment with instruction
 */
@interface VMMetaFragment : VMFragment {
#if SUPPORT_32BIT_MAC
	VMArray			*instructionList_;
#endif

}
@property	(nonatomic, VMStrong)	VMArray			*instructionList;
@end

//------------------------ AudioInfo -----------------------------
/*
 information about audio file
 */
@interface VMAudioInfo : VMMetaFragment {
#if SUPPORT_32BIT_MAC
	VMId						*fileId_;
	VMVolume					volume_;
	VMTimeRangeDescriptor		*cuePoints_;
	VMTimeRangeDescriptor		*regionRange_;
#endif
}
@property	(nonatomic, copy)		VMId						*fileId;
@property	(nonatomic, assign)		VMVolume					volume;
@property	(nonatomic, VMStrong)	VMTimeRangeDescriptor		*cuePoints;
@property	(nonatomic, VMStrong)	VMTimeRangeDescriptor		*regionRange;
@end

//------------------------ AudioModifier ------------------------
/*
 information about audio playback, add audio-file modification such as volume, cue-point, EQ, compression, here.
 */
@interface VMAudioModifier : VMAudioInfo {
#if SUPPORT_32BIT_MAC
	VMId	*originalId_;
#endif
}
@property	(nonatomic, copy)		VMId				*originalId;
@end

//------------------------ Transformer --------------------------
/*
 evaluate expression and transform multiple factros into one output value
 */
@interface VMTransformer : VMData {
#if SUPPORT_32BIT_MAC
	VMString	*scoreDescriptor_;
#endif

}
@property	(nonatomic, copy)		VMString 			*scoreDescriptor;
@property	(nonatomic, readonly)	VMFloat				currentValue;
@end


//------------------------ Stimulator --------------------------
/*
 external input definition
  */
@interface VMStimulator : VMData {
#if SUPPORT_32BIT_MAC
	VMId	*source_;
	VMId	*key_;
#endif

}
@property	(nonatomic, copy)		VMId				*source;
@property	(nonatomic, copy)		VMId				*key;
@property	(nonatomic, readonly)	VMFloat				currentValue;
@end


/*---------------------------------------------------------------------------------
 *	Stimulator and Transformer (refactored)
 *
 *	example 1: react to camera input
 *
 *	{ type="Stimulator", id:"@Camera{Red}"	}												//	built-in definition
 *	{ type="Stimulator", id:"@Camera{Blue}"	}												//	built-in definition
 *	{ type="Stimulator", id:"@Camera{Saturation}"	}										//	built-in definition
 *
 *	{ type="Transformer", id:"FeelsWarm",	score:"@Limit{(@Camera{Red}*0.5)+(@Camera{Saturation}*0.5)}"	},	//	user defined
 *	{ type="Transformer", id:"FeelsCold",	score:"@Limit{(@Camera{Blue}*0.5)+(1-@Camera{Saturation}*0.5)}"	},	//	user defined
 *
 *	{ type="Selector", sel:["ocean_beach=FeelsWarm","home_bed=FeelsCold"] }
 *
 *
 *	example 2: react to tag information
 *
 *	{ type="Stimulator", id:"@Tag{fresh}"	}
 *	{ type="Stimulator", id:"@Tag{cold}"	}
 *
 *	{ type="Transformer", id:"EarlyMorning",	score:"(@Tag{fresh}*.5)+(@Tag{cold}*.5)+(@Tag{fresh}*@Tag{cold}*0.5)"	}
 *	
 *	{ type="Selector", sel:["dawn=EarlyMorning","noon=1-EarlyMorning","night=@Tag{cold}"] }
 *
 *---------------------------------------------------------------------------------*/




//------------------------ AudioFragment -----------------------------
/*
 fragment with audio
 */
@interface VMAudioFragment : VMMetaFragment {
#if SUPPORT_32BIT_MAC
	VMId		*audioInfoId_;
	VMAudioInfo	*audioInfoRef_;
#endif

}
@property	(nonatomic, copy)		VMId			*audioInfoId;

//	audioInfoReference 
//	note: 	this is defined here just for runtime convenience, 
//			actually not a part of static song stucture.
//			set by the preprocessor, but not copied with setWithData: or setWithProto:
@property 	(unsafe_unretained)		VMAudioInfo		*audioInfoRef;
@end

//------------------------ AudioFragmentPlayer -----------------------------
/*
 dynamic data related to audio fragment.
 */
@interface VMAudioFragmentPlayer : VMAudioFragment {
#if SUPPORT_32BIT_MAC
	VMTime	firedTimestamp_;
#endif
}
//@property	(nonatomic, assign)		VMAudioFragment	*nextLayer;			//	re-design in future.
@property	(nonatomic, assign)		VMTime			firedTimestamp;
@end



//------------------------ Chance -----------------------------
/*
 a fragment with probability
 */
@interface VMChance : VMReference {
@private
	VMFloat		cachedScore_;
#if SUPPORT_32BIT_MAC
@protected
	VMString	*scoreDescriptor_;
	
#endif
}
@property	(nonatomic, copy)		VMString		*scoreDescriptor;
@property	(nonatomic, copy)		VMId			*targetId;

@property	(nonatomic, VMWeak)		VMFloat			primaryFactor;
@property	(nonatomic, readonly)	VMFloat			evaluatedScore;
@property 	(nonatomic, readonly)	VMFloat			cachedScore;

@end

//-------------------- Collection (abstract) -----------------------------
/*
 generic collection of fragments (abstract)
 */
@interface VMCollection : VMMetaFragment {
#if SUPPORT_32BIT_MAC
	VMArray	*frags_;
#endif
}
@property	(nonatomic, VMStrong)	VMArray			*fragments;
@property	(nonatomic, readonly)	VMInt			length;
@end

//------------------------ LiveData -----------------------------
/*
 runtime properties
 */
@interface VMLiveData : VMCollection {
#if SUPPORT_32BIT_MAC
	VMInt			counter_;
	VMInt			fragPosition_;
	VMArray			*history_;
#endif
	
}
@property	(nonatomic, assign)	VMInt			counter;
@property 	(nonatomic, assign)	VMInt			fragPosition;
@property	(nonatomic, VMStrong)	VMArray			*history;
//	accessor
@property 	(nonatomic, VMReadonly)	VMFragment		*currentFragment;	
@property	(nonatomic, VMReadonly)	VMFragment		*nextFragment;
@end



//------------------------ Selector -----------------------------
/*
 fragments collection selector
 */
@interface VMSelector : VMCollection {
	VMFloat			sumOfInnerScores_cache_;	//	for improve performance
	VMChance		*selectedChance_;			//	for internal temporary use
#if SUPPORT_32BIT_MAC
	VMLiveData		*liveData_;
#endif
}
@property	(VMNonatomic VMStrong)	VMLiveData	*liveData;
@end


//-------------------- Player -----------------------------
/*
 generic player
 */
@interface VMPlayer : VMLiveData {
#if SUPPORT_32BIT_MAC
	VMFragment	*nextPlayer_;
	VMId		*staticDataId_;
#endif

}
@property	(nonatomic, VMStrong)	VMFragment	*nextPlayer;
@property	(nonatomic, copy)		VMId		*staticDataId;
@end

//------------------------ LayerList -----------------------------
/*
 fragments collection layer
 */
@interface VMLayerList : VMCollection
@end


//------------------------ Sequence -----------------------------
/*
 fragments collection sequence
 */
@interface VMSequence : VMCollection {
#if SUPPORT_32BIT_MAC
	VMSelector	*subsequent_;
#endif
}
//	the fragment which should be set after finishing sequence.
//	only used if sequence has no parent sequence
@property 	(nonatomic, VMStrong)	VMSelector		*subsequent;	
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
- (BOOL)containsId:(VMId*)dataId;

- (VMString*)stringExpression;
- (void)feedEvaluator;
@end

//------------------------ Function --------------------------
@interface VMFunction(publicMethods)
- (id)firstParameterValue;
- (id)valueForParameter:(VMString*)parameterName;
- (BOOL)isEqualToFunction:(VMFunction*)aFunc;
- (id)processWithData:(id)data action:(VMActionType)action;
- (BOOL)doesChangeFragmentsOrder;
@end




//------------------------ Fragment -----------------------------
@interface VMFragment(publicMethods)
//	dataId components accessor
@property	(nonatomic, VMStrong)	VMId	*fragId;
@property 	(nonatomic, assign)	VMId		*partId;
@property 	(nonatomic, assign)	VMId		*sectionId;
@property 	(nonatomic, assign)	VMId		*trackId;
@property	(nonatomic, assign)	VMId		*variantId;
@property	(nonatomic, assign)	VMId		*VMPModifier;
//	util
- (VMId*)userGeneratedId;
- (VMId*)fileIdPart;
- (void)idComponentsForPart:(VMId**)part_p section:(VMId**)section_p track:(VMId**)track_p;
@end

//------------------------ MetaFragment --------------------------
@interface VMMetaFragment(publicMethods)
- (void)interpreteInstructionsWithAction:(VMActionType)action;
- (void)interpreteInstructionsWithData:(VMData*)data action:(VMActionType)action;
- (VMFunction*)functionWithName:(VMString*)functionName;
- (BOOL)hasFunction:(VMString*)functionName;
- (BOOL)shouldSelectTemporary;
- (void)interpreteInstructions;
- (void)setInstructionsByString:(VMString*)instString;
@end


//------------------------ AudioInfo -----------------------------
@interface VMAudioInfo(publicMethods)
//	cue points alias
@property	(nonatomic, readonly)	VMTime			duration;
@property	(nonatomic, readonly)	VMTime			offset;

- (BOOL)hasExplicitlySpecifiedFileId;

@end


//------------------------ AudioFragment -----------------------------
/*
 fragment of audio
 */
@interface VMAudioFragment(publicMethods)
//	audioInfoWrapper
@property	(nonatomic, VMReadonly)	VMId			*fileId;
@property	(nonatomic, readonly)	VMTime			duration;
@property	(nonatomic, readonly)	VMTime			offset;
@property	(nonatomic, readonly)	VMVolume		volume;
@property	(nonatomic, readonly)	VMTime			modulatedDuration;
@property	(nonatomic, readonly)	VMTime			modulatedOffset;
@end

@interface VMAudioFragmentPlayer(publicMethods)
@end

//------------------------ Collection -----------------------------
/*
 generic collection of fragments
 */
@interface VMCollection (publicMethods)
- (VMChance*)chanceWithId:(VMId*)dataId;
- (VMChance*)chanceWithTargetId:(VMId*)targetId;
- (VMFragment*)fragmentAtIndex:(VMInt)pos;
- (VMArray*)fragmentIdList;
- (void)addFragmentsWithData:(id)data;
- (void)convertFragmentObjectsToReference;
- (VMTime)averageDuration;	//	abstract
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
 fragments collection selector
*/
@interface VMSelector (publicMethods)
@property (nonatomic, readonly, getter=isDeadEnd) BOOL deadEnd;

- (VMChance*)chanceAtIndex:(VMInt)pos;
- (VMFragment*)selectOne;
- (VMFragment*)selectOneTemporaryUsingScores:(VMHash*)scoreForFragments sumOfScores:(VMFloat)sum;
- (VMFloat)sumOfInnerScores;
- (VMInt)counter;
- (void)prepareLiveData;
- (void)prepareSelection;
- (BOOL)useSubsequentOfBranchFragments;
//	return value is reference to a static VMHash.	copy if you want hold the result.
- (VMHash*)collectScoresOfFragments:(VMFloat)parentScore frameOffset:(VMInt)counterOffset normalize:(BOOL)normalize;
- (VMFloat)ratioOfDeadEndBranchesWithScores:(VMHash*)scoreForFragments sumOfScores:(VMFloat)sum;
@end

//------------------------ Player -----------------------------
/*
 player 
 (needs to be instanized at playback because it has a dynamic property)
 not a static data-type.
 */


@interface VMPlayer (publicMethods)
- (BOOL)finished;

//- (VMFragment*)resolveAudioFragmentOrPlayer;

@end












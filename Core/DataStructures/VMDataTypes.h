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
} vmObjectType;

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
	SEL		processor_;
}
@property	(VMNonatomic retain)	VMId			*functionName;
@property	(VMNonatomic retain)	VMHash			*parameter;
@end

//------------------------- MetaFragment -----------------------------
/*
 a fragment with instruction
 */
@interface VMMetaFragment : VMFragment 
@property	(VMNonatomic retain)	VMArray			*instructionList;
@end

//------------------------ AudioInfo -----------------------------
/*
 information about audio file
 */
@interface VMAudioInfo : VMMetaFragment {
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

//------------------------ Transformer --------------------------
/*
 evaluate expression and transform multiple factros into one output value
 */
@interface VMTransformer : VMData
@property	(VMNonatomic copy)		VMString 			*scoreDescriptor;
@property	(VMNonatomic readonly)	VMFloat				currentValue;
@end


//------------------------ Stimulator --------------------------
/*
 external input definition
  */
@interface VMStimulator : VMData
@property	(VMNonatomic copy)		VMId				*source;
@property	(VMNonatomic copy)		VMId				*key;
@property	(VMNonatomic readonly)	VMFloat				currentValue;
@end


/*---------------------------------------------------------------------------------
 *	Stimulator and Transformer (refactored)
 *
 *	example 1: react to camera input
 *
 *	{ type="Stimulator", id:"@Camera{Red}"	}												//	this is a built-in definition
 *	{ type="Stimulator", id:"@Camera{Blue}"	}												//	this is a built-in definition
 *	{ type="Stimulator", id:"@Camera{Saturation}"	}										//	this is a built-in definition
 *
 *	{ type="Transformer", id:"FeelsWarm",	score:"@Limit{(@Camera{Red}*0.5)+(@Camera{Saturation}*0.5)}"	},	//	user definition
 *	{ type="Transformer", id:"FeelsCold",	score:"@Limit{(@Camera{Blue}*0.5)+(1-@Camera{Saturation}*0.5)}"	},	//	user definition
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
	__weak VMAudioInfo	*audioInfoRef_;
}
@property	(nonatomic, copy)		VMId			*audioInfoId;

//	audioInfoReference 
//	note: 	this is defined here just for runtime convenience, 
//			actually not a part of static song stucture.
//			set by the preprocessor, but not copied with setWithData: or setWithProto:
@property 	(weak)					VMAudioInfo		*audioInfoRef;
@end

//------------------------ AudioFragmentPlayer -----------------------------
/*
 dynamic data while playing 
 */
@interface VMAudioFragmentPlayer : VMAudioFragment
@property	(VMNonatomic assign)	VMAudioFragment		*nextLayer;
@end



//------------------------ Chance -----------------------------
/*
 a fragment with probability
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

//-------------------- Collection (abstract) -----------------------------
/*
 generic collection of fragments (abstract)
 */
@interface VMCollection : VMMetaFragment 
@property	(VMNonatomic retain)	VMArray			*fragments;
@property	(VMNonatomic readonly)	VMInt			length;		
@end

//------------------------ LiveData -----------------------------
/*
 runtime properties
 */
@interface VMLiveData : VMCollection
@property	(VMNonatomic assign)	VMInt			counter;
@property 	(VMNonatomic assign)	VMInt			fragPosition;
@property	(VMNonatomic retain)	VMArray			*history;
//	accessor
@property 	(VMNonatomic readonly)	VMFragment		*currentFragment;	
@property	(VMNonatomic readonly)	VMFragment		*nextFragment;
@end



//------------------------ Selector -----------------------------
/*
 fragments collection selector
 */
@interface VMSelector : VMCollection {
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
@interface VMPlayer : VMLiveData
@property	(VMNonatomic retain)	VMFragment	 	*nextPlayer;
@property	(VMNonatomic copy)		VMId		*staticDataId;
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
@interface VMSequence : VMCollection
//	the fragment which should be set after finishing sequence.
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
- (BOOL)doesChangeFragmentsOrder;
@end




//------------------------ Fragment -----------------------------
@interface VMFragment(publicMethods)
//	dataId components accessor
@property	(VMNonatomic retain)	VMId		*fragId;
@property 	(VMNonatomic assign)	VMId		*partId;
@property 	(VMNonatomic assign)	VMId		*sectionId;
@property 	(VMNonatomic assign)	VMId		*trackId;
@property	(VMNonatomic assign)	VMId		*variantId;
@property	(VMNonatomic assign)	VMId		*VMPModifier;
//	util
- (NSString*)userGeneratedId;
//- (VMFragment*)resolve;
@end

//------------------------ MetaFragment --------------------------
@interface VMMetaFragment(publicMethods)
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


//------------------------ AudioFragment -----------------------------
/*
 fragment of audio
 */
@interface VMAudioFragment(publicMethods)
//	audioInfoWrapper
@property	(VMNonatomic readonly)	VMId			*fileId;
@property	(VMNonatomic readonly)	VMTime			duration;
@property	(VMNonatomic readonly)	VMTime			offset;
@property	(VMNonatomic readonly)	VMVolume		volume;
@property	(VMNonatomic readonly)	VMTime			modulatedDuration;
@property	(VMNonatomic readonly)	VMTime			modulatedOffset;
@end

//------------------------- MetaFragment ------------------------------
@interface VMMetaFragment(publicMethods2)
- (void)interpreteInstructions;
- (void)setInstructionsByString:(VMString*)instString;
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
- (VMFragment*)selectOne;
- (VMFragment*)selectOneTemporaryUsingScores:(VMHash*)scoreForFragments sumOfScores:(VMFloat)sum;
- (VMFloat)sumOfInnerScores;
- (VMInt)counter;
- (void)prepareLiveData;
- (void)prepareSelection;

//	return value is reference to a static VMHash.	copy if you want hold the result.
- (VMHash*)collectScoresOfFragments:(VMFloat)parentScore frameOffset:(VMInt)counterOffset normalize:(BOOL)normalize;	
@end

//------------------------ Player -----------------------------
/*
 player 
 (needs to be instanized at playback because it has a dynamic property)
 actually, not a data-type.
 */


@interface VMPlayer (publicMethods)
- (BOOL)finished;

//- (VMFragment*)resolveAudioFragmentOrPlayer;

@end












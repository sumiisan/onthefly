//
//  VMPreprocessor.h
//  VariableMusicPlayer
//
//  Created by  on 12/11/19.
//  Copyright (c) 2012 sumiisan (aframasda.com). All rights reserved.
//


/**
 	the variable music player roadmap (v1)
 
 	version 1
 		-	playback of non-interractive vms, the basic preprocessor
 		-	source code for compiling stand-alone app (iOS, OSX)
 		-	vmPlayer
 
 	version 2
 		-	interraction and structure-expansion support
 		-	export compiled vmp (variable music package)
 		
	version ?
 		-	vmp editor
 		-	image / text media support
 		-	windows app ... only if my clients wants to have.
 		-	android app ... maybe not. buy iPod.
 
 */


/**
 	the expandable ( mod-able ) music definition:
 
 	songs defined with same songId will be merged ( if allowed ) in following manner: ( definition v.1.0 )
 	1. 	merge vms files into one in order as specified in overwriteOrder property.
 	2. 	merge selectors with same id.
 	3.	overwrite sequences with same id. (replace)
 	4.	for other duplicates throw error and stop.
 
 */

#import <Foundation/Foundation.h>
#import "VMDataTypes.h"
#import "VMSong.h"

#define DEFAULTPREPROCESSOR [VMPreprocessor defaultPreprocessor]

@interface VMPreprocessor : NSObject {
@public
	//	conversion tables:
	VMHash		*classForType;
	VMHash		*typeForTypeString;
	VMHash		*stringForType;
	VMHash		*shortTypeStringForType;
	VMHash		*compatibilityOrder;
	VMHash		*dialects;
	VMHash		*shortKeyword;
	//	character sets:
	NSCharacterSet *vmReservedCharacterSet;
	
//	VMArray		*propNames;
	//
	int			fatalErrors;
	int 		debugCounter;
	
@private
	__unsafe_unretained VMSong *song_;
}

@property (nonatomic,VMWeak)	VMSong	*song;

//	singleton
+ (VMPreprocessor*)defaultPreprocessor;

//	preprocess
- (BOOL)preprocess:(NSString*)vmsText error:(NSError**)outError;

//	databse access
- (id)data:(VMId*)dataId;			//	this does resolve aliases.
- (id)rawData:(VMId*)dataId;		//	this does not resolve aliases.
- (void)setData:(id)data withId:(VMId*)dataId;

//	data creation
+ (id)dataWithType:(vmObjectType)inType;
+ (id)dataWithData:(id)data;
+ (VMChance*)createOrModifyChanceWithId:(VMSelector*)selector target:(VMId*)targetId score:(VMFloat)score;

//	util
+ (Class)classForType:(vmObjectType)inType;
+ (NSString*)shortTypeStringForType:(vmObjectType)typ;
+ (NSString*)typeStringForType:(vmObjectType)typ;
+ (VMId*)idWithVMPModifier:(NSString*)dataId tag:(NSString*)tag info:(NSString*)info;
- (VMId*)completeId:(VMId*)dataId withParentId:(VMId*)parentId;
- (VMId*)purifiedId:(VMId*)fragId;

- (void)setAudioInfoRefForAllAudioFragments;

@end


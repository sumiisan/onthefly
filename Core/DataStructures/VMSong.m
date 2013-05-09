//
//  NLSong.m
//  VariableMusicPlayer
//
//  Created by cboy on 12/10/30.
//  Copyright 2012 sumiisan (aframasda.com). All rights reserved.
//

#import "VMSong.h"
#import "VMPreprocessor.h"
#import "VMScoreEvaluator.h"
#import "VMException.h"
#include "VMPMacros.h"

/*---------------------------------------------------------------------------------
 *
 *
 *	Variable Media Song
 *
 *
 *---------------------------------------------------------------------------------*/


@implementation VMSong
@synthesize songName, audioFileExtension, vsFilePath, audioFileDirectory, defaultCueId;
@synthesize songData=songData_, entryPoints=entryPoints_, history=history_;
@synthesize player;
@synthesize showReport=showReport_;

static VMSong *vmsong_singleton__;
//static BOOL reportNotRegisteredObjects = NO;
BOOL verbose = NO;

#pragma mark -
#pragma mark accessor

/*---------------------------------------------------------------------------------
 
 record (history) related
 
 ----------------------------------------------------------------------------------*/

- (void)record:(VMArray*)cueIds {
	[self.history push:cueIds];
	if( self.history.count > 2000 ) [self.history truncateFirst:1500];
}

- (VMInt)distanceToLastRecordOf:(VMId*)cueId {
	VMInt c = self.history.count;
	VMInt p = c;
	for ( int i = 0; i < c; ++i ) {
		VMArray *arr = [self.history item: --p ];
		if ( [arr position:cueId] >= 0 ) return i;
	}
	return 1e30f;	//	don't use INFINITY
}

+ (VMSong*)defaultSong {
	if( ! vmsong_singleton__ ) vmsong_singleton__ = NewInstance(VMSong);
	return vmsong_singleton__;
}

- (BOOL)isVerbose {
	return verbose;
}

- (id)data:(VMId*)dataId {
	if( ! dataId ) return nil;
    id c = [songData_ item:dataId];
	if ( ClassMatch( c, VMReference ))
		c = [self data: ClassCast( c, VMReference ).referenceId ];	//	resolve reference.
	
	if (!c && [self.showReport.current boolValue] && ( ! [dataId hasPrefix:@"*"] ))
		NSLog(@"VMSong: data for id:%@ not found!", dataId );
    return c;
}


/*---------------------------------------------------------------------------------
 
 set the song position to given cue.
 
 ----------------------------------------------------------------------------------*/

- (void)setCueId:(VMId*)cueId {
	self.player = nil;		//	disable returning to parent player.
	self.player = [self playerFrom:cueId];
}

/*---------------------------------------------------------------------------------
 
 reset song position, clear history and variables.
 
 ----------------------------------------------------------------------------------*/

- (void)reset {
	self.player				= nil;
	self.history			= ARInstance(VMArray);
	
	VMArray *dataIds = [self.songData keys];
	for( VMId *dataId in dataIds ) {
		VMData *d = [self.songData item:dataId];
		if ( ClassMatch( d, VMLiveData )) [ClassCast( d, VMLiveData ) reset];
		if ( ClassMatch( d, VMSelector )) [ClassCast( d, VMSelector ).liveData reset];
	}
}

#pragma mark -
#pragma mark private internal methods to resolving cues

//	private:
- (BOOL)currentPlayerHasSubseq {
	if( ! player.nextPlayer ) return NO;
	//	NOTE:
	//	'*' should be placed always at #0.
	//	overriding by adding sel's is not allowed.
	VMSelector *subseq = ClassCastIfMatch( player.nextPlayer, VMSelector );
	if ( subseq )
		return (! Pittari( [[subseq chanceAtIndex:0] targetId], @"*" ));
	
	VMPlayer *pl = ClassCastIfMatch( player.nextPlayer, VMPlayer );
	if ( pl )
		return YES;	//	DISCUSSION: ? maybe we should call 'currentPlayerHasSubseq' recursively with the parent player.
	
	return NO;
}


/*---------------------------------------------------------------------------------
 
 try to resolve data having a sepecified type with route tracking.
 
 ---------------------------------------------------------------------------------*/

- (id)resolveDataWithId:(VMId*)dataId untilReachType:(int)mask {
	VMData *d = [self data:dataId];
	if (! HasMethod(d, resolveUntilType:)) return nil;
	return [DEFAULTEVALUATOR resolveDataWithTracking:d toType:mask];		//	resolve with tracking
}


#pragma mark -
#pragma mark *** getting next sequence / resolve audio cues ***
#pragma mark -


/*---------------------------------------------------------------------------------
 *
 *
 *	check if player has reached end ( CPE )
 *
 *
 *---------------------------------------------------------------------------------*/
- (void) checkIfPlayerHasReachedEnd {
	//
	// 1) if current player is finished:
	//		a)	pop player if this is a sub-player
	//		b)	create player from subsequent
	//
	VerboseLog(@" CPE : check if player has reached end");
	
	if ( [self.player finished] ) {
		VMCue *c = self.player.nextPlayer;
		
		if ( c.type == vmObjectType_player ) {
			self.player = (VMPlayer*)self.player.nextPlayer;		//	pop
			VerboseLog(@" CPE 1a : pop -> %@", self.player.id );
		} else {
			VerboseLog(@" CPE 1b : player from subseq ->" );
			self.player = [self playerFrom:c];						//	make new player from nextplayer (selector assumed)
		}
	}

	//
	//	2)	continue pop players if multiple times nested
	//		TODO: make the code clearer.
	//
	while (self.player) {
		if ( self.player.cuePosition >= self.player.length ) {
			VerboseLog(@" CPE 2  : multiple pop -->" );
			self.player = [self playerFrom:self.player.nextPlayer];
			VerboseLog(@" CPE 2  : <--" );
		} else
			break;
	}
}

/*---------------------------------------------------------------------------------
 *
 *
 *	nextAudioCue (NAC)
 *
 *		get the next fragment (audioCue) from current player.
 *
 *
 *---------------------------------------------------------------------------------*/

- (VMAudioCue*)nextAudioCue {
	if ( ! self.player )
		return nil;
		
	if( verbose ) {
		NSLog(@"\n\n");
		NSLog(@"NAC : --- begin resolve nextAudioCue ---");
	}
	
	[self checkIfPlayerHasReachedEnd];

	//
	//	1)	try to resolve some sequence from current position of player.
	//
	//	1a)	found it: advance and push current player, make a sub-player from, then try to resolve a sequence recursively.
	//	1b)	found, but reached the end of player: (looks redundant - clearify:TODO ) pop, then try to resolve a sequence recursively.
	VMCue *cc = self.player.currentCue;
	VMInt depth = 0;	//	only for debugging use
	
	doForever {
		VMSequence *seq = [DEFAULTEVALUATOR resolveDataWithTracking:cc toType:vmObjectType_sequence];	
		if( seq ) {
			if ( self.player.cuePosition < self.player.length ) {
				//
				// case 1a:
				//
				[self.player advance];
				VerboseLog(@"NAC 1a : depth:%ld %@[%ld](advanced to -> pos:%ld = %@)",
									depth,
									self.player.id,
									self.player.length,
									self.player.cuePosition,
									self.player.currentCue.id );
				self.player = [self pushPlayerAndMakeSubPlayer:seq];
			} else {
				//
				// case 1b:
				//
				VerboseLog(@"NAC 1b : depth:%ld %@(popped 2)", depth, self.player.id);
				self.player = [self playerFrom:player.nextPlayer];
			}
			cc = self.player.currentCue;
			if(!cc && verbose)
				NSLog(@"empty cue!");
		} else
			break;
		
		++depth;
	}
	
	//
	//	2)	after no more sequences could be resolved:
	//
	//	2a)	no sequence found: empty cue. cannot continue playing. (possibly an error)
	//	2b)	found a sequence, but no audioCue was inside. cannot continue playing. (possibly an error)
	//	2c)	did'nt find a sequence, but an audioCue: okay, why not use it. (maybe we can find a seq at next cue in sequence)
	//
	if( !cc ) {
		//
		// case 2a.
		//
		id cueId = [self.player.cues item:self.player.cuePosition];
		if( verbose ) {
			if ( ClassMatch(cueId, VMId) )
				NSLog(@"NAC 2a : empty cue! possibly, %@ is not registered.", ((VMId*)cueId) );
			else 
				NSLog(@"NAC 2a : empty cue! %@", cueId );
		}
	}

	VerboseLog(@"NAC 2 : resolve audioCue from currentCue ->");
	VMAudioCue *ac = [DEFAULTEVALUATOR resolveDataWithTracking:cc toType:vmObjectType_audioCue];
	if( ! ac ) {
		//
		//	case 2b:
		//
		NSLog(@"NAC 2b : no audioCue in sequence !");
		
		/*
		 ac = [cc resolveUntilType:vmObjectType_audioCue];
		 NSLog(@"%@",ac);
		 self.player.cuePosition = 0;
		 ac = [self nextAudioCue];
		 */
	} else {
		//
		// case 2c:
		//
		[self.player advance];
		VerboseLog(@"NAC 2c : a/c %@ resolved and %@[%ld] advanced to -> pos:%ld",
							ac.id,
							self.player.id,
							self.player.length,
							self.player.cuePosition
							);
		
		[DEFAULTEVALUATOR setCueId:ac.id];

		
	}
	return ac;
}

/*---------------------------------------------------------------------------------
 *
 *
 *	playerFrom:someObject (PF)
 *
 *		try to make a VMPlayerfrom given object.
 *
 *		1)	resolve a cue
 *			a)	object is VMPlayer:			advance, if the end of seq was reached, resolve subsequent.
 *			b)	object is VMSelector:		select one cue.
 *			c)	object is VMCue or VMId:	make sure it is a cue-able object. (convert if needed)
 *
 *		2)	push current player and make a new player including the cue.
 *
 *
 *---------------------------------------------------------------------------------*/

- (VMPlayer*)playerFrom:(id)someObj {
	if ( ! someObj ) return nil;
	VMPlayer 	*parentPlayer 	= nil;
	id 			cueObj 			= nil;
	VerboseLog(@" PF : --- playerFrom:%@ ---", someObj);
	
	while ( ClassMatch(someObj, VMPlayer)) {
		parentPlayer 	= someObj;
		someObj 		= parentPlayer.currentCue;	//	this returns nextPlayer if player is finished
		VerboseLog(@" PF 1a : got next cue %@ from player:%@",((VMData*)someObj).id, parentPlayer.id );
		
		if( someObj == parentPlayer.nextPlayer ) {
			VerboseLog(@" PF 1a : pop:%@ from player:%@",((VMData*)someObj).id, parentPlayer.id );
		} else {
			[(VMPlayer*)parentPlayer advance];
			VerboseLog(@" PF 1a : advanced to %ld",((VMPlayer*)parentPlayer).cuePosition);
			break;
		}
	}
	
	if ( ClassMatch(someObj, VMSelector)) {
		VerboseLog(@" PF 1b : select cue");
		cueObj = [(VMSelector*)someObj resolveUntilType:vmObjectCategory_cue];
	} else if ( ClassMatch(someObj, VMCue)) {
		VerboseLog(@" PF 1c : found cue");
		cueObj = someObj;	//[self resolveDataWithId:((VMCue*)someObj).id untilReachType:vmObjectCategory_cue];
	} else if ( ClassMatch(someObj, VMId)) {
		VerboseLog(@" PF 1c : ensure cue");
		cueObj = [self data:someObj];
		if ( ! [cueObj matchMask:vmObjectCategory_cue] ) {
			cueObj = [self resolveDataWithId:(VMId*)someObj untilReachType:vmObjectCategory_cue];
		}
	}

	VerboseLog(@" PF 1  : cue %@ resolved from input",[cueObj description] );
	
	VMPlayer *pl = nil;

	if( cueObj ) 
		pl = [self pushPlayerAndMakeSubPlayer:cueObj];
	
	return pl;	
}


/**
 |
 | the relationship between player, subseq and nextPlayer:
 |
 | rule #1: convert a sequence to player:
 | - copy cues. put subseq into nextplayer.
 | SEQ			 subseq				PLY				   nextPlayer
 | {seq [cue1,cue2][subseq] }  	-> 	{player [cue1,cue2][subseq]}
 |
 | rule #2: sequence without subseq:
 | - put the last cue in cues into nextPlayer.
 | SEQ			 subseq				PLY			  nextPlayer
 | {seq [cue1,cue2][] }  		-> 	{player [cue1][cue2]}
 |
 | rule #3: nested sequence(1):
 | - create new player for nested sequence, put the parent player into
 | child's nextPlayer.
 | SEQ								PLY
 | {seq1 [seq2][subseq] }  		->	{player1 [
 |											  {player2 [..][seq1]}
 |											  ][subseq] }
 |
 | rule #4: nested sequence(2):
 | - if the parent player's subsequent is "*", put the subseq of child sequence into child's nextPlayer
 | SEQ								PLY
 | {seq1 [seq2][*] } 			->  {player1 [
 |											  {player2 [..][subseq2]}
 |											  ][]}
 |
 | rule #5:convert an audioCue into player:
 | - put audioCue into cues, put parent player into nextPlayer
 |
 | AUQ
 | {auq}							->
 | */

/*---------------------------------------------------------------------------------
 *
 *
 *	push player and make sub player (MSP)
 *
 *		push the current player into stack, make a new player including the
 *		input cue.
 *
 *
 *---------------------------------------------------------------------------------*/


- (VMPlayer*)pushPlayerAndMakeSubPlayer:(VMCue*)cue {
	
	VMSequence *seq = ClassCastIfMatch(cue, VMSequence);
	VMAudioCue *ac  = ClassCastIfMatch(cue, VMAudioCue);
	VMPlayer *newPlayer = nil;
	
	VerboseLog(@"  MSP : ---- push player and make sub player from %@ ---",cue.id);
	
	if ( seq ) {
		newPlayer = [[[VMPlayer alloc] initWithProto:seq] autorelease];		//	rule #1
		if ( self.player
			&& (( ![self.player finished] ) || ( ! newPlayer.nextPlayer ))	//
			&& [self currentPlayerHasSubseq] )
			newPlayer.nextPlayer = self.player;								//	rules #3 & #4
		
		if( (! newPlayer.nextPlayer) && [newPlayer.cues count] > 1 ) {
			VMSelector *subseq = ARInstance(VMSelector);
			VMChance   *ch	   = ARInstance(VMChance);
			[ch setWithData:[newPlayer.cues pop]];
			subseq.cues = [VMArray arrayWithObject:ch];
			subseq.id = [VMPreprocessor idWithVMPModifier:newPlayer.userGeneratedId tag:@"subseq" info:nil];
			newPlayer.nextPlayer = subseq;										//	rule #2
		}
		[newPlayer interpreteInstructionsWithAction:vmAction_prepare];
	}
	
	if ( ac ) {
		newPlayer = ARInstance(VMPlayer);
		newPlayer.cues = [VMArray arrayWithObject:ac.id];
		newPlayer.id = [VMPreprocessor idWithVMPModifier:ac.id tag:@"temp-player" info:nil];
		newPlayer.nextPlayer = self.player;									//	rule #5
	}	
	
	return newPlayer;
}









#pragma mark -
#pragma mark loading


- (BOOL)readFromURL:(NSURL *)url error:(NSError **)outError {
    NSData *data = [NSData dataWithContentsOfURL:url options:NSDataReadingUncached error:outError];
    return [self readFromData:data error:outError];
}

- (BOOL)readFromData:(NSData *)data error:(NSError **)outError {
	if ( data ) {
		NSString *vmsText = [[NSString alloc] initWithData:data encoding:vmFileEncoding];
		
		[self.songData clear];
		self.showReport.current = NO;
		
		DEFAULTPREPROCESSOR.song = self;
		[DEFAULTPREPROCESSOR preprocess:vmsText];
		
		[self.showReport restore];
		[vmsText release];
		[self reset];
	}
    return YES;
}




/*---------------------------------------------------------------------------------
 
 oligatory
 
 ----------------------------------------------------------------------------------*/

#pragma mark -
#pragma mark obligatory

//	NOTE:	should not called directly. use [VMSong defaultSong] instead (at least for now).
//			for future expansion, consider creating multiple song instances.
- (id)init {
    self = [super init];
    if (self) {
		self.songData				= ARInstance(VMHash);
		self.entryPoints			= ARInstance(VMArray);
		self.history				= ARInstance(VMArray);
		self.showReport				= ARInstance(VMStack);
#if VMP_LOGGING
		self.log				= [[[VMLog alloc] initWithOwner:VMLogOwner_Player managedObjectContext:nil] autorelease];
#endif
		if (!vmsong_singleton__) {
			vmsong_singleton__ = self;
		}
    }
    return self;
}

- (void)dealloc {
	self.songData = nil;
	self.entryPoints 
	= self.history
	= self.showReport
	= nil;
	self.vsFilePath 
	= self.audioFileDirectory 
	= self.audioFileExtension 
	= nil;
	
#if VMP_LOGGING
	self.log = nil;
#endif
	
	[self->defaultCueId release];
	[self->songName release];
    [super dealloc];
}


-(void)setByHash:(VMHash *)hash {
	//self->songName = hash->hash_.songName;
	self->songName 			= 	[HashItem(songName) retain];
    self->defaultCueId 		=	[HashItem(defaultCueId) retain];
    self.audioFileExtension =    HashItem(audioFileExtension);
    self.audioFileDirectory =    HashItem(audioFileDirectory);
	if ( Pittari(self.audioFileDirectory,@"./" ))
		self.audioFileDirectory = kDefaultVMDirectory;
}


- (NSString*)callStackInfo {
	NSString *info = @"";
	VMPlayer *p = self.player;
	doForever {
		info = [info stringByAppendingFormat:@"%@\n", p.description];
		if ( ClassMatch( p.nextPlayer, VMPlayer )) {
			p = (VMPlayer*)p.nextPlayer;
		} else {
			info = [info stringByAppendingFormat:@"next: %@\n", p.nextPlayer.description ];
			break;
		}
	}
	return info;
}

- (NSString*)description {
	VMArray *ids = [self.songData sortedKeys];
	VMArray *descs = NewInstance(VMArray);
	for ( NSString *cid in ids )
		[descs push:[[self.songData item:cid] description]]; 
	
	NSString *descStr = [descs join:@"\n"];
	[descs release];
	return [NSString stringWithFormat:@"%@\n%@",self.songName,descStr]; 
}

@end

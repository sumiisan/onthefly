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
@synthesize songName=songName_, audioFileExtension=audioFileExtension_,
vsFilePath=vsFilePath_, audioFileDirectory=audioFileDirectory_, defaultFragmentId=defaultFragmentId_;
@synthesize songData=songData_, entryPoints=entryPoints_, history=history_;
@synthesize player;
@synthesize showReport=showReport_;

static VMSong *vmsong_singleton_static_;
//static BOOL reportNotRegisteredObjects = NO;
BOOL verbose = NO;

#pragma mark -
#pragma mark accessor

/*---------------------------------------------------------------------------------
 
 record (history) related
 
 ----------------------------------------------------------------------------------*/

- (void)record:(VMArray*)fragIds {
	[self.history push:fragIds];
	if( self.history.count > 2000 ) [self.history truncateFirst:1500];
}

- (VMInt)distanceToLastRecordOf:(VMId*)fragId {
	VMInt c = self.history.count;
	VMInt p = c;
	for ( int i = 0; i < c; ++i ) {
		VMArray *arr = [self.history item: --p ];
		if ( [arr position:fragId] >= 0 ) return i;
	}
	return 1e30f;	//	don't use INFINITY
}

+ (VMSong*)defaultSong {
	if( ! vmsong_singleton_static_ ) vmsong_singleton_static_ = NewInstance(VMSong);
	return vmsong_singleton_static_;
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
 
 set the song position to given frag.
 
 ----------------------------------------------------------------------------------*/

- (void)setFragmentId:(VMId*)fragId {
	VMNullify(player);		//	disable returning to parent player.
	self.player = [self playerFrom:fragId];
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
#pragma mark private internal methods to resolving frags

//	private:
- (BOOL)currentPlayerHasSubseq {
	if( ! player.nextPlayer ) return NO;
	//	NOTE:
	//	'*' should be placed always at #0.
	//	overriding by adding sel's is not allowed.
	VMSelector *subseq = ClassCastIfMatch( player.nextPlayer, VMSelector );
	if ( subseq )
		return (! subseq.isDeadEnd );
	
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
#pragma mark *** getting next sequence / resolve audio frags ***
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
		VMFragment *c = self.player.nextPlayer;
		
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
		if ( self.player.fragPosition >= self.player.length ) {
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
 *	nextAudioFragment (NAC)
 *
 *		get the next fragment (audioFragment) from current player.
 *
 *
 *---------------------------------------------------------------------------------*/

- (VMAudioFragment*)nextAudioFragment {
	if ( ! self.player )
		return nil;
		
	if( verbose ) {
		NSLog(@"\n\n");
		NSLog(@"NAC : --- begin resolve nextAudioFragment ---");
	}
	
	[self checkIfPlayerHasReachedEnd];

	//
	//	1)	try to resolve some sequence from current position of player.
	//
	//	1a)	found it: advance and push current player, make a sub-player from, then try to resolve a sequence recursively.
	//	1b)	found, but reached the end of player: (looks redundant - clearify:TODO ) pop, then try to resolve a sequence recursively.
	VMFragment *cc = self.player.currentFragment;
	VMInt depth = 0;	//	only for debugging use
	
	doForever {
		VMSequence *seq = [DEFAULTEVALUATOR resolveDataWithTracking:cc toType:vmObjectType_sequence];	
		if( seq ) {
			if ( self.player.fragPosition < self.player.length ) {
				//
				// case 1a:
				//
				[self.player advance];
				VerboseLog(@"NAC 1a : depth:%ld %@[%ld](advanced to -> pos:%ld = %@)",
									depth,
									self.player.id,
									self.player.length,
									self.player.fragPosition,
									self.player.currentFragment.id );
				self.player = [self pushPlayerAndMakeSubPlayer:seq];
			} else {
				//
				// case 1b:
				//
				VerboseLog(@"NAC 1b : depth:%ld %@(popped 2)", depth, self.player.id);
				self.player = [self playerFrom:player.nextPlayer];
			}
			cc = self.player.currentFragment;
			if(!cc && verbose)
				NSLog(@"empty frag!");
		} else
			break;
		
		++depth;
	}
	
	//
	//	2)	after no more sequences can be resolved:
	//
	//	2a)	no sequence found: empty fragment. cannot continue playing. (possibly an error of vm structure)
	//	2b)	found a sequence, but no audioFragment was inside. cannot continue playing. (possibly an error of vm structure)
	//	2c)	did'nt find a sequence, but an audioFragment: okay, why not use it. (maybe we can find a seq at next frag in sequence)
	//
	if( !cc ) {
		//
		// case 2a.
		//
		id fragId = [self.player.fragments item:self.player.fragPosition];
		if( verbose ) {
			if ( ClassMatch(fragId, VMId) )
				NSLog(@"NAC 2a : empty frag! possibly, %@ is not registered.", ((VMId*)fragId) );
			else 
				NSLog(@"NAC 2a : empty frag! %@", fragId );
		}
	}

	VerboseLog(@"NAC 2 : resolve audioFragment from currentFragment ->");
	VMAudioFragment *ac = [DEFAULTEVALUATOR resolveDataWithTracking:cc toType:vmObjectType_audioFragment];
	if( ! ac ) {
		//
		//	case 2b:
		//
		NSLog(@"NAC 2b : no audioFragment in sequence !");
		
		/*
		 ac = [cc resolveUntilType:vmObjectType_audioFragment];
		 NSLog(@"%@",ac);
		 self.player.fragPosition = 0;
		 ac = [self nextAudioFragment];
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
							self.player.fragPosition
							);
		
		[DEFAULTEVALUATOR setFragmentId:ac.id];

		
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
 *		1)	resolve a frag
 *			a)	object is VMPlayer:				advance, if the end of seq was reached, resolve subsequent.
 *			b)	object is VMSelector:			select one frag.
 *			c)	object is VMFragment or VMId:	make sure it is a queue-able fragment. (convert if needed)
 *
 *		2)	push current player and make a new player including the frag.
 *
 *
 *---------------------------------------------------------------------------------*/

- (VMPlayer*)playerFrom:(id)someObj {
	if ( ! someObj ) return nil;
	VMPlayer 	*parentPlayer 	= nil;
	id 			fragObj 			= nil;
	VerboseLog(@" PF : --- playerFrom:%@ ---", someObj);
	
	while ( ClassMatch(someObj, VMPlayer)) {
		parentPlayer 	= someObj;
		someObj 		= parentPlayer.currentFragment;	//	this returns nextPlayer if player is finished
		VerboseLog(@" PF 1a : got next frag %@ from player:%@",((VMData*)someObj).id, parentPlayer.id );
		
		if( someObj == parentPlayer.nextPlayer ) {
			VerboseLog(@" PF 1a : pop:%@ from player:%@",((VMData*)someObj).id, parentPlayer.id );
		} else {
			[(VMPlayer*)parentPlayer advance];
			VerboseLog(@" PF 1a : advanced to %ld",((VMPlayer*)parentPlayer).fragPosition);
			break;
		}
	}
	
	if ( ClassMatch(someObj, VMSelector)) {
		VerboseLog(@" PF 1b : select frag");

	//	TEST:	we want track seqence of subseq as well.
		fragObj = [DEFAULTEVALUATOR resolveDataWithTracking:(VMSelector*)someObj toType:vmObjectCategory_fragment];

		
		//fragObj = [(VMSelector*)someObj resolveUntilType:vmObjectCategory_fragment];
		
	} else if ( ClassMatch(someObj, VMFragment)) {
		VerboseLog(@" PF 1c : found frag");
		fragObj = someObj;	//[self resolveDataWithId:((VMFragment*)someObj).id untilReachType:vmObjectCategory_fragment];
	} else if ( ClassMatch(someObj, VMId)) {
		VerboseLog(@" PF 1c : ensure frag");
		fragObj = [self data:someObj];
		if ( ! [fragObj matchMask:vmObjectCategory_fragment] ) {
			fragObj = [self resolveDataWithId:(VMId*)someObj untilReachType:vmObjectCategory_fragment];
		}
	}

	VerboseLog(@" PF 1  : frag %@ resolved from input",[fragObj description] );
	
	VMPlayer *pl = nil;

	if( fragObj ) 
		pl = [self pushPlayerAndMakeSubPlayer:fragObj];
	
	return pl;	
}


/**
 |
 | the relationship between player, subseq and nextPlayer:
 |
 | rule #1: convert a sequence to player:
 | - copy frags. put subseq into nextplayer.
 | SEQ			 subseq				PLY				   nextPlayer
 | {seq [frag1,frag2][subseq] }  	-> 	{player [frag1,frag2][subseq]}
 |
 | rule #2: sequence without subseq:
 | - put the last frag in frags into nextPlayer.
 | SEQ			 subseq				PLY			  nextPlayer
 | {seq [frag1,frag2][] }  		-> 	{player [frag1][frag2]}
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
 | rule #5:convert an audioFragment into player:
 | - put audioFragment into frags, put parent player into nextPlayer
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
 *		input frag.
 *
 *
 *---------------------------------------------------------------------------------*/


- (VMPlayer*)pushPlayerAndMakeSubPlayer:(VMFragment*)frag {
	
	VMSequence *seq = ClassCastIfMatch(frag, VMSequence);
	VMAudioFragment *ac  = ClassCastIfMatch(frag, VMAudioFragment);
	VMPlayer *newPlayer = nil;
	
	VerboseLog(@"  MSP : ---- push player and make sub player from %@ ---",frag.id);
	
	if ( seq ) {
		newPlayer = AutoRelease([[VMPlayer alloc] initWithProto:seq] );		//	rule #1
		if ( self.player
			&& (( ![self.player finished] ) || ( ! newPlayer.nextPlayer ))	//
			&& [self currentPlayerHasSubseq] )
			newPlayer.nextPlayer = self.player;								//	rules #3 & #4
		
		if( (! newPlayer.nextPlayer) && [newPlayer.fragments count] > 1 ) {
			VMSelector *subseq = ARInstance(VMSelector);
			VMChance   *ch	   = ARInstance(VMChance);
			[ch setWithData:[newPlayer.fragments pop]];
			subseq.fragments = [VMArray arrayWithObject:ch];
			subseq.id = [VMPreprocessor idWithVMPModifier:newPlayer.userGeneratedId tag:@"subseq" info:nil];
			newPlayer.nextPlayer = subseq;										//	rule #2
		}
		[newPlayer interpreteInstructionsWithAction:vmAction_prepare];
	}
	
	if ( ac ) {
		newPlayer = ARInstance(VMPlayer);
		newPlayer.fragments = [VMArray arrayWithObject:ac.id];
		newPlayer.id = [VMPreprocessor idWithVMPModifier:ac.id tag:@"temp-player" info:nil];
		newPlayer.nextPlayer = self.player;									//	rule #5
	}	
	
	return newPlayer;
}









#pragma mark -
#pragma mark loading

//	returns YES on success, NO if failed.
- (BOOL)readFromURL:(NSURL *)url error:(NSError **)outError {
    NSData *data = [NSData dataWithContentsOfURL:url options:NSDataReadingUncached error:outError];
	if ( [self readFromData:data error:outError] ) {
		self.fileURL = url;
		return YES;
	}
	return NO;
}

//	returns YES on success, NO if failed.
- (BOOL)readFromData:(NSData *)data error:(NSError **)outError {
	if ( data ) {
		return [self readFromString:AutoRelease([[NSString alloc] initWithData:data encoding:vmFileEncoding])
							  error:outError ];
	}
	return NO;
}

- (void)clear {
	VMNullify(fileURL);
	Release(songName_);
	songName_ = nil;
	[self reset];
	[self.songData clear];
}

//	returns YES on success, NO if failed.
- (BOOL)readFromString:(VMString *)string error:(NSError **)outError {
	if( string ) self.vmsData = string;
	[self.songData clear];
	self.showReport.current = NO;
	
	DEFAULTPREPROCESSOR.song = self;
	BOOL success = [DEFAULTPREPROCESSOR preprocess:self.vmsData error:outError];
	
#if VMP_EDITOR
	if (!success) {
		//	handle errors during preprocessing if any:
		
		//	JSON-parse error is handled inside JSON-parser
		//	because the Touch-JSON does not report leaf-node errors upon return.
	}
#endif
	
	[self.showReport restore];
	[self reset];
	
	return success;
}

- (BOOL)saveToURL:(NSURL *)url error:(NSError **)outError {		//	note: outError is never set
	if( self.vmsData.length == 0 ) {
		[VMException alert:@"Can not save empty structure!"];
		return NO;
	}
	NSData *data = [self.vmsData dataUsingEncoding:vmFileEncoding];
	if ( [data writeToURL:url atomically:YES] ) {
		self.fileURL = url;
		return YES;
	}
	return NO;
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
		self.log				= AutoRelease([[VMLog alloc] initWithOwner:VMLogOwner_MediaPlayer managedObjectContext:nil] );
#endif
		if (!vmsong_singleton_static_) {
			vmsong_singleton_static_ = self;
		}
    }
    return self;
}

- (void)dealloc {
	VMNullify(fileURL);
	VMNullify(songData);
	VMNullify(defaultFragmentId);
	VMNullify(songName);
	VMNullify(entryPoints);
	VMNullify(history);
	VMNullify(showReport);
	VMNullify(vsFilePath);
	VMNullify(audioFileDirectory);
	VMNullify(audioFileExtension);
	VMNullify(vmsData);
	
#if VMP_LOGGING
	VMNullify(log);
#endif
	
    Dealloc( super );
}

-(void)setByHash:(VMHash *)hash {
	//self->songName = hash->hash_.songName;
	songName_				= 	Retain( HashItem(songName));
    defaultFragmentId_		=	Retain( HashItem(defaultFragmentId) );
    self.audioFileExtension =   HashItem(audioFileExtension);
    self.audioFileDirectory =   HashItem(audioFileDirectory);
	if ( [self.audioFileDirectory isEqualToString:@"./"] ) self.audioFileDirectory = @"";
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
	Release(descs);
	return [NSString stringWithFormat:@"%@\n%@",self.songName,descStr]; 
}

@end

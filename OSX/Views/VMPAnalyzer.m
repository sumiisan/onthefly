//
//  VMPAnalyzer.m
//  OnTheFlyOSX
//
//  Created by  on 13/02/26.
//  Copyright (c) 2013 __MyCompanyName__. All rights reserved.
//

#import "VMPAnalyzer.h"
#import "VMSong.h"
#import "VMPMacros.h"
#import "VMPlayerOSXDelegate.h"
#import "VMPSongPlayer.h"
#include "KeyCodes.h"
#import "VMPNotification.h"



/*---------------------------------------------------------------------------------
 
 report record
 
 ----------------------------------------------------------------------------------*/

#pragma mark -
#pragma mark Report Record
@implementation VMPReportRecord

- (id)initWithType:(VMPReportRecordType)inType
				id:(NSString *)inId
			 count:(int)inCount
		   percent:(double)inPercent
		  duration:(double)inDuration {
	self.type		= inType;
	self.ident		= inId;
	self.count		= [NSNumber numberWithInt:inCount];
	self.percent	= [NSNumber numberWithDouble:inPercent];
	self.duration	= [NSNumber numberWithDouble:inDuration];

	return self;
}

- (void)dealloc {
	self.ident = nil;
	self.count = nil;
	self.percent = nil;
	self.duration = nil;
	[super dealloc];
}

@end

/*---------------------------------------------------------------------------------
 
 statistics view
 
 ----------------------------------------------------------------------------------*/

#pragma mark -
#pragma mark Statististics View

@implementation VMPStatisticsView

- (void)awakeFromNib {
	self.reportView.doubleAction = @selector(doubleClickOnRow:);
}


- (void)setInfoText:(VMString*)infoText {
	((NSTextField*)[self viewWithTag:140]).stringValue = infoText;
}


- (IBAction)clickOnButton:(id)sender {
	NSButton *b = (NSButton*)sender;
	switch (b.tag) {
		case -100:
			[DEFAULTANALYZER moveHistory:-1];
			break;
		case  100:
			[DEFAULTANALYZER moveHistory: 1];
			break;
	}
}

- (IBAction)clickOnRow:(id)sender {
	NSTableView *tableView = sender;
	[DEFAULTANALYZER selectRow:[tableView selectedRow]];
	VMPReportRecord *rec = [DEFAULTANALYZER recordForRow:tableView.selectedRow];
	if ( rec )
		[VMPNotificationCenter postNotificationName:VMPNotificationFragmentSelected
											 object:self
										   userInfo:@{@"id":rec.ident} ];
}


- (IBAction)doubleClickOnRow:(id)sender {
	NSTableView *tableView = sender;
	VMPReportRecord *rec = [DEFAULTANALYZER recordForRow:tableView.selectedRow];
	[VMPNotificationCenter postNotificationName:VMPNotificationFragmentDoubleClicked
										 object:self
									   userInfo:@{@"id":rec.ident} ];
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
	SEL action = menuItem.action;
	if (action==@selector(moveHistoryBack:)) {
		if ( DEFAULTANALYZER.historyPosition < 1 ) return NO;
	}
	if (action==@selector(moveHistoryForward:)) {
		if ( DEFAULTANALYZER.historyPosition >= DEFAULTANALYZER.history.count -1 ) return NO;
	}
	return YES;
}

- (IBAction)moveHistoryForward:(id)sender {
	[DEFAULTANALYZER moveHistory:1];
}

- (IBAction)moveHistoryBack:(id)sender {
	[DEFAULTANALYZER moveHistory:-1];
}

- (void)updateButtonStates {
	[((NSButton*)[self viewWithTag: 100]) setEnabled:( DEFAULTANALYZER.historyPosition < DEFAULTANALYZER.history.count -1 )];
	[((NSButton*)[self viewWithTag:-100]) setEnabled:( DEFAULTANALYZER.historyPosition > 0 )];
}

@end

/*---------------------------------------------------------------------------------
 *
 *
 *	Analyzer
 *
 *
 *---------------------------------------------------------------------------------*/

#pragma mark -
#pragma mark Analyzer

@interface VMPAnalyzer()
/*---------------------------------------------------------------------------------
 
 analyzer intern
 
 ----------------------------------------------------------------------------------*/

@property (retain)						VMHash						*countForFragmentId;
@property (retain)						VMHash						*routesForId;
@property (retain)						VMHash						*countForPart;
@property (retain)						VMHash						*sojournDataForPart;
@property (retain)						VMHash						*histograms;
@property (retain)						VMArray						*unresolveables;

@property (readonly, getter=isBusy)		BOOL						busy;
@property (retain)						VMFragment					*entryPoint;
@property (retain)						VMId						*currentPartId;

@property (retain)						VMArray						*dataIdToProcess;
@property (assign)						VMInt						currentPositionInDataIdList;

@property (retain)						VMString					*lastFragmentId;

@end

static NSColor *oliveColor, *teaColor, *mandarineColor;

/*---------------------------------------------------------------------------------
 *
 *
 *	VMP Analyzer
 *
 *
 *---------------------------------------------------------------------------------*/

@implementation VMPAnalyzer 

static VMPAnalyzer		*analyzer_singleton__		= nil;
static VMPRecordCell	*recordCell_defaultCell__	= nil;

//	50000 times
static const int	kNumberOfIterationsOfGlobalTraceRoute   =  1000;
static const int	kLengthOfGlobalTraceRoute				=    50;

//	300 entries
static const int	kNumberOfIterationsOfPartTraceRoute		=	300;
static const int	kLengthOfPartTraceRoute					= 10000;	//	gives up after 10000 times advancing.

+ (VMPAnalyzer*)defaultAnalyzer {

	if ( ! analyzer_singleton__ ) {
		analyzer_singleton__ = [[VMPAnalyzer alloc] init];
	}
	if ( ! recordCell_defaultCell__ ) {
		recordCell_defaultCell__ = [[VMPRecordCell alloc] initTextCell:@""];
		[recordCell_defaultCell__ setFont:[NSFont systemFontOfSize:11]];
		[recordCell_defaultCell__ setAlignment:NSRightTextAlignment ];
	}
	if ( ! oliveColor ) {
		oliveColor		= [[NSColor colorWithCalibratedRed:0.3 green:0.7 blue:0.4 alpha:0.9] retain];
		teaColor		= [[NSColor colorWithCalibratedRed:0.4 green:0.9 blue:0.6 alpha:0.9] retain];
		mandarineColor	= [[NSColor colorWithCalibratedRed:1.0 green:0.7 blue:0.3 alpha:0.9] retain];
	}
	
	return analyzer_singleton__;
}

- (id)init {
	self=[super init];
	if (self) {
		analyzer_singleton__ = self;
		self.progressWC = [[[VMPProgressWindowController alloc] initWithWindow:nil] autorelease];
		[NSBundle loadNibNamed: @"VMPProgressWindow" owner: self.progressWC];
		self.progressWC.delegate = self;
	}
	return self;
}

- (void)dealloc {
	self.dataIdToProcess = nil;
	self.lastFragmentId = nil;
	//
	self.entryPoint = nil;
	self.report = nil;
	self.progressWC = nil;
	self.currentPartId = nil;
	self.unresolveables = nil;
	self.history = nil;
	self.countForFragmentId = nil;
	self.countForPart = nil;
	self.sojournDataForPart = nil;
	self.routesForId = nil;
	self.histograms = nil;	
    [super dealloc];
}

#pragma mark -
#pragma mark menu action


- (IBAction)performStatistics:(id)sender {
	if (_busy) return;
	
	switch ( ((NSMenuItem *)sender).tag ) {
		case 0: {
			//
			// global route statistic
			//
			[DEFAULTSONGPLAYER fadeoutAndStop:5.];
			[self routeStatistic:[DEFAULTSONG data:DEFAULTSONG.defaultFragmentId]
			  numberOfIterations:kNumberOfIterationsOfGlobalTraceRoute
						   until:nil];
			break;
		}
		case 1: {
			//
			// part domestic route statistics
			//
			VMId *partId = [[VMArray arrayWithString:APPDELEGATE.editorViewController.lastSelectedId
											 splitBy:@"_"] item:0];
			VMFragment *entrySelector = [DEFAULTSONG data:[partId stringByAppendingString:@"_sel"]];
			if (entrySelector) {
				[self routeStatistic:entrySelector numberOfIterations:kNumberOfIterationsOfPartTraceRoute until:@"exit-part"];
			}
			break;
		}
		case 2: {
			//
			// validate vm structure:	check unresolved
			//
			[self findUnresolveables];
			break;
		}
		case 3: {
			//
			// check missing audio files
			//
			self.dataIdToProcess = [DEFAULTSONG.songData sortedKeys];
			self.unresolveables = ARInstance(VMArray);
			self.currentPositionInDataIdList = 0;
			_busy =YES;
			[self checkFiles_proc];
			
			break;
		}
	}
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
	return ! self.busy;
}


- (void)updateGraphView {
	[self.countHistogramView setData:[self.histograms item:@"count"] numberOfBins:0];
	[self.countHistogramView setTitle:@"number of playback times / audioFragment"];
	
	[self.durationHistogramView setData:[self.histograms item:@"duration"] numberOfBins:0];
	[self.durationHistogramView setTitle:@"accumulated duration / audioFragment"];
	
	[self.varietyHistogramView setData:[self.histograms item:@"variety"] numberOfBins:0];
	[self.varietyHistogramView setTitle:@"variety (acc. duration / num of ac) / part"];
}

- (IBAction)openGraphView:(id)sender {
	[self updateGraphView];
	[self.statGraphPane setViewsNeedDisplay:YES];
	[self.statGraphPane makeKeyAndOrderFront:self];
}

#pragma mark -
#pragma mark analysis


/*---------------------------------------------------------------------------------
 
 route statistics (public method)
 
 ----------------------------------------------------------------------------------*/

- (BOOL)routeStatistic:(VMFragment *)inEntryPoint
	numberOfIterations:(const long)inNumberOfIterations until:(VMString*)exitCondition {
	if ( self.isBusy ) return NO;
	
    _busy = YES;
	self.report = nil;
	self.entryPoint = inEntryPoint;
	self.log = [[[VMLog alloc] initWithOwner:VMLogOwner_Statistics
						managedObjectContext:nil] autorelease];
	[DEFAULTSONG.log save];
	DEFAULTSONG.log = self.log;
	
	DEFAULTSONG.showReport.current = NO;
	[DEFAULTSONG setFragmentId:self.entryPoint.id];
	
    exitWhenPartChanged = ( [exitCondition isEqualToString:@"exit-part" ]);
	self.currentPartId	= inEntryPoint.partId;
    
	
	self.unresolveables		= ARInstance(VMArray);
	self.countForFragmentId		= ARInstance(VMHash);
	self.countForPart		= ARInstance(VMHash);
	self.sojournDataForPart	= ARInstance(VMHash);
	self.routesForId		= ARInstance(VMHash);
	self.histograms			= ARInstance(VMHash);
	
	sojourn				= 0;
	startIndexOfSojourn	= 0;
    totalAudioFragmentCount	= 0;
	totalPartCount		= 0;
	numberOfIterations	= inNumberOfIterations;
	iterationsLeft		= numberOfIterations;
    
	[self reset_proc];
	[self analyze_proc];
	return YES;
}

/*---------------------------------------------------------------------------------
 
 subs for route statistics
 
 ----------------------------------------------------------------------------------*/

- (void)addUnresolveable:(id)data {
	[self.unresolveables pushUnique:data];
}

- (void)pushSojournForPart:(VMString*)partId length:(VMInt)inSojourn startIndexInLog:(VMInt)startIndex {
	VMArray *ar = [_sojournDataForPart item:partId];
	if (! ar) {
		ar = ARInstance(VMArray);
		[_sojournDataForPart setItem:ar for:partId];
	}
	[ar push:[VMHash hashWithDictionary:@{ @"length":@(inSojourn), @"position":@(startIndex) } ]];
}

- (void)incrementRouteForId:(VMId*)dataId from:(VMId*)from to:(VMId*)to {
	VMHash *d = [_routesForId item:dataId];
	if ( ! d ) {
		d = [VMHash hashWithDictionary:@{ @"from":ARInstance(VMHash), @"to":ARInstance(VMHash) }];
		[_routesForId setItem:d for:dataId];
	}
	if ( from ) {
		VMHash *fromHash = [d item:@"from"];
		[fromHash setItem:@([fromHash itemAsInt:from]+1) for:from];
	}
	if ( to ) {
		VMHash *fromHash = [d item:@"to"];
		[fromHash setItem:@([fromHash itemAsInt:to]+1) for:to];
	}
}
/*---------------------------------------------------------------------------------
 
 process analysis
 
 @return	YES if it should exit analyze_step loop
 
 ----------------------------------------------------------------------------------*/
- (BOOL)analyze_step {
	@autoreleasepool {
		VMAudioFragment *ac = [DEFAULTSONG nextAudioFragment];
		if( ! ac ) {
			NSLog(@"------ call stack ------\n%@",[DEFAULTSONG callStackInfo]);
			
			[_countForFragmentId setItem:@([_countForFragmentId itemAsInt:@"unresolved"] +1) for:@"unresolved"];
			[self incrementRouteForId:@"unresolved" from:_lastFragmentId to:nil];
			[self incrementRouteForId:_lastFragmentId from:nil to:@"unresolved"];
			[self reset_proc];
			return exitWhenPartChanged;
		}
		
		++sojourn;
		
		//	route
		if ( _lastFragmentId ) {
			[self incrementRouteForId:_lastFragmentId from:nil to:ac.id];
			[self incrementRouteForId:ac.id from:_lastFragmentId to:nil];
		}
		
		if ( exitWhenPartChanged ) {
			if ( ! [ac.partId isEqualToString: self.currentPartId ] ) {
				VMInt c = [_countForPart itemAsInt:ac.partId];
				[_countForPart setItem:@(c+1) for:ac.partId];
				[self pushSojournForPart:ac.partId length:sojourn startIndexInLog:startIndexOfSojourn];
				[self incrementRouteForId:ac.partId from:_lastFragmentId to:ac.fragId];
				sojourn = 0;
				startIndexOfSojourn = [self.log nextIndex];
				++totalPartCount;
				[self reset_proc];
				return exitWhenPartChanged;
			}
		} else {
			VMInt c = [_countForPart itemAsInt:ac.partId];
			[_countForPart setItem:@(c+1) for:ac.partId];
			++totalPartCount;
			if ( ! [ac.partId isEqualToString: self.currentPartId ] ) {
				[self pushSojournForPart:self.currentPartId length:sojourn startIndexInLog:startIndexOfSojourn];
				[self incrementRouteForId:self.currentPartId from:nil to:ac.partId];
				[self incrementRouteForId:ac.partId from:self.currentPartId to:nil];
				self.currentPartId = ac.partId;
				sojourn = 0;
				startIndexOfSojourn = [self.log nextIndex];
			}
		}
		
		[_countForFragmentId setItem:@([_countForFragmentId itemAsInt:ac.id]+1) for:ac.id];
		
		//	simulate fire
		[ac interpreteInstructionsWithAction:vmAction_play];
		++totalAudioFragmentCount;
		self.lastFragmentId = ac.fragId;
	}
	return NO;
}

- (void)reset_proc {
	[DEFAULTSONG setFragmentId:self.entryPoint.id];
	self.lastFragmentId = nil;
}

- (void)analyze_proc {
    for ( long j  = ( exitWhenPartChanged ? kLengthOfPartTraceRoute : kLengthOfGlobalTraceRoute ) ; j; --j) {
		if ( [self analyze_step] ) break;
    }
	[self.progressWC setProgress:(double)(numberOfIterations - iterationsLeft)
						 ofTotal:(double)numberOfIterations message:@"Analyzing:"
						  window:[VMPlayerOSXDelegate singleton].editorViewController.window];
	if ( --iterationsLeft > 0 ) {
		[self performSelector:@selector(analyze_proc) withObject:nil afterDelay:0.005];
	} else {
		[self finishAnalysis];
	}
}

/*---------------------------------------------------------------------------------
 
 finish analysis
 
 ----------------------------------------------------------------------------------*/
//
// fragments ( audioFragment ) report
//
- (VMArray*)audioFragmentReportWithDurationForPart:(VMHash*)durationForPart numberOfFragmentsForPart:(VMHash*)numberOfFragmentsForPart {
	self.dataIdToProcess = [_countForFragmentId sortedKeys];
	VMArray *fragArray		= ARInstance(VMArray);
	VMArray *durationArray	= ARInstance(VMArray);
	
	for ( VMString *dataId in _dataIdToProcess ) {
		VMFloat		count		= [_countForFragmentId itemAsFloat:dataId];
		VMFloat		percent		= (count*100./(double)totalAudioFragmentCount);
		VMAudioFragment	*ac			= ClassCastIfMatch( [DEFAULTSONG data:dataId], VMAudioFragment );
		VMTime		duration	= ( ac ? ac.duration * count : 0 );
		
		maxFragmentCount		= MAX( count,		maxFragmentCount );
		maxFragmentPercent	= MAX( percent,		maxFragmentPercent );
		maxFragmentDuration	= MAX( duration,	maxFragmentDuration );
		
		[fragArray push:[[[VMPReportRecord alloc] initWithType:vmpReportRecordType_frag
														   id:dataId
														count:count
													  percent:percent
													 duration:duration  ] autorelease]];
		
		if ( ac ) {
			VMId	*partId			= ac.partId;
			VMTime	partDuration	= [durationForPart itemAsFloat:partId];
			partDuration  += duration;
			totalDuration += ac.duration;
			[durationForPart		setItem:VMFloatObj(partDuration) for:partId];
			[numberOfFragmentsForPart	setItem:@([numberOfFragmentsForPart itemAsInt:partId] +1) for:partId];
			[durationArray			push:	VMFloatObj(duration)];
		}
	}
	[self.histograms setItem:durationArray for:@"duration"];
	return fragArray;
}

//
// part report
//
- (VMArray*)partReportWithDurationForPart:(VMHash*)durationForPart numberOfFragmentsForPart:(VMHash*)numberOfFragmentsForPart {
	self.dataIdToProcess = [_countForPart sortedKeys];
	VMArray *partsArray = ARInstance(VMArray);
	VMArray *varietyArray = ARInstance(VMArray);
	for ( VMString *dataId in _dataIdToProcess ) {
		VMFloat count		= [_countForPart itemAsFloat:dataId];
		VMInt	dataCount	= [numberOfFragmentsForPart itemAsInt:dataId];
		VMFloat percent		= (count*100./(double)totalPartCount);
		VMTime  duration	= [durationForPart itemAsFloat:dataId];
		
		maxPartCount	= MAX( count,		maxPartCount );
		maxPartPercent	= MAX( percent,		maxPartPercent );
		maxPartDuration	= MAX( duration,	maxPartDuration );
		
		VMPReportRecord *r = [[[VMPReportRecord alloc] initWithType:VMPReportRecordType_part
																 id:dataId
															  count:count
															percent:percent
														   duration:duration] autorelease];
		if ( !exitWhenPartChanged ) {
			//	calculate mean for sojourn length
			VMFloat sum = 0;
			VMArray *sojForPart = [_sojournDataForPart item:dataId];
			for( VMHash *h in sojForPart )
				sum += [h itemAsFloat:@"length"];
			r.sojourn		= @( sum / sojForPart.count );
			
			//
			VMFloat variety = [numberOfFragmentsForPart itemAsInt:dataId] / duration * 100;
			if ( variety > 100 ) variety = 0;//	ignore too big values.
			r.variety		= VMFloatObj( variety );
			[varietyArray push:r.variety];
			maxVariety		= MAX( variety, maxVariety );
			r.title			= [NSString stringWithFormat:@"%@  (%ld frags)",dataId, dataCount ];
		}
		[partsArray push:r];
	}
	[self.histograms setItem:varietyArray for:@"variety"];
	return partsArray;
}

//
//	main
//
- (void)finishAnalysis {
	VMHash *durationForPart = ARInstance(VMHash);
	VMHash *numberOfFragmentsForPart = ARInstance(VMHash);
	[self.progressWC setProgress:0 ofTotal:0 message:nil window:[VMPlayerOSXDelegate singleton].editorViewController.window];

	totalDuration=maxPartCount=maxPartPercent=maxPartDuration=maxFragmentCount=maxFragmentPercent=maxFragmentDuration=maxVariety=0;
	
	VMArray *fragArray   = [self audioFragmentReportWithDurationForPart:durationForPart numberOfFragmentsForPart:numberOfFragmentsForPart];
	VMArray *partsArray = [self partReportWithDurationForPart:durationForPart numberOfFragmentsForPart:numberOfFragmentsForPart];
	[DEFAULTSONG.showReport restore];
	
	//
	// histograms
	//
	[self.histograms setItem:[_countForFragmentId values] for:@"count"];

	//
	// unreacheables
	//
	VMArray *unreacheableAC = ARInstance(VMArray);
	int totalAcCount=0;
	
	VMArray *allIdArray = [DEFAULTSONG.songData sortedKeys];
	for( VMId *dataId in allIdArray ) {
		VMData *d = [DEFAULTSONG.songData item:dataId];
		if ( d.type == vmObjectType_audioFragment ) {
			id c = [_countForFragmentId item:dataId];
			++totalAcCount;
			if ( !c ) [unreacheableAC push:dataId];
		}
	}

	//
	// make report
	//
	self.report = [VMHash hashWithDictionary:
				   @{
				   @"frags":fragArray,
				   @"parts":partsArray,
				   @"totalDuration":VMFloatObj(totalDuration),
				   @"unreachableAudioFragments":unreacheableAC,
				   @"unresolveables":self.unresolveables,
				   @"fragmax":[VMHash hashWithDictionary:
							  @{@"count":@(maxFragmentCount), @"percent":@(maxFragmentPercent), @"duration":@(maxFragmentDuration)}],
				   @"partmax":[VMHash hashWithDictionary:
							   @{@"count":@(maxPartCount), @"percent":@(maxPartPercent), @"duration":@(maxPartDuration)}]
				   }];
	
		
	if( unreacheableAC.count > 0 ) {
		[APPDELEGATE.systemLog logWarning: [NSString stringWithFormat:
											@"%ld unreacheable audio frags (within %d steps)",
											unreacheableAC.count,
											kNumberOfIterationsOfGlobalTraceRoute * kLengthOfGlobalTraceRoute]
								 withData: nil];
		[APPDELEGATE.systemLog record:unreacheableAC filter:NO];
	}
	if ( self.unresolveables.count > 0 ) {
		[APPDELEGATE.systemLog logWarning: [NSString stringWithFormat:
											@"%ld unresolveable data",
											self.unresolveables.count]
								 withData: nil];
		[APPDELEGATE.systemLog record:self.unresolveables filter:NO];
	}
	if ( self.unresolveables == 0 && unreacheableAC.count == 0 ) {
		[APPDELEGATE.systemLog addTextLog:@"Route Stats" message:@"no issue."];
	}
	[VMPNotificationCenter postNotificationName:VMPNotificationLogAdded
										 object:self
									   userInfo:@{@"owner":@(VMLogOwner_System)}];
	self.reportWindow.isVisible = YES;
	[self.reportWindow makeKeyAndOrderFront:self];
	[self.statisticsView.reportView reloadData];
	
	//
	// history
	//
	self.history = ARInstance(VMArray);
	self.historyPosition = 0;
	
	//	log
	[self.log save];
	DEFAULTSONG.log = [[[VMLog alloc] initWithOwner:VMLogOwner_Player managedObjectContext:nil] autorelease];

						

	//
	// statistics view
	//
	[self.statisticsView setInfoText: [NSString stringWithFormat:@"%ld parts / %ld audio frags / total %2d:%2d'%2.2f",
									   partsArray.count, fragArray.count,
									   ((int)totalDuration)/3600, ((int)totalDuration/60)%60, fmod(totalDuration, 60)
									   ]];

	[self.statisticsView updateButtonStates];
	[self.statisticsView.reportView selectColumnIndexes:[NSIndexSet indexSetWithIndex:0]
								   byExtendingSelection:NO];
	
	[self updateGraphView];
	[self.delegate analysisFinished: self.report];
	
	
	
	numberOfIterations = 0;
    _busy = NO;
}


/*---------------------------------------------------------------------------------
 
 check for missing media files
 
 ----------------------------------------------------------------------------------*/

- (void)checkFiles_proc {
	VMInt dataCount = self.dataIdToProcess.count;
	for( int i = 0; i < 100; ++i ) {
		VMData *d = [DEFAULTSONG.songData item:[self.dataIdToProcess item:self.currentPositionInDataIdList]];
		if ( d.type == vmObjectType_audioInfo ) {
			NSString *fileId = ((VMAudioInfo*)d).fileId;
			VMString *path = [DEFAULTSONGPLAYER filePathForFileId:fileId];
			if( ! path )
				[self addUnresolveable:( fileId.length > 3 ? fileId : d )];
		}
		++self.currentPositionInDataIdList;
		if( self.currentPositionInDataIdList >= dataCount ) break;
	}
	
	[self.progressWC setProgress:(double)self.currentPositionInDataIdList
						 ofTotal:(double)dataCount message:@"Checking File:"
						  window:APPDELEGATE.editorViewController.window];
	
	if ( ++self.currentPositionInDataIdList < dataCount ) {
		[self performSelector:@selector(checkFiles_proc) withObject:nil afterDelay:0.005];
	} else {
		if( self.unresolveables.count == 0 ){
			[APPDELEGATE.systemLog addTextLog:@"Check Media Files" message:@"no issue"];
		} else {
			[APPDELEGATE.systemLog logError:[NSString stringWithFormat:@"%ld audio files not found:", self.unresolveables.count]
								   withData:nil];
			[APPDELEGATE.systemLog record:self.unresolveables filter:NO];
		}
		
		[self.progressWC setProgress:0 ofTotal:0 message:nil window:[VMPlayerOSXDelegate singleton].editorViewController.window];
		[VMPNotificationCenter postNotificationName:VMPNotificationLogAdded
											 object:self
										   userInfo:@{@"owner":@(VMLogOwner_System)}];
		self.dataIdToProcess = nil;
		_busy =NO;
	}
}

#define addReferrerForId(targetId) \
VMHash *referrerOfData = [referrer itemAsHash:targetId];\
if ( ! referrerOfData ) {\
	referrerOfData = ARInstance(VMHash);\
	[referrer setItem:referrerOfData for:targetId];\
}\
[referrerOfData setItem:@(YES) for:dataId]

#define addReferrerAndCheckUnresolved(targetId) \
VMId *tid = targetId ; \
addReferrerForId(tid); \
unresolved = ! [DEFAULTSONG data:tid]

#define addRefererAndAddUnresolved(targetId) {\
VMId *tid2 = targetId; \
addReferrerForId(tid2); \
if ( ! [DEFAULTSONG data:tid2] ) [self addUnresolveable:tid2]; }

#define addReferrerAndCheckUnresolvedForSubData(subData) {\
if( ClassMatch(subData, VMId)) \
	addRefererAndAddUnresolved( subData ) \
else if( ClassMatch(subData, VMChance )) \
	addRefererAndAddUnresolved( ((VMChance*)subData).targetId ) \
}


/*---------------------------------------------------------------------------------
 
 vms validation
 
 ----------------------------------------------------------------------------------*/
- (VMHash*)collectReferrer {
	self.dataIdToProcess	= [DEFAULTSONG.songData sortedKeys];
	self.unresolveables		= ARInstance(VMArray);
	VMHash *referrer		= ARInstance(VMHash);		// this is for collecting referrer info. not used to find unresolveables.
	for( VMId* dataId in self.dataIdToProcess ) {
		VMData *data = [DEFAULTSONG.songData item:dataId];
		
		BOOL unresolved = NO;
		switch ( (int)data.type) {
			case vmObjectType_unresolved:
			case vmObjectType_unknown:
				unresolved = YES;
				break;
				
			case vmObjectType_audioFragment: {
				addReferrerAndCheckUnresolved( ((VMAudioFragment*)data).audioInfoId );
				break;
			}
			case vmObjectType_reference:
			case vmObjectType_chance: {
				addReferrerAndCheckUnresolved(((VMReference*)data).referenceId );
				break;
			}
			case vmObjectType_collection:
			case vmObjectType_selector:
			case vmObjectType_sequence: {
				for( id subData in ((VMCollection*)data).fragments ) {
					addReferrerAndCheckUnresolvedForSubData( subData );
				}
				if ( data.type == vmObjectType_sequence ) {
					for( id subData in ((VMSequence*)data).subsequent.fragments ) {
						addReferrerAndCheckUnresolvedForSubData( subData );
					}
				}
				break;
			}
		}
		if ( unresolved ) [self addUnresolveable:data];
	}
	
	_busy = NO;
	return referrer;
}

- (void)findUnresolveables {
	[self collectReferrer];
	if( self.unresolveables.count == 0 )
		[APPDELEGATE.systemLog addTextLog:@"Validate VM Structure" message:@"no issue."];
	else {
		[APPDELEGATE.systemLog logError:[NSString stringWithFormat:@"%ld unresolved references found:", self.unresolveables.count]
							   withData:nil];
		[APPDELEGATE.systemLog record:self.unresolveables filter:NO];
	}
	[VMPNotificationCenter postNotificationName:VMPNotificationLogAdded
										 object:self
									   userInfo:@{@"owner":@(VMLogOwner_System)}];
}


#pragma mark -
#pragma mark progress
- (void)progressCancelled {
	iterationsLeft = 0;
}


#pragma mark -
#pragma mark history

- (void)addHistory:(VMId*)recordId {
	if( [((VMId*)[self.history item:self.historyPosition]) isEqualToString:recordId] ) return;
	
	if( !self.history ) self.history = ARInstance(VMArray);
	[self.history deleteItemsFrom:self.historyPosition +1 to:-1];
	[self.history push:recordId];
	
	self.historyPosition = self.history.count -1;
	[self.statisticsView updateButtonStates];
	
	if ( self.history.count > 1500 ) [self.history truncateFirst:1000];
}

- (void)moveHistory:(VMInt)vector {
	self.historyPosition += vector;
	if ( self.historyPosition < 0 )
		self.historyPosition = 0;
	if ( self.historyPosition >= self.history.count )
		self.historyPosition = self.history.count -1;
	
	[self.statisticsView updateButtonStates];

	VMId *recordId = [self.history item:self.historyPosition];
	[self itemSelectedWithId:recordId];
}


#pragma mark -
#pragma mark tableview related

//	NSTableView delegate and dataSource
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
	return [(VMArray*)[self.report item:@"frags"] count] + [(VMArray*)[self.report item:@"parts"] count];
}


- (NSString*)textForColumnType:(char)type record:(VMPReportRecord*)record {
	switch (type) {
		case 'i':
			return record.title ? record.title : record.ident;
			break;
			
		case 'c':
			return [NSString stringWithFormat:@"%d",[record.count intValue]];
			break;
			
		case 'p':
			return [NSString stringWithFormat:@"%3.3f%%",[record.percent doubleValue]];
			break;
			
		case 'd': {
			VMTime dur = [record.duration doubleValue];
			if ( dur == 0 ) return @"-";
			int sec  = ((int)( dur         )) % 60;
			int min  = ((int)( dur /    60 )) % 60;
			int hour = ((int)( dur /  3600 )) % 24;
			int day  = ((int)( dur / 86400 ));
			
			return [NSString stringWithFormat:@"%d|%02d:%02d'%02d",day,hour,min,sec];
			break;
			
			
		}
		case 's': {
			double s = [record.sojourn doubleValue];
			if ( s ) return [NSString stringWithFormat:@"%.2f",s];
			break;
		}
		case 'v': {
			double v = [record.variety doubleValue];
			if ( v ) return [NSString stringWithFormat:@"%.2f",v];
			break;
		}
	}
	return @"";

}

- (VMPReportRecord *)recordForRow:(NSInteger)row {
    VMArray *parts = [self.report item:@"parts"];
	VMInt	partsCount = parts.count;
	
	if ( row >= partsCount ) {
		VMArray *frags  = [self.report item:@"frags"];
		return [frags item:(VMInt)row - partsCount];
	} else {
		return [parts item:(VMInt)row];
	}
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
	VMPReportRecord *record = [self recordForRow:row];
	char type = [tableColumn.identifier cStringUsingEncoding:NSASCIIStringEncoding][0];
	return [self textForColumnType:type record:record];
}

- (NSCell *)tableView:(NSTableView *)tableView dataCellForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
	if( !tableColumn) return nil;
	VMPReportRecord *record = [self recordForRow:row];
	char type = [tableColumn.identifier cStringUsingEncoding:NSASCIIStringEncoding][0];
	if ( type == 'i' || type == 'c' || type == 's' ) return [tableColumn dataCellForRow:row];
	
	VMPRecordCell *cell = recordCell_defaultCell__;
	cell.title = [self textForColumnType:type record:record];
	VMFloat ratio;
	switch (type) {
		case 'p':
			ratio = cell.ratio = [record.percent doubleValue] / ( record.type == vmpReportRecordType_frag ? maxFragmentPercent : maxPartPercent );
			cell.barColor = record.type == vmpReportRecordType_frag
			? [NSColor colorWithCalibratedRed:1.
										green:0.7 - ratio * 0.3
										 blue:ratio
										alpha:.9]
			: [NSColor colorWithCalibratedRed:ratio * 0.4 + 0.1
										green:0.7
										 blue:0.7 - ratio * 0.5
										alpha:0.9];
			break;
		case 'd':
			ratio = cell.ratio = [record.duration doubleValue] /( record.type == vmpReportRecordType_frag ? maxFragmentDuration : maxPartDuration );
			cell.barColor = record.type == vmpReportRecordType_frag
			? [NSColor colorWithCalibratedRed:1.
										green:0.7 - ratio * 0.3
										 blue:ratio
										alpha:.9]
			: [NSColor colorWithCalibratedRed:ratio * 0.4 + 0.1
										green:0.7
										 blue:0.7 - ratio * 0.5
										alpha:0.9];
			break;
		case 'v':
			ratio = cell.ratio = [record.variety doubleValue] / ( record.type == vmpReportRecordType_frag ? 1 : maxVariety );
			cell.barColor = [NSColor colorWithCalibratedRed:0.4
													  green:0.5 + ratio * 0.3
													   blue:0.7 - ratio * 0.5
													  alpha:.9];

			break;
	}
	/*
	 oliveColor		= [[NSColor colorWithCalibratedRed:0.3 green:0.7 blue:0.4 alpha:0.9] retain];
	 teaColor		= [[NSColor colorWithCalibratedRed:0.4 green:0.9 blue:0.6 alpha:0.9] retain];
	 mandarineColor	= [[NSColor colorWithCalibratedRed:1.0 green:0.7 blue:0.3 alpha:0.9] retain];
	 */
	
	return cell;
}

/*
 
		select row
 
 */

- (void)selectRow:(NSInteger)row {
	VMPReportRecord *record = [self recordForRow:row];
	[self addHistory:record.ident];
	[self.recordDetailPopover setRecordId:record.ident routeData:_routesForId];
	[self.recordDetailPopover setSojourn:[_sojournDataForPart item:record.ident]];
	self.recordDetailPopover.popoverDelegate = self;
	
	NSRect rect = [self.statisticsView.reportView rectOfRow:row];
	[self.recordDetailPopover showRelativeToRect:rect
										  ofView:self.statisticsView.reportView
								   preferredEdge:NSMaxXEdge];
	if (record && record.ident.length > 2)
		[VMPNotificationCenter postNotificationName:VMPNotificationFragmentSelected object:self userInfo:@{@"id":record.ident}];
}



/*
- (void)scrollRowToVisible:(NSInteger)rowIndex animate:(BOOL)animate{
    if(animate){
        NSRect rowRect = [self.reportView rectOfRow:rowIndex];
        NSPoint scrollOrigin = rowRect.origin;
        NSClipView *clipView = (NSClipView *)[self.reportView superview];
        scrollOrigin.y += MAX(0, round((NSHeight(rowRect)-NSHeight(clipView.frame))*0.5f));
        [[clipView animator] setBoundsOrigin:scrollOrigin];
    }else{
        [self.reportView scrollRowToVisible:rowIndex];
    }
}
*/
//	reordDetailPopover delegate
- (BOOL)itemSelectedWithId:(NSString *)itemId {
	NSInteger c = [self numberOfRowsInTableView:nil ];
	NSInteger found = -1;
	for( int row = 0; row < c; ++row ) {
		VMPReportRecord *rec = [self recordForRow:row];
		if ( [rec.ident isEqualToString:itemId] ) {
			found = row;
			break;
		}
	}
	
	if ( found >=0 ) {
		NSInteger sel = self.statisticsView.reportView.selectedRow;
		
		[self.statisticsView.reportView selectRowIndexes:[NSIndexSet indexSetWithIndex:found] byExtendingSelection:NO];
		[self.statisticsView.reportView scrollRowToVisible:found + (( sel < found ) ? 3 : -3 ) ];
		[self selectRow:found];
		return YES;
	}
	return NO;
}

- (BOOL)tableView:(NSTableView *)tableView shouldTypeSelectForEvent:(NSEvent *)event
withCurrentSearchString:(NSString *)searchString {
	if ( event.type == NSKeyDown && event.keyCode == kVK_Space ) {
		[DEFAULTSONGPLAYER startWithFragmentId:[self.history item:self.historyPosition]];
		return NO;
	}
	
	if ( [searchString hasPrefix:@" "]) return NO;
	return YES;
}


- (void)tableViewSelectionDidChange:(NSNotification *)notification {
	[self selectRow:self.statisticsView.reportView.selectedRow];
}

- (void)tableView:(NSTableView *)tableView sortDescriptorsDidChange:(NSArray *)oldDescriptors {
	VMArray *parts = [self.report item:@"parts"];
	VMArray *frags  = [self.report item:@"frags"];
	
	NSArray *desc = [tableView sortDescriptors];
	
	[parts.array sortUsingDescriptors:desc];
	[frags. array sortUsingDescriptors:desc];
	[tableView reloadData];
	
	[self moveHistory:0];
}

@end

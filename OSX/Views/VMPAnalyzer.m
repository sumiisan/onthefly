//
//  VMPAnalyzer.m
//  OnTheFlyOSX
//
//  Created by  on 13/02/26.
//  Copyright (c) 2013 sumiisan. All rights reserved.
//

#import "VMPAnalyzer.h"
#import "VMSong.h"
#import "VMPMacros.h"
#import "VMOnTheFlyEditorAppDelegate.h"
#import "VMPSongPlayer.h"
#include "KeyCodes.h"
#import "VMPNotification.h"
#import "VMPProgressWindowController.h"
#import "VMAudioObject.h"
#import "VMScoreEvaluator.h"


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
	self.count		= @(inCount);
	self.percent	= @(inPercent);
	self.duration	= @(inDuration);

	return self;
}

- (void)dealloc {
	VMNullify(ident);
	VMNullify(count);
	VMNullify(percent);
	VMNullify(duration);
	Dealloc( super );
}

@end

/*---------------------------------------------------------------------------------
 
 statistics view
 
 ----------------------------------------------------------------------------------*/

#pragma mark -
#pragma mark Statististics View

@implementation VMPStatisticsView

- (void)awakeFromNib {
	self.tableView.doubleAction = @selector(doubleClickOnRow:);
}


- (void)setInfoText:(VMString*)infoText {
	((NSTextField*)[self viewWithTag:140]).stringValue = infoText;
}


- (IBAction)clickOnButton:(id)sender {
	NSSegmentedControl *sc = sender;
	
	switch (sc.selectedSegment) {
		case 0:
			[DEFAULTANALYZER moveHistory:-1];
			break;
		case 1:
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
		return [DEFAULTANALYZER.history canMove:-1];
	}
	if (action==@selector(moveHistoryForward:)) {
		return [DEFAULTANALYZER.history canMove: 1];
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
	[self.historyArrowButtons setEnabled:[DEFAULTANALYZER.history canMove:-1] forSegment:0];
	[self.historyArrowButtons setEnabled:[DEFAULTANALYZER.history canMove: 1] forSegment:1];
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

@property (VMStrong)						VMHash						*countForFragmentId;
@property (VMStrong)						VMHash						*routesForFragmentId;
@property (VMStrong)						VMHash						*routesForSelectorId;
@property (VMStrong)						VMHash						*countForPart;
@property (VMStrong)						VMHash						*sojournDataForPart;
@property (VMStrong)						VMHash						*histograms;
@property (VMStrong)						VMArray						*unresolveables;
@property (VMStrong)						VMArray						*fileWarnings;

@property (readonly, getter=isBusy)			BOOL						busy;
@property (VMStrong)						VMFragment					*entryPoint;
@property (VMStrong)						VMId						*currentPartId;

@property (VMStrong)						VMArray						*dataIdToProcess;
@property (assign)							VMInt						currentPositionInDataIdList;

@property (VMStrong)						VMString					*lastFragmentId;

//	for histogram
@property (VMStrong)						VMArray						*hist_numberOfBranches;
@property (VMStrong)						VMArray						*hist_duration;

@end

/*---------------------------------------------------------------------------------
 *
 *
 *	VMP Analyzer
 *
 *
 *---------------------------------------------------------------------------------*/

@implementation VMPAnalyzer 

static VMPAnalyzer		*analyzer_singleton_static_		= nil;
static VMPRecordCell	*recordCell_defaultCell_static_	= nil;

//
static const int	kNumberOfIterationsOfGlobalTraceRoute   =   800;
static const int	kLengthOfGlobalTraceRoute				=   600;

//	300 entries
static const int	kNumberOfIterationsOfPartTraceRoute		=	300;
static const int	kLengthOfPartTraceRoute					= 10000;	//	gives up after 10000 times advancing.

+ (VMPAnalyzer*)defaultAnalyzer {

	if ( ! analyzer_singleton_static_ ) {
		analyzer_singleton_static_ = [[VMPAnalyzer alloc] init];
	}
	if ( ! recordCell_defaultCell_static_ ) {
		recordCell_defaultCell_static_ = [[VMPRecordCell alloc] initTextCell:@""];
		[recordCell_defaultCell_static_ setFont:[NSFont systemFontOfSize:11]];
		[recordCell_defaultCell_static_ setAlignment:NSRightTextAlignment ];
	}	
	return analyzer_singleton_static_;
}

- (id)init {
	self=[super init];
	if (self) {
		analyzer_singleton_static_ = self;
		self.progressWC = AutoRelease([[VMPProgressWindowController alloc] initWithWindow:nil] );
		[[NSBundle mainBundle] loadNibNamed:@"VMPProgressWindow" owner:self.progressWC topLevelObjects:nil];
		
		self.progressWC.delegate = self;
		
		[VMPNotificationCenter addObserver:self selector:@selector(vmsDataLoaded:) name:VMPNotificationVMSDataLoaded object:nil];
	}
	return self;
}

- (void)dealloc {
	[VMPNotificationCenter removeObserver:self];
	//
	VMNullify(dataIdToProcess);
	VMNullify(lastFragmentId);
	//
	VMNullify(entryPoint);
	VMNullify(report);
	VMNullify(progressWC);
	VMNullify(currentPartId);
	VMNullify(unresolveables);
	VMNullify(fileWarnings);
	VMNullify(history);
	VMNullify(countForFragmentId);
	VMNullify(countForPart);
	VMNullify(sojournDataForPart);
	VMNullify(routesForFragmentId);
	VMNullify(routesForSelectorId);
	VMNullify(histograms);
	VMNullify(hist_numberOfBranches);
	VMNullify(hist_duration);
	
    Dealloc( super );;
}

#pragma mark -
#pragma mark data access

- (VMPReportRecord*)reportRecordForId:(VMId*)dataId {
	VMArray *fragArray = [self.report item:@"frags"];
	if( ! fragArray ) return nil;
	for( VMPReportRecord *rec in fragArray ) {
		if ( [rec.ident isEqualToString:dataId ] ) return rec;
	}
	return nil;
}

- (VMSelector*)makeSelectorFromStatistics:(VMId*)selectorId{
	VMHash		*scores = [_routesForSelectorId item:selectorId];
	VMArray		*keys	= [scores keys];
	VMSelector	*sel	= ARInstance(VMSelector);
	sel.fragments = ARInstance(VMArray);
	for ( VMId *targetId in keys ) {
		VMChance *c = ARInstance( VMChance );
		c.targetId = targetId;
		c.scoreDescriptor = [NSString stringWithFormat:@"%.2f", [scores itemAsFloat:targetId]];
		[sel.fragments push:c];
	}
	return sel;
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
			[self routeStatistic:[CURRENTSONG data:CURRENTSONG.defaultFragmentId]
			  numberOfIterations:kNumberOfIterationsOfGlobalTraceRoute
						   until:nil];
			break;
		}
		case 1: {
			//
			// part domestic route statistics
			//
			VMId *partId = [[VMArray arrayWithString:APPDELEGATE.editorWindowController.currentDisplayingDataId
											 splitBy:@"_"] item:0];
			VMFragment *entrySelector = [CURRENTSONG data:[partId stringByAppendingString:@"_sel"]];
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
			// check audio files
			//
			totalDuration = 0;
			totalFileDuration = 0;
			self.dataIdToProcess = [CURRENTSONG.songData sortedKeys];
			self.unresolveables = ARInstance(VMArray);
			self.currentPositionInDataIdList = 0;
			self.fileWarnings = ARInstance(VMArray);
			self.hist_numberOfBranches = ARInstance(VMArray);
			self.hist_duration = ARInstance(VMArray);
			_busy =YES;
			[self checkFiles_proc];
			
			break;
		}
	}
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
	if ( menuItem.action == @selector(songPlay:)) {
		return self.statisticsView.tableView.selectedRow != -1;
	}
	return ! self.busy;
}

- (IBAction)songPlay:(id)sender {
	VMPReportRecord *rr = [self recordForRow:self.statisticsView.tableView.selectedRow];
	if ( rr ) {
		if ( rr.type == VMPReportRecordType_part ) {
			[DEFAULTSONGPLAYER startWithFragmentId:[rr.ident stringByAppendingString:@"_sel"]];
		} else {
			[DEFAULTSONGPLAYER startWithFragmentId:rr.ident];
		}
	}	
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
	[self.statOverviewGraphPanel setViewsNeedDisplay:YES];
	[self.statOverviewGraphPanel makeKeyAndOrderFront:self];
}

#pragma mark -
#pragma mark analysis


/*---------------------------------------------------------------------------------
 
 route statistics (public method)
 
 ----------------------------------------------------------------------------------*/

- (BOOL)routeStatistic:(VMFragment *)inEntryPoint
	numberOfIterations:(const long)inNumberOfIterations
				 until:(VMString*)exitCondition {
	if ( self.isBusy ) return NO;

    totalSteps = 0;

    _busy = YES;
	VMNullify(report);
	self.entryPoint = inEntryPoint;
	self.log = AutoRelease([[VMLog alloc] initWithOwner:VMLogOwner_Statistics
						managedObjectContext:nil] );
	[CURRENTSONG.log save];
	CURRENTSONG.log = self.log;
	
	CURRENTSONG.showReport.current = @NO;
	[CURRENTSONG setFragmentId:self.entryPoint.id];
	
    exitWhenPartChanged = ( [exitCondition isEqualToString:@"exit-part" ]);
	self.currentPartId	= inEntryPoint.partId;
    
	
	self.unresolveables		= ARInstance(VMArray);
	self.countForFragmentId	= ARInstance(VMHash);
	self.countForPart		= ARInstance(VMHash);
	self.sojournDataForPart	= ARInstance(VMHash);
	self.routesForFragmentId= ARInstance(VMHash);
	self.routesForSelectorId= ARInstance(VMHash);
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

#define incrementRouteForId(hashStorage,dataId,fromId,toId) \
{\
	VMHash *d = [hashStorage item:dataId];\
	if ( d == nil ) {\
		d = [VMHash hashWith:@{ @"from":ARInstance(VMHash), @"to":ARInstance(VMHash) }];\
		[hashStorage setItem:d for:dataId];\
	}\
	if ( fromId != nil ) [[d item:@"from"] add:1. ontoItem:fromId];\
	if ( toId   != nil ) [[d item:@"to"]   add:1. ontoItem:toId];\
}

/*---------------------------------------------------------------------------------
 
 process analysis
 
 @return	YES if it should exit analyze_step loop
 
 ----------------------------------------------------------------------------------*/
- (BOOL)analyze_step {
	@autoreleasepool {
        totalSteps++;
		VMAudioFragment *af = [CURRENTSONG nextAudioFragment];
		if( ! af ) {
            /*  don't add unresolved frags after "end" into statistic (may destroy statistic balance) */
            if (![_lastFragmentId isEqualToString:@"end"]) {
                [_countForFragmentId add:1. ontoItem:@"unresolved"];
                incrementRouteForId( _routesForFragmentId, @"unresolved,", _lastFragmentId, nil );
                incrementRouteForId( _routesForFragmentId, _lastFragmentId, nil, @"unresolved");
            }

            [self reset_proc];
			return YES;     // end iteration if unresolved
		}
		
		++sojourn;
		
		//	route
		if ( _lastFragmentId ) {
			incrementRouteForId( _routesForFragmentId, _lastFragmentId, nil, af.id );
			incrementRouteForId( _routesForFragmentId, af.id, _lastFragmentId, nil );
		}
		
		if ( exitWhenPartChanged ) {
			if ( ! [af.partId isEqualToString: self.currentPartId ] ) {
				VMInt c = [_countForPart itemAsInt:af.partId];
				[_countForPart setItem:@(c+1) for:af.partId];
				[self pushSojournForPart:af.partId length:sojourn startIndexInLog:startIndexOfSojourn];
				incrementRouteForId( _routesForFragmentId, af.partId, _lastFragmentId, af.fragId );
				sojourn = 0;
				startIndexOfSojourn = [self.log nextIndex];
				++totalPartCount;
				[self reset_proc];
				return exitWhenPartChanged;
			}
		} else {
			VMInt c = [_countForPart itemAsInt:af.partId];
			[_countForPart setItem:@(c+1) for:af.partId];
			++totalPartCount;
			if ( ! [af.partId isEqualToString: self.currentPartId ] ) {
				[self pushSojournForPart:self.currentPartId length:sojourn startIndexInLog:startIndexOfSojourn];
				incrementRouteForId( _routesForFragmentId, self.currentPartId, nil, af.partId );
				incrementRouteForId( _routesForFragmentId, af.partId, self.currentPartId, nil );
				self.currentPartId = af.partId;
				sojourn = 0;
				startIndexOfSojourn = [self.log nextIndex];
			}
		}
		
		[_countForFragmentId setItem:@([_countForFragmentId itemAsInt:af.id]+1) for:af.id];
		
		//	simulate fire
		[af interpreteInstructionsWithAction:vmAction_play];
        DEFAULTSONGPLAYER.playTimeAccumulator.playingTimeOfCurrentPart += af.duration;  // increment part playing time

		++totalAudioFragmentCount;
		self.lastFragmentId = af.fragId;
	}
	return NO;
}

- (void)reset_proc {
	[CURRENTSONG setFragmentId:self.entryPoint.id];
	VMNullify(lastFragmentId);
}

- (void)collectSelectorScores {
	VMInt  p = self.log.count -1;
	VMTime now = [NSDate timeIntervalSinceReferenceDate];
	
	while ( p >= 0 ) {
		VMLogRecord *lr = [self.log item:p];
		if ( lr.playbackTimestamp ) break;
		lr.playbackTimestamp = now;
		--p;

		if ( lr.type != vmObjectType_selector ) continue;
		
		VMHash  *scoreForFragments = lr.subInfo;
		VMArray *keys = [scoreForFragments keys];
		VMFloat sum = [[scoreForFragments values] sum];
		VMHash  *accumulatedScoreForFragments = [_routesForSelectorId item:lr.data];	//	;whereby data = id
		if ( ! accumulatedScoreForFragments ) {
			accumulatedScoreForFragments = ARInstance( VMHash );
			[_routesForSelectorId setItem:accumulatedScoreForFragments for:lr.data];
		}

		for( VMId *key in keys ) {
			if ( [key isEqualToString:@"vmlog_selected"] ) continue;
			VMFloat score = [scoreForFragments itemAsFloat:key] / sum;	//	normalize
			[accumulatedScoreForFragments add:score ontoItem:key];
		}
	}

}


- (void)analyze_proc {
	//	collect route data
    for ( long j  = ( exitWhenPartChanged ? kLengthOfPartTraceRoute : (kLengthOfGlobalTraceRoute * 2) ); j; --j) {
        if (j < kLengthOfGlobalTraceRoute) {
            DEFAULTEVALUATOR.timeManager.remainTimeUntilShutdown = 0;
        }
		if ( [self analyze_step] ) break;
    }
	
	//	collect selector scores
	[self collectSelectorScores];
	
	[self.progressWC setProgress:(double)(numberOfIterations - iterationsLeft)
						 ofTotal:(double)numberOfIterations message:@"Analyzing:"
						  window:[VMOnTheFlyEditorAppDelegate singleton].editorWindowController.window];
	if ( --iterationsLeft > 0 ) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.0001 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self analyze_proc];
        });
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
- (VMArray*)audioFragmentReportWithDurationForPart:(VMHash*)durationForPart
						  numberOfFragmentsForPart:(VMHash*)numberOfFragmentsForPart {
	
	self.dataIdToProcess = [_countForFragmentId sortedKeys];
	VMArray *fragArray		= ARInstance(VMArray);
	VMArray *durationArray	= ARInstance(VMArray);
	
	for ( VMString *dataId in _dataIdToProcess ) {
		VMFloat		count		= [_countForFragmentId itemAsFloat:dataId];
		VMFloat		percent		= (count*100./(double)totalAudioFragmentCount);
		VMAudioFragment	*af		= ClassCastIfMatch( [CURRENTSONG data:dataId], VMAudioFragment );
		VMTime		duration	= ( af ? af.duration * count : 0 );
		
		maxFragmentCount	= MAX( count,		maxFragmentCount );
		maxFragmentPercent	= MAX( percent,		maxFragmentPercent );
		maxFragmentDuration	= MAX( duration,	maxFragmentDuration );
		
		VMPReportRecord *rec = AutoRelease([[VMPReportRecord alloc] initWithType:vmpReportRecordType_frag
																			  id:dataId
																		   count:count
																		 percent:percent
																		duration:duration  ] );
		
		VMId	*partId = nil;
		if ( af ) {
			partId = af.partId;
			VMTime	partDuration	= [durationForPart itemAsFloat:partId];
			partDuration  += duration;
			totalDuration += af.duration;
			[durationForPart		setItem:VMFloatObj(partDuration) for:partId];
			[numberOfFragmentsForPart	setItem:@([numberOfFragmentsForPart itemAsInt:partId] +1) for:partId];
			[durationArray			push:	VMFloatObj(duration)];
		}
		
		//	list-up subsequent parts
		VMArray *subseq = [[[_routesForFragmentId itemAsHash:dataId] itemAsHash:@"to"] sortedKeys];
		VMArray *subseqParts = NewInstance(VMArray);
		
		for ( VMId* subseqId in subseq ) {
			VMId *subPartId = [subseqId componentsSeparatedByString:@"_"][0];
			if ( ! [partId isEqualToString:subPartId] )
				[subseqParts pushUnique:subPartId];
		}
		
		rec.exitParts = [subseqParts join:@","];
		Release(subseqParts);
		[fragArray push:rec];

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
		
		VMPReportRecord *r = AutoRelease([[VMPReportRecord alloc] initWithType:VMPReportRecordType_part
																 id:dataId
															  count:count
															percent:percent
														   duration:duration]);
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
	[self.progressWC setProgress:0 ofTotal:0 message:nil window:[VMOnTheFlyEditorAppDelegate singleton].editorWindowController.window];

	totalDuration=maxPartCount=maxPartPercent=maxPartDuration=maxFragmentCount=maxFragmentPercent=maxFragmentDuration=maxVariety=0;
	
	//	make report records
	
	VMArray *fragArray  = [self audioFragmentReportWithDurationForPart:durationForPart
											  numberOfFragmentsForPart:numberOfFragmentsForPart];
	VMArray *partsArray = [self partReportWithDurationForPart:durationForPart
									 numberOfFragmentsForPart:numberOfFragmentsForPart];
	[CURRENTSONG.showReport restore];
	
	//
	// histograms
	//
	[self.histograms setItem:[_countForFragmentId values] for:@"count"];

	//
	// unreacheables
	//
	VMArray *unreacheableAC = ARInstance(VMArray);
	int totalAcCount=0;
	
	VMArray *allIdArray = [CURRENTSONG.songData sortedKeys];
	for( VMId *dataId in allIdArray ) {
		VMData *d = [CURRENTSONG.songData item:dataId];
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
                       @"steps":@(totalSteps),
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
                                            @"%ld unreacheable audio frags (within %ld steps)",
											unreacheableAC.count,
                                            totalSteps]
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
    
    
	
	[APPDELEGATE showLogPanelIfNewSystemLogsAreAdded];

	self.statisticsWindow.isVisible = YES;
	[self.statisticsWindow makeKeyAndOrderFront:self];
	[self.statisticsView.tableView reloadData];
	
	//
	// history
	//
	self.history = ARInstance(VMHistory);
	
	//	log
	[self.log save];
	CURRENTSONG.log = AutoRelease([[VMLog alloc] initWithOwner:VMLogOwner_MediaPlayer managedObjectContext:nil] );

	//
	// statistics view
	//
	[self.statisticsView setInfoText: [NSString stringWithFormat:@"%ld parts / %ld audio frags / total %2d:%2d'%2.2f",
									   partsArray.count, fragArray.count,
									   ((int)totalDuration)/3600, ((int)totalDuration/60)%60, fmod(totalDuration, 60)
									   ]];

	[self.statisticsView updateButtonStates];
	[self.statisticsView.tableView selectColumnIndexes:[NSIndexSet indexSetWithIndex:0]
								   byExtendingSelection:NO];
	
	[self updateGraphView];
	[self.delegate analysisFinished: self.report];
	
	
	
	numberOfIterations = 0;
    _busy = NO;
}


/*---------------------------------------------------------------------------------
 
 check media files
 
 ----------------------------------------------------------------------------------*/

- (void)checkFiles_proc {
	VMTime standardReleaseTime = 5.0;	//	assume 5 secs of release time
	VMInt dataCount = self.dataIdToProcess.count;
	for( int i = 0; i < 100; ++i ) {
		VMData *d = [CURRENTSONG.songData item:[self.dataIdToProcess item:self.currentPositionInDataIdList]];
		if ( d.type == vmObjectType_audioInfo ) {
			VMAudioInfo *ai = (VMAudioInfo*)d;
			NSString *fileId = ((VMAudioInfo*)d).fileId;
			VMString *path = [DEFAULTSONGPLAYER filePathForFileId:fileId];
			if(( ! path ) || (! [[NSFileManager defaultManager] fileExistsAtPath:path]) )
				[self addUnresolveable:( fileId.length > 3 ? fileId : d )];
			
			VMAudioObject *ao = NewInstance(VMAudioObject);
			[ao open:path];
			if ( (( ai.duration + standardReleaseTime ) < ao.fileDuration ) ||
				 (  ai.duration > ao.fileDuration + 2. )) {
				VMLogRecord *record = [VMLogRecord recordWithAction:@"Warning" data:ai
															subInfo:[VMHash hashWithDictionary: @{@"message":[NSString stringWithFormat:
																	 @"%@ fileId:%@ (dur:%.2fsecs) has file length of %.2fsecs",
																			   ai.duration > ao.fileDuration ? @"S" : @"L",
																			   ai.fileId, ai.duration, ao.fileDuration] }]
															  owner:VMLogOwner_Statistics
												 usePersistentStore:NO];
				
				[self.fileWarnings push:record];
			}
			totalDuration += ai.duration;
			[self.hist_duration push:@(ai.duration)];
			if ( !isnan( ao.fileDuration ) )
				totalFileDuration += ao.fileDuration;
			Release( ao );
		} else
			//
			//	number of branches -- statistics (	actually, it has nothing to do with checking files..
			//										make it separate maybe later )
			//
			if ( d.type == vmObjectType_selector ) {
			[self.hist_numberOfBranches push:@( ((VMSelector*)d).length ) ];
		} else if ( d.type == vmObjectType_sequence ) {
			[self.hist_numberOfBranches push:@( ((VMSequence*)d).subsequent.length ) ];
			
		}
		++self.currentPositionInDataIdList;
		if( self.currentPositionInDataIdList >= dataCount ) break;
	}
	
	[self.progressWC setProgress:(double)self.currentPositionInDataIdList
						 ofTotal:(double)dataCount message:@"Checking File:"
						  window:APPDELEGATE.editorWindowController.window];
	
	if ( ++self.currentPositionInDataIdList < dataCount ) {
		[self performSelector:@selector(checkFiles_proc) withObject:nil afterDelay:0.005];
	} else {
		//
		//	finito!
		//
		if( self.unresolveables.count == 0 && self.fileWarnings.count == 0 ){
			[APPDELEGATE.systemLog addTextLog:@"Check Media Files" message:@"no issue"];
		} else {
			if ( self.unresolveables.count > 0 ) {
				[APPDELEGATE.systemLog logError:[NSString stringWithFormat:@"%ld audio file(s) not found:", self.unresolveables.count]
									   withData:nil];
				[APPDELEGATE.systemLog record:self.unresolveables filter:NO];
			}
			if (self.fileWarnings.count > 0 ) {
				[APPDELEGATE.systemLog logWarning:[NSString stringWithFormat:@"%ld audio file(s) have suspicious file length:",
												   self.fileWarnings.count] withData:nil];
				[APPDELEGATE.systemLog record:self.fileWarnings filter:NO];
			}
			
		}
		VMTime margin = totalFileDuration - totalDuration;
		LLog(@"\n"
			 "total duration: %.2fmin\n"
			 "total file duration: %.2fmin\n"
			 "margin: %.2fmin"
			 "\n"
			 "median of duration %.2fsec\n"
			 "average of numberOfBranches %.2fbranches\n"
			 ,totalDuration / 60., totalFileDuration / 60., margin / 60.
			 ,[self.hist_duration median]
			 ,[self.hist_numberOfBranches mean]
			 );
		[self.progressWC setProgress:0 ofTotal:0 message:nil window:[VMOnTheFlyEditorAppDelegate singleton].editorWindowController.window];
		[APPDELEGATE showLogPanelIfNewSystemLogsAreAdded];
		VMNullify(dataIdToProcess);
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
VMId *tid = targetId; \
if ( ![tid isEqualToString:@"*"] ) {\
	addReferrerForId(tid); \
	unresolved = ! [CURRENTSONG data:tid];\
}

#define addRefererAndAddUnresolved(targetId) {\
	VMId *tid2 = targetId; \
	if ( ![tid2 isEqualToString:@"*"] ) {\
		addReferrerForId(tid2); \
		if ( ! [CURRENTSONG data:tid2] ) [self addUnresolveable:tid2]; \
	}\
}

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
	self.dataIdToProcess	= [CURRENTSONG.songData sortedKeys];
	self.unresolveables		= ARInstance(VMArray);
	VMHash *referrer		= ARInstance(VMHash);		// this is for collecting referrer info. not used to find unresolveables.
	for( VMId* dataId in self.dataIdToProcess ) {
		VMData *data = [CURRENTSONG.songData item:dataId];
		
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
	[APPDELEGATE showLogPanelIfNewSystemLogsAreAdded];
}


#pragma mark -
#pragma mark progress
- (void)progressCancelled {
	iterationsLeft = 0;
}


#pragma mark -
#pragma mark history

- (void)addHistory:(VMId*)recordId {
	if( !self.history ) self.history = ARInstance(VMHistory);
	
	if( [((VMId*)[self.history currentItem]) isEqualToString:recordId] ) return;
	[self.history push:recordId];
	[self.statisticsView updateButtonStates];
	
	if ( self.history.count > 1500 ) [self.history truncateFirst:1000];
}

- (void)moveHistory:(VMInt)vector {
	[self.history move:vector];
	[self.statisticsView updateButtonStates];

	VMId *recordId = [self.history currentItem];
	[self itemSelectedWithId:recordId];
}


#pragma mark -
#pragma mark notification

- (void)vmsDataLoaded:(NSNotification*)notification {
	[self.statisticsView.tableView reloadData];
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
			if ( record.type == VMPReportRecordType_part ) {
				double s = [record.sojourn doubleValue];
				if ( s ) return [NSString stringWithFormat:@"%.2f",s];
				break;
			} else {
				return record.exitParts;
			}
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
	
	VMPRecordCell *cell = recordCell_defaultCell_static_;
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
	return cell;
}

/*
 
		select row
 
 */
- (void)selectRow:(NSInteger)row {
	VMPReportRecord *record = [self recordForRow:row];
	[self addHistory:record.ident];
	[self.recordDetailPopover setRecordId:record.ident routeData:_routesForFragmentId];
	[self.recordDetailPopover setSojourn:[_sojournDataForPart item:record.ident]];
	self.recordDetailPopover.popoverDelegate = self;
	
	NSRect rect = [self.statisticsView.tableView rectOfRow:row];
	[self.recordDetailPopover showRelativeToRect:rect
										  ofView:self.statisticsView.tableView
								   preferredEdge:NSMaxXEdge];
	
	if (record && record.ident.length > 2)
		[VMPNotificationCenter postNotificationName:VMPNotificationFragmentSelected
											 object:self
										   userInfo:@{@"id":record.ident}];
}




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
		NSInteger sel = self.statisticsView.tableView.selectedRow;
		
		[self.statisticsView.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:found] byExtendingSelection:NO];
		[self.statisticsView.tableView scrollRowToVisible:found + (( sel < found ) ? 3 : -3 ) ];
		[self selectRow:found];
		return YES;
	}
	return NO;
}

- (BOOL)tableView:(NSTableView *)tableView shouldTypeSelectForEvent:(NSEvent *)event
withCurrentSearchString:(NSString *)searchString {
	if ( event.type == NSKeyDown && event.keyCode == kVK_Space ) {
		[self songPlay:self];
		return NO;
	}
	
	if ( [searchString hasPrefix:@" "]) return NO;
	return YES;
}


- (void)tableViewSelectionDidChange:(NSNotification *)notification {
	[self selectRow:self.statisticsView.tableView.selectedRow];
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

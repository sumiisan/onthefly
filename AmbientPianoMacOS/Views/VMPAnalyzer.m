//
//  VMPAnalyzer.m
//  VariableMediaPlayerOSX
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

static NSColor *oliveColor, *teaColor, *mandarineColor;

@implementation VMPAnalyzer 

static VMPAnalyzer		*analyzer_singleton__		= nil;
static VMPRecordCell	*recordCell_defaultCell__	= nil;

static const int	kNumberOfIterationsOfGlobalTraceRoute   =    20;
static const int	kNumberOfIterationsOfPartTraceRoute		=	300;
static const int	kLengthOfGlobalTraceRoute				=  2500;	//
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
	self.entryPoint = nil;
	self.report = nil;
	self.progressWC = nil;
	self.currentPartId = nil;
	self.unresolveables = nil;
	self.history = nil;
	self.countForCueId = nil;
	self.countForPart = nil;
	self.sojournDataForPart = nil;
	self.routesForId = nil;
	self.histograms = nil;	
    [super dealloc];
}

#pragma mark -
#pragma mark menu action

- (IBAction)moveHistoryFromMenu:(id)sender {
	NSMenuItem *i = sender;
	[self moveHistory:(VMInt)i.tag];
}

- (IBAction)performStatistics:(id)sender {
	switch ( ((NSMenuItem *)sender).tag ) {
		case 0: {
			[DEFAULTSONGPLAYER fadeoutAndStop:5.];
			[self routeStatistic:[DEFAULTSONG data:DEFAULTSONG.defaultCueId]
			  numberOfIterations:kNumberOfIterationsOfGlobalTraceRoute
						   until:nil];
			break;
			
		}
		case 1: {
			VMId *partId = [[VMArray arrayWithString:[VMPlayerOSXDelegate singleton].objectBrowserView.lastSelectedId
											 splitBy:@"_"] item:0];
			VMData *entrySelector = [DEFAULTSONG data:[partId stringByAppendingString:@"_sel"]];
			if (entrySelector) {
				[self routeStatistic:entrySelector numberOfIterations:kNumberOfIterationsOfPartTraceRoute until:@"exit-part"];
			}
			break;
		}
		default:
			break;
	}
}

- (void)updateGraphView {
	[self.countHistogramView setData:[self.histograms item:@"count"] numberOfBins:0];
	[self.countHistogramView setTitle:@"number of playback times / audioCue"];
	
	[self.durationHistogramView setData:[self.histograms item:@"duration"] numberOfBins:0];
	[self.durationHistogramView setTitle:@"accumulated duration / audioCue"];
	
	[self.varietyHistogramView setData:[self.histograms item:@"variety"] numberOfBins:0];
	[self.varietyHistogramView setTitle:@"variety (acc. duration / num of ac) / part"];
	
	VMArray *unreacheables  = [self.report item:@"unreachableAudioCues"];
	VMArray *unresolveables = [self.report item:@"unresolveables"];
	
	self.reportTextView.string = [NSString stringWithFormat:
								  @"-- Report --\n"
								  "%ld unreacheable audio cues (within %d steps):\n  %@\n\n"
								  "%ld unresolveable data:\n  %@\n\n",
								  unreacheables.count,
								  kNumberOfIterationsOfGlobalTraceRoute * kLengthOfGlobalTraceRoute,
								  [unreacheables join:@"\n  "],
								  unresolveables.count,
								  [unresolveables join:@"\n  "]
								  ];
	self.reportTextView.font = [NSFont systemFontOfSize:11];

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

- (BOOL)routeStatistic:(VMCue *)inEntryPoint
	numberOfIterations:(const long)inNumberOfIterations until:(VMString*)exitCondition {
	if ( self.isBusy ) return NO;
	
    _busy = YES;
	self.entryPoint = inEntryPoint;
	self.log = ARInstance(VMLog);
	DEFAULTSONG.log = self.log;
	
	[DEFAULTSONG showReport:NO];
	[DEFAULTSONG setCueId:self.entryPoint.id];
	
    exitWhenPartChanged = ( [exitCondition isEqualToString:@"exit-part" ]);
	self.currentPartId	= inEntryPoint.partId;
    
	
	self.unresolveables		= ARInstance(VMArray);
	self.countForCueId		= ARInstance(VMHash);
	self.countForPart		= ARInstance(VMHash);
	self.sojournDataForPart	= ARInstance(VMHash);
	self.routesForId		= ARInstance(VMHash);
	self.histograms			= ARInstance(VMHash);
	
	sojourn				= 0;
	startIndexOfSojourn	= 0;
    totalAudioCueCount	= 0;
	totalPartCount		= 0;
	numberOfIterations	= inNumberOfIterations;
	iterationsLeft		= numberOfIterations;
    
	[self analyze_proc];
	return YES;
}

/*---------------------------------------------------------------------------------
 
 subs
 
 ----------------------------------------------------------------------------------*/

- (void)addUnresolveable:(VMId*)dataId {
	[self.unresolveables pushUnique:dataId];
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
		[fromHash setItem:VMIntObj([fromHash itemAsInt:from]+1) for:from];
	}
	if ( to ) {
		VMHash *fromHash = [d item:@"to"];
		[fromHash setItem:VMIntObj([fromHash itemAsInt:to]+1) for:to];
	}
}

/*---------------------------------------------------------------------------------
 
 finish analysis
 
 ----------------------------------------------------------------------------------*/

- (void)finishAnalysis {
	VMArray *idList;
	VMHash  *durationForPart = ARInstance(VMHash);
	VMHash *numberOfCuesForPart = ARInstance(VMHash);
	[self.progressWC setProgress:0 ofTotal:0 message:nil window:[VMPlayerOSXDelegate singleton].objectBrowserWindow];

	maxPartCount=maxPartPercent=maxPartDuration=maxCueCount=maxCuePercent=maxCueDuration=maxVariety=0;
	
	//
	// fragments ( audioCue ) report
	//
	VMTime totalDuration = 0;

	idList = [_countForCueId sortedKeys];
	VMArray *cueArray		= ARInstance(VMArray);
	VMArray *durationArray	= ARInstance(VMArray);
	
	for ( VMString *dataId in idList ) {
		VMFloat		count		= [_countForCueId itemAsFloat:dataId];
		VMFloat		percent		= (count*100./(double)totalAudioCueCount);
		VMAudioCue	*ac			= ClassCastIfMatch( [DEFAULTSONG data:dataId], VMAudioCue );
		VMTime		duration	= ( ac ? ac.duration * count : 0 );
		VMId		*partId		= ( ac ? ac.partId : @"?" );
		
		maxCueCount		= MAX( count,		maxCueCount );
		maxCuePercent	= MAX( percent,		maxCuePercent );
		maxCueDuration	= MAX( duration,	maxCueDuration );

		[cueArray push:[[[VMPReportRecord alloc] initWithType:vmpReportRecordType_cue
														   id:dataId
														count:count
													  percent:percent
													 duration:duration  ] autorelease]];
		
		if ( ac ) {
			VMTime	partDuration = [durationForPart itemAsFloat:partId];
			partDuration += duration;
			totalDuration += ac.duration;
			[durationForPart setItem:VMFloatObj(partDuration) for:partId];
			[numberOfCuesForPart setItem:VMIntObj([numberOfCuesForPart itemAsInt:partId] +1) for:partId];
			[durationArray push:VMFloatObj(duration)];
		}
	}
	
	//
	// part report
	//
	idList = [_countForPart sortedKeys];
	VMArray *partsArray = ARInstance(VMArray);
	VMArray *varietyArray = ARInstance(VMArray);
	for ( VMString *dataId in idList ) {
		VMFloat count		= [_countForPart itemAsFloat:dataId];
		VMInt	dataCount	= [numberOfCuesForPart itemAsInt:dataId];
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
			VMFloat variety = [numberOfCuesForPart itemAsInt:dataId] / duration * 100;
			if ( variety > 100 ) variety = 0;//	ignore too big values.
			r.variety		= VMFloatObj( variety );
			[varietyArray push:r.variety];
			maxVariety		= MAX( variety, maxVariety );
			r.title			= [NSString stringWithFormat:@"%@  (%ld cues)",dataId, dataCount ];
		}
		[partsArray push:r];
	}
	
	[DEFAULTSONG showReport:YES];
	
	
	//
	// histograms
	//
	[self.histograms setItem:[_countForCueId values] for:@"count"];
	[self.histograms setItem:durationArray for:@"duration"];
	[self.histograms setItem:varietyArray for:@"variety"];

	//
	// unreacheables
	//
	VMArray *unreacheableAC = ARInstance(VMArray);
	int totalAcCount=0;
	
	VMArray *allIdArray = [DEFAULTSONG.songData sortedKeys];
	for( VMId *dataId in allIdArray ) {
		VMData *d = [DEFAULTSONG.songData item:dataId];
		if ( d.type == vmObjectType_audioCue ) {
			id c = [_countForCueId item:dataId];
			++totalAcCount;
			if ( !c ) [unreacheableAC push:dataId];
		}
	}

	//
	// make report
	//
	self.report = [VMHash hashWithDictionary:
				   @{
				   @"cues":cueArray,
				   @"parts":partsArray,
				   @"totalDuration":VMFloatObj(totalDuration),
				   @"unreachableAudioCues":unreacheableAC,
				   @"unresolveables":self.unresolveables,
				   @"cuemax":[VMHash hashWithDictionary:
							  @{@"count":@(maxCueCount), @"percent":@(maxCuePercent), @"duration":@(maxCueDuration)}],
				   @"partmax":[VMHash hashWithDictionary:
							   @{@"count":@(maxPartCount), @"percent":@(maxPartPercent), @"duration":@(maxPartDuration)}]
				   }];
	self.reportWindow.isVisible = YES;
	[self.reportWindow makeKeyAndOrderFront:self];
	[self.statisticsView.reportView reloadData];
	
	//
	// history
	//

	self.history = ARInstance(VMArray);
	self.historyPosition = 0;
	
	//	log
	DEFAULTSONG.log = ARInstance(VMLog);	//	clear song log.

	//
	// statistics view
	//
	[self.statisticsView setInfoText: [NSString stringWithFormat:@"%ld parts / %ld audio cues / total %2d:%2d'%2.2f",
									   partsArray.count, cueArray.count,
									   ((int)totalDuration)/3600, ((int)totalDuration/60)%60, fmod(totalDuration, 60)
									   ]];

	[self.statisticsView updateButtonStates];
	[self.statisticsView.reportView selectColumnIndexes:[NSIndexSet indexSetWithIndex:0]
								   byExtendingSelection:NO];
	
	[self updateGraphView];
	
	[self.delegate analysisFinished: self.report];
	
    _busy = NO;
}

- (void)analyze_proc {
	[DEFAULTSONG setCueId:self.entryPoint.id];
	VMId *lastCueId = nil;
	
    for ( long j  = ( exitWhenPartChanged ? kLengthOfPartTraceRoute : kLengthOfGlobalTraceRoute ) ; j; --j) {
        VMAudioCue *ac = [DEFAULTSONG nextAudioCue];
        if( ! ac ) {
		//	ac = [DEFAULTSONG nextAudioCue];	//debug
			NSLog(@"------ call stack ------\n%@",[DEFAULTSONG callStackInfo]);

            [_countForCueId setItem:VMIntObj([_countForCueId itemAsInt:@"unresolved"] +1) for:@"unresolved"];
			[self incrementRouteForId:@"unresolved" from:lastCueId to:nil];
			[self incrementRouteForId:lastCueId from:nil to:@"unresolved"];
            break;
        }
		
		++sojourn;
		
		//	route
		if ( lastCueId ) {
			[self incrementRouteForId:lastCueId from:nil to:ac.id];
			[self incrementRouteForId:ac.id from:lastCueId to:nil];
		}

        if ( exitWhenPartChanged ) {
            if ( ! [ac.partId isEqualToString: self.currentPartId ] ) {
                VMInt c = [_countForPart itemAsInt:ac.partId];
                [_countForPart setItem:VMIntObj(c+1) for:ac.partId];
				[self pushSojournForPart:ac.partId length:sojourn startIndexInLog:startIndexOfSojourn];
				[self incrementRouteForId:ac.partId from:lastCueId to:ac.cueId];
				sojourn = 0;
				startIndexOfSojourn = [self.log nextIndex];
                ++totalPartCount;
                break;
            }
        } else {
            VMInt c = [_countForPart itemAsInt:ac.partId];
            [_countForPart setItem:VMIntObj(c+1) for:ac.partId];
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
        
        [_countForCueId setItem:VMIntObj([_countForCueId itemAsInt:ac.id]+1) for:ac.id];
		
		

        //	simulate fire
        [ac interpreteInstructionsWithAction:vmAction_play];
        ++totalAudioCueCount;
		lastCueId = ac.cueId;
	
    }
	[self.progressWC setProgress:(double)(numberOfIterations - iterationsLeft)
						 ofTotal:(double)numberOfIterations message:@"Analyzing:"
						  window:[VMPlayerOSXDelegate singleton].objectBrowserWindow];
	if ( --iterationsLeft > 0 ) {
		[self performSelector:@selector(analyze_proc) withObject:nil afterDelay:0.005];
	} else {
		[self finishAnalysis];
	}
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
	return [(VMArray*)[self.report item:@"cues"] count] + [(VMArray*)[self.report item:@"parts"] count];
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
		VMArray *cues  = [self.report item:@"cues"];
		return [cues item:(VMInt)row - partsCount];
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
			ratio = cell.ratio = [record.percent doubleValue] / ( record.type == vmpReportRecordType_cue ? maxCuePercent : maxPartPercent );
			cell.barColor = record.type == vmpReportRecordType_cue
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
			ratio = cell.ratio = [record.duration doubleValue] /( record.type == vmpReportRecordType_cue ? maxCueDuration : maxPartDuration );
			cell.barColor = record.type == vmpReportRecordType_cue
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
			ratio = cell.ratio = [record.variety doubleValue] / ( record.type == vmpReportRecordType_cue ? 1 : maxVariety );
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
		[DEFAULTSONGPLAYER startWithCueId:[self.history item:self.historyPosition]];
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
	VMArray *cues  = [self.report item:@"cues"];
	
	NSArray *desc = [tableView sortDescriptors];
	
	[parts.array sortUsingDescriptors:desc];
	[cues. array sortUsingDescriptors:desc];
	[tableView reloadData];
	
	[self moveHistory:0];
}

@end

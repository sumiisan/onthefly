//
//  VMPAnalyzer.h
//  VariableMediaPlayerOSX
//
//  Created by  on 13/02/26.
//  Copyright (c) 2013 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "VMSong.h"
#import "VMPRecordDetailPopover.h"


#define DEFAULTANALYZER [VMPAnalyzer defaultAnalyzer]
#import "VMPProgressWindowController.h"

/*
 
	delegate protocol
 
 */
@protocol VMPAnalyzerDelegate <NSObject,NSTableViewDataSource,NSTableViewDelegate>
- (void)analysisFinished:(VMHash*)report;
@end


typedef enum {
	vmpReportRecordType_cue,
	VMPReportRecordType_part
} VMPReportRecordType;

/*
 
	report record
 
 */
@interface VMPReportRecord : NSObject
@property (nonatomic,retain) NSString	*ident;
@property (nonatomic,retain) NSString	*title;
@property (nonatomic,retain) NSNumber	*count;
@property (nonatomic,retain) NSNumber	*percent;
@property (nonatomic,retain) NSNumber	*duration;
@property (nonatomic,retain) NSNumber	*variety;
@property (nonatomic,retain) NSNumber	*sojourn;
@property (nonatomic)		 VMPReportRecordType type;
- (id)initWithType:(VMPReportRecordType)type id:(VMId*)inId count:(int)inCount percent:(double)inPercent duration:(double)inDuration;

@end

/*

	statistics view
 
 */

@interface VMPStatisticsView :  NSView

- (void)updateButtonStates;
- (void)setInfoText:(VMString*)infoText;
- (IBAction)clickOnRow:(id)sender;
- (IBAction)clickOnButton:(id)sender;

@property (assign)	IBOutlet	NSTableView *reportView;

@end



/*
 
	the analyzer
 
 */
@interface VMPAnalyzer : NSObject <VMPProgressWindowControllerDelegate, VMPRecordDetailPopoverDelegate> {
    long        totalAudioCueCount;
    long        totalPartCount;
    long        numberOfIterations;
    long        iterationsLeft;
	BOOL        exitWhenPartChanged;
	long		maxPartCount,maxCueCount;
	VMInt		sojourn;
	VMInt		startIndexOfSojourn;
//	VMString	*currentPartId;
	VMFloat		maxPartPercent,maxPartDuration;
	VMFloat		maxCuePercent,maxCueDuration;
	VMFloat		maxVariety;
}

+ (VMPAnalyzer*)defaultAnalyzer;
//- (void)showProgress:(double)current ofTotal:(double)total message:(VMString*)message;
- (BOOL)routeStatistic:(VMData*)entryPoint numberOfIterations:(const long)numberOfIterations until:(VMString*)exitCondition;
- (void)addUnresolveable:(VMId*)dataId;
- (void)selectRow:(NSInteger)row;
- (VMPReportRecord *)recordForRow:(NSInteger)row;
- (void)moveHistory:(VMInt)vector;
- (IBAction)moveHistoryFromMenu:(id)sender;
- (IBAction)performStatistics:(id)sender;
- (IBAction)openGraphView:(id)sender;

@property (nonatomic,retain)	VMArray		*history;
@property (nonatomic,assign)	VMInt		historyPosition;
@property (assign)				id			<VMPAnalyzerDelegate>	delegate;
@property (retain)				VMLog		*log;


/*---------------------------------------------------------------------------------
 
 view related
 
 ----------------------------------------------------------------------------------*/

//	statistics window
@property (assign)	IBOutlet	NSWindow					*reportWindow;
@property (assign)	IBOutlet	VMPStatisticsView			*statisticsView;

//	record detail popover
@property (assign)	IBOutlet	VMPRecordDetailPopover		*recordDetailPopover;

//	statistics graph
@property (assign)	IBOutlet	NSPanel						*statGraphPane;
@property (assign)	IBOutlet	VMPHistogramView			*countHistogramView;
@property (assign)	IBOutlet	VMPHistogramView			*durationHistogramView;
@property (assign)	IBOutlet	VMPHistogramView			*varietyHistogramView;
@property (assign)	IBOutlet	NSTextView					*reportTextView;

//	progress bar
@property (nonatomic, retain)	VMPProgressWindowController *progressWC;

@end

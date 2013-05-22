//
//  VMPAnalyzer.h
//  OnTheFlyOSX
//
//  Created by  on 13/02/26.
//  Copyright (c) 2013 sumiisan. All rights reserved.
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
	vmpReportRecordType_frag,
	VMPReportRecordType_part
} VMPReportRecordType;

/*
 
	report record
 
 */
@interface VMPReportRecord : NSObject
@property (nonatomic,VMStrong) NSString	*ident;
@property (nonatomic,VMStrong) NSString	*title;
@property (nonatomic,VMStrong) NSNumber	*count;
@property (nonatomic,VMStrong) NSNumber	*percent;
@property (nonatomic,VMStrong) NSNumber	*duration;
@property (nonatomic,VMStrong) NSNumber	*variety;
@property (nonatomic,VMStrong) NSNumber	*sojourn;

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

@property (nonatomic, VMWeak) IBOutlet NSSegmentedControl *historyArrowButtons;

//	defaults first responder
- (IBAction)moveHistoryBack:(id)sender;
- (IBAction)moveHistoryForward:(id)sender;

@property (nonatomic, VMWeak) IBOutlet	NSTableView *tableView;

@end



/*
 
	the analyzer
 
 */
@interface VMPAnalyzer : NSObject <VMPProgressWindowControllerDelegate, VMPRecordDetailPopoverDelegate> {
    long        totalAudioFragmentCount;
    long        totalPartCount;
    long        numberOfIterations;
    long        iterationsLeft;
	BOOL        exitWhenPartChanged;
	long		maxPartCount,maxFragmentCount;
	VMInt		sojourn;
	VMInt		startIndexOfSojourn;
	VMTime		totalDuration;
	VMFloat		maxPartPercent,maxPartDuration;
	VMFloat		maxFragmentPercent,maxFragmentDuration;
	VMFloat		maxVariety;
}

+ (VMPAnalyzer*)defaultAnalyzer;

//	accessor
- (void)selectRow:(NSInteger)row;
- (VMPReportRecord *)recordForRow:(NSInteger)row;

- (VMSelector*)makeSelectorFromStatistics:(VMId*)selectorId;

//	history
- (void)moveHistory:(VMInt)vector;

//	called back from VMSelector
- (void)addUnresolveable:(id)dataId;

//	utility
- (VMHash*)collectReferrer;

//	actions
- (IBAction)performStatistics:(id)sender;
- (IBAction)openGraphView:(id)sender;

@property (nonatomic, VMStrong)	VMHistory	*history;
@property (unsafe_unretained)	id			<VMPAnalyzerDelegate>	delegate;
@property (nonatomic, VMStrong)	VMLog		*log;
@property (nonatomic, VMStrong)	VMHash		*report;


/*---------------------------------------------------------------------------------
 
 view related
 
 ----------------------------------------------------------------------------------*/

//	statistics window
@property (VMWeak)	IBOutlet	NSWindow					*statisticsWindow;
@property (VMWeak)	IBOutlet	VMPStatisticsView			*statisticsView;

//	record detail popover
@property (VMWeak)	IBOutlet	VMPRecordDetailPopover		*recordDetailPopover;

//	statistics graph
@property (VMWeak)	IBOutlet	NSPanel						*statOverviewGraphPanel;
@property (VMWeak)	IBOutlet	VMPHistogramView			*countHistogramView;
@property (VMWeak)	IBOutlet	VMPHistogramView			*durationHistogramView;
@property (VMWeak)	IBOutlet	VMPHistogramView			*varietyHistogramView;

//	progress bar
@property (nonatomic, VMStrong)	VMPProgressWindowController *progressWC;

@end

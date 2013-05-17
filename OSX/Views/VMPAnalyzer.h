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

@property (nonatomic, assign) IBOutlet NSSegmentedControl *historyArrowButtons;

//	defaults first responder
- (IBAction)moveHistoryBack:(id)sender;
- (IBAction)moveHistoryForward:(id)sender;

@property (assign)	IBOutlet	NSTableView *reportView;

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
- (void)moveHistory:(VMInt)vector;

//	called back from VMSelector
- (void)addUnresolveable:(id)dataId;

//	utility
- (VMHash*)collectReferrer;

//	actions
- (IBAction)performStatistics:(id)sender;
- (IBAction)openGraphView:(id)sender;

@property (nonatomic,retain)	VMHistory	*history;
@property (assign)				id			<VMPAnalyzerDelegate>	delegate;
@property (retain)				VMLog		*log;
@property (nonatomic,retain)	VMHash		*report;


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

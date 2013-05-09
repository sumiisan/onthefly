//
//  VMPRecordDetailPopover.h
//  VARI
//
//  Created by sumiisan on 2013/03/25.
//
//


#import <Cocoa/Cocoa.h>
#import "VMPrimitives.h"
#import "VMPHistogramView.h"

enum {
	vmRouteDirection_from = 0,
	vmRouteDirection_to
};
/*
 
 record cell
 
 */
@interface VMPRecordCell : NSTextFieldCell

@property (nonatomic)			VMFloat		ratio;
@property (nonatomic, retain)	NSColor		*barColor;
@end


/*

 record detail
 
 */

@protocol VMPRecordDetailPopoverDelegate <NSObject>
- (BOOL)itemSelectedWithId:(VMId*)itemId;
@end

@interface VMPRecordDetailPopover : NSPopover <NSTableViewDataSource,NSTableViewDelegate> {
	VMInt		maxCount;
	VMInt		total;
}
@property (assign) IBOutlet NSTableView			*detailTable;
@property (assign) IBOutlet NSScrollView		*detailScrollView;
@property (assign) IBOutlet NSSegmentedControl	*filterChooser;
@property (assign) IBOutlet	VMPHistogramView	*histogramView;

@property (nonatomic,retain)	VMArray *currentRouteList;
@property (nonatomic,retain)	VMHash  *routeListByCategory;
@property (nonatomic,retain)	VMArray *sojournData;
@property (nonatomic,assign)	id <VMPRecordDetailPopoverDelegate> popoverDelegate;

- (void)setRecordId:(VMId*)recordId routeData:(VMHash*)routeData;
- (void)setSojourn:(VMArray*)sojournArray;
- (IBAction)clickOnRow:(id)sender;
- (IBAction)filterSelected:(id)sender;
- (IBAction)locateLongestSojournInLog:(id)sender;

@end

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
@property (nonatomic, VMStrong)	NSColor		*barColor;
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
@property (nonatomic, VMWeak) IBOutlet NSTableView			*detailTable;
@property (nonatomic, VMWeak) IBOutlet NSScrollView		*detailScrollView;
@property (nonatomic, VMWeak) IBOutlet NSSegmentedControl	*filterChooser;
@property (nonatomic, VMWeak) IBOutlet	VMPHistogramView	*histogramView;

@property (nonatomic, VMStrong)	VMArray *currentRouteList;
@property (nonatomic, VMStrong)	VMHash  *routeListByCategory;
@property (nonatomic, VMStrong)	VMArray *sojournData;
@property (nonatomic, unsafe_unretained)	id <VMPRecordDetailPopoverDelegate> popoverDelegate;

- (void)setRecordId:(VMId*)recordId routeData:(VMHash*)routeData;
- (void)setSojourn:(VMArray*)sojournArray;
- (IBAction)clickOnRow:(id)sender;
- (IBAction)filterSelected:(id)sender;
- (IBAction)locateLongestSojournInLog:(id)sender;

@end

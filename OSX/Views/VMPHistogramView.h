//
//  VMPHistogramView.h
//  OnTheFly
//
//  Created by sumiisan on 2013/04/20.
//
//

#import <Cocoa/Cocoa.h>
#import "VMPCanvas.h"
#import "VMPrimitives.h"

typedef enum {
	VMPHistogramType_linear = 0,
	VMPHistogramType_log,
	VMPHistogramType_log10,
	VMPHistogramType_sqrt,
} VMPHistogramType;

@interface VMPHistogramView : VMPCanvas {
	VMArray *_data;
	VMFloat	mean;
	VMFloat	sd;
	VMRange range;
}

- (void)setData:(VMArray *)data numberOfBins:(VMInt)numberOfBins;
- (void)setTitle:(NSString *)title;

@property (nonatomic, retain)	VMArray			*data;
@property (nonatomic, retain)	VMString		*title;
@property (nonatomic)			VMPHistogramType histogramType;
@end

//
//  VMPHistogramView.m
//  OnTheFly
//
//  Created by sumiisan on 2013/04/20.
//
//

#import "VMPHistogramView.h"
#import "VMPMacros.h"

@implementation VMPHistogramView

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
		
        // Initialization code here.
		NSTextField *t;
		CGFloat textFieldWidth = 50;
		CGFloat areaWidth = frame.size.width - textFieldWidth -2;
		CGFloat interval = areaWidth / 2;
		NSArray *align = @[	@( NSLeftTextAlignment ),
							@( NSCenterTextAlignment ),
							@( NSRightTextAlignment ),
							@( NSCenterTextAlignment ) ];
		
		for( int i = 0; i < 4; ++i ) {
			t = [[NSTextField alloc] initWithFrame:CGRectMake( i * interval +1, 1, textFieldWidth, 12)];
			t.tag = 'txf0' + i;
			t.editable = NO;
			t.drawsBackground = NO;//( i == 3 );
			t.bordered = NO;	
			t.font = [NSFont systemFontOfSize:9];
			t.textColor = [NSColor colorWithCalibratedWhite:0.1 alpha:1.];
			t.alignment = [align[i] intValue];
			
			
			[self addSubview:t];
			Release( t );
		}
		
		NSButton *b = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, frame.size.width, frame.size.height)];
		b.target = self;
		b.action = @selector(changeHistogramType:);
		b.transparent = YES;
		
		[self addSubview:b];
    }
    
    return self;
}

- (void)dealloc {
	VMNullify(data);
	Release( _title );
	Dealloc( super );;
}

- (void)setData:(VMArray *)data numberOfBins:(VMInt)numberOfBins {
	if ( numberOfBins == 0 ) numberOfBins = sqrt(data.count);
	self.data = [data histogramWithBins:numberOfBins normalize:YES];
	range = [data valueRange];
	mean = [data mean];
	sd = [data standardDeviation];
	
	((NSTextField*)[self viewWithTag:'txf0']).stringValue = [NSString stringWithFormat:@"%.1f", range.minimum];
	((NSTextField*)[self viewWithTag:'txf1']).stringValue = [NSString stringWithFormat:@"%.1f", ( range.minimum + range.maximum ) * 0.5 ];
	((NSTextField*)[self viewWithTag:'txf2']).stringValue = [NSString stringWithFormat:@"%.1f", range.maximum ];
	
	[self setNeedsDisplay:YES];
}


- (void)setTitle:(NSString *)title {
	if( title != _title ) {	//	because we call this function internally
		Release( _title );
		_title = Retain( title );
	}
	if ( ! title ) title = @"";
	NSTextField *titleField = [self viewWithTag:'txf3'];
	VMArray *histTypeString = [VMArray arrayWithArray:@[@" (linear)",@" (log e)",@" (log 10)",@" (sqrt)"]];
	titleField.frame = CGRectMake(2, self.frame.size.height - 13, self.frame.size.width - 4, 12);
	titleField.stringValue = [title stringByAppendingString:[ histTypeString item: self.histogramType]];
	titleField.backgroundColor = [NSColor colorWithCalibratedRed:.9 green:.9 blue:.9 alpha:.5];
}

- (void)changeHistogramType:(id)sender {
	self.histogramType = ( self.histogramType +1 ) % 3;	//	usually we don't need sqrt
	self.title = _title;
	self.needsDisplay = YES;
}

- (void)drawRect:(NSRect)dirtyRect {
	const VMFloat e3m1	= pow( M_E, 3 ) -1;
	//
	//	setup transformer for histogram types
	//
	VMFloat(^transform)(VMFloat value);
	switch ( self.histogramType ) {
		case VMPHistogramType_linear:
			transform = ^(VMFloat value ) {	return value;	};
			break;
		case VMPHistogramType_log:
			transform = ^(VMFloat value ) {	return log( value * e3m1 + 1. ) / 3.; };
			break;
		case VMPHistogramType_log10:
			transform = ^(VMFloat value ) {	return log10(value * 999. + 1. ) / 3; };
			break;
		case VMPHistogramType_sqrt:
			transform = ^(VMFloat value ) {	return sqrt(value); };
			break;
	}

	
	CGFloat titleTextHeight	= 12;
	CGFloat valueTextHeight = 9;
	CGFloat margin			= 2;
	CGFloat graphLeft		= margin;
	
	CGFloat	graphWidth		= self.frame.size.width - margin*2;
	CGFloat graphHeight		= self.frame.size.height - titleTextHeight - valueTextHeight;
	CGFloat graphBase		= valueTextHeight + graphHeight;
	
	[self setCanvas];
	
	
	//
	// baackground
	//
	[self setLineWidth:1.];
	[self setColor_r:.9 g:.9 b:.9];
	NSRectFill(dirtyRect);
	
	//
	//	sd
	//
	VMFloat height      = graphHeight - 4;
	VMFloat valPerPix   = graphWidth / ( range.maximum - range.minimum );
	
	[self setColor_r:1. g:1. b:.8];
	[self fillRect_x:valPerPix * ( mean - sd - range.minimum) + graphLeft
				   y:graphBase
				   w:valPerPix * ( sd * 2 )
				   h:-height ];

	//
	//	mean line
	//
	[self setLineWidth:1.];
	[self setColor_r:1. g:.3 b:.3];
	CGFloat meanx = valPerPix * ( mean - range.minimum ) + graphLeft;
	[self drawLine_x0:meanx y0:graphBase
				   x1:meanx y1:1];

	//
	//	guide lines
	//
	[self setLineWidth:0.1];
	[self setColor_r:.3 g:.3 b:.6];
	CGFloat center = (int)(self.frame.size.width * 0.5 + graphLeft) + 0.5;
	[self drawLine_x0:center y0:graphBase
				   x1:center y1:self.frame.size.height];
	for ( VMFloat i = 0.0; i <= 1; i += 0.25 ) {
		VMFloat y = graphBase - (int)(transform(i) * height) + 0.5;
		[self drawLine_x0:graphLeft y0:y x1:graphLeft+graphWidth y1:y];
	}
	
	
	//
	//	bins
	//
	VMInt	bins		= _data.count;
	CGFloat binWidth	= graphWidth / bins;
	VMFloat binMargin	= ( binWidth > 2. ? 1 : 0 );
	VMFloat barWidth	= binWidth - binMargin;
	VMFloat ht			= self.histogramType * 0.05;
	for ( int i = 0; i < bins; ++i ) {
		VMFloat v = [_data itemAsFloat:i];
		
		VMFloat h = transform(v) * height;
		[self setColor_r:0.4 + ht * 1.67
					   g:0.6 - ht - v * 0.5
					   b:1.0 - ht ];
		[self fillRect_x:i * binWidth + 2
					   y:graphBase
					   w:barWidth
					   h:-h
		 ];
	}
	
	//	frame
	[self setColor_r:.4 g:.4 b:.6];
	[self setLineWidth:1.];
	[self drawRect_x:0.5 y:0.5 w:self.frame.size.width-1 h:graphBase-1];

}

@end

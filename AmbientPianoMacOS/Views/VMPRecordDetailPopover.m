//
//  VMPRecordDetailPopover.m
//  VARI
//
//  Created by sumiisan on 2013/03/25.
//
//

#import "VMPRecordDetailPopover.h"
#import "VMPMacros.h"
#import "VMPlayerOSXDelegate.h"

static VMPRecordCell *recordCell_defaultCell__ = nil;


static NSColor *limeColor = nil, *skyColor = nil, *limeColor2 = nil, *skyColor2 = nil;

/*---------------------------------------------------------------------------------
 
 VMPRecordCell
 
 ----------------------------------------------------------------------------------*/

#pragma mark -
#pragma mark VMPRecordCell

@implementation VMPRecordCell
- (id)copyWithZone:(NSZone *)zone {
	VMPRecordCell *newCell = [[VMPRecordCell alloc] initTextCell:self.stringValue];
	newCell.ratio = self.ratio;
	newCell.barColor = self.barColor;
	return newCell;
}

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
	VMFloat ratio = self.ratio;
	if ( ratio > 0 ) {
		NSRect r = NSMakeRect(	cellFrame.origin.x, cellFrame.origin.y,
								cellFrame.size.width * ratio, cellFrame.size.height);
		[(self.barColor ? self.barColor : limeColor) set];
		NSRectFill(r);
	}
	[super drawInteriorWithFrame:cellFrame inView:controlView];
}

- (void)dealloc {
	self.barColor = nil;
	[super dealloc];
}
@end

/*---------------------------------------------------------------------------------
 
 VMPRecordDetailPopover
 
 ----------------------------------------------------------------------------------*/

#pragma mark -
#pragma mark VMPRecordDetailPopover

@implementation VMPRecordDetailPopover

static VMArray *colorForCategory = nil;
static VMArray *indicatorForCategory = nil;

- (id)initWithCoder:(NSCoder *)aDecoder {
	if ( aDecoder )
		self = [super initWithCoder:aDecoder];
	else
		self = [super init];
	
	if (self) {
		recordCell_defaultCell__ = [[VMPRecordCell alloc] initTextCell:@""];
		if( ! limeColor ) {
			skyColor2		= [[NSColor colorWithCalibratedRed:0.5 green:0.4 blue:0.9 alpha:0.9] retain];
			skyColor		= [[NSColor colorWithCalibratedRed:0.3 green:0.6 blue:0.9 alpha:0.9] retain];
			limeColor		= [[NSColor colorWithCalibratedRed:0.7 green:0.6 blue:0.1 alpha:0.9] retain];
			limeColor2		= [[NSColor colorWithCalibratedRed:0.9 green:0.4 blue:0.1 alpha:0.9] retain];
			colorForCategory = [[VMArray arrayWithObjects:skyColor2,skyColor,limeColor,limeColor2,nil] retain];
		}
		if ( ! indicatorForCategory ) {
			indicatorForCategory = [[VMArray arrayWithObjects:@"⇉⦿",@"→⦿",@"⦿→",@"⦿⇉"] retain];
		}
	}

	return self;
}
- (id)init {
	self = [self initWithCoder:nil];
	return self;
}

- (void)dealloc {
	self.currentRouteList = nil;
	self.routeListByCategory = nil;
	self.sojournData = nil;
	[super dealloc];
}

- (void)awakeFromNib {
	for( VMInt i = 0; i < 4; ++i ) {
		[self.filterChooser setLabel:[indicatorForCategory item:i] forSegment:i];
	}
	self.histogramView.title = @"sojourn";
	self.histogramView.hidden = YES;

}

- (VMInt)pushRoutes:(VMHash*)data
		  intoArray:(VMArray*)array
		   category:(VMInt)category {
	VMArray *dataIds = [data sortedKeys];
	VMInt sum = 0;
	
    for ( VMId *dataId in dataIds ) {
		VMInt c = [data itemAsInt:dataId];
		sum += c;
		if ( c > maxCount ) maxCount = c;
		[array push:[VMHash hashWithDictionary: @{
					 @"id":dataId,
					 @"count":@(c),
					 @"category":@(category)
					 }	]];
	}
	return sum;
}

- (void)collectSecondaryRoutesOfRoutes:(VMHash*)rootRouteData
							  fromData:(VMHash*)globalRouteData
							  intoHash:(VMHash*)secondaryRouteData
							 direction:(VMString*)direction {
	
	VMHash *dirRouteData = [rootRouteData item:direction];
	VMArray *dirRouteIds = [dirRouteData keys];
	
	for( VMId *routeId in dirRouteIds ) {
		VMFloat rcFactor = [dirRouteData itemAsInt:routeId];// / (VMFloat)total;
		//NSLog(@"--begin add sub routes for:%@ (%.2f%%)",routeId, rcFactor );
		VMHash  *subRouteData = [((VMHash*)[globalRouteData item:routeId]) item:direction];
		VMFloat subTotal = [[subRouteData values] sum];
		VMArray *secondaryRouteIds = [subRouteData keys];
		for ( VMId *routeId2 in secondaryRouteIds ) {
			VMFloat c = [subRouteData itemAsInt:routeId2] / subTotal * rcFactor;
			[secondaryRouteData add:c ontoItem:routeId2];
			//NSLog(@"-add subroute:%@ (%.2f%%)",routeId2,c);
		}
	}
	
}

- (void)collectData:(VMId*)rootId routeData:(VMHash *)globalRouteData {
	VMHash *rootRouteData = [globalRouteData item:rootId];
	VMHash *from_2nd = ARInstance(VMHash);
	VMHash *to_2nd = ARInstance(VMHash);
	
	
	//	calculate total first.
	total =
	[self pushRoutes:[rootRouteData item:@"from"]
		   intoArray:[self.routeListByCategory item:@"from_p"]
			category:1];
	
	[self pushRoutes:[rootRouteData item:@"to"]
		   intoArray:[self.routeListByCategory item:@"to_p"]
			category:2];
	
	if (total==0)return;	//	unable to calculate secondary routes
	
	[self collectSecondaryRoutesOfRoutes:rootRouteData
								fromData:globalRouteData
								intoHash:from_2nd
							   direction:@"from"];
	
	[self collectSecondaryRoutesOfRoutes:rootRouteData
								fromData:globalRouteData
								intoHash:to_2nd
							   direction:@"to"];

	[self pushRoutes:from_2nd
		   intoArray:[self.routeListByCategory item:@"from_s"]
			category:0];
	
	[self pushRoutes:to_2nd
		   intoArray:[self.routeListByCategory item:@"to_s"]
			category:3];
	
}

#pragma mark -
#pragma mark action

- (void)locateLongestSojournInLog:(id)sender {
	VMInt maxLength = 0;
	VMInt maxIndex = 0;
	for ( VMHash *h in self.sojournData ) {
		VMInt len = [h itemAsFloat:@"length"];
		if ( len > maxLength ) {
			maxLength = len;
			maxIndex = [h itemAsInt:@"position"];
		}
	}
	[[VMPlayerOSXDelegate singleton].logView locateLogWithIndex:maxIndex ofSource:VMPLogViewSource_Statistics];
}

- (void)filterSelected:(id)sender {
	[self filterCurrentRouteList];
	[self.detailTable reloadData];
}

- (void)filterCurrentRouteList {
	self.currentRouteList = ARInstance(VMArray);
	
	if( [self.filterChooser isSelectedForSegment:0] )
		[self.currentRouteList append:[self.routeListByCategory item:@"from_s"]];

	if( [self.filterChooser isSelectedForSegment:1] )
		[self.currentRouteList append:[self.routeListByCategory item:@"from_p"]];

	if( [self.filterChooser isSelectedForSegment:2] )
		[self.currentRouteList append:[self.routeListByCategory item:@"to_p"]];

	if( [self.filterChooser isSelectedForSegment:3] )
		[self.currentRouteList append:[self.routeListByCategory item:@"to_s"]];
	
}

#pragma mark -
#pragma mark accessor

- (void)setRecordId:(VMId*)recordId routeData:(VMHash*)routeData{
	
	maxCount = 0;
	self.routeListByCategory = [VMHash hashWithDictionary:@{
								@"from_p":ARInstance(VMArray),
								@"to_p"  :ARInstance(VMArray),
								@"from_s":ARInstance(VMArray),
								@"to_s"  :ARInstance(VMArray) } ];
	
	[self collectData:recordId routeData:routeData];
	[self filterCurrentRouteList];
	
	[self.detailTable reloadData];
}

- (void)setSojourn:(VMArray*)sojournArray {
	if (sojournArray) {
		self.sojournData = sojournArray;
		//	get the length
		VMArray *lengthArray = ARInstance(VMArray);
		for( VMHash *h in sojournArray )
			[lengthArray push:[h item:@"length"]];
		
		[self.histogramView setData:lengthArray numberOfBins:0];
		self.histogramView.hidden = NO;
		self.detailScrollView.frame = NSMakeRect(0, 120, 250, 360);
		[self.contentViewController.view addSubview:self.histogramView];
	} else {
		self.histogramView.hidden = YES;
		self.detailScrollView.frame = NSMakeRect(0, 0, 250, 480);
	}
}


#pragma mark -
#pragma mark tableview

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
	return self.currentRouteList.count;
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
	VMHash *h = [self.currentRouteList item:(VMInt)row];
	if (!h) return @"";
	char type = [tableColumn.identifier cStringUsingEncoding:NSASCIIStringEncoding][0];
	
	switch ( type ) {
		case 'i':
			return [h item:@"id"];
			break;
		case 'c': {
			VMInt c = [h itemAsInt:@"count"];
			return [NSString stringWithFormat:@"%ld (%.2f%%)", c, c/(double)total*100.0 ];
			break;
		}
		case 'd':
			return [indicatorForCategory item:[h itemAsInt:@"category"]];
			break;
	}
	return nil;
}

- (NSCell *)tableView:(NSTableView *)tableView dataCellForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
	if( !tableColumn) return nil;
	VMHash *h = [self.currentRouteList item:(VMInt)row];
	char type = [tableColumn.identifier cStringUsingEncoding:NSASCIIStringEncoding][0];
	//if ( type == 'i' ) return [tableColumn dataCellForRow:row];
	
	VMPRecordCell *cell = recordCell_defaultCell__;
	cell.title = [self tableView:tableView objectValueForTableColumn:tableColumn row:row];
	VMInt category = [h itemAsInt:@"category"];
	cell.barColor = [colorForCategory item:category];
	 
	switch (type) {
		case 'd':
			cell.ratio = 1.;
			cell.font = [NSFont fontWithName:@"Apple Symbols" size:16];
			cell.textColor = [NSColor whiteColor];
			break;
		case 'c':
			cell.font = [NSFont systemFontOfSize:11];
			cell.textColor = [NSColor blackColor];
			cell.ratio = [h itemAsInt:@"count"] / (double)maxCount;
			break;
		case 'i':
			cell.font = [NSFont systemFontOfSize:11];
			cell.textColor = ( category == 0 || category == 3 ) ? [NSColor grayColor] : [NSColor controlTextColor];
			cell.ratio = 0;
			break;
	}
	
	return cell;
}

- (IBAction)clickOnRow:(id)sender {
	if( self.popoverDelegate ) {
		NSTableView *tbv = sender;
		VMHash *h = [self.currentRouteList item:(VMInt)tbv.clickedRow];
		if( h ) {
			if ( [self.popoverDelegate itemSelectedWithId:[h item:@"id"]] )
				[tbv deselectAll:self];
		}
	}
}








@end

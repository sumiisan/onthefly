//
//  VMPSelectorEditorViewController.m
//  OnTheFly
//
//  Created by sumiisan on 2013/05/04.
//
//

#import "VMPSelectorEditorViewController.h"

@interface VMPSelectorEditorViewController ()

@end

@implementation VMPSelectorEditorViewController

static VMPSelectorEditorTab defaultTab__ = VMPSelectorEditor_BranchTab;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}

- (void)dealloc {
	self.selector = nil;
	[super dealloc];
}

- (void)setData:(id)data {
	self.selector = data;
	[self.tabView selectTabViewItemAtIndex:defaultTab__];
	[self selectTabView:defaultTab__];
}

#pragma mark -
#pragma mark action

- (IBAction)clickOnRow:(id)sender {
	
}

- (IBAction)clickOnCueCell:(id)sender {
	
}

#pragma mark -
#pragma mark tableview

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
	return self.selector.length;
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
	if( !tableColumn ) return nil;
	if( [tableColumn.identifier hasPrefix:@"Ta"] ) {
		//	target
	}
	
	if ([tableColumn.identifier hasPrefix:@"Sc"]) {
		//	score
	}
	return @"dummy";
}

#pragma mark -
#pragma mark tabview

- (void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem {
	VMPSelectorEditorTab tab=0;
	if( [tabViewItem.identifier hasPrefix:@"Ed"] ) {
		//	editor
		tab = VMPSelectorEditor_EditorTab;
	}
	if( [tabViewItem.identifier hasPrefix:@"Br"] ) {
		//	branch
		tab = VMPSelectorEditor_BranchTab;
	}
	if( [tabViewItem.identifier hasPrefix:@"Fr"] ) {
		//	frame
		tab = VMPSelectorEditor_FrameTab;
	}
	[self selectTabView:tab];
}

- (void)selectTabView:(VMPSelectorEditorTab)tab {
	defaultTab__ = tab;
	switch (tab) {
			
		case VMPSelectorEditor_EditorTab: {
			[self.chanceTableView reloadData];
			break;
		}
			
		case VMPSelectorEditor_BranchTab:
		case VMPSelectorEditor_FrameTab: {
			VMPGraph *baseView;
			NSRect baseViewRect, graphRect;
			CGFloat graphWidth;
			
			if (tab==VMPSelectorEditor_BranchTab) {
				baseView			= self.branchView;
				graphWidth			= 2000;
			} else {
				baseView			= self.frameView;
				graphWidth			= (vmpCellWidth + vmpCellMargin) * 15;
			}
			
			baseViewRect		= CGRectMake( 0, 0, graphWidth + 10, baseView.frame.size.height	 );
			graphRect			= CGRectMake( 5, 5, graphWidth, baseViewRect.size.height -10 );
			VMPSelectorGraph *selectorGraph = [[VMPSelectorGraph alloc] initWithFrame:graphRect];
			selectorGraph.frameGraphMode = ( tab == VMPSelectorEditor_FrameTab );
			[selectorGraph setData:self.selector];
			
			[baseView removeAllSubviews];
			baseView.frame = baseViewRect;
			[baseView addSubview:selectorGraph];
			[selectorGraph release];
			
			[self.branchViewScroller scrollPoint:NSMakePoint(0, 0)];
			[self.frameViewScroller scrollPoint:NSMakePoint(0, 0)];
			break;
		}
	}
}

@end

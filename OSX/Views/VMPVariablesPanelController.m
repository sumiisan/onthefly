//
//  VMPVariablesPanelController.m
//  OnTheFly
//
//  Created by sumiisan on 2013/05/02.
//
//

#import "VMPVariablesPanelController.h"
#import "VMPNotification.h"
#import "VMScoreEvaluator.h"
#import "VMSong.h"
#import "VMPMacros.h"

@interface VMPVariablesPanelController ()

@end

@implementation VMPVariablesPanelController

- (id)initWithWindowNibName:(NSString *)windowNibName {
	self = [super initWithWindowNibName:windowNibName];
	[self updateItemsInTable];
	[VMPNotificationCenter addObserver:self
							  selector:@selector(fragSelectionChanged:)
								  name:VMPNotificationFragmentSelected
								object:nil];
	[VMPNotificationCenter addObserver:self
							  selector:@selector(updateTableView:)
								  name:VMPNotificationVariableValueChanged
								object:nil];
	[VMPNotificationCenter addObserver:self
							  selector:@selector(updateTableView:)
								  name:VMPNotificationAudioFragmentFired
								object:nil];
	return self;
}

- (void)dealloc {
    [VMPNotificationCenter removeObserver:self];
	self.selectedFragmentId = nil;
	self.itemsInTable = nil;
	[super dealloc];
}

- (void)fragSelectionChanged:(NSNotification*)notification {
	self.selectedFragmentId = [notification.userInfo objectForKey:@"id"];
	[self updateItemsInTable];
}

- (void)updateTableView:(NSNotification*)notification {
	if( ! tableReloadingScheduled ) {
		tableReloadingScheduled = YES;
		[self updateItemsInTable];
		[self performSelector:@selector(reloadTableAfterDelay:) withObject:nil afterDelay:0.2];	//	do not reload too often.
	}
}

- (void)reloadTableAfterDelay:(id)object {
	[self.tableView reloadData];
	tableReloadingScheduled = NO;
}

- (IBAction)typeSelected:(id)sender {
	[self updateItemsInTable];
}

- (void)pushFunctionIntoTable:(NSString*)functionExpression {
	NSString *expr = [NSString stringWithFormat:functionExpression, self.selectedFragmentId];
	[_itemsInTable push:[VMHash hashWith:@{@"name":expr, @"value":@( [DEFAULTEVALUATOR evaluate:expr ] ) }]];
}

- (void)updateItemsInTable {
	self.itemsInTable = ARInstance(VMArray);
	
	VMHash  *vars  = DEFAULTEVALUATOR.variables;
	VMArray *names = [vars sortedKeys];
	if ( [self.typeSelector isSelectedForSegment:0] ) {
		//	variables
		for( VMString *name in names ) {
			if ( [name hasPrefix:@"@"] ) continue;
			id var = [vars item:name];
			if( var ) [_itemsInTable push:[VMHash hashWith:@{@"name":name,@"value":var}]];
		}
	}
	
	if ( [self.typeSelector isSelectedForSegment:1] ) {
		//	functions
		for( VMString *name in names ) {
			if (! [name hasPrefix:@"@"] ) continue;
			id var = [vars item:name];
			if( var ) [_itemsInTable push:[VMHash hashWith:@{@"name":name,@"value":var}]];
		}
		
		[self pushFunctionIntoTable:@"@F{%@}"];
		[self pushFunctionIntoTable:@"@D{%@}"];
		[self pushFunctionIntoTable:@"@LS"];
		[self pushFunctionIntoTable:@"@LS{%@}"];
		[self pushFunctionIntoTable:@"@LC"];
		[self pushFunctionIntoTable:@"@LC{%@}"];
		[self pushFunctionIntoTable:@"@PT"];
		
	}
	
	if ( [self.typeSelector isSelectedForSegment:2] ) {
		VMData *d = [DEFAULTSONG data:self.selectedFragmentId];
		if ( d.type == vmObjectType_selector || d.type == vmObjectType_sequence ) {
			if (d.type == vmObjectType_sequence ) d = ((VMSequence*)d).subsequent;
			VMArray *history = ((VMSelector*)d).liveData.history;
			int index = 1;
			for( VMString *fragId in history ) {
				[_itemsInTable push:[VMHash hashWith:@{@"name":VMIntObj(index),@"value":fragId}]];
				++index;
			}
		}
	}
	
	[self.tableView reloadData];
}

- (IBAction)expressionEntered:(id)sender {
	
}

#pragma mark -
#pragma mark tableview
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
	return self.itemsInTable.count;
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
	if (!tableColumn)return nil;
	switch ( tableColumn.identifier.intValue ) {
		case 0:
			return [[self.itemsInTable itemAsHash:row] item:@"name"];
			break;
		case 1:
			return [[self.itemsInTable itemAsHash:row] item:@"value"];
			break;
	}
	return nil;
}

@end

//
//  VMPTimeRangeEditorView.m
//  GotchaP
//
//  Created by sumiisan on 2013/04/28.
//
//

#import "VMPTimeRangeEditorView.h"
#import "VMDataTypes.h"

@implementation VMPTimeRangeEditorView

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    return self;
	
}
/*
- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
	return self;
}
*/
- (void)awakeFromNib {
	if(!self.titleLabel)
		[self loadView];
}

#pragma mark -
#pragma mark acessor


- (VMString*)timeAsTimeDescriptor:(VMFloat)time unit:(VMPTimeUnitType)unit {
	VMFloat bpm = self.bpmField.floatValue;
	VMFloat secsPerBeat = 60. / bpm;
	
	switch ( unit ) {
		case VMPTimeUnit_msec:
			return [NSString stringWithFormat:@"%.3f",time ];
			break;
			
		case VMPTimeUnit_beat:
			return [NSString stringWithFormat:@"%.6f/4@%.2fbpm",time / secsPerBeat, bpm ];
			break;
			
		case VMPTimeUnit_bar44:
			return [NSString stringWithFormat:@"%.6f/1@%.2fbpm",time / secsPerBeat, bpm ];
			break;
			
		case VMPTimeUnit_bar34:
			return [NSString stringWithFormat:@"%.6f/3@%.2fbpm",time * 3 / secsPerBeat, bpm ];
			break;
	}
	return nil;
}

- (VMFloat)timeAsFieldFloatValue:(VMFloat)time unit:(VMPTimeUnitType)unit {
	VMFloat bpm = self.bpmField.floatValue;
	VMFloat secsPerBeat = 60. / bpm;
	
	switch ( unit ) {
		case VMPTimeUnit_msec:
			return time * 1000;
			break;
			
		case VMPTimeUnit_beat:
			return time / secsPerBeat;
			break;
			
		case VMPTimeUnit_bar44:
			return time / secsPerBeat / 4;
			break;
			
		case VMPTimeUnit_bar34:
			return time / secsPerBeat / 3;
			break;
	}
	return 0;
}

- (VMFloat)valueFromTimeFieldFloat:(VMFloat)fieldValue unit:(VMPTimeUnitType)unit {
	VMFloat bpm = self.bpmField.floatValue;
	VMFloat secsPerBeat = 60. / bpm;
	
	switch ( unit ) {
		case VMPTimeUnit_msec:
			return fieldValue / 1000.;
			break;
			
		case VMPTimeUnit_beat:
			return fieldValue * secsPerBeat;
			break;
			
		case VMPTimeUnit_bar44:
			return fieldValue * secsPerBeat * 4;
			break;
			
		case VMPTimeUnit_bar34:
			return fieldValue * secsPerBeat * 3;
			break;
	}
	return 0;
}

- (void)updateTimeFields {
	self.time1Field.floatValue = [self timeAsFieldFloatValue:value1 unit:self.unitSelector1.selectedItem.tag];
	self.time2Field.floatValue = [self timeAsFieldFloatValue:value2 unit:self.unitSelector2.selectedItem.tag];
}

- (VMString*)time1 {
	return [self timeAsTimeDescriptor:value1 unit:(VMPTimeUnitType)self.unitSelector1.selectedItem.tag];
}

- (VMString*)time2 {
	return [self timeAsTimeDescriptor:value2 unit:(VMPTimeUnitType)self.unitSelector2.selectedItem.tag];
}

- (void)setTime1:(VMString*)time1 time2:(VMString*)time2 {
	VMFloat bpm;
	[VMTimeRangeDescriptor splitTimeDescriptor:time1 numerator:nil denominator:nil bpm:&bpm];
	if ( bpm ) self.bpmField.floatValue = bpm;
	[VMTimeRangeDescriptor splitTimeDescriptor:time2 numerator:nil denominator:nil bpm:&bpm];
	if ( bpm ) self.bpmField.floatValue = bpm;
	
	value1 = [VMTimeRangeDescriptor secondsFromTimeDescriptor:time1];
	value2 = [VMTimeRangeDescriptor secondsFromTimeDescriptor:time2];
	[self updateTimeFields];
}



#pragma mark -
#pragma mark action

- (IBAction)unitSelected:(id)sender {
	//NSPopUpButton *pu = sender;
	[self updateTimeFields];
	BOOL bpmVisible = (   self.unitSelector1.selectedItem.tag != 0
					   || self.unitSelector2.selectedItem.tag != 0 );
	self.bpmField.hidden = ! bpmVisible;
	self.bpmLabel.hidden = ! bpmVisible;
}

- (void)setTitle:(NSString *)title caption1:(NSString *)caption1 caption2:(NSString *)caption2 {
	self.titleLabel.stringValue = title;
	self.time1Label.stringValue = caption1;
	self.time2Label.stringValue = caption2;
}


- (BOOL)control:(NSControl *)control didFailToFormatString:(NSString *)string errorDescription:(NSString *)error {
	NSLog(@"format fail: %@ %@",string,error);
	return YES;
}

- (void)control:(NSControl *)control didFailToValidatePartialString:(NSString *)string errorDescription:(NSString *)error {
	NSLog(@"validate fail: %@ %@",string,error);
	
}

- (void)controlTextDidChange:(NSNotification *)obj {
	NSTextField *tf = obj.object;
	if ( tf == self.time1Field ) value1 = [self valueFromTimeFieldFloat:tf.floatValue unit:(int)self.unitSelector1.selectedItem.tag];
	if ( tf == self.time2Field ) value2 = [self valueFromTimeFieldFloat:tf.floatValue unit:(int)self.unitSelector2.selectedItem.tag];
	if ( tf == self.bpmField ) [self updateTimeFields];
	NSLog(@"textChange %@",tf.stringValue);
}

- (void)controlTextDidEndEditing:(NSNotification *)obj {
	NSTextField *tf = obj.object;
	NSLog(@"endEdit %@",tf.stringValue);
}


@end

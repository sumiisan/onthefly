//
//  VMPAudioEditorView.h
//  OnTheFly
//
//  Created by sumiisan on 2013/04/29.
//
//

#import "VMPGraph.h"
#import "VMPTimeRangeEditorView.h"
#import "VMDataTypes.h"
#import "VMAudioObject.h"

@interface VMPAudioInfoEditorViewController : NSViewController <VMPDataGraphObject, VMPGraphDelegate>

@property (nonatomic, retain)	VMAudioInfo						*audioInfo;
@property (nonatomic, retain)	VMAudioObject					*audioObject;
@property (nonatomic)			VMFloat							waveScale;


@property (nonatomic, assign) IBOutlet VMPTimeRangeEditorView	*cueRangeEditor;
@property (nonatomic, assign) IBOutlet VMPTimeRangeEditorView	*regionRangeEditor;
@property (nonatomic, assign) IBOutlet NSView					*cueRangeEditorViewPlaceHolder;
@property (nonatomic, assign) IBOutlet NSView					*regionRangeEditorViewPlaceHolder;
@property (nonatomic, assign) IBOutlet NSPopUpButton			*regionSelector;
@property (nonatomic, assign) IBOutlet NSSlider					*volumeSlider;
@property (nonatomic, assign) IBOutlet NSTextField				*volumeIndicator;
@property (nonatomic, assign) IBOutlet NSButton					*zoomInButton;
@property (nonatomic, assign) IBOutlet NSButton					*zoomOutButton;
@property (nonatomic, assign) IBOutlet NSScrollView				*waveScrollView;
@property (nonatomic, assign) IBOutlet NSImageView				*waveDisplay;
@property (nonatomic, assign) IBOutlet VMPGraph					*waveAndMarkerView;
@property (nonatomic, assign) IBOutlet NSTextField				*fileIdField;
@property (nonatomic, assign) IBOutlet NSButton					*openFileButton;

- (IBAction)openFileButtonClicked:(id)sender;
- (IBAction)zoomButtonClicked:(id)sender;
- (IBAction)volumeSliderMoved:(id)sender;
- (IBAction)volumeTextSet:(id)sender;
- (IBAction)regionSelected:(id)sender;


@end

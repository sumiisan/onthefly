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
#import "VMPAudioPlayer.h"

//--------------------- VMPWaveView -----------------------------

@interface VMPWaveView : VMPGraph {
	__weak	VMAudioObject	*_audioObject;
}
@property (weak)				VMAudioObject					*audioObject;
@end

/*---------------------------------------------------------------------------------
 *
 *
 *	VMP Audio Info Editor View Controller
 *
 *
 *---------------------------------------------------------------------------------*/

@interface VMPAudioInfoEditorViewController : NSViewController <VMPDataGraphObject, VMPGraphDelegate> {
	__weak	VMPAudioPlayer	*_audioPlayer;
}

@property (nonatomic, retain)	VMAudioInfo						*audioInfo;
@property (nonatomic, retain)	VMAudioObject					*audioObject;
@property (nonatomic)			VMFloat							waveScale;
@property (weak)				VMPAudioPlayer					*audioPlayer;


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
//@property (nonatomic, assign) IBOutlet NSImageView				*waveDisplay;
@property (nonatomic, assign) IBOutlet VMPWaveView				*waveView;
@property (nonatomic, assign) IBOutlet VMPGraph					*waveAndMarkerView;

@property (nonatomic, assign) IBOutlet NSTextField				*fileIdField;
@property (nonatomic, assign) IBOutlet NSButton					*openFileButton;

- (IBAction)openFileButtonClicked:(id)sender;
- (IBAction)zoomButtonClicked:(id)sender;
- (IBAction)volumeSliderMoved:(id)sender;
- (IBAction)volumeTextSet:(id)sender;
- (IBAction)regionSelected:(id)sender;


@end

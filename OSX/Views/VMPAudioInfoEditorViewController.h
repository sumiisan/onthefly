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
#import "VMAudioFFT.h"

//--------------------- VMPWaveView -----------------------------

@interface VMPWaveView : VMPGraph
@property (nonatomic, VMStrong)		VMAudioObject					*audioObject;
@property (nonatomic, VMStrong)		VMAudioFFTWrapper				*audioFFTWrapper;

@end

/*---------------------------------------------------------------------------------
 *
 *
 *	VMP Audio Info Editor View Controller
 *
 *
 *---------------------------------------------------------------------------------*/

@interface VMPAudioInfoEditorViewController : NSViewController <VMPDataGraphObject, VMPGraphDelegate>

@property (nonatomic, VMStrong)	VMAudioInfo						*audioInfo;
@property (nonatomic, VMStrong)	VMAudioObject					*audioObject;
@property (nonatomic)			VMFloat							waveScale;
@property (nonatomic, VMStrong)	VMPAudioPlayer					*audioPlayer;


@property (nonatomic, VMWeak) IBOutlet VMPTimeRangeEditorView	*cueRangeEditor;
@property (nonatomic, VMWeak) IBOutlet VMPTimeRangeEditorView	*regionRangeEditor;
@property (nonatomic, VMWeak) IBOutlet NSView					*cueRangeEditorViewPlaceHolder;
@property (nonatomic, VMWeak) IBOutlet NSView					*regionRangeEditorViewPlaceHolder;
@property (nonatomic, VMWeak) IBOutlet NSPopUpButton			*regionSelector;
@property (nonatomic, VMWeak) IBOutlet NSSlider					*volumeSlider;
@property (nonatomic, VMWeak) IBOutlet NSTextField				*volumeIndicator;
@property (nonatomic, VMWeak) IBOutlet NSButton					*zoomInButton;
@property (nonatomic, VMWeak) IBOutlet NSButton					*zoomOutButton;
@property (nonatomic, VMWeak) IBOutlet NSScrollView				*waveScrollView;
//@property (nonatomic, assign) IBOutlet NSImageView				*waveDisplay;
@property (nonatomic, VMWeak) IBOutlet VMPWaveView				*waveView;
@property (nonatomic, VMWeak) IBOutlet VMPGraph					*waveAndMarkerView;

@property (nonatomic, VMWeak) IBOutlet NSTextField				*fileIdField;
@property (nonatomic, VMWeak) IBOutlet NSButton					*openFileButton;

- (IBAction)openFileButtonClicked:(id)sender;
- (IBAction)zoomButtonClicked:(id)sender;
- (IBAction)volumeSliderMoved:(id)sender;
- (IBAction)volumeTextSet:(id)sender;
- (IBAction)regionSelected:(id)sender;


@end

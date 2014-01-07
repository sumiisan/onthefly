//
//  VMPAudioEditorView.m
//  OnTheFly
//
//  Created by sumiisan on 2013/04/29.
//
//

#include <AudioToolbox/AudioToolbox.h>

#import "VMPAudioInfoEditorViewController.h"
#import "VMPlayerOSXDelegate.h"
#import "VMPSongPlayer.h"
#import "VMPNotification.h"
#import "VMPSongPlayer.h"
#import "VMAudioFFT.h"

/*---------------------------------------------------------------------------------
 
 VMPWaveView
 
 ----------------------------------------------------------------------------------*/

#pragma mark -
#pragma mark VMPWaveView
#pragma mark -

@implementation VMPWaveView
@synthesize audioFFTWrapper=audioFFTWrapper_;

- (BOOL)isOpaque {
	return YES;
}

- (void)drawRect:(NSRect)dirtyRect {
	if (self.backgroundColor) {
		[self.backgroundColor set];
		NSRectFill(dirtyRect);
	}
	if ( ! self.audioFFTWrapper ) {
		self.audioFFTWrapper = [[VMAudioFFTWrapper alloc] init];
	}
	
	VMFloat w = self.frame.size.width;
	VMFloat beginP			= dirtyRect.origin.x / w;
	VMFloat lengthP			= dirtyRect.size.width / w;
	
	VMInt	numberOfFrames	= _audioObject.numberOfFrames;
	VMInt	beginFrame		= (VMInt)(beginP * (VMFloat)numberOfFrames);
	VMInt	frameLength		= (VMInt)(lengthP * (VMFloat)numberOfFrames);
		
	VMFloat pixelPerFrame	=  dirtyRect.size.width / frameLength;
	
	void	*waveData		= [_audioObject dataAtFrame:beginFrame];

	int waveX				= dirtyRect.origin.x;
	VMFloat currentX		= dirtyRect.origin.x;

	/*
	//
	//	plot spectrum
	//
	CGFloat x0 = dirtyRect.origin.x;
	CGFloat wd = pixelPerFrame * kHalfFFTLength;
	CGFloat x1 = x0 + wd;
	CGFloat h = self.frame.size.height;
	CGFloat logMax = logf(1.01 / 0.01);
	
//	NSLog(@"wavedata:%p beginFrame:%ld frameLength:%ld x0:%.2f",_audioObject.waveData,beginFrame,frameLength,x0);
	for( VMInt ofs = 0; ofs	< frameLength; ofs += kHalfFFTLength ) {
		[audioFFTWrapper_ fft:_audioObject.waveData
				   sampleRate:_audioObject.framesPerSecond
					   frames:frameLength
					   offset:ofs+beginFrame];
		//NSDictionary *d = [audioFFTWrapper_ features];
		float *mag = [audioFFTWrapper_ magnitude];
		CGFloat y0 = h;
		CGFloat y1;
		
		float min = INFINITY;
		float max = 0;

		for ( int bin = 0; bin < kHalfFFTLength; ++bin ) {
			float r = bin / (float)kHalfFFTLength;
			
			y1 = h - h * ( 1 + ( log( r + 0.01 ) / logMax ) );
			float m = mag[bin] * 0.01;
			if ( m > max ) max = m;
			if ( m < min ) min = m;
			if ( m >   1 ) m   = 1;
			//NSLog(@"%.4f %.2f=%.2f %.2f -- %.2f",m,r,1 + (log( r + 0.01 ) / logMax) ,y0, y1);
			
			[[NSColor colorWithCalibratedHue:r saturation:0.5 brightness:m alpha:1] setFill];
			[NSBezierPath fillRect:NSMakeRect(x0, y0, x1, y1)];
			y0 = y1;
		}
		NSLog(@"%.2f - %.2f",min,max);
		x0 = x1;
		x1 = x1 + wd;
	}
*/
	//
	//	plot wave
	//
	VMFloat m = self.frame.size.height * 0.5;
	Float32 *waveDataBorder = waveData + _audioObject.bytesPerFrame * frameLength +1;
	if ( (void*)waveDataBorder > _audioObject.waveDataBorder ) waveDataBorder = _audioObject.waveDataBorder;
	Float32 min =  2;
	Float32 max = -2;
	currentX	= dirtyRect.origin.x;
	
	[self.foregroundColor setStroke];
	for( Float32 *p = waveData; p < waveDataBorder; ) {
		Float32 l = *p++;
		Float32 r = *p++;
		max = ( l > max ? (( l > r ) ? l : r ) : max );
		min = ( l < min ? (( l < r ) ? l : r ) : min );
		if ( max >  1 ) max = min;
		if ( min < -1 ) min = max;
		currentX += pixelPerFrame;
		if ( ((int)currentX) > waveX ) {
			[NSBezierPath strokeLineFromPoint:NSMakePoint(waveX+0.5, m + m * min) toPoint:NSMakePoint(waveX+0.5, m + m * max )];
			min =  2;
			max = -2;
			++waveX;
		}
	}
}

- (void)dealloc {
 	VMNullify(audioFFTWrapper);
	VMNullify(audioObject);
	[super dealloc];
}


@end




/*---------------------------------------------------------------------------------
 
 VMPAudioInfoEditorViewController
 
 ----------------------------------------------------------------------------------*/

#pragma mark -
#pragma mark VMPAudioInfoEditorViewController
#pragma mark -

@implementation VMPAudioInfoEditorViewController

static const CGFloat kWaveDisplayHorizontalMargin = 20;


/*- (id)initWithCoder:(NSCoder *)aDecoder {
	self = [super initWithCoder:aDecoder];
	return self;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
	self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
	return self;
}
*/

- (void)dealloc {
	[VMPNotificationCenter removeObserver:self];
	VMNullify(audioPlayer);
	VMNullify(audioInfo);
	VMNullify(audioObject);
	Dealloc( super );
}

- (void)awakeFromNib {
	self.waveScale = 1;
	VMPGraph *cueRangeEditorView	= (VMPGraph*)self.cueRangeEditor.view;
	VMPGraph *regionRangeEditorView = (VMPGraph*)self.regionRangeEditor.view;
	cueRangeEditorView.		frame = self.cueRangeEditorViewPlaceHolder.frame;
	regionRangeEditorView.	frame = self.regionRangeEditorViewPlaceHolder.frame;
	cueRangeEditorView.		backgroundColor = [NSColor colorWithCalibratedWhite:0.85 alpha:1.];
	regionRangeEditorView.	backgroundColor = [NSColor colorWithCalibratedWhite:0.85 alpha:1.];
	cueRangeEditorView.		flippedYCoordinate = NO;
	regionRangeEditorView.	flippedYCoordinate = NO;
	cueRangeEditorView.		autoresizingMask = NSViewMinXMargin;
	regionRangeEditorView.	autoresizingMask = NSViewMinXMargin;
	[self.view addSubview:cueRangeEditorView];
	[self.view addSubview:regionRangeEditorView];
	[self.cueRangeEditor	setTitle:@"Cue Position" caption1:@"offset" caption2:@"duration"];
	[self.regionRangeEditor setTitle:@"Region" caption1:@"start" caption2:@"length"];

	self.waveAndMarkerView.graphDelegate = self;
	[self.waveAndMarkerView addTopOverlay];
	
	self.waveView.foregroundColor = [NSColor colorWithCalibratedRed:.4 green:.4 blue:.4 alpha:1.];
	self.waveView.backgroundColor = [NSColor colorWithCalibratedRed:.85 green:.85 blue:.85 alpha:1.];
	
	[self updateFieldsAndKnobs];
	
	[VMPNotificationCenter addObserver:self selector:@selector(audioFragmentFired:) name:VMPNotificationAudioFragmentFired object:nil];
}

#pragma mark -
#pragma mark ui
- (void)updateFieldsAndKnobs {
	[self.cueRangeEditor setTime1:self.audioInfo.cuePoints.locationDescriptor time2:self.audioInfo.cuePoints.lengthDescriptor];
	[self.regionRangeEditor setTime1:self.audioInfo.regionRange.locationDescriptor time2:self.audioInfo.regionRange.lengthDescriptor];
	self.volumeIndicator.floatValue = self.audioInfo.volume;
	self.volumeSlider.floatValue = self.audioInfo.volume;
	
	self.fileIdField.stringValue = (self.audioInfo.hasExplicitlySpecifiedFileId ? self.audioInfo.fileId : @"" );
	if( self.audioInfo.fileId )
		[self.fileIdField.cell setPlaceholderAttributedString:
		 AutoRelease([[NSAttributedString alloc] initWithString: self.audioInfo.fileId attributes:@{
					  NSForegroundColorAttributeName:[NSColor disabledControlTextColor]
		   }] )];
}


#pragma mark -
#pragma mark accessor

- (void)setAudioInfo:(VMAudioInfo *)audioInfo {
	Release( _audioInfo );
	_audioInfo = Retain( audioInfo );
	[self updateFieldsAndKnobs];
	
	[self loadAudioObject:_audioInfo.fileId];
	[[self.waveAndMarkerView viewWithTag:'spll'] removeFromSuperview];
	[self plotWaveAndRanges];
	
	self.audioPlayer = [DEFAULTSONGPLAYER audioPlayerForFileId:self.audioInfo.fileId];
	if ( self.audioPlayer ) [self beginDisplayPlayPositionLine];
	
}

- (void)loadAudioObject:(VMString*)fileId {
	NSString *path = [DEFAULTSONGPLAYER filePathForFileId:fileId];
	if (path) {
		self.audioObject = AutoRelease( [[VMAudioObject alloc] init] );
		OSErr err = [self.audioObject load:path];
		if (err)
			NSLog(@"AudioObject load error:%d",err);
		else
			self.waveView.audioObject = self.audioObject;
	} else {
		[APPDELEGATE.systemLog logError:@"Could not open audio file for %@." withData:fileId];
		[APPDELEGATE showLogPanelIfNewSystemLogsAreAdded];
	}
}

- (void)plotWaveAndRanges {
	CGFloat waveDisplayWidth = self.waveScrollView.frame.size.width - kWaveDisplayHorizontalMargin * 2;	
	self.waveView.y = 0;
	CGFloat w = waveDisplayWidth * self.waveScale;
	self.waveAndMarkerView.frame = CGRectMake(_waveAndMarkerView.x,
											  _waveAndMarkerView.y,
											  w + kWaveDisplayHorizontalMargin *2,
											  self.waveAndMarkerView.height);
	
	self.waveView.needsDisplay = YES;
	self.waveAndMarkerView.needsDisplay = YES;
}

//	wave and marker view delegate
- (void)drawRect:(NSRect)dirtyRect ofView:(NSView*)view {
	CGFloat markerAreaHeight = 20;
	CGFloat x = view.frame.origin.x;
	CGFloat y = view.frame.origin.y;
	CGFloat w = view.frame.size.width;
	CGFloat h = view.frame.size.height;
	
	if ( view == self.waveAndMarkerView ) {
		//
		//	background
		//
		[[NSColor colorWithCalibratedWhite:0.6 alpha:1.] set];
		NSRectFill( NSMakeRect(x,y+h-markerAreaHeight,w,markerAreaHeight));
		[[NSColor colorWithCalibratedWhite:0.3 alpha:1.] set];
		NSRectFill( NSMakeRect(x,y,kWaveDisplayHorizontalMargin,h-markerAreaHeight));
		NSRectFill( NSMakeRect(w-kWaveDisplayHorizontalMargin,y,kWaveDisplayHorizontalMargin,h-markerAreaHeight));
	} else if ( view == self.waveAndMarkerView.topOverlay ) {
		//
		// overlay
		//
		VMFloat pixPerSec =  ( w - 2 * kWaveDisplayHorizontalMargin ) / ( _audioObject.numberOfFrames / (VMFloat)_audioObject.framesPerSecond );
		[[NSColor colorWithCalibratedRed:.6 green:.2 blue:.2 alpha:1.] setStroke];
		CGFloat offsetX = (int)(_audioInfo.offset * pixPerSec + kWaveDisplayHorizontalMargin) + 0.5;
		[NSBezierPath strokeLineFromPoint:NSMakePoint(offsetX, y) toPoint:NSMakePoint(offsetX, y+h)];
		CGFloat durationX = (int)(_audioInfo.duration * pixPerSec + offsetX ) + 0.5;
		[NSBezierPath strokeLineFromPoint:NSMakePoint(durationX, y) toPoint:NSMakePoint(durationX, y+h)];
		[NSBezierPath strokeLineFromPoint:NSMakePoint(offsetX, (int)(y+h)-15.5) toPoint:NSMakePoint(durationX, (int)(y+h)-15.5)];
	}
}


- (void)setData:(id)data {
	self.audioInfo = data;
}

#pragma mark -
#pragma mark action
static BOOL ui_lock;

- (IBAction)openFileButtonClicked:(id)sender {
	
}

- (IBAction)zoomButtonClicked:(id)sender {
	
	VMFloat maxWaveScale = self.audioObject.numberOfFrames / self.waveScrollView.frame.size.width;
	
	_waveScale = ( ((NSControl*)sender).tag == 1 ) ? _waveScale * 0.5 : _waveScale * 2.;
	_waveScale = ( _waveScale < 1 ? 1 : ( _waveScale > maxWaveScale ? maxWaveScale : _waveScale ));
	
	[self plotWaveAndRanges];
}

- (IBAction)volumeSliderMoved:(id)sender {
	if(ui_lock)return;
	ui_lock=YES;
	self.volumeIndicator.floatValue = self.volumeSlider.floatValue;
	ui_lock=NO;
}

- (IBAction)volumeTextSet:(id)sender {
	self.volumeSlider.floatValue = self.volumeIndicator.floatValue;	
}

- (IBAction)regionSelected:(id)sender {
	
}

#pragma mark -
#pragma mark notification

- (void)audioFragmentFired:(NSNotification*)notification {
	VMAudioFragment *fr = (notification.userInfo)[@"audioFragment"];
	if ( fr.audioInfoId == self.audioInfo.id ) {
		self.audioPlayer = (notification.userInfo)[@"player"];
		[self beginDisplayPlayPositionLine];
	} else {
		VMNullify(audioPlayer);
	}
}

- (void)beginDisplayPlayPositionLine {
	[[self.waveAndMarkerView viewWithTag:'spll'] removeFromSuperview];
	VMPGraph *vertLine = [[VMPGraph alloc] initWithFrame:NSMakeRect(-1000, 0, 1, self.waveView.height)];
	vertLine.backgroundColor = [NSColor redColor];
	vertLine.tag = 'spll';
	[self.waveAndMarkerView addSubview:vertLine];
	[self performSelector:@selector(drawPlayPositionLine:) withObject:vertLine afterDelay:.03];
}


#pragma mark -
#pragma mark play position

- (void)drawPlayPositionLine:(VMPGraph*)lineObj {
	if ( self.audioPlayer &&  self.audioPlayer.isPlaying ) {
		VMFloat dur = _audioObject.numberOfFrames / (VMFloat)_audioObject.framesPerSecond;
		VMFloat p = ( self.audioPlayer.currentTime / dur );
		if ( p > 1 ) {
			VMNullify(audioPlayer);
		} else {
			lineObj.x = p * _waveView.width + kWaveDisplayHorizontalMargin;
			[self performSelector:@selector(drawPlayPositionLine:) withObject:lineObj afterDelay:.03];
		}
	}
	if ( ! self.audioPlayer ) {
		[lineObj removeFromSuperview];
		Release(lineObj);
	}
}


@end

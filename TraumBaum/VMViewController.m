//
//  VMViewController.m
//  Traumbaum
//
//  Created by sumiisan on 2013/03/22.
//
//

#import "VMViewController.h"
#import "VMPTrackView.h"
#import "VMPSongPlayer.h"
#import "VMScoreEvaluator.h"
#import "VMPInfoViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "VMAppDelegate.h"
#import "VMPVineView.h"

@import MediaPlayer;


@interface VMViewController ()

@end

@implementation VMViewController


- (BOOL)prefersStatusBarHidden {
	return NO;
}


- (void)viewDidLoad {
    [super viewDidLoad];
	[[VMAppDelegate defaultAppDelegate] setAudioBackgroundMode];
	
	self.view.frame = [[UIScreen mainScreen] bounds];
	self.trackView = [[[VMPTrackView alloc] initWithFrame:self.view.frame] autorelease];
    DEFAULTSONGPLAYER.trackView = self.trackView;
		
	[self dayPhaseChanged:nil];
	self.frontView = [[[VMPFrontView alloc]
					   initWithFrame:self.view.bounds
					   ] autorelease];
	[self.view addSubview:self.frontView];
	[[MPRemoteCommandCenter sharedCommandCenter].togglePlayPauseCommand
	 addTarget:self.frontView action:@selector(handleRemoteControl)];

	[[MPRemoteCommandCenter sharedCommandCenter].playCommand
	 addTarget:self.frontView action:@selector(handleRemoteControl)];

	[[MPRemoteCommandCenter sharedCommandCenter].stopCommand
	 addTarget:self.frontView action:@selector(handleRemoteControl)];

	[[MPRemoteCommandCenter sharedCommandCenter].pauseCommand
	 addTarget:self.frontView action:@selector(handleRemoteControl)];

	
	
	[self attachConfigButton];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dayPhaseChanged:) name:DAYPHASE_CHANGED_NOTIFICATION object:nil];
	
	//	test code:
#if VMP_VISUALIZER
	VMPVineView *vv = [[[VMPVineView alloc] initWithFrame:self.view.frame] autorelease];
	[self.view addSubview:vv];
#endif
}


- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id <UIViewControllerTransitionCoordinator>)coordinator {
	//NSLog(@"transition to size:%@",NSStringFromCGSize(size));
	[super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
	[self placeConfigButton:size];
	[self.frontView calculateDimensions:size];

	if( [self.view.subviews indexOfObject:self.infoViewController.view] != NSNotFound ) {
		[self.infoViewController viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
		//	because this VC is never presented (just loaded and view-added), we must pass event explicitly
	}
}

- (void)placeConfigButton:(CGSize)size {
	CGFloat radius = 19;//9 + MIN(size.width,size.height) * 0.03;

	_configButton.frame = CGRectMake( size.width * 0.5 - radius, size.height * 0.78, radius*2, radius*2 );

}

- (void)attachConfigButton {
	
	//	config button
	self.configButton = [UIButton buttonWithType:UIButtonTypeCustom];
	
    // draw original image into the context
	
	//	draw config button
	CGRect outerRect = CGRectMake(  0.0,  0.0, 100, 100 );
	CGRect innerRect = CGRectMake( 10.0, 10.0,  80,  80 );

	CGContextRef originalContext = UIGraphicsGetCurrentContext();
	if (originalContext) UIGraphicsPushContext(originalContext);
	
	UIGraphicsBeginImageContext(outerRect.size);
	//assert(context);
	UIBezierPath *outerCircle = [UIBezierPath bezierPathWithOvalInRect:outerRect];
	UIBezierPath *innerCircle = [UIBezierPath bezierPathWithOvalInRect:innerRect];
	[[UIColor colorWithWhite:0.5 alpha:0.3] setFill];
	[outerCircle fill];
	[[UIColor colorWithWhite:0.5 alpha:0.3] setFill];
	[innerCircle fill];
	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
	
	UIGraphicsEndImageContext();
	if (originalContext) UIGraphicsPopContext();
	
	[_configButton setImage:image forState:UIControlStateNormal];
	//	y * 0.827	-- 3.5"iphone
	//	y * 0.778	-- 4" iphone
	[_configButton addTarget:self action:@selector(configButtonTouched:) forControlEvents:UIControlEventTouchUpInside];
	[self.view addSubview:_configButton];
	
	[self placeConfigButton:self.view.bounds.size];
	
}


- (void)configButtonTouched:(id)sender {
	
	
	self.infoViewController = [[[VMPInfoViewController alloc] initWithNibName:@"VMPInfoViewController" bundle:nil] autorelease];
	self.infoViewController.view.frame = self.view.bounds;
	[self.view addSubview:self.infoViewController.view];
	[self.infoViewController showView];
}
	
- (VMPProgressView*)showProgressView {
	VMPProgressView *p = (VMPProgressView*)[self.view viewWithTag:899];
	if ( !p ) {
		p = [[[VMPProgressView alloc] initWithFrame:CGRectMake(0, 0, 300, 80)] autorelease];
		p.tag = 899;
		[self.view addSubview:p];
	}
	return p;
}

- (void)hideProgressView {
	[[self.view viewWithTag:899] removeFromSuperview];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
	if( ![self.view.subviews containsObject:self.infoViewController.view] ) {
		[self.infoViewController.view removeFromSuperview];
		self.infoViewController = nil;
	}
}

- (void)dayPhaseChanged:(NSNotification*)notification {
	self.view.backgroundColor = DEFAULTEVALUATOR.timeManager.backgroundColor;
}

	
- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
	[super setEditing:editing animated:animated];

	UITableView *tv = (UITableView*)[self.view viewWithTag:888];
	[tv setEditing:editing animated:YES];

}

	
- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	VMNullify(infoViewController);
	VMNullify(trackView);
	VMNullify(frontView);
	VMNullify(configButton);
	Dealloc(super);
}


@end

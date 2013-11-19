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
//#import "VMPIHole.h"
#import "VMPInfoView.h"
#import <AVFoundation/AVFoundation.h>
#import "VMAppDelegate.h"
#import "VMPFrontView.h"

@interface VMViewController ()

@end

@implementation VMViewController


- (void)setSkin:(int)index {
	
	//	skin obsoleted in ver 1.1
	
/*	UIImageView *bg = (UIImageView*)[self.view viewWithTag:'__bg'];
	if ( !bg ) {
		bg = [[UIImageView alloc] initWithFrame:CGRectMake(0, ( Is4InchIPhone ? 0 : -40 ), 320, 568 )];
		bg.tag = '__bg';
		[self.view addSubview:bg];
		Release(bg);
	}
	bg.image = [UIImage imageNamed:[NSString stringWithFormat:@"iPhone-UI/skin%d_phone.jpg", index]];
 */
//	self.view.backgroundColor = ( index == 0 ? [UIColor whiteColor] : [UIColor blackColor] );
	
}

//	delegate
- (void)setSkinIndex:(int)skinIndex {
	[self setSkin:skinIndex];
	[[NSUserDefaults standardUserDefaults] setInteger:skinIndex forKey:@"skinIndex"];
}

- (void)viewDidLoad {
    [super viewDidLoad];
	[[VMAppDelegate defaultAppDelegate] setAudioBackgroundMode];
	self.view.frame = CGRectMake(0, 0, 320, Is4InchIPhone ? 568 : 480 );
	
	self.trackView = [[[VMPTrackView alloc] initWithFrame:self.view.frame] autorelease];
//    [self.view addSubview:trackView];
    DEFAULTSONGPLAYER.trackView = self.trackView;
		
	self.view.backgroundColor = [UIColor whiteColor];
	//	background
//	NSInteger skinIndex = [[NSUserDefaults standardUserDefaults] integerForKey:@"skinIndex"];
//	[self setSkin: skinIndex];
	
	//	testing:
	VMPFrontView *fv = AutoRelease( [[VMPFrontView alloc] initWithFrame:self.view.frame] );
	[self.view addSubview:fv];

	
	//	config button
	UIButton *bt = [UIButton buttonWithType:UIButtonTypeCustom];
	/*
	[bt setImage:[UIImage imageNamed:@"iPhone-UI/round_button_up.png"] forState:UIControlStateNormal];
	[bt setImage:[UIImage imageNamed:@"iPhone-UI/round_button_dn.png"] forState:UIControlStateHighlighted];
	 */
	
	//	draw config button
	CGRect outerRect = CGRectMake(  0.0,  0.0, 100, 100 );
	CGRect innerRect = CGRectMake( 10.0, 10.0,  80,  80 );
	CGContextRef context = UIGraphicsGetCurrentContext();
	UIGraphicsPushContext(context);
	UIGraphicsBeginImageContext(outerRect.size);
	UIBezierPath *outerCircle = [UIBezierPath bezierPathWithOvalInRect:outerRect];
	UIBezierPath *innerCircle = [UIBezierPath bezierPathWithOvalInRect:innerRect];
	[[UIColor colorWithWhite:0.7 alpha:0.5] setFill];
	[outerCircle fill];
	CGContextAddPath(context, outerCircle.CGPath);
	[[UIColor colorWithWhite:0.7 alpha:0.5] setFill];
	[innerCircle fill];
	CGContextAddPath(context, innerCircle.CGPath);
	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsPopContext();
	UIGraphicsEndImageContext();
	
	[bt setImage:image forState:UIControlStateNormal];
	
	CGFloat radius = 19;
	bt.frame = CGRectMake( 162 - radius, 397 + ( Is4InchIPhone ? 45 : 0 ), radius*2, radius*2 );
	[bt addTarget:self action:@selector(configButtonTouched:) forControlEvents:UIControlEventTouchUpInside];
	[self.view addSubview:bt];
	
	if ( ! self.infoView ) {
		//	info view
		self.infoView = [[[VMPInfoView alloc] initWithFrame:CGRectMake(0, 0, 320, 480)] autorelease];
		
		UIView *view = [[[NSBundle mainBundle] loadNibNamed:@"VMPInfoView" owner:self.infoView options:nil] objectAtIndex:0];
		[self.infoView addSubview: view];
	}
}


- (void)configButtonTouched:(id)sender {
	[self.view addSubview:self.infoView];
	[(VMPInfoView*)self.infoView showView];
}

- (void)awakeFromNib {
//	self.frontView.backgroundColor = [UIColor blueColor];	//test
	
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (void)dealloc {
	VMNullify(infoView);
	Dealloc(super);
}


@end

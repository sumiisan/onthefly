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
#import "VMPInfoView.h"
#import <AVFoundation/AVFoundation.h>
#import "VMAppDelegate.h"

@interface VMViewController ()

@end

@implementation VMViewController


- (BOOL)prefersStatusBarHidden {
    return YES;//(DEFAULTEVALUATOR.timeManager.nightNess>0.5);
}

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
}

- (void)viewDidLoad {
    [super viewDidLoad];
	[[VMAppDelegate defaultAppDelegate] setAudioBackgroundMode];
	self.view.frame = CGRectMake(0, 0, 320, Is4InchIPhone ? 568 : 480 );
	
	self.trackView = [[[VMPTrackView alloc] initWithFrame:self.view.frame] autorelease];
    DEFAULTSONGPLAYER.trackView = self.trackView;
		
	self.view.backgroundColor = [UIColor grayColor];
	
	self.frontView = [[[VMPFrontView alloc]
					   initWithFrame:CGRectMake(0,
												0,
												320,
												self.view.bounds.size.height)
					   ] autorelease];
	[self.view addSubview:self.frontView];
	[self attachConfigButton];
}

- (void)attachConfigButton {
	
	//	config button
	UIButton *bt = [UIButton buttonWithType:UIButtonTypeCustom];
	
	
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
	
	[bt setImage:image forState:UIControlStateNormal];
	
	CGFloat radius = 19;
	bt.frame = CGRectMake( 162 - radius, 397 + ( Is4InchIPhone ? 45 : 0 ), radius*2, radius*2 );
	[bt addTarget:self action:@selector(configButtonTouched:) forControlEvents:UIControlEventTouchUpInside];
	[self.view addSubview:bt];
	
}


- (void)configButtonTouched:(id)sender {
	self.infoView = [[[VMPInfoView alloc] initWithFrame:CGRectMake(0, (self.view.bounds.size.height - 480)*0.5,
																   320, 480)] autorelease];
	
	UIView *view = [[[NSBundle mainBundle] loadNibNamed:@"VMPInfoView" owner:self.infoView options:nil] objectAtIndex:0];
	[self.infoView addSubview: view];

	[self.view addSubview:self.infoView];
	[(VMPInfoView*)self.infoView showView];
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

- (void)awakeFromNib {
//	self.frontView.backgroundColor = [UIColor blueColor];	//test
	
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
	if( ![self.view.subviews containsObject:self.infoView] ) {
		[self.infoView removeFromSuperview];
		self.infoView = nil;
	}
}

	
	
- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
	[super setEditing:editing animated:animated];

	UITableView *tv = (UITableView*)[self.view viewWithTag:888];
	[tv setEditing:editing animated:YES];

}

	
- (void)dealloc {
	VMNullify(infoView);
	VMNullify(trackView);
	VMNullify(frontView);
	Dealloc(super);
}


@end

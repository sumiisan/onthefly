//
//  VMViewController.h
//  Traumbaum
//
//  Created by sumiisan on 2013/03/22.
//
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "VMPInfoViewController.h"
#import "VMPTrackView.h"
#import "VMPFrontView.h"
#import "VMPProgressView.h"

@interface VMViewController : UIViewController <AVAudioSessionDelegate>

@property (retain, nonatomic)				VMPTrackView *trackView;
@property (nonatomic, retain)				VMPInfoViewController *infoViewController;
@property (nonatomic, retain)				VMPFrontView *frontView;
@property (nonatomic, retain)				UIButton *configButton;

- (VMPProgressView*)showProgressView;
- (void)hideProgressView;

@end

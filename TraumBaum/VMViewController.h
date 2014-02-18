//
//  VMViewController.h
//  Traumbaum
//
//  Created by sumiisan on 2013/03/22.
//
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "VMPInfoView.h"
#import "VMPTrackView.h"
#import "VMPFrontView.h"
#import "VMPProgressView.h"

@interface VMViewController : UIViewController <VMPInfoViewDelegate,AVAudioSessionDelegate>

@property (retain, nonatomic)				VMPTrackView *trackView;
@property (nonatomic, retain)	IBOutlet	VMPInfoView *infoView;
@property (nonatomic, retain)				VMPFrontView *frontView;

- (VMPProgressView*)showProgressView;
- (void)hideProgressView;

@end

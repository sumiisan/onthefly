//
//  VMPSongListView.h
//  OnTheFly
//
//  Created by sumiisan on 2014/02/16.
//
//

#import <UIKit/UIKit.h>
#import "VMVmsarcManager.h"

@interface VMPSongListView : UIView <UITableViewDelegate,UITableViewDataSource,VMVmsarcManagerUpdateDelegate> {
}
- (void)resetMetricsToSize:(CGSize)size;

@end

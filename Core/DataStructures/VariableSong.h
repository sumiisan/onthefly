//
//  VariableSong.h
//  VariableMusicPlayer
//
//  Created by cboy on 12/11/01.
//  Copyright 2012 sumiisan@gmail.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "VMSong.h"
#import "MultiPlatform.h"


@interface VariableSong : VMPDocument {
@public
    VMSong  *song;
}

@property (nonatomic,retain) VMSong *song;

@end

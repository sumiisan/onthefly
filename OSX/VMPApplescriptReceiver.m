//
//  VMPApplescriptReceiver.m
//  VariableMusicPlayer
//
//  Created by cboy on 12/10/22.
//  Copyright 2012 sumiisan (sumiisan.com). All rights reserved.
//

#import "VMPApplescriptReceiver.h"
#import "VMPSongPlayer.h"

@implementation VMPApplescriptReceiver

- (id)init
{
    self = [super init];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}

-(void)StartNMP:(NSScriptCommand *)command {
    [DEFAULTSONGPLAYER start];

}

-(void)StopNMP:(NSScriptCommand *)command {
    [DEFAULTSONGPLAYER stop];
}

-(void)FadeoutAndStopNMP:(NSScriptCommand *)command {
    Float32 fadeLength = kDefaultFadeoutTime;
    if ( [[command arguments] valueForKey:@"length"] != nil ) 
        fadeLength = [[[command arguments] valueForKey:@"length"] floatValue];
    
    [DEFAULTSONGPLAYER fadeoutAndStop:fadeLength ];
}

-(void)SetParameter:(NSScriptCommand *)command {
    Float32 volume = 1.;
    if ( [[command arguments] valueForKey:@"volume"] != nil ) {
        volume = [[[command arguments] valueForKey:@"volume"] floatValue];
        [DEFAULTSONGPLAYER setGlobalVolume:volume];
    }
}

-(void)Hide:(NSScriptCommand *)command {
    [NSApp hide:self];
}

-(void)Unhide:(NSScriptCommand *)command {
    [NSApp unhide:self];
}


-(id)performDefaultImplementation {
    NSLog(@"default");
    return self;
}

-(id)executeCommand {

    NSScriptCommandDescription *d = [self commandDescription];
    NSString *command= [d commandName];
    NSLog(@"execute %@",command);
    
    if ( [command isEqualToString:@"StopNMP"] ) [self StopNMP:self];
    if ( [command isEqualToString:@"StartNMP"] ) [self StartNMP:self];
    if ( [command isEqualToString:@"FadeoutAndStopNMP"] ) [self FadeoutAndStopNMP:self];
    if ( [command isEqualToString:@"SetParameter"] ) [self SetParameter:self];
    if ( [command isEqualToString:@"Hide"] ) [self Hide:self];
    if ( [command isEqualToString:@"Unhide"] ) [self Unhide:self];
    
    return self;
}

@end

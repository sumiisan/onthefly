//
//  ApplescriptReceiver.h
//  VariableMusicPlayer
//
//  Created by cboy on 12/10/22.
//  Copyright 2012 sumiisan (aframasda.com). All rights reserved.
//

#import <Foundation/Foundation.h>


@interface ApplescriptReceiver : NSScriptCommand {
@private
    
}

- (id)performDefaultImplementation;
- (id)executeCommand;

- (void)StartNMP:(NSScriptCommand*)command;
- (void)StopNMP:(NSScriptCommand*)command;
- (void)Hide:(NSScriptCommand*)command;
- (void)Unhide:(NSScriptCommand*)command;
@end

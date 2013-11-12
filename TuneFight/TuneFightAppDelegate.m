//
//  TuneFightAppDelegate.m
//  TuneFight
//
//  Created by Pit Garbe on 14.01.11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "TuneFightAppDelegate.h"
#import "RootViewController.h"
#import <AVFoundation/AVFoundation.h>

@implementation TuneFightAppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Override point for customization after application launch.
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    
	self.viewController = [RootViewController new];
    
    [self.window addSubview:self.viewController.view];
    
    [self.window makeKeyAndVisible];
    return YES;
}


@end

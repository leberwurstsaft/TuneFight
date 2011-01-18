//
//  TuneFightAppDelegate.h
//  TuneFight
//
//  Created by Pit Garbe on 14.01.11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@class RootViewController;

@interface TuneFightAppDelegate : NSObject <UIApplicationDelegate> {
@private    RootViewController *viewController;


}

@property (nonatomic, retain)  UIWindow *window;
@property (nonatomic, retain)  RootViewController *viewController;

@end

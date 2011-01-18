//
//  RootViewController.h
//  TuneFight
//
//  Created by Pit Garbe on 14.01.11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MediaPlayer/MediaPlayer.h>
#import <AVFoundation/AVFoundation.h>

@class TuneView;

@interface RootViewController : UIViewController <MPMediaPickerControllerDelegate, UIScrollViewDelegate> {

	NSMutableArray *tuneViews;
    UIButton *importButton;
	AVPlayer* player;
	UIScrollView *scrollView;
}

- (BOOL)exportItem:(MPMediaItem *)item;
- (void)importTuneFromLibrary;
- (void)playMPItem:(MPMediaItem *)item;

@end

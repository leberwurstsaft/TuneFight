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

@interface RootViewController : UIViewController <MPMediaPickerControllerDelegate, UIScrollViewDelegate>

@property (readonly) BOOL visEnabled;

- (BOOL)exportItem:(MPMediaItem *)item;
- (IBAction)importTuneFromLibrary;
- (void)playMPItem:(MPMediaItem *)item;
- (IBAction)toggleVisualizations;
- (void)updatePlaybackButtons;
- (void)keepHistogramData:(double *)data forItem:(MPMediaItem *)item;

@end

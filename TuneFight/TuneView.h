//
//  ImportView.h
//  TuneFight
//
//  Created by Pit Garbe on 14.01.11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MediaPlayer/MediaPlayer.h>

@class RootViewController, HistogramView, PCMView;

@interface TuneView : UIView {
	MPMediaItem *item;
	UIButton *playBackButton;
	HistogramView *histogramView;
    PCMView *pcmView;
    
    UILabel *artist, *title, *album, *duration;
    
    UIView *timeToConvert;
    double totalFrames;
    double currentFrames;
    
    BOOL once;
}

@property (nonatomic, weak) RootViewController *delegate;
@property (nonatomic, strong) MPMediaItem *item;

- (void)play;
- (void)setHistogramData:(double *)data;
- (void)setPCMData:(double *)data;
- (void)setSpectrumData:(double *)data;
- (void)drawHistogram;
- (void)drawPCM;
- (void)showMetadata;
- (void)updateProgress:(NSInteger)frames;

- (void)disablePlaybackButton;
- (void)enablePlaybackButton;
- (void)enableShadows:(BOOL)enable;

@end

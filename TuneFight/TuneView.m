//
//  ImportView.m
//  TuneFight
//
//  Created by Pit Garbe on 14.01.11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "TuneView.h"
#import "HistogramView.h"
#import "PCMView.h"
#import "RootViewController.h"

@implementation TuneView

@synthesize delegate;
@synthesize item;

- (id)init {
	return [self initWithFrame: CGRectMake(0, 0, 600, 200)];
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
  
		histogramView = [[HistogramView alloc] initWithFrame: CGRectMake(200, 0, 400, 200)];
		histogramView.backgroundColor = [UIColor clearColor];
        
        pcmView = [[PCMView alloc] initWithFrame: CGRectMake(200, 0, 400, 200)];
        pcmView.backgroundColor = [UIColor clearColor];

		playBackButton = [UIButton buttonWithType:UIButtonTypeCustom];
        playBackButton.frame = CGRectMake(5, 140, 180, 60);
        playBackButton.backgroundColor = [UIColor lightGrayColor];
        [playBackButton setTitle:@"►" forState: UIControlStateNormal];
        [[playBackButton titleLabel] setFont:[UIFont fontWithName:@"Arial" size:40]];
        [playBackButton setTitleColor:[UIColor darkGrayColor] forState: UIControlStateNormal];
        [playBackButton setTitleColor:[UIColor darkGrayColor] forState: UIControlStateHighlighted];
		[playBackButton addTarget:self action:@selector(play) forControlEvents:UIControlEventTouchUpInside];
        playBackButton.enabled = NO;
		
		[self addSubview: playBackButton];
        [self addSubview: pcmView];
        
        artist = [[UILabel alloc] initWithFrame: CGRectMake(5, 5, 180, 15)];
        artist.font = [UIFont fontWithName:@"American Typewriter" size:16];
        artist.backgroundColor = [UIColor clearColor];
        artist.textColor = [UIColor lightGrayColor];
        artist.shadowColor = [UIColor colorWithWhite:0 alpha:0.8];
        artist.shadowOffset = CGSizeMake(0, 1);
        [self addSubview: artist];
        
        album = [[UILabel alloc] initWithFrame: CGRectMake(5, 25, 180, 15)];
        album.font = [UIFont fontWithName:@"American Typewriter" size:16];
        album.backgroundColor = [UIColor clearColor];
        album.textColor = [UIColor lightGrayColor];
        album.shadowColor = [UIColor colorWithWhite:0 alpha:0.8];
        album.shadowOffset = CGSizeMake(0, 1);
        [self addSubview: album];
        
        title = [[UILabel alloc] initWithFrame: CGRectMake(5, 45, 180, 15)];
        title.font = [UIFont fontWithName:@"American Typewriter" size:16];
        title.backgroundColor = [UIColor clearColor];
        title.textColor = [UIColor lightGrayColor];
        title.shadowColor = [UIColor colorWithWhite:0 alpha:0.8];
        title.shadowOffset = CGSizeMake(0, 1);
        [self addSubview: title];
        
        duration = [[UILabel alloc] initWithFrame: CGRectMake(5, 65, 180, 15)];
        duration.font = [UIFont fontWithName:@"American Typewriter" size:16];
        duration.backgroundColor = [UIColor clearColor];
        duration.textColor = [UIColor lightGrayColor];
        duration.shadowColor = [UIColor colorWithWhite:0 alpha:0.8];
        duration.shadowOffset = CGSizeMake(0, 1);
        [self addSubview: duration];
        
        timeToConvert = [[UIView alloc] initWithFrame: CGRectMake(5, 105, 180, 15)];
        timeToConvert.backgroundColor = [UIColor lightGrayColor];
        [self addSubview: timeToConvert];
        
        once = NO;
    }
    return self;
}

- (void)play {
	[delegate playMPItem:item];
}

- (void)setHistogramData:(double *)data {
    [histogramView setHistogramData:data];
}

- (void)setPCMData:(double *)data {
    [pcmView setWaveform:data];
}

- (void)setSpectrumData:(double *)data {
    [pcmView setSpectrum:data];
}

- (void)enableShadows:(BOOL)enable {
    pcmView.shadowsEnabled = enable;
}

- (void)drawHistogram {
    [pcmView removeFromSuperview];
    [self addSubview:histogramView];
    [timeToConvert setFrame: CGRectMake(timeToConvert.frame.origin.x, timeToConvert.frame.origin.y, 0, timeToConvert.frame.size.height)];
    [histogramView setNeedsDisplay];
}

- (void)drawPCM {
    [pcmView setNeedsDisplay];
}

- (void)showMetadata {
    artist.text = [NSString stringWithFormat: @"K:   %@",[item valueForProperty: MPMediaItemPropertyArtist]];
    album.text = [NSString stringWithFormat: @"A:   %@",[item valueForProperty: MPMediaItemPropertyAlbumTitle]];
    title.text = [NSString stringWithFormat: @"T:   %@",[item valueForProperty: MPMediaItemPropertyTitle]];
    duration.text = [NSString stringWithFormat: @"D:   %@ s",[item valueForProperty: MPMediaItemPropertyPlaybackDuration]];
    
    currentFrames = 0;
    totalFrames = [[item valueForProperty: MPMediaItemPropertyPlaybackDuration] doubleValue] * 44100 / 8192;
    
    //    NSLog(@"Artist: %@",[item valueForProperty: MPMediaItemPropertyArtwork]);
}

- (void)updateProgress:(NSInteger)frames {
    currentFrames += frames;
    [timeToConvert setFrame: CGRectMake(timeToConvert.frame.origin.x, timeToConvert.frame.origin.y, (1 - (currentFrames/totalFrames)) * 180 , timeToConvert.frame.size.height)];
}

- (void)disablePlaybackButton {
    playBackButton.enabled = NO;
    [playBackButton setTitleColor:[UIColor darkGrayColor] forState: UIControlStateNormal];
}

- (void)enablePlaybackButton {
    playBackButton.enabled = YES;
    [playBackButton setTitleColor:[UIColor whiteColor] forState: UIControlStateNormal];
}


@end

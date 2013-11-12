//
//  RootViewController.m
//  TuneFight
//
//  Created by Pit Garbe on 14.01.11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "RootViewController.h"
#import "TuneView.h"
#import <AudioToolbox/AudioToolbox.h>
#include <Accelerate/Accelerate.h>

@interface RootViewController ()

@property (nonatomic, strong) NSMutableArray *tuneViews;
@property (nonatomic, strong) UIButton *importButton;
@property (nonatomic, strong) UIButton *visButton;

@property (nonatomic, strong) AVPlayer* player;
@property (nonatomic, strong) UIScrollView *scrollView;

@property (nonatomic) int currentlyImporting;
@property (nonatomic, readwrite) BOOL visEnabled;

@property (nonatomic, strong) NSFileManager *fileManager;

@end

@implementation RootViewController


- (id)init {
    if ((self=[super init])) {
        self.tuneViews = [NSMutableArray new];
		self.player = [AVPlayer new];
        
        // enable visualisations per default
        // speedup goes down to 5.15 (thank you, glowing shadow of awesome!) from 9.0 (measured on iPad 1) 
        self.visEnabled = YES;
        self.currentlyImporting = 0;
        self.fileManager = [NSFileManager defaultManager];
    }
    return self;
}

#pragma mark - View lifecycle

// Implement loadView to create a view hierarchy programmatically, without using a nib.
- (void)loadView {
	UIView *aView = [[UIView alloc] initWithFrame: CGRectMake(0, 0, 768, 1024)];
    aView.backgroundColor = [UIColor colorWithRed:0.8 green:0.8 blue:0.8 alpha:1];
	
	self.importButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.importButton.frame = CGRectMake(0, 0, 168, 168);
    self.importButton.backgroundColor = [UIColor lightGrayColor];
    [self.importButton setTitle:@"+" forState: UIControlStateNormal];
    [[self.importButton titleLabel] setFont:[UIFont fontWithName:@"American Typewriter" size:80]];
    [self.importButton setTitleColor:[UIColor whiteColor] forState: UIControlStateNormal];
    [self.importButton setTitleColor:[UIColor darkGrayColor] forState: UIControlStateHighlighted];
	[self.importButton addTarget:self action:@selector(importTuneFromLibrary) forControlEvents:UIControlEventTouchUpInside];
	
	[aView addSubview: self.importButton];

    self.visButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.visButton.frame = CGRectMake(0, 170, 168, 168);
    self.visButton.backgroundColor = [UIColor lightGrayColor];
    [self.visButton setImage:[UIImage imageNamed:@"PCM"] forState:UIControlStateNormal];
	[self.visButton addTarget:self action:@selector(toggleVisualizations) forControlEvents:UIControlEventTouchUpInside];
	
	[aView addSubview: self.visButton];

    
	self.scrollView = [[UIScrollView alloc] initWithFrame: CGRectMake(168, 00, 600, 1004)];
    self.scrollView.backgroundColor = [UIColor darkGrayColor];
	self.scrollView.delegate = self;
	self.scrollView.maximumZoomScale = 1.0;
	self.scrollView.minimumZoomScale = 1.0;
	self.scrollView.contentSize = CGSizeMake(self.scrollView.frame.size.width, 100 + [self.tuneViews count] * 200);
	[aView addSubview: self.scrollView];
	
	self.view = aView;
	
	
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

- (void)viewDidLoad {
	
    [super viewDidLoad];
    
	AVAudioSession* session = [AVAudioSession sharedInstance];
	NSError* error = nil;
	if(![session setCategory:AVAudioSessionCategorySoloAmbient error:&error]) {
		NSLog(@"Couldn't set audio session category: %@", error);
	}	
	if(![session setActive:YES error:&error]) {
		NSLog(@"Couldn't make audio session active: %@", error);
	}
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
	return YES;
}

#pragma mark -

- (BOOL)exportItem:(MPMediaItem *)item {
    BOOL histogramExists = NO;
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);

	NSString *documentsDirectory = [paths objectAtIndex:0];
    
    NSString *artist = [item valueForProperty: MPMediaItemPropertyArtist];
    NSString *album = [item valueForProperty: MPMediaItemPropertyAlbumTitle];
    NSString *title = [item valueForProperty: MPMediaItemPropertyTitle];
    
    if (artist == nil && [artist length] == 0) {
        artist = @"unknown artist";
    }
    
    if (album == nil && [album length] == 0) {
        album = @"unknown album";
    }
    
    if (title == nil && [title length] == 0) {
        title = @"unknown title";
    }
    
    NSString *uniqueFileName = [NSString stringWithFormat:@"%@-%@-%@.histogram", artist, album, title];
    
    NSString *path = [NSString stringWithFormat:@"%@/%@", documentsDirectory, uniqueFileName];
	
	if ([self.fileManager fileExistsAtPath: path]) {
        histogramExists = YES;
        NSLog(@"file %@ exists", path);
	}
    
     
    if (histogramExists)
    {
        NSData *histogramData = [NSKeyedUnarchiver unarchiveObjectWithFile: path];
        double *data = calloc(800, sizeof(double));
        [histogramData getBytes:data length: 800 * sizeof(double)];
        
        // add new TuneView
        TuneView *aTuneView = [TuneView new];
        aTuneView.delegate = self;
        aTuneView.center = CGPointMake(self.scrollView.frame.size.width/2.0, [self.tuneViews count] * 220 + 120);
        aTuneView.item = item;
        [aTuneView showMetadata];
        [self.tuneViews addObject: aTuneView];
        [self.scrollView addSubview: aTuneView];
        [self.scrollView setContentSize: CGSizeMake(self.scrollView.frame.size.width, 100 + [self.tuneViews count] * 220)];
        
        [aTuneView setHistogramData: data];
        
        [aTuneView performSelectorOnMainThread:@selector(drawHistogram) withObject:nil waitUntilDone: YES];
        
        
        [self performSelectorOnMainThread:@selector(updatePlaybackButtons) withObject:nil waitUntilDone:NO];
        free(data);
        
        return YES;
    }
    else {
        self.currentlyImporting++;
        [self updatePlaybackButtons];
        
        NSError *error = nil;
        
        NSDictionary *audioSetting = [NSDictionary dictionaryWithObjectsAndKeys:
                                      [NSNumber numberWithFloat: 44100.0], AVSampleRateKey,
                                      [NSNumber numberWithInt: 1], AVNumberOfChannelsKey,
                                      [NSNumber numberWithInt: 16], AVLinearPCMBitDepthKey,
                                      [NSNumber numberWithInt: kAudioFormatLinearPCM], AVFormatIDKey,
                                      [NSNumber numberWithBool: NO], AVLinearPCMIsFloatKey, 
                                      [NSNumber numberWithBool: 0], AVLinearPCMIsBigEndianKey,
                                      [NSNumber numberWithBool: NO], AVLinearPCMIsNonInterleaved,
                                      [NSData data], AVChannelLayoutKey, nil];
        
        
        
        
        // Setup the reader   
        NSURL *url = [item valueForProperty: MPMediaItemPropertyAssetURL];
        AVURLAsset *URLAsset = [AVURLAsset URLAssetWithURL:url options:nil];
        if (!URLAsset)
            return NO;
        
        AVAssetReader *assetReader = [AVAssetReader assetReaderWithAsset:URLAsset error:&error];
        if (error)
            return NO;
        
        NSArray *tracks = [URLAsset tracksWithMediaType:AVMediaTypeAudio];
        if (![tracks count])
            return NO;
        
        AVAssetReaderAudioMixOutput *audioMixOutput = [AVAssetReaderAudioMixOutput
                                                       assetReaderAudioMixOutputWithAudioTracks:tracks
                                                       audioSettings:audioSetting];
        
        if (![assetReader canAddOutput:audioMixOutput])
            return NO;
        
        [assetReader addOutput:audioMixOutput];
        
        if (![assetReader startReading])
            return NO;
        
        
        // Set the writer    
        NSString *title = [item valueForProperty:MPMediaItemPropertyTitle];
        NSArray *docDirs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *docDir = [docDirs objectAtIndex:0];
        NSString *outPath = [[docDir stringByAppendingPathComponent:title]
                             stringByAppendingPathExtension:@"wav"];
        
        NSURL *outURL = [NSURL fileURLWithPath:outPath];

        [self.fileManager removeItemAtURL:outURL error:nil];
        
        AVAssetWriter *assetWriter = [AVAssetWriter assetWriterWithURL:outURL
                                                              fileType: AVFileTypeWAVE
                                                                 error: &error];
        if (error)
            return NO;
        
        AVAssetWriterInput *assetWriterInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio
                                                                                  outputSettings:audioSetting];
        assetWriterInput.expectsMediaDataInRealTime = NO;
        
        if (![assetWriter canAddInput:assetWriterInput])
            return NO;
        
        [assetWriter addInput:assetWriterInput];
        
        if (![assetWriter startWriting])
            return NO;
        
        // add new TuneView
        TuneView *aTuneView = [TuneView new];
        aTuneView.delegate = self;
        aTuneView.center = CGPointMake(self.scrollView.frame.size.width/2.0, [self.tuneViews count] * 220 + 120);
        aTuneView.item = item;
        [aTuneView showMetadata];
        [self.tuneViews addObject: aTuneView];
        [self.scrollView addSubview: aTuneView];
        
        [self.scrollView setContentSize: CGSizeMake(self.scrollView.frame.size.width, 100 + [self.tuneViews count] * 220)];
        
        // Copy process    
        
        [assetWriter startSessionAtSourceTime: kCMTimeZero];
        
        dispatch_queue_t queue = dispatch_queue_create("assetWriterQueue", NULL);
        
        void (^sampleBlock) (void) = ^{
            NSLog (@"start");
            
            FFTSetupD				mFFT;
            DSPDoubleSplitComplex	complexData;
            
            double * histogramData = calloc(40 * 20, sizeof(double));;
            
            NSLog(@"setup done.");
            
            mFFT = vDSP_create_fftsetupD(13, kFFTRadix2);
            
            int sampleCount = 0;
            
            // log2 table for bucketing frequencies
            int freqToBand[8192];
            double baseline = log2(10.76);
            
            for (int j = 0; j < 8192; j++ ) {
                double f = 10.76 * (double)j;
                freqToBand[j] = (int)(3.0 * (log2(f) - baseline));
            }
            
            BOOL once = NO;
            double scaleSamples = 1.0/65536.0;
            double scaleLevels = 0.333;
            double addOne = 1.0;
            double fillWith = 1.0;
            
            int len = 8192;
            
            double real[len] __attribute__ ((aligned (16)));
            double realScaled[len] __attribute__ ((aligned (16)));
            double imag[len] __attribute__ ((aligned (16)));
            double hamm[len] __attribute__ ((aligned (16)));
            
            vDSP_hamm_windowD(hamm, len, 0);
            
            while (1)
            {
                if ([assetWriterInput isReadyForMoreMediaData]) {
                    
                    CMSampleBufferRef sampleBuffer = [audioMixOutput copyNextSampleBuffer];
                    
                    if (sampleBuffer) {
                        //NSLog(@"buffer: %@", sampleBuffer);
                        //[assetWriterInput appendSampleBuffer:sampleBuffer];
                        sampleCount++;
                        
                        AudioBufferList audioBufferList;
                        CMBlockBufferRef blockBuffer;
                        CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(sampleBuffer, NULL, &audioBufferList, sizeof(audioBufferList), NULL, NULL, 0, &blockBuffer);
                        
                        len = audioBufferList.mBuffers[0].mDataByteSize / sizeof(SInt16);
                        
                        vDSP_vflt16D(audioBufferList.mBuffers[0].mData, 1, real, 1, len);
                        
                        vDSP_vclrD(imag,  1, len);
                        vDSP_vclrD(realScaled, 1, len);
                        
                        complexData.realp = realScaled;
                        complexData.imagp = imag;
                        
                        //scaling
                        
                        vDSP_vsmulD(real, 1, &scaleSamples, realScaled, 1, len);
                        if (self.visEnabled) {
                            [aTuneView setPCMData: realScaled];
                        }
                        
                        // windowing
                        vDSP_vmulD(realScaled, 1, hamm, 1, complexData.realp, 1, len);
                        
                        // FFT
                        vDSP_fft_zipD(mFFT, &complexData, 1, (int)log2((double)len), kFFTDirection_Forward);
                        
                        vDSP_zvabsD(&complexData, 1, real, 1, len);
                        
                        // just add once to the real vector, so we don't run into problems with the dB-conversion
                        vDSP_vsaddD(real, 1, &addOne, real, 1, len);
                        
                        // use imag as help vector, filled with 1's
                        vDSP_vfillD(&fillWith, imag, 1, len);
                        
                        vDSP_vdbconD(real, 1, imag, real, 1, len, 1);
                        
                        if (self.visEnabled) {
                            // draw nice lines and spectrum
                            [aTuneView setSpectrumData: real];
                            
                            [aTuneView performSelectorOnMainThread:@selector(drawPCM) withObject:nil waitUntilDone:NO];
                        }
                        
                        vDSP_vsmulD(real, 1, &scaleLevels, real, 1, len);
                        
                        
                        // !!!: hier irgendwas mit dem spektrum tun
                        
                        
                        for (int j = 1; j < len; j++ ) {
                            double power = real[j];
                            double value = histogramData[freqToBand[j]*20+(int)power];
                            
                            histogramData[freqToBand[j]*20+(int)power] = value + 1.0;
                        }
                        
                        CFRelease(blockBuffer);
                        CFRelease(sampleBuffer);
                        
                        if ((sampleCount % 20) == 0) { 
                            [aTuneView performSelectorOnMainThread:@selector(updateProgress) withObject:nil waitUntilDone:NO];
                        }
                    }
                    else {
                        [assetWriterInput markAsFinished];
                        break;
                    }
                }
            }
            
            for (int band = 0; band < 40; band++) {
                for (int intensity = 0; intensity < 20; intensity++) {
                    double normalizedSum = histogramData[band*20 + intensity] / (double)sampleCount;
                    histogramData[band*20 + intensity] = normalizedSum;
                }
            }
            
            [aTuneView setHistogramData: histogramData];
            [self keepHistogramData: histogramData forItem: item];
            
            [aTuneView performSelectorOnMainThread:@selector(drawHistogram) withObject:nil waitUntilDone: YES];
            
            
            vDSP_destroy_fftsetupD(mFFT);
            
            [assetWriter finishWritingWithCompletionHandler:nil];
            
            NSLog (@"finish");
            
            self.currentlyImporting--;
            [self performSelectorOnMainThread:@selector(updatePlaybackButtons) withObject:nil waitUntilDone:NO];
        };
        
        [assetWriterInput requestMediaDataWhenReadyOnQueue:queue usingBlock: sampleBlock];
        
        return YES;
    }
}

- (void)playMPItem:(MPMediaItem*)item {
	NSLog(@"playback!");
	NSURL *url = [item valueForProperty: MPMediaItemPropertyAssetURL];
	if ([self.player currentItem] == nil) {
		self.player = [self.player initWithPlayerItem:[AVPlayerItem playerItemWithURL:url]];
	}
	else {
		[self.player pause];
		[self.player replaceCurrentItemWithPlayerItem:[AVPlayerItem playerItemWithURL:url]];
	}

	[self.player play];
}

- (void)mediaPicker:(MPMediaPickerController *)mediaPicker 
  didPickMediaItems:(MPMediaItemCollection *)mediaItemCollection {
	[self dismissViewControllerAnimated:YES completion:nil];
	for (MPMediaItem* item in mediaItemCollection.items) {
        [self exportItem: item];
	}
}

- (void)mediaPickerDidCancel:(MPMediaPickerController *)mediaPicker {
	[self dismissViewControllerAnimated:YES completion:nil];
}

- (void)showMediaPicker {
	/*
	 * ???: Can we filter the media picker so we don't see m4p files?
	 */
	MPMediaPickerController* mediaPicker = [[MPMediaPickerController alloc] initWithMediaTypes:MPMediaTypeAnyAudio];
	mediaPicker.delegate = self;
	mediaPicker.allowsPickingMultipleItems = YES;
	mediaPicker.prompt = @"Wähl mal paar Lieder aus!";
	[self presentViewController:mediaPicker animated:YES completion:nil];
}

- (void)importTuneFromLibrary {
    
    [self showMediaPicker];
}

- (void)toggleVisualizations {
    if (self.visEnabled) {
        [self.visButton setImage:[UIImage imageNamed:@"PCM_off"] forState:UIControlStateNormal];
    }
    else {
        [self.visButton setImage:[UIImage imageNamed:@"PCM"] forState:UIControlStateNormal];
    }
    self.visEnabled = !self.visEnabled;
}

- (void)updatePlaybackButtons {
    for (TuneView *view in self.tuneViews) {
        if (self.currentlyImporting > 0) {
            [view disablePlaybackButton];
        }
        else {
            [view enablePlaybackButton];
        }
    }
}

- (void)keepHistogramData:(double *)data forItem:(MPMediaItem *)item {
    NSData *histogramData = [NSData dataWithBytes: data length: 800 * sizeof(double)];
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);

	NSString *documentsDirectory = [paths objectAtIndex:0];
    
    NSString *artist = [item valueForProperty: MPMediaItemPropertyArtist];
    NSString *album = [item valueForProperty: MPMediaItemPropertyAlbumTitle];
    NSString *title = [item valueForProperty: MPMediaItemPropertyTitle];
    
    if (artist == nil && [artist length] == 0) {
        artist = @"unknown artist";
    }
    
    if (album == nil && [album length] == 0) {
        album = @"unknown album";
    }
    
    if (title == nil && [title length] == 0) {
        title = @"unknown title";
    }
    
    NSString *uniqueFileName = [NSString stringWithFormat:@"%@-%@-%@.histogram", artist, album, title];
    
    NSString *path = [NSString stringWithFormat:@"%@/%@", documentsDirectory, uniqueFileName];
	
	if ([self.fileManager fileExistsAtPath: path]) {
        [self.fileManager removeItemAtPath: path error: NULL];
	}

    NSLog(@"keeping file %@", path);
    
	BOOL result = [NSKeyedArchiver archiveRootObject: histogramData toFile: path];
    if (!result)
        NSLog(@"could not write!");
    
    
}



- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}


@end

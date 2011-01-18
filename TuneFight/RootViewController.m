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
#include <stdio.h>
#include <math.h>

@implementation RootViewController

- (id)init {
    if ((self=[super init])) {
        tuneViews = [[NSMutableArray alloc] init];
		player = [[AVPlayer alloc] init];			
    }
    return self;
}

#pragma mark - View lifecycle

// Implement loadView to create a view hierarchy programmatically, without using a nib.
- (void)loadView {
	UIView *aView = [[UIView alloc] initWithFrame: CGRectMake(0, 20, 768, 1004)];
    aView.backgroundColor = [UIColor colorWithRed:0.8 green:0.8 blue:0.8 alpha:1];
	
	importButton = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
    importButton.frame = CGRectMake(0, 0, 168, 168);
    importButton.backgroundColor = [UIColor lightGrayColor];
//	importButton.center = CGPointMake(15, 50);
    [importButton setTitle:@"+" forState: UIControlStateNormal];
    [[importButton titleLabel] setFont:[UIFont fontWithName:@"American Typewriter" size:80]];
    [importButton setTitleColor:[UIColor whiteColor] forState: UIControlStateNormal];
    [importButton setTitleColor:[UIColor darkGrayColor] forState: UIControlStateHighlighted];
	[importButton addTarget:self action:@selector(importTuneFromLibrary) forControlEvents:UIControlEventTouchUpInside];
	
	[aView addSubview: importButton];
	
	scrollView = [[UIScrollView alloc] initWithFrame: CGRectMake(168, 00, 600, 1004)];
    scrollView.backgroundColor = [UIColor darkGrayColor];
	scrollView.delegate = self;
	scrollView.maximumZoomScale = 1.0;
	scrollView.minimumZoomScale = 1.0;
	scrollView.contentSize = CGSizeMake(scrollView.frame.size.width, 100 + [tuneViews count] * 200);
	[aView addSubview: scrollView];
	
	self.view = aView;
	
	[aView release];
	
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
	
	NSFileManager *fileManager = [[NSFileManager alloc] init];
	[fileManager removeItemAtURL:outURL error:nil];
	[fileManager release];
	
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
	TuneView *aTuneView = [[[TuneView alloc] init] autorelease];
	aTuneView.delegate = self;
	aTuneView.center = CGPointMake(scrollView.frame.size.width/2.0, [tuneViews count] * 220 + 120);
	aTuneView.item = item;
    [aTuneView showMetadata];
	[tuneViews addObject: aTuneView];
	[scrollView addSubview: aTuneView];
	
	[scrollView setContentSize: CGSizeMake(scrollView.frame.size.width, 100 + [tuneViews count] * 220)];
	
    // Copy process    
    [assetReader retain];
    [assetWriter retain];
    
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
                    
					int len = audioBufferList.mBuffers[0].mDataByteSize / sizeof(SInt16);
                    
                    double real[len] __attribute__ ((aligned (16)));
					double realScaled[len] __attribute__ ((aligned (16)));
					double imag[len] __attribute__ ((aligned (16)));
					double hamm[len] __attribute__ ((aligned (16)));
					
					vDSP_vflt16D(audioBufferList.mBuffers[0].mData, 1, real, 1, len);
                    
					vDSP_vclrD(imag,  1, len);
					vDSP_hamm_windowD(hamm, len, 0);
					vDSP_vclrD(realScaled, 1, len);
					
					complexData.realp = realScaled;
					complexData.imagp = imag;

					//scaling
					double scale = 1.0/65536.0;
					vDSP_vsmulD(real, 1, &scale, realScaled, 1, len);

					// windowing
					vDSP_vmulD(realScaled, 1, hamm, 1, complexData.realp, 1, len);
                    
					// FFT
					vDSP_fft_zipD(mFFT, &complexData, 1, (int)log2((double)len), kFFTDirection_Forward);
					
					vDSP_zvabsD(&complexData, 1, real, 1, len);
					double addOne = 1.0;
					vDSP_vsaddD(real, 1, &addOne, real, 1, len);
					double fillWith = 1.0;
					vDSP_vfillD(&fillWith, imag, 1, len);
					
					vDSP_vdbconD(real, 1, imag, real, 1, len, 1);
					scale = 0.3333;
					vDSP_vsmulD(real, 1, &scale, real, 1, len);
					
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
		
		[aTuneView performSelectorOnMainThread:@selector(drawHistogram) withObject:nil waitUntilDone: YES];

		
		vDSP_destroy_fftsetupD(mFFT);
        
        [assetWriter finishWriting];
        [assetReader release];
        [assetWriter release];
		        
		NSLog (@"finish");
		//return bufferMono;
	};
	
    [assetWriterInput requestMediaDataWhenReadyOnQueue:queue usingBlock: sampleBlock];

    dispatch_release(queue);

    return YES;
}

- (void)playMPItem:(MPMediaItem*)item {
	NSLog(@"playback!");
	NSURL *url = [item valueForProperty: MPMediaItemPropertyAssetURL];
	if ([player currentItem] == nil) {
		[player initWithPlayerItem:[AVPlayerItem playerItemWithURL:url]];
	}
	else {
		[player pause];
		[player replaceCurrentItemWithPlayerItem:[AVPlayerItem playerItemWithURL:url]];
	}

	[player play];
}

- (void)mediaPicker:(MPMediaPickerController *)mediaPicker 
  didPickMediaItems:(MPMediaItemCollection *)mediaItemCollection {
	[self dismissModalViewControllerAnimated:YES];
	for (MPMediaItem* item in mediaItemCollection.items) {
        [self exportItem: item];
	}
}

- (void)mediaPickerDidCancel:(MPMediaPickerController *)mediaPicker {
	[self dismissModalViewControllerAnimated:YES];
}

- (void)showMediaPicker {
	/*
	 * ???: Can we filter the media picker so we don't see m4p files?
	 */
	MPMediaPickerController* mediaPicker = [[[MPMediaPickerController alloc] initWithMediaTypes:MPMediaTypeAnyAudio] autorelease];
	mediaPicker.delegate = self;
	mediaPicker.allowsPickingMultipleItems = YES;
	mediaPicker.prompt = @"Wähl mal paar Lieder aus!";
	[self presentModalViewController:mediaPicker animated:YES];
}

- (void)importTuneFromLibrary {
    
    [self showMediaPicker];
}


- (void)dealloc
{
	[scrollView release];
	[importButton release];
    [player release];
    
    [super dealloc];
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}


@end

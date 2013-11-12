//
//  RootViewController.m
//  TuneFight
//
//  Created by Pit Garbe on 14.01.11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "RootViewController.h"
#import "TuneView.h"
#import "BNRTimeBlock.h"
#import <AudioToolbox/AudioToolbox.h>
#include <Accelerate/Accelerate.h>

@interface RootViewController ()

@property (nonatomic, strong) NSMutableArray        *tuneViews;
@property (nonatomic, strong) IBOutlet UIButton     *importButton;
@property (nonatomic, strong) IBOutlet UIButton     *visButton;

@property (nonatomic, strong) AVPlayer              *player;
@property (strong, nonatomic) IBOutlet UIScrollView *scrollView;

@property (nonatomic, readwrite) BOOL               visEnabled;

@property (nonatomic, strong) NSFileManager         *fileManager;
@property (nonatomic) FFTSetupD                     mFFT;
@property (nonatomic, strong) NSOperationQueue      *operationQueue;

@end

@implementation RootViewController {
    dispatch_queue_t importQueue;
}


- (id)initWithCoder:(NSCoder *)aDecoder {
    if ((self = [super initWithCoder:aDecoder])) {
        self.tuneViews  = [NSMutableArray new];
        self.player     = [AVPlayer new];

        // enable visualisations per default
        // speedup goes down to 5.15 (thank you, glowing shadow of awesome!) from 9.0 (measured on iPad 1)
        self.visEnabled     = YES;
        self.fileManager    = [NSFileManager defaultManager];

        self.operationQueue = [NSOperationQueue new];
        [self.operationQueue addObserver:self forKeyPath:@"operationCount" options:0 context:NULL];

        // only create this once!
        self.mFFT = vDSP_create_fftsetupD(13, kFFTRadix2);

        AVAudioSession  *session    = [AVAudioSession sharedInstance];
        NSError         *error      = nil;
        if (![session setCategory:AVAudioSessionCategorySoloAmbient error:&error]) {
            NSLog(@"Couldn't set audio session category: %@", error);
        }
        if (![session setActive:YES error:&error]) {
            NSLog(@"Couldn't make audio session active: %@", error);
        }
    }
    return self;
}

- (void)dealloc {
    vDSP_destroy_fftsetupD(self.mFFT);
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"operationCount"]) {
        [self updatePlaybackButtons];
    }
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

#pragma mark -

- (BOOL)exportItem:(MPMediaItem *)item {
    NSArray     *paths              = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);

    NSString    *documentsDirectory = paths[0];

    NSString    *artist             = [item valueForProperty:MPMediaItemPropertyArtist];
    NSString    *album              = [item valueForProperty:MPMediaItemPropertyAlbumTitle];
    NSString    *title              = [item valueForProperty:MPMediaItemPropertyTitle];

    if (artist == nil && [artist length] == 0) {
        artist = @"unknown artist";
    }

    if (album == nil && [album length] == 0) {
        album = @"unknown album";
    }

    if (title == nil && [title length] == 0) {
        title = @"unknown title";
    }

    [self updatePlaybackButtons];

    NSString    *uniqueFileName = [NSString stringWithFormat:@"%@-%@-%@.histogram", artist, album, title];
    NSString    *path           = [NSString stringWithFormat:@"%@/%@", documentsDirectory, uniqueFileName];

    // add new TuneView
    TuneView *aTuneView = [TuneView new];
    aTuneView.delegate  = self;
    aTuneView.center    = CGPointMake(self.scrollView.frame.size.width / 2.0, [self.tuneViews count] * 220 + 120);
    aTuneView.item      = item;
    [aTuneView showMetadata];
    [self.tuneViews addObject:aTuneView];
    [self.scrollView addSubview:aTuneView];
    [self.scrollView setContentSize:CGSizeMake(self.scrollView.frame.size.width, 100 + [self.tuneViews count] * 220)];
    //    [aTuneView enableShadows:NO];

    if ([self.fileManager fileExistsAtPath:path]) {
        NSLog(@"file %@ exists", path);

        NSData  *histogramData  = [NSKeyedUnarchiver unarchiveObjectWithFile:path];
        double  *data           = calloc(800, sizeof(double));
        [histogramData getBytes:data length:800 * sizeof(double)];

        [aTuneView setHistogramData:data];
        free(data);

        dispatch_async(dispatch_get_main_queue(), ^{
            [aTuneView drawHistogram];
        });

        return YES;
    }
    else {
        NSError         *error          = nil;

        NSDictionary    *audioSetting   = @{ AVSampleRateKey: @44100.0f,
                                             AVNumberOfChannelsKey: @1,
                                             AVLinearPCMBitDepthKey: @16,
                                             AVFormatIDKey: @(kAudioFormatLinearPCM),
                                             AVLinearPCMIsFloatKey: @NO,
                                             AVLinearPCMIsBigEndianKey: [NSNumber numberWithBool:0],
                                             AVLinearPCMIsNonInterleaved: @NO,
                                             AVChannelLayoutKey: [NSData data] };

        // Setup the reader
        NSURL       *url        = [item valueForProperty:MPMediaItemPropertyAssetURL];
        AVURLAsset  *URLAsset   = [AVURLAsset URLAssetWithURL:url options:nil];
        if (!URLAsset) {
            return NO;
        }

        AVAssetReader *assetReader = [AVAssetReader assetReaderWithAsset:URLAsset error:&error];
        if (error) {
            return NO;
        }

        NSArray *tracks = [URLAsset tracksWithMediaType:AVMediaTypeAudio];
        if (![tracks count]) {
            return NO;
        }

        AVAssetReaderAudioMixOutput *audioMixOutput = [AVAssetReaderAudioMixOutput
                                                       assetReaderAudioMixOutputWithAudioTracks:tracks
                                                       audioSettings                           :audioSetting];

        if (![assetReader canAddOutput:audioMixOutput]) {
            return NO;
        }

        [assetReader addOutput:audioMixOutput];

        if (![assetReader startReading]) {
            return NO;
        }

        void (^sampleBlock) (void) = ^{
            // prepare some buckets for the frequencies, basically calculate some logarithms once as a lookup table
            int     freqToBand[8192];
            double  baseline = log2(10.76);

            for (int j = 0; j < 8192; j++) {
                double f = 10.76 * (double)j;
                freqToBand[j] = (int)(3.0 * (log2(f) - baseline));
            }

            DSPDoubleSplitComplex complexData;

            // 2D histogram, 40 columns by 20 rows
            double  *histogramData  = calloc(40 * 20, sizeof(double));

            int     sampleCount     = 0;

            double  scaleSamples    = 1.0 / 65536.0;
            double  scaleLevels     = 0.333;
            double  addOne          = 1.0;
            double  fillWith        = 1.0;

            int     len             = 8192;
            int     log2Len         = log2(len);
            double  real[len] __attribute__((aligned(16)));
            double  realScaled[len] __attribute__((aligned(16)));
            double  imag[len] __attribute__((aligned(16)));
            double  hamm[len] __attribute__((aligned(16)));

            vDSP_hamm_windowD(hamm, len, 0);

            CMSampleBufferRef sampleBuffer;

            while ([assetReader status] == AVAssetReaderStatusReading) {
                sampleBuffer = [audioMixOutput copyNextSampleBuffer];

                if (sampleBuffer) {
                    sampleCount++;

                    AudioBufferList     audioBufferList;
                    CMBlockBufferRef    blockBuffer;
                    CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(sampleBuffer,
                                                                            NULL,
                                                                            &audioBufferList,
                                                                            sizeof(audioBufferList),
                                                                            NULL,
                                                                            NULL,
                                                                            0,
                                                                            &blockBuffer);

                    len = audioBufferList.mBuffers[0].mDataByteSize / sizeof(SInt16);

                    vDSP_vflt16D(audioBufferList.mBuffers[0].mData, 1, real, 1, len);

                    vDSP_vclrD(imag,  1, len);
                    vDSP_vclrD(realScaled, 1, len);

                    complexData.realp   = realScaled;
                    complexData.imagp   = imag;

                    //scaling
                    vDSP_vsmulD(real, 1, &scaleSamples, realScaled, 1, len);
                    if (self.visEnabled) {
                        [aTuneView setPCMData:realScaled];
                    }

                    // windowing
                    vDSP_vmulD(realScaled, 1, hamm, 1, complexData.realp, 1, len);

                    // FFT
                    vDSP_fft_zipD(self.mFFT, &complexData, 1, log2Len, kFFTDirection_Forward);

                    // absolute values of complex vectors
                    vDSP_zvabsD(&complexData, 1, real, 1, len);

                    // just add one to the real vector, so we don't run into problems with the dB-conversion
                    vDSP_vsaddD(real, 1, &addOne, real, 1, len);

                    // use imag as help vector, filled with 1's
                    vDSP_vfillD(&fillWith, imag, 1, len);

                    // dB conversion
                    vDSP_vdbconD(real, 1, imag, real, 1, len, 1);

                    if (self.visEnabled) {
                        // draw nice lines and spectrum
                        [aTuneView setSpectrumData:real];
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [aTuneView drawPCM];
                        });
                    }

                    vDSP_vsmulD(real, 1, &scaleLevels, real, 1, len);


                    // !!!: hier etwas tolles mit dem spektrum tun

                    //
                    for (int j = 1; j < len; j++) {
                        int power           = (int)real[j];  // power equals the vertical position in the column, low power is at the bottom
                        int band            = freqToBand[j]; // band equals the column in the histogram
                        int linearPosition  = band * 20 + power;

                        histogramData[linearPosition] = histogramData[linearPosition] + 1.0;
                    }

                    CFRelease(blockBuffer);
                    CFRelease(sampleBuffer);

                    if ((sampleCount % 100) == 0) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [aTuneView updateProgress:100];
                        });
                    }
                }
            }

            // normalize by sample count
            double *originalData = malloc(40 * 20 * sizeof(double));
            memcpy(originalData, histogramData, 40*20);

            LWSBenchBlock("for loop Division                               ", ^{
                for (int pos = 0; pos < 40 * 20; pos++) {
                    double normalizedSum = histogramData[pos] / (double)sampleCount;
                    histogramData[pos] = normalizedSum;
                }
                memcpy(histogramData, originalData, 40*20);
            }, 100000);


            LWSBenchBlock("vDSP Division with malloc in benchmark          ", ^{
                double *resampled = malloc(40 * 20 * sizeof(double));
                const double divisor = sampleCount;
                vDSP_vsdivD(histogramData, 1, &divisor, resampled, 1, 40*20);
                memcpy(histogramData, originalData, 40*20);
                free(resampled);
            }, 100000);

            double *resampled = malloc(40 * 20 * sizeof(double));
            LWSBenchBlock("vDSP Division with malloc removed from benchmark", ^{
                const double divisor = sampleCount;
                vDSP_vsdivD(histogramData, 1, &divisor, resampled, 1, 40*20);
                memcpy(histogramData, originalData, 40*20);
            }, 100000);

            resampled = malloc(40 * 20 * sizeof(double));
            const double divisor = sampleCount;
            vDSP_vsdivD(histogramData, 1, &divisor, resampled, 1, 40*20);
            memcpy(histogramData, resampled, 40*20);

            free(resampled);

            [aTuneView setHistogramData:histogramData];
            [self keepHistogramData:histogramData forItem:item];

            free(histogramData);

            dispatch_async(dispatch_get_main_queue(), ^{
                [aTuneView drawHistogram];
            });
        };

        [self.operationQueue addOperation:[NSBlockOperation blockOperationWithBlock:sampleBlock]];

        return YES;
    }
}

- (void)playMPItem:(MPMediaItem *)item {
    NSURL *url = [item valueForProperty:MPMediaItemPropertyAssetURL];
    if ([self.player currentItem] == nil) {
        self.player = [self.player initWithPlayerItem:[AVPlayerItem playerItemWithURL:url]];
    }
    else {
        [self.player pause];
        [self.player replaceCurrentItemWithPlayerItem:[AVPlayerItem playerItemWithURL:url]];
    }

    [self.player play];
}

- (void)mediaPicker         :(MPMediaPickerController *)mediaPicker
        didPickMediaItems   :(MPMediaItemCollection *)mediaItemCollection {
    [self dismissViewControllerAnimated:YES completion:nil];
    for (MPMediaItem *item in mediaItemCollection.items) {
        [self exportItem:item];
    }
}

- (void)mediaPickerDidCancel:(MPMediaPickerController *)mediaPicker {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)showMediaPicker {
    /*
     * ???: Can we filter the media picker so we don't see m4p files?
     */
    MPMediaPickerController *mediaPicker = [[MPMediaPickerController alloc] initWithMediaTypes:MPMediaTypeAnyAudio];
    mediaPicker.delegate                    = self;
    mediaPicker.allowsPickingMultipleItems  = YES;
    mediaPicker.showsCloudItems             = NO;
    mediaPicker.prompt                      = @"Wähl mal paar Lieder aus!";
    [mediaPicker loadView];
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
    SEL makeItSo;
    if (self.operationQueue.operationCount > 0) {
        makeItSo = @selector(disablePlaybackButton);
    }
    else {
        makeItSo = @selector(enablePlaybackButton);
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tuneViews makeObjectsPerformSelector:makeItSo];
    });
}

- (void)keepHistogramData:(double *)data forItem:(MPMediaItem *)item {
    NSData      *histogramData      = [NSData dataWithBytes:data length:800 * sizeof(double)];

    NSArray     *paths              = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);

    NSString    *documentsDirectory = paths[0];

    NSString    *artist             = [item valueForProperty:MPMediaItemPropertyArtist];
    NSString    *album              = [item valueForProperty:MPMediaItemPropertyAlbumTitle];
    NSString    *title              = [item valueForProperty:MPMediaItemPropertyTitle];

    if (artist == nil && [artist length] == 0) {
        artist = @"unknown artist";
    }

    if (album == nil && [album length] == 0) {
        album = @"unknown album";
    }

    if (title == nil && [title length] == 0) {
        title = @"unknown title";
    }

    NSString    *uniqueFileName = [NSString stringWithFormat:@"%@-%@-%@.histogram", artist, album, title];

    NSString    *path           = [NSString stringWithFormat:@"%@/%@", documentsDirectory, uniqueFileName];

    if ([self.fileManager fileExistsAtPath:path]) {
        [self.fileManager removeItemAtPath:path error:NULL];
    }

    NSLog(@"keeping file %@", path);

    BOOL result = [NSKeyedArchiver archiveRootObject:histogramData toFile:path];
    if (!result)
        NSLog(@"could not write!");
}

- (BOOL)shouldAutorotate {
    return YES;
}

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];

    // Release any cached data, images, etc that aren't in use.
}

@end

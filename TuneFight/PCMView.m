//
//  PCMView.m
//  TuneFight
//
//  Created by Pit Garbe on 18.01.11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "PCMView.h"


@implementation PCMView {
    double * waveform;
    double * spectrum;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        waveform = calloc(4096, sizeof(double));
        for (int i = 0; i < 4096; i++) {
            waveform[i] = 0.0;
        }

        spectrum = calloc(4096, sizeof(double));
        for (int i = 0; i < 4096; i++) {
            spectrum[i] = 0.0;
        }
        
        self.shadowsEnabled = YES;
    }
    return self;
}

- (void)setWaveform:(double *)data {
    waveform = memcpy(waveform, data, 4096*sizeof(double));
}

- (void)setSpectrum:(double *)data {
    spectrum = memcpy(spectrum, data, 4096*sizeof(double));;
}

- (void)drawRect:(CGRect)rect {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
	CGContextScaleCTM(ctx, 1.0, -1.0);
	CGContextTranslateCTM(ctx, 0, -(rect.size.height));
	    
 //   CGContextBeginPath(ctx);
   
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathMoveToPoint(path, NULL, 0, 150 + 1.5 * waveform[0]);
        
    for (int sample = 8; sample < 4096; sample += 8) {
		double amplitude = 40 * waveform[sample];
        CGPathAddLineToPoint(path, NULL, sample/10.24, 150 + amplitude);
	}
    
    CGContextAddPath(ctx, path);
    CGContextSetLineWidth(ctx, 0.5);
    CGContextSetStrokeColorWithColor(ctx, [UIColor whiteColor].CGColor);
    if (_shadowsEnabled) {
        CGContextSetShadowWithColor(ctx, CGSizeMake(0, 0), 4, [UIColor whiteColor].CGColor);
    }
    CGContextStrokePath(ctx);
    
    
    CGContextSetFillColorWithColor(ctx, [UIColor whiteColor].CGColor);

    if (_shadowsEnabled) {
        CGContextSetShadowWithColor(ctx, CGSizeMake(0, 0), 10, [UIColor whiteColor].CGColor);
    }

    for (int sample = 0; sample < 4096; sample += 64) {
		double level = 0;
        for (int l = 0; l < 64; l++) {
            level += spectrum[sample+l];
        }
        level = level / 64;
        
        CGContextFillRect(ctx, CGRectMake(sample/10.24, 0, 6, level));
	}

}


- (void)dealloc
{
    free(spectrum);
    free(waveform);
}

@end

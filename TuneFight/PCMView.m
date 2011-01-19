//
//  PCMView.m
//  TuneFight
//
//  Created by Pit Garbe on 18.01.11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "PCMView.h"


@implementation PCMView

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
        
        once = NO;
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
	CGContextSetStrokeColorWithColor(ctx, [UIColor whiteColor].CGColor);
        
    CGContextBeginPath(ctx);
    CGContextMoveToPoint(ctx, 0, 150 + 1.5 * waveform[0]);
	
    for (int sample = 8; sample < 4096; sample += 8) {
		double amplitude = 40 * waveform[sample];
        CGContextAddLineToPoint(ctx, sample/10.24, 150 + amplitude);
	}
    CGContextSetLineWidth(ctx, 0.5);
    CGContextStrokePath(ctx);
    
    CGContextSetFillColorWithColor(ctx, [UIColor whiteColor].CGColor);
    
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
    [super dealloc];
}

@end

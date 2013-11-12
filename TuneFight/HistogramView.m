//
//  HistogramView.m
//  TuneFight
//
//  Created by Pit Garbe on 16.01.11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "HistogramView.h"
#import <QuartzCore/QuartzCore.h>


@implementation HistogramView {
	double * histogram;

	UIView *exponentView;
	UILabel *exponentLabel;

	double exponent;
	CGPoint touchDown;
}

- (id)initWithFrame:(CGRect)frame {
    
    self = [super initWithFrame:frame];
    if (self) {
        exponent = 0.25;
		exponentView = [[UIView alloc] initWithFrame: CGRectMake(0, 0, 200, 50)];
		exponentView.center = CGPointMake(frame.size.width/2.0, frame.size.height/2.0);
		
		CALayer *layer = [CALayer new];
		layer.frame = [exponentView bounds];
		CGColorRef bgColor = [UIColor colorWithRed:0.9 green:0.9 blue:0.2 alpha:0.3].CGColor;
		layer.backgroundColor = bgColor;
		layer.cornerRadius = 22.0;
		layer.borderWidth = 0.0;
		[exponentView.layer addSublayer: layer];
		
		exponentLabel = [[UILabel alloc] initWithFrame:CGRectMake(0.0, 0, 200, 50)];
		exponentLabel.adjustsFontSizeToFitWidth = YES;
		exponentLabel.textAlignment = NSTextAlignmentCenter;
		exponentLabel.font = [UIFont boldSystemFontOfSize:20];
		exponentLabel.backgroundColor = [UIColor clearColor];
		exponentLabel.textColor = [UIColor lightGrayColor];
		exponentLabel.shadowColor = [UIColor colorWithWhite:0.0 alpha:0.7];
		exponentLabel.shadowOffset = CGSizeMake(0, 1.0);
		exponentLabel.text = [NSString stringWithFormat:@"Exponent = %.2f", exponent];
		[exponentView addSubview: exponentLabel];
		
		exponentView.alpha = 0.0;
        
        histogram = calloc(40 * 20, sizeof(double));
        for (int i = 0; i < 800; i++) {
            histogram[i] = 0.0;
        }
        
		[self addSubview: exponentView];
		
    }
    return self;
}

- (void)setHistogramData:(double *)data {
    histogram = memcpy(histogram, data, 800*sizeof(double));
}

// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
	CGContextRef ctx = UIGraphicsGetCurrentContext();
	CGContextScaleCTM(ctx, 1.0, -1.0);
	CGContextTranslateCTM(ctx, 0, -(rect.size.height));
	CGContextSetFillColorWithColor(ctx, self.backgroundColor.CGColor);

	for (int band = 0; band < 40; band++) {
		for (int intensity = 0; intensity < 20; intensity++) {
			double sum = histogram[band*20 + intensity];
			sum = pow(sum, exponent);
			CGContextSetFillColorWithColor(ctx, [UIColor colorWithWhite:1.0 alpha: sum].CGColor);
			CGContextFillRect(ctx, CGRectMake(band*(rect.size.width/40), intensity*(rect.size.height/20), rect.size.width/40, rect.size.height/20));
			//NSLog(@"x = %d  y = %d", band, intensity);
		}
	}
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
	UITouch *touch = [touches anyObject];
	touchDown = [touch locationInView: self];
	
	[UIView animateWithDuration: 0.2
						  delay: 0
						options: UIViewAnimationOptionCurveEaseOut + UIViewAnimationOptionAllowUserInteraction
					 animations: ^{
						 exponentView.alpha = 1.0;
					 }
					 completion: NULL
	 ];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
	UITouch *touch = [touches anyObject];
	CGPoint touchMoved = [touch locationInView: self];
	double xDistance = touchMoved.x - touchDown.x;
	exponent = 0.25 + (xDistance * xDistance * xDistance / 5000000.0);

	exponentLabel.text = [NSString stringWithFormat:@"Exponent = %.2f", exponent];
	[self setNeedsDisplay];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
	[UIView animateWithDuration: 0.2
						  delay: 0
						options: UIViewAnimationOptionCurveEaseOut + UIViewAnimationOptionAllowUserInteraction
					 animations: ^{
						 exponentView.alpha = 0.0;
					 }
					 completion: NULL
	 ];	
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
	[UIView animateWithDuration: 0.2
						  delay: 0
						options: UIViewAnimationOptionCurveEaseOut + UIViewAnimationOptionAllowUserInteraction
					 animations: ^{
						 exponentView.alpha = 0.0;
					 }
					 completion: NULL
	 ];	
}

- (void)dealloc {
    free(histogram);
}


@end

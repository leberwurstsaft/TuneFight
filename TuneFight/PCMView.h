//
//  PCMView.h
//  TuneFight
//
//  Created by Pit Garbe on 18.01.11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface PCMView : UIView

@property (nonatomic) BOOL shadowsEnabled;

- (void)setWaveform:(double *)data;
- (void)setSpectrum:(double *)data;


@end

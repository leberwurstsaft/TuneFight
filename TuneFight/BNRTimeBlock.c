//
//  BNRTimeBlock.c
//  ReportApp
//
//  Created by Pit Garbe on 18.09.12.
//  Copyright (c) 2012 Pit Garbe. All rights reserved.
//

#include <stdio.h>

#import <mach/mach_time.h>
#import "BNRTimeBlock.h"

void BNRTimeBlock (const char* ident, void (^block)(void)) {
    mach_timebase_info_data_t info;
    if (mach_timebase_info(&info) != KERN_SUCCESS) return; // -1.0;
    
    uint64_t start = mach_absolute_time ();
    block ();
    uint64_t end = mach_absolute_time ();
    uint64_t elapsed = end - start;
    
    uint64_t nanos = elapsed * info.numer / info.denom;
    
    printf ("[%s] time: %f\n", ident, (double)((double)nanos/(double)NSEC_PER_MSEC));
    //    return (CGFloat)nanos / NSEC_PER_SEC;
    
} // BNRTimeBlock


void LWSBenchBlock (const char* identifier, void (^block)(void), int iterations) {
    mach_timebase_info_data_t info;
    if (mach_timebase_info(&info) != KERN_SUCCESS) return; // -1.0;

    int i = 0;
    uint64_t start = mach_absolute_time ();

    for (i = 0; i<iterations; i++) {
        block ();
    }
    
    uint64_t end = mach_absolute_time ();
    uint64_t elapsed = end - start;

    uint64_t nanos = elapsed * info.numer / info.denom;

    printf ("BENCHMARK RESULT: [%s] avg time (%d iterations): %f  total time: %f\n", identifier, iterations, (double)(((double)nanos/iterations) / (double)NSEC_PER_MSEC), (double)((double)nanos / (double)NSEC_PER_MSEC));
}
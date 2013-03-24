//
//  main.m
//  NWSchedulingTest
//
//  Created by Nathan W on 3/23/13.
//
//

#import <Foundation/Foundation.h>
#import "NWScheduling.h"
#import <mach/mach.h>
#import <mach/mach_time.h>

@interface SchedulingTest : NSObject

@property (nonatomic) NSTimeInterval absEnd;
@property (nonatomic) long double absToNs;

- (void)timerFire;
- (void)timerFireWithString:(NSString *)string;
- (void)noFire;

@end

@implementation SchedulingTest

- (id)init {
    if (self = [super init]) {
        mach_timebase_info_data_t tbdata;
        mach_timebase_info(&tbdata);
        _absToNs = ((long double) tbdata.numer) / ((long double) tbdata.denom) * 1000000000;
    }
    return self;
}

- (void)timerFire {
    NSLog(@"Timer was fired!");
    _absEnd = mach_absolute_time();
    //NSLog(@"%lf",_end);
}

- (void)timerFireWithString:(NSString *)string {
    NSLog(@"Timer fired: %@",string);
    //_end = mach_absolute_time() * _absToNs;
}

- (void)noFire {
    NSLog(@"This should not have been logged!");
}

@end

int main(int argc, const char * argv[])
{

    @autoreleasepool {
        SchedulingTest *test = [[SchedulingTest alloc] init];
        mach_timebase_info_data_t tbdata;
        mach_timebase_info(&tbdata);
        long double absToNs = ((long double) tbdata.numer) / ((long double) tbdata.denom);
        
        for (int i = 0; i < 5; i++) {
            NSTimeInterval duration = ((double)rand() / RAND_MAX) * 5.0; //returns ratio of random number and multipies it
            NSLog(@"\n\nTimer will run for %f seconds.",duration);
            
            NSTimeInterval start = mach_absolute_time() * absToNs;
            
            [NWScheduler scheduleEvent:@selector(timerFire) target:test inSeconds:duration];
        
            [NSThread sleepForTimeInterval:duration + 0.1];
            NSTimeInterval end = (test.absEnd) * absToNs;
            NSLog(@"%lfs",((end - start) / 1000000000) - duration);
            
            //printf("NWScheduler thread deviation: %f\n",(test.end - start) - duration);
        }
        
    }
    return 0;
}


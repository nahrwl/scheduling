//
//  main.m
//  NWSchedulingTest
//
//  Created by Nathan W on 3/23/13.
//
//

#import <Foundation/Foundation.h>
#import "NWScheduling.h"

@interface SchedulingTest : NSObject

- (void)timerFire;
- (void)timerFireWithString:(NSString *)string;
- (void)noFire;

@end

@implementation SchedulingTest

- (void)timerFire {
    NSLog(@"Timer was fired!");
}

- (void)timerFireWithString:(NSString *)string {
    NSLog(@"Timer fired: %@",string);
}

- (void)noFire {
    NSLog(@"This should not have been logged!");
}

@end

int main(int argc, const char * argv[])
{

    @autoreleasepool {
        SchedulingTest *test = [[SchedulingTest alloc] init];
        NSTimeInterval duration = 1.0;
        [NWScheduler scheduleEvent:@selector(timerFire) target:test inSeconds:duration];
        [NSThread sleepForTimeInterval:1];
        //[NWScheduler scheduleEvent:@selector(timerFire) target:test inSeconds:10];
        
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:duration + 0.1]];
        
    }
    return 0;
}


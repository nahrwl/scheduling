//
//  NWScheduler.h
//  NWScheduling
//
//  Created by Nathan W on 3/23/13.
//
//

#import <Foundation/Foundation.h>

@interface NWScheduler : NSObject

+ (void)scheduleEvent:(SEL)event target:(id)target inSeconds:(NSTimeInterval)seconds;
+ (void)scheduleEvent:(SEL)event target:(id)target withObject:(id)object inSeconds:(NSTimeInterval)seconds;

+ (void)scheduleEvent:(SEL)event target:(id)target inNanoseconds:(UInt64)ns;
+ (void)scheduleEvent:(SEL)event target:(id)target withObject:(id)object inNanoseconds:(UInt64)ns;

// Will return a BOOL indicating if cancellation was successful (YES for success)
+ (BOOL)cancelEvent:(SEL)event target:(id)target;
+ (BOOL)cancelEvent:(SEL)event target:(id)target withObject:(id)object;

// Add some boolean for persistance?


@end

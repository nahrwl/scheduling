//
//  NWScheduler.m
//  NWScheduling
//
//  Created by Nathan W on 3/23/13.
//
//

#import "NWScheduler.h"
#import <mach/mach.h>
#import <mach/mach_time.h>
#import <libkern/OSAtomic.h>
#import "pthread.h"

// the shared singleton instance
static NWScheduler *_sharedScheduler;

// conversion factor for mach_absolute_time()
static volatile long double kAbsoluteToNanosecondsRatio;

// event dictionary keys
static NSString *kSelectorKey = @"selector";
static NSString *kTargetKey = @"target";
static NSString *kObjectKey = @"object";
static NSString *kTimeKey = @"nanoseconds";

#define kSpinlockTime = 0.01;

@interface NWScheduler () {
    //OSSpinLock spinlock;
    pthread_mutex_t mutex;
    pthread_cond_t condition;
}

@property (retain) NSMutableArray *schedule;
@property (retain) pthread_t eventThread;

// Define instance method counterparts to public class methods
// No need for the ..inSeconds: methods because we'll just convert to nanoseconds
- (void)scheduleEvent:(SEL)event target:(id)target inNanoseconds:(UInt64)ns;
- (void)scheduleEvent:(SEL)event target:(id)target withObject:(id)object inNanoseconds:(UInt64)ns;

- (BOOL)cancelEvent:(SEL)event target:(id)target;
- (BOOL)cancelEvent:(SEL)event target:(id)target withObject:(id)object;

- (void)addEvent:(NSDictionary *)newEvent;
- (BOOL)removeEvent:(NSDictionary *)oldEvent;

@end

@implementation NWScheduler
@synthesize schedule = _schedule;

#pragma mark - Main thread -
#pragma mark Public Methods

+ (void)scheduleEvent:(SEL)event target:(id)target inSeconds:(NSTimeInterval)seconds {
    if (!_sharedScheduler) _sharedScheduler = [[NWScheduler alloc] init];
    [_sharedScheduler scheduleEvent:event target:target inNanoseconds:(UInt64)(seconds * 1000000000)];
}

+ (void)scheduleEvent:(SEL)event target:(id)target withObject:(id)object inSeconds:(NSTimeInterval)seconds {
    if (!_sharedScheduler) _sharedScheduler = [[NWScheduler alloc] init];
    [_sharedScheduler scheduleEvent:event target:target withObject:object inNanoseconds:(UInt64)(seconds * 1000000000)]
}

+ (void)scheduleEvent:(SEL)event target:(id)target inNanoseconds:(UInt64)ns {
    if (!_sharedScheduler) _sharedScheduler = [[NWScheduler alloc] init];
    [_sharedScheduler scheduleEvent:event target:target inNanoseconds:ns];
}

+ (void)scheduleEvent:(SEL)event target:(id)target withObject:(id)object inNanoseconds:(UInt64)ns {
    if (!_sharedScheduler) _sharedScheduler = [[NWScheduler alloc] init];
    [_sharedScheduler scheduleEvent:event target:target withObject:object inNanoseconds:ns];
}

+ (BOOL)cancelEvent:(SEL)event target:(id)target {
    if (!_sharedScheduler) _sharedScheduler = [[NWScheduler alloc] init];
    [_sharedScheduler cancelEvent:event target:target];
}

+ (BOOL)cancelEvent:(SEL)event target:(id)target withObject:(id)object {
    if (!_sharedScheduler) _sharedScheduler = [[NWScheduler alloc] init];
    [_sharedScheduler cancelEvent:event target:target withObject:object];
}

#pragma mark Private methods

- (void)scheduleEvent:(SEL)event target:(id)target inNanoseconds:(UInt64)ns {
    UInt64 absTime = (mach_absolute_time() + (ns / kAbsoluteToNanosecondsRatio));
    NSDictionary *newEvent = [NSDictionary dictionaryWithObjectsAndKeys:
                              [NSNumber numberWithUnsignedLongLong:absTime], kTimeKey,
                              NSStringFromSelector(event), kSelectorKey,
                              target, kTargetKey, nil];
    [self addEvent:newEvent];
    
}

- (void)scheduleEvent:(SEL)event target:(id)target withObject:(id)object inNanoseconds:(UInt64)ns {
    UInt64 absTime = (mach_absolute_time() + (ns / kAbsoluteToNanosecondsRatio));
    NSDictionary *newEvent = [NSDictionary dictionaryWithObjectsAndKeys:
                              [NSNumber numberWithUnsignedLongLong:absTime], kTimeKey,
                              NSStringFromSelector(event), kSelectorKey,
                              target, kTargetKey,
                              object, kObjectKey, nil];
    [self addEvent:newEvent];}

- (void)addEvent:(NSDictionary *)newEvent {
    BOOL needsWake = NO;
    int i = 0;
    // insert the event into the array, but remember to lock
    pthread_mutex_lock(&mutex); // try and minimize the amount of code that executes inside lock
    // add event at the correct place by time
    while (absTime > [(NSNumber *)[(NSDictionary *)[_schedule objectAtIndex:i] objectForKey:kTimeKey] unsignedLongLongValue]) {
        i++;
    }
    [_schedule insertObject:newEvent atIndex:i];
    if (([_schedule count] > 0) && ([newEvent isEqualToDictionary:[_schedule objectAtIndex:0]]))
        needsWake = YES;
    pthread_mutex_unlock(&mutex);
    
    // check if our event will occur before the first event
    // wake the thread from sleeping if it needs to look at our new event first
    if (needsWake) {
        // wake the thread
#warning Wake unimplemented
    }
    
}

- (BOOL)cancelEvent:(SEL)event target:(id)target {
    
}

- (BOOL)cancelEvent:(SEL)event target:(id)target withObject:(id)object {
    
}


- (id)init {
    // Basic setup here
    // First, set the conversion factor
    mach_timebase_info_data_t tbdata;
    mach_timebase_info(&tbdata);
    kAbsoluteToNanosecondsRatio = ((long double) tbdata.numer) / ((long double) tbdata.denom);
    
    pthread_mutex_init(&mutex, NULL);
    pthread_cond_init(&condition, NULL);
    
    
    _schedule = [[NSMutableArray alloc] init];
}

#pragma mark - Timer thread -

- (void)thread {
    signal(SIGALRM, <#void (*)(int)#>)
    // Lock the mutex.
    pthread_mutex_lock(&mutex);
    
    while (YES) {
        while ([_schedule count] == 0) {
            pthread_cond_wait(&condition, &mutex);
        }
        
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSDictionary *upcomingEvent = [_schedule objectAtIndex:0];
        UInt64 absTime = [[upcomingEvent objectForKey:kTimeKey] unsignedLongLongValue];
        
        pthread_mutex_unlock(&mutex);
        
        // sleep until we have to spinlock
        uint46_t wakeTime = (absTime - (kSpinlockTime / kAbsoluteToNanosecondsRatio));
        mach_wait_until(wakeTime);
        
        // make sure we haven't woken up early
        if (mach_absolute_time() > wakeTime) {
            
            while (mach_absolute_time() < absTime); //wait until it's time to send the message
            
            id targetObject = [upcomingEvent objectForKey:kTargetKey];
            SEL selector = NSSelectorFromString([upcomingEvent objectForKey:kSelectorKey]);
            if ([upcomingEvent objectForKey:kObjectKey]) {
                [targetObject performSelector:selector
                                   withObject:[upcomingEvent objectForKey:kObjectKey]];
            }
            else {
                [targetObject performSelector:selector];
            }
            // lock the mutex once more
            pthread_mutex_lock(&mutex);
            [_schedule removeObject:upcomingEvent];
        }
        else {
            // lock the mutex once more
            pthread_mutex_lock(&mutex);
        }
        
        
        [pool drain];
    }
}

@end

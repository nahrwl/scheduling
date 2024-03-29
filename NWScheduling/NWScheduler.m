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
#import "pthread.h"

// the shared instance
static NWScheduler *_sharedScheduler = nil;

// conversion factor for mach_absolute_time()
static volatile long double kAbsoluteToNanosecondsRatio;

// event dictionary keys
static NSString *kSelectorKey = @"selector";
static NSString *kTargetKey = @"target";
static NSString *kObjectKey = @"object";
static NSString *kTimeKey = @"nanoseconds";

#define kSpinlockTime 0.01

@interface NWScheduler () {
    NSCondition *condition;
    NSMutableArray *_schedule;
    pthread_t eventThread;
}

// Define instance method counterparts to public class methods
// No need for the ..inSeconds: methods because we'll just convert to nanoseconds
- (void)scheduleEvent:(SEL)event target:(id)target inNanoseconds:(UInt64)ns;
- (void)scheduleEvent:(SEL)event target:(id)target withObject:(id)object inNanoseconds:(UInt64)ns;

- (BOOL)cancelEvent:(SEL)event target:(id)target;
- (BOOL)cancelEvent:(SEL)event target:(id)target withObject:(id)object;

- (void)addEvent:(NSDictionary *)newEvent;

void *thread_start(void* arg);
void thread_sig(int signal);
- (void)thread;

@end

@implementation NWScheduler

#pragma mark - Main thread -
#pragma mark Public Methods

+ (void)scheduleEvent:(SEL)event target:(id)target inSeconds:(NSTimeInterval)seconds {
    if (!_sharedScheduler) _sharedScheduler = [[NWScheduler alloc] init];
    [_sharedScheduler scheduleEvent:event target:target inNanoseconds:(UInt64)(seconds * 1000000000)];
}

+ (void)scheduleEvent:(SEL)event target:(id)target withObject:(id)object inSeconds:(NSTimeInterval)seconds {
    if (!_sharedScheduler) _sharedScheduler = [[NWScheduler alloc] init];
    [_sharedScheduler scheduleEvent:event target:target withObject:object inNanoseconds:(UInt64)(seconds * 1000000000)];
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
    return [_sharedScheduler cancelEvent:event target:target];
}

+ (BOOL)cancelEvent:(SEL)event target:(id)target withObject:(id)object {
    if (!_sharedScheduler) _sharedScheduler = [[NWScheduler alloc] init];
    return [_sharedScheduler cancelEvent:event target:target withObject:object];
}

#pragma mark Private methods

- (void)scheduleEvent:(SEL)event target:(id)target inNanoseconds:(UInt64)ns {
    UInt64 absTime = (mach_absolute_time() + (ns / kAbsoluteToNanosecondsRatio));
    NSDictionary *newEvent = [NSDictionary dictionaryWithObjectsAndKeys:
                              [NSNumber numberWithUnsignedLongLong:absTime], kTimeKey,
                              NSStringFromSelector(event), kSelectorKey,
                              target, kTargetKey, nil];
    //NSLog(@"Event absolute time: %lld",[[newEvent objectForKey:kTimeKey] unsignedLongLongValue]);
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
    UInt64 absTime = [[newEvent objectForKey:kTimeKey] unsignedLongLongValue];
    int i = 0;
    // insert the event into the array, but remember to lock
    [condition lock]; // try and minimize the amount of code that executes inside lock
    // add event at the correct place by time
    while (([_schedule count] > i) && (absTime > [(NSNumber *)[(NSDictionary *)[_schedule objectAtIndex:i] objectForKey:kTimeKey] unsignedLongLongValue])) {
        i++;
    }
    [_schedule insertObject:newEvent atIndex:i];
    if (([_schedule count] > 0) && ([newEvent isEqualToDictionary:[_schedule objectAtIndex:0]]))
        needsWake = YES;
    [condition signal];
    [condition unlock];
    
    // check if our event will occur before the first event
    // wake the thread from sleeping if it needs to look at our new event first
    if (needsWake) {
        // wake the thread
        pthread_kill(eventThread, SIGALRM);
    }
    
}

- (BOOL)cancelEvent:(SEL)event target:(id)target {
    return NO;
}

- (BOOL)cancelEvent:(SEL)event target:(id)target withObject:(id)object {
    return NO;
}


- (id)init {
    if (self = [super init]) {
        // Basic setup here
        // First, set the conversion factor
        mach_timebase_info_data_t tbdata;
        mach_timebase_info(&tbdata);
        kAbsoluteToNanosecondsRatio = ((long double) tbdata.numer) / ((long double) tbdata.denom);
        
        condition = [[NSCondition alloc] init];
        
        
        _schedule = [[NSMutableArray alloc] init];
        
        // Create the eventThread using POSIX routines.
        pthread_attr_t  attr;
        int             returnVal;
        
        returnVal = pthread_attr_init(&attr);
        assert(!returnVal);
        returnVal = pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_DETACHED);
        assert(!returnVal);
        
        struct sched_param param;
        param.sched_priority = sched_get_priority_max(SCHED_FIFO);
        pthread_attr_setschedparam(&attr, &param);
        pthread_attr_setschedpolicy(&attr, SCHED_FIFO);
        
        int     threadError = pthread_create(&eventThread, &attr, thread_start, (__bridge void*)self);
        
        returnVal = pthread_attr_destroy(&attr);
        assert(!returnVal);
        if (threadError != 0)
        {
            // Report an error.
            NSLog(@"An error occurred while creating the thread: %d",threadError);
        }
    }
    return self;
}

#pragma mark - Timer thread -

void *thread_start(void* arg) {
    //NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    [(__bridge NWScheduler*)arg thread];
    //[pool drain];
    return NULL;
}

void thread_sig(int signal) { }

- (void)thread {
    // NSLog(@"Please log this");
    signal(SIGALRM, thread_sig);
    // Lock the mutex.
    [condition lock];
    
    while (1) {
        while ([_schedule count] == 0) {
            [condition wait];
        }
        // NSLog(@"Made it past while loop");
        //NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSDictionary *upcomingEvent = [_schedule objectAtIndex:0];
        UInt64 absTime = [[upcomingEvent objectForKey:kTimeKey] unsignedLongLongValue];
        
        [condition unlock];
        
        // sleep until we have to spinlock
        uint64_t wakeTime = (absTime - (kSpinlockTime / kAbsoluteToNanosecondsRatio));
        // NSLog(@"Arrived at mach_wait_until");
        mach_wait_until(wakeTime);
        // NSLog(@"Made it past mach_wait_until");
        // make sure we haven't woken up early
        if (mach_absolute_time() >= wakeTime) {
            
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
            [condition lock];
            [_schedule removeObject:upcomingEvent];
        }
        else {
            // lock the mutex once more
            [condition lock];
        }
        
        
        //[pool drain];
    }
}

@end

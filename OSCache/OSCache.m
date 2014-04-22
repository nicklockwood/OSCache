//
//  OSCache.m
//
//  Version 1.0
//
//  Created by Nick Lockwood on 01/01/2014.
//  Copyright (C) 2014 Charcoal Design
//
//  Distributed under the permissive zlib License
//  Get the latest version from here:
//
//  https://github.com/nicklockwood/OSCache
//
//  This software is provided 'as-is', without any express or implied
//  warranty.  In no event will the authors be held liable for any damages
//  arising from the use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,
//  including commercial applications, and to alter it and redistribute it
//  freely, subject to the following restrictions:
//
//  1. The origin of this software must not be misrepresented; you must not
//  claim that you wrote the original software. If you use this software
//  in a product, an acknowledgment in the product documentation would be
//  appreciated but is not required.
//
//  2. Altered source versions must be plainly marked as such, and must not be
//  misrepresented as being the original software.
//
//  3. This notice may not be removed or altered from any source distribution.
//

#import "OSCache.h"


#import <Availability.h>
#if !__has_feature(objc_arc)
#error This class requires automatic reference counting
#endif


#pragma GCC diagnostic ignored "-Wobjc-missing-property-synthesis"
#pragma GCC diagnostic ignored "-Wdirect-ivar-access"
#pragma GCC diagnostic ignored "-Wconversion"
#pragma GCC diagnostic ignored "-Wgnu"


@interface OSCacheEntry : NSObject

+ (instancetype)entryWithObject:(id)object cost:(NSUInteger)cost;

@property (nonatomic, strong) NSObject *object;
@property (nonatomic, assign) NSUInteger cost;
@property (nonatomic, assign) CFAbsoluteTime lastAccessed;

@end


@implementation OSCacheEntry

+ (instancetype)entryWithObject:(id)object cost:(NSUInteger)cost
{
    OSCacheEntry *entry = [[self alloc] init];
    entry.object = object;
    entry.cost = cost;
    entry.lastAccessed = CFAbsoluteTimeGetCurrent();
    return entry;
}

@end


@interface OSCache ()

@property (nonatomic, assign) NSUInteger totalCost;
@property (nonatomic, strong) NSMutableDictionary *cache;
@property (nonatomic, assign) BOOL delegateRespondsToWillEvictObject;
@property (nonatomic, assign) BOOL currentlyCleaning;

#if __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_6_0
@property (nonatomic, assign) dispatch_semaphore_t semaphore;
#else
@property (nonatomic, strong) dispatch_semaphore_t semaphore;
#endif

@end


@implementation OSCache

- (id)init
{
    if ((self = [super init]))
    {
        //create storage
        _cache = [[NSMutableDictionary alloc] init];
        _semaphore = dispatch_semaphore_create(1);
        _totalCost = 0;
        
        //clean up in the event of a memory warning
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(removeAllObjects) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter]  removeObserver:self];
    
#if __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_6_0
    dispatch_release(_semaphore);
#endif
    
}

- (void)setDelegate:(id<NSCacheDelegate>)delegate
{
    super.delegate = delegate;
    _delegateRespondsToWillEvictObject = [delegate respondsToSelector:@selector(cache:willEvictObject:)];
}

- (void)setCountLimit:(NSUInteger)lim
{
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
    [super setCountLimit:lim];
    dispatch_semaphore_signal(_semaphore);
    [self cleanUp];
}

- (void)setTotalCostLimit:(NSUInteger)lim
{
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
    [super setTotalCostLimit:lim];
    dispatch_semaphore_signal(_semaphore);
    [self cleanUp];
}

- (void)cleanUp
{
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
    NSUInteger maxCount = [self countLimit] ?: INT_MAX;
    NSUInteger maxCost = [self totalCostLimit] ?: INT_MAX;
    NSUInteger totalCount = [_cache count];
    if (totalCount > maxCount || _totalCost > maxCost)
    {
        //sort, oldest first
        NSArray *keys = [[_cache allKeys] sortedArrayUsingComparator:^NSComparisonResult(id key1, id key2) {
            OSCacheEntry *entry1 = self.cache[key1];
            OSCacheEntry *entry2 = self.cache[key2];
            return (NSComparisonResult)MIN(1, MAX(-1, (entry1.lastAccessed - entry2.lastAccessed) * 1000));
        }];
        
        //remove oldest items until within limit
        for (id key in keys)
        {
            if (totalCount <= maxCount && _totalCost <= maxCost)
            {
                break;
            }
            totalCount --;
            _totalCost -= [ _cache[key] cost];
            if (_delegateRespondsToWillEvictObject)
            {
                _currentlyCleaning = YES;
                [self.delegate cache:self willEvictObject:[_cache objectForKey:key]];
                _currentlyCleaning = NO;
            }
            [_cache removeObjectForKey:key];
        }
    }
    dispatch_semaphore_signal(_semaphore);
}

- (id)objectForKey:(id)key
{
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
    OSCacheEntry *entry = _cache[key];
    entry.lastAccessed = CFAbsoluteTimeGetCurrent();
    id object = entry.object;
    dispatch_semaphore_signal(_semaphore);
    return object;
}

- (void)setObject:(id)obj forKey:(id)key
{
    [self setObject:obj forKey:key cost:0];
}

- (void)setObject:(id)obj forKey:(id)key cost:(NSUInteger)g
{
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
    NSAssert(!_currentlyCleaning, @"It is not possible to modify cache from within the implementation of this delegate method.");
    _totalCost -= [_cache[key] cost];
    _totalCost += g;
    _cache[key] = [OSCacheEntry entryWithObject:obj cost:g];
    dispatch_semaphore_signal(_semaphore);
    [self cleanUp];
}

- (void)removeObjectForKey:(id)key
{
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
    NSAssert(!_currentlyCleaning, @"It is not possible to modify cache from within the implementation of this delegate method.");
    _totalCost -= [_cache[key] cost];
    [_cache removeObjectForKey:key];
    dispatch_semaphore_signal(_semaphore);
}

- (void)removeAllObjects
{
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
    NSAssert(!_currentlyCleaning, @"It is not possible to modify cache from within the implementation of this delegate method.");
    _totalCost = 0;
    [_cache removeAllObjects];
    dispatch_semaphore_signal(_semaphore);
}

- (BOOL)evictsObjectsWithDiscardedContent
{
    //not implemented
    return NO;
}

@end

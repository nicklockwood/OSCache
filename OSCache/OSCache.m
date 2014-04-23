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


#import <libkern/OSAtomic.h>

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
@property (nonatomic, readonly, strong) NSMutableDictionary *cache;
@property (nonatomic, assign) BOOL delegateRespondsToWillEvictObject;
@property (nonatomic, assign) BOOL osDelegateRespondsToShouldEvictObject;
@property (nonatomic, assign) BOOL currentlyCleaning;

@property (nonatomic, readonly, assign) OSSpinLock spinLock;

@end


@implementation OSCache

- (id)init
{
    if ((self = [super init]))
    {
        //create storage
        _cache = [[NSMutableDictionary alloc] init];
        _totalCost = 0;
        
#if TARGET_OS_IPHONE
        
        //clean up in the event of a memory warning
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(removeAllObjects) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
        
#endif
        
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter]  removeObserver:self];
}

- (void)setDelegate:(id<NSCacheDelegate>)delegate
{
    super.delegate = delegate;
    _delegateRespondsToWillEvictObject = [delegate respondsToSelector:@selector(cache:willEvictObject:)];
}

- (void)setOsDelegate:(id<OSCacheDelegate>)osDelegate
{
    _osDelegate = osDelegate;
    _osDelegateRespondsToShouldEvictObject = [osDelegate respondsToSelector:@selector(cache:shouldEvictObject:)];
}

- (void)setCountLimit:(NSUInteger)lim
{
    OSSpinLockLock(&_spinLock);
    [super setCountLimit:lim];
    OSSpinLockUnlock(&_spinLock);
    [self cleanUp];
}

- (void)setTotalCostLimit:(NSUInteger)lim
{
    OSSpinLockLock(&_spinLock);
    [super setTotalCostLimit:lim];
    OSSpinLockUnlock(&_spinLock);
    [self cleanUp];
}

- (void)cleanUp
{
    OSSpinLockLock(&_spinLock);
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
            if (_osDelegateRespondsToShouldEvictObject)
            {
                if (![self.osDelegate cache:self shouldEvictObject:[_cache objectForKey:key]])
                {
                    continue;
                }
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
    OSSpinLockUnlock(&_spinLock);
}

- (id)objectForKey:(id)key
{
    OSSpinLockLock(&_spinLock);
    OSCacheEntry *entry = _cache[key];
    entry.lastAccessed = CFAbsoluteTimeGetCurrent();
    id object = entry.object;
    OSSpinLockUnlock(&_spinLock);
    return object;
}

- (void)setObject:(id)obj forKey:(id)key
{
    [self setObject:obj forKey:key cost:0];
}

- (void)setObject:(id)obj forKey:(id)key cost:(NSUInteger)g
{
    OSSpinLockLock(&_spinLock);
    NSAssert(!_currentlyCleaning, @"It is not possible to modify cache from within the implementation of this delegate method.");
    _totalCost -= [_cache[key] cost];
    _totalCost += g;
    _cache[key] = [OSCacheEntry entryWithObject:obj cost:g];
    OSSpinLockUnlock(&_spinLock);
    [self cleanUp];
}

- (void)removeObjectForKey:(id)key
{
    OSSpinLockLock(&_spinLock);
    NSAssert(!_currentlyCleaning, @"It is not possible to modify cache from within the implementation of this delegate method.");
    BOOL shouldEvict = YES;
    if (_osDelegateRespondsToShouldEvictObject)
    {
        if (![self.osDelegate cache:self shouldEvictObject:[_cache objectForKey:key]])
        {
            shouldEvict = NO;
        }
    }
    if (shouldEvict)
    {
        _totalCost -= [_cache[key] cost];
        [_cache removeObjectForKey:key];
    }
    OSSpinLockUnlock(&_spinLock);
}

- (void)removeAllObjects
{
    OSSpinLockLock(&_spinLock);
    NSAssert(!_currentlyCleaning, @"It is not possible to modify cache from within the implementation of this delegate method.");
    _totalCost = 0;
    if (_osDelegateRespondsToShouldEvictObject)
    {
        for (id key in [_cache allKeys])
        {
            if ([self.osDelegate cache:self shouldEvictObject:[_cache objectForKey:key]])
            {
                [_cache removeObjectForKey:key];
            }
        }
    }
    else
    {
        [_cache removeAllObjects];
    }
    OSSpinLockUnlock(&_spinLock);
}

- (BOOL)evictsObjectsWithDiscardedContent
{
    //not implemented
    return NO;
}

@end

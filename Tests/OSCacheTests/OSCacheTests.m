//
//  OSCacheTests.m
//  OSCacheTests
//
//  Created by Nick Lockwood on 23/04/2014.
//  Copyright (c) 2014 Charcoal Design. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "OSCache.h"


@interface OSCache (Private)

- (void)cleanUpAllObjects;
- (void)resequence;
- (NSDictionary *)cache;
- (void)setSequenceNumber:(NSInteger)number;

@end


@interface OSCacheTests : XCTestCase

@property (nonatomic, strong) OSCache *cache;

@end


@implementation OSCacheTests

- (void)setUp
{
    self.cache = [[OSCache alloc] init];
    self.cache.countLimit = 3;
    self.cache.totalCostLimit = 100;
}

- (void)tearDown
{
    self.cache = nil;
}

- (void)testInsertion
{
    [self.cache setObject:@1 forKey:@"foo" cost:1];
    [self.cache setObject:@2 forKey:@"bar" cost:2];
    [self.cache setObject:@3 forKey:@"baz" cost:3];
    
    XCTAssertEqual([self.cache count], 3, @"Insertion failed");
    XCTAssertEqual([self.cache totalCost], 6, @"Insertion failed");
}

- (void)testRemoval
{
    [self.cache setObject:@1 forKey:@"foo" cost:1];
    [self.cache setObject:@2 forKey:@"bar" cost:2];
    [self.cache setObject:@3 forKey:@"baz" cost:3];
    
    [self.cache removeObjectForKey:@"bar"];
    
    XCTAssertEqual([self.cache count], 2, @"Removal failed");
    XCTAssertNil([self.cache objectForKey:@"bar"], @"Removal failed");
}

- (void)testCountEviction
{
    [self.cache setObject:@1 forKey:@"foo"];
    [self.cache setObject:@2 forKey:@"bar"];
    [self.cache setObject:@3 forKey:@"baz"];
    [self.cache setObject:@4 forKey:@"bam"];
    
    XCTAssertEqual([self.cache count], 3, @"Eviction failed");
    XCTAssertNil([self.cache objectForKey:@"foo"], @"Eviction failed");
    
    [self.cache setObject:@5 forKey:@"boo"];
    
    XCTAssertEqual([self.cache count], 3, @"Eviction failed");
    XCTAssertNil([self.cache objectForKey:@"bar"], @"Eviction failed");
}

- (void)testCostEviction
{
    [self.cache setObject:@1 forKey:@"foo" cost:99];
    [self.cache setObject:@2 forKey:@"bar" cost:2];
    
    XCTAssertEqual([self.cache count], 1, @"Eviction failed");
    XCTAssertEqual([self.cache totalCost], 2, @"Eviction failed");
    XCTAssertNil([self.cache objectForKey:@"foo"], @"Eviction failed");
    
    [self.cache setObject:@3 forKey:@"baz" cost:999];
    
    XCTAssertEqual([self.cache count], 0, @"Eviction failed");
    XCTAssertEqual([self.cache totalCost], 0, @"Eviction failed");
}

- (void)testCleanup
{
    [self.cache setObject:@1 forKey:@"foo"];
    [self.cache setObject:@2 forKey:@"bar"];
    [self.cache setObject:@3 forKey:@"baz"];
    
    //simulate memory warning
    [self.cache cleanUpAllObjects];
    
    XCTAssertEqual([self.cache count], 0, @"Cleanup failed");
    XCTAssertEqual([self.cache totalCost], 0, @"Cleanup failed");
}

- (void)testResequence
{
    [self.cache setObject:@1 forKey:@"foo"];
    [self.cache setObject:@2 forKey:@"bar"];
    [self.cache setObject:@3 forKey:@"baz"];
    
    [self.cache resequence];
    
    NSDictionary *innerCache = [self.cache cache];
    XCTAssertEqualObjects([innerCache[@"foo"] valueForKey:@"sequenceNumber"], @0, @"Resequence failed");
    XCTAssertEqualObjects([innerCache[@"bar"] valueForKey:@"sequenceNumber"], @1, @"Resequence failed");
    XCTAssertEqualObjects([innerCache[@"baz"] valueForKey:@"sequenceNumber"], @2, @"Resequence failed");
    
    [self.cache removeObjectForKey:@"foo"];
    [self.cache resequence];
    
    XCTAssertEqualObjects([innerCache[@"bar"] valueForKey:@"sequenceNumber"], @0, @"Resequence failed");
    XCTAssertEqualObjects([innerCache[@"baz"] valueForKey:@"sequenceNumber"], @1, @"Resequence failed");
}

- (void)testResequenceTrigger
{
    [self.cache setObject:@1 forKey:@"foo"];
    [self.cache setObject:@2 forKey:@"bar"];
    
    //first object should now be bar with sequence number of 1
    [self.cache removeObjectForKey:@"foo"];
    
    //should trigger resequence
    [self.cache setSequenceNumber:NSIntegerMax];
    [self.cache setObject:@3 forKey:@"baz"];
    
    NSDictionary *innerCache = [self.cache cache];
    XCTAssertEqualObjects([innerCache[@"bar"] valueForKey:@"sequenceNumber"], @0, @"Resequence failed");
    XCTAssertEqualObjects([innerCache[@"baz"] valueForKey:@"sequenceNumber"], @1, @"Resequence failed");
    
    //first object should now be baz with sequence number of 1
    [self.cache removeObjectForKey:@"bar"];
    
    //should also trigger resequence
    [self.cache setSequenceNumber:NSIntegerMax];
    [self.cache objectForKey:@"baz"];
    
    XCTAssertEqualObjects([innerCache[@"baz"] valueForKey:@"sequenceNumber"], @0, @"Resequence failed");
}

- (void)testName
{
    self.cache.name = @"Hello";
    XCTAssertEqualObjects(self.cache.name, @"Hello", @"Name failed");
}

@end

//
//  OSCacheTestsSwift.swift
//  OSCacheTests
//
//  Created by Tom King on 1/6/16.
//  Copyright © 2016 IZI Mobile. All rights reserved.
//

import XCTest

let TEST_COUNT = 2048

class OSCacheTestsSwift: XCTestCase
{
    var cache: OSCache!
    
    override func setUp()
    {
        super.setUp()
        cache = OSCache()
        cache.countLimit = 3
        cache.totalCostLimit = 100
    }
    
    override func tearDown()
    {
        super.tearDown()
        cache = nil
    }
    
    func testInsertion()
    {
        cache.setObject(NSNumber(integer: 1), forKey: "foo", cost: 1)
        cache.setObject(NSNumber(integer: 2), forKey: "bar", cost: 2)
        cache.setObject(NSNumber(integer: 3), forKey: "baz", cost: 3)
        
        XCTAssertEqual(cache.count, 3, "Insertion failed")
        XCTAssertEqual(cache.totalCost, 6, "Insertion failed")
    }
    
    func testRemoval()
    {
        cache.setObject(NSNumber(integer: 1), forKey: "foo", cost: 1)
        cache.setObject(NSNumber(integer: 2), forKey: "bar", cost: 2)
        cache.setObject(NSNumber(integer: 3), forKey: "baz", cost: 3)
        
        cache.removeObjectForKey("bar")
        
        XCTAssertEqual(cache.count, 2, "Removal failed")
        let bar = cache.objectForKey("bar")
        XCTAssertNil(bar, "Removal failed")
    }
    
    func testCountEviction()
    {
        cache.setObject(NSNumber(integer: 1), forKey: "foo")
        cache.setObject(NSNumber(integer: 2), forKey: "bar")
        cache.setObject(NSNumber(integer: 3), forKey: "baz")
        cache.setObject(NSNumber(integer: 4), forKey: "bam")
        
        XCTAssertEqual(cache.count, 3, "Eviction failed")
        let foo = cache.objectForKey("foo")
        XCTAssertNil(foo, "Eviction failed")
        
        cache.setObject(NSNumber(integer: 4), forKey: "boo")
        
        XCTAssertEqual(cache.count, 3, "Eviction failed")
        let bar = cache.objectForKey("bar")
        XCTAssertNil(bar, "Eviction failed")
    }
    
    func testCostEviction()
    {
        cache.setObject(NSNumber(integer: 1), forKey: "foo", cost: 99)
        cache.setObject(NSNumber(integer: 2), forKey: "bar", cost: 2)
        
        XCTAssertEqual(cache.count, 1, "Eviction failed")
        XCTAssertEqual(cache.totalCost, 2, "Eviction failed")
        let foo = cache.objectForKey("foo")
        XCTAssertNil(foo, "Eviction failed")
        
        cache.setObject(NSNumber(integer: 3), forKey: "baz", cost: 999)

        XCTAssertEqual(cache.count, 0, "Eviction failed")
        XCTAssertEqual(cache.totalCost, 0, "Eviction failed")
    }
    
    func testCleanup()
    {
        cache.setObject(NSNumber(integer: 1), forKey: "foo")
        cache.setObject(NSNumber(integer: 2), forKey: "bar")
        cache.setObject(NSNumber(integer: 3), forKey: "baz")
        
        //simulate memory warning
        cache.cleanUpAllObjects()
        
        XCTAssertEqual(cache.count, 0, "Cleanup failed")
        XCTAssertEqual(cache.totalCost, 0, "Cleanup failed")
    }
    
    func testResequence()
    {
        cache.setObject(NSNumber(integer: 1), forKey: "foo")
        cache.setObject(NSNumber(integer: 2), forKey: "bar")
        cache.setObject(NSNumber(integer: 3), forKey: "baz")
        
        cache.resequence()
        
        let innerCache = cache.cache()
        XCTAssertEqual(innerCache["foo"]!.valueForKey("sequenceNumber") as? NSNumber, NSNumber(integer: 0), "Resequence failed")
        XCTAssertEqual(innerCache["bar"]!.valueForKey("sequenceNumber") as? NSNumber, NSNumber(integer: 1), "Resequence failed")
        XCTAssertEqual(innerCache["baz"]!.valueForKey("sequenceNumber") as? NSNumber, NSNumber(integer: 2), "Resequence failed")
        
        cache.removeObjectForKey("foo")
        cache.resequence()
        
        XCTAssertEqual(innerCache["bar"]!.valueForKey("sequenceNumber") as? NSNumber, NSNumber(integer: 0), "Resequence failed")
        XCTAssertEqual(innerCache["baz"]!.valueForKey("sequenceNumber") as? NSNumber, NSNumber(integer: 1), "Resequence failed")
    }
    
    func testResequenceTrigger()
    {
        cache.setObject(NSNumber(integer: 1), forKey: "foo")
        cache.setObject(NSNumber(integer: 2), forKey: "bar")
        
        //first object should now be bar with sequence number of 1
        cache.removeObjectForKey("foo")
        
        //should trigger resequence
        cache.setSequenceNumber(NSIntegerMax)
        cache.setObject(NSNumber(integer: 3), forKey: "baz")
        
        let innerCache = cache.cache()
        XCTAssertEqual(innerCache["bar"]!.valueForKey("sequenceNumber") as? NSNumber, NSNumber(integer: 0), "Resequence failed")
        XCTAssertEqual(innerCache["baz"]!.valueForKey("sequenceNumber") as? NSNumber, NSNumber(integer: 1), "Resequence failed")
        
        //first object should now be baz with sequence number of 1
        cache.removeObjectForKey("bar")
        
        //should also trigger resequence
        cache.setSequenceNumber(NSIntegerMax)
        cache.objectForKey("baz")
        
        XCTAssertEqual(innerCache["baz"]!.valueForKey("sequenceNumber") as? NSNumber, NSNumber(integer: 0), "Resequence failed")
    }
    
    func testName()
    {
        cache.name = "Hello"
        XCTAssertEqual(cache.name, "Hello", "Name failed")
    }
    
    func testAccessPerf()
    {
        measureMetrics(OSCacheTestsSwift.defaultPerformanceMetrics(), automaticallyStartMeasuring: false) { () -> Void in
            self.cache = OSCache()
            self.cache.countLimit = TEST_COUNT
            for i in 0..<TEST_COUNT
            {
                self.cache.setObject(NSNumber(integer: i), forKey: NSNumber(integer: i))
            }
            
            self.startMeasuring()
            
            for i in 0..<TEST_COUNT
            {
                self.cache.objectForKey(NSNumber(integer: i))
            }
            
            self.stopMeasuring()
            
            self.cache = nil
        }
    }
    
    func testInsertionPerf()
    {
        measureMetrics(OSCacheTestsSwift.defaultPerformanceMetrics(), automaticallyStartMeasuring: false) { () -> Void in
            self.cache = OSCache()
            self.cache.countLimit = TEST_COUNT
            
            self.startMeasuring()
            
            for i in 0..<TEST_COUNT
            {
                self.cache.setObject(NSNumber(integer: i), forKey: NSNumber(integer: i))
            }
            
            self.stopMeasuring()
            
            self.cache = nil
        }
    }
    
    func testDeletionPerf()
    {
        measureMetrics(OSCacheTestsSwift.defaultPerformanceMetrics(), automaticallyStartMeasuring: false) { () -> Void in
            self.cache = OSCache()
            self.cache.countLimit = TEST_COUNT
            for i in 0..<TEST_COUNT
            {
                self.cache.setObject(NSNumber(integer: i), forKey: NSNumber(integer: i))
            }
            
            self.startMeasuring()
            
            for i in 0..<TEST_COUNT
            {
                self.cache.removeObjectForKey(NSNumber(integer: i))
            }
            
            self.stopMeasuring()
            
            self.cache = nil
        }
    }
    
    func testOverflowInsertionsPerf()
    {
        measureMetrics(OSCacheTestsSwift.defaultPerformanceMetrics(), automaticallyStartMeasuring: false) { () -> Void in
            self.cache = OSCache()
            self.cache.countLimit = TEST_COUNT
            for i in 0..<TEST_COUNT
            {
                self.cache.setObject(NSNumber(integer: i), forKey: NSNumber(integer: i))
            }
            
            self.startMeasuring()
            
            for i in 0..<TEST_COUNT
            {
                self.cache.setObject(NSNumber(integer: i), forKey: NSNumber(integer: i + TEST_COUNT))
            }
            
            self.stopMeasuring()
            
            self.cache = nil
        }
    }
    
    func testOverflowDeletionPerf()
    {
        measureMetrics(OSCacheTestsSwift.defaultPerformanceMetrics(), automaticallyStartMeasuring: false) { () -> Void in
            self.cache = OSCache()
            self.cache.countLimit = TEST_COUNT
            for i in 0..<TEST_COUNT*2
            {
                self.cache.setObject(NSNumber(integer: i), forKey: NSNumber(integer: i))
            }
            
            self.startMeasuring()
            
            for i in 0..<TEST_COUNT
            {
                self.cache.removeObjectForKey(NSNumber(integer: i))
            }
            
            self.stopMeasuring()
            
            self.cache = nil
        }
    }
}

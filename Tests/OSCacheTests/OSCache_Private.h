//
//  OSCache_Private.h
//  OSCacheTests
//
//  Created by Tom King on 1/6/16.
//  Copyright © 2016 IZI Mobile. All rights reserved.
//

#ifndef OSCache_Private_h
#define OSCache_Private_h

@interface OSCache (Private)

- (void)cleanUpAllObjects;
- (void)resequence;
- (NSDictionary *)cache;
- (void)setSequenceNumber:(NSInteger)number;

@end

#endif /* OSCache_Private_h */

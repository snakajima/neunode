//
//  BDHost.h
//  neu.Node
//
//  Created by satoshi on 12/1/12.
//  Copyright (c) 2012 satoshi. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface BDHost : NSObject
+ (NSString *)addressForHostname:(NSString *)hostname;
+ (NSArray *)addressesForHostname:(NSString *)hostname;
@end

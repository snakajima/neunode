//
//  BDHost.m
//  neu.Node
//
//  Created by satoshi on 12/1/12.
//  Copyright (c) 2012 satoshi. All rights reserved.
//

#import "BDHost.h"

// from http://www.bdunagan.com/2009/11/28/iphone-tip-no-nshost/
// MIT license
// Remember to add CFNetwork.framework to your project using Add=>Existing Frameworks.
 
#import "BDHost.h"
#import <CFNetwork/CFNetwork.h>
#import <netinet/in.h>
#import <netdb.h>
#import <ifaddrs.h>
#import <arpa/inet.h>
#import <net/ethernet.h>
#import <net/if_dl.h>
 
@implementation BDHost

+ (NSString *)addressForHostname:(NSString *)hostname {
    NSArray *addresses = [BDHost addressesForHostname:hostname];
    if ([addresses count] > 0)
        return [addresses objectAtIndex:0];
    else
        return nil;
}

+ (NSArray *)addressesForHostname:(NSString *)hostname {
    // Get the addresses for the given hostname.
    CFHostRef hostRef = CFHostCreateWithName(kCFAllocatorDefault, (__bridge CFStringRef)hostname);
    BOOL isSuccess = CFHostStartInfoResolution(hostRef, kCFHostAddresses, nil);
    if (!isSuccess) return nil;
    CFArrayRef addressesRef = CFHostGetAddressing(hostRef, nil);
    if (addressesRef == nil) return nil;
     
    // Convert these addresses into strings.
    char ipAddress[INET6_ADDRSTRLEN];
    NSMutableArray *addresses = [NSMutableArray array];
    CFIndex numAddresses = CFArrayGetCount(addressesRef);
    for (CFIndex currentIndex = 0; currentIndex < numAddresses; currentIndex++) {
        struct sockaddr *address = (struct sockaddr *)CFDataGetBytePtr(CFArrayGetValueAtIndex(addressesRef, currentIndex));
        if (address == nil) return nil;
        getnameinfo(address, address->sa_len, ipAddress, INET6_ADDRSTRLEN, nil, 0, NI_NUMERICHOST);
        if (ipAddress == nil) return nil;
      
        // SATOSHI: return only IPv4 address
        // http://h30097.www3.hp.com/docs/base%5Fdoc/DOCUMENTATION/V50A%5FHTML/MAN/MAN7/0052%5F%5F%5F%5F.HTM
        if (address->sa_family == AF_INET) {
          [addresses addObject:[NSString stringWithCString:ipAddress encoding:NSASCIIStringEncoding]];
        }
    }
     
    return addresses;
}
 
+ (NSString *)hostnameForAddress:(NSString *)address {
    NSArray *hostnames = [BDHost hostnamesForAddress:address];
    if ([hostnames count] > 0)
        return [hostnames objectAtIndex:0];
    else
        return nil;
}
 
+ (NSArray *)hostnamesForAddress:(NSString *)address {
    // Get the host reference for the given address.
    struct addrinfo      hints;
    struct addrinfo      *result = NULL;
    memset(&hints, 0, sizeof(hints));
    hints.ai_flags    = AI_NUMERICHOST;
    hints.ai_family   = PF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;
    hints.ai_protocol = 0;
    int errorStatus = getaddrinfo([address cStringUsingEncoding:NSASCIIStringEncoding], NULL, &hints, &result);
    if (errorStatus != 0) return nil;
    CFDataRef addressRef = CFDataCreate(NULL, (UInt8 *)result->ai_addr, result->ai_addrlen);
    if (addressRef == nil) return nil;
    freeaddrinfo(result);
    CFHostRef hostRef = CFHostCreateWithAddress(kCFAllocatorDefault, addressRef);
    if (hostRef == nil) return nil;
    CFRelease(addressRef);
    BOOL isSuccess = CFHostStartInfoResolution(hostRef, kCFHostNames, NULL);
    if (!isSuccess) return nil;
     
    // Get the hostnames for the host reference.
    NSArray* hostnamesRef = CFBridgingRelease(CFHostGetNames(hostRef, NULL));
    NSMutableArray *hostnames = [NSMutableArray array];
    for (int currentIndex = 0; currentIndex < [(NSArray *)hostnamesRef count]; currentIndex++) {
        [hostnames addObject:[(NSArray *)hostnamesRef objectAtIndex:currentIndex]];
    }
     
    return hostnames;
}
 
+ (NSArray *)ipAddresses {
    NSMutableArray *addresses = [NSMutableArray array];
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *currentAddress = NULL;
     
    int success = getifaddrs(&interfaces);
    if (success == 0) {
        currentAddress = interfaces;
        while(currentAddress != NULL) {
            if(currentAddress->ifa_addr->sa_family == AF_INET) {
                NSString *address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)currentAddress->ifa_addr)->sin_addr)];
                if (![address isEqual:@"127.0.0.1"]) {
                    NSLog(@"%@ ip: %@", [NSString stringWithUTF8String:currentAddress->ifa_name], address);
                    [addresses addObject:address];
                }
            }
            currentAddress = currentAddress->ifa_next;
        }
    }
    freeifaddrs(interfaces);
    return addresses;
}
 
+ (NSArray *)ethernetAddresses {
    NSMutableArray *addresses = [NSMutableArray array];
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *currentAddress = NULL;
    int success = getifaddrs(&interfaces);
    if (success == 0) {
        currentAddress = interfaces;
        while(currentAddress != NULL) {
            if(currentAddress->ifa_addr->sa_family == AF_LINK) {
                NSString *address = [NSString stringWithUTF8String:ether_ntoa((const struct ether_addr *)LLADDR((struct sockaddr_dl *)currentAddress->ifa_addr))];
                 
                // ether_ntoa doesn't format the ethernet address with padding.
                char paddedAddress[80];
                int a,b,c,d,e,f;
                sscanf([address UTF8String], "%x:%x:%x:%x:%x:%x", &a, &b, &c, &d, &e, &f);
                sprintf(paddedAddress, "%02X:%02X:%02X:%02X:%02X:%02X",a,b,c,d,e,f);
                address = [NSString stringWithUTF8String:paddedAddress];
                 
                if (![address isEqual:@"00:00:00:00:00:00"] && ![address isEqual:@"00:00:00:00:00:FF"]) {
                    NSLog(@"%@ mac: %@", [NSString stringWithUTF8String:currentAddress->ifa_name], address);
                    [addresses addObject:address];
                }
            }
            currentAddress = currentAddress->ifa_next;
        }
    }
    freeifaddrs(interfaces);
    return addresses;
}
 
@end
//
//  NodeSocket.m
//  neu.Node
//
//  Created by Satoshi Nakajima on 11/14/12.
//  Copyright (c) 2012 Satoshi Nakajima All rights reserved.
//

#import "NodeSocket.h"

@implementation NodeSocket
@synthesize objectID;
@synthesize delegate;

-(BOOL) isValid {
  return _socket ? CFSocketIsValid(_socket) : NO;
}

-(void) _close {
  if (_socket) {
    CFSocketInvalidate(_socket);
    CFRelease(_socket);
    _socket = NULL;
  }
}

-(void) close {
  [self _close];
}

-(void) dealloc {
  //NSLog(@"socket deallocating %@", self.objectID);
  [self _close];
}

@end

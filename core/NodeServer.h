//
//  NodeServer.h
//  neu.Node
//
//  Created by Satoshi Nakajima on 11/14/12.
//  Copyright (c) 2012 Satoshi Nakajima All rights reserved.
//

#import "NodeSocket.h"
#import "NodeController.h"

@interface NodeServer : NodeSocket <NodeService> {
  NSMutableArray* _sockets;
  CFRunLoopSourceRef _rls;
  NSUInteger _port;
}
@property (nonatomic, strong) NSString* url;
@property (nonatomic, strong) NSString* protocol;
@property (nonatomic, readonly) NSUInteger connections;
@property (nonatomic, readonly) NSUInteger port;
// For future extensions
@property (nonatomic, strong) NSMutableDictionary* extra; 
@property (nonatomic, strong) NSNetService* service;
-(id) initWithId:(NSString*)id port:(NSUInteger)port_ delegate:(id <NodeSocketDelegate>)delegate_;
-(void) _childSocketDidClose:(NodeSocket*)socket;
-(void) shutdown;
@end

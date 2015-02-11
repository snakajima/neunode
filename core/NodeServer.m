//
//  NodeServer.m
//  neu.Node
//
//  Created by Satoshi Nakajima on 11/14/12.
//  Copyright (c) 2012 Satoshi Nakajima All rights reserved.
//

#import "NodeServer.h"
#import "NodeConnection.h"

@interface NodeServer ()
-(void) _childSocketDidClose:(NodeSocket*)socket;
-(void) _emitCloseIfNoChild;
@end

@implementation NodeServer
@dynamic connections;
@dynamic port;

-(NSUInteger) port {
  return _port;
}

-(NSUInteger) connections {
  return _sockets.count;
}

// Forcefully close all the connections, then close itself
-(void) shutdown {
  if (_sockets) {
    // We don't want to mutate the array while enumerating
    NSArray* socketsCopy = [NSArray arrayWithArray:_sockets];
    for (NodeConnection* socket in socketsCopy) {
      [socket close];
    }
  }
  [self _close];
  [self.delegate socketEmitClose:self];
}

-(void) _childSocketDidClose:(NodeSocket*)socket {
  [_sockets removeObject:socket];
  //NSLog(@"Socket child.count = %d", _sockets.count);
  
  if (_socket == NULL) {
    // If it's already closed and no child, emit the close event
    [self _emitCloseIfNoChild];
  }
}

-(void) _emitCloseIfNoChild {
  if (!_sockets || _sockets.count==0) {
    [self.delegate socketEmitClose:self];
  }
}

-(void) _socketCallback:(CFSocketCallBackType)type address:(NSData*)address data:(const void *)pData {
  if (type == kCFSocketAcceptCallBack) {
    CFSocketNativeHandle nativeHandle = *(CFSocketNativeHandle *)pData;
    NSString* idSocket = [self.delegate socketConnect:self];
    //NSLog(@"NS _socketCallback %@, %@", self.objectID, idSocket);
    if (!_sockets) {
      _sockets = [NSMutableArray array];
    }
    NodeConnection* socket = [[NodeConnection alloc] initWithId:idSocket nativeHandle:nativeHandle parent:self];
    if (socket) {
      [self.delegate registerSocket:socket];
      [_sockets addObject:socket];
      //NSLog(@"Socket child.count = %d", _sockets.count);
    } // no need to handle error because initWithId will emit error if necessary
  } else {
    NSLog(@"_socketCallback %ld", type);
  }
}

static void MyCFSocketCallback(CFSocketRef sref, CFSocketCallBackType type, CFDataRef address, const void *pData, void *pInfo) {
  NodeServer* self = (__bridge NodeServer *)(pInfo);
  [self _socketCallback:type address:(__bridge NSData *)(address) data:pData];
}

-(id) initWithId:(NSString*)id_ port:(NSUInteger)port_  delegate:(id <NodeSocketDelegate>)delegate_ {
  if (self = [super init]) {
    self.objectID = id_;
    self.delegate = delegate_;
    self.extra = [NSMutableDictionary dictionary];
    CFSocketContext context = {0};
    context.info = (__bridge void *)(self);

    _socket = CFSocketCreate(kCFAllocatorDefault,
										PF_INET,
										SOCK_STREAM,
										0,
										kCFSocketAcceptCallBack,                // Callback flags
										&MyCFSocketCallback,  // Callback method
										&context);

    if (_socket == NULL) {
      // CFSocket offers no feedback on errors
      [self.delegate socketError:self err:nil errStr:@"NOSOCKET" syscall:@"listen"];
      self = nil;
    }

    if (self) {
      // We want to reuse the socket even if it's in timeout state
      int reuseOn = 1;
      setsockopt(CFSocketGetNative(_socket), SOL_SOCKET, SO_REUSEADDR, &reuseOn, sizeof(reuseOn));

      struct sockaddr_in nativeAddr = {0};
      nativeAddr.sin_len         = sizeof(struct sockaddr_in);
      nativeAddr.sin_family      = AF_INET;
      nativeAddr.sin_port        = htons(port_);
      nativeAddr.sin_addr.s_addr = htonl(INADDR_ANY);
      
      NSData *address = [NSData dataWithBytes:&nativeAddr length:sizeof(nativeAddr)];
      if (kCFSocketSuccess != CFSocketSetAddress(_socket, CFBridgingRetain(address))) {
        [self.delegate socketError:self err:nil errStr:@"EADDRINUSE" syscall:@"listen"];
        self = nil;
      }
    }
    
    if (self) {
      NSData* dataAddr = CFBridgingRelease(CFSocketCopyAddress(_socket));
      struct sockaddr_in *paddr = (struct sockaddr_in *)dataAddr.bytes;
      _port = ntohs(paddr->sin_port);
      
      _rls = CFSocketCreateRunLoopSource(kCFAllocatorDefault, _socket, 0);
      CFRunLoopAddSource(CFRunLoopGetCurrent(), _rls, kCFRunLoopCommonModes);
    }
  }
  return self;
}

-(void) _close {
  [self.service stop];
  if (_rls) {
    CFRunLoopRemoveSource(CFRunLoopGetCurrent(), _rls, kCFRunLoopCommonModes);
    CFRelease(_rls);
    _rls = NULL;
  }
  [super _close];
}

-(void) close {
  [super close];
  [self _emitCloseIfNoChild];
}

@end

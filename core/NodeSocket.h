//
//  NodeSocket.h
//  neu.Node
//
//  Created by Satoshi Nakajima on 11/14/12.
//  Copyright (c) 2012 Satoshi Nakajima All rights reserved.
//

#import <Foundation/Foundation.h>
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import <netdb.h>

@class NodeSocket, NodeServer, NodeConnection;
@protocol NodeSocketDelegate <NSObject>
-(void) registerSocket:(NodeSocket*)socket;
-(void) socket:(NodeSocket*)socket onData:(NSData*)data;
-(NSString*) socketConnect:(NodeSocket*)socket;
-(void) socketReadStreamOpen:(NodeSocket*)socket;
-(void) socketWriteStreamOpen:(NodeSocket*)socket;
-(void) socketReadStreamEnd:(NodeSocket*)socket;
-(void) socketEmitClose:(NodeSocket*)socket;
-(void) socketWriteDidDrain:(NodeConnection*)socket;
-(void) socketError:(NodeSocket*)socket err:(CFErrorRef)err errStr:(NSString*)errStr syscall:(NSString*)syscall;
@end

@class NodeServer;
@interface NodeSocket : NSObject {
  CFSocketRef _socket;
}
@property (nonatomic, assign) id <NodeSocketDelegate> delegate;
@property (nonatomic, strong) NSString* objectID;
-(BOOL) isValid;
-(void) close;
-(void) _close;
@end

//
//  NodeConnection.h
//  neu.Node
//
//  Created by Satoshi Nakajima on 11/14/12.
//  Copyright (c) 2012 Satoshi Nakajima All rights reserved.
//

#import "NodeSocket.h"

@interface NodeConnection : NodeSocket {
	CFReadStreamRef _readStream;
	CFWriteStreamRef _writeStream;
  NSMutableData* _data;
  // memory optimization (to avoid copying data from memory mapped NSData)
  NSData* _dataBlob;
  NSUInteger _cursorBlob;
}
@property (nonatomic, assign) NodeServer* parent;
@property (nonatomic) NSUInteger status; // only for 'complete' (http-static)
-(void) write:(NSData*)data;
-(id) initWithId:(NSString*)id_ nativeHandle:(CFSocketNativeHandle)nativeHandle parent:(NodeServer*)parent;
-(id) initWithId:(NSString*)id_ hostName:(NSString*)host post:(NSUInteger)port delegate:(id <NodeSocketDelegate>)delegate_;

@end

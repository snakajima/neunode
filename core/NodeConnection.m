//
//  NodeConnection.m
//  neu.Node
//
//  Created by Satoshi Nakajima on 11/14/12.
//  Copyright (c) 2012 Satoshi Nakajima All rights reserved.
//

#import "NodeConnection.h"
#import "NodeServer.h"

#define BUFFER_SIZE (100 * 1024)

@interface NodeConnection ()
-(void) _sendBytes;
-(void) _emitReadStreamError:(NSString*)syscall;
-(void) _emitWriteStreamError:(NSString*)syscall;
@end


@implementation NodeConnection

@synthesize status;

-(void) _readStreamCallback:(CFStreamEventType)type {
  //NSLog(@"NC _readStreamCallback %ld, %@", type, self.objectID);
  if (type==kCFStreamEventOpenCompleted) {
    [self.delegate socketReadStreamOpen:self];
  } else if (type==kCFStreamEventHasBytesAvailable) {
    //NSLog(@"NC _readStreamCallback: bytes available");
    NSMutableData* data = [NSMutableData data];
    UInt8 buffer[1024];
    NSInteger bytesRead;
    while(CFReadStreamHasBytesAvailable(_readStream)) {
      bytesRead = CFReadStreamRead(_readStream, buffer, sizeof(buffer));
      //NSLog(@"_readStreamCallback bytesRead = %d", bytesRead);
      if (bytesRead < 0) {
        [self _emitReadStreamError:@"read"];
      } else {
        [data appendBytes:buffer length:bytesRead];
      }
    }
    if (data.length > 0) {
      [self.delegate socket:self onData:data];
    }
  } else if (type==kCFStreamEventEndEncountered) {
    [self.delegate socketReadStreamEnd:self];
    if (self.parent) {
      [self.parent _childSocketDidClose:self];
    }
  } else {
    NSLog(@"_readStreamCallback %ld", type);
  }
}

static void MyCFReadStreamCallback (CFReadStreamRef stream, CFStreamEventType type, void *pInfo) {
  NodeConnection* self = (__bridge NodeConnection *)(pInfo);
  [self _readStreamCallback:type];
}

-(void) _writeStreamCallback:(CFStreamEventType)type {
  //NSLog(@"NC _writeStreamCallback %ld, %@", type, self.objectID);
  if (type==kCFStreamEventOpenCompleted) {
    [self.delegate socketWriteStreamOpen:self];
  } else if (type == kCFStreamEventCanAcceptBytes) {
    [self _sendBytes];
  } else {
    NSLog(@"_writeStreamCallback %ld", type);
  }
}

static void MyCFWriteStreamCallback (CFWriteStreamRef stream, CFStreamEventType type, void *pInfo) {
  NodeConnection* self = (__bridge NodeConnection *)(pInfo);
  [self _writeStreamCallback:type];
}

-(void) _emitReadStreamError:(NSString*)syscall {
  CFErrorRef err = CFReadStreamCopyError(_readStream);
  NSString* code = CFBridgingRelease(CFErrorCopyDescription(err));
  [self.delegate socketError:self err:err errStr:code syscall:syscall];
}

-(void) _emitWriteStreamError:(NSString*)syscall {
  CFErrorRef err = CFWriteStreamCopyError(_writeStream);
  NSString* code = CFBridgingRelease(CFErrorCopyDescription(err));
  [self.delegate socketError:self err:err errStr:code syscall:syscall];
}

-(id) initWithId:(NSString*)id_ hostName:(NSString*)host post:(NSUInteger)port delegate:(id <NodeSocketDelegate>)delegate_ {
  if (self = [super init]) {
    self.objectID = id_;
    self.delegate = delegate_;
    _data = [NSMutableData data];
    CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault, (__bridge CFStringRef)(host), port, &_readStream, &_writeStream);
    if (_readStream && _writeStream) {
      CFReadStreamSetProperty(_readStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
      CFWriteStreamSetProperty(_writeStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
      
      // This is supposed to keep the connection alive in the background mode (but has no effect unless we declare 'voip')
      CFReadStreamSetProperty(_readStream, kCFStreamNetworkServiceType, kCFStreamNetworkServiceTypeVoIP);
      CFWriteStreamSetProperty(_writeStream, kCFStreamNetworkServiceType, kCFStreamNetworkServiceTypeVoIP);

      CFStreamClientContext context = {0};
      context.info = (__bridge void *)(self);
      if (!CFReadStreamSetClient(_readStream,
            kCFStreamEventHasBytesAvailable | kCFStreamEventErrorOccurred | kCFStreamEventEndEncountered | kCFStreamEventOpenCompleted,
            &MyCFReadStreamCallback,
            &context )) {
        [self _emitReadStreamError:@"accept"];
        self = nil;
      }
      
      
      if (self && !CFWriteStreamSetClient(_writeStream,
            kCFStreamEventCanAcceptBytes | kCFStreamEventErrorOccurred | kCFStreamEventEndEncountered | kCFStreamEventOpenCompleted,
            &MyCFWriteStreamCallback,
            &context )) {
        [self _emitWriteStreamError:@"accept"];
        self = nil;
      }
      
      if (self) {
        CFReadStreamScheduleWithRunLoop(_readStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
        CFWriteStreamScheduleWithRunLoop(_writeStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
      }
      
      if (self && !CFReadStreamOpen(_readStream)) {
        [self _emitReadStreamError:@"accept"];
        self = nil;
      }
      if (self && !CFWriteStreamOpen(_writeStream)) {
        [self _emitWriteStreamError:@"accept"];
        self = nil;
      }
    } else {
      // CFStreamCreatePairWithSocket offers no feedback on errors
      [self.delegate socketError:self err:nil errStr:@"NOSTREAM" syscall:@"accept"];
      self = nil;
    }
  }
  return self;
}

-(id) initWithId:(NSString*)id_ nativeHandle:(CFSocketNativeHandle)nativeHandle parent:(NodeServer*)parent {
  if (self = [super init]) {
    self.objectID = id_;
    self.parent = parent;
    self.delegate = parent.delegate;
    _data = [NSMutableData data];
    CFStreamCreatePairWithSocket(kCFAllocatorDefault, nativeHandle, &_readStream, &_writeStream);
    if (_readStream && _writeStream) {
      //NSLog(@"Socket initWithNativeHandle: called");
      // Ensure the CF & BSD socket is closed when the streams are closed.
      CFReadStreamSetProperty(_readStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
      CFWriteStreamSetProperty(_writeStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
      
      CFStreamClientContext context = {0};
      context.info = (__bridge void *)(self);
      if (!CFReadStreamSetClient(_readStream,
            kCFStreamEventHasBytesAvailable | kCFStreamEventErrorOccurred | kCFStreamEventEndEncountered | kCFStreamEventOpenCompleted,
            &MyCFReadStreamCallback,
            &context )) {
        [self _emitReadStreamError:@"accept"];
        self = nil;
      }
      
      
      if (self && !CFWriteStreamSetClient(_writeStream,
            kCFStreamEventCanAcceptBytes | kCFStreamEventErrorOccurred | kCFStreamEventEndEncountered | kCFStreamEventOpenCompleted,
            &MyCFWriteStreamCallback,
            &context )) {
        [self _emitWriteStreamError:@"accept"];
        self = nil;
      }
      
      if (self) {
        CFReadStreamScheduleWithRunLoop(_readStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
        CFWriteStreamScheduleWithRunLoop(_writeStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
      }
      
      if (self && !CFReadStreamOpen(_readStream)) {
        [self _emitReadStreamError:@"accept"];
        self = nil;
      }
      if (self && !CFWriteStreamOpen(_writeStream)) {
        [self _emitWriteStreamError:@"accept"];
        self = nil;
      }
    } else {
      // CFStreamCreatePairWithSocket offers no feedback on errors
      [self.delegate socketError:self err:nil errStr:@"NOSTREAM" syscall:@"accept"];
      self = nil;
    }
  }
  return self;
}

-(void) _drainBlob {
  if (_data.length == 0 && _dataBlob) {
    NSUInteger bytesToCopy = _dataBlob.length - _cursorBlob;
    if (bytesToCopy <= BUFFER_SIZE) {
      [_data appendBytes:_dataBlob.bytes + _cursorBlob length:bytesToCopy];
      _dataBlob = nil;
    } else {
      [_data appendBytes:_dataBlob.bytes + _cursorBlob length:BUFFER_SIZE];
      _cursorBlob += BUFFER_SIZE;
    }
  }
}

-(void) _sendBytes {
  // We don't want to wire drain event if it's already empty
  if (_data.length > 0) {
    BOOL error = NO;
    while(!error && _data.length > 0 &&  CFWriteStreamCanAcceptBytes(_writeStream)) {
      CFIndex bytesToWrite = _data.length;
      if (bytesToWrite > BUFFER_SIZE) {
        bytesToWrite = BUFFER_SIZE;
      }
      CFIndex bytesWritten = CFWriteStreamWrite(_writeStream, _data.bytes, bytesToWrite);
      if (bytesWritten < 0) {
        NSLog(@"NC _sendBytes error writing %ld bytes (remain=%d)", bytesToWrite, _data.length);
        error = YES;
        [self _emitWriteStreamError:@"write"];
      } else {
        //NSData* dataDebug = [NSData dataWithBytes:_data.bytes length:bytesWritten];
        //NSString* strDebug = [[NSString alloc] initWithData:dataDebug encoding:NSUTF8StringEncoding];
        //NSLog(@"_sendBytes wrote(%@)", strDebug);
        
        _data = [NSMutableData dataWithBytes:_data.bytes+bytesWritten length:_data.length - bytesWritten];
      }
      [self _drainBlob];
    }
    //NSLog(@"NC _sendBytes %d %@", _data.length + (_dataBlob ? (_dataBlob.length - _cursorBlob) : 0), self.objectID);
    if (_data.length == 0) {
      [self.delegate socketWriteDidDrain:self];
    }
  }
}

-(void) write:(NSData*)data {
  if (_writeStream) {
    if (data.length > BUFFER_SIZE && !_dataBlob) {
      _dataBlob = data;
      _cursorBlob = 0;
      [self _drainBlob];
      NSAssert(_data.length > 0, @"NC _data must have some data here");
    } else {
      [_data appendData:data];
    }
    // This delay allows the chunked data to be submitted sequentially without causing the drain event
    dispatch_async(dispatch_get_main_queue(), ^{
      [self _sendBytes];
    });
  } else {
    NSLog(@"Socket no _writeStream");
  }
}

-(void) _close {
  //NSLog(@"NC _close %@", self.objectID);
  [super _close];
  if (_readStream) {
		CFReadStreamUnscheduleFromRunLoop(_readStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
    CFReadStreamSetClient(_readStream, kCFStreamEventNone, NULL, NULL);
    CFReadStreamClose(_readStream);
    CFRelease(_readStream);
    _readStream = NULL;
  }
  if (_writeStream) {
		CFWriteStreamUnscheduleFromRunLoop(_writeStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
    CFWriteStreamSetClient(_writeStream, kCFStreamEventNone, NULL, NULL);
    CFWriteStreamClose(_writeStream);
    CFRelease(_writeStream);
    _writeStream = NULL;
  }
}

-(void) close {
  [super close];
  [self.delegate socketEmitClose:self];
  if (self.parent) {
        [self.parent _childSocketDidClose:self];
  }
}
@end

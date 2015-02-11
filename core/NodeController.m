//
// NodeController.m
//   neu.Node
//
// Created by Satoshi Nakajima on 11/14/12.
//
// Copyright (c) 2012 Satoshi Nakajima All rights reserved.
//   Github: https://github.com/snakajima
//   Twitter: @snakajima
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the 'Software'), to
// deal in the Software without restriction, including without limitation the
// rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
// sell copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
// ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
// WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#import "NodeController.h"
#import "JSON.h"
#import "NodeServer.h"
#import "NodeConnection.h"
#include <ifaddrs.h>
#import "BDHost.h"


@interface NodeController () <NodeSocketDelegate, UIWebViewDelegate>

@end

@implementation NodeController
@synthesize autoStart = _autoStart;

-(id) initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
  if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
    _sockets = [NSMutableDictionary dictionary];
    _servers = [NSMutableDictionary dictionary];
  }
  return self;
}

#if TARGET_IPHONE_SIMULATOR
#define kIFAName @"en0"
#else
#define kIFAName @"en0"
#endif

- (NSString *)_getIPAddress {
	NSString *address = nil;
	struct ifaddrs *interfaces = NULL;
	
	// retrieve the current interfaces - returns 0 on success
	if (getifaddrs(&interfaces) == 0) {
		// Loop through linked list of interfaces
		struct ifaddrs *temp_addr = interfaces;
		while(temp_addr != NULL) {
			if(temp_addr->ifa_addr->sa_family == AF_INET) {
				// Check if interface is en0 which is the wifi connection on the iPhone
				NSString* ifaName = [NSString stringWithUTF8String:temp_addr->ifa_name];
				//NSLog(@"NC ifa_name=%@", ifaName);
				if((!address && [ifaName isEqualToString:@"pdp_ip0"]) || [ifaName isEqualToString:kIFAName]) {
					// Get NSString from C String
					address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr)];
				}
			}
			
			temp_addr = temp_addr->ifa_next;
		}
		// Free memory
		freeifaddrs(interfaces);
	}
	
	return address;
}

-(NSString*) appId {
  return self.appInfo ? [self.appInfo valueForKey:@"appId"] : @"app";
}

- (void)viewDidLoad {
  [super viewDidLoad];

  //NSString* appId = self.appId;
  //NSLog(@"NC viewDidLoad got appId %@", appId);
  NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
  NSString *path = [paths objectAtIndex:0];
  self.pathWorking = [path stringByAppendingPathComponent:self.appId];
  NSFileManager* manager = [NSFileManager defaultManager];
  if (![manager fileExistsAtPath:self.pathWorking]) {
    [manager createDirectoryAtPath:self.pathWorking withIntermediateDirectories:NO
                          attributes:nil error:NULL];
    //NSLog(@"NC viewDidLoad created working directory %@", self.pathWorking);
  } else {
    //NSLog(@"NC viewDidLoad we already has working directory %@", self.pathWorking);
  }

  self.webView = [[UIWebView alloc] initWithFrame:CGRectMake(240,10,80,20)];
  self.webView.hidden = YES;
  self.webView.delegate = self;
  [self.view addSubview:self.webView];
  _ipaddress = [self _getIPAddress];
  if (!_ipaddress) {
    _ipaddress = @"127.0.0.1";
  }
  if (self.autoStart) {
    [self play:nil];
  }

  NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
  [center addObserver:self selector:@selector(_didAppBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
  [center addObserver:self selector:@selector(_didAppEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
  [center addObserver:self selector:@selector(_didAppWillEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
  [center addObserver:self selector:@selector(_didAppWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
}

-(void) viewDidUnload {
  [super viewDidUnload];
  NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
  [center removeObserver:self];
}

-(void) _didAppBecomeActive:(NSNotification*)n {
  //NSLog(@"NC _didAppBecomeActive");
  // Waking up from the sleep mode or background mode (#2)
}
-(void) _didAppEnterBackground:(NSNotification*)n {
  //NSLog(@"NC _didAppEnterBackground");
  // Entering the sleep mode or background (#2)
  [self stop:nil];
}
-(void) _didAppWillEnterForeground:(NSNotification*)n {
  //NSLog(@"NC _didAppWillEnterForeground");
  // Waking up from the sleep mode or background (#1)
  
  // http://developer.apple.com/library/ios/#technotes/tn2277/_index.html
  /*  Once your app goes into the background, it may be suspended. Once it is suspended, it's unable to properly process incoming connections on the listening socket. However, the socket is still active as far as the kernel is concerned. If a client connects to the socket, the kernel will accept the connection but your app won't communicate over it. Eventually the client will give up, but that might take a while.
      Thus, it's better to close the listening socket when going into the background, which will cause incoming connections to be immediately rejected by the kernel.

      If the system suspends your app and then, later on, reclaims the resources from underneath your listening socket, your app will no longer be listening for connections, even after it has been resumed. The app may or may not be notified of this, depending on how it manages the listening socket. It's generally easier to avoid this problem entirely by closing the listening socket when the app is in the background. */
  [self play:nil];
}
-(void) _didAppWillResignActive:(NSNotification*)n {
  NSLog(@"NC _didAppWillResignActive");
  // Entering the sleep mode or background mode (#1)
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(NSString*) sendEvent:(NSString*)strEvent payload:(id)payload objectID:(NSString*)objectID sync:(BOOL)sync {
  NSMutableDictionary* json = [NSMutableDictionary dictionaryWithObject:strEvent forKey:@"event"];
  [json setValue:objectID forKey:@"objectID"];
  if (payload) {
    [json setValue:payload forKey:@"payload"];
  }
  NSString* script = [NSString stringWithFormat:@"process._ios.callback(%@, %@)",
    [json JSONRepresentation], sync ? @"true": @"false"];
  return [self.webView stringByEvaluatingJavaScriptFromString:script];
}

-(void) _write:(NSString*)objectID params:(NSDictionary*)json {
  NSString* buffer = [json valueForKey:@"buffer"];
  BOOL chunked = [[json valueForKey:@"chunked"] boolValue];
  BOOL deferred = [[json valueForKey:@"deferred"] boolValue];

  //NSLog(@"VS _write chunked = %d", chunked);
  NodeConnection* socket = [_sockets valueForKey:objectID];
  if (socket && [socket isKindOfClass:[NodeConnection class]]) {
    // This is just an attempt to fix 'drain with pending write' issue.
    [self sendEvent:@"_unqueuedWrite" payload:nil objectID:objectID sync:YES];
    
    NSData* data = [buffer dataUsingEncoding:NSUTF8StringEncoding];
    if (deferred) {
      // If there is any deferred data (such as HTTP header), write it now
      NSString* script = [NSString stringWithFormat:@"require('net').deferredData('%@', '%d')", objectID, data.length];
      NSString* deferredData  = [self.webView stringByEvaluatingJavaScriptFromString:script];
      if (deferredData.length > 0) {
        [socket write:[deferredData dataUsingEncoding:NSUTF8StringEncoding]];
      }
    }
    if (chunked) {
      NSString* chunkedHeader = [NSString stringWithFormat:@"%x\r\n", data.length];
      [socket write:[chunkedHeader dataUsingEncoding:NSUTF8StringEncoding]];
    }
    if (data.length > 0) {
      [socket write:data];
    }
    if (chunked) {
      [socket write:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    }
  } else {
    NSLog(@"VC _write: socket does not exist for %@", objectID);
  }
}

-(void) didServerRegister:(id <NodeService>)service {
}

-(void) _registerServer:(NodeServer*)server {
    [self registerSocket:server];
    [self registerServer:server];
    [self didServerRegister:server];
}

-(void) _listen:(NSString*)objectID params:(NSDictionary*)json {
  NSInteger port = [[json valueForKey:@"port"] intValue];
  NodeServer* server = [[NodeServer alloc] initWithId:objectID port:port delegate:self];
  if (server) {
    server.protocol = [json valueForKey:@"protocol"];
    server.url = [NSString stringWithFormat:@"%@://%@:%d", server.protocol, _ipaddress, server.port];
    [self _registerServer:server];
    NSString* payload = [NSString stringWithFormat:@"{ \"port\":%d, \"family\":\"IPv4\", \"address\":\"%@\" }",
                                                        server.port, _ipaddress];
    [self sendEvent:@"_listening" payload:payload objectID:server.objectID sync:NO];
    [self sendEvent:@"listening" payload:nil objectID:server.objectID sync:NO];
    
  } // no need to handle error because initWithId:port:delegate: will emit event if necessary
}

// Return system specific data
-(NSData*) _loadSystemDataForSocket:(NodeConnection*)socket filename:(NSString*)filename {
  NSData* data = nil;
  return data;
}

-(NSData*) dataForURL:(NSString*)url socket:(NodeConnection*)socket dir:(NSString*)dir pfilename:(NSString**)pfilename {
  NSDataReadingOptions options = NSDataReadingMappedAlways;
  NSMutableArray* components = [NSMutableArray arrayWithArray:[url pathComponents]];
  NSData* data = nil;
  NSString* filename = [components objectAtIndex:components.count-1];
  if ([filename isEqualToString:@"/"]) {
    filename = @"index.html";
  }
  if (pfilename) {
    *pfilename = filename;
  }
  
  if (components.count == 3 && socket && [[components objectAtIndex:1] isEqualToString:@"_sys"]) {
    data = [self _loadSystemDataForSocket:socket filename:filename];
  } else {
    NSString* trunk = nil;
    if (components.count > 1) {
      trunk = [components objectAtIndex:1];
    }
    
    NSString* pathAbs = nil;
    if ([trunk isEqualToString:@"_doc"]) {
      options = NSDataReadingMappedIfSafe;
      // ignore dir
      NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
      pathAbs = [paths objectAtIndex:0];
      for (int i = 2; i < components.count; i++) {
        pathAbs = [pathAbs stringByAppendingPathComponent:[components objectAtIndex:i]];
      }
    } else if ([trunk isEqualToString:@"_prv"]) {
      options = NSDataReadingMappedIfSafe;
      // ignore dir
      NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
      pathAbs = [paths objectAtIndex:0];
      for (int i = 2; i < components.count; i++) {
        pathAbs = [pathAbs stringByAppendingPathComponent:[components objectAtIndex:i]];
      }
    } else {
      if (dir && ![trunk isEqualToString:@"_lib"]) {
        NSString* path = [NSString stringWithFormat:@"%@%@", dir, url];
        components = [NSMutableArray arrayWithArray:[path pathComponents]];
      }
      [components removeLastObject]; // filename or '/'
      [components insertObject:@"root" atIndex:0];
      dir = [NSString pathWithComponents:components];
      pathAbs = [[NSBundle mainBundle] pathForResource:filename ofType:nil inDirectory:dir];
    }
  
    //;NSLog(@"_serve (pathAbs)=%@", pathAbs);
    if (pathAbs) {
      //
      // While it is possible to use asynchronous file I/O (in <aio.h>),
      // it is much better to use memory mapped NSData here.
      //
      // It takes only a few msec to create a memory mapped NSData, and
      // uses a small amount of physical memory to feed megabytes of file.
      //
      data = [NSData dataWithContentsOfFile:pathAbs options:options error:nil];
    }
  }
  return data;
}

-(void) _fileRead:(NSString*)objectID params:(NSDictionary*)json {
  NSString* path = [json valueForKey:@"path"];
  // Try the app bundle first
  NSData* data = [self dataForURL:path socket:nil dir:nil pfilename:nil];
  if (data) {
    NSString* payload = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    [self sendEvent:@"data" payload:payload objectID:objectID sync:NO];
  } else {
    // Try the working directory
    NSString* fullPath = [NSString stringWithFormat:@"%@%@", self.pathWorking, [json valueForKey:@"path"]];
    NSError * err = nil;
    NSString* payload = [NSString stringWithContentsOfFile:fullPath encoding:NSUTF8StringEncoding error:&err];
    if (payload) {
      [self sendEvent:@"data" payload:payload objectID:objectID sync:NO];
    } else {
      payload = [NSString stringWithFormat:@"ENOENT, No such file or directory '%@'", path];
      [self sendEvent:@"error" payload:payload objectID:objectID sync:NO];
    }
  }
}

-(void) _fileWrite:(NSString*)objectID params:(NSDictionary*)json {
  NSString* path = [NSString stringWithFormat:@"%@%@", self.pathWorking, [json valueForKey:@"path"]];
  NSLog(@"fileWrite was called %@", path);
  NSString* payload = [json valueForKey:@"payload"];
  NSString* encoding = [json valueForKey:@"encoding"];
  NSStringEncoding enc = [encoding isEqualToString:@"utf8"] ? NSUTF8StringEncoding : NSISOLatin1StringEncoding;
  NSError* err = nil;
  if ([payload writeToFile:path atomically:YES encoding:enc error:&err]) {
    //NSLog(@"NC _fileWrite succeeded %@", err.localizedDescription);
    [self sendEvent:@"success" payload:nil objectID:objectID sync:NO];
  } else {
    NSLog(@"NC _fileWrite failed %@", err.description);
    [self sendEvent:@"error" payload:err.localizedDescription objectID:objectID sync:NO];
  }
}

-(void) _fileSend:(NSString*)objectID params:(NSDictionary*)json {
  NSString* path = [NSString stringWithFormat:@"%@%@", self.pathWorking, [json valueForKey:@"path"]];
  NSLog(@"fileSend was called %@", path);
  NSDictionary* payload = [json valueForKey:@"payload"];
  if ([MFMailComposeViewController canSendMail]) {
    NSLog(@"fileSend is able to send e-mail");
    MFMailComposeViewController *mailer = [[MFMailComposeViewController alloc] init];
    mailer.mailComposeDelegate = self;
    if (payload) {
      NSString* subject = [payload valueForKey:@"subject"];
      if (subject) {
        [mailer setSubject:subject];
      }
    }
    
    NSError* err = nil;
    NSData* data = [NSData dataWithContentsOfFile:path options:NSDataReadingMappedIfSafe error:&err];
    if (data) {
      [mailer addAttachmentData:data mimeType:@"text/plain" fileName:@"summary.txt"];
      [self.navigationController.topViewController presentViewController:mailer animated:YES completion:nil];
      //[self.navigationController.topViewController presentModalViewController:mailer animated:YES];
    } else {
      [self sendEvent:@"error" payload:err.localizedDescription objectID:objectID sync:NO];
    }
  } else {
    [self sendEvent:@"error" payload:@"No Default E-email" objectID:objectID sync:NO];
  }
}

- (void)mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error
{
    switch (result)
    {
        case MFMailComposeResultCancelled:
            NSLog(@"Mail cancelled: you cancelled the operation and no email message was queued.");
            break;
        case MFMailComposeResultSaved:
            NSLog(@"Mail saved: you saved the email message in the drafts folder.");
            break;
        case MFMailComposeResultSent:
            NSLog(@"Mail send: the email message is queued in the outbox. It is ready to send.");
            break;
        case MFMailComposeResultFailed:
            NSLog(@"Mail failed: the email message was not saved or queued, possibly due to an error.");
            break;
        default:
            NSLog(@"Mail not sent.");
            break;
    }
        // Remove the mail view
    //[self.navigationController.topViewController dismissModalViewControllerAnimated:YES completion:nil];
    [self.navigationController.topViewController dismissViewControllerAnimated:YES completion:nil];
}

-(void) _close:(NSString*)objectID params:(NSDictionary*)json {
  NodeSocket* socket = [_sockets valueForKey:objectID];
  if (socket) {
    [socket close];
  } else {
    NSLog(@"NC _close: no socket %@", objectID);
  }
}

-(void) _resolve4:(NSString*)objectID params:(NSDictionary*)json {
    NSArray *payload=[BDHost addressesForHostname:[json valueForKey:@"domain"]];
    //NSLog(@"NC addresses=%@", payload);
    [self sendEvent:@"resolve4" payload:payload objectID:objectID sync:NO];
}

-(void) _connect:(NSString*)objectID params:(NSDictionary*)json {
  NSString* host = [json valueForKey:@"host"];
  NSUInteger port = [[json valueForKey:@"port"] intValue];
  //NSLog(@"NC connect was caled with %@:%d %@", host, port, objectID);
  NodeSocket* socket = [[NodeConnection alloc] initWithId:objectID hostName:host post:port delegate:self];
  [self registerSocket:socket];
}

// static file
-(void) _serve:(NSString*)objectID params:(NSDictionary*)json {
  NSString* url = [json valueForKey:@"url"];
  NSString* dir = [json valueForKey:@"dir"];
  BOOL hasCallback = ((NSNumber*)[json valueForKey:@"hasCallback"]).boolValue;
  NodeConnection* socket = [_sockets valueForKey:objectID];
  if (socket) {
    NSString* filename = nil;
    NSData* data = [self dataForURL:url socket:socket dir:dir pfilename:&filename];
    socket.status = data ? 200 : 404;
    NSString* script = [NSString stringWithFormat:@"require('static').header('%@', '%@', %d, %d)", objectID, filename, data.length, socket.status];
    NSString* header = [self.webView stringByEvaluatingJavaScriptFromString:script];
    NSDictionary *err = nil;
    if (data) {
      //NSLog(@"NC _serve: serving header on %@:\n%@", objectID, header);
      [socket write:[header dataUsingEncoding:NSUTF8StringEncoding]];
      [socket write:data]; 
    } else {
      NSLog(@"NC _serve can't find file %@", filename);
      if (hasCallback) {
        // face drain event
        err = [NSDictionary dictionaryWithObjectsAndKeys:
          [NSNumber numberWithInt:socket.status], @"status",
          [NSDictionary dictionary], @"headers", nil];
      } else {
        [socket write:[header dataUsingEncoding:NSUTF8StringEncoding]];
      }
    }
    [self sendEvent:@"_serve_complete" payload:err objectID:socket.objectID sync:YES];
  } else {
    NSLog(@"NC _serve: socket does not exist for %@", objectID);
  }
}

-(void) _appInfo:(NSString*)objectID params:(NSDictionary*)json {
  [self sendEvent:@"params" payload:[self.appInfo valueForKey:[json valueForKey:@"key"]] objectID:objectID sync:NO];
}

-(BOOL) dispatchCommand:(NSString*)cmd objectID:(NSString*)objectID params:(NSDictionary*)json {
  BOOL success = YES;
  if ([cmd isEqualToString:@"log"]) {
    NSLog(@"%@", [json valueForKey:@"log"]);
  } else if ([cmd isEqualToString:@"listen"]) {
    [self _listen:objectID params:json];
  } else if ([cmd isEqualToString:@"write"]) {
    [self _write:objectID params:json];
  } else if ([cmd isEqualToString:@"file.read"]) {
    [self _fileRead:objectID params:json];
  } else if ([cmd isEqualToString:@"file.write"]) {
    [self _fileWrite:objectID params:json];
  } else if ([cmd isEqualToString:@"file.send"]) {
    [self _fileSend:objectID params:json];
  } else if ([cmd isEqualToString:@"close"]) {
    [self _close:objectID params:json];
  } else if ([cmd isEqualToString:@"resolve4"]) {
    [self _resolve4:objectID params:json];
  } else if ([cmd isEqualToString:@"connect"]) {
    [self _connect:objectID params:json];
  } else if ([cmd isEqualToString:@"serve"]) {
    [self _serve:objectID params:json];
  } else if ([cmd isEqualToString:@"appInfo"]) {
    [self _appInfo:objectID params:json];
  } else {
    success = NO;
  }
  return success;
}

-(BOOL) webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
  NSString *requestString = [[request URL] absoluteString];
  //NSLog(@"requestString=%@", requestString);
  if ([requestString hasPrefix:@"dispatch:"]) {
    NSArray *components = [requestString componentsSeparatedByString:@":"];
    NSString *argsAsString = [(NSString*)[components objectAtIndex:1]
                                stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSDictionary* json = [argsAsString JSONValue];
    NSString* cmd = [json valueForKey:@"cmd"];
    NSString* objectID = [json valueForKey:@"id"];
    BOOL success = [self dispatchCommand:cmd objectID:objectID params:json];
    if (!success) {
      NSLog(@"VC unknown command %@", cmd);
    }
    return NO;
  }
  return YES;
}

-(void) socket:(NodeSocket*)socket onData:(NSData*)data {
  //NSString* str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
  NSString* str = [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding];
  if (data.length != str.length) {
    NSLog(@"NC onData %d, %d, %@", data.length, str.length, socket.objectID);
  }
  //NSDictionary* json = [NSDictionary dictionaryWithObject:str forKey:@"data"];
  [self sendEvent:@"data" payload:str objectID:socket.objectID sync:NO];
}

// This function is called when some change happened to any of servers
-(void) didServersUpdate {
}

-(void) registerSocket:(NodeSocket*)socket {
  //NSLog(@"VC registering %@", socket.objectID);
  [_sockets setValue:socket forKey:socket.objectID];
  if (_sockets.allKeys.count % 100 == 0) {
    NSLog(@"VC registerSocket: count=%d (%@)", _sockets.allKeys.count, socket.objectID);
  }
  _labelSockets.text = [NSString stringWithFormat:@"%d", _sockets.allKeys.count];
  [self didServersUpdate];
}

-(void) _unregisterSocket:(NodeSocket*)socket {
  //NSLog(@"VC unregistering %@", socket.objectID);
  [_sockets removeObjectForKey:socket.objectID];
  if (_sockets.allKeys.count % 100 == 0) {
    NSLog(@"VC _unregisterSocket: count=%d (%@)", _sockets.allKeys.count, socket.objectID);
  }
  _labelSockets.text = [NSString stringWithFormat:@"%d", _sockets.allKeys.count];
  [self didServersUpdate];
}

-(void) registerServer:(NodeServer *)server {
  [_servers setValue:server forKey:server.objectID];
  [self didServersUpdate];
}

-(void) _unregisterServer:(NodeServer *)server {
  [_servers removeObjectForKey:server.objectID];
  [self didServersUpdate];
}

-(NSString*) socketConnect:(NodeSocket*)socket {
  //NSLog(@"NC socketConnect %@", socket.objectID);
  return [self sendEvent:@"connection" payload:nil objectID:socket.objectID sync:YES];
}

-(void) socketReadStreamOpen:(NodeSocket*)socket {
  //NSLog(@"NC socketReadStreamOpen %@", socket.objectID);
  [self sendEvent:@"_read.open" payload:nil objectID:socket.objectID sync:NO];
}
-(void) socketWriteStreamOpen:(NodeSocket*)socket {
  //NSLog(@"NC socketWriteStreamOpen %@", socket.objectID);
  [self sendEvent:@"_write.open" payload:nil objectID:socket.objectID sync:NO];
}
-(void) socketReadStreamEnd:(NodeSocket*)socket {
  //NSLog(@"NC socketReadStreamEnd %@", socket.objectID);
  [self sendEvent:@"close" payload:nil objectID:socket.objectID sync:NO];
  [self _unregisterSocket:socket];
}

-(void) socketEmitClose:(NodeSocket*)socket {
  [self sendEvent:@"close" payload:nil objectID:socket.objectID sync:NO];
  [self _unregisterSocket:socket];
  if ([socket isKindOfClass:[NodeServer class]]) {
    [self _unregisterServer:(NodeServer*)socket];
  }
}

-(void) socketWriteDidDrain:(NodeConnection*)socket {
  //NSLog(@"NC socketWriteDidDrain %@", socket.objectID);
  NSString* isEmpty = [self sendEvent:@"_isWriteQueueEmpty" payload:nil objectID:socket.objectID sync:YES];
  //NSLog(@"VC iEmpty = %@", isEmpty);
  // We don't fire the drain event if there is a write event queued in the JS-bridge
  if ([isEmpty isEqualToString:@"yes"]) {
    [self sendEvent:@"drain" payload:nil objectID:socket.objectID sync:NO];
  }
}

-(void) socketError:(NodeSocket*)socket err:(CFErrorRef)err errStr:(NSString*)errStr syscall:(NSString*)syscall {
  NSLog(@"NC socketError %@, %@", socket.objectID, errStr);
  if (err) {
    CFStringRef str = CFErrorGetDomain(err);
    if (str == kCFErrorDomainPOSIX) {
      CFIndex index = CFErrorGetCode(err);
      if (index == ETIMEDOUT || index == EHOSTUNREACH) {
        NSLog(@"NC socketError ETIMEOUT %@, %ld", str, index);
      }
    }
  }
  NSMutableDictionary* payload = [NSMutableDictionary dictionaryWithObject:errStr forKey:@"code"];
  [payload setValue:syscall forKey:@"syscall"];
  //dispatch_async(dispatch_get_main_queue(), ^{
    [self sendEvent:@"error" payload:payload objectID:socket.objectID sync:NO];
  //});
}

@class WebView;
@class WebScriptCallFrame;
@class WebFrame;
- (void)webView:(WebView *)webView   exceptionWasRaised:(id)frame
       sourceId:(int)sid
           line:(int)lineno
    forWebFrame:(WebFrame *)webFrame
{
    NSLog(@"NSDD: exception: sid=%d line=%d function=%@, caller=%@, exception=%@", 
          sid, lineno,
          [frame performSelector:@selector(functionName)], [frame performSelector:@selector(caller)],
          [frame performSelector:@selector(exception)]
          );
}

-(IBAction) play:(id)sender {
  NSURLRequest* request = [NSURLRequest requestWithURL:self.url];
  [self.webView loadRequest:request];
  _btnPlay.enabled = NO;
  _btnStop.enabled = YES;
  [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
}

-(IBAction) stop:(id)sender {
  for (NSString* key in _servers.allKeys) {
    NodeServer* server = [_servers valueForKey:key];
    [server shutdown];
  }
  
  NSURL* url = [NSURL URLWithString:@"about:blank"];
  NSURLRequest* request = [NSURLRequest requestWithURL:url];
  [self.webView loadRequest:request];
  _btnPlay.enabled = YES;
  _btnStop.enabled = NO;
  [[UIApplication sharedApplication] setIdleTimerDisabled:NO];
}

-(NSArray*) allServers {
  NSMutableArray* servers = [NSMutableArray arrayWithCapacity:3];
  for (NSString* key in _servers.allKeys) {
    NodeServer* server = [_sockets valueForKey:key];
    [servers addObject:server];
  }
  return servers;
}

@end

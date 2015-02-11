//
// NodeController.h
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

#import <UIKit/UIKit.h>

@protocol NodeService <NSObject>
@property (nonatomic, readonly) NSString* url;
@property (nonatomic, readonly) NSString* protocol;
@property (nonatomic, readonly) NSUInteger port;
@property (nonatomic, readonly) NSUInteger connections; 
@property (nonatomic, readonly) NSMutableDictionary* extra; // extra storage
@property (nonatomic, strong) NSNetService* service; // bonjour
@end

@interface NodeController : UIViewController <MFMailComposeViewControllerDelegate> {
  IBOutlet UILabel *_labelSockets;
  IBOutlet UIBarButtonItem* _btnPlay, *_btnStop;

  NSString* _ipaddress;
  NSMutableDictionary* _sockets;
  NSMutableDictionary* _servers;
  BOOL _autoStart;
}
@property (nonatomic, strong) NSURL* url;
@property (nonatomic, strong) UIWebView* webView;
@property (nonatomic, strong) NSDictionary* appInfo;
@property (nonatomic, strong) NSString* pathWorking;
@property (nonatomic) BOOL autoStart;
-(IBAction) play:(id)sender;
-(IBAction) stop:(id)sender;
-(NSArray*) allServers; // <NodeService> objects
@end

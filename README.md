# neu.Node

## Overview

neu.Node is an implementation of Node.js-compatible API for iOS devices,
which allows the application developer to embed variety of micro servers (http server, chat server, proxy server, game server, etc.) in their iOS applications.

With neu.Node, iOS devices are no longer just "client" devices. 
They become network "nodes", which actively participate in providing
*distributed computing services* and enriching the user experience.

neu.Node enables new breeds of applications, such as:

- Server-less multi-player games
- Ad-Hoc/local social networking applications
- Peer-to-peer sharing, co-producing, and collaborations
- Real-time media transport (such as security camera)
- HTML5 apps with embedded proxy server for better caching and off-line support

## License

All code is licensed
under the [MIT License](http://www.opensource.org/licenses/mit-license.php).

## Support & Community

Please join [neu.Node](http://www.facebook.com/groups/486521141393508/) on Facebook.

## Node.js and neu.Node

neu.Node is NOT a straight port of Node.js to iOS. 
iOS has too many restrictions to run Node.js as-is.

iOS does not allow applications to
execute dynamically generated code, essentially
prohibiting V8's Just-In-Time compilation.

iOS does not allow applications to access low-level system
resources, such as file systems and processes, which Node.js
takes advantage of. 

In addition, the performance characteristic of mobile devices is very different
from servers, where the original Node.js was designed for. We need to pay a lot
more attention to the power consumption and memory usage on mobile devices,
and some techniques used in Node.js (such as thread pooling and in-memory cache) 
are not appropriate for mobile devices.

## Design principle and Architecture

The primary goal of this project is "offering a Node.js-compatible development 
environment for developers to run lightweight servers on iOS devices".

While it is quite important to be Node.js-compatible, it does not have to be
comprehensive. neu.Node offers a subset of Node.js API, which are
essential to implement embedded servers. 

neu.Node consists of libnode.core, which are implemented in Objective-C, 
and a set of standard JavaScript libraries.

It uses UIWebView as the JavaScript runtime (instead of V8).
It has a custom JavaScript/Objective-C (JS/OC) bridge to call Objective-C code from
JavaScript, and fire asynchronous events from Objective-C to JavaScript.

## Debugging

In order to debug your neu.Node application (written in JavaScript), you need to

  1. Run your app under xCode
  2. Attach Safari's Web Inspector to your app by choosing Develop -> *device name* -> *app name*

You need to enable "Web Inspector" of your iPhone/iPad by choosing Safari -> Advanced in the Settings application.

## Standard JavaScript Libraries

*global.js* is the key JavaScript library that implements the JS/OC bridge,
*require* method, as well as built-in globals such as *console* and *process*.

*assert.js, events.js, freelist.js, punycode.js, querystring.js and stream.js*
are directly brought from Node.js since they don't rely on any C++ code. 

*dns.js, fs.js, net.js, http.js* are neu.Node-specific implementations 
of equivalent modules in Node.js.

*static.js and mime.js* are standard extensions, which offer the equivalent functionality
to node-static (a popular module for static HTTP server). It uses memory mapped files to
efficiently serve large files over HTTP.

### Globals

#### require(module_name)

To require modules. 

Unlike regular Node.js, all required modules must be explicitly loaded in the *loader file*.

The contents of loader.html (a loader file):

    <html>
    <header>
    </header>
      <body></body>
      <script src="./global.js"></script>
      <script src="./util.js"></script>
      <script src="./events.js"></script>
      <script src="./punycode.js"></script>
      <script src="./querystring.js"></script>
      <script src="./url.js"></script>
      <script src="./path.js"></script>
      <script src="./stream.js"></script>
      <script src="./assert.js"></script>
      <script src="./freelist.js"></script>
      <script src="./dns.js"></script>
      <script src="./net.js"></script>
      <script src="./http.js"></script>
      <script src="./server.js"></script>
    </html>
  
The contents of server.js:

    var http = require('http');
    var server = http.createServer(handler);
    function handler(request, response) {
      ...
    }

#### __dirname

The name of the directory that the currently executing script resides in. 

Under neu.Node, the actual value of __dirname is always empty string,
which indicates the 'root' folder of the main bundle.

The contents of server.js:

    var fs = require('fs');
    fs.readFile(__dirname + '/myapp/templates.html', 
                'utf8', function(err, str) {
      ...
    });
    
In neu.Node, the readFile function above accesses the templates.html file in /root/myapp/ folder in the main bundle.

### module, module.exports, exports

In order to access module, module.exports and exports, each module file needs to be surrounded by
following code. 

    (function() {
      var module = require.register('module_name');
      var exports = module.exports;
      ...
      ... // definition of the module
      ...
    })();

If the module will be used for both neu.Node and Node.js, it needs to be surrounded by following code instead.

    (function(module_) {
      var module = module_ || require.register('module_name');
      var exports = module.exports;
      ...
      ... // definition of the module
      ...
    })(typeof module != 'undefined' ? module : null);

### process (global object)

#### process.platform

In neu.Node, this function returns 'ios'

#### process.nextTick(callback)

In neu.Node, this function is equivalent to `setTimeout(callback, 0)`

### console (global object)

#### console.log([data], [...])

In neu.Node, this function prints the output to the Xcode console

### net module

#### net.connect(options, [connectListner]), net.createConnection(options, [connectListner])

Creates a TCP socket connection to the host:port specified by options. The connectListner parameter will be
added as a listener for the 'connect' event. 

- options.host: specifies the hostname or ip address
- options.port: specifies the port number

#### Class: net.Socket()

Just like Node.js, this object is an abstraction of a TCP socket, 
which implements a duplex Stream interface.

#### net.createServer(connectionListner)

Creates a new TCP server. The connectionListner argument is automatically set as a listener for the 'connection' event. 

#### Class: net.Server(connectionListner)

This class is used to create a TCP or UNIX server. A server is a net.Socket that can listen for new incoming connections.

### http module

#### http.STATUS_CODES

A collection of all the standard HTTP response status codes, and the short description of each.

#### http.createServer(requestListner)

Returns a new web server object.

The requestListener is a function which is automatically added to the 'request' event.

#### http.request(options, callback)

options can be an object or a string. if options is a string, it is automatically parsed with url.parse().

Options:

- host: A domain name or IP address of the server to issue the request to. Defaults to 'localhost'.
- port: Port of remote server. Defaults to 80.
- method: method: A string specifying the HTTP request method. Defaults to 'GET'.
- headers: An object containing request headers.
- path: Request path. Defaults to '/'. Should include query string if any. E.G. '/index.html?page=12'

### fs module

#### fs.readFile(filename, encoding, callback)

Asynchronously reads the entire contents of a file. encoding must be 'utf8'.

If the filename start with '/_doc/', it will access the file in the Document directory. 
If the filename start with '/_prv/', it will access the file in the Library directory. 
Otherwise, it will access the file in the 'root' directory of the main bundle.

#### fs.writeFile(filename, data, encoding, callback)

Asynchronously writes data to a file, replacing the file if it already exists. data must be a string (not buffer unlike Node.js).

It always write the file into the *working directory* (the 'app' folder) of the Library directory.

### dns module

#### dns.resolve4(domain, callback)

Resolves a domain (e.g. 'google.com') into an array of IPv4 addresses. 

The callback has arguments (err, addresses).

## libnode.core

libnode.core is a static library implemented in Objective-C.

### NodeController class
 
The primary interface of libnode.core is *NodeController* class:

    @interface NodeController : UIViewController {
      IBOutlet UIBarButtonItem* _btnPlay, *_btnStop;
    }
    @property (nonatomic, strong) NSURL* url;
    @property (nonatomic) BOOL autoStart;
    @property (nonatomic, strong) NSDictionary* appInfo;
    -(IBAction) play:(id)sender;
    -(IBAction) stop:(id)sender;
    -(NSArray*) allServers;
    @end

  - *url* property specifies the location of the *loader* HTML file.
  - *autostart* property specifies if the server should automatically start running when the view becomes visible.
  - *appInfo* specifies the *working directory* name (under the Library directory).
  - *play:* method starts the server.
  - *stop:* method stops the server.
  - *allServer* method returns an array of *<NodeService>* instances.

The application should create an instance of NodeController, adds its view to the view hierarchy (does not have to be visible), and call play: method (or set the autoStart property before adding the view to the view hierarchy). 

### NodeService protocol

<NodeService> is a protocol which defines either *net* or *http* service offered by a neu.Node application.

    @protocol NodeService <NSObject>
    @property (nonatomic, readonly) NSString* url;
    @property (nonatomic, readonly) NSString* protocol;
    @property (nonatomic, readonly) NSUInteger port;
    @property (nonatomic, readonly) NSUInteger connections; 
    @property (nonatomic, readonly) NSMutableDictionary* extra; // extra storage
    @property (nonatomic, strong) NSNetService* service; // bonjour
    @end
    
- *url* specifies the url of the service (such as 'http://10.0.1.2:8000')
- *protocol* specifies the protocol ('http' or 'net')
- *port* specifies the port number assigned for this service
- *connections* indicates the number of current connections
- *extra* is an in-memory storage for application-specific data
- *service* is an instance of NSNetService object for bonjour (for future enhancement)



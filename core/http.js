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

(function() {
  var module = require.register('http');
  var exports = module.exports;

  var net = require('net');
  var util = require('util');
  var events = require('events');
  var url = require('url');
  var CRLF = '\r\n';
  var STATUS_CODES = exports.STATUS_CODES = {
    100 : 'Continue',
    101 : 'Switching Protocols',
    102 : 'Processing',                 // RFC 2518, obsoleted by RFC 4918
    200 : 'OK',
    201 : 'Created',
    202 : 'Accepted',
    203 : 'Non-Authoritative Information',
    204 : 'No Content',
    205 : 'Reset Content',
    206 : 'Partial Content',
    207 : 'Multi-Status',               // RFC 4918
    300 : 'Multiple Choices',
    301 : 'Moved Permanently',
    302 : 'Moved Temporarily',
    303 : 'See Other',
    304 : 'Not Modified',
    305 : 'Use Proxy',
    307 : 'Temporary Redirect',
    400 : 'Bad Request',
    401 : 'Unauthorized',
    402 : 'Payment Required',
    403 : 'Forbidden',
    404 : 'Not Found',
    405 : 'Method Not Allowed',
    406 : 'Not Acceptable',
    407 : 'Proxy Authentication Required',
    408 : 'Request Time-out',
    409 : 'Conflict',
    410 : 'Gone',
    411 : 'Length Required',
    412 : 'Precondition Failed',
    413 : 'Request Entity Too Large',
    414 : 'Request-URI Too Large',
    415 : 'Unsupported Media Type',
    416 : 'Requested Range Not Satisfiable',
    417 : 'Expectation Failed',
    418 : 'I\'m a teapot',              // RFC 2324
    422 : 'Unprocessable Entity',       // RFC 4918
    423 : 'Locked',                     // RFC 4918
    424 : 'Failed Dependency',          // RFC 4918
    425 : 'Unordered Collection',       // RFC 4918
    426 : 'Upgrade Required',           // RFC 2817
    428 : 'Precondition Required',      // RFC 6585
    429 : 'Too Many Requests',          // RFC 6585
    431 : 'Request Header Fields Too Large',// RFC 6585
    500 : 'Internal Server Error',
    501 : 'Not Implemented',
    502 : 'Bad Gateway',
    503 : 'Service Unavailable',
    504 : 'Gateway Time-out',
    505 : 'HTTP Version not supported',
    506 : 'Variant Also Negotiates',    // RFC 2295
    507 : 'Insufficient Storage',       // RFC 4918
    509 : 'Bandwidth Limit Exceeded',
    510 : 'Not Extended',               // RFC 2774
    511 : 'Network Authentication Required' // RFC 6585
  };


  function Server(requestListener) {
    net.Server.call(this);
 
    if (requestListener) {
      this.on('request', requestListener);
    }
    this.on('connection', connectionListener);
  }
  util.inherits(Server, net.Server);
  Server.prototype._protocol = 'http';
 
  exports.createServer = function(requestListener) {
    return new Server(requestListener);
  };

function IncomingMessage(header, isResponse) {
  var lines = header.split(CRLF);
  var fields = lines[0].split(' ');
  if (isResponse) {
    this.httpVersion = fields[0].split('/')[1];
    this.statusCode = parseInt(fields[1]);
  } else {
    this.method = fields[0].toUpperCase();
    this.url = fields[1];
    this.httpVersion = fields[2].split('/')[1];
  }
  lines.shift();
  this.headers = lines.reduce(function(headers, line) {
    var i = line.indexOf(':');
    if (i > 0) {
      headers[line.slice(0,i).toLowerCase()] = line.slice(i+1).trim();
    }
    return headers;
  }, {});
}
util.inherits(IncomingMessage, events.EventEmitter);
 
  function ServerResponse(socket, connection) {
    var self = this;
    this._socket = socket;
    this._connection = connection;
    this._ended = false;
    this._closeHandler = function() {
      if (!this._ended) {
        console.log('http:ServerResponce: client closed before the end', self._socket._index);
        // client closed the connection before the completion
        self.emit('close');
      }
    };
    this._socket.on('close', this._closeHandler);
  }
  util.inherits(ServerResponse, events.EventEmitter);
 
  ServerResponse.prototype._cleanup = function() {
    this._socket.removeListener('close', this._closeHandler);
  };
 
  ServerResponse.prototype._generateHead = function(statusCode, headersIn) {
    this._chunked = false; // always false for now
    this._keepAlive = false;
    var headers = {};
    for (var key in headersIn) {
      if (/Content-Length/i.test(key)) {
        var fKeepAlive = /keep-alive/i.test(this._connection);
        this._keepAlive = fKeepAlive;
      }
      headers[key] = headersIn[key];
    }
    if (this._keepAlive) {
      headers.Connection = 'keep-alive';
      if (this._chunked) {
        headers['Transfer-Encoding'] = 'chunked';
      }
    } else {
      headers.Connection = 'close';
    }
    var reasonPhrase = STATUS_CODES[statusCode] || 'unknown';
    var statusLine = 'HTTP/' + this._httpVersion + ' ' + statusCode.toString() + ' ' + reasonPhrase + CRLF;
    //console.debug('http receive header:\n%s', statusLine);
    var headerLines = Object.keys(headers).reduce(function(lines, key) {
      return lines + key + ':' + headers[key] + CRLF;
    }, statusLine);
    //console.debug('http respond headers:\n%s', headerLines);
    return headerLines + CRLF;
  };
  ServerResponse.prototype.writeHead = function(statusCode, headersIn) {
    var self = this;
    this._socket.setDeferred(function(size) {
      if (size > 0) {
        headersIn['Content-Length'] = size;
      }
      return self._generateHead(statusCode, headersIn);
    });
    //this._socket.write(this._generateHead(statusCode, headersIn));
  };
  ServerResponse.prototype.write = function(data) {
    data = this._socket.deferredData(0) + data;
    //this._socket.write(this._generateHead(statusCode, headersIn));
    this._socket.write(data, this._chunked);
  }
  ServerResponse.prototype.end = function(data) {
    // this._socket.deferredData(size) will be called if any
    // data = this._socket.deferredData(0) + data;
    this._ended = true;
    this._socket.write(data, this._chunked);
  }

  function connectionListener(socket) {
    var self = this; // Server
    var contentLength = 0;
    var receivedLength = 0;
    var buffer = '';
    var request = null;
    var response = null;

    socket.on('error', function(e) {
      self.emit('clientError', e, this);
    });
    socket.on('data', function(data) {
      if (request) {
        if (request.method == 'POST') {
          _process_post_data(data);
        }
      } else {
        buffer += data;
        var index = buffer.indexOf(CRLF+CRLF);
        if (index > 0) {
          var header = buffer.slice(0, index);
          request = new IncomingMessage(header);
          response = new ServerResponse(this, request.headers.connection);
          // Helper method for static
          socket._generateHead = function(statusCode, headersIn) {
            return response._generateHead(statusCode, headersIn);
          };
          //console.log('headers=' + JSON.stringify(request.headers));
          response._httpVersion = (request.httpVersion == '1.0') ? '1.0' : '1.1';
          buffer = buffer.slice(index + 4);
          //console.debug('http: _buffer.length=%d', buffer.length);
          self.emit('request', request, response);
          if (request.method == 'GET' || request.method == 'HEAD' || request.method == 'DELETE') {
            request.emit('end');
          } else if (request.method == 'POST') {
            contentLength = parseInt(request.headers['content-length']);
            if (buffer.length > 0) {
              _process_post_data(buffer);
            }
          } else {
            console.log('http.server unsupported method', request.method, buffer.length);
          }
        }
      }
      function _process_post_data(data) {
        request.emit('data', data);
        receivedLength += data.length;
        if (receivedLength >= contentLength) {
          request.emit('end');
        }
      }
    });
    socket.on('drain', function() {
      //console.debug('http got drain ended=%d, kA=%d', response._ended, response._keepAlive);
      //console.log('http: drain', socket._index, response._ended, response._keepAlive);
      if (response._ended) {
        response._cleanup(); // removes the close listner
        if (response._keepAlive) {
          //console.debug('http socket.complete called');
          request = null;
          response = null;
          buffer = '';
        } else {
          socket.close();
        }
        //console.log(typeof socket.removeAllListeners);
      }
    });
  }
 
function ClientRequest(options, cb) {
  var self = this;
  options.port = options.port || 80;
  options.host = options.host || 'localhost';
  options.method = (options.method || 'GET').toUpperCase();
  options.headers = options.headers || {};
  options.path = options.path || '/';

  if (cb) {
    self.once('response', cb);
  }
  var buffer = '';
  var fHeader = false;
  var response; // will be set when fHeader became true
  var socket = net.createConnection(options, function() {
    function sendHeader() {
      var header = Object.keys(options.headers).reduce(function(lines, key) {
        return lines + key + ':' + headers[key] + CRLF;
      }, options.method + ' ' + options.path + ' HTTP/1.0' + CRLF) + CRLF;
      socket.write(header);
    };
    if (self._end) {
      sendHeader(); // end() method was called before the connection
    } else {
      self.end = sendHeader; // override with instant specific method
    }
    socket.on('data', function(data) {
      buffer = buffer + data;
      if (!fHeader) {
        var index = buffer.indexOf(CRLF+CRLF);
        if (index > 0) {
          fHeader = true;
          response = new IncomingMessage(buffer.slice(0, index), true);
          buffer = buffer.slice(index + 4);
          self.emit('response', response);
        }
      }
      if (fHeader && buffer.length > 0) {
        response.emit('data', buffer);
        buffer = '';
      }
    }).on('drain', function() {
    }).on('close', function() {
      if (fHeader) {
        response.emit('end');
      } else {
        response.emit('close');
      }
    });
  }).on('error', function(err) {
    console.log('http:ClientRequest:error', err);
  });
};
util.inherits(ClientRequest, events.EventEmitter);

ClientRequest.prototype.end = function() {
  console.log('http:ClientRequest end was called before the connection');
  this._end = true;
};

exports.request = function(options, cb) {
  if (typeof options === 'string') {
    options = url.parse(options);
  }

  if (options.protocol && options.protocol !== 'http:') {
    throw new Error('Protocol:' + options.protocol + ' not supported.');
  }

  return new ClientRequest(options, cb);
};

})();
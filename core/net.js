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
  var module = require.register('net');
  var exports = module.exports;

  var util = require('util');
  var events = require('events');
  var Stream = require('stream');
  var dns = require('dns');

  function Socket() {
    Stream.call(this);
    this._queuedWrite = 0; // to detect the real drain
  }
  util.inherits(Socket, Stream);
  exports.Socket = Socket;

  Socket.prototype.readable = Socket.prototype.writable = true;

  Socket.prototype._callback = function(params) {
    var ret = null;
    //console.log("Socket._callback:%s, %s", params.event, typeof params.payload);
    this.emit(params.event, params.payload);
    if (params.event == 'close') {
      process._ios.unregisterObject(this);
    } else if (params.event == '_unqueuedWrite') {
      this._queuedWrite--;
      //console.log('net got _unqueuedWrite', this._queuedWrite);
    } else if (params.event == '_isWriteQueueEmpty') {
      ret = (this._queuedWrite == 0) ? 'yes' : 'no';
    }
    return ret;
  };
  Socket.prototype.write = function(buffer, chunked) {
    this._queuedWrite++;
    process._ios.call({ cmd:'write', callback:this, buffer:buffer,
                        chunked:chunked || false, deferred:this._deferred ? true : false });
  };
  Socket.prototype.close = function() {
    process._ios.call({ cmd:'close', callback:this });
  };
  Socket.prototype.connect = function(options, cb) {
    var self = this;
    if (typeof cb === 'function') {
      self.on('connect', cb);
    }
    if (!options.host) {
      connect(self, '127.0.0.1', options.port);
    } else {
      require('dns').resolve4(options.host, function(err, addresses) {
        if (err) {
          process.nextTick(function() {
            self.emit('error', err);
            //self._destroy();
          });
        } else {
          connect(self, addresses[0], options.port);
        }
      });
    }
    return self;
  };
  function connect(socket, address, port) {
    process._ios.registerObject(socket);
    //console.log('net: connect was called with', address, port, socket._index);
    socket.on('_write.open', function() {
      socket.emit('connect');
    });
    process._ios.call({ cmd:'connect', host:address, port:port , callback:socket});
  };
  Socket.prototype.setDeferred = function(callback) {
    this._deferred = callback;
  };
  Socket.prototype.deferredData = function(size) {
    var ret = '';
    if (this._deferred) {
      ret = this._deferred(size);
      delete this._deferred;
    }
    return ret;
  };
  exports.deferredData = function(objectID, size) {
    var socket = process._ios.objectFromID(objectID);
    return socket ? socket.deferredData(size) : '';
  };
  exports.connect = exports.createConnection = function(options, cb) {
    var socket = new Socket();
    return socket.connect(options, cb);
  };
 
  function Server(handler) {
    process._ios.registerObject(this);
    if (handler) {
      this.on('connection', handler);
    }
  }
  util.inherits(Server, events.EventEmitter);
  Server.prototype._protocol = 'net';

  Server.prototype.listen = function(port, callback) {
    this.on('_listening', function(payload) {
      this._address = JSON.parse(payload);
    });
    if (callback) {
      this.on('listening', callback);
    }
    process._ios.call({ cmd:'listen', callback:this, port:port, protocol:this._protocol });
    return this;
  };
  Server.prototype.address = function() { return this._address; }
  Server.prototype._callback = function(params) {
    var ret = null;
    //console.debug("Server._callback:" + params.event + ',' + typeof params.payload);
    if (params.event == "connection") {
      var socket = new Socket();
      socket._server = this;
      ret = process._ios.registerObject(socket);
      this.emit(params.event, socket);
      socket.emit('connect');
    } else {
      this.emit(params.event, params.payload);
    }
    return ret;
  };
  Server.prototype.close = function(callback) {
    if (callback) {
      this.on('close', callback);
    }
    process._ios.call({ cmd:'close', callback:this });
  }
 
  exports.Server = Server;
  exports.createServer = function(handler) {
      return new Server(handler);
  };

  /*
  function errnoException(errorno, syscall) {
    var e = new Error(syscall + ' ' + errorno);
    e.errno = e.code = errorno;
    e.syscall = syscall;
    return e;
  }
  */
  
})();
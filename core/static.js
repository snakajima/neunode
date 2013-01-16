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
  var module = require.register('static');
  var exports = module.exports;

  var mime = require('mime');
  var path = require('path');
  var http = require('http');
 
  function Server(dir, options) {
    this.dir = dir;
    this.options = { };
    if (typeof options == 'object') {
      for (var key in options) {
        this.options[key] = options[key];
      }
    };
  }
  Server.prototype.serve = function(req, res, callback) {
    if (callback) {
      var start = new Date();
      res._socket.once('_serve_complete', function(err) {
        if (err) {
          res._ended = false; // HACK: Undoing the end() in case of error with callback
          err.message = http.STATUS_CODES[err.status];
          process.nextTick(function() {
            callback(err /*, result*/);
          });
        } else {
          //console.log("static serving", req.url, ((new Date()) - start) / 1000);
          res._socket.once('drain', function(err) {
            callback(null /*, result*/);
          });
        }
      })
    }
    res._ended = true; // HACK: This is effectively calling end()
    process._ios.call({ cmd:'serve', callback:res._socket, dir:this.dir, url:req.url, hasCallback: callback ? true : false });
  }
 
  exports.createServer = function(dir, options) {
    return new Server(dir, options);
  };
 
  exports.header = function(objectID, filename, size, status) {
    var ret = '';
    var socket = process._ios.objectFromID(objectID);
    if (socket) {
      var headers = {};
      var ext = path.extname(filename).slice(1).toLowerCase();
      headers['Content-Type']   = mime.contentTypes[ext] || 'application/octet-stream';
      if (size > 0) {
        headers['Content-Length'] = size;
      }
      ret = socket._generateHead(status, headers);
    } else {
      console.log('ERROR static.header invalid objectID = ', objectID);
    }
    return ret;
  };
})();
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
  var module = require.register('fs');
  var exports = module.exports;

  exports.readFile = function(filename, encoding, callback) {
    process._ios.call({
      cmd:'file.read', 
      path:filename,
      callback:function(params){
        if (params.event == 'data') {
          callback(null, params.payload);
        } else  if (params.event == 'error') {
          callback(new Error(params.payload));
        }
      }
    });
  };
 
  exports.writeFile = function(filename, data, encoding, callback) {
    process._ios.call({
      cmd:'file.write',
      path:filename,
      payload:data,
      encoding:encoding,
      callback:function(params){
        if (params.event == 'error') {
          callback(new Error(params.payload));
        } else {
          callback(null);
        }
      }
    });
  };
 
})();
//
// Copyright (c) 2012 Satoshi Nakajima All rights reserved.
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

var __dirname = '';

var require = (function() {
  var _modules = {};
  var func = function(name) {
    // treat require('./foo') as require('foo')
    if (name.slice(0,2)=='./') {
      name = name.slice(2);
    }
    if (!_modules[name]) {
      console.error('*** ALERT *** No module named ' + name);
      return null;
    }
    return _modules[name].exports;
  };
  func.register = function(name) {
    _modules[name] = { exports:{} };
    return _modules[name];
  };
  return func;
})();

var console = (function() {
  function _log(format) {
    if (process._ios) {
      var params = [format];
      for (var i=1, max=arguments.length; i<max; i++) { params.push(arguments[i])};
      var str = require('util').format.apply(this, params);
      process._ios.call({ cmd:'log', log:str });
    }
  }
  function _none() {}
  return {
    log: _log,
    trace: _log,
    debug: _none,
    error: _log
  };
})();


var process = (function() {
  return {
    stdout: { write:function() {} },
    stderr: { write:function() {} },
    platform: 'ios',
    nextTick: function(callback) {
      setTimeout(callback, 0);
    },
    binding: function(name) {
      //console.log('binding:' + name);
      return {};
    }
  };
})();

(function() {
  var _objects = {};
  var _deffered = []; // deferred ios calls
  var _counter = 0;
 
  document.addEventListener( "DOMContentLoaded", _ready, false );
 
  function _ready() {
    process._ios.call = process._ios._call;
    for (var i=0, max=_deffered.length; i < max; i++) {
      process._ios.call(_deffered[i]);
    }
    _deffered = null;
		document.removeEventListener( "DOMContentLoaded", _ready, false );
  }

  process._ios = {
    registerObject: function(obj) {
      obj._index = 'id' + _counter;
      _objects[obj._index] = obj;
      _counter++;
      if (Object.keys(_objects).length % 10 == 0) {
        console.log('process._ios object ++count = ' + Object.keys(_objects).length);
      }
      return obj._index;
    },
    unregisterObject: function(obj) {
      delete _objects[obj._index];
      if (Object.keys(_objects).length % 10 == 0) {
        console.log('process._ios object --count = ' + Object.keys(_objects).length);
      }
    },
    objectID: function(obj) {
      return obj._index;
    },
    objectFromID: function(objectID) {
      return _objects[objectID];
    },
    _call: function(json) {
      var callback = json.callback;
      if (json.id) {
        console.log('global:_call unexpected id');
      }
      if (typeof callback == 'object') {
        json.id = json.callback._index;
      } else if (typeof callback == 'function') {
        var obj = {
          _callback:function(params) {
            callback(params);
            process._ios.unregisterObject(obj);
          }
        };
        json.id = process._ios.registerObject(obj);
      }
      delete json.callback;
      var iframe = document.createElement("IFRAME");
      iframe.src = "dispatch:" + encodeURIComponent(JSON.stringify(json));
      document.documentElement.appendChild(iframe);
      iframe.parentNode.removeChild(iframe);
      iframe = null;
    },
    call: function(json) {
      _deffered.push(json);
    },
    callback: function(params, sync) {
      var ret = null;
      var obj = _objects[params.objectID];
      if (obj && typeof obj._callback == 'function') {
        if (sync) {
          ret = obj._callback(params);
        } else {
          (function(obj, params) {
            setTimeout(function() {
              obj._callback(params);
            }, 10);
          })(obj, params);
        }
      } else {
        console.log('process._ios ERROR: no object for %s', params.objectID);
      }
      return ret;
    }
  };
})();

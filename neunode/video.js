var server = require('http').createServer(handler);
var static = require('static').createServer(__dirname + '/video', {} );
var util = require('util');

server.listen(8000, function() {
  var address = server.address();
  console.log('Server is running at http://%s:%d', address.address, address.port);
  console.log('Access this URL with Safari browser.');
});

function handler(req, res) {
  req.on('end', function() {
    static.serve(req, res, function(err) {
      if (err) { 
        console.log("app file > Error serving " + req.url + " - " + err);
        err.headers['Content-Type'] = 'text/html; charset=UTF-8';
        res.writeHead(err.status, err.headers);
        res.end(util.format("<h1>%d : %s<h1>", err.status, err.message));
      }
    });
  });
}
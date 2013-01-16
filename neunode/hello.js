var http = require('http');

var server = http.createServer(function (req, res) {
  res.writeHead(200, {'Content-Type': 'text/plain'});
  res.end('Hello World\n');
});

server.listen(8000, function() {
  var address = server.address();
  console.log('Server is running at http://%s:%d', address.address, address.port);
  console.log('Access this URL with your browser.');
});

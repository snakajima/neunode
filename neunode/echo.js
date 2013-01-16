var net = require('net');

var server = net.createServer(function (socket) {
  socket.write('Echo server\r\n');
  socket.pipe(socket);
});

server.listen(1337, function() {
  var address = server.address();
  console.log('Server is running at', address);
  console.log('Use "telnet %s %d" to see the action', address.address, address.port);
});
var net = require('net');
var index = 0;
var sockets = {};

var server = net.createServer(function(socket) {
  socket.id = index++;
  sockets[socket.id] = socket;
  
  socket.on('data', function(data) {
    for (var id in sockets) {
      if (id != socket.id) {
        sockets[id].write(data);
      }
    }
  });
  
  socket.on('close', function() {
    delete sockets[socket.id];
  });
});

server.listen(1337, function() {
  var address = server.address();
  console.log('Server is running at', address);
  console.log('Use "telnet %s %d" to see the action', address.address, address.port);
});
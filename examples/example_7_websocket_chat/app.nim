import ../../src/xander
from strutils import format
from random import randomize, rand

randomize()

get "/":
  respond tmplt("index")
  
type 
  Client = tuple
    id: int 
    socket: WebSocket

var clients {.threadvar.} : seq[Client]
clients = newSeq[Client]()

proc addClient(socket: WebSocket): Client = 
  result = (rand(1000), socket)
  clients.add(result)

proc sendMessageToAll(message: string) {.async.} =
  for client in clients:
    if client.socket.readyState == Open:
      await client.socket.send(message)

websocket "/ws":
  var client = addClient(ws)
  while ws.readyState == Open:
    let packet = await ws.receiveStrPacket()
    let message = "anon#$1: $2".format(client.id, packet)
    await sendMessageToAll(message)

serveFiles("/public")
printServerStructure()
runForever(3000)
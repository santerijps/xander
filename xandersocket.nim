import asyncnet, asyncdispatch, threadpool
export asyncnet, asyncdispatch, threadpool

type
  Client* = tuple
    socket: AsyncSocket
    name: string
    connected: bool
  LineHandler* = proc(client: Client, line: string): Future[bool]
  ConnectionHandler* = proc(socket: AsyncSocket): Future[Client]
  DisconnectionHandler* = proc(client: Client): Future[void]
  InitHandler* = proc(): Future[void]

var
  server {.threadvar.}: AsyncSocket
  port {.threadvar.}: uint
  lineHandler {.threadvar.}: LineHandler
  connectionHandler {.threadvar.}: ConnectionHandler
  disconnectionHandler {.threadvar.}: DisconnectionHandler
  initHandler {.threadvar.}: InitHandler

proc processClient(socket: AsyncSocket) {.async.} =
  defer: close(socket)
  var client = await connectionHandler(socket)
  var keepGoing = true
  while keepGoing:
    let line = await client.socket.recvLine()
    keepGoing = await lineHandler(client, line)
  await disconnectionHandler(client)

proc serve() {.async.} =
  server = newAsyncSocket()
  server.bindAddr(Port(port))
  server.listen()
  defer: close(server)
  echo "Socket server listening on port ", port
  while true:
    let socket = await server.accept()
    asyncCheck processClient(socket)

proc setOnConnect*(handler: ConnectionHandler) =
  connectionHandler = handler

proc setOnReceiveLine*(handler: LineHandler) =
  lineHandler = handler

proc setOnDisconnect*(handler: DisconnectionHandler) =
  disconnectionHandler = handler

proc setPort*(p: uint) =
  port = p

proc startSocket*(init: InitHandler) =
  discard init()
  asyncCheck serve()
  runForever()

proc onSigInt() {.noconv.} = 
  if not isClosed(server):
    close(server)
  quit(0)

setControlCHook(onSigInt)
import
  ../../xander,
  ../../xandersocket

get("/", proc(req: Request, vars: var Data): Response =
  displayTemplate("index"))

var clients {.threadvar.}: seq[Client]

proc connectionHandler(socket: AsyncSocket): Future[Client] {.async.} =
  #await socket.send("Please enter your name:")
  discard await socket.recvLine()
  var client: Client = (socket, await socket.recvLine(), true)
  clients.add(client)
  echo clients
  return client

proc lineHandler(client: Client, line: string): Future[bool] {.async.} =
  result = true
  if line == "exit":
    result = false
  else:
    for c in clients:
      if c != client and not(isClosed(c.socket)):
        await c.socket.send(client.name & ">" & line & "\c\L")
    await client.socket.send("len = " & $line.len & "\c\L")

proc disconnectionHandler(client: Client): Future[void] {.async.} =
  await client.socket.send("Bye!\c\L")

spawn startSocket(proc(): Future[void] = 
  clients = @[]
  xandersocket.setOnConnect(connectionHandler)
  xandersocket.setOnReceiveLine(lineHandler)
  xandersocket.setOnDisconnect(disconnectionHandler)
  xandersocket.setPort(3001)
)

startServer()

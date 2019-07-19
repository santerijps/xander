import ../../src/xander
import ws

get "/":
  respond tmplt("index")

get "/about":
  respond tmplt("about")

get "/contact":
  respond tmplt("contact")

requestHook = proc(request: Request) {.async.} =
  if request.url.path == "/ws":
    try:
      var ws = await newWebSocket(request)
      while ws.readyState == Open:
        let packet = await ws.receiveStrPacket()
        await ws.send(packet)  
    except:
      echo "Socket closed!"
  else:
    await request.respond(Http200, "Hello World!")

serveFiles("/public")
printServerStructure()
runForever(3000)
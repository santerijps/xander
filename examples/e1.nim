import ../xander

get("/", proc(req: Request, vars: var Data): Response =
  display("The Index"))

get("/about", proc(req: Request, vars: var Data): Response = 
  display("This is the very basic example"))

startServer()
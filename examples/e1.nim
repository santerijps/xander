import ../Xander

get("/", (r, v) => r.respond("The index page"))

get("/about", proc(req: Request, vars: Vars) {.async.} = 
  await req.respond("This is the very basic example")
)

startServer()
# Xander
A simple HTTP library for Nim inspired by Node.js and Express.

A basic example:
```nim
import ../Xander

get("/", (r, v) => r.respond("The index page"))

get("/about", proc(req: Request, vars: Vars) {.async.} = 
  await req.respond("This is the very basic example")
)

startServer()
```
More examples can be found in the ```examples``` folder.
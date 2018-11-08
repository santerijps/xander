import ../../../../xander

proc serveIndexPage*(req: Request, vars: Vars) {.async.} =
  await req.display("index", vars)
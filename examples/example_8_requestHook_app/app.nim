import ../../src/xander

requestHook = proc(r: Request) {.async.} =
  await r.respond( Http200, "Hello World!")

runForever(3000)
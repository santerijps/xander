import ../xander

# New
get "/":
  # The variables
  # - req: asynchttpserver.Request
  # - vars: var xander.Data
  # exist in this context implicitly
  assert(vars.len == 0)
  display("The index page")

# Legacy
addGet("/about", proc(req: Request, vars: var Data): Response = 
  # The variables req and vars are declared explicitly.
  # This proc can be used when the route handler proc is in a different module.
  vars["page"] = "about"
  displayJSON(vars))

startServer()
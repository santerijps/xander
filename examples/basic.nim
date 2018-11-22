import xander

# New
get "/":
  # The variables
  # - req: asynchttpserver.Request
  # - vars: var xander.Data
  # exist in this block implicitly, as well as
  # the return type 'Response'. The built in display methods (display, displayTemplate, displayJSON)
  # have the 'Response' return type, thus no explicit return statement is required.
  assert(vars.len == 0)
  display("The index page")

# Legacy
addGet("/about", proc(req: Request, vars: var Data): Response = 
  # The variables req and vars are declared explicitly.
  # This way the handler proc can be stored in a controller file.
  vars["page"] = "about"
  displayJSON(vars))

startServer()
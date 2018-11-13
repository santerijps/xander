import ../../../../xander

proc serveIndexPage*(req: Request, vars: var Data): Response =
  displayTemplate("index", vars)
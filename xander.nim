import
  asyncdispatch as async,
  asynchttpserver as http,
  os, strutils, tables, re, json, sugar,
  xandercli

export
  async,
  http,
  json,
  tables,
  sugar

type
  APP_MODE* = enum
    DEBUG
    PROD
  Vars* = Table[string, string]

proc newVars*(): Vars = initTable[string, string]()

var # Define globals
  server {.threadvar.}: AsyncHttpServer
  html {.threadvar.}: Vars
  mode* {.threadvar.}: APP_MODE
  port* {.threadvar.}: uint
  projectDir {.threadvar.}: string
  publicDir {.threadvar.}: string
  templateDir {.threadvar.}: string
  routes {.threadvar.}: Table[HttpMethod, Table[string, proc(req: http.Request, vars: Vars): Future[void]]]
  statics {.threadvar.}: Vars

# global initializations
server = http.newAsyncHttpServer()
html = initTable[string ,string]()
routes = initTable[HttpMethod, Table[string, proc(req: http.Request, vars: Vars): Future[void]]]()
mode = APP_MODE.DEBUG
port = 3000
projectDir = os.getAppDir().parentDir()
publicDir = projectDir & "/public/"
templateDir = projectDir & "/app/views/"
statics = newVars()

proc initTemplates(root: string) =
  for filepath in os.walkFiles(root & "*"):
    html[filepath.splitFile().name] = open(filepath, fmRead).readAll()
  for dir in os.walkDirs(root & "*"):
    initTemplates(dir & "/")

proc putVars(page: string, vars: Vars): string =
  result = page
  for key in vars.keys:
    result = result.replace("{[" & key & "]}", vars[key])

proc buildPage(page: string, vars: Vars): string =
  result = html["layout"].replace("{[%content%]}", html[page])
  result = putVars(result, vars)

proc getTemplate*(name: string): string =
  if html.hasKey(name):
    result = html[name]

proc serve404(req: http.Request) {.async.} =
  var page: string = "404 page not found"
  if html.hasKey("error"):
    var vars = newVars()
    vars["title"] = "Error"
    vars["code"] = "404"
    vars["message"] = "Not found."
    page = buildPage("error", vars)
  await req.respond(Http404, page)

proc getJsonData(keys: OrderedTable[string, JsonNode], node: JsonNode): Vars = 
  result = newVars()
  for key in keys.keys:
    result[key] = node[key].getStr()

proc parseRequestBody(body: string): Vars =
  var
    parsed = json.parseJson(body)
    keys = parsed.getFields()
  return getJsonData(keys, parsed)

proc isValidGetPath(url, kind: string, params: var Vars): bool =
  var 
    kind = kind.split("/")
    klen = kind.len
    url = url.split("/")
  result = true
  if url.len == klen:
    for i in 0..klen-1:
      if ":" in kind[i]:
        params[kind[i][1..kind[i].len-1]] = url[i]
      elif kind[i] != url[i]:
        result = false
        break
  else:
    result = false

proc checkPath(req: http.Request, kind: string, vars: var Vars): bool =
  result = false
  if routes.hasKey(req.reqMethod):
    if req.reqMethod == HttpGet: # URL parameters
      var getParams = newVars()
      if req.url.path.isValidGetPath(kind, getParams):
        result = true
        vars = getParams
    else: # Request body
      if req.url.path == kind:
        result = true
        vars = parseRequestBody(req.body)
  
proc checkRoutes(req: http.Request) {.async.} =
  var vars: Vars
  if routes.hasKey(req.reqMethod):
    for route in routes[req.reqMethod].keys:
      if checkPath(req, route, vars):
        await routes[req.reqMethod][route](req, vars)
        return
  await serve404(req)

proc addRoute(httpMethod: HttpMethod, path: string, handler: proc(req: http.Request, vars: Vars): Future[void]) =
  if not routes.hasKey(httpMethod):
    routes[httpMethod] = initTable[string, proc(req: http.Request, vars: Vars): Future[void]]()
  routes[httpMethod][path] = handler

proc get*(path: string, handler: proc(req: http.Request, vars: Vars): Future[void]) =
  addRoute(HttpMethod.HttpGet, path, handler)

proc post*(path: string, handler: proc(req: http.Request, vars: Vars): Future[void]) =
  addRoute(HttpMethod.HttpPost, path, handler)

proc delete*(path: string, handler: proc(req: http.Request, vars: Vars): Future[void]) =
  addRoute(HttpMethod.HttpDelete, path, handler)
  
proc put*(path: string, handler: proc(req: http.Request, vars: Vars): Future[void]) =
  addRoute(HttpMethod.HttpPut, path, handler)
  
proc display*(req: http.Request, templ: string, vars: Vars = newVars(), code: HttpCode = Http200) {.async.} =
  await req.respond(code, buildPage(templ, vars))

proc respond*(req: http.Request, body: string, code: HttpCode = Http200) {.async.} =
  await req.respond(code, body)

proc setPublicDir*(dir: string) = 
  publicDir = dir
  if publicDir[publicDir.len - 1] != '/':
    publicDir = publicDir & '/'

proc setTemplateDir*(dir: string) =
  templateDir = dir
  if templateDir[templateDir.len - 1] != '/':
    templateDir = templateDir & '/'

setControlCHook(proc() {.noconv.} = quit(0))

proc initStatics(root: string) =
  for file in os.walkFiles(root & "*"):
    var 
      f = "/" & (file.replace(publicDir, ""))
      fp = f.parentDir() & "/"
    statics[fp & f.extractFilename()] = open(file, fmRead).readAll()
    get(fp & ":file", (r, v) => r.respond(Http200, statics[fp & v["file"]]))
  for dir in os.walkDirs(root & "*"):
    initStatics(dir & "/")

proc init() =
  initStatics(publicDir)
  initTemplates(templateDir)

proc requestHandler(req: http.Request) {.async.} =
  if mode == APP_MODE.DEBUG:
    init()
  await checkRoutes(req)

proc startServer*() =
  init()
  echo "Server listening on port ", port
  async.waitFor server.serve(async.Port(port), requestHandler)

when isMainModule:
  xandercli.runXander()
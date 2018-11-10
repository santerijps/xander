import
  asyncdispatch as async,
  asynchttpserver as http,
  os, strutils, tables, regex, json, sugar, typetraits,
  xandercli

export
  async,
  http,
  json,
  tables,
  sugar

type # Custom types
  APP_MODE* = enum DEBUG, PROD
  Dictionary* = Table[string, string]
  HandlerProc* = proc(req: http.Request, vars: var Data): Response
  Route = Table[string, HandlerProc]
  RoutingTable = Table[HttpMethod, Route]
  Data* = JsonNode
  Response* = tuple[body: string, code: HttpCode]

# Custom type functions
func newDictionary(): Dictionary = initTable[string, string]()
func newRoute(): Route = initTable[string, HandlerProc]()
func newRoutingTable(): RoutingTable = initTable[HttpMethod, Route]()
func newData*(): Data = newJObject()
func newData*[T](key: string, value: T): Data =
  result = newData()
  result.add(key, %value)
func set*[T](node: var Data, key: string, value: T) = node.add(key, %value)
func `[]=`*[T](node: var Data, key: string, value: T) = node.add(key, %value)

var # Define globals
  server {.threadvar.}: AsyncHttpServer
  html {.threadvar.}: Dictionary
  mode {.threadvar.}: APP_MODE
  port {.threadvar.}: uint
  projectDir {.threadvar.}: string
  publicDir {.threadvar.}: string
  templateDir {.threadvar.}: string
  routes {.threadvar.}: RoutingTable
  statics {.threadvar.}: Dictionary

# Global initializations
server = http.newAsyncHttpServer()
html = newDictionary()
routes = newRoutingTable()
mode = APP_MODE.DEBUG
port = 3000
projectDir = os.getAppDir().parentDir()
publicDir = projectDir & "/public/"
templateDir = projectDir & "/app/views/"
statics = newDictionary()

proc setPort*(p: uint) =
  port = p

proc setMode*(m: APP_MODE) =
  mode = m

proc initTemplates(root: string) =
  for filepath in os.walkFiles(root & "*"):
    var file: File
    if open(file, filepath, fmRead):
      html[filepath.splitFile().name] = file.readAll()
      file.close()
    else:
      echo "Could not read template ", filepath
  for dir in os.walkDirs(root & "*"):
    initTemplates(dir & "/")

proc getTemplate*(name: string): string =
  if html.hasKey(name):
    result = html[name]

proc putVars(page: string, vars: Data): string =
  result = page
  for pair in vars.pairs:
    result = result.replace("{[" & pair.key & "]}", vars[pair.key].getStr())
  for m in findAndCaptureAll(result, re"\{\[template\s\w*\-?\w*\]\}"):
    var templ = m.substr(2, m.len - 3).split(" ")[1]
    result = result.replace(m, getTemplate(templ).putVars(vars))

proc buildPage(page: string, vars: Data): string =
  if html.hasKey("layout"):
    result = html["layout"].replace("{[%content%]}", html[page])
  else: result = html[page]
  result = putVars(result, vars)

proc serve404(req: http.Request) {.async.} =
  var page: string = "404 page not found"
  if html.hasKey("error"):
    var vars = newJObject()
    vars.add("title", newJString("Error"))
    vars.add("code", newJString("404"))
    vars.add("message", newJString("Page not found"))
    page = buildPage("error", vars)
  await req.respond(Http404, page)

proc getJsonData(keys: OrderedTable[string, JsonNode], node: JsonNode): JsonNode = 
  result = newJObject()
  for key in keys.keys:
    result{key} = node[key]

proc parseRequestBody(body: string): JsonNode =
  var
    parsed = json.parseJson(body)
    keys = parsed.getFields()
  return getJsonData(keys, parsed)

proc isValidGetPath(url, kind: string, params: var Data): bool =
  var 
    kind = kind.split("/")
    klen = kind.len
    url = url.split("/")
  result = true
  if url.len == klen:
    for i in 0..klen-1:
      if ":" in kind[i]:
        #params{kind[i][1..kind[i].len-1]} = newJString(url[i])
        params[kind[i][1 .. kind[i].len - 1]] = url[i]
      elif kind[i] != url[i]:
        result = false
        break
  else:
    result = false

proc checkPath(req: http.Request, kind: string, vars: var Data): bool =
  result = false
  if routes.hasKey(req.reqMethod):
    if req.reqMethod == HttpGet: # URL parameters
      var getParams = newData()
      if req.url.path.isValidGetPath(kind, getParams):
        result = true
        vars = getParams
    else: # Request body
      if req.url.path == kind:
        result = true
        if req.body.len > 0:
          vars = parseRequestBody(req.body)
  
proc checkRoutes(req: http.Request) {.async.} =
  var vars: Data
  if routes.hasKey(req.reqMethod):
    for route in routes[req.reqMethod].keys:
      if checkPath(req, route, vars):
        let response = routes[req.reqMethod][route](req, vars)
        await req.respond(response.code, response.body)
        return
  await serve404(req)

proc addRoute(httpMethod: HttpMethod, path: string, handler: HandlerProc) =
  if not routes.hasKey(httpMethod):
    routes[httpMethod] = newRoute()
  routes[httpMethod][path] = handler

proc get*(path: string, handler: HandlerProc) =
  addRoute(HttpMethod.HttpGet, path, handler)

proc post*(path: string, handler: HandlerProc) =
  addRoute(HttpMethod.HttpPost, path, handler)

proc delete*(path: string, handler: HandlerProc) =
  addRoute(HttpMethod.HttpDelete, path, handler)
  
proc put*(path: string, handler: HandlerProc) =
  addRoute(HttpMethod.HttpPut, path, handler)

proc display*(text: string, code: HttpCode = Http200): Response =
  return (text, code)

proc displayTemplate*(tmplt: string, code: HttpCode = Http200): Response =
  return (buildPage(tmplt, newData()), code)

proc displayTemplate*(tmplt: string, vars: Data, code: HttpCode = Http200): Response =
  return (buildPage(tmplt, vars), code)

proc displayJSON*(data: Data | JsonNode | string, code: HttpCode = Http200): Response =
  return ($data, code)

proc setPublicDir*(dir: string) = 
  publicDir = projectDir & dir
  if publicDir[publicDir.len - 1] != '/':
    publicDir = publicDir & '/'

proc setTemplateDir*(dir: string) =
  templateDir = projectDir & dir
  if templateDir[templateDir.len - 1] != '/':
    templateDir = templateDir & '/'

setControlCHook(proc() {.noconv.} = quit(0))

proc initStatics(root: string) =
  for file in os.walkFiles(root & "*"):
    var 
      fr = "/" & (file.replace(publicDir, "")) # relative file path
      fp = fr.parentDir() & "/" # file's parent dir
      f: File
    if open(f, file, fmRead):
      statics[fp & fr.extractFilename()] = f.readAll()
      get(fp & ":file", proc(req: http.Request, vars: var Data): Response =
        return (statics[fp & vars["file"].getStr()], Http200))
      f.close()
    else:
      echo "Could not read static file ", file
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
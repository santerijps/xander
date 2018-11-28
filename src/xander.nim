import
  asyncnet,
  asyncdispatch as async,
  asynchttpserver as http,
  json, macros, os, regex, strformat, strutils, tables, typetraits

export
  async,
  http,
  json,
  tables,
  strformat

type # Custom types
  ApplicationMode* = enum Debug, Production
  Dictionary* = Table[string, string]
  HandlerProc* = proc(req: http.Request, vars: var Data): Response
  Route = Table[string, HandlerProc]
  RoutingTable = Table[HttpMethod, Route]
  Data* = JsonNode
  Response* = tuple[body: string, code: HttpCode]
  Session* = Table[int, Data]
  For = tuple[collection, each, body: string]

func newDictionary(): Dictionary =
  initTable[string, string]()

func newRoute(): Route =
  initTable[string, HandlerProc]()

func newRoutingTable(): RoutingTable =
  initTable[HttpMethod, Route]()

func newData*(): Data =
  newJObject()

# put and set essentially do the same thing, with the difference
# that put returns the altered Data object, whereas set simply
# alters the reference. This way, one can chain puts on one line.
# e.g. let data = newData("name", "Alice").put("age", 25).put("country", "UK")

func put*[T](node: Data, key: string, value: T): Data =
  add(result, key, %value)
  return node

func set*[T](node: var Data, key: string, value: T) = 
  add(node, key, %value)

func get*(node: Data, key: string): string =
  let n = node.getOrDefault(key)
  if n != nil:
    return n.getStr()

func `[]=`*[T](node: var Data, key: string, value: T) =
  add(node, key, %value)

func newData*[T](key: string, value: T): Data =
  result = newData()
  set(result, key, value)

func newSession*(): Table[int, Data] =
  initTable[int, Data]()

func new*(session: var Session, sessionID: int) =
  session[sessionID] = newData()

func get*(session: var Session, sessionID: int): Data =
  session[sessionID]

var # Define globals
  server {.threadvar.}: AsyncHttpServer
  html {.threadvar.}: Dictionary
  mode {.threadvar.}: ApplicationMode
  port {.threadvar.}: uint
  projectDir {.threadvar.}: string
  publicDir {.threadvar.}: string
  templateDir {.threadvar.}: string
  routes {.threadvar.}: RoutingTable
  statics {.threadvar.}: Dictionary
  session {.threadvar.}: Session

# Global initializations
server = newAsyncHttpServer()
html = newDictionary()
routes = newRoutingTable()
mode = ApplicationMode.Debug
port = 3000
projectDir = getAppDir()
publicDir = projectDir & "/public/"
templateDir = projectDir & "/app/views/"
statics = newDictionary()
session = newSession()

proc setPort*(p: uint) = 
  port = p

proc setMode*(m: ApplicationMode) = 
  mode = m

const # Template parsing REGEX strings
  MATCH_FOR_ALL = re"(?s)\{\[for \w+ in \w+\]\}\s*(.+?)\{\[end\]\}"
  MATCH_FOR_STMT = re"\{\[for \w+ in \w+\]\}"

func parseFor(forString: string): For =
  let forStmt = findAndCaptureAll(forString, MATCH_FOR_STMT)[0].split(" ")
  result.each = "{[" & forStmt[1] & "]}"
  result.collection = forStmt[3][0 .. len(forStmt[3]) - 3]
  var match: RegexMatch
  if find(forString, MATCH_FOR_ALL, match):
    let boundaries = group(match, 0)[0]
    result.body = forString[boundaries.a .. boundaries.b]

func buildFor(forObj: For, vars: Data): string =
  for item in vars[forObj.collection]:
    add(result, replace(forObj.body, forObj.each, item.getStr()))

func handleFor(tmplt: string, vars: Data): string =
  result = tmplt
  for forString in findAndCaptureAll(tmplt, MATCH_FOR_ALL):
    let parsed = parseFor(forString)
    let built = buildFor(parsed, vars)
    result = result.replace(forString, built)

proc templateExists(tmplt: string): bool = 
  html.hasKey(tmplt)

proc getTemplate*(tmplt: string): string =
  if templateExists(tmplt):
    return html[tmplt]

proc putVars(page: string, vars: Data): string =
  # Puts the variables defined in 'vars' into specified template.
  # If a template inclusion is found in the template, its
  # variables will also be put.
  #result = page
  result = handleFor(page, vars)
  for pair in vars.pairs:
    result = result.replace("{[" & pair.key & "]}", vars[pair.key].getStr())
  for m in findAndCaptureAll(result, re"\{\[template\s\w*\-?\w*\]\}"):
    var templ = m.substr(2, m.len - 3).split(" ")[1]
    result = result.replace(m, getTemplate(templ).putVars(vars))

proc buildPage(tmplt: string, vars: Data): string =
  # Builds a template page. If 'layout' template exists,
  # it will be used. Otherwise, the specified template
  # will be used exclusively.
  if templateExists(tmplt):
    if templateExists("layout"):
      result = html["layout"].replace("{[%content%]}", html[tmplt])
    else: result = html[tmplt]
    result = putVars(result, vars)
  else:
    echo "Error! Template does not exist: ", tmplt

proc serve404(req: http.Request) {.async.} =
  # Respons to client with a 404. If an error template exists
  # (of the same name 'error'), the template will be served
  # instead.
  var page: string = "404 page not found"
  if templateExists("error"):
    var vars = newData()
    vars["title"] = "Error"
    vars["code"] = 404
    vars["message"] = "Page not found"
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

# TODO
proc refererSameAsRequest(req: Request, route: string): bool =
  if req.reqMethod != HttpGet: return false
  var referer = req.headers["referer"].toString()
  referer = referer.replace(re"https?://", "")
  var start: int
  for i, c in referer:
    if c == '/':
      start = i
      break
  return referer[start .. referer.len - 1] == route

proc isValidGetPath(url, kind: string, params: var Data): bool =
  # Checks if the given 'url' matches 'kind'. As the 'url' can be dynamic,
  # the checker will ignore differences if a 'kind' subpath starts with a colon.
  var 
    kind = kind.split("/")
    klen = kind.len
    url = url.split("/")
  result = true
  if url.len == klen:
    for i in 0..klen-1:
      if ":" in kind[i]:
        params[kind[i][1 .. kind[i].len - 1]] = url[i]
      elif kind[i] != url[i]:
        result = false
        break
  else:
    result = false

proc checkPath(req: http.Request, kind: string, vars: var Data): bool =
  # For get requests, checks that the path (which could be dynamic) is valid,
  # and gets the url parameters. For other requests, the request body is parsed.
  # The 'kind' parameter is an existing route.
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
  # Checks if the specified request method and path match
  # a created route. If there is no match, throw a 404.
  var vars: Data
  if routes.hasKey(req.reqMethod):
    for route in routes[req.reqMethod].keys:
      if checkPath(req, route, vars):
        let response = routes[req.reqMethod][route](req, vars)
        await req.respond(response.code, response.body)
        return
  await serve404(req)

# All the add-procs simply call 'addRoute' with a specified request method
# and path/route. The add-procs are also utilized by the jester-like syntax
# enabling macros.

proc addRoute(httpMethod: HttpMethod, path: string, handler: HandlerProc) =
  if not routes.hasKey(httpMethod):
    routes[httpMethod] = newRoute()
  routes[httpMethod][path] = handler

proc addGet*(path: string, handler: HandlerProc) =
  addRoute(HttpMethod.HttpGet, path, handler)

proc addPost*(path: string, handler: HandlerProc) =
  addRoute(HttpMethod.HttpPost, path, handler)

proc addDelete*(path: string, handler: HandlerProc) =
  addRoute(HttpMethod.HttpDelete, path, handler)
  
proc addPut*(path: string, handler: HandlerProc) =
  addRoute(HttpMethod.HttpPut, path, handler)

# The macros are used to allow simple sinatra-like syntax.
# Each macro calls 'buildRequestHandlerSource' with their 
# respective request methods in order to call the correct
# request handler e.g. addGet, addPost etc.

proc buildRequestHandlerSource(reqMethod, route: string, body: untyped): string =
  var source = &"add{reqMethod}(\"{route}\", proc(req: Request, vars: var Data): Response =\n"
  for row in repr(body).split("\n"):
    if row.len > 0:
      source &= &"  {row}\n"
  return source & ")"

macro get*(route: string, body: untyped): typed =
  parseStmt(buildRequestHandlerSource("Get", repr(route).replace("\"", ""), body))

macro post*(route: string, body: untyped): typed =
  parseStmt(buildRequestHandlerSource("Post", repr(route).replace("\"", ""), body))

macro delete*(route: string, body: untyped): typed =
  parseStmt(buildRequestHandlerSource("Delete", repr(route).replace("\"", ""), body))

macro put*(route: string, body: untyped): typed =
  parseStmt(buildRequestHandlerSource("Put", repr(route).replace("\"", ""), body))

proc display*(text: string, code: HttpCode = Http200): Response =
  return (text, code)

proc displayTemplate*(tmplt: string, code: HttpCode = Http200): Response =
  return (buildPage(tmplt, newData()), code)

proc displayTemplate*(tmplt: string, vars: Data, code: HttpCode = Http200): Response =
  return (buildPage(tmplt, vars), code)

proc displayJSON*(data: Data | JsonNode | string, code: HttpCode = Http200): Response =
  return ($data, code)

proc setPublicDir*(dir: string) =
  var dir = dir
  if dir[0] != '/':
    dir = '/' & dir
  publicDir = projectDir & dir
  if publicDir[publicDir.len - 1] != '/':
    publicDir = publicDir & '/'

proc setTemplateDir*(dir: string) =
  var dir = dir
  if dir[0] != '/':
    dir = '/' & dir
  templateDir = projectDir & dir
  if templateDir[templateDir.len - 1] != '/':
    templateDir = templateDir & '/'

proc initStatics(root: string) =
  for file in os.walkFiles(root & "*"):
    var 
      fr = "/" & (file.replace(publicDir, "")) # relative file path
      fp = fr.parentDir() & "/" # file's parent dir
      f: File
    if open(f, file, fmRead):
      statics[fp & fr.extractFilename] = f.readAll()
      addGet(fp & ":file", proc(req: http.Request, vars: var Data): Response =
        return (statics[fp & vars["file"].getStr()], Http200))
      f.close()
    else:
      echo "ERROR: Could not read static file ", file
  for dir in os.walkDirs(root & "*"):
    initStatics(dir & "/")

proc initTemplates(root: string) =
  var file: File
  for filepath in os.walkFiles(root & "*"):
    if open(file, filepath, fmRead):
      html[filepath.splitFile.name] = readAll(file)
      close(file)
    else:
      echo "ERROR: Could not read template ", filepath
  for dir in os.walkDirs(root & "*"):
    initTemplates(dir & "/")

proc init() =
  # If the Xander project structure is followed,
  # this if block will be true
  if projectDir.extractFilename == "bin":
    projectDir = projectDir.parentDir
    publicDir = projectDir & "/public/"
    templateDir = projectDir & "/app/views/"
  initStatics(publicDir)
  initTemplates(templateDir)

proc requestHandler(req: http.Request) {.async.} =
  # Simply calls 'checkRoutes', but first checks
  # if the app mode is debug, and if so, initializes
  # public files and templates.
  if mode == ApplicationMode.Debug:
    init()
  await checkRoutes(req)

proc startServer*() =
  init()
  defer: close(server)
  echo "Web server listening on port ", port
  async.waitFor server.serve(async.Port(port), requestHandler)

# This should make killing the app with ctrl + c
# a bit more graceful.
setControlCHook(proc() {.noconv.} = quit(0))

when isMainModule:
  # When the xander binary is is executed,
  # a set of commands are provided for:
  #  - creating a new xander project
  #  - running a xander project

  proc copyDirAndContents(source, destination: string) =
    createDir(destination)
    for file in walkFiles(source & "/*"):
      copyFile(file, destination & "/" & file.extractFilename)
    for dir in walkDirs(source & "/*"):
      copyDirAndContents(dir, destination & "/" & dir.extractFilename)
  
  proc newApp(appName: string) =
    copyDirAndContents(getAppDir() & "/src/xander/project", getCurrentDir() & "/" & appName)
  
  proc runApp() =
    # Compiles the project into the 'bin' folder, and
    # runs the project with hints set off.
    var 
      currentDir = getCurrentDir()
      appNim = currentDir & "/app.nim"
      appExe = currentDir & "/bin/www"
      cmd = "nim c -r --out:" & appExe & " --hints:off --verbosity:0 --threads:on "
    if os.fileExists(appNim):
      discard os.execShellCmd(cmd & appNim)
    else:
      echo "ERROR: Could not find 'app.nim' in ", currentDir
  
  if os.paramCount() >= 1:
    var params = os.commandLineParams()
    case params[0]:
      of "new":
        if os.paramCount() > 1:
          newApp(params[1])
        else:
          echo "ERROR: Provide app name!"
      of "run":
        runApp()
      else:
        echo "ERROR: unknown command: ", params[0]
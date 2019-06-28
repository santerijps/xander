import
  asyncnet,
  asyncdispatch as async,
  asynchttpserver as http,
  cookies as cookies_module,
  base64,
  json,
  logging,
  macros,
  os,
  random,
  regex,
  std/sha1,
  strformat,
  strtabs,
  strutils,
  tables,
  times,
  typetraits,
  uri

import # Local imports
  xander/constants,
  xander/contenttype,
  xander/templating,
  xander/tools,
  xander/types,
  xander/zip/zlib_modified

export # TODO: What really needs to be exported???
  async,
  cookies_module,
  http,
  json,
  os,
  strformat,
  tables,
  types,
  tools

randomize()

var # Global variables
  # Directories
  applicationDirectory {.threadvar.} : string
  templateDirectory {.threadvar.} : string
  # Storage
  sessions {.threadvar.} : Sessions
  templates {.threadvar.} : Dictionary
  fileServers {.threadvar.} : seq[string]
  # Fundamental server variables
  xanderServer {.threadvar.} : AsyncHttpServer
  xanderRoutes {.threadvar.} : RoutingTable
  # Logger
  logger {.threadvar.} : Logger

applicationDirectory = getAppDir()
templateDirectory = applicationDirectory & "/templates/"
sessions = newSessions()
templates = newDictionary()
fileServers = newSeq[string]()
xanderServer = newAsyncHttpServer(maxBody = 2147483647) # 32 bits MAXED
xanderRoutes = newRoutingTable()
logger = newConsoleLogger(fmtStr="[$time] - XANDER($levelname) ")

proc setTemplateDirectory*(path: string): void =
  var path = path
  if not path.startsWith("/"):
    path = "/" & path
  if not path.endsWith("/"):
    path &= "/"
  templateDirectory = applicationDirectory & path

proc fillTemplateWithData*(templateString: string, data: Data): string =
  # Puts the variables defined in 'vars' into specified template.
  # If a template inclusion is found in the template, its
  # variables will also be put.
  result = templateString
  #result = handleFor(page, data)
  # Insert template variables
  for pair in data.pairs:
    result = result.replace("{[" & pair.key & "]}", data[pair.key].getStr())
  # Clear unused template variables
  for m in findAndCaptureAll(result, re"\{\[\w+\]\}"):
    result = result.replace(m, "")
  # Find embedded templates and insert their template variables
  for m in findAndCaptureAll(result, re"\{\[template\s\w*\-?\w*\]\}"):
    var templ = m.substr(2, m.len - 3).split(" ")[1]
    result = result.replace(m, templates[templ].fillTemplateWithData(data))

proc tmplt*(templateName: string, data: Data = newData()): string =
  if templates.hasKey(templateName):
    if templates.hasKey("layout"):
      let layout = templates["layout"]
      result = layout.replace(contentTag, templates[templateName])
    else:
      result = templates[templateName]
    result = fillTemplateWithData(result, data)
  else:
    logger.log(lvlError, &"Template '{templateName}' does not exist!")

proc html*(content: string): string = 
  # Let's the browser know that the response should be treated as HTML
  "<!DOCTYPE html><meta charset=\"utf-8\">\n" & content

func respond*(httpCode: HttpCode = Http200, body: string = "", headers: HttpHeaders = newHttpHeaders()): Response =
  return (body, httpCode, headers)

func respond*(body: string, httpCode: HttpCode = Http200, headers = newHttpHeaders()): Response =
  return (body, httpCode, headers)

proc respond*(data: Data, httpCode = Http200, headers = newHttpHeaders()): Response =
  return ($data, httpCode, headers)

proc redirect*(path: string, content = "", delay = 0, httpCode = Http303): Response =
  var headers: HttpHeaders
  if delay == 0:
    headers = newHttpHeaders([("Location", path)])
  else:
    headers = newHttpHeaders([("refresh", &"{delay};url=\"{path}\"")])
  return (content, httpCode, headers)

proc serve(request: Request, httpCode: HttpCode, content: string = ""): Future[void] {.async.} =
  await request.respond(httpCode, "")

proc serveError(request: Request, httpCode: HttpCode = Http500, message: string = ""): Future[void] {.async.} =
  var content = message
  if templates.hasKey("error"):
    var data = newData()
    data["title"] = "Error"
    data["code"] = $httpCode
    data["message"] = message
    content = tmplt("error", data)
  else:
    content = &"<h2>({httpCode}) Error</h2><hr><p>{message}</p>"
    content = html(content)
  await serve(request, httpCode, content)

proc parseFormMultiPart(body, boundary: string, data: var Data, files: var UploadFiles): void = 
  let fileInfos = body.split(boundary) # Contains: Content-Disposition, Content-Type, Others... and actual content 
  var
    parts: seq[string]
    fileName, fileExtension, content, varName: string
    size: int
  for fileInfo in fileInfos:
    if "Content-Disposition" in fileInfo:
      parts = fileInfo.split("\c\n\c\n", 1)
      assert parts.len == 2
      for keyVals in parts[0].split(";"):
        if " name=" in keyVals:
          varName = keyVals.split(" name=\"")[1].strip(chars = {'"'})
        if " filename=" in keyVals:
          fileName = keyVals.split(" filename=\"")[1].split("\"")[0]
          fileExtension = if '.' in fileName: fileName.split(".")[1] else: "file"
      content = parts[1][0..parts[1].len - 3] # Strip the last two characters out = \r\n
      size = content.len
      # Add variables to Data and files to UploadFiles
      if fileName.len == 0: # Data
        data[varName] = content#.strip()
      else: # UploadFiles
        if not files.hasKey(varName):
          files[varName] = newSeq[UploadFile]()
        files[varName].add(newUploadFile(fileName, fileExtension, content, size))
      varName = ""; fileName = ""; content = ""

proc uploadFile*(directory: string, file: UploadFile, name = ""): void =
  let fileName = if name == "": file.name else: name
  var filePath = if directory.endsWith("/"): directory & fileName else: directory & "/" & fileName
  try:
    writeFile(filePath, file.content)
  except IOError:
    logger.log(lvlError, "IOError: Failed to write file")

proc uploadFiles*(directory: string, files: seq[UploadFile]): void =
  var filePath: string
  let dir = if directory.endsWith("/"): directory else: directory & "/" 
  for file in files:
    filePath = dir & file.name
    try:
      writeFile(filePath, file.content)
    except IOError:
      logger.log(lvlError, &"IOError: Failed to write file '{filePath}'")

proc parseForm(body: string): JsonNode =
  result = newJObject()
  # Use decodeUrl(body, false) if plusses (+) should not
  # be considered spaces.
  let urlDecoded = decodeUrl(body)
  let kvPairs = urlDecoded.split("&")
  for kvPair in kvPairs:
    let kvArray = kvPair.split("=")
    result.set(kvArray[0], kvArray[1])

proc getJsonData(keys: OrderedTable[string, JsonNode], node: JsonNode): JsonNode = 
  result = newJObject()
  for key in keys.keys:
    result{key} = node[key]

proc parseRequestBody(body: string): JsonNode =
  try: # JSON
    var
      parsed = json.parseJson(body)
      keys = parsed.getFields()
    return getJsonData(keys, parsed)
  except: # Form
    return parseForm(body)

func parseUrlQuery(query: string, data: var Data): void =
  let query = decodeUrl(query)
  if query.len > 0:
    for parameter in query.split("&"):
      if "=" in parameter:
        let pair = parameter.split("=")
        data[pair[0]] = pair[1]
      else:
        data[parameter] = true

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

proc hasSubdomain(host: string, subdomain: var string): bool =
  let domains = host.split('.')
  let count = domains.len
  if count > 1: # ["api", "mysite", "com"] ["mysite", "com"] ["api", "localhost"]
    if (count >= 3) or (count == 2 and domains[1].split(":")[0] == "localhost"):
      subdomain = domains[0]
      result = true

proc handleSubdomain(request: Request): string =
  result = request.url.path
  var subdomain: string
  if request.headers.hasKey("host") and hasSubdomain(request.headers["host"], subdomain):
    result = subdomain & "." & result

proc checkPath(request: Request, kind: string, data: var Data, files: var UploadFiles): bool =
  # For get requests, checks that the path (which could be dynamic) is valid,
  # and gets the url parameters. For other requests, the request body is parsed.
  # The 'kind' parameter is an existing route.
  let path = handleSubdomain(request)
  if request.reqMethod == HttpGet: # URL parameters
    result = isValidGetPath(path, kind, data)
  else: # Form body
    let contentType = request.headers["Content-Type"].split(";") # TODO: Use me wisely to detemine how to parse request body
    if path == kind:
      result = true
      if request.body.len > 0:
        if "multipart/form-data" in contentType: # File upload
          let boundary = "--" & contentType[1].split("=")[1]
          parseFormMultiPart(request.body, boundary, data, files)
        else: # Other
          data = parseRequestBody(request.body)

proc setResponseCookies*(response: var Response, cookies: Cookies): void =
  for key, cookie in cookies.server:
    response.headers.add("Set-Cookie", 
      cookies_module.setCookie(
        cookie.name, cookie.value, cookie.domain, cookie.path, cookie.expires, true, cookie.secure, cookie.httpOnly))

# TODO: This is not very random
# SHA-1 Hash
proc generateSessionId(): string =
  $secureHash($(cpuTime() + rand(10000).float))

proc setResponseHeaders(response: var Response, headers: HttpHeaders): void =
  for key, val in headers.pairs:
    response.headers.add(key, val)

proc getSession(cookies: var Cookies, session: var Session): string =
  # Gets a session if one exists. Initializes a new one if it doesn't.
  var ssid: string
  if not cookies.contains("XANDER-SSID"):
    ssid = $generateSessionId()
    sessions[ssid] = session
    cookies.set("XANDER-SSID", ssid)
  else:
    ssid = cookies.get("XANDER-SSID")
    if sessions.hasKey(ssid):
      session = sessions[ssid]  
  return ssid

# The default content-type header is text/html.
# If the request handler returns nothing but text,
# content-type should be text/plain
proc setContentTypeToTextPlainIfNeeded(response: Response, headers: var HttpHeaders): void =
  if "text/html" in headers["Content-Type"] and not("<!DOCTYPE html>" in response.body):
    headers["Content-Type"] = "text/plain; charset=UTF-8"

proc setDefaultHeaders(headers: var HttpHeaders): void =
  headers["Cache-Control"] = "public; max-age=" & $(60*60*24*7) # One week
  headers["Connection"] = "keep-alive"
  headers["Content-Type"] = "text/html; charset=UTF-8"
  headers["Content-Security-Policy"] = "script-src 'self'"
  headers["Feature-Policy"] = "autoplay 'none'"
  headers["Referrer-Policy"] = "no-referrer"
  headers["Server"] = "xander"
  headers["Vary"] = "User-Agent, Accept-Encoding"
  headers["X-Content-Type-Options"] = "nosniff"
  headers["X-Frame-Options"] = "DENY"
  headers["X-XSS-Protection"] = "1; mode=block"

# TODO: Some say .pngs should not be compressed
proc gzip(response: var Response, request: Request, headers: var HttpHeaders): void =
  if request.headers.hasKey("accept-encoding"):
    if "gzip" in request.headers["accept-encoding"]:
      try:
        # Uses a modified version of zip/zlib.nim
        response.body = compress(response.body, response.body.len, Z_DEFLATED)
        headers["content-encoding"] = "gzip"
      except:
        logger.log(lvlError, "Failed to gzip compress. Did you set 'Type Ulong* = uint'?")

# TODO: Check that request size <= server max allowed size
# Called on each request to server
proc onRequest*(request: Request): Future[void] {.gcsafe.} =
  var (data, headers, cookies, session, files) = newRequestHandlerVariables()
  if xanderRoutes.hasKey(request.reqMethod):
    for route in xanderRoutes[request.reqMethod].keys:
      if checkPath(request, route, data, files):
        # Get URL query parameters
        parseUrlQuery(request.url.query, data)
        # Parse cookies from header
        let parsedCookies = parseCookies(request.headers.getOrDefault("Cookie"))
        # Cookies sent from client
        for key, val in parsedCookies.pairs:
          cookies.setClient(key, val)
        # Create or get session and session ID
        let ssid = getSession(cookies, session)
        # Set default headers
        setDefaultHeaders(headers)
        # Request handler response
        var response = xanderRoutes[request.reqMethod][route](request, data, headers, cookies, session, files)
        # TODO: Fix the way content type is determined
        setContentTypeToTextPlainIfNeeded(response, headers)
        # gzip encode if needed
        gzip(response, request, headers)
        # Update session
        sessions[ssid] = session
        # Cookies set on server => add them to headers
        setResponseCookies(response, cookies)
        # Put headers into response
        setResponseHeaders(response, headers)
        return request.respond(response.httpCode, response.body, response.headers)
  serveError(request, Http404)

# TODO: Check port range
proc runForever*(port: uint = 3000, message: string = "Xander server is up and running!"): void =
  logger.log(lvlInfo, message)
  defer: close(xanderServer)
  readTemplates(templateDirectory, templates)
  waitFor xanderServer.serve(Port(port), onRequest)

proc getServer*(): AsyncHttpServer =
  readTemplates(templateDirectory, templates)
  return xanderServer

proc addRoute*(httpMethod: HttpMethod, route: string, handler: RequestHandler): void =
  if not xanderRoutes.hasKey(httpMethod):
    xanderRoutes[httpMethod] = newRoute()
  xanderRoutes[httpMethod][route] = handler

proc addGet*(route: string, handler: RequestHandler): void =
  addRoute(HttpGet, route, handler)

proc addPost*(route: string, handler: RequestHandler): void =
  addRoute(HttpPost, route, handler)

proc addPut*(route: string, handler: RequestHandler): void =
  addRoute(HttpPut, route, handler)

proc addDelete*(route: string, handler: RequestHandler): void =
  addRoute(HttpDelete, route, handler)

# TODO: Build source using Nim Nodes instead of strings
proc buildRequestHandlerSource(reqMethod, route, body: string): string =
  var source = &"add{reqMethod}({tools.quote(route)}, {requestHandlerString}{newLine}"
  for row in body.split(newLine):
    if row.len > 0:
      source &= &"{tab}{row}{newLine}"
  return source & ")"

macro get*(route: string, body: untyped): void =
  let requestHandlerSource = buildRequestHandlerSource("Get", unquote(route), repr(body))
  parseStmt(requestHandlerSource)

macro post*(route: string, body: untyped): void =
  let requestHandlerSource = buildRequestHandlerSource("Post", unquote(route), repr(body))
  parseStmt(requestHandlerSource)

macro put*(route: string, body: untyped): void =
  let requestHandlerSource = buildRequestHandlerSource("Put", unquote(route), repr(body))
  parseStmt(requestHandlerSource)

macro delete*(route: string, body: untyped): void =
  let requestHandlerSource = buildRequestHandlerSource("Delete", unquote(route), repr(body))
  parseStmt(requestHandlerSource)

# TODO: Dynamically created directories are not supported
proc serveFiles*(route: string): void =
  # Given a route, e.g. '/public', this proc
  # adds a get method for provided directory and
  # its child directories. This proc is RECURSIVE.
  logger.log(lvlInfo, "Serving files from ", applicationDirectory & route)
  let path = if route.endsWith("/"): route[0..route.len-2] else: route # /public/ => /public
  let newRoute = path & "/:fileName" # /public/:fileName
  addGet(newRoute, proc(request: Request, data: var Data, headers: var HttpHeaders, cookies: var Cookies, session: var Session, files: var UploadFiles): Response = 
    let filePath = "." & path / decodeUrl(data.get("fileName")) # ./public/.../fileName
    let ext = splitFile(filePath).ext
    if existsFile(filePath):
      headers["Content-Type"] = getContentType(ext)
      respond readFile(filePath)
    else: respond Http404)
  for directory in walkDirs("." & path & "/*"):
    serveFiles(directory[1..directory.len - 1])

when isMainModule:
  # TODO: project creation etc.
  discard

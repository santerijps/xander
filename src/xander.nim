import
  asyncnet,
  asyncdispatch as async,
  asynchttpserver as http,
  cookies as cookies_module,
  base64,
  httpclient,
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
  xander/tools,
  xander/types,
  xander/zip/zlib_modified

export # TODO: What really needs to be exported???
  async,
  cookies_module,
  contenttype,
  http,
  json,
  os,
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
  # Fundamental server variables
  xanderServer {.threadvar.} : AsyncHttpServer
  xanderRoutes {.threadvar.} : Hosts
  # Logger
  logger {.threadvar.} : Logger

let appDir = getAppDir()
applicationDirectory = if appDir.extractFilename == "bin": appDir.parentDir() else: appDir
templateDirectory = "templates"
sessions = newSessions()
xanderServer = newAsyncHttpServer(maxBody = 2147483647) # 32 bits MAXED
xanderRoutes = newHosts()
logger = newConsoleLogger(fmtStr="[$time] - XANDER($levelname) ")

proc setTemplateDirectory*(path: string): void =
  var path = path
  if path.startsWith("/"):
    path = path.substr(1)
  templateDirectory = path

#[

  NOTE! Known templating bug:
    - Regex doesn't always match tags as it should. This means that some variables in the template do not get assigned
      any values. To fix this, in the template, add a few tabs or new lines before the problematic variable.

]#

const contentRE = "\\{\\[\\s*content\\s*\\]\\}"
const forRE = "\\{\\[\\s*for\\s+(\\w+)\\s+in\\s+([\\w+\\.?]+)\\s*\\]\\}([\\s\\S]*)\\{\\[\\s*end\\s*\\]\\}"
const templateRE = "\\{\\[\\s*template\\s*(\\S+)\\s*\\]\\}"
const varRE = "\\{\\[([\\s\\S]*?)\\]\\}"

proc unquote(s: string): string =
  s.strip(chars = {'"'})

# Checks if the specified 'path' exists in provided JsonNode 'src'.
# If it does, assign its value to 'dest' and return true. 
proc dotwalk(src: JsonNode, path: string, dest: var JsonNode): bool =
  let keys = path.split('.')
  dest = src
  result = true
  for i in 0 .. keys.high:
    let key = keys[i]
    if dest.kind == JObject:
      if dest.hasKey(key):
        dest = dest[key]
      else:
        return false
    elif dest.kind == JArray:
      try:
        let elems = dest.getElems()
        dest = elems[key.parseInt]
      except:
        return false

# Gets the appropriate layout file if one exists.
# Prioritizes the layout file in the same directory.
# Then checks parent directories for the file.
proc getLayout(templateName: string): string =
  let path = templateName.split( '/' ) 
  let dirs = path[ 0 .. ^2 ]          
  var i = dirs.high
  while i > -1:
    let dir = dirs[ 0 .. i ].join( "/" )
    for file in walkFiles( dir / "*" ):
      if file.splitFile.name == "layout":
        return readFile(file)
    dec(i)

proc getTemplate(templateName: string, templateContent: var string, imported = false): bool =
  var layout = if imported: "" else: getLayout(templateName)
  for file in walkFiles(templateName & "*"):
    if file.splitFile.name == templateName.splitFile.name:
      templateContent = readFile(file)
      var match: RegexMatch
      if find(layout, re(contentRE), match):
        layout[match.boundaries] = templateContent
        templateContent = layout
      return true

proc findAndInsertRegularVariables(doc: string, data: JsonNode): string =
  result = doc
  for match in findAll(result, re(varRe)):
    var slice = match.group(0)[0]
    let tag = result[slice].strip
    slice = slice.a - 2 .. slice.b + 2
    var node: JsonNode
    if data.dotwalk(tag, node):
      result[slice] = ($node).unquote

proc findAndInsertForLoops(doc: string, data: JsonNode): string =
  result = doc
  for match in findAll(result, re(forRE)):
    # {[ for [item] in [iterable] ]} [body] {[ end ]}
    let item = result[match.group(0)[0]]
    let iterable = result[match.group(1)[0]]
    let body = result[match.group(2)[0]]
    # The looped content
    var forBody: string
    var elements: JsonNode
    if data.dotwalk(iterable, elements):
      for element in elements.getElems:
        let temp = %* { item: element }
        forBody &= findAndInsertRegularVariables(body, temp) & '\n'
        var m: RegexMatch # Inner for-loop
        if find(forBody, re(forRe), m):
          forBody = findAndInsertForLoops(forBody, temp)
      result[match.boundaries] = forBody

proc findAndInsertTemplates(doc: string, data: JsonNode): string =
  result = doc
  for match in findAll(result, re(templateRE)):
    let templateName = templateDirectory / result[match.group(0)[0]]
    var templateContent: string
    if getTemplate(templateName, templateContent, true):
      templateContent = findAndInsertTemplates(templateContent, data)
      templateContent = findAndInsertRegularVariables(templateContent, data)
      templateContent = findAndInsertForLoops(templateContent, data)
      result[match.boundaries] = templateContent
    else:
      echo "Template '$1' not found!".format(templateName)

proc tmplt*(templateName: string, data: JsonNode = newJObject()): string =
  var templateContent: string
  if getTemplate(templateDirectory / templateName, templateContent):
    result = templateContent
    result = findAndInsertTemplates(result, data)
    result = findAndInsertRegularVariables(result, data)
    result = findAndInsertForLoops(result, data)  
  else:
    echo "Template '$1' not found!".format(templateName)

proc html*(content: string): string = 
  # Let's the browser know that the response should be treated as HTML
  "<!DOCTYPE html><meta charset=\"utf-8\">\n" & content

proc respond*(httpCode = Http200, content = "", headers = newHttpHeaders()): types.Response =
  return (content, httpCode, headers)

proc respond*(content: string, httpCode = Http200, headers = newHttpHeaders()): types.Response =
  return (content, httpCode, headers)

proc respond*(data: Data, httpCode = Http200, headers = newHttpHeaders()): types.Response =
  return ($data, httpCode, headers)

proc respond*(file: UploadFile, httpCode = Http200, headers = newHttpHeaders()): types.Response =
  headers["Content-Type"] = getContentType(file.ext)
  return (file.content, httpCode, headers)

proc redirect*(path: string, content = "", delay = 0, httpCode = Http303): types.Response =  
  ( content, httpCode,
    if delay == 0:
      newHttpHeaders([("location", path)]) 
    else:
      newHttpHeaders([("refresh", &"{delay};url=\"{path}\"")])
  )

proc serve(request: Request, httpCode: HttpCode, content = "", headers = newHttpHeaders()): Future[void] {.async.} =
  await request.respond(httpCode, content, headers)

proc serveError(request: Request, httpCode: HttpCode = Http500, message = ""): Future[void] {.gcsafe, async.} =
  var content = message
  if existsFile(templateDirectory / "error.html"):
    var data = newData()
    data["title"] = "Internal Server Error"
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
    var key = kvArray[0]
    let value = kvArray[1]
    if "[]" in key:
      key = key[0 .. key.len - 3]
      if result.hasKey(key):
        var arr = result[key].getElems()
        arr.add(newJString(value))
        result.set(key, arr)
      else:
        let arr = newJArray()
        arr.add(newJString(value))
        result.set(key, arr)
    else:
      result.set(key, value)

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
    if count == 3 and domains[0] == "www":
      result = false  
    elif (count >= 3) or (count == 2 and domains[1].split(":")[0] == "localhost"):
      subdomain = domains[0]
      result = true

proc checkPath(request: Request, kind: string, data: var Data, files: var UploadFiles): bool =
  # For get requests, checks that the path (which could be dynamic) is valid,
  # and gets the url parameters. For other requests, the request body is parsed.
  # The 'kind' parameter is an existing route.
  if request.reqMethod == HttpGet: # URL parameters
    result = isValidGetPath(request.url.path, kind, data)
  else: # Form body
    let contentType = request.headers["Content-Type"].split(";") # TODO: Use me wisely to detemine how to parse request body
    if request.url.path == kind:
      result = true
      if request.body.len > 0:
        if "multipart/form-data" in contentType: # File upload
          let boundary = "--" & contentType[1].split("=")[1]
          parseFormMultiPart(request.body, boundary, data, files)
        else: # Other
          data = parseRequestBody(request.body)

proc setResponseCookies*(response: var types.Response, cookies: Cookies): void =
  for key, cookie in cookies.server:
    response.headers.add("Set-Cookie", 
      cookies_module.setCookie(
        cookie.name, cookie.value, cookie.domain, cookie.path, cookie.expires, true, cookie.secure, cookie.httpOnly))

# TODO: This is not very random
# SHA-1 Hash
proc generateSessionId(): string =
  $secureHash($(cpuTime() + rand(10000).float))

proc setResponseHeaders(response: var types.Response, headers: HttpHeaders): void =
  for key, val in headers.pairs:
    response.headers.add(key, val)

proc getSession(cookies: var Cookies, session: var Session): string =
  # Gets a session if one exists. Initializes a new one if it doesn't.
  var ssid: string
  if not cookies.contains("XANDER-SSID"):
    ssid = $generateSessionId()
    sessions[ssid] = session
    cookies.set("XANDER-SSID", ssid, httpOnly = true)
  else:
    ssid = cookies.get("XANDER-SSID")
    if sessions.hasKey(ssid):
      session = sessions[ssid]  
  return ssid

# The default content-type header is text/plain.
proc setContentTypeToHTMLIfNeeded(response: types.Response, headers: var HttpHeaders): void =
  if "<!DOCTYPE html>" in response.body:
    headers["Content-Type"] = "text/html; charset=UTF-8"

proc setDefaultHeaders(headers: var HttpHeaders): void =
  headers["Cache-Control"] = "public; max-age=" & $(60*60*24*7) # One week
  headers["Connection"] = "keep-alive"
  headers["Content-Type"] = "text/plain; charset=UTF-8"
  headers["Content-Security-Policy"] = "font-src 'self'"
  headers["Feature-Policy"] = "autoplay 'none'"
  headers["Referrer-Policy"] = "no-referrer"
  headers["Server"] = "xander"
  headers["Vary"] = "User-Agent, Accept-Encoding"
  headers["X-Content-Type-Options"] = "nosniff"
  headers["X-Frame-Options"] = "DENY"
  headers["X-XSS-Protection"] = "1; mode=block"

# TODO: Some say .pngs should not be compressed
proc gzip(response: var types.Response, request: Request, headers: var HttpHeaders): void =
  if request.headers.hasKey("accept-encoding"):
    if "gzip" in request.headers["accept-encoding"]:
      try:
        # Uses a modified version of zip/zlib.nim
        response.body = compress(response.body, response.body.len, Z_DEFLATED)
        headers["content-encoding"] = "gzip"
      except:
        # Deprecated, since the modified version is used
        logger.log(lvlError, "Failed to gzip compress. Did you set 'Type Ulong* = uint'?")

proc parseHostAndDomain(request: Request): tuple[host, domain: string] =
  result = (defaultHost, defaultDomain)
  if request.headers.hasKey("host"):
    let url = $request.headers["host"].split(':')[0] # leave the port out of this!
    let parts = url.split('.')
    result = case parts.len:
      of 1:
        (parts[0], defaultDomain) # localhost
      of 2:
        if parts[1] == "localhost":
          (parts[1], parts[0]) # api.localhost
        else:
          (parts[0], defaultDomain) # site.com
      of 3:
        (parts[1], parts[0]) # api.site.com
      else:
        # TODO: NOT GOOD AT ALL
        (defaultHost, defaultDomain)

proc getHostAndDomain(request: Request): tuple[host, domain: string] =
  if xanderRoutes.isDefaultHost():
    var subdomain: string
    if request.headers.hasKey("host") and hasSubdomain(request.headers["host"], subdomain):
      (defaultHost, subdomain)
    else:
      (defaultHost, defaultDomain)
  else:
    parseHostAndDomain(request)

# EXPERIMENTAL
type RequestHookProc* = proc(r: Request): Future[void] {.gcsafe.}
var requestHook* {.threadvar.} : RequestHookProc # == nil

# TODO: Check that request size <= server max allowed size
# Called on each request to server
proc onRequest(request: Request): Future[void] {.async,gcsafe.} =
  # Experimental: Request Hook
  if requestHook != nil:
    await requestHook(request)
  var (data, headers, cookies, session, files) = newRequestHandlerVariables()
  var (host, domain) = getHostAndDomain(request)
  if xanderRoutes.existsMethod(request.reqMethod, host, domain):
    # At this point, we're inside the domain!
    for serverRoute in xanderRoutes[host][domain][request.reqMethod]:
      if checkPath(request, serverRoute.route, data, files):
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
        var response: types.Response
        try:
          response = serverRoute.handler(request, data, headers, cookies, session, files)
        except:
          logger.log(lvlError, "Request Handler broke with request path '$1'.".format(request.url.path))
          response.httpCode = Http500
          response.body = "Internal server error"
          response.headers = newHttpHeaders()
        # TODO: Fix the way content type is determined
        setContentTypeToHTMLIfNeeded(response, headers)
        # gzip encode if needed
        gzip(response, request, headers)
        # Update session
        sessions[ssid] = session
        # Cookies set on server => add them to headers
        setResponseCookies(response, cookies)
        # Put headers into response
        setResponseHeaders(response, headers)
        await request.respond(response.httpCode, response.body, response.headers)
  await serveError(request, Http404)

# TODO: Check port range
proc runForever*(port: uint = 3000, message: string = "Xander server is up and running!"): void =
  logger.log(lvlInfo, message)
  defer: close(xanderServer)
  waitFor xanderServer.serve(Port(port), onRequest)

proc addRoute*(host = defaultHost, domain = defaultDomain, httpMethod: HttpMethod, route: string, handler: RequestHandler): void =
  xanderRoutes.addRoute(httpMethod, route, handler, host, domain)

proc addGet*(host, domain, route: string, handler: RequestHandler): void =
  addRoute(host, domain, HttpGet, route, handler)

proc addPost*(host, domain, route: string, handler: RequestHandler): void =
  addRoute(host, domain, HttpPost, route, handler)

proc addPut*(host, domain, route: string, handler: RequestHandler): void =
  addRoute(host, domain, HttpPut, route, handler)

proc addDelete*(host, domain, route: string, handler: RequestHandler): void =
  addRoute(host, domain, HttpDelete, route, handler)

# TODO: Build source using Nim Nodes instead of strings
proc buildRequestHandlerSource(host, domain, reqMethod, route, body: string): string =
  var source = &"add{reqMethod}({tools.quote(host)}, {tools.quote(domain)}, {tools.quote(route)}, {requestHandlerString}{newLine}"
  for row in body.split(newLine):
    if row.len > 0:
      source &= &"{tab}{row}{newLine}"
  return source & ")"

macro get*(route: string, body: untyped): void =
  let requestHandlerSource = buildRequestHandlerSource(defaultHost, defaultDomain, "Get", unquote(route), repr(body))
  parseStmt(requestHandlerSource)

macro x_get*(host, domain, route: string, body: untyped): void =
  let requestHandlerSource = buildRequestHandlerSource(unquote(host), unquote(domain), "Get", unquote(route), repr(body))
  parseStmt(requestHandlerSource)

macro post*(route: string, body: untyped): void =
  let requestHandlerSource = buildRequestHandlerSource(defaultHost, defaultDomain, "Post", unquote(route), repr(body))
  parseStmt(requestHandlerSource)

macro x_post*(host, domain, route: string, body: untyped): void =
  let requestHandlerSource = buildRequestHandlerSource(unquote(host), unquote(domain), "Post", unquote(route), repr(body))
  parseStmt(requestHandlerSource)

macro put*(route: string, body: untyped): void =
  let requestHandlerSource = buildRequestHandlerSource(defaultHost, defaultDomain, "Put", unquote(route), repr(body))
  parseStmt(requestHandlerSource)

macro x_put*(host, domain, route: string, body: untyped): void =
  let requestHandlerSource = buildRequestHandlerSource(unquote(host), unquote(domain), "Put", unquote(route), repr(body))
  parseStmt(requestHandlerSource)

macro delete*(route: string, body: untyped): void =
  let requestHandlerSource = buildRequestHandlerSource(defaultHost, defaultDomain, "Delete", unquote(route), repr(body))
  parseStmt(requestHandlerSource)

macro delete*(host, domain, route: string, body: untyped): void =
  let requestHandlerSource = buildRequestHandlerSource(unquote(host), unquote(domain), "Delete", unquote(route), repr(body))
  parseStmt(requestHandlerSource)

proc startsWithRequestMethod(s: string): bool =
  let methods = @["get", "post", "put", "delete"]
  for m in methods:
    if s.startsWith(m):
      return true

proc reformatRouterCode(host, domain, path, body: string): string =
  for line in body.split(newLine):
    var lineToAdd = line & newLine
    if line.len > 0 and ':' in line:
      # request handler
      if startsWithRequestMethod(line):
        let requestHandlerDefinition = line.split(" ")
        let requestMethod = requestHandlerDefinition[0]
        var route = requestHandlerDefinition[1]
        if route == "\"/\":":
          route = "\"\""
          route = route[0] & path & route[1..route.len - 1]
          lineToAdd = "x_" & requestMethod & " " & tools.quote(host) & ", " & tools.quote(domain) & ", " & route & ":" & newLine
        elif route.startsWith('"') and route.endsWith("\":") and route[1] == '/':
          route = route[0] & path & route[1..route.len - 1]
          lineToAdd = "x_" & requestMethod & " " & tools.quote(host) & ", " & tools.quote(domain) & ", " & route & newLine
    result &= lineToAdd

macro router*(route, body: untyped): void =
  let path = repr(route).unquote
  let body = reformatRouterCode(defaultHost, defaultDomain, path, repr(body))
  parseStmt(body)

macro x_router*(host, domain, route, body: untyped): void =
  let body = reformatRouterCode(host.unquote, domain.unquote, route.unquote, repr(body))
  parseStmt(body)

proc reformatSubdomainCode(domain, host, body: string): string =
  # transforms request macros and routers to x_gets and x_routers
  for line in body.split(newLine):
    var lineToAdd = line & newLine
    if line.len > 0 and ':' in line:
      # request handler not within a host-block
      if startsWithRequestMethod(line):
        let requestHandlerDefinition = line.split(" ")
        let requestMethod = requestHandlerDefinition[0]
        let route = requestHandlerDefinition[1]
        lineToAdd = "x_" & requestMethod & " " & tools.quote(host) & ", " & tools.quote(domain) & ", " & route & newLine
      # router not within a host-block
      elif line.startsWith("router"):
        let routerDefinition = line.split(" ")
        var route = routerDefinition[1]
        lineToAdd = "x_router " & tools.quote(host) & ", " & tools.quote(domain) & ", " & route & newLine
    result &= lineToAdd

macro subdomain*(name, body: untyped): void =
  let name = repr(name).unquote.toLower
  let body = reformatSubdomainCode(name, defaultHost, repr(body))
  parseStmt(body)

proc reformatHostCode(host, body: string): string =
  var domain = defaultDomain
  var router = ""
  for line in body.split(newLine):
    var lineToAdd = line & newLine
    if line.len > 0 and ':' in line:
      # Subdomain
      if strip(line).startsWith("subdomain"):
        router = ""
        domain = unquote(line.split(" ")[1].replace(":", ""))
      # Router
      elif strip(line).startsWith("router"):
        if indentation(line) == 0: domain = defaultDomain
        router = strip(line).split(" ")[1].replace(":", "").unquote
      # Request Handler
      elif strip(line).startsWithRequestMethod:
        let indent = indentation(line) # level of indentation
        case indent:
          of 0: # just inside host
            domain = defaultDomain
            router = ""
          else: # other options
            discard
        var line = line[indent .. line.len - 1]
        let handlerDef = line.split(" ")
        var route = handlerDef[1].unquote.strip(chars = {':'})
        route = if route.len == 1 and router != "": router else: router & route[0 .. route.len - 1]
        lineToAdd = repeat(" ", indent) & "x_" & handlerDef[0] & " " & tools.quote(host) & ", " & tools.quote(domain) & ", " & tools.quote(route) & ":" & newLine
    # Append line to result
    result &= lineToAdd

macro host*(host, body: untyped): void =
  let host = repr(host).unquote.toLower
  let body = reformatHostCode(host, repr(body))
  parseStmt(body)

proc printServerStructure*(): void =
  logger.log(lvlInfo, xanderRoutes)
  
# TODO: Dynamically created directories are not supported
proc serveFiles*(route: string): void =
  # Given a route, e.g. '/public', this proc
  # adds a get method for provided directory and
  # its child directories. This proc is RECURSIVE.
  var route = route.replace(applicationDirectory, "")
  logger.log(lvlInfo, "Serving files from ", applicationDirectory & route)
  let path = if route.endsWith("/"): route[0..route.len-2] else: route # /public/ => /public
  let newRoute = path & "/:fileName" # /public/:fileName
  for host in xanderRoutes.keys: # add file serving for every host
    addGet(host, defaultDomain, newRoute, proc(request: Request, data: var Data, headers: var HttpHeaders, cookies: var Cookies, session: var Session, files: var UploadFiles): types.Response {.gcsafe.} = 
      let filePath = applicationDirectory & path / decodeUrl(data.get("fileName")) # ./public/.../fileName
      let ext = splitFile(filePath).ext
      if existsFile(filePath):
        headers["Content-Type"] = getContentType(ext)
        respond readFile(filePath)
      else: respond Http404)
  for directory in walkDirs(applicationDirectory & path & "/*"):
    serveFiles(directory)

proc fetch*(url: string): string =
  var client = newAsyncHttpClient()
  waitFor client.getContent(url)

setControlCHook(proc() {.noconv.} =
  close(xanderServer)
  quit(0)
)

when isMainModule:
  
  include xander/cli

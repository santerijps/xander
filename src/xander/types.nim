import
  asyncdispatch,
  asynchttpserver,
  json,
  regex,
  sequtils,
  strutils,
  tables,
  macros

import
  constants,
  tools

type
  Cookie* = tuple
    name: string
    value: string
    domain: string
    path: string
    expires: string
    secure: bool
    httpOnly: bool

func newCookie*(name, value, domain, path, expires = "", secure, httpOnly = false): Cookie =
  return (name, value, domain, path, expires, secure, httpOnly)

type
  Cookies* = tuple
    client: Table[string, Cookie]
    server: Table[string, Cookie]

func newCookies*(): Cookies =
  var c: Cookies
  c.client = initTable[string, Cookie]()
  c.server = initTable[string, Cookie]()
  return c

func get*(cookies: Cookies, cookieName: string): string =
  if cookies.client.hasKey(cookieName):
    return cookies.client[cookieName].value

func set*(cookies: var Cookies, c: Cookie): void =
  let cookieName = c.name
  cookies.server[cookieName] = c

func set*(cookies: var Cookies, name, value, domain, path, expires = "", secure, httpOnly = false): void =
  cookies.server[name] = newCookie(name, value, domain, path, expires, secure, httpOnly)

func contains*(cookies: var Cookies, cookieName: string): bool =
  cookies.client.hasKey(cookieName)

func contains*(cookies: Cookies, keys: varargs[string]): bool =
  result = true
  for key in keys:
    if not cookies.client.hasKey(key):
      return false

func containsAndEquals*(cookies: var Cookies, cookieName, value: string): bool =
  cookies.contains(cookieName) and cookies.get(cookieName) == value

func remove*(cookies: var Cookies, cookieName: string): void =
  cookies.server[cookieName] = newCookie(cookieName, expires = unixEpoch)

# Cookies in the request header only contain the 'name' and 'value' -fields
func setClient*(cookies: var Cookies, name, value: string = ""): void =
  cookies.client[name] = newCookie(name, value)

type
  Data* = JsonNode

func newData*(): Data =
  newJObject()

func newData*[T](key: string, value: T): Data = 
  result = newData()
  set(result, key, value)

func get*(data: Data, key: string): string =
  let d = data.getOrDefault(key)
  if d != nil:
    return d.getStr()

macro withData*(keys: varargs[string], body: untyped): void =
  var vars = repr(keys).strip(chars = {'[', ']'}).replace("\"", "").split(", ")
  var source: string = "if"
  # create if statement
  for i in 0 .. vars.len - 1:
    source &= " data.hasKey($1)".format(tools.quote(vars[i]))
    if i == vars.len - 1: source &= ":\n"
    else: source &= " and"
  # add var declaration(s)
  for v in vars:
    source &= tab & "var $1 = data.get($2)\n".format(v.replace('-', '_'), tools.quote(v))
  # add body
  for line in repr(body).splitLines:
    if line.len > 0:
      source &= tab & line & newLine
  # parse statement
  parseStmt(source)

macro withHeaders*(keys: varargs[string], body: untyped): void =
  var vars = repr(keys).strip(chars = {'[', ']'}).replace("\"", "").split(", ")
  var source: string = "if"
  # create if statement
  for i in 0 .. vars.len - 1:
    source &= " request.headers.hasKey($1)".format(tools.quote(vars[i]))
    if i == vars.len - 1: source &= ":\n"
    else: source &= " and"
  # add var declaration(s)
  for v in vars:
    source &= tab & "var $1 = request.headers[$2]\n".format(v.replace('-', '_'), tools.quote(v))
  # add body
  for line in repr(body).splitLines:
    if line.len > 0:
      source &= tab & line & newLine
  # parse statement
  parseStmt(source)

func getBool*(data: Data, key: string): bool =
  let d = data.getOrDefault(key)
  if d != nil:
    return d.getBool()

func getInt*(data: Data, key: string): int =
  let d = data.getOrDefault(key)
  if d != nil:
    return d.getInt()

func set*[T](node: var Data, key: string, data: T) = 
  add(node, key, %data)

func add*[T](node: Data, key: string, value: T): Data =
  result = node
  add(node, key, %value)

func hasKeys*(data: Data, keys: varargs[string]): bool =
  result = true
  for key in keys:
    if not data.hasKey(key):
      return false

func `[]=`*[T](node: var Data, key: string, value: T) =
  add(node, key, %value)

type 
  Dictionary* =
    Table[string, string]

func newDictionary*(): Dictionary =
  return initTable[string, string]()

func set*(dict: var Dictionary, key, value: string) =
  dict[key] = value

type
  Response* = tuple
    body: string
    httpCode: HttpCode
    headers: HttpHeaders

type
  Session* = Data
  Sessions* = Table[string, Session]

func newSession*(): Session =
  newData()

func newSessions*(): Sessions =
  initTable[string, Session]()

func remove*(session: var Session, key: string): void =
  if session.hasKey(key):
    delete(session, key)

type
  UploadFile* = tuple
    name, ext, content: string
    size: int

func newUploadFile*(name, ext, content: string, size: int = 0): UploadFile =
  (name, ext, content, size)

type
  UploadFiles* =
    Table[string, seq[UploadFile]]

func newUploadFiles*(): UploadFiles =
  return initTable[string, seq[UploadFile]]()

type
  RequestHandlerVariables* = tuple
    data: Data
    headers: HttpHeaders
    cookies: Cookies
    session: Session
    files: UploadFiles

func newRequestHandlerVariables*(): RequestHandlerVariables =
  (newData(), newHttpHeaders(), newCookies(), newSession(), newUploadFiles())
  
type
  RequestHandler* =
    proc(request: Request, data: var Data, headers: var HttpHeaders, cookies: var Cookies, session: var Session, files: var UploadFiles): Response {.gcsafe.}
    # TODO: Would below work?
    #proc(request: Request, X: var RequestHandlerVariables): Response {.gcsafe.}

template newRequestHandler*(body: untyped): RequestHandler =
  body

type
  ServerRoute* = tuple
    route: string
    handler: RequestHandler

func newServerRoute*(route: string, handler: RequestHandler): ServerRoute =
  (route, handler)

type
  Domain* = 
    # HttpMethod => List of Server Routes
    Table[HttpMethod, seq[ServerRoute]]
  Domains* =
    Table[string, Domain]

func newDomain*(): Domain =
  initTable[HttpMethod, seq[ServerRoute]]()

func newDomains*(): Domains =
  initTable[string, Domain]()

type
  Hosts* =
    # Host => Domains
    Table[string, Domains]

const defaultHost* = "DEFAULT_HOST"
const defaultDomain* = "DEFAULT_DOMAIN"
const defaultMethod* = HttpGet

func `$`*(server: Hosts): string =
  result = newLine & newLine & "~~~ SERVER STRUCTURE ~~~" & newLine
  for host in server.keys:
    result &= " HOST " & host & newLine
    for domain in server[host].keys:
      result &= "  DOMAIN " & domain & newLine
      for httpMethod in server[host][domain].keys:
        result &= "   METHOD " & $httpMethod & newLine
        for route in server[host][domain][httpMethod]:
          result &= "    ROUTE " & route.route & newLine
  result &= "~~~ SERVER STRUCTURE ~~~" & newLine & newLine

func newHosts*(): Hosts =
  initTable[string, Domains]()

func existsHost*(server: Hosts, host: string): bool =
  server.hasKey(host)

func existsDomain*(server: Hosts, domain: string, host: string): bool =
  server.existsHost(host) and server[host].hasKey(domain)

func existsMethod*(server: Hosts, httpMethod: HttpMethod, host = defaultHost, domain = defaultDomain): bool =
  server.existsHost(host) and server.existsDomain(domain, host) and server[host][domain].hasKey(httpMethod)

func addHost*(server: var Hosts, host = defaultHost): void =
  if not server.hasKey(host):
    server[host] = newDomains()

func addDomain*(server: var Hosts, domain = defaultDomain, host = defaultHost): void =
  server[host][domain] = newDomain()

func addMethod*(server: var Hosts, httpMethod = defaultMethod, host = defaultHost, domain = defaultDomain): void =
  if server.hasKey(host) and server[host].hasKey(domain):
    server[host][domain][httpMethod] = newSeq[ServerRoute]()

func getRoutes*(server: Hosts, host = defaultHost, domain = defaultDomain, httpMethod = defaultMethod): seq[ServerRoute] =
  server[host][domain][httpMethod]

func addRoute*(server: var Hosts, httpMethod: HttpMethod, route: string, handler: RequestHandler, host = defaultHost, domain = defaultDomain): void =
  if not server.existsHost(host):
    server.addHost(host)
  if not server.existsDomain(domain, host):
    server.addDomain(domain, host)
  if not server.existsMethod(httpMethod, host, domain):
    server.addMethod(httpMethod, host, domain)
  var routes = server.getRoutes(host, domain, httpMethod)
  routes.add newServerRoute(route, handler)
  server[host][domain][httpMethod] = routes

func addRoute*(server: var Hosts, route: string, handler: RequestHandler, host = defaultHost, domain = defaultDomain, httpMethod: HttpMethod = defaultMethod): void =
  var routes = server.getRoutes(host, domain, httpMethod)
  routes.add newServerRoute(route, handler)
  server[host][domain][httpMethod] = routes

proc isDefaultHost*(server: Hosts): bool =
  server.existsHost(defaultHost) #and server.len == 1

type
  ErrorHandler* = 
    proc(request: Request, httpCode: HttpCode): Response {.gcsafe.}
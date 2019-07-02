import
  asyncdispatch,
  asynchttpserver,
  json,
  regex,
  tables

import
  constants

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

func contains*(data: Data, keys: varargs[string]): bool =
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

type
  Route* = Table[string, RequestHandler]
  RoutingTable* = Table[HttpMethod, Route]

func newRoute*(): Route =
  initTable[string, RequestHandler]()

func newRoutingTable*(): RoutingTable =
  initTable[HttpMethod, Route]()

func `$`*(routingTable: RoutingTable): string =
  for httpMethod, route in routingTable.pairs:
    result &= $httpMethod
    for r, m in route.pairs:
      result &= newLine & tab & r

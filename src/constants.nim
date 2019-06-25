import
  regex

const # Characters 
  newLine*: string = "\n"
  tab*: string = "  "

const # Template tags
  contentTag*: string = "{[%content%]}"

const # Request handler string
  requestHandlerString*: string = "proc(request: Request, data: var Data, headers: var HttpHeaders, cookies: var Cookies, session: var Session, files: var UploadFiles): Response {.gcsafe.} ="

const # Time
  unixEpoch*: string = "Thu, 1 Jan 1970 12:00:00 UTC"
import ../../src/xander

get "/":
  #
  # The injected variables
  #  request: Request
  #  data: var Data*
  #  headers: var Headers
  #  cookies: var Cookies*
  #  session: var Session*
  #  files: var UploadFiles*
  # exist in this block implicitly.
  # (* marks Xander's own data types)
  #
  # The return type of this method is Xander's own Response type, which
  # is a tuple[body: string, httpCode: HttpCode, headers: HttpHeaders].
  # Returning the 'respond' proc call returns this tuple
  #
  assert respond("Hello World!") == ("Hello World!", Http200, nil)
  assert respond(Http404) == ("", Http404, nil)

runForever(3000)
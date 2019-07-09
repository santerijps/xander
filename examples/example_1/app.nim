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
  respond "Hello World!"

runForever(3000)
import ../../../src/xander

get "/":
  respond "Index"

router "/about":
  get "/":
    redirect "/about/us"
  get "/us":
    respond "We are a small scale company."
  get "/sponsors":
    respond "We have multiple sponsors."
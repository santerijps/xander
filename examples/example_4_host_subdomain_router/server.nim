import ../../src/xander

host "localhost":

  get "/":
    respond "Welcome to localhost!"
  
  router "/about":

    get "/":
      redirect "/about/us"
    
    get "/us":
      respond "Us or we?"

  subdomain "api":

    get "/":
      respond "You will find many interesting things in this API..."
    
    router "/countries":

      get "/":
        respond "List of countries"

      get "/:search":
        let search = data.get("search")
        respond "You searched for " & search


printServerStructure()
runForever 3000
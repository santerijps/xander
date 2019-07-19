import ../../../src/xander

# api.mysite.com
subdomain API:

  # api.mysite.com/
  get "/":
    respond "API Index"

  # api.mysite.com/countries
  router "/countries":

    # api.mysite.com/countries/
    get "/":
      respond "Countries Index"
    
    # api.mysite.com/countries/:search
    get "/:search":
      let search = data.get("search")
      respond "You searched for this country: " & search
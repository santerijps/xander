import ../../src/xander

serveFiles "/public"
setTemplateDirectory "/templates"

var db {.threadvar.} : Table[string, string]
db = initTable[string, string]()

get "/":
  if session.hasKey("authenticated") and session.getBool("authenticated"):
    return redirect("/home")
  var uploadedFiles = "<ul>"
  for f in walkFiles("./public/uploads/*"):
    uploadedFiles &= &"<li><a href=\"{f}\">{f}</a></li>"
  uploadedFiles &= "</ul>"
  data["UploadedFiles"] = uploadedFiles
  respond tmplt("index", data)

get "/math/sum":
  var response = ""
  var sum = 0
  if data.hasKey("nums"):
    let nums = data.get("nums").toIntSeq()
    response &= "Nums = " & $nums
    for num in nums:
      sum += num
    response &= "\nSum = " & $sum
    if data.hasKey("avg"):
      response &= "\nAvg = " & $(sum / nums.len)
  respond response

get "/home":
  if not(session.hasKey("authenticated") and session.getBool("authenticated")):
    redirect("/")
  else:
    respond tmplt("home", session)

proc login(session: var Session, user, pass: string): Response =
  session["authenticated"] = true
  session["username"] = user
  session["password"] = pass
  return redirect("/home")

post "/register":
  if data.contains("username", "password"):
    let
      user = data.get("username")
      pass = data.get("password")
    if user.len > 0 and pass.len > 0:
      db[user] = pass
      return login(session, user, pass)
  redirect("/")

post "/login":
  var
    oldUser: string 
    errors: string
  if data.contains("username", "password"):
    let 
      user = data.get("username")
      pass = data.get("password")
    if db.hasKey(user):
      if db[user] == pass:
        return login(session, user, pass)
      else:
        oldUser = user
        errors.add("Bad password! ")
    else:
      errors.add("User doesn't exist!")
  respond tmplt("index", newData("loginErrors", errors).add("oldUser", oldUser))    

# AJAX
post "/logout": 
  if data.contains("logout") and data.getBool("logout"):
    session.remove("authenticated")
    return respond newData("redirect", true)
  respond newData("redirect", false)

post "/upload":
  var filesString = "<h3>File Upload Status</h3><ul>"
  for file in files["upload"]:
    if file.size < 100000: # File smaller than 100KB
      uploadFile("./public/uploads", file)
      filesString &= &"<li>UPLOADED: {file.name} {file.ext} {file.size}</li>"
    else:
      filesString &= &"<li>FAILED: {file.name} {file.ext} {file.size}</li>"
  filesString &= "</ul><h2>You will be redirected in 10 seconds</h2>"
  headers["refresh"] = "10;url=\"/\""
  serveFiles "/public/uploads"
  respond html(filesString)

runForever(3000)
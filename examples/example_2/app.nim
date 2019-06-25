import ../../src/xander

serveFiles "/public"
setTemplateDirectory "/templates"

get "/":
  if session.hasKey("authenticated") and session.getBool("authenticated"):
    return redirect("/home")
  var uploadedFiles = "<ul>"
  for f in walkFiles("./public/uploads/*"):
    let name = f.extractFileName
    uploadedFiles &= &"<li><a href=\"{f}\">{name}</a><a href=\"/remove?f={f}\">(X)</a></li>"
  uploadedFiles &= "</ul>"
  data["UploadedFiles"] = uploadedFiles
  respond tmplt("index", data)

get "/remove":
  var removed = false
  if data.hasKey("f"):
    let filePath = data.get("f")
    if existsFile(filePath):
      removeFile(filePath)
      removed = true
  let status = if not removed: " not" else: ""
  redirect("/", "File was" & status & " removed", 6)

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
  respond html(filesString)

runForever(3000)
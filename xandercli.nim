import
  os

proc newApp(appName: string) =
  var
    projectDir = os.getCurrentDir() & "/" & appName
    appNim = projectDir & "/app.nim"
    appDir = projectDir & "/app"
    binDir = projectDir & "/bin"
    pubDir = projectDir & "/public"
    models = appDir & "/models"
    views = appDir & "/views"
    layoutHtml = views & "/layout.html"
    indexHtml = views & "/index.html"
    controllers = appDir & "/controllers"
  os.createDir(projectDir)
  os.createDir(appDir)
  os.createDir(binDir)
  os.createDir(pubDir)
  os.createDir(models)
  os.createDir(views)
  os.createDir(controllers)
  discard open(appNim, fmWrite)
  discard open(layoutHtml, fmWrite)
  discard open(indexHtml, fmWrite)

proc runApp() =
  var 
    appNim = os.getCurrentDir() & "/app.nim"
    appExe = os.getCurrentDir() & "/bin/www"
    cmd = "nim c -r --out:" & appExe & " --hints:off --verbosity:0 --threads:on "
  if os.fileExists(appNim):
    discard os.execShellCmd(cmd & appNim)

proc runXander*() =
  if os.paramCount() >= 1:
    var params = os.commandLineParams()
    case params[0]:
      of "new":
        if os.paramCount() > 1:
          newApp(params[1])
        else:
          echo "Provide app name!"
      of "run":
        runApp()
      else:
        echo "unknown command"

when isMainModule:
  runXander()
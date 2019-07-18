import
  os,
  osproc,
  sequtils,
  strutils

proc newProject(appDir = "my-xander-app"): void = 
  stdout.write "Creating project '$1'... ".format(appDir)
  createDir(appDir)
  createDir(appDir / "templates")
  createDir(appDir / "public")
  createDir(appDir / "public" / "css")
  createDir(appDir / "public" / "js")
  writeFile(appDir / "app.nim", """import xander

get "/":
  respond tmplt("index")

get "/about":
  respond tmplt("about")

get "/contact":
  respond tmplt("contact")

serveFiles("/public")
printServerStructure()
runForever(3000)""")
  writeFile(appDir / "templates" / "layout.html", """<!DOCTYPE html>
<html lang="en">

  <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta http-equiv="X-UA-Compatible" content="ie=edge">
    <link rel="stylesheet" href="/public/css/styles.css">
    <link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/4.3.1/css/bootstrap.min.css">
    <script src="https://ajax.googleapis.com/ajax/libs/jquery/3.4.1/jquery.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/popper.js/1.14.7/umd/popper.min.js"></script>
    <script src="https://maxcdn.bootstrapcdn.com/bootstrap/4.3.1/js/bootstrap.min.js"></script>
    <link rel="shortcut icon" type="image/png" href="https://upload.wikimedia.org/wikipedia/commons/1/1b/Nim-logo.png">
    <title>$1</title>
  </head>

  <body>

    <div class="jumbotron text-center" style="margin-bottom:0">
      <h1>$1</h1>
      <p>Powered by Xander</p> 
    </div>

    <nav class="navbar navbar-expand-sm navbar-dark bg-dark">
      <ul class="navbar-nav">
        <li class="nav-item">
          <a class="nav-link" href="/">Home</a>
        </li>
        <li class="nav-item">
          <a class="nav-link" href="/about">About</a>
        </li>
        <li class="nav-item">
          <a class="nav-link" href="/contact">Contact</a>
        </li>
      </ul>
    </nav>

    <div class="container" style="margin-top: 30px;">
      {[%content%]}
    </div>

  </body>

</html>""".format(appDir))
  writeFile(appDir / "templates" / "index.html", """<h1>Home</h1>
<hr>
<p>
  Congratulations! This app is running Xander! For Xander reference, check out
  <a href="http://xander-nim.tk">xander-nim.tk</a> and 
  <a href="https://github.com/sunjohanday/xander">Xander's GitHub page</a>.
</p>""")
  writeFile(appDir / "templates" / "about.html", """<h1>About</h1>
<hr>
<p>
  Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed tempor odio quis sem tincidunt, id tincidunt velit rutrum. Orci varius natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus. Sed lectus nisl, lacinia sed volutpat a, convallis a velit. Etiam rhoncus tincidunt enim, sed interdum justo tincidunt eu. Nulla bibendum dui at mi vulputate, sed eleifend turpis sodales. Vivamus dignissim dapibus blandit. In laoreet mattis dapibus. Pellentesque magna elit, porta sed tristique et, tempus sit amet justo. Curabitur aliquet feugiat tincidunt. Fusce tempor efficitur mi blandit consequat. Praesent sed maximus risus. Nullam nulla purus, pellentesque quis leo sed, tincidunt ultrices enim. Curabitur at ante et justo porta bibendum. Morbi quis bibendum ipsum, a vulputate mi. Nulla blandit sodales diam a pharetra. Phasellus tristique, magna nec dapibus aliquam, felis nisl viverra ipsum, vitae hendrerit felis nisi ut tortor.
  Vestibulum ut lobortis dui, sit amet dictum dolor. Integer vitae varius lectus, quis tincidunt mauris. Phasellus sodales ligula non vestibulum faucibus. Duis ac risus eleifend nisl accumsan feugiat. Maecenas vestibulum dolor id nibh molestie, a mollis dolor viverra. Proin at feugiat est. Cras porta suscipit dignissim. Pellentesque maximus libero at eros fringilla tincidunt. Vestibulum ultricies pulvinar finibus. Phasellus id rutrum dui, vel condimentum nunc. Vivamus condimentum aliquet magna ut convallis. Maecenas congue dignissim urna, ac feugiat lorem cursus at. Integer placerat, quam id vulputate sollicitudin, dui neque pellentesque est, sed malesuada mauris ligula non ex. Sed ac dignissim massa, sit amet congue diam.
  Ut pellentesque rhoncus ultricies. Aenean non pretium diam. Nunc fringilla ante eleifend, maximus lacus non, euismod orci. Sed non orci ornare, condimentum sapien commodo, efficitur eros. Mauris quis magna sed sapien aliquet feugiat. Duis scelerisque purus libero, et condimentum lacus faucibus eu. Proin porttitor molestie arcu a consectetur. Nunc sed tortor non ipsum finibus condimentum. Duis quis scelerisque sem, vel sagittis lorem. Proin egestas lorem nec augue finibus dapibus.
  Donec malesuada ante eu diam tincidunt, id commodo nisi accumsan. Phasellus non dictum justo. Suspendisse pharetra quis dolor eu pretium. Proin consectetur imperdiet lacus quis sollicitudin. Vivamus hendrerit metus bibendum erat semper, id placerat nibh tristique. Suspendisse quis tristique leo, ac consectetur velit. Vivamus dui velit, porta a urna sit amet, tristique vestibulum orci.
  Curabitur velit lacus, mattis at quam vitae, ultricies ornare dui. Nam sed elementum orci. Pellentesque eu quam nunc. Morbi pharetra consectetur lorem quis molestie. Praesent viverra arcu elit, venenatis elementum diam commodo a. Integer venenatis turpis vel felis sodales, vitae iaculis odio dignissim. Aliquam erat volutpat.
</p>""")
  writeFile(appDir / "templates" / "contact.html", """<h1>Contact</h1>
<hr>
<p>
  Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed tempor odio quis sem tincidunt, id tincidunt velit rutrum. Orci varius natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus. Sed lectus nisl, lacinia sed volutpat a, convallis a velit. Etiam rhoncus tincidunt enim, sed interdum justo tincidunt eu. Nulla bibendum dui at mi vulputate, sed eleifend turpis sodales. Vivamus dignissim dapibus blandit. In laoreet mattis dapibus. Pellentesque magna elit, porta sed tristique et, tempus sit amet justo. Curabitur aliquet feugiat tincidunt. Fusce tempor efficitur mi blandit consequat. Praesent sed maximus risus. Nullam nulla purus, pellentesque quis leo sed, tincidunt ultrices enim. Curabitur at ante et justo porta bibendum. Morbi quis bibendum ipsum, a vulputate mi. Nulla blandit sodales diam a pharetra. Phasellus tristique, magna nec dapibus aliquam, felis nisl viverra ipsum, vitae hendrerit felis nisi ut tortor.
  Vestibulum ut lobortis dui, sit amet dictum dolor. Integer vitae varius lectus, quis tincidunt mauris. Phasellus sodales ligula non vestibulum faucibus. Duis ac risus eleifend nisl accumsan feugiat. Maecenas vestibulum dolor id nibh molestie, a mollis dolor viverra. Proin at feugiat est. Cras porta suscipit dignissim. Pellentesque maximus libero at eros fringilla tincidunt. Vestibulum ultricies pulvinar finibus. Phasellus id rutrum dui, vel condimentum nunc. Vivamus condimentum aliquet magna ut convallis. Maecenas congue dignissim urna, ac feugiat lorem cursus at. Integer placerat, quam id vulputate sollicitudin, dui neque pellentesque est, sed malesuada mauris ligula non ex. Sed ac dignissim massa, sit amet congue diam.
  Ut pellentesque rhoncus ultricies. Aenean non pretium diam. Nunc fringilla ante eleifend, maximus lacus non, euismod orci. Sed non orci ornare, condimentum sapien commodo, efficitur eros. Mauris quis magna sed sapien aliquet feugiat. Duis scelerisque purus libero, et condimentum lacus faucibus eu. Proin porttitor molestie arcu a consectetur. Nunc sed tortor non ipsum finibus condimentum. Duis quis scelerisque sem, vel sagittis lorem. Proin egestas lorem nec augue finibus dapibus.
  Donec malesuada ante eu diam tincidunt, id commodo nisi accumsan. Phasellus non dictum justo. Suspendisse pharetra quis dolor eu pretium. Proin consectetur imperdiet lacus quis sollicitudin. Vivamus hendrerit metus bibendum erat semper, id placerat nibh tristique. Suspendisse quis tristique leo, ac consectetur velit. Vivamus dui velit, porta a urna sit amet, tristique vestibulum orci.
  Curabitur velit lacus, mattis at quam vitae, ultricies ornare dui. Nam sed elementum orci. Pellentesque eu quam nunc. Morbi pharetra consectetur lorem quis molestie. Praesent viverra arcu elit, venenatis elementum diam commodo a. Integer venenatis turpis vel felis sodales, vitae iaculis odio dignissim. Aliquam erat volutpat.
</p>""")
  writeFile(appDir / "public" / "css" / "styles.css", """html {
  min-height: 100%;
}

body {
  margin: 0 auto;
  min-height: 100%;
  font-family: Arial; 
}""")
  echo "Done!"

type
  CmdResponse = tuple
    output: TaintedString
    exitCode: int

proc cmd(s: string): CmdResponse =
  execCmdEx(s)

proc nimCompile(fileName: string): CmdResponse =
  cmd("nim c --threads:on --verbosity:1 --hints:off $1".format(fileName))

proc runProject(fileName = "app.nim"): void =
  if existsFile(fileName):
    discard execCmd("rm ." / fileName.splitFile.name)
    discard nimCompile(fileName)
    discard execCmd("." / fileName.splitFile.name)
  else:
    echo "File not found: ", fileName

proc getProcessId(port: string, pid: var string): bool =
  var output = execProcess("lsof -i | grep *:$1".format(port)).strip()
  var parts = output.split(" ").filter(proc(x: string): bool = x.len > 0)
  if parts.len > 1:
    pid = parts[1]
    return true

proc killProcess(pid: string): void =
  discard execProcess("kill $1".format(pid))

proc updateXander(): void =
  echo execCmd("nimble install https://github.com/sunjohanday/xander")

setControlCHook(proc() {.noconv.} =
  quit(0)
)

let params = commandLineParams()

if params.len == 0:
  echo "No command provided."

else:
  case params[0]:
    
    of "new":
      if params.len > 1:
        newProject(params[1])
      else:
        newProject()
    
    of "run":
      if params.len > 1:
        runProject(params[1])
      else:
        runProject()
    
    of "listen":

      var fileName {.threadvar.} : string 
      var execName {.threadvar.} : string 
  
      if params.len > 1:
        fileName = params[1]
        execName = fileName.splitFile.name

      else:
        fileName = "app.nim"
        execName = "app"

      var app: Thread[string]
      var appProc = proc(execName: string) {.thread, nimcall.} = 
        let output = execProcess("./$1 &".format(execName))
        if output.len > 0:
          echo "\n~~~OUTPUT~~~\n$1\n~~~/OUTPUT~~~\n".format(output)

      var (output, exitCode) = nimCompile(fileName)

      if exitCode == 1:
        echo output
      else:
        createThread(app, appProc, execName)

      proc getPort(): string =
        for line in fileName.lines:
          if "runForever" in line:
            result = line.replace("(", "").replace(")", "").replace(" ", "").replace("runForever", "")
            # Linux: lsof command recognizes port 8080 as http-alt
            result = if result == "8080": "http-alt" else: result 

      var pid: string                   # Process ID
      var previous = readFile(fileName) # File content previously
      var next: TaintedString           # File content now
      var port = getPort()              # Application port

      echo "Listening $1 on port $2".format(fileName, port)

      # Infinite loop?
      while true:

        # Get file content
        next = readFile(fileName)

        # File content has changed
        if next != previous:
          echo "Code changed!"
          previous = next

          # If process is found, kill it and re-compile
          if getProcessId(port, pid):
            killProcess(pid)
            (output, exitCode) = nimCompile(fileName)
            if exitCode == 1:
              echo output
            else:
              port = getPort()
              createThread(app, appProc, execName) 

          else:
            port = getPort()
            createThread(app, appProc, execName) 

        sleep(200)

    of "update":
      updateXander()
    
    else:
      echo "Bad command! Commands are 'new' and 'run'."
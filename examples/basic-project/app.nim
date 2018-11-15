import 
  ../../xander,
  app/controllers/controller

xander.setPort(3000)
xander.setMode(ApplicationMode.Debug)

addGet("/", controller.serveIndexPage)

startServer()
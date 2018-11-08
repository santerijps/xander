import 
  ../../xander,
  app/controllers/controller

xander.setPort(3000)
xander.setMode(APP_MODE.DEBUG)

get("/", controller.serveIndexPage)

startServer()
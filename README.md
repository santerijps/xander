# Xander (work in progress)
A simple HTTP library for Nim inspired by Node.js and Express.

A basic example:
```nim
import ../Xander

get "/":
  display("index")

get "/about": 
  display("This is the very basic example")

startServer()
```
More examples can be found in the ```examples``` folder.

## Getting started with xandercli (coming soon)
1. Move to directory you want to create your project
2. In the command line, type ```xander new my-first-app```
3. ```$ cd my-first-app```
4. To run your app, type ```xander run``` in the command line

## Project structure
The default folder structure is the following:
```
Project root folder
  app
    controllers
    models
    views
      layout.html
      index.html
  bin
  public
    css
      bootstrap.min.css
      ...
    js
      bootstrap.min.js
      ...
  app.nim
  ...
```
The public folder can be altered by calling the Xander methods
```nim
xander.setStaticDir("new dir")
```

## Templates
Xander provides support for templates, although it is very much a work in progress and for example *does not* support including files.
To serve a template file:
```nim
# Serve the index page
displayTemplate("index")
```
The default folder for templates is the ```app/views``` folder, but it can also be changed by calling
```nim
xander.setTemplateDir("new dir")
```
By having a ```layout.html``` template one can define a base layout for their pages.
```html
<!DOCTYPE html>
<html>
  <head>
    <title>{[title]}</title>
  </head>
  <body>
    {[%content%]}
    {[template footer]}
  </body>
</html>
```
In the example above, ```{[title]}``` is a user defined variable, whereas ```{[%content%]}``` is a Xander defined variable, that contains the contents of a template file. To include your own templates, use the ```template``` keyword ```{[template my-template]}```. You can also include templates that themselves include other templates.

### User-defined variables
Xander provides a custom type ```Data```, which is shorthand for ```JsonNode```, and it also adds some functions to make life easier. To initialize it, one must use the ```newData()``` func. In the initialized variable, one can add key-value pairs
```nim
var vars = newData()
vars["name"] = "Alice"
vars["age"] = 21

# or you can initialize it with a pair
var vars = newData("name", "Alice")
```
In a template, one must define the variables with matching names
```html
<p>{[name]} is {[age]} years old.</p>
```

## Dynamic routes
To match a custom route and get the provided value(s), one must simply use a colon to specify a dynamic value. The values will be stored in the ```vars``` parameter.
```nim
# User requests /countries/ireland/people/paddy
get("/countries/:country/people/:person", proc(req: Request, vars: var Data): Response =  
  # vars["country"] == "ireland"
  # vars["person"] == "paddy"
  displayTemplate("userPage", vars)
)
```
```html
<h1>{[person]} is from {[country]}</h1>
```

## TODO
1. Error checking / handling
2. Code refactoring
3. Seperating different tasks to different files(???)
4. Template logic (e.g. loops)
5. Impement web sockets
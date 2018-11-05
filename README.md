# Xander
A simple HTTP library for Nim inspired by Node.js and Express.

A basic example:
```nim
import ../Xander

get("/", (r, v) => r.respond("The index page"))

get("/about", proc(req: Request, vars: Vars) {.async.} = 
  await req.respond("This is the very basic example")
)

startServer()
```
More examples can be found in the ```examples``` folder.

## Project structure
The default folder structure is the following:
```
Root
  public
    css
    html
    js
  main.nim
  ...
```
The public folder can be altered by changing the Xander variable in your project file
```nim
Xander.publicDir = "./myPublicFiles/"
```
In the future, I will be looking into having MVC be the default project structure.

## Templates
Xander provides support for templates, although it is very much a work in progress and for example *does not* support including files.
To serve a template file:
```nim
# Serve the index page
await req.display("index")
```
The default folder for templates is the ```public/html``` folder, but it can also be changed by altering the variable
```nim
Xander.templateDir = "./public/mytemplates/"
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
  </body>
</html>
```
In the example above, ```{[title]}``` is a user defined variable, whereas ```{[%content%]}``` is a Xander defined variable, that contains the contents of a template file.

### User-defined variables
Xander provides a custom type ```Vars```, which is shorthand for ```Table[string, string]```. To initialize it, one must use the ```newVars()``` proc. In the initialized variable, one can add key-value pairs
```nim
var vars = newVars()
vars["name"] = "Alice"
vars["age"] = "21"
```
In a template, one must define the variables with matching names
```html
<p>{[name]} is {[age]} years old.</p>
```

## Dynamic routes
To match a custom route and get the provided value(s), one must simply use a colon to specify a dynamic value. The values will be stored in the ```vars``` parameter.
```nim
# User requests /countries/ireland/people/paddy
get("/countries/:country/people/:person", proc(req: Request, vars: Vars) {.async.} =  
  # vars["country"] == "ireland"
  # vars["person"] == "paddy"
  await req.display("userPage", vars)
)
```
```html
<h1>{[person]} is from {[country]}</h1>
```

import ../../src/xander

get "/":
  respond "Index"

get "/users":
  let users = fetch("https://jsonplaceholder.typicode.com/users")
  respond users

runForever(3000)
import ../../src/xander

get "/":
  respond html"""
    <form action="/submit" method="POST">
      <input type="email" name="email">
      <input type="password" name="password">
      <input type="submit">
    </form>
  """

post "/submit":

  # Macro for:
  #
  # if data.hasKey("email") and data.hasKey("password"):
  #   var email = data.get("email")
  #   var password = data.get("password")
  #
  withData "email", "password":
    return redirect("/", "Your email is " & email & " and your password is " & password, 5)

  respond Http400


runForever(3000)
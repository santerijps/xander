import
  regex, tables, json, strutils

type
  TemplateVars = tuple
    keyword: string
    params: seq[string]
    variable: string

let keywords = @["for", "endfor", "template"]

var tmplt = """
  <h1>{[title]}</h1>
  <ul>
  {[for fruit fruits]}
    <li>{[fruit]}</li>
  {[endfor]}
  </ul>
"""

proc handleVar(text: string, boundaries: Slice[int], value: string): string =
  return

proc handleLoop[T](items: seq[T]): string =
  return

proc parseTemplateVars(text: string, boundaries: Slice[int]): TemplateVars =
  var 
    parts = text.substr(boundaries.a + 2, boundaries.b - 2).split(re"\s")
    keyword: string
    params: seq[string]
    variable: string
  if parts[0] in keywords:
    keyword = parts[0]
    if parts.len > 1:
      params = parts[1 .. parts.len - 1]
  else:
    variable = parts[0]
  return (keyword, params, variable)

var
  title = "List of fruits:" 
  fruits = @["apples", "bananas", "cucumbers"]
  tvars = %* {
    "title": title,
    "fruits": fruits
  }

var matches = regex.findAll(tmplt, re"\{\[(\w+\s*\w*\s*\w*)\]\}")
for match in matches:
  #echo match.boundaries
  var vars = parseTemplateVars(tmplt, match.boundaries)
  echo "Template vars: ", vars
  if vars.variable != "":
    if tvars.hasKey(vars.variable):
      discard handleVar(tmplt, match.boundaries, tvars[vars.variable].getStr())
  else:
    case vars.keyword:
      of "for":
        echo "for hehe"

echo tmplt

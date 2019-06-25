import
  strutils

func quote*(s: string): string =
  "\"" & s & "\""

func unquote*(s: string): string =
  s.replace("\"", "")

func unquote*(n: NimNode): string =
  repr(n).replace("\"", "")

func toIntSeq*(s: string, sep = ','): seq[int] =
  result = newSeq[int]()
  for value in s.multiReplace(("[", ""), ("]", "")).split(sep):
    result.add(parseInt(value))
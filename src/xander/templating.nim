import
  os

import
  types

proc readTemplates*(rootDir: string, templates: var Dictionary): void =
  var file: File
  for filepath in walkFiles(rootDir & "*"):
    if open(file, filepath, fmRead):
      templates.set(filepath.splitFile.name, readAll(file))
      close(file)
    else:
      echo "ERROR: Could not read template ", filepath
  for dir in walkDirs(rootDir & "*"):
    readTemplates(dir & "/", templates)
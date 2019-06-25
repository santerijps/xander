func getContentType*(ext: string, charset = "utf-8"): string =
  result = case ext:
    of ".aac":
      "audio/aac"
    of ".abw":
      "application/x-abiword"
    of ".arc":
      "application/x-freearc"
    of ".avi":
      "video/x-msvideo"
    of ".azw":
      "application/vnd.amazon.ebook"
    of ".bin":
      "application/octet-stream"
    of ".bmp":
      "image/bmp"
    of ".bz":
      "application/x-bzip"
    of ".bz2":
      "application/x-bzip2"
    of ".csh":
      "application/x-csh"
    of ".css":
      "text/css"
    of ".csv":
      "text/csv"
    of ".doc":
      "application/msword"
    of ".docx":
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
    of ".eot":
      "application/vnd.ms-fontobject"
    of ".epub":
      "application/epub+zip"
    of ".gif":
      "image/gif"
    of ".html":
      "text/html"
    of ".htm":
      "text/html"
    of ".ico":
      "image/vnd.microsoft.icon"
    of ".ics":
      "text/calendar"
    of ".jar":
      "application/java-archive"
    of ".jpg":
      "image/jpeg"
    of ".jpeg":
      "image/jpeg"
    of ".js":
      "text/javascript"
    of ".json":
      "application/json"
    of ".jsonld":
      "application/ld+json"
    of ".midi":
      "audio/midi audio/x-midi"
    of ".mid":
      "audio/midi audio/x-midi"
    of ".mjs":
      "text/javascript"
    of ".mp3":
      "audio/mpeg"
    of ".mpeg":
      "video/mpeg"
    of ".mpkg":
      "application/vnd.apple.installer+xml"
    of ".odp":
      "application/vnd.oasis.opendocument.presentation"
    of ".ods":
      "application/vnd.oasis.opendocument.spreadsheet"
    of ".odt":
      "application/vnd.oasis.opendocument.text"
    of ".oga":
      "audio/ogg"
    of ".ogv":
      "video/ogg"
    of ".ogx":
      "application/ogg"
    of ".otf":
      "font/otf"
    of ".png":
      "image/png"
    of ".pdf":
      "application/pdf"
    of ".ppt":
      "application/vnd.ms-powerpoint"
    of ".pptx":
      "application/vnd.openxmlformats-officedocument.presentationml.presentation"
    of ".rar":
      "application/x-rar-compressed"
    of ".rtf":
      "application/rtf"
    of ".sh":
      "application/x-sh"
    of ".svg":
      "image/svg+xml"
    of ".swf":
      "application/x-shockwave-flash"
    of ".tar":
      "application/x-tar"
    of ".tiff":
      "image/tiff"
    of ".tif":
      "image/tiff"
    of ".ts":
      "video/mp2t"
    of ".ttf":
      "font/ttf"
    of ".txt":
      "text/plain"
    of ".vsd":
      "application/vnd.visio"
    of ".wav":
      "audio/wav"
    of ".weba":
      "audio/webm"
    of ".webm":
      "video/webm"
    of ".webp":
      "image/webp"
    of ".woff":
      "font/woff"
    of ".woff2":
      "font/woff2"
    of ".xhtml":
      "application/xhtml+xml"
    of ".xls":
      "application/vnd.ms-excel"
    of ".xlsx":
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    of ".xml":
      "application/xml"
    of ".xul":
      "application/vnd.mozilla.xul+xml"
    of ".zip":
      "application/zip"
    of ".3gp":
      "video/3gpp"
    of ".3g2":
      "video/3gpp2"
    of ".7z":
      "application/x-7z-compressed"
    else:
      "text/plain"
  return result & "; charset=" & charset
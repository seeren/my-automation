function to_ms(ts, a, b, h, m, s, ms) {
  split(ts, a, ":")
  split(a[3], b, ",")
  h = a[1] + 0
  m = a[2] + 0
  s = b[1] + 0
  ms = b[2] + 0
  return (((h * 60) + m) * 60 + s) * 1000 + ms
}

/^[0-9]+$/ { next }

/-->/ {
  split($0, parts, " --> ")
  start_ms = to_ms(parts[1])
  text = ""

  while (getline line) {
    if (line == "") {
      break
    }
    if (text != "") {
      text = text " "
    }
    text = text line
  }

  gsub(/\t/, " ", text)
  if (length(text) > 0) {
    print start_ms "\t" text
  }
}

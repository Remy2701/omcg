import gleam/float
import gleam/int
import gleam/string

pub fn render(name: String) {
  let padding = int.to_float(76 - string.length(name)) /. 2.0

  "//"
  <> string.repeat("-", 76)
  <> "//"
  <> "\n"
  <> "//"
  <> string.repeat(" ", float.round(float.floor(padding)))
  <> string.capitalise(name)
  <> string.repeat(" ", float.round(float.ceiling(padding)))
  <> "//"
  <> "\n"
  <> "//"
  <> string.repeat("-", 76)
  <> "//"
}

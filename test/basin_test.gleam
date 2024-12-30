import basin
import gleam/io
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

pub type SomeResource {
  SomeResource
}

// gleeunit test functions end in `_test`
pub fn single_use_test() {
  let b = basin.new(1000, fn() { SomeResource })
  use resource <- b.then()

  io.debug(resource)
}

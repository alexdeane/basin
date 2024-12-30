import basin
import gleam/erlang/process
import gleam/function
import gleam/io
import gleam/list
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

pub fn nested_next_calls_should_create_multiple_instances() {
  use test_basin <- basin.new(1000, fn() {
    io.debug("used")
    Nil
  })

  let get_resource = fn() {
    use r <- basin.next(test_basin)
    r
  }

  let assert Ok(resource) = get_resource()
  let assert Ok(resource) = get_resource()
  let assert Ok(resource) = get_resource()

  Nil
}

pub fn flat_next_calls_should_reuse_instances() {
  use test_basin <- basin.new(1000, fn() {
    io.debug("used")
    Nil
  })

  let r1 = basin.next(test_basin, function.identity)
  let r2 = basin.next(test_basin, function.identity)
  let r3 = basin.next(test_basin, function.identity)

  Nil
}

pub type SomeResource {
  SomeResource(Int)
}

pub fn basin_should_reuse_single_instance() {
  use test_basin <- basin.new(1000, fn() { SomeResource })
  use resource <- basin.next(test_basin)

  should.equal(resource, SomeResource)
}

pub fn basin_should_dispose() {
  let test_basin = {
    use test_basin <- basin.new(1000, fn() { SomeResource })

    let assert Ok(resource) = {
      use r <- basin.next(test_basin)
      r
    }
    let assert Ok(resource) = {
      use r <- basin.next(test_basin)
      r
    }
    let assert Ok(resource) = {
      use r <- basin.next(test_basin)
      r
    }

    test_basin
  }

  let assert Error(basin.ProcessCallError(e)) = {
    use r <- basin.next(test_basin)
    r
  }

  io.debug(e)
  Nil
}

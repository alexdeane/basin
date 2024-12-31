import basin
import gleam/function
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

pub type SomeResource {
  SomeResource(Int)
}

pub fn flat_next_calls_should_reuse_instances_test() {
  use test_basin <- basin.new(1000, fn() {
    // Would like this callback to instead be able to
    // increment an integer or at least SOMEHOW affect something
    // stateful in the outer scope that I could leverage to ensure
    // the initializer fn was only invoked once
    SomeResource(3)
  })

  let assert Ok(r1) = basin.next(test_basin, function.identity)
  let assert Ok(r2) = basin.next(test_basin, function.identity)
  let assert Ok(r3) = basin.next(test_basin, function.identity)

  // This won't work because the value is the same
  should.not_equal(r1, r2)
  should.not_equal(r1, r3)
  should.not_equal(r2, r3)
}

pub fn nested_next_calls_should_create_multiple_instances_test() {
  use test_basin <- basin.new(1000, fn() { SomeResource(3) })

  use r1 <- basin.next(test_basin)
  use r2 <- basin.next(test_basin)
  use r3 <- basin.next(test_basin)

  // This won't work because the value is the same
  should.not_equal(r1, r2)
  should.not_equal(r1, r3)
  should.not_equal(r2, r3)
}

pub fn basin_should_use_single_instance_test() {
  use test_basin <- basin.new(1000, fn() { SomeResource(3) })
  use resource <- basin.next(test_basin)

  should.equal(resource, SomeResource(3))
}

pub fn basin_should_dispose_after_callback_test() {
  let test_basin = basin.new(1000, fn() { SomeResource }, function.identity)

  let assert Error(basin.ProcessCallError(_)) = {
    use r <- basin.next(test_basin)
    r
  }
}

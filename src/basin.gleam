import gleam/erlang/process.{type Subject}
import gleam/list
import gleam/otp/actor

pub type Basin(resource, a) {
  Basin(then: fn(fn(resource) -> a) -> a)
}

type ProvisionedResource(resource) {
  Owned(resource, owner: Subject(resource))
  Free(resource)
}

type Message(resource) {
  Shutdown
  Acquire(client: Subject(resource))
  Release(resource: resource)
}

// type PoolState(resource) {
//   PoolState(resources: List(ProvisionedResource(resource)))
// }

pub fn new(idle_lifetime: Int, initializer: fn() -> resource) {
  let assert Ok(pool) = actor.start([], create_pool_handler(initializer))
  // let assert Ok(janitor) = actor.start([], create_janitor(idle_lifetime, pool))

  Basin(fn(callback) { use_resource(pool, callback) })
}

fn use_resource(
  pool: Subject(Message(resource)),
  callback: fn(resource) -> a,
) -> a {
  // Acquire
  let resource = process.call(pool, Acquire, 10)

  // Use
  let res = callback(resource)

  // Release
  process.send(pool, Release(resource))

  res
}

fn create_janitor() {
  todo
}

fn create_pool_handler(initializer: fn() -> resource) {
  fn(message: Message(resource), state: List(ProvisionedResource(resource))) -> actor.Next(
    Message(resource),
    List(ProvisionedResource(resource)),
  ) {
    case message {
      Shutdown -> actor.Stop(process.Normal)
      Release(resource) -> {
        let pop_result =
          state
          |> list.pop(fn(r) {
            case r {
              Owned(r, _) -> r == resource
              _ -> False
            }
          })

        case pop_result {
          Error(Nil) -> actor.continue(state)
          Ok(#(pr, rest)) -> {
            let assert Owned(resource, _) = pr
            // pr.owner.send(Ok(pr.resource))
            actor.continue([Free(resource), ..rest])
          }
        }
      }
      Acquire(client) -> {
        let pop_result =
          state
          |> list.pop(fn(r) {
            case r {
              Free(_) -> True
              _ -> False
            }
          })

        let #(resource, rest) = case pop_result {
          Ok(#(Free(resource), rest)) -> #(resource, rest)
          _ -> #(initializer(), state)
        }

        // Send to client
        process.send(client, resource)

        // Continue
        actor.continue([Owned(resource, client), ..rest])
      }
    }
  }
}

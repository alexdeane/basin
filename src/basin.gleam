import gleam/erlang/process.{type Subject}
import gleam/list
import gleam/otp/actor

pub opaque type Basin(resource, a) {
  Basin(
    // next: fn(fn(resource) -> a) -> a,
    pool: Subject(Message(resource)),
    //  janitor: Subject(JanitorMessage(resource))
  )
}

pub type BasinError(resource) {
  ProcessCallError(call_error: process.CallError(resource))
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

pub fn next(
  basin: Basin(resource, a),
  resource_callback: fn(resource) -> a,
) -> Result(a, BasinError(resource)) {
  use_resource(basin.pool, resource_callback)
}

pub fn new(
  idle_lifetime: Int,
  initializer: fn() -> resource,
  usage: fn(Basin(resource, b)) -> a,
) -> a {
  let assert Ok(pool) = actor.start([], create_pool_handler(initializer))
  // let assert Ok(janitor) = actor.start([], create_janitor(idle_lifetime, pool))

  let result = usage(Basin(pool))

  // shut down the actor
  process.send(pool, Shutdown)

  result
}

fn use_resource(
  pool: Subject(Message(resource)),
  callback: fn(resource) -> a,
) -> Result(a, BasinError(resource)) {
  // Acquire
  case process.try_call(pool, Acquire, 10) {
    Ok(resource) -> {
      // Use
      let res = callback(resource)

      // Release
      process.send(pool, Release(resource))

      Ok(res)
    }
    Error(call_error) -> Error(ProcessCallError(call_error))
  }
}

fn create_janitor(idle_lifetime, pool) {
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

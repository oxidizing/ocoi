let%lwt conn = Db.connection

let example_todo =
  let open Models.Todo in
  {id = 1; title = "Do some example thing 7"; completed = false}

let create ~title ~completed = Queries.Todo.create conn ~title ~completed

module Rud : Ocoi.Controllers.Rud = struct
  include Models.Todo

  let index () = Queries.Todo.all conn

  let show id = Queries.Todo.show conn id

  let update {id; title; completed} =
    Queries.Todo.update conn {id; title; completed}

  let destroy id = Queries.Todo.destroy conn id
end

let create_example () =
  Queries.Todo.create conn ~title:"DB example" ~completed:false

let do_migration () = Models.Todo_migration_queries.migrate conn
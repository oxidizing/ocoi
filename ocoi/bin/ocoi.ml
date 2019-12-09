open Core

let generate_queries =
  (* TODO - fill out readmes *)
  Command.basic ~summary:"Generate CRUD DB code for a model"
    Command.Let_syntax.(
      let%map_open model_path = anon ("model_path" %: Filename.arg_type) in
      fun () ->
        let tree = Codegen.load_tree ~model_path in
        Db_codegen.write_queries ~model_path ~tree;
        Migrations_codegen.write_migration_scripts ~model_path)

let generate_controller =
  Command.basic ~summary:"Generate CRUD controller code for a model"
    Command.Let_syntax.(
      let%map_open model_path = anon ("model_path" %: Filename.arg_type) in
      fun () ->
        let tree = Codegen.load_tree ~model_path in
        Controller_codegen.write_controller ~model_path ~tree)

let generate_scaffold =
  (* TODO - pluralise name *)
  Command.basic ~summary:"Generate CRUD controller and DB code for a model"
    ~readme:(fun () ->
      "Currently just does `ocoi generate queries` and `ocoi generate \
       controller`.")
    Command.Let_syntax.(
      let%map_open model_path = anon ("model_path" %: Filename.arg_type) in
      fun () ->
        let tree = Codegen.load_tree ~model_path in
        Db_codegen.write_queries ~model_path ~tree;
        Migrations_codegen.write_migration_scripts ~model_path;
        Controller_codegen.write_controller ~model_path ~tree)

let generate =
  Command.group ~summary:"Generate various kinds of code"
    [
      ("queries", generate_queries);
      ("controller", generate_controller);
      ("scaffold", generate_scaffold);
    ]

let new_ =
  Command.basic ~summary:"Create an empty project"
    Command.Let_syntax.(
      let%map_open name = anon ("name" %: Filename.arg_type) in
      (* TODO - sanitise name *)
      fun () ->
        let template_directory_name =
          FilePath.concat
            ("ocoi" |> FileUtil.which |> FilePath.dirname)
            "../share/ocoi/project_template"
        in
        FileUtil.cp ~recurse:true [ template_directory_name ] name)

let migrate =
  Command.basic ~summary:"Run DB migrations for a model"
    ~readme:(fun () ->
      "This should be called from the root project directory (the one \
       containing `app`). It just builds and runs the relevant file in \
       `app/db/migrate`.")
    Command.Let_syntax.(
      let%map_open name = anon ("model" %: Filename.arg_type) in
      (* TODO - check if file exists *)
      fun () ->
        let _ =
          Sys.command
            (Printf.sprintf "dune exec -- ./app/db/migrate/%s_migrate.exe" name)
        in
        ())

let rollback =
  Command.basic ~summary:"Run DB rollback for a model"
    ~readme:(fun () ->
      "This should be called from the root project directory (the one \
       containing `app`). It just builds and runs the relevant file in \
       `app/db/migrate`.")
    Command.Let_syntax.(
      let%map_open name = anon ("model" %: Filename.arg_type) in
      (* TODO - check if file exists *)
      fun () ->
        let _ =
          Sys.command
            (Printf.sprintf "dune exec -- ./app/db/migrate/%s_rollback.exe"
               name)
        in
        ())

let db =
  Command.group ~summary:"Run DB migrations or rollbacks"
    [ ("migrate", migrate); ("rollback", rollback) ]

let server =
  Command.basic ~summary:"Run an OCOI app, rebuilding when files are changed"
    ~readme:(fun () ->
      "aaaaaaThis should be called from the root project directory (the one \
       containing `app`). It uses `main.ml` as an entry point. It is \
       implemented by rerunning `dune exec -- ./app/main.exe` when inotifywait \
       detects changes.")
    (Command.Param.return (fun () ->
         let () = print_endline "Starting server" in
         let server = Server.start_server () in
         (* TODO - optimise inotifywait command (e.g. limit to certain file types) *)
         (* FIXME - sometimes it seem to watch the _build directory even though it should be excluded *)
         let watch_args =
           [
             "-mr";
             "-e";
             "modify";
             "-e";
             "attrib";
             "-e";
             "close_write";
             "-e";
             "moved_to";
             "-e";
             "moved_from";
             "-e";
             "create";
             "-e";
             "delete";
             "-e";
             "delete_self";
             "@./_build/";
             ".";
           ]
         in
         let watchtool_output =
           (Unix.create_process ~prog:"inotifywait" ~args:watch_args).stdout
         in
         (* TODO - ensure spawned processes are nicely cleaned up when killed *)
         Lwt_main.run
           (* TODO - make 2 second maximum restart frequency configurable *)
           (Server.restart_on_change ~server ~watchtool_output ~freq:2.0)))

let command =
  Command.group ~summary:"Run OCOI commands"
    [ ("generate", generate); ("new", new_); ("server", server); ("db", db) ]

let () = Command.run command

open Mysql_example

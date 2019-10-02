open Core

(** Read lines indefinitely from an in_channel, displaying `f line` for each
 * and then `channel_finished` if/when the channel is closed. *)
let rec display_lines ic ~f ~channel_finished =
  let () = print_endline "YOYOYO" in
  let%lwt () = Lwt_io.printl "Test lwt printio" in
  match%lwt Lwt_io.read_line_opt ic with
  | Some s ->
      let%lwt () = Lwt_io.printl "!!! inside" in
      let () = print_endline "PROGAM MESSAGE" in
      let () = print_endline (f s) in
      display_lines ic ~f ~channel_finished
  | None -> print_endline channel_finished |> Lwt.return

let kill process =
  let pid = process.Unix.Process_info.pid in
  (* Redirect stderr to stdout so it is captured rather than printed *)
  let status =
    Printf.sprintf "kill %d 2>&1" (Pid.to_int pid)
    (* TODO - determine if this is the best way of running a process *)
    |> Unix.open_process
    |> Unix.close_process
  in
  (* TODO - log something if run in verbose mode *)
  match status with Ok () -> () | Error _ -> ()

(** Asynchronously wait until a process terminates and then do something based on the result. *)
let watch_for_server_end process ~f =
  let task () =
    let%lwt () = Lwt_io.printl "???" in
    let result =
      match%lwt
        Lwt_unix.waitpid [] (Pid.to_int process.Unix.Process_info.pid)
      with
      | 0, _ -> f None
      | i, _ -> f (Some i)
    in
    result
  in
  Lwt.async task

(** Asynchronously call display_lines on a file descriptor, for instance stdout or stderr of a process *)
let watch_file_descr_output descr ~f ~channel_finished =
  let descr = descr |> Lwt_unix.of_unix_file_descr in
  let ic = Lwt_io.(of_fd ~mode:input descr) in
  let () =
    Lwt.async (fun () -> display_lines ic ~f ~channel_finished |> Lwt.return)
  in
  print_endline "t"

let start_server () =
  let result =
    Lwt_process.open_process_full ("dune", [|"exec"; "--"; "./main.exe"|])
  in
  let () = print_endline "aaa" in
  let () =
    watch_file_descr_output result.stdout
      ~f:(fun s -> "STDOUT: " ^ s)
      ~channel_finished:"STDOUT closed"
  in
  let () = print_endline "bbb" in
  let () =
    watch_file_descr_output result.stderr
      ~f:(fun s -> "STDERR: " ^ s)
      ~channel_finished:"STDERR closed"
  in
  let () = print_endline "ccc" in
  let () =
    watch_for_server_end result ~f:(fun x ->
        let () =
          match x with
          | None -> print_endline "Finished successfully!"
          | Some _ -> print_endline "Finished with error!"
        in
        Lwt.return ())
  in
  let () = print_endline "ddd" in
  let () = Lwt.async (fun () -> Lwt_io.printl "test Lwt.async") in
  result

let restart_server server =
  let () = kill server in
  let () = print_endline "Server killed" in
  let new_server = start_server () in
  let () = print_endline "Server started" in
  new_server

let restart_on_change server fswatch_output freq =
  let rec restart_on_change_after restart_time server =
    match In_channel.input_line fswatch_output with
    | Some s -> (
        let current_time = Unix.time () in
        match current_time >= restart_time with
        | true ->
            let () = Printf.printf "Restarting server, reason: %s\n" s in
            let new_server = restart_server server in
            restart_on_change_after (current_time +. freq) new_server
        | false ->
            (* let () = print_endline "not restarting yet" in*)
            restart_on_change_after restart_time server )
    | None -> failwith "Unexpected end of input channel!"
  in
  let () = Lwt_main.run (Lwt_io.printl "Lwt main") in
  restart_on_change_after 0.0 server

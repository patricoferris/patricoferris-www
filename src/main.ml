let schedule = Current_cache.Schedule.v ~valid_for:(Duration.of_day 7) ()

let () =
  Fmt_tty.setup_std_outputs ();
  Logs.set_level (Some Info);
  Logs.set_reporter (Logs_fmt.reporter ());
  ()

let watcher = Current_sesame.Watcher.create ()

let dst = Current.state_dir "files"

let unikernel = Current.state_dir "unikernel"

let pipeline b_unikernel dev () =
  let db = Db.load dev in
  let c =
    Post.Fetch.get ~watcher ~label:"fetching collection"
      ~path:(Some (Fpath.v "posts"))
      db
  in
  let htmls =
    Post.Html.build ~label:"building html" c
    |> Current.map (fun hs ->
           List.map
             (fun { Post.H.path; html } ->
               (Fpath.(dst // Sesame.Utils.filename_to_html (v path)), html))
             hs)
  in
  let html =
    Current.map (fun () -> dst)
    @@ Current.all [ Current_sesame.Local.save_list htmls ]
  in
  let mirage base html =
    let cp =
      Current.all_labelled
        [
          ( "copy unipi",
            Copy.cp ~label:"unipi"
              ~src:(Current.return @@ Fpath.v "./unipi")
              unikernel );
          ("copy site", Copy.cp ~label:"website" ~src:html unikernel);
        ]
    in
    let build =
      Current.bind
        ~info:(Current.component "build unikernel")
        (fun () -> Mirage.build ~base ~out:(Current.return unikernel) dev)
        cp
    in
    Mirage.run_unikernel build
  in
  if b_unikernel then
    let base = Current_docker.Default.pull ~schedule "ocaml/opam" in
    mirage base html
  else Current.map (fun _ -> ()) html

let main unikernel dev =
  let open Lwt.Syntax in
  let engine = Current.Engine.create (pipeline unikernel dev) in
  let routes = Current_web.routes engine in
  let site =
    Current_web.Site.v ~name:"patricoferris.com pipeline"
      ~has_role:(fun _ _ -> true)
      routes
  in
  Lwt_main.run
    (let* { f; cond = reload; _ } =
       Current_sesame.Watcher.FS.watch ~watcher ~engine "data"
     in
     Lwt.choose
       ([
          Current.Engine.thread engine;
          Current_web.run ~mode:(`TCP (`Port 8081)) site;
        ]
       @
       if unikernel then []
       else
         [
           Lwt_result.ok @@ f ();
           Lwt_result.ok
           @@ Current_sesame.Server.dev_server ~port:8080 ~reload
                (Fpath.to_string dst);
         ]))

open Cmdliner

let dev =
  Arg.value @@ Arg.flag
  @@ Arg.info ~doc:"Run the development server" ~docv:"DEV"
       [ "d"; "development" ]

let unikernel =
  Arg.value @@ Arg.flag
  @@ Arg.info
       ~doc:"For development, this will build and run the unikernel locally"
       ~docv:"UNIKERNEL" [ "u"; "unikernel" ]

let cmd =
  let doc = "Current-sesame Pipeline" in
  ( Term.(term_result (const main $ unikernel $ dev)),
    Term.info "simple pipeline" ~doc )

let () = Term.(exit @@ eval cmd)

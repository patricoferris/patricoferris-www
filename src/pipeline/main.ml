let schedule = Current_cache.Schedule.v ~valid_for:(Duration.of_day 7) ()

let () =
  Fmt_tty.setup_std_outputs ();
  Logs.set_level (Some Info);
  Logs.set_reporter (Logs_fmt.reporter ());
  ()

let watcher = Current_sesame.Watcher.create ()

let dst = Current.state_dir "files"

let unikernel = Current.state_dir "unikernel"

let repo =
  { Current_github.Repo_id.owner = "patricoferris"; name = "patricoferris-www" }

let gcloud_deploy () =
  let project_id = Sys.getenv "GCLOUD_PROJECT_ID" in
  let credentials =
    Bos.OS.File.read (Fpath.v ".credentials") |> Rresult.R.get_ok
  in
  let config =
    {
      Gcloud.project_id;
      credentials;
      bucket = "patricoferris-www";
      image_name = "patricoferris-www";
      machine_type = `F1_micro;
      region = "europe-west1";
      zone = "europe-west1-b";
    }
  in
  Gcloud.deploy config

let drop_top_dir path =
  match Fpath.relativize ~root:(Fpath.v "./data") path with
  | Some p -> p
  | _ -> path

let post_path path =
  let f = Sesame.Path.last_dir_and_file (Fpath.v path) in
  Sesame.Utils.html_path f

let pipeline token b_unikernel deploy dev () =
  let db = Db.load dev in
  let posts =
    Post.Fetch.get ~watcher ~label:"fetching posts"
      ~path:(Some (Fpath.v "posts"))
      db
  in
  let drafts_and_posts =
    Current.map
      (List.partition (fun p ->
           match p.Post_intf.C.meta.draft with Some true -> true | _ -> false))
      posts
  in
  let htmls =
    Post.Html.build ~label:"building html" (Current.map snd drafts_and_posts)
    |> Current.map (fun hs ->
           List.map
             (fun { Post.H.path; html } ->
               (Fpath.(dst / "posts" // post_path path), html))
             hs)
  in
  let drafts =
    Post.Html.build ~label:"building html" (Current.map fst drafts_and_posts)
    |> Current.map (fun hs ->
           List.map
             (fun { Post.H.path; html } ->
               (Fpath.(dst / "posts" / "drafts" // post_path path), html))
             hs)
  in
  let pages =
    Current.bind
      ~info:(Current.component "index page")
      (fun posts ->
        Current.return
          [
            ( Fpath.(dst / "index.html"),
              Home_template.page (List.sort Post.compare posts) );
          ])
      (Current.map snd drafts_and_posts)
  in
  let html =
    Current.map (fun () -> dst)
    @@ Current.all
         [
           Current_sesame.Local.save_list ~create_dirs:true htmls;
           Current_sesame.Local.save_list ~create_dirs:true drafts;
           Current_sesame.Local.save_list ~create_dirs:true pages;
           Copy.cp ~label:"assets"
             ~src:(Current.return Fpath.(v "data" / "assets"))
             dst;
           Copy.cp ~label:"js" ~src:(Current.return Fpath.(v "data" / "js")) dst;
           Copy.cp ~label:"css"
             ~src:(Current.return Fpath.(v "data" / "css" / "main.css"))
             dst;
         ]
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
    if dev then
      let build =
        Current.bind
          ~info:(Current.component "site + unipi")
          (fun _ -> Mirage.build ~base ~out:(Current.return unikernel) dev)
          cp
      in
      Mirage.run_unikernel build
    else
      let deployment =
        if deploy then
          let build =
            Current.bind
              ~info:(Current.component "site + unipi")
              (fun _ -> Mirage.build ~base ~out:(Current.return unikernel) dev)
              cp
          in
          Current.bind
            ~info:(Current.component "gcloud deploy")
            (fun _ -> gcloud_deploy ())
            build
        else Current.ignore_value html
      in
      Current.bind
        (fun _ ->
          Git_live.update ~out:dst ~branch:"live" (Db.fetch_repo ~token repo))
        deployment
  in
  if b_unikernel then
    let base = Current_docker.Default.pull ~schedule "ocaml/opam" in
    mirage base html
  else Current.map (fun _ -> ()) html

let main token unikernel deploy dev =
  let open Lwt.Syntax in
  let engine = Current.Engine.create (pipeline token unikernel deploy dev) in
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

let deploy =
  Arg.value @@ Arg.flag
  @@ Arg.info ~doc:"Will deploy the unikernel" ~docv:"DEPLOY" [ "deploy" ]

let token =
  Arg.value
  @@ Arg.(opt (some file) None)
  @@ Arg.info ~doc:"Github token file" ~docv:"TOKEN" [ "t"; "token" ]

let cmd =
  let doc = "Current-sesame Pipeline" in
  ( Term.(term_result (const main $ token $ unikernel $ deploy $ dev)),
    Term.info "simple pipeline" ~doc )

let () = Term.(exit @@ eval cmd)

module Docker = Current_docker.Default

type backend = [ `Hvt | `Macos | `Unix ]

let backend_to_string = function
  | `Hvt -> "hvt"
  | `Macos -> "macos"
  | `Unix -> "unix"

let dockerfile ~base ~backend _out =
  let open Dockerfile in
  from (Docker.Image.hash base)
  @@ run "opam install mirage -y"
  @@ workdir "/home/opam"
  @@ copy ~chown:"opam" ~src:[ "./unikernel" ] ~dst:"./unikernel" ()
  @@ workdir "/home/opam/unikernel/unipi"
  @@ run "opam exec -- mirage configure -t %s" (backend_to_string backend)
  @@ run "make depends"
  @@ run "opam exec -- make build"

let build ~out ~base dev =
  let backend = if dev then `Macos else `Hvt in
  let open Current.Syntax in
  let dockerfile =
    let+ base = base and+ out = out in
    `Contents (dockerfile ~base ~backend out)
  in
  Docker.build ~dockerfile ~pull:false (`Dir out)

let run_unikernel image =
  Docker.run ~label:"unikernel" ~run_args:[ "-p"; "8080:8080" ] image
    ~args:[ "/home/opam/unikernel/unipi/main.native"; "--port"; "8080" ]

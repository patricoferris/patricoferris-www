module Docker = Current_docker.Default

type backend = [ `Hvt | `Macos | `Unix | `Virtio ]

let backend_to_string = function
  | `Hvt -> "hvt"
  | `Macos -> "macos"
  | `Unix -> "unix"
  | `Virtio -> "virtio"

let dockerfile ~opts ~base ~backend dev =
  let open Dockerfile in
  from (Docker.Image.digest base)
  @@ run "opam install mirage -y"
  @@ workdir "/home/opam"
  @@ copy ~chown:"opam" ~src:[ "./unikernel" ] ~dst:"./unikernel" ()
  @@ workdir "/home/opam/unikernel/unipi"
  @@ run "opam exec -- mirage configure -t %s %s"
       (backend_to_string backend)
       opts
  @@ run "make depends"
  @@ run "opam exec -- make build"
  @@ run
       (if dev then "echo done"
       else
         "sudo apt-get update && sudo apt-get install syslinux dosfstools \
          libseccomp-dev -y && opam exec -- solo5-virtio-mkimage -f tar \
          unipi.tar.gz unipi.virtio")

let build ~out ~base dev =
  let backend = if dev then `Macos else `Virtio in
  (* TODO: make this nicer *)
  let opts =
    if dev then ""
    else "--dhcp true --tls true --production true --hostname patricoferris.com"
  in
  let open Current.Syntax in
  let dockerfile =
    let+ base = base in
    `Contents (dockerfile ~opts ~base ~backend dev)
  in
  let build = Docker.build ~dockerfile ~pull:false (`Dir out) in
  let tag = Docker.tag ~tag:"unikernel-image" build in
  Current.bind ~info:(Current.component "unikernel image") (fun () -> build) tag

let run_unikernel image =
  Docker.run ~label:"unikernel" ~run_args:[ "-p"; "8080:8080" ] image
    ~args:[ "/home/opam/unikernel/unipi/main.native"; "--port"; "8080" ]

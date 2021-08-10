(* Abstract over a Git repository for production and a file path
   for development *)
module Github = Current_github

type t =
  [ `Commit of Current_git.Commit.t Current.t | `Fpath of Fpath.t Current.t ]

let fetch_repo ~token repo =
  match token with
  | Some token ->
      let token = Bos.OS.File.read (Fpath.v token) |> Rresult.R.get_ok in
      let head = Github.Api.head_commit (Github.Api.of_oauth token) repo in
      Current_git.fetch (Current.map Github.Api.Commit.id head)
  | None -> failwith "Using git + github requires a token"

let load ?token:_ _dev : t =
  (*if dev then *) `Fpath (Current.return Fpath.(v "./data"))
(* else
   `Commit
     (fetch_repo ~token
        {  }) *)

module Make (T : Sesame.Types.S with type Input.t = Fpath.t) = struct
  module Git_C = Git.Make (T)
  module Fpath_C = Current_sesame.Make_watch (T)

  let get ?watcher ~label ~path (repo : t) =
    let append a b = match a with Some a -> Fpath.(b // a) | None -> b in
    match repo with
    | `Commit commit -> Git_C.get ~label path commit
    | `Fpath fpath ->
        Fpath_C.build ?watcher ~label (Current.map (append path) fpath)
end

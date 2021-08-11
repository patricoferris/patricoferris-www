module Git = Current_git

module Builder = struct
  type t = No_context

  let auto_cancel = true

  let id = "copy"

  module Key = struct
    type t = { out : Fpath.t; repo : Git.Commit.t; branch : string }

    let digest { out; branch } =
      Yojson.Safe.to_string
        (`Assoc
          [ ("out", `String (Fpath.to_string out)); ("branch", `String branch) ])
  end

  let pp ppf { Key.out; branch } =
    Fmt.pf ppf "copy %a to %s" Fpath.pp out branch

  module Value = Current.Unit

  let build No_context job { Key.out; repo; branch } =
    let open Lwt.Infix in
    Current.Job.start job ~level:Current.Level.Harmless >>= fun () ->
    Git.with_checkout ~job repo @@ fun dst ->
    Current.Process.exec ~cwd:dst ~cancellable:true ~job
      ("", [| "git"; "checkout"; branch |])
    >>= fun _ ->
    (* Should be able to turn off submodule checkout *)
    Current.Process.exec ~cwd:dst ~cancellable:true ~job
      ("", [| "rm"; "-rf"; "hilite"; "unipi" |])
    >>= fun _ ->
    Current.Process.exec ~cwd:dst ~cancellable:true ~job
      ("", [| "cp"; "-a"; Fpath.to_string out ^ "/"; Fpath.to_string dst |])
    >>= fun _ ->
    Current.Process.exec ~cwd:dst ~cancellable:true ~job
      ("", [| "git"; "add"; "." |])
    >>= fun _ ->
    Current.Process.exec ~cwd:dst ~cancellable:true ~job
      ("", [| "git"; "commit"; "-m"; "update live site" |])
    >>= fun _ ->
    Current.Process.exec ~cwd:dst ~cancellable:true ~job
      ("", [| "git"; "push" |])
end

module GC = Current_cache.Make (Builder)

let update ~out ~branch repo =
  let open Current.Syntax in
  Current.component "git live"
  |> let> repo = repo in
     GC.get ?schedule:None No_context { out; repo; branch }

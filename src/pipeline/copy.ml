module Builder = struct
  type t = No_context

  let auto_cancel = true

  let id = "copy"

  module Key = struct
    type t = Fpath.t * Fpath.t

    let digest (src, dst) = Fpath.to_string src ^ " " ^ Fpath.to_string dst
  end

  let pp ppf (src, dst) = Fmt.pf ppf "copy %a to %a" Fpath.pp src Fpath.pp dst

  module Value = Current.Unit

  let build No_context job (src, dst) =
    let open Lwt.Infix in
    Current.Job.start job ~level:Current.Level.Harmless >>= fun () ->
    Current.Process.exec ~cancellable:true ~job
      ("", [| "cp"; "-a"; Fpath.to_string src; Fpath.to_string dst |])
end

module GC = Current_cache.Make (Builder)

let cp ?(label = "") ~src dst =
  let open Current.Syntax in
  Current.component "copy %s" label
  |> let> src = src in
     GC.get ?schedule:None No_context (src, dst)

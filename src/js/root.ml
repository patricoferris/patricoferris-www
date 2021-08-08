(* Setting some CSS for dark-mode *)
open Brr
open Theme

let dark_mode = "dark-mode"

let str = Jstr.of_string

let () =
  let store = Store.storage () in
  match Store.get store dark_mode with
  | Some t ->
      let dark = bool_of_string (Jstr.to_string t) in
      let root = Document.root G.document in
      if dark then Css.set_dark root else Css.set_light root
  | None ->
      let root = Document.root G.document in
      Css.set_light root

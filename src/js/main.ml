(* A little JS script for toggling the light/dark mode *)
open Brr
open Theme

let str = Jstr.of_string

let dark_mode = "dark-mode"

let js_dark_mode = str dark_mode

let set_class b cl el = El.set_class cl b el

let store = Store.storage ()

let check_dark_mode () =
  let open Brr_io in
  match Storage.(get_item store js_dark_mode) with
  | Some t -> bool_of_string (Jstr.to_string t)
  | None -> false

let handler txt_changer _ =
  let body = Document.body G.document in
  let b = check_dark_mode () in
  if not b then Css.set_dark body else Css.set_light body;
  txt_changer (not b);
  Store.set store dark_mode (string_of_bool (not b)) |> Store.handle ()

let () =
  match Document.find_el_by_id G.document (Jstr.of_string "toggle") with
  | Some b -> Ev.(listen click (handler (Theme.txt_changer b)) (El.as_target b))
  | None -> Console.(log [ Jstr.of_string "No toggle button" ])

open Sesame

module H = struct
  include Sesame.Collection.Html (Post_intf.Meta)

  let build (t : Post_intf.C.t) =
    let omd = t.body |> Omd.of_string |> Hilite.Md.transform in
    let html =
      Layout.html ~title:t.meta.title ~description:t.meta.description
        ~body:(Post_template.render t @@ (Omd.to_html omd))
    in
    Lwt_result.return { path = t.path; html }
end

let compare (a : Post_intf.C.t) (b : Post_intf.C.t) =
  let date_to_int d = String.split_on_char '-' d |> String.concat "" |> int_of_string in
  Int.compare (date_to_int b.meta.date) (date_to_int a.meta.date)

module Fetch = Db.Make (Utils.Dir (Post_intf.C))
module Html = Current_sesame.Make (Utils.List (H))

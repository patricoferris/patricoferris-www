open Sesame

module H = struct
  include Sesame.Collection.Html (Post_intf.Meta)

  let build (t : Post_intf.C.t) =
    let html =
      Layout.html ~title:t.meta.title ~description:t.meta.description
        ~body:(Post_template.render t @@ t.body |> Omd.of_string |> Omd.to_html)
    in
    Lwt_result.return { path = t.path; html }
end

module Fetch = Db.Make (Utils.Dir (Post_intf.C))
module Html = Current_sesame.Make (Utils.List (H))

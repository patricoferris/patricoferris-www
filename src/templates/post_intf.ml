module Meta = struct
  type reading = { name : string; description : string; url : string }
  [@@deriving yaml]

  type t = {
    title : string;
    description : string;
    date : string;
    authors : string list;
    topics : string list;
    reading : reading list;
  }
  [@@deriving yaml]
end

module C = Sesame.Collection.Make (Meta)

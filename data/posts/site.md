---
title: An Incremental, Unikernel-deploying Website Pipeline
description: A detailed look at how you are able read this description. 
date: 2021-08-08
authors: 
  - Patrick Ferris
topics:
  - mirage
  - ocurrent
  - ocaml
reading: []
---

It took me a whole year to get this very modest looking website off the ground. But here 
we are with something reasonably stable and functional. In short this site uses [current-sesame](https://github.com/patricoferris/sesame)
to build pages from markdown, yaml (or really any data source you write a `Sesame.S` for).
The pipeline collects the output and then bundles it in to a customised [unipi MirageOS unikernel](https://github.com/robur/unipi). The rest 
of this post has a look at some of the interesting features and challenges I faced.

<img width="100%" alt="An OCurrent pipeline showing the information flow for this website. First the HTML is built, then the unikernel before deploying it" src="/assets/pipeline.png" />

## Sesame

[Sesame](https://github.com/patricoferris/sesame) is a very simple static site generator. It is essentially
a series of transformations (as all site generation tools tend to be). The main transformation is from
a "jekyll format" (yaml metadata and markdown) to HTML, something Sesame calls a `Collection`.

```ocaml
module Meta = struct
    type t = { title : string }

    let of_yaml = 
      function `O [ "title", `String title ] -> Ok { title } | _ -> Error (`Msg "Failed")
    let to_yaml { title } = `O [ "title", `String title ]
  end
module C = Sesame.Collection.Make(Meta)
```

To make describing metadata easier, there's a [ppx for deriving the yaml functions](https://github.com/patricoferris/ppx_deriving_yaml).

Sesame is very much a work in progress, but it also supports (in a limited way) image optimisation by generating user-defined
resolutions and replacing uses of the images in markdown with a responsive image element using `srcset`s.

The syntax highlighting is not performed on your client but instead at build time as a simple transformation over [omd](https://github.com/ocaml/omd)
AST using [hilite](https://github.com/patricoferris/hilite). Sesame is really for building simple, light-weight websites. [The smallest front-end framework](https://medium.com/dailyjs/a-realworld-comparison-of-front-end-frameworks-2020-4e50655fe4c1) is the one that doesn't exist.

The site does contain a small amount of Javascript to do the light/dark mode toggling. It's written with [js_of_ocaml](https://github.com/ocsigen/js_of_ocaml) and [brr](https://erratique.ch/software/brr).

## Current-sesame

[Current-sesame](https://github.com/patricoferris/sesame) is the "OCurrent plugin" form of sesame. Functors are provided
to build pipeline stages that could for example read the filesystem and build collections.

The benefit of OCurrent is that are dependencies are now tracked i.e. we know how information flows in our site generation
graph. For example, some file `blog-post.md` is converted into a `Collection`, this collection is then passed through 
some HTML template, this `string` is then written to the filesystem.

Do bare in mind that you are not limited to the file-system. You can pull in anything from anywhere with current-sesame. The beauty
here is everything in your site happens at build time, **but** thanks to OCurrent you have a comprehensive monitoring system for free.
This means you could build READMEs from your Github projects into your site, monitor them with the Github webhook so when there's a change
your pipeline rebuilds and redeploys! [Check out the fake OCaml website](https://github.com/patricoferris/sesame/blob/main/example/ocaml/changes.ml), it does something similar I just didn't get around to adding the watching.

### A live-reloading development server

#### Watching Files

Thanks to the incremental pipeline, we can build a helpful live-reloading server on top of our website's information flow graph.
Current-sesame handles this with the `Current-sesame.Watcher` module. At the heart of Sesame is the `Sesame.S` module type which
describes a transformation from an `Input` type to an and `Output` type.

```ocaml
# #show Sesame.Types.S
module type S =
  sig
    module Input : Sesame.Types.Encodeable
    type t
    module Output :
      sig
        type t = t
        val encode : t -> string
        val decode : string -> t
        val pp : t Fmt.t
      end
    val build : Input.t -> (t, [ `Msg of string ]) Lwt_result.t
  end
```

This, it turns out, maps directly on to an OCurrent cache builder very seamlessly (in the OCurrent-world we have a `Key` and `Value`).

Anything that matches `Sesame.S with type Input.t = Fpath.t` is up for being watched. Being watched means the watcher records paths with
there OCurrent job identifiers. If the filesystem watcher notices a change to a file, then it looks up the job identifier for the path
and triggers a rebuild.

```ocaml
# #show Current_sesame.Make_watch
module Make_watch :
  functor
    (V : sig
           module Input :
             sig
               type t = Fpath.t
               val encode : t -> string
               val decode : string -> t
               val pp : t Fmt.t
             end
           type t
           module Output :
             sig
               type t = t
               val encode : t -> string
               val decode : string -> t
               val pp : t Fmt.t
             end
           val build : Input.t -> (t, [ `Msg of string ]) Lwt_result.t
         end)
    ->
    sig
      module C :
        sig
          val get :
            ?schedule:Current_cache.Schedule.t ->
            Current_sesame.Make_cache(Current_sesame.SesameInfo)(V).t ->
            Fpath.t -> V.t Current.Primitive.t
          val invalidate : Fpath.t -> unit
          val reset : db:bool -> unit
        end
      val build :
        ?watcher:(Fpath.t, string) Hashtbl.t ->
        ?label:string -> Fpath.t Current.term -> V.t Current.term
    end
```

#### Live-reloading

Rebuilding the HTML is only half the battle. The development server also has to force a client-side refresh in the browser. The watcher also
returns a `Lwt_condition.t` which is broadcast to when something changes. The development server (written with [dream](https://github.com/aantron/dream))
opens a websocket with the client and when the condition variable is broadcast to, it tells the client to re-render. Every HTML page the development
server sends is modified to include a little bit of javascript to listen on this websocket and refresh when told to.

## Unikernels

This isn't the post for explaining the wonderful world of [MirageOS unikernels](https://mirage.io). Instead just think of them as tiny executables with a 
small footprint. The pipeline for this website uses a modified version of the [unipi unikernel](https://github.com/roburio/unipi) from the good folk at [robur](https://robur.io/). The major benefit for me of reusing this unikernel is (1) it was built by more talented people than myself and (2) it does lets-encrypt certificate provisioning all by itself!

It's modified in a way that makes it substantially "less cool". Unipi uses [irmin](https://irmin.org) to pull a git repository and serve it over HTTP/HTTPS. For example,
you could take your Gatsby/Nextjs site, build it and push it to a branch and have unipi serve it. The modification I made was to remove all of irmin from the unikernel 
and convert it to using a plain old, [read-only mirage key-value store](https://github.com/patricoferris/unipi/tree/simple-kv).

### Unikernel in development

For testing it's useful to not only use current-sesame's development server but also go through the motions of building the unikernel. So between the pipeline's development
mode and production mode, there's a unikernel development mode. This builds the site as before, it also builds the git-submoduled, modified unipi unikernel inside a docker image thanks to [OCurrent's Docker plugin](https://v3.ocaml.org/p/current_docker/0.5). It builds the unikernel using the `unix` backend and then runs it without TLS.

### Unikernel in deployment

This site is deployed on Google Cloud. A priority of mine is to remove the dependency on Google and self-host this probably using [albatross](https://github.com/roburio/albatross).

Running the pipeline in production is very similar to the "unikernel in development" mode, except now at the end of the pipeline the unikernel is built using the `virtio` backend, bundled up by [solo5](https://github.com/Solo5/solo5) and deployed to an `f1-micro` instance on Google Cloud. For the interested reader you can take a look in the [gcloud.ml](https://github.com/patricoferris/patricoferris-www/blob/main/src/gcloud.ml) file. It essentially amounts to the following steps:

 1. Create a bucket and copy the `.tar.gz` unikernel to the bucket (the whole thing is only megabytes in size!)
 2. Create an image from this unikernel
 3. Deploy the instance with the right firewall rules, at the right address etc.

The majority of this "Google Cloud workflow" is thanks to [this blog post](https://www.riseos.com/blog/2016/09/13/continuously-deploying-mirage-unikernels-to-google-compute-engine-using-circle-ci.html) and help from [@dinosaure](https://twitter.com/Dinoosaure).


## What's next?

I'm pretty happy with the different bits of this workflow. There are definitely lots of rough corners:

 - Reduce the path mangling, there's quite a bit and there should be a better story in Sesame for the default paths
 - Image optimisation doesn't work as well as I want it too
 - Better caching strategy between OCurrent and Sesame
 - Self-host the unikernel
 - Editing the content... it would be nice to have a CMS based on the types Sesame understands

For me though, I think I'm going to let the site sit for a bit now that I can quite easily write new content and redeploy it. There's lot of other interesting OCaml projects
to do in the mean time.
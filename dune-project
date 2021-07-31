(lang dune 2.8)

(generate_opam_files true)

(package
 (name patricoferris)
 (synopsis "A personal website")
 (description "An ocurrent-powered, website pipeline using current-sesame and a modified unipi unikernel")
 (depends 
  current-sesame
  current_docker
  current_github
  dream
  ))
(* Deploy unikernels using gcloud... I'd rather deploy somewhere else :( *)
module Docker = Current_docker.Default

let gcloud_image = "gcr.io/google.com/cloudsdktool/cloud-sdk:latest"

type machine = [ `F1_micro ] [@@deriving to_yojson]

let machine_to_string = function `F1_micro -> "f1-micro"

type image = Docker.Image.t

let image_to_yojson t = `String (Docker.Image.hash t)

type t = {
  project_id : string;
  credentials : string;
  bucket : string;
  image_name : string;
  machine_type : machine;
  region : string;
  zone : string;
}
[@@deriving to_yojson]

let dockerfile (t : t) =
  let open Dockerfile in
  from gcloud_image
  @@ copy ~from:"unikernel-image"
       ~src:[ "/home/opam/unikernel/unipi/unipi.tar.gz" ]
       ~dst:"/unikernel.tar.gz" ()
  @@ run "gcloud config set project %s" t.project_id
  @@ run
       "echo \"%s\" | base64 -d > /tmp/account.json && gcloud auth \
        activate-service-account --key-file=/tmp/account.json"
       t.credentials
  @@
  let deploy_script =
    Fmt.str
      "gsutil rm gs://%s/unikernel.tar.gz && gsutil cp \
       unikernel.tar.gz gs://%s && gcloud compute images delete %s && gcloud compute images create %s \
       --source-uri gs://%s/unikernel.tar.gz && gcloud compute instances delete %s --zone %s && gcloud compute instances create %s --image %s \
       --address %s --zone %s --machine-type %s"
      t.bucket t.bucket t.image_name t.image_name t.bucket t.image_name t.zone
      t.image_name t.image_name t.image_name t.zone
      (machine_to_string t.machine_type)
  in
  run "echo \"%s\" > /deploy.sh && chmod +x ./deploy.sh" deploy_script

let deploy t =
  let dockerfile = Current.return (`Contents (dockerfile t)) in
  let image = Docker.build ~label:"unikernel" ~dockerfile ~pull:false `No_context in
    Docker.run ~label:" -- gcloud deploy" image ~args:[ "/bin/bash"; "-c"; "./deploy.sh" ]

# The `mimir` CLI and scheduler (Tn-mimir on Akmon, Tn-learning on Kvasir).
# Its tests run in the build, so `tn-check` exercises them.
#
# plImage is THE pinned PrairieLearn image: Tn-mimir runs it (passthru),
# and it's baked in so `mimir lint` and `mimir preview` on either host use
# exactly what Akmon runs. Upgrading PL = changing it here (then tn-check,
# deploy, and the post-deploy checks in the plan).
{ lib, python3Packages,
  plImage ? "docker.io/prairielearn/prairielearn:30424b04be9b30ccc52ca83f9ee2dd2125f1e93b@sha256:9f03a429d1b34a65972344721e7c7b2f9b30b217d40058a571e1860eb6f47f47" }:

let
  fsrs = python3Packages.callPackage ./fsrs.nix { };
in
python3Packages.buildPythonApplication {
  pname   = "mimir";
  version = "0.1.0";
  pyproject = true;

  src = lib.fileset.toSource {
    root    = ./.;
    fileset = lib.fileset.unions [ ./pyproject.toml ./mimir ./tests ];
  };

  build-system = [ python3Packages.setuptools ];
  dependencies = [ fsrs python3Packages.jsonschema ];
  nativeCheckInputs = [ python3Packages.pytestCheckHook ];

  makeWrapperArgs = [ "--set-default" "MIMIR_PL_IMAGE" plImage ];

  passthru = { inherit plImage; };
  meta.mainProgram = "mimir";
}

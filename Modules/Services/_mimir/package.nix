# The `mimir` CLI and scheduler (Tn-mimir on Akmon, Tn-learning on Kvasir).
# Its tests run in the build, so `tn-check` exercises them. plImage is the
# pinned PrairieLearn image, baked in so `mimir lint` and `mimir preview`
# on either host match what Akmon runs.
{ lib, python3Packages, plImage }:

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

  meta.mainProgram = "mimir";
}

# py-fsrs, the reference FSRS-6 scheduler (open-spaced-repetition), not in
# nixpkgs. Only the core: the optimizer extra pulls torch; Mimir fits its
# parameters later (phase 5) and can add it then.
{ buildPythonPackage, fetchPypi, setuptools, typing-extensions }:

buildPythonPackage rec {
  pname   = "fsrs";
  version = "6.3.2";
  pyproject = true;
  src = fetchPypi {
    inherit pname version;
    hash = "sha256-f+eZR865LKNf3KPfpRGiOb4VsxfN5j1mQ6LaYRCETZE=";
  };
  build-system = [ setuptools ];
  dependencies = [ typing-extensions ];
  doCheck = false;   # its test suite needs torch (the optimizer)
  pythonImportsCheck = [ "fsrs" ];
}

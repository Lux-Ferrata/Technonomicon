# `tts`: Kokoro text-to-speech, offline on the CPU. English (US/UK) and
# Mandarin. Weights and voices are pinned store paths (hexgrad/Kokoro-82M);
# misaki's Mandarin front end needs three small PyPI packages nixpkgs
# doesn't carry yet, built here.
{ lib, python3, fetchurl, linkFarm, makeWrapper, runCommand, pipewire }:
let
  rev = "f3ff3571791e39611d31c381e3a41a3af07b4987";
  hf = file: sha256: fetchurl {
    url  = "https://huggingface.co/hexgrad/Kokoro-82M/resolve/${rev}/${file}";
    name = baseNameOf file;
    inherit sha256;
  };
  kokoro = linkFarm "kokoro-82m" [
    { name = "config.json";     path = hf "config.json"     "5abb01e2403b072bf03d04fde160443e209d7a0dad49a423be15196b9b43c17f"; }
    { name = "kokoro-v1_0.pth"; path = hf "kokoro-v1_0.pth" "496dba118d1a58f5f3db2efc88dbdc216e0483fc89fe6e47ee1f2c53f18ad1e4"; }
    { name = "voices/af_heart.pt";   path = hf "voices/af_heart.pt"   "0ab5709b8ffab19bfd849cd11d98f75b60af7733253ad0d67b12382a102cb4ff"; }
    { name = "voices/am_michael.pt"; path = hf "voices/am_michael.pt" "9a443b79a4b22489a5b0ab7c651a0bcd1a30bef675c28333f06971abbd47bd37"; }
    { name = "voices/bf_emma.pt";    path = hf "voices/bf_emma.pt"    "d0a423deabf4a52b4f49318c51742c54e21bb89bbbe9a12141e7758ddb5da701"; }
    { name = "voices/zf_xiaobei.pt"; path = hf "voices/zf_xiaobei.pt" "9b76be63dab4f4f96962030acc0126a9aee9728608fbbe115e2b58a2bd504df6"; }
    { name = "voices/zm_yunxi.pt";   path = hf "voices/zm_yunxi.pt"   "dbe6e1ce7c3dbaf2f5667432947b638b1c6831ccbe154c4610dbcc44f431e27b"; }
  ];

  py = python3.override {
    packageOverrides = self: super: let
      pypi = pname: version: sha256: deps: self.buildPythonPackage {
        inherit pname version;
        pyproject = true;
        src = self.fetchPypi { inherit pname version sha256; };
        build-system = [ self.setuptools ];
        dependencies = deps;
        doCheck = false;
      };
    in {
      proces = pypi "proces" "0.1.7" "70a05d9e973dd685f7a9092c58be695a8181a411d63796c213232fd3fdc43775" [];
      cn2an  = pypi "cn2an" "0.5.24" "c276cfc4b3c9e758214841de597502eb178de50b8da2633ed345564f90705f0e" [ self.proces ];
      pypinyin-dict = pypi "pypinyin_dict" "0.9.0" "8c491396baa1567311f2ec759cbc154638f3bcefdc711d34e53e373e3a429fa5" [ self.pypinyin ];
    };
  };
  env = py.withPackages (ps: [ ps.kokoro ps.soundfile ps.spacy-models.en_core_web_sm
                               ps.cn2an ps.pypinyin-dict ]
                             ++ ps.misaki.optional-dependencies.zh);
in
runCommand "tts" { nativeBuildInputs = [ makeWrapper ]; meta.mainProgram = "tts"; } ''
  makeWrapper ${env}/bin/python $out/bin/tts \
    --add-flags ${./_tts.py} \
    --set KOKORO_DIR ${kokoro} \
    --set PYTHONWARNINGS ignore \
    --prefix PATH : ${lib.makeBinPath [ pipewire ]}
''

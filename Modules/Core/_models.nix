# Local LLM weights, pinned by HuggingFace revision + sha256 so they're
# ordinary store paths: built into the closure, cached by harmonia, and on
# Akmon they survive the root wipe because /nix does.
{ fetchurl }:
let
  hf = { repo, rev, file, sha256 }: fetchurl {
    url = "https://huggingface.co/${repo}/resolve/${rev}/${file}";
    name = file;
    inherit sha256;
  };
in {
  # Code completion (fill-in-the-middle). Base (not instruct) models: FIM
  # needs the raw infill tokens. Small on purpose -- it stays loaded, and
  # the rest of Akmon's 16 GB VRAM is for the chat model.
  fim-3b = hf {
    repo   = "ggml-org/Qwen2.5-Coder-3B-Q8_0-GGUF";
    rev    = "9c1de162ae417c9c3aacde97c729c4128de047d8";
    file   = "qwen2.5-coder-3b-q8_0.gguf";
    sha256 = "a522a906e299ed34db738b9626b2cd0da9e446c14674468a22fc2eae3dbd344d";
  };
  # Kvasir's offline fallback, on CPU
  fim-1_5b = hf {
    repo   = "ggml-org/Qwen2.5-Coder-1.5B-Q8_0-GGUF";
    rev    = "8be1b8a895a84beea772817caaa71eba6b6e0d07";
    file   = "qwen2.5-coder-1.5b-q8_0.gguf";
    sha256 = "29871c94d15727a6e243f79a37113d4ae625a6215b5e800bf41a23af2da32832";
  };
}

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
  # needs the raw infill tokens. The biggest that still fits Akmon's 16 GB
  # with its context, so it stays loaded and instant; chat loads on demand.
  fim-14b = hf {
    repo   = "bartowski/Qwen2.5-Coder-14B-GGUF";
    rev    = "0e179a81290a5e9b04bb1b4f1badf79bc880b261";
    file   = "Qwen2.5-Coder-14B-Q6_K.gguf";
    sha256 = "b7d035013a0570b7bc116ddf9dfc58d85d054869455c1c3d5a12f9ad3095be8b";
  };
  # Kvasir's offline fallback, on CPU
  fim-1_5b = hf {
    repo   = "ggml-org/Qwen2.5-Coder-1.5B-Q8_0-GGUF";
    rev    = "8be1b8a895a84beea772817caaa71eba6b6e0d07";
    file   = "qwen2.5-coder-1.5b-q8_0.gguf";
    sha256 = "29871c94d15727a6e243f79a37113d4ae625a6215b5e800bf41a23af2da32832";
  };

  # Chat / edit-selection / aider. MoE: 30B weights, ~3B active per token,
  # so it's quick even with the experts that don't fit in VRAM held in RAM
  # (llama.cpp --fit decides the split at start). Loaded on demand.
  chat-30b-a3b = hf {
    repo   = "unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF";
    rev    = "b17cb02dd882d5b6ab62fc777ad2995f19668350";
    file   = "Qwen3-Coder-30B-A3B-Instruct-UD-Q4_K_XL.gguf";
    sha256 = "2841aa314d916434860cfb8990347528dcdfe5c350dbcb9d1461dbee88ff2533";
  };
  # Kvasir's offline chat fallback, on CPU
  chat-3b = hf {
    repo   = "ggml-org/Qwen2.5-Coder-3B-Instruct-Q8_0-GGUF";
    rev    = "4944a3e9ecbaacda76873e9577d038400413772c";
    file   = "qwen2.5-coder-3b-instruct-q8_0.gguf";
    sha256 = "691c4400ab952b4196f667e01e521a48fe9571f0cb8e4a7f2cd084d07fd99d71";
  };

  # Speech to text (whisper.cpp). Multilingual, Mandarin included.
  # Akmon's GPU server: large-v3-turbo, 8-bit (~1 GB of VRAM)
  whisper-turbo = hf {
    repo   = "ggerganov/whisper.cpp";
    rev    = "5359861c739e955e79d9a303bcbc70fb988958b1";
    file   = "ggml-large-v3-turbo-q8_0.bin";
    sha256 = "317eb69c11673c9de1e1f0d459b253999804ec71ac4c23c17ecf5fbe24e259a1";
  };
  # Kvasir's offline fallback, on CPU
  whisper-base = hf {
    repo   = "ggerganov/whisper.cpp";
    rev    = "5359861c739e955e79d9a303bcbc70fb988958b1";
    file   = "ggml-base.bin";
    sha256 = "60ed5bc3dd14eea856493d334349b405782ddcaf0028d4b5df4088345fba2efe";
  };
}

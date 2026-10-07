"""tts: speak text with Kokoro (offline, CPU).

    tts "Hello there"            speak it
    echo "text" | tts            from stdin
    tts -o out.wav "text"        write a WAV instead of playing
    tts -v am_michael "text"     another voice (tts --voices lists them)
    tts --lang zh "你好"          Mandarin (auto-detected from the text too)

Weights and voices are store paths (KOKORO_DIR), so nothing is downloaded.
"""
import argparse
import os
import re
import subprocess
import sys
import tempfile

os.environ.setdefault("HF_HUB_OFFLINE", "1")
os.environ.setdefault("TRANSFORMERS_OFFLINE", "1")

KOKORO = os.environ["KOKORO_DIR"]
DEFAULT_VOICE = {"a": "af_heart", "b": "bf_emma", "z": "zf_xiaobei"}


def voices():
    return sorted(f[:-3] for f in os.listdir(os.path.join(KOKORO, "voices")))


def main():
    ap = argparse.ArgumentParser(prog="tts", description="Speak text with Kokoro.")
    ap.add_argument("text", nargs="*")
    ap.add_argument("-v", "--voice")
    ap.add_argument("-o", "--output", help="write a WAV file instead of playing")
    ap.add_argument("-s", "--speed", type=float, default=1.0)
    ap.add_argument("--lang", choices=["auto", "en", "en-gb", "zh"], default="auto")
    ap.add_argument("--voices", action="store_true", help="list voices")
    a = ap.parse_args()

    if a.voices:
        print("\n".join(voices()))
        return
    text = " ".join(a.text) if a.text else sys.stdin.read()
    if not text.strip():
        ap.error("no text")

    if a.lang == "auto":
        lang = "z" if re.search(r"[一-鿿]", text) else "a"
    else:
        lang = {"en": "a", "en-gb": "b", "zh": "z"}[a.lang]
    voice = a.voice or DEFAULT_VOICE[lang]
    if voice not in voices():
        ap.error(f"unknown voice {voice} (tts --voices)")

    # heavy imports only once there is something to say
    import numpy as np
    import soundfile as sf
    from kokoro import KModel, KPipeline

    model = KModel(repo_id="hexgrad/Kokoro-82M",
                   config=os.path.join(KOKORO, "config.json"),
                   model=os.path.join(KOKORO, "kokoro-v1_0.pth")).eval()
    pipe = KPipeline(lang_code=lang, repo_id="hexgrad/Kokoro-82M", model=model)
    chunks = [r.audio.numpy() for r in pipe(text, voice=os.path.join(KOKORO, "voices", voice + ".pt"),
                                             speed=a.speed) if r.audio is not None]
    if not chunks:
        sys.exit("tts: nothing to say")
    audio = np.concatenate(chunks)

    if a.output:
        sf.write(a.output, audio, 24000)
        return
    with tempfile.NamedTemporaryFile(suffix=".wav") as f:
        sf.write(f.name, audio, 24000)
        subprocess.run(["pw-play", f.name], check=True)


if __name__ == "__main__":
    main()

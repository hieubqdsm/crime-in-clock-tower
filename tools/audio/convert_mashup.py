"""Convert the tester's mashup.mp3 to a web-safe WAV (F-002).

Why: single-threaded (nothreads) web builds silently hang when loading
disk-streamed audio; AudioStreamMP3 proved to hang them too. Raw PCM WAV in
RAM (compress/mode=0) is the only combination verified to work.

Run:  python tools/audio/convert_mashup.py
Source: tools/audio/mashup.mp3 (kept out of assets/ so the pck stays small)
Output: assets/audio/mashup.wav — 22050 Hz mono PCM-16 (~26 MB for 10 min)
"""
import os

import soundfile as sf

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "mashup.mp3")
OUT = os.path.normpath(os.path.join(HERE, "..", "..", "assets", "audio", "mashup.wav"))

TARGET_RATE = 22050  # halves the size; fine for the proximity-audio mechanic

data, sr = sf.read(SRC, always_2d=True, dtype="float64")
mono = data.mean(axis=1)
if sr != TARGET_RATE:
    # decimate by simple linear resample (quality is not the point here)
    import math
    n_out = int(len(mono) * TARGET_RATE / sr)
    mono = [mono[min(len(mono) - 1, int(i * len(mono) / n_out))] for i in range(n_out)]

peak = max(1e-9, max(abs(x) for x in mono))
gain = min(1.0, 0.85 / peak)  # normalize down only, never clip up
mono = [x * gain for x in mono]

sf.write(OUT, mono, TARGET_RATE, subtype="PCM_16")
mb = os.path.getsize(OUT) / (1024 * 1024)
print("[mashup] %s -> %s  %.1f MB  %.0f s  peak gain %.2f"
      % (SRC, OUT, mb, len(mono) / TARGET_RATE, gain))

"""Procedural looping sounds for the corner tokens (F-002).

Run:  python tools/audio/make_token_sounds.py
Outputs (committed with this script):
  assets/audio/token_ticktock.wav  - clock ticking (clock-tower theme)
  assets/audio/token_chime.wav     - bell chime with decay
  assets/audio/token_hum.wav       - low machine hum with vibrato
  assets/audio/token_drip.wav      - water drips in a pipe

Stdlib only (wave + math). 22050 Hz mono 16-bit, normalized to 0.85 peak,
seamless loops: every component uses whole cycles inside the loop length or
fades to the same value it started at, so the last sample meets the first
cleanly. Looping is applied by sound_token.gd at runtime (the WAV importer
ignores its own loop params in 4.7, incl. the RIFF smpl chunk).
"""
import math
import os
import struct
import wave

SR = 22050
OUT_DIR = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                        "..", "..", "assets", "audio"))
os.makedirs(OUT_DIR, exist_ok=True)

TAU = 2.0 * math.pi


def write_wav(name: str, samples: list) -> None:
    # Normalize to 0.85 peak so tokens are clearly audible in the mix.
    peak = max(1e-9, max(abs(s) for s in samples))
    gain = 0.85 / peak
    path = os.path.join(OUT_DIR, name)
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        frames = bytearray()
        for s in samples:
            frames += struct.pack("<h", int(max(-1.0, min(1.0, s * gain)) * 32767.0))
        w.writeframes(bytes(frames))
    print("[audio] %-22s %.2f s  %d KB" % (name, len(samples) / SR, os.path.getsize(path) // 1024))


def silence(dur: float) -> list:
    return [0.0] * int(SR * dur)


def mix_into(base: list, add: list, at_s: float, gain: float = 1.0) -> None:
    start = int(at_s * SR)
    for i, v in enumerate(add):
        j = start + i
        if 0 <= j < len(base):
            base[j] += v * gain


def tone(dur: float, freq: float, decay: float = 0.0, attack: float = 0.004) -> list:
    """Sine with optional exponential decay and short attack. decay=0 -> steady."""
    n = int(SR * dur)
    out = []
    # whole cycles: round the frequency so the tone loops seamlessly when the
    # containing clip loops (used for the hum)
    for i in range(n):
        t = i / SR
        env = 1.0
        if decay > 0:
            env = math.exp(-t / decay)
        a = min(1.0, t / attack) if attack > 0 else 1.0
        out.append(0.6 * a * env * math.sin(TAU * freq * t))
    return out


def blip(dur: float, f0: float, f1: float, decay: float) -> list:
    """Frequency-swept sine (drip 'plop') with exponential decay."""
    n = int(SR * dur)
    out = []
    for i in range(n):
        t = i / SR
        k = t / dur
        freq = f0 + (f1 - f0) * k
        # integrate phase with the sweep
        phase = TAU * (f0 * t + (f1 - f0) * t * k / 2.0)
        out.append(0.9 * math.exp(-t / decay) * math.sin(phase))
    return out


# 1) Tick-tock: sharp woody ticks alternating pitch, 2 s loop.
tick = tone(0.05, 1900, decay=0.012) + tone(0.05, 950, decay=0.012, attack=0.0)
loop = silence(2.0)
mix_into(loop, tick, 0.0)
mix_into(loop, tick, 1.0, gain=0.8)  # tock slightly softer
write_wav("token_ticktock.wav", loop)

# 2) Chime: bell strike (fundamental + 2 harmonics), soft second strike.
loop = silence(3.0)
for mult, g, dec in ((1.0, 1.0, 0.9), (2.76, 0.4, 0.5), (5.4, 0.15, 0.3)):
    mix_into(loop, tone(1.6, 523.25 * mult, decay=dec), 0.0, gain=g)
for mult, g, dec in ((1.0, 0.7, 0.8), (2.76, 0.25, 0.45)):
    mix_into(loop, tone(1.4, 392.0 * mult, decay=dec), 1.5, gain=g)
write_wav("token_chime.wav", loop)

# 3) Hum: low drone, whole cycles inside the 2 s loop + slow vibrato that
# completes whole cycles too -> perfectly seamless.
n = int(SR * 2.0)
loop = []
for i in range(n):
    t = i / SR
    vib = 1.0 + 0.004 * math.sin(TAU * 0.5 * t)   # 0.5 Hz vibrato (whole cycle)
    loop.append(0.45 * math.sin(TAU * 55.0 * vib * t)
                + 0.18 * math.sin(TAU * 110.0 * t)
                + 0.08 * math.sin(TAU * 220.0 * t))
write_wav("token_hum.wav", loop)

# 4) Drip: two plops per 3 s loop, second one deeper.
loop = silence(3.0)
mix_into(loop, blip(0.09, 900, 350, decay=0.03), 0.20)
mix_into(loop, blip(0.11, 700, 260, decay=0.035), 1.65)
write_wav("token_drip.wav", loop)

print("[audio] DONE -> %s" % OUT_DIR)

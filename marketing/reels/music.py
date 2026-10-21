#!/usr/bin/env python3
"""Royalty-free lo-fi backing track, synthesized from scratch with numpy.

Usage: python3 music.py <seconds> <out.wav> [seed]
"""
import sys, numpy as np
from scipy.signal import butter, lfilter

SR = 44100
BPM = 78
BEAT = 60 / BPM
BAR = BEAT * 4

# Fmaj7 · Em7 · Dm7 · Cmaj7 — the classic warm lo-fi loop (midi notes)
CHORDS = [[53, 57, 60, 64], [52, 55, 59, 62], [50, 53, 57, 60], [48, 52, 55, 59]]


def hz(m):
    return 440 * 2 ** ((m - 69) / 12)


def env(n, attack=0.005, decay=1.2):
    t = np.arange(n) / SR
    e = np.exp(-t / decay)
    a = int(attack * SR)
    if a:
        e[:a] *= np.linspace(0, 1, a)
    return e


def rhodes(midi, dur, vel=1.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = hz(midi)
    tone = (np.sin(2 * np.pi * f * t)
            + 0.35 * np.sin(2 * np.pi * 2 * f * t) * np.exp(-t * 3)
            + 0.12 * np.sin(2 * np.pi * 3 * f * t) * np.exp(-t * 5))
    trem = 1 + 0.08 * np.sin(2 * np.pi * 4.5 * t)
    return tone * env(n, 0.004, 1.1) * trem * vel * 0.18


def bass(midi, dur, vel=1.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = hz(midi)
    tone = np.sin(2 * np.pi * f * t) + 0.25 * np.sin(2 * np.pi * 2 * f * t)
    return tone * env(n, 0.006, 0.45) * vel * 0.35


def kick(vel=1.0):
    n = int(0.32 * SR)
    t = np.arange(n) / SR
    f = 42 + 90 * np.exp(-t * 28)
    ph = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(ph) * np.exp(-t * 9) * vel * 0.9


def snare(rng, vel=1.0):
    n = int(0.16 * SR)
    t = np.arange(n) / SR
    noise = rng.standard_normal(n)
    b, a = butter(2, [1500 / (SR / 2), 6000 / (SR / 2)], btype="band")
    noise = lfilter(b, a, noise)
    body = np.sin(2 * np.pi * 190 * t) * np.exp(-t * 30)
    return (noise * np.exp(-t * 22) * 0.5 + body * 0.4) * vel * 0.5


def hat(rng, vel=1.0, dur=0.05):
    n = int(dur * SR)
    t = np.arange(n) / SR
    noise = rng.standard_normal(n)
    b, a = butter(2, 7000 / (SR / 2), btype="high")
    return lfilter(b, a, noise) * np.exp(-t * 60) * vel * 0.16


def place(buf, sig, at):
    i = max(0, int(at * SR))        # humanized timing can nudge the first hit below zero
    j = min(len(buf), i + len(sig))
    if j > i:
        buf[i:j] += sig[: j - i]


def render(seconds, seed=7):
    rng = np.random.default_rng(seed)
    loop = BAR * len(CHORDS)
    n_loops = int(np.ceil((seconds + 2) / loop))
    total = n_loops * loop + 3
    buf = np.zeros(int(total * SR))

    for L in range(n_loops):
        for ci, chord in enumerate(CHORDS):
            bar0 = L * loop + ci * BAR
            # chord stabs: beat 1 (full) and the "and" of 2 (softer), slight humanized timing
            for at, vel in ((0, 1.0), (BEAT * 1.5, 0.55), (BEAT * 3, 0.7)):
                for k, m in enumerate(chord):
                    place(buf, rhodes(m, BEAT * 2.2, vel), bar0 + at + k * 0.012 + rng.normal(0, 0.004))
            # bass
            root = chord[0] - 12
            place(buf, bass(root, BEAT * 1.6), bar0)
            place(buf, bass(root, BEAT * 0.8, 0.7), bar0 + BEAT * 2.5)
            if ci % 2 == 1:
                place(buf, bass(root + 7, BEAT * 0.6, 0.5), bar0 + BEAT * 3.5)
            # drums (swung 8ths)
            place(buf, kick(), bar0)
            place(buf, kick(0.7), bar0 + BEAT * 2.5)
            place(buf, snare(rng), bar0 + BEAT)
            place(buf, snare(rng, 0.9), bar0 + BEAT * 3)
            for e in range(8):
                swing = 0.08 * BEAT if e % 2 else 0
                vel = 0.9 if e % 2 == 0 else 0.5
                place(buf, hat(rng, vel * rng.uniform(0.8, 1.0)), bar0 + e * BEAT / 2 + swing)

    # vinyl crackle + hiss
    crackle = np.zeros_like(buf)
    idx = rng.integers(0, len(buf), size=int(total * 9))
    crackle[idx] = rng.uniform(-1, 1, size=len(idx))
    b, a = butter(2, 3000 / (SR / 2))
    crackle = lfilter(b, a, crackle) * 0.9
    hiss = rng.standard_normal(len(buf))
    b, a = butter(2, 1200 / (SR / 2))
    hiss = lfilter(b, a, hiss) * 0.004
    buf += crackle + hiss

    # lo-fi warmth: gentle low-pass + soft clip
    b, a = butter(2, 4200 / (SR / 2))
    buf = lfilter(b, a, buf)
    buf = np.tanh(buf * 1.4) / 1.4
    buf /= np.max(np.abs(buf)) + 1e-9
    buf *= 0.5

    buf = buf[: int(seconds * SR)]
    fade_in = int(0.8 * SR)
    fade_out = int(2.0 * SR)
    buf[:fade_in] *= np.linspace(0, 1, fade_in)
    buf[-fade_out:] *= np.linspace(1, 0, fade_out)
    return buf


def write_wav(path, buf):
    import wave
    data = (np.clip(buf, -1, 1) * 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


if __name__ == "__main__":
    secs = float(sys.argv[1])
    out = sys.argv[2]
    seed = int(sys.argv[3]) if len(sys.argv) > 3 else 7
    write_wav(out, render(secs, seed))
    print(f"wrote {out} ({secs:.1f}s)")

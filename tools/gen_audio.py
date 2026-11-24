#!/usr/bin/env python3
"""効果音を numpy で合成して godot/assets/audio/*.wav に書き出す。
音楽（bgm_*・jingle_*・場面クリアの clear.wav）は ここでは 作らない：tools/music/（docs/audio.md）。

使い方: python3 tools/gen_audio.py
外部の音素材は使わず、全部プログラムで作っている（22050 Hz / 16bit / モノラル）。
"""
from __future__ import annotations

import math
import pathlib
import struct
import wave

import numpy as np

SR = 22050
OUT = pathlib.Path(__file__).resolve().parent.parent / "godot" / "assets" / "audio"


def t(sec: float) -> np.ndarray:
    return np.arange(int(SR * sec)) / SR


def env(n: int, a=0.005, d=0.1, s=0.6, r=0.1) -> np.ndarray:
    """ADSR っぽい簡単なエンベロープ"""
    a_n, d_n, r_n = int(a * SR), int(d * SR), int(r * SR)
    s_n = max(n - a_n - d_n - r_n, 0)
    e = np.concatenate([
        np.linspace(0, 1, a_n, endpoint=False),
        np.linspace(1, s, d_n, endpoint=False),
        np.full(s_n, s),
        np.linspace(s, 0, r_n, endpoint=True),
    ])
    if len(e) < n:
        e = np.concatenate([e, np.zeros(n - len(e))])
    return e[:n]


def sine(freq, sec, vol=1.0):
    return vol * np.sin(2 * math.pi * freq * t(sec))


def sweep(f0, f1, sec, vol=1.0, shape="sin"):
    tt = t(sec)
    f = f0 + (f1 - f0) * (tt / sec)
    phase = 2 * math.pi * np.cumsum(f) / SR
    if shape == "square":
        return vol * np.sign(np.sin(phase))
    if shape == "tri":
        return vol * (2 / math.pi) * np.arcsin(np.sin(phase))
    return vol * np.sin(phase)


def square(freq, sec, vol=1.0):
    return vol * np.sign(np.sin(2 * math.pi * freq * t(sec)))


def tri(freq, sec, vol=1.0):
    return vol * (2 / math.pi) * np.arcsin(np.sin(2 * math.pi * freq * t(sec)))


def noise(sec, vol=1.0, seed=0):
    rng = np.random.default_rng(seed)
    return vol * rng.uniform(-1, 1, int(SR * sec))


def lowpass(x, alpha=0.1):
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += alpha * (v - acc)
        y[i] = acc
    return y


def midi(n: float) -> float:
    return 440.0 * 2 ** ((n - 69) / 12)


def concat(*parts):
    return np.concatenate(parts)


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def fade(x, ms=8):
    n = min(int(SR * ms / 1000), len(x) // 2)
    if n > 0:
        x[:n] *= np.linspace(0, 1, n)
        x[-n:] *= np.linspace(1, 0, n)
    return x


def write(name: str, data: np.ndarray, vol=0.8):
    data = np.asarray(data, dtype=np.float64)
    peak = np.max(np.abs(data)) if len(data) else 1.0
    if peak > 0:
        data = data / peak * vol
    data = fade(data.copy())
    pcm = (np.clip(data, -1, 1) * 32767).astype("<i2")
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print(f"  {name}.wav  {len(pcm) / SR:.2f}s")


def note(freq, sec, kind="tri", vol=1.0, a=0.005, d=0.05, s=0.7, r=0.08):
    if kind == "square":
        x = square(freq, sec, vol)
    elif kind == "sin":
        x = sine(freq, sec, vol)
    else:
        x = tri(freq, sec, vol)
    return x * env(len(x), a, d, s, r)


def arp(notes, each=0.09, kind="tri", gap=0.0):
    parts = []
    for n in notes:
        parts.append(note(midi(n), each, kind))
        if gap:
            parts.append(np.zeros(int(SR * gap)))
    return concat(*parts)


# ------------------------------------------------------------ 効果音
def sfx():
    print("sfx:")
    write("shoot", sweep(700, 1400, 0.12) * env(int(SR * 0.12), 0.002, 0.03, 0.5, 0.06))
    write("hit", mix(noise(0.08, 0.6, 1) * env(int(SR * 0.08), 0.001, 0.02, 0.3, 0.05),
                     sweep(300, 120, 0.1) * env(int(SR * 0.1), 0.001, 0.03, 0.4, 0.05)))
    write("pop", sweep(900, 200, 0.16) * env(int(SR * 0.16), 0.002, 0.05, 0.4, 0.08))
    write("collect", arp([84, 88, 91], 0.07, "tri"))
    write("cheer", arp([79, 84, 88, 91], 0.08, "tri", 0.01))
    write("hurt", sweep(420, 140, 0.32, shape="square") * env(int(SR * 0.32), 0.002, 0.1, 0.5, 0.15) * 0.6)
    write("heal", mix(arp([76, 83, 88, 95], 0.09, "sin"), np.zeros(1)))
    write("checkpoint", mix(note(midi(88), 0.45, "sin", 1.0, 0.002, 0.1, 0.5, 0.3), note(midi(100), 0.45, "sin", 0.4, 0.002, 0.1, 0.5, 0.3)))
    write("deliver", mix(note(midi(72), 0.5, "tri", 0.6, 0.01, 0.1, 0.6, 0.3), note(midi(76), 0.5, "tri", 0.6, 0.01, 0.1, 0.6, 0.3), note(midi(79), 0.5, "tri", 0.6, 0.01, 0.1, 0.6, 0.3)))
    write("mission", arp([72, 76, 79, 84], 0.11, "square", 0.01) * 0.6)
    write("goal_open", mix(sweep(400, 1600, 0.6) * env(int(SR * 0.6), 0.01, 0.2, 0.6, 0.3), arp([84, 88, 91, 96], 0.15, "sin")))
    write("locked", concat(square(180, 0.09, 0.5) * env(int(SR * 0.09), 0.002, 0.02, 0.8, 0.03), np.zeros(int(SR * 0.05)), square(160, 0.14, 0.5) * env(int(SR * 0.14), 0.002, 0.02, 0.8, 0.05)))
    write("card", mix(lowpass(noise(0.25, 0.7, 2), 0.25) * env(int(SR * 0.25), 0.01, 0.1, 0.3, 0.1), note(midi(91), 0.3, "sin", 0.5, 0.05, 0.1, 0.5, 0.15)))
    write("click", sweep(1200, 900, 0.05) * env(int(SR * 0.05), 0.001, 0.02, 0.4, 0.02))
    write("beep", note(440, 0.35, "tri", 1.0, 0.005, 0.05, 0.8, 0.12))
    write("wrong", concat(note(midi(64), 0.18, "square", 0.6), note(midi(58), 0.3, "square", 0.6)))
    write("quiz_ok", arp([72, 76, 79, 84, 88], 0.09, "tri", 0.01))
    write("boss_roar", lowpass(noise(0.7, 1.0, 3), 0.08) * env(int(SR * 0.7), 0.05, 0.2, 0.6, 0.3) + sweep(90, 60, 0.7, 0.5, "square") * env(int(SR * 0.7), 0.05, 0.2, 0.6, 0.3))
    write("boss_weak", concat(note(midi(84), 0.12, "sin"), note(midi(88), 0.12, "sin"), note(midi(84), 0.12, "sin"), note(midi(88), 0.25, "sin")))
    write("boss_hit", mix(noise(0.12, 0.6, 4) * env(int(SR * 0.12), 0.001, 0.03, 0.3, 0.08), sweep(200, 80, 0.2) * env(int(SR * 0.2), 0.001, 0.05, 0.4, 0.1)))
    write("boss_down", mix(lowpass(noise(1.2, 1.0, 5), 0.12) * env(int(SR * 1.2), 0.01, 0.3, 0.5, 0.6), sweep(500, 50, 1.2, 0.7, "square") * env(int(SR * 1.2), 0.01, 0.3, 0.5, 0.6)))
    write("gate_open", sweep(300, 900, 0.3) * env(int(SR * 0.3), 0.01, 0.1, 0.5, 0.15))
    write("gate_close", mix(sweep(200, 90, 0.2) * env(int(SR * 0.2), 0.002, 0.05, 0.4, 0.1), lowpass(noise(0.15, 0.5, 6), 0.2) * env(int(SR * 0.15), 0.002, 0.05, 0.3, 0.08)))


if __name__ == "__main__":
    sfx()
    print("done ->", OUT)

#!/usr/bin/env python3
"""場所の 面に はる「仮の 画像」を 作る（発注した 絵が とどく までの つなぎ）。

  python3 tools/gen_stage_textures.py            # 全部
  python3 tools/gen_stage_textures.py mouth      # 口だけ

出力：godot/assets/textures/stages/tex_<場所>_<役わり>.png（floor・wall）。もう ある ファイルは 上書き しない（--force で 上書き）。
口（mouth）は 納品の 絵（W3-01）に 入れかえ ずみ（docs/art_orders/W3_01_口_取り込みの結果.md）。
決まり は 発注書（docs/art_orders/W3_01_からだのぶたい.md 2.3）と 同じ：上下左右が つながる・均一な 光・影なし・
1 枚 = 4 m 四方。Godot は ファイル名で さがすので、とどいた 絵を 同じ 名前で 置けば 差しかわる（GLB は 作りなおさない）。
大きさは 1024 px（とどく 絵は 2048 px。.import の process/size_limit で 読みこむ 大きさを 決める。口は 512）。

作りかた：色の 平らな 面に、大きく やわらかい むら（筆で ぬった ような 明るい・暗い ところ）と、
その 場所らしい もよう（したの ぶつぶつ）を、ふちを ぼかして 重ねる。細かい ノイズは 入れない。
"""
from __future__ import annotations

import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "godot", "assets", "textures", "stages")
N = 1024


def lin(hex_color):
    s = hex_color.lstrip("#")
    c = np.array([int(s[i:i + 2], 16) for i in (0, 2, 4)], dtype=float) / 255.0
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def to_srgb(c):
    c = np.clip(c, 0.0, 1.0)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * c ** (1 / 2.4) - 0.055)


def grid():
    t = (np.arange(N) + 0.5) / N
    return np.meshgrid(t, t)


def wrap(d):
    """くりかえしの 中での 差（−0.5〜0.5）"""
    return (d + 0.5) % 1.0 - 0.5


def blob(u, v, cx, cy, sx, sy=None, angle=0.0):
    """ふちの ぼけた だ円（上下左右に つながる）。0〜1"""
    sy = sx if sy is None else sy
    dx, dy = wrap(u - cx), wrap(v - cy)
    ca, sa = np.cos(angle), np.sin(angle)
    a, b = dx * ca + dy * sa, -dx * sa + dy * ca
    return np.exp(-0.5 * ((a / sx) ** 2 + (b / sy) ** 2))


def spots(rng, count, min_dist):
    """はなれた 点を まく（つながりを 考えた きょり）。同じ もようが ならんで 見えにくい"""
    pts = []
    tries = 0
    while len(pts) < count and tries < 20000:
        tries += 1
        p = rng.random(2)
        if all(np.hypot(*wrap(p - q)) >= min_dist for q in pts):
            pts.append(p)
    return pts


def wash(rng, u, v, big, mid, strokes=0):
    """筆で ぬった ような 大きい むら（−1〜1 くらい）"""
    w = np.zeros_like(u)
    for _ in range(big):
        w += rng.choice((-1.0, 1.0)) * rng.uniform(0.5, 1.0) * blob(u, v, rng.random(), rng.random(), rng.uniform(0.13, 0.24))
    for _ in range(mid):
        w += rng.choice((-1.0, 1.0)) * rng.uniform(0.2, 0.5) * blob(u, v, rng.random(), rng.random(), rng.uniform(0.04, 0.08))
    for _ in range(strokes):
        w += rng.choice((-1.0, 1.0)) * rng.uniform(0.25, 0.55) * blob(
            u, v, rng.random(), rng.random(), rng.uniform(0.012, 0.03), rng.uniform(0.12, 0.26), rng.normal(0.0, 0.35))
    return w / max(1e-6, np.abs(w).max())


def paint(base, light, dark, amount):
    """amount（−1〜1）で base を light／dark へ よせる"""
    a = np.clip(amount, -1.0, 1.0)[..., None]
    return np.where(a >= 0, base + (light - base) * a, base + (dark - base) * (-a))


def save(name, rgb_lin, rng):
    os.makedirs(OUT, exist_ok=True)
    img = to_srgb(rgb_lin) * 255.0 + rng.uniform(-0.5, 0.5, rgb_lin.shape)   # 段が 見えない ように ほんの 少し ちらす
    path = os.path.join(OUT, name)
    if os.path.exists(path) and "--force" not in sys.argv:
        print(f"  skip {os.path.relpath(path, ROOT)}（もう ある。とどいた 絵を 上書き しない。仮に もどす ときは --force）")
        return
    Image.fromarray(np.clip(np.round(img), 0, 255).astype(np.uint8), "RGB").save(path, optimize=True)
    print(f"  -> {os.path.relpath(path, ROOT)}  ({os.path.getsize(path) / 1024:.0f} KB)")


# ------------------------------------------------------------------ くち
def mouth_floor():
    """した：明るい ピンクに、やわらかい むらと、まるく ふくらんだ ぶつぶつ（0.5〜0.9 m）を 少し"""
    rng = np.random.default_rng(11)
    u, v = grid()
    base, light, dark = lin("#FD7985"), lin("#FF9AA3"), lin("#F0647A")
    a = 0.30 * wash(rng, u, v, 12, 18)
    for p in spots(rng, 13, 0.2):
        r = rng.uniform(0.062, 0.105)
        ang = rng.uniform(0, np.pi)
        k = rng.uniform(0.85, 1.0)
        halo = blob(u, v, p[0], p[1], r * 1.2, r * 1.2 * k, ang)
        dome = blob(u, v, p[0], p[1], r * 0.7, r * 0.7 * k, ang) ** 0.6
        a += -0.26 * halo + 0.42 * dome        # まわりを 少し こく、まんなかを 明るく＝ぷっくり
    save("tex_mouth_floor.png", paint(base, light, dark, a), rng)


def mouth_wall():
    """かべ：あかい コーラル色に、たてに 流れる やわらかい 筆あと"""
    rng = np.random.default_rng(23)
    u, v = grid()
    base, light, dark = lin("#EF5658"), lin("#F8706C"), lin("#DC4450")
    a = 0.30 * wash(rng, u, v, 6, 30, strokes=30)
    for p in spots(rng, 9, 0.2):               # ところどころ 明るい たまり
        a += 0.35 * blob(u, v, p[0], p[1], rng.uniform(0.05, 0.09), rng.uniform(0.05, 0.09))
    save("tex_mouth_wall.png", paint(base, light, dark, a), rng)


STAGES = {"mouth": (mouth_floor, mouth_wall)}

if __name__ == "__main__":
    names = [a for a in sys.argv[1:] if not a.startswith("-")] or list(STAGES)
    unknown = [n for n in names if n not in STAGES]
    if unknown:
        sys.exit(f"unknown stage(s) {unknown}; choices: {', '.join(STAGES)}")
    for n in names:
        print(f"[textures] {n}")
        for fn in STAGES[n]:
            fn()

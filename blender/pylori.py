"""ピロリきん（pylori）。い（胃）の ステージの てき。

納品された 3D 用の絵（art/concepts/W2_enemies/ の pylori_3d_*・pylori_turnaround・pylori_3d_parts）から 測った 寸法で 作る。
寸法・色・絵との ちがいは docs/art_orders/W2_01_pylori_3D化の結果.md。

・前は +Y、上は +Z、単位は m。原点は 体の 長さの まん中（体の 軸の 上）。本人の 右は +X（正面の 絵では 左）。
・大きさは spec（べん毛こみ 全長 1.4 m、胴の 太さ 0.55 m）の S 倍（当たり判定 enemy.gd の radius 0.7・touch_r 0.9 に
  合わせた。むしばきんと ほぼ 同じ 倍率）。
・体は 太い 豆形：前の 頭の 球と うしろの 球（ほぼ 同じ 大きさ）を なめらかに つつんだ 形（round cone）を、
  頭の 中心より うしろを 円弧に そって 上へ 曲げた もの（断面も いっしょに 回るので、うしろは まるい ドームの まま 上がる）。
  絵は 頭が 下がった すがただが、頭は 水平に 作る（取り込みの 決め）。曲げで うしろの ドームが 頭の 上に 見える。
・らせんの 帯：ななめに 1 周 する とじた 輪 1 本（明るい 色、ほぼ 平らで ふちは 丸い）。2 回目で 1 周半の らせんから 変えた（記録 11 章）。
・べん毛 3 本（まん中 1 本は 上へ 立って うしろへ そり、先は 前へ まるく もどる。左右 2 本は うしろ上へ 出て 外へ ひろがる。
  根もとが ほそく、先へ 向かって 太く なって まるく とじる こん棒の 形の しょく手。4 回目で 絵の 形に 合わせた（記録 13 章）。
  別の 部品 Flagella（原点は 根もとの まん中）。
  いまの ゲームは 動かして いない（ゆらす ときは この ノードを 回す）。
・顔（白目・黒目・光・まゆ・あいた 口と 舌）は 頭の 面に はった うすい ふくらみ。正面の 絵の 位置で 置く。
・色は 部品ごとに 1 色（絵から 測った hex）。形が まじわる 所の うすい 影は 頂点カラー（Col）に 焼いて ある。
  作りの 道具は blender/pod.py と 共通。

実行: python -m blender.characters pylori
"""
from __future__ import annotations

import math

import numpy as np

try:
    from . import common as C
    from . import pod as P
except ImportError:  # blender -b -P で直接実行したとき
    import os
    import sys
    sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    from blender import common as C
    from blender import pod as P


# ------------------------------------------------------------------ 寸法（m。spec の 大きさ × S）
S = 1.5             # spec → ゲーム（当たり判定に 合わせる 倍率。むしばきんは 1.56）

RH = 0.275 * S      # 頭（前の 球）の 半径（spec の 胴の 太さ 0.55）
RR = 0.270 * S      # うしろの 球の 半径（1 回目は 0.200。見なおしで「太い 豆」に：真上の 絵 319 px ÷ 頭 360 px より 少し 太い）
HC = 0.280 * S      # 頭の 中心（前後）
RC = -0.300 * S     # うしろの 球の 中心（曲げる 前。うしろの はしが さわる 範囲 0.9 m の 内に 入る ように 1 回目の -0.34 から 前へ）
BEND_R = 0.80 * S   # 豆形の 曲がり：頭の 中心より うしろを、上に ある 半径 BEND_R の 円に そって 曲げる（断面も いっしょに 回る）
WAIST = 0.012 * S   # 帯の あたりの くびれ
WAIST_AT = -0.06 * S
REAR_FLAT = 0.0     # うしろの 断面：横に これだけ 広く、たてに これだけ 低く（1 回目は 0.15。低い うしろが いもむしに 見えたので 0）

# 帯（ななめの 輪 1 本。2 回目で 1 周半の らせんから 変えた。記録 11 章）
#   帯の まん中の 線：前後の 位置 h(φ) ＝ RING_A ＋ RING_TOP·sin φ ＋ RING_SAG·sin² φ ＋ RING_SIDE·cos φ
#   （φ は まわりの 角度。0 ＝ 本人の 右、90 ＝ 上）。上は 頭の すぐ うしろ、よこは 体の うしろ半分、下は うしろの 球の 下。
#   本人の 右が 少し 前・左が 少し うしろ（真上の 絵と 背面の 絵の ななめ）。とじた 輪なので はしが 無い。
RING_A = -0.100 * S         # よこ（φ ＝ 0, 180）の 平均
RING_TOP = 0.100 * S        # 上は 前、下は うしろ（真横・45° の 絵：頭の うしろの 上から うしろの 下へ）
RING_SAG = 0.000 * S        # 上と 下を いっしょに 前へ（よこが いちばん うしろ寄りに なる）
RING_SIDE = 0.180 * S       # 本人の 右が 前、左が うしろ
BAND_W = 0.19 * S           # 帯の 幅（絵は 体の 長さの 約 0.17〜0.22）
BAND_H = 0.010 * S          # 盛り上がり（ほぼ 平ら。ふちは 丸く 体へ おりる）

# べん毛（根もとの 向きは うしろの 球の 中心から。道は 根もとからの ずれ ×S）
# 4 回目：絵の しょく手は「根もとが ほそく、先へ 向かって 太く なって まるく とじる」こん棒の 形（正面の 絵で 根もとの 太さは 体の 幅の
# 約 0.16、先の ふくらみは 約 0.30）。3 回目は 逆（根もとが 太く 先が 細い）で、つのに 見えた。うしろへ ながれる 向きも 絵に 合わせた。
FLAG_R = 0.042 * S          # 根もとの 太さの 半分（直径 約 0.13 m）
FLAG_BULB = 0.084 * S       # 先の ふくらみの 半径（直径 約 0.25 m）
FLAG_GROW = 0.45            # 長さの この 割合から 先へ、だんだん 太く なる
FLAG_NECK = 0.94            # ふくらみの 手前で くきが とどく 太さ（ふくらみの 半径の 倍。くびれを 作らない）
FLAGELLA = [
    # 根もとの 向き, 道の 点（根もとからの ずれ。3 次ベジェの 残り 3 点）
    # まん中：上へ 立って うしろへ そり、先は 前へ まるく もどる（正面の 絵では まっすぐ 上、真横の 絵では「？」の 形）
    ((0.0, -0.45, 0.89), ((0.0, -0.07, 0.15), (0.0, -0.24, 0.32), (0.0, -0.11, 0.44))),
    # 左右：うしろへ ながれて 外へ ひろがり、先は 外がわへ まがる（正面・背面の 絵の 外へ そる 2 本、真横の 絵の うしろへ ながれる 2 本）。
    # 高さを 少し ずらす（真横から 3 本とも 見える。絵も 3 本を ずらして 描いて いる）
    ((0.30, -0.66, 0.68), ((0.03, -0.13, 0.11), (0.13, -0.30, 0.27), (0.27, -0.35, 0.17))),
    ((-0.30, -0.66, 0.68), ((-0.03, -0.11, 0.13), (-0.13, -0.25, 0.31), (-0.27, -0.29, 0.23))),
]

# 顔（正面の 絵の 座標。頭の 半径 ＝ 1、右 ＝ 絵の 右、上 ＝ 上。頭の 中心 (976, 1327) px、半径 272 px）
EYE_C = (0.427, 0.055)
EYE_AB = (0.243, 0.283)
PUPIL_IN = 0.100
PUPIL_AB = (0.147, 0.195)
SPARK = (0.052, 0.105)      # 黒目の まん中から 絵の 右上
SPARK_R = 0.050
BROW_IN = (0.191, 0.272)
BROW_OUT = (0.566, 0.489)
BROW_W = 0.066
MOUTH_HALF = 0.235          # 口の 上の へりの はしまで
MOUTH_TOP = -0.232          # 上の へり（はしは 少し 上がる）
MOUTH_LIFT = 0.020
MOUTH_LOW = -0.518          # いちばん 下
TONGUE_TOP = -0.350         # 舌の いちばん 上（まん中）

H_WHITE = 0.010
H_PUPIL = 0.007
H_SPARK = 0.004
H_BROW = 0.020
H_MOUTH = 0.006
H_TONGUE = 0.005
SINK = 0.006

# ------------------------------------------------------------------ 色（絵から 測った sRGB）
COL = {
    "body": "#957D94",      # 体（絵の 平らな 所の 中央値。2 回目で い（胃）の 光を 弱めたので 絵の 色に もどした。1 回目は spec の #8D7993）
    "band": "#C0A3BD",      # 帯・べん毛（2 回目に 測りなおした 絵の 帯の 中央値。べん毛は #C4A6C1〜#AE91A8。1 回目は #BB9DB5）
    "white": "#FCF4F1",
    "pupil": "#3C2A32",
    "brow": "#4C3A43",
    "mouth": "#853C44",
    "tongue": "#DF6D6E",
}


# ------------------------------------------------------------------ 体の 形
def _profile_table(n=1200):
    """前後の 位置 h → 半径 r(h)（2 つの 球を つつんだ 形 ＋ くびれ）。"""
    h = np.linspace(RC - RR, HC + RH, n)
    s = np.linspace(0.0, 1.0, 400)
    c = RC + s * (HC - RC)
    rho = RR + s * (RH - RR)
    d = h[:, None] - c[None, :]
    r2 = rho[None, :] ** 2 - d ** 2
    r = np.sqrt(np.maximum(r2.max(axis=1), 0.0))
    r = r - WAIST * np.exp(-((h - WAIST_AT) / (0.14 * S)) ** 2) * (r > 0.05)
    return h, np.maximum(r, 0.0)


_H, _R = _profile_table()


def radius(h):
    return np.interp(h, _H, _R)


def bend_map(y, z):
    """まっすぐな 体の 点 (前後 y, 上 z) → 曲げた 位置。頭の 中心より うしろを 上へ 曲げる（円弧の 曲げ。断面は 軸と いっしょに 回る）。"""
    y = np.asarray(y, dtype=float)
    z = np.asarray(z, dtype=float)
    th = np.clip(HC - y, 0.0, None) / BEND_R
    rho = BEND_R - z
    return np.where(y < HC, HC - rho * np.sin(th), y), BEND_R - rho * np.cos(th)


def axis_point(h):
    """体の 軸の 点（曲げた あと）。(x, y, z)。"""
    y, z = bend_map(h, 0.0)
    y, z = np.broadcast_arrays(y, z)
    return np.stack([np.zeros_like(y), y, z], axis=-1)


def rear_w(h):
    """うしろの 球の あたりで 1、頭で 0。"""
    return np.clip((HC - np.asarray(h, dtype=float)) / (HC - RC), 0.0, 1.0) ** 1.5


def surf(h, phi):
    """体の 面の 点。phi は 度（0 ＝ 本人の 右 +X、90 ＝ 上 +Z）。"""
    h = np.asarray(h, dtype=float)
    a = np.radians(phi)
    r = radius(h)
    w = rear_w(h)
    x = r * np.cos(a) * (1.0 + REAR_FLAT * w)
    zs = r * np.sin(a) * (1.0 - REAR_FLAT * w)
    y, z = bend_map(np.broadcast_to(h, x.shape), zs)
    return np.stack([x, y, z], axis=-1)


def surf_normal(h, phi, eps=1e-3):
    h = np.asarray(h, dtype=float)
    phi = np.asarray(phi, dtype=float)
    dh = surf(h + eps, phi) - surf(h - eps, phi)
    da = surf(h, phi + 0.1) - surf(h, phi - 0.1)
    n = np.cross(da, dh)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    # 外向きに（軸からの 向きと 同じ がわ）
    out = surf(h, phi) - axis_point(np.broadcast_to(h, np.shape(phi)) if np.ndim(phi) > np.ndim(h) else h)
    flip = np.sum(n * out, axis=-1) < 0.0
    n[flip] *= -1.0
    return n


def build_body(m_body, nu=48, nv=44):
    # 輪郭の 長さで 輪を ならべる（はしの 丸みにも 輪が 入る）
    seg = np.hypot(np.diff(_H), np.diff(_R))
    L = np.concatenate([[0.0], np.cumsum(seg)])
    t = np.linspace(0.0, L[-1], nv + 1)[1:-1]
    hs = np.interp(t, L, _H)
    phis = np.linspace(0.0, 360.0, nu, endpoint=False)
    rings = surf(hs[:, None], phis[None, :])
    start = axis_point(_H[0])
    end = np.array([0.0, _H[-1], 0.0])
    verts, faces = P.skin(rings, start, end)
    return P.mesh_obj("pylori_body", verts, faces, m_body, inside=(0.0, 0.0, 0.0))


# ------------------------------------------------------------------ 帯（ななめの 輪）
def bump(s):
    s = np.clip(np.asarray(s, dtype=float), 0.0, 1.0)
    return (1.0 - s ** 4) ** 0.25


def band_lift(s):
    """帯の 横の 断面：まん中は ほぼ 平ら、ふちへ 丸く おりて 0。"""
    s = np.clip(np.asarray(s, dtype=float), 0.0, 1.0)
    return (1.0 - s ** 2.5) ** 0.8


def ring_h(phi):
    a = np.radians(phi)
    return RING_A + RING_TOP * np.sin(a) + RING_SAG * np.sin(a) ** 2 + RING_SIDE * np.cos(a)


def build_band(m_band, n=192):
    ac = np.linspace(0.0, 360.0, n + 1)          # さいごは さいしょと 同じ 点（あとで つなぐ）
    hc = ring_h(ac)
    r = radius(hc)
    a = np.radians(ac)
    dh = RING_TOP * np.cos(a) + 2.0 * RING_SAG * np.sin(a) * np.cos(a) - RING_SIDE * np.sin(a)    # dh/dφ（φ は ラジアン）
    darc = r
    ln = np.hypot(dh, darc)
    ph, pa = darc / ln, -dh / ln          # 帯に 直角な 向き（前後, まわりの 長さ）
    rings_s = (0.0, 0.3, 0.55, 0.75, 0.88, 0.96, 1.0)
    rows = []
    for side in (-1.0, 1.0):
        order = rings_s if side > 0 else rings_s[::-1]
        for s_ in order:
            if side < 0 and s_ == 0.0:
                continue
            k = side * s_ * BAND_W * 0.5
            hh = hc + ph * k
            aa = ac + np.degrees(pa * k / np.maximum(radius(hh), 1e-3))
            lift = np.full_like(hh, BAND_H * float(band_lift(s_)))
            rows.append(surf(hh, aa) + surf_normal(hh, aa) * lift[:, None])
        # ふちを 体の 中へ
        k = side * BAND_W * 0.5
        hh = hc + ph * k
        aa = ac + np.degrees(pa * k / np.maximum(radius(hh), 1e-3))
        sunk = surf(hh, aa) - surf_normal(hh, aa) * SINK
        if side < 0:
            rows.insert(0, sunk)
        else:
            rows.append(sunk)
    grid = np.array(rows)            # (across, along, 3)
    grid[:, -1] = grid[:, 0]         # 輪を とじる
    na, nl, _ = grid.shape
    verts = [tuple(p) for p in grid.reshape(-1, 3)]
    faces = []
    for i in range(na - 1):
        for j in range(nl - 1):
            faces.append((i * nl + j, i * nl + j + 1, (i + 1) * nl + j + 1, (i + 1) * nl + j))
    ob = P.mesh_obj("pylori_band", verts, faces, m_band, inside=(0.0, 0.0, 0.0))
    _merge(ob)
    return ob


def _merge(ob, dist=1e-6):
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=dist)
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.update()


# ------------------------------------------------------------------ べん毛
def _bezier3(p0, p1, p2, p3, n):
    t = np.linspace(0.0, 1.0, n)[:, None]
    return (1 - t) ** 3 * p0 + 3 * (1 - t) ** 2 * t * p1 + 3 * (1 - t) * t ** 2 * p2 + t ** 3 * p3


def flagellum_root(d):
    """うしろの 球の 中心から 向き d の 面の 点（少し 中へ）。"""
    d = np.asarray(d, dtype=float)
    d = d / np.linalg.norm(d)
    c = axis_point(RC)
    r = RR * np.array([1.0 + REAR_FLAT, 1.0, 1.0 - REAR_FLAT])
    return c + d * r * 0.92, d


def flag_radius(l, L):
    """べん毛の 太さ（根もとからの 長さ l、全長 L）：根もとは ほそく、FLAG_GROW から 先へ だんだん 太く なって、
    先の まるい ふくらみ（半径 FLAG_BULB）に そのまま つながる（こん棒の 形。くびれも ピンの 頭も 作らない）。"""
    l = np.asarray(l, dtype=float)
    c = L - FLAG_BULB
    t = np.clip(l / c, 0.0, 1.0)
    g = np.clip((t - FLAG_GROW) / (1.0 - FLAG_GROW), 0.0, 1.0)
    g = g * g * (3.0 - 2.0 * g)
    stem = FLAG_R + (FLAG_BULB * FLAG_NECK - FLAG_R) * g
    stem = stem + 0.35 * FLAG_R * np.exp(-l / (0.05 * S))     # 根もとは 体へ なじむ ように 少し ひろがる
    bulb = np.sqrt(np.maximum(FLAG_BULB ** 2 - (l - c) ** 2, 0.0))
    k = 0.020 * S                                # くきと ふくらみの つなぎの まるみ
    return _smax(np.where(l < c, stem, 0.0), bulb, k)     # ふくらみの 中では くきを 消す（先が とじる）


def _smax(a, b, k):
    h = np.clip(0.5 + 0.5 * (a - b) / k, 0.0, 1.0)
    return b + (a - b) * h + k * h * (1.0 - h)


def build_flagellum(name, m_stem, m_tip, d, offs, nu=18):
    root, d = flagellum_root(d)
    p1, p2, p3 = (root + np.asarray(o) * S for o in offs)
    dense = _bezier3(root, p1, p2, p3, 400)
    # 根もとは 体の 中から（少し もどる）
    dense = np.concatenate([[root - d * 0.07 * S], dense])
    seg = np.linalg.norm(np.diff(dense, axis=0), axis=1)
    cum = np.concatenate([[0.0], np.cumsum(seg)])
    L = cum[-1]
    # 輪の 位置：くきは 等間かく、玉は 細かく（先の はしへ 向けて つまる）
    c = L - FLAG_BULB
    l_stem = np.linspace(0.0, c, 26, endpoint=False)
    l_bulb = c + FLAG_BULB * np.sin(np.linspace(0.0, 1.0, 14) * math.pi * 0.5 * 0.97)
    ls = np.concatenate([l_stem, l_bulb])
    path = np.stack([np.interp(ls, cum, dense[:, j]) for j in range(3)], axis=-1)
    tan = np.stack([np.interp(ls, cum, np.gradient(dense[:, j]) / np.maximum(np.gradient(cum), 1e-9)) for j in range(3)], axis=-1)
    tan /= np.linalg.norm(tan, axis=-1, keepdims=True)
    up = np.array([0.0, 0.0, 1.0]) if abs(tan[0][2]) < 0.9 else np.array([1.0, 0.0, 0.0])
    # 平行移動の 枠（ねじれない）
    nrm = []
    cur = up - tan[0] * np.dot(up, tan[0])
    cur /= np.linalg.norm(cur)
    for i in range(len(ls)):
        cur = cur - tan[i] * np.dot(cur, tan[i])
        cur /= np.linalg.norm(cur)
        nrm.append(cur.copy())
    nrm = np.array(nrm)
    bi = np.cross(tan, nrm)
    rr = flag_radius(ls, L)
    u = np.linspace(0.0, 2.0 * np.pi, nu, endpoint=False)
    rings = path[:, None, :] + rr[:, None, None] * (np.cos(u)[None, :, None] * nrm[:, None, :] + np.sin(u)[None, :, None] * bi[:, None, :])
    end = np.array([np.interp(L, cum, dense[:, j]) for j in range(3)])
    verts, faces = P.skin(rings, path[0], end)
    ob = P.mesh_obj(name, verts, faces, m_stem, inside=path[len(ls) // 3])
    # 先の 部分は 別の マテリアル（同じ 色。Godot の 1 つ目の マテリアルの 件。下の 注）
    me = ob.data
    me.materials.append(m_tip)
    vt = np.concatenate([np.repeat(ls / L, nu), [0.0, 1.0]])
    for p in me.polygons:
        if min(vt[i] for i in p.vertices) > 0.6:
            p.material_index = 1
    return ob, root


# ------------------------------------------------------------------ 顔：頭の 面に はる ふくらみ
def wrap(u, v, lift):
    """正面の 絵の 座標（m。u ＝ 3D の X、v ＝ Z）を 頭の 球の 面へ まっすぐ 投影し、法線の 向きに lift 浮かせる。"""
    u = np.asarray(u, dtype=float)
    v = np.asarray(v, dtype=float)
    y = np.sqrt(np.maximum(RH * RH - u * u - v * v, 1e-9))
    p = np.stack([u, y, v], axis=-1)
    n = p / RH
    return p + n * np.asarray(lift, dtype=float)[..., None] + np.array([0.0, HC, 0.0])


RINGS = (0.5, 0.78, 0.9, 0.96, 1.0)


def _decal(name, material, rings2d, centre, h, under, inner=None):
    n_r = len(rings2d)
    rows = []
    for i, r2 in enumerate(rings2d):
        base = under(r2[:, 0], r2[:, 1]) if under is not None else np.zeros(len(r2))
        lift = base - SINK if i == n_r - 1 else base + h * bump(RINGS[i])
        rows.append(wrap(r2[:, 0], r2[:, 1], lift))
    if inner is not None:
        base = under(inner[:, 0], inner[:, 1]) if under is not None else np.zeros(len(inner))
        rows.insert(0, wrap(inner[:, 0], inner[:, 1], base + h))
        verts, faces = P.skin(np.array(rows))
    else:
        b0 = under(np.array([centre[0]]), np.array([centre[1]]))[0] if under is not None else 0.0
        start = wrap(np.array(centre[0]), np.array(centre[1]), np.array(b0 + h))
        verts, faces = P.skin(np.array(rows), start=start)
    ob = P.mesh_obj(name, verts, faces, material, inside=(0.0, HC, 0.0))
    if inner is not None:
        _merge(ob)
    return ob


def decal_poly(name, material, outline, h, under=None):
    """星形の 輪郭（(N, 2) m、まん中から 見て 1 回 まわる）の ふくらみ。"""
    outline = np.asarray(outline, dtype=float)
    c = outline.mean(axis=0)
    rings = [c + s * (outline - c) for s in RINGS + (1.0,)]
    return _decal(name, material, rings, c, h, under)


def ellipse_outline(c, ab, nu=32):
    th = np.linspace(0.0, 2.0 * np.pi, nu, endpoint=False)
    return np.stack([c[0] + ab[0] * np.cos(th), c[1] + ab[1] * np.sin(th)], axis=-1)


def ellipse_height(u, v, c, ab, h):
    s = np.sqrt(((u - c[0]) / ab[0]) ** 2 + ((v - c[1]) / ab[1]) ** 2)
    return np.where(s < 1.0, h * bump(s), 0.0)


def decal_stroke(name, material, path, w, h, under=None, n_cap=5):
    path = np.asarray(path, dtype=float)
    tan = np.gradient(path, axis=0)
    tan /= np.linalg.norm(tan, axis=-1, keepdims=True)
    nrm = np.stack([-tan[:, 1], tan[:, 0]], axis=-1)
    caps = np.linspace(0.0, np.pi, n_cap + 2)[1:-1]
    rings = []
    for s in (0.0,) + RINGS + (1.0,):
        k = s * w
        side_a = path + nrm * k
        cap_b = [path[-1] + k * (math.cos(a) * nrm[-1] + math.sin(a) * tan[-1]) for a in caps]
        side_b = path[::-1] - nrm[::-1] * k
        cap_a = [path[0] + k * (-math.cos(a) * nrm[0] - math.sin(a) * tan[0]) for a in caps]
        rings.append(np.concatenate([side_a, cap_b, side_b, cap_a]))
    return _decal(name, material, rings[1:], None, h, under, inner=rings[0])


def mouth_outline(n_top=11, n_bot=21):
    """あいた 口：上の へりは ほぼ まっすぐ（はしが 少し 上がる）、下は 丸い。"""
    top = []
    for x in np.linspace(MOUTH_HALF, -MOUTH_HALF, n_top):
        top.append((x, MOUTH_TOP + MOUTH_LIFT * (x / MOUTH_HALF) ** 2))
    bot = []
    for a in np.linspace(math.pi, 2.0 * math.pi, n_bot)[1:-1]:
        bot.append((MOUTH_HALF * 0.96 * math.cos(a), MOUTH_TOP + (MOUTH_TOP - MOUTH_LOW) * math.sin(a) * 1.0))
    return np.array(top + bot)


def tongue_outline(n=24):
    """舌：口の 下の 丸みの 内がわと、上へ ふくらむ 弧。"""
    hw = MOUTH_HALF * 0.96
    depth = (MOUTH_TOP - MOUTH_LOW) * 0.92

    def bottom(x):
        return MOUTH_TOP - depth * math.sqrt(max(0.0, 1.0 - (x / hw) ** 2))

    w = MOUTH_HALF * 0.78
    end_y = bottom(w)
    pts = []
    for a in np.linspace(0.0, math.pi, n // 2):         # 上の 弧（右 → 左）
        pts.append((w * math.cos(a), end_y + (TONGUE_TOP - end_y) * math.sin(a)))
    for x in np.linspace(-w, w, n // 2)[1:-1]:          # 下（口の 丸みの 少し 内がわ）
        pts.append((x, bottom(x)))
    return np.array(pts)


def build_face(m_white, m_pupil, m_spark, m_brow, m_mouth, m_tongue):
    out = []
    eyes = []
    for sx in (-1.0, 1.0):   # sx ＝ 3D の X の 向き（+1 ＝ 本人の 右 ＝ 絵の 左）
        c = np.array([sx * EYE_C[0], EYE_C[1]]) * RH
        ab = np.array(EYE_AB) * RH
        pc = c + np.array([-sx * PUPIL_IN, 0.0]) * RH
        pab = np.array(PUPIL_AB) * RH
        eyes.append((sx, c, ab, pc, pab))

    def whites(u, v):
        return sum(ellipse_height(u, v, c, ab, H_WHITE) for _, c, ab, _, _ in eyes)

    def pupils(u, v):
        return sum(ellipse_height(u, v, pc, pab, H_PUPIL) for _, _, _, pc, pab in eyes)

    for sx, c, ab, pc, pab in eyes:
        tag = int(sx)
        out.append(decal_poly(f"pylori_white{tag}", m_white, ellipse_outline(c, ab, 32), H_WHITE))
        out.append(decal_poly(f"pylori_pupil{tag}", m_pupil, ellipse_outline(pc, pab, 24), H_PUPIL, under=whites))
        sc = pc + np.array([-SPARK[0], SPARK[1]]) * RH     # 絵の 右上 ＝ 3D の -X・上
        out.append(decal_poly(f"pylori_spark{tag}", m_spark, ellipse_outline(sc, (SPARK_R * RH, SPARK_R * RH), 16), H_SPARK,
                              under=lambda u, v: whites(u, v) + pupils(u, v)))
        a = np.array([sx * BROW_IN[0], BROW_IN[1]]) * RH
        b = np.array([sx * BROW_OUT[0], BROW_OUT[1]]) * RH
        path = a + (b - a) * np.linspace(0.0, 1.0, 6)[:, None]
        out.append(decal_stroke(f"pylori_brow{tag}", m_brow, path, BROW_W * RH, H_BROW,
                                under=lambda u, v: whites(u, v) + pupils(u, v)))
    mo = mouth_outline() * RH
    out.append(decal_poly("pylori_mouth", m_mouth, mo, H_MOUTH))
    c_m = mo.mean(axis=0)
    mouth_h = lambda u, v: np.where(((u / (MOUTH_HALF * RH)) ** 2 < 1.0) & (v < MOUTH_TOP * RH), H_MOUTH, 0.0)  # noqa: E731
    out.append(decal_poly("pylori_tongue", m_tongue, tongue_outline() * RH, H_TONGUE, under=mouth_h))
    del c_m
    return out


# ------------------------------------------------------------------ 組み立て
def build_pylori():
    m_body = P.mat("PyloriBody", COL["body"], 0.9)
    m_band = P.mat("PyloriBand", COL["band"], 1.0)
    m_flag = P.mat("PyloriFlagellum", COL["band"], 1.0)   # つやなし（船の 明かりで 白く 光らない ように）
    m_ftip = P.mat("PyloriFlagellumTip", COL["band"], 1.0)   # 同じ 色。Flagella の 1 つ目の マテリアル（下の 注）
    m_white = P.mat("PyloriWhite", COL["white"], 0.9)
    m_spark = P.mat("PyloriSpark", COL["white"], 0.5)
    m_pupil = P.mat("PyloriPupil", COL["pupil"], 0.45)
    m_brow = P.mat("PyloriBrow", COL["brow"], 0.9)
    m_mouth = P.mat("PyloriMouth", COL["mouth"], 0.8)
    m_tongue = P.mat("PyloriTongue", COL["tongue"], 0.7)

    body = build_body(m_body)
    band = build_band(m_band)
    flags = []
    roots = []
    for i, (d, offs) in enumerate(FLAGELLA):
        ob, root = build_flagellum(f"pylori_flagellum{i}", m_flag, m_ftip, d, offs)
        flags.append(ob)
        roots.append(root)
    face = build_face(m_white, m_pupil, m_spark, m_brow, m_mouth, m_tongue)

    solid = [body, band] + flags
    # 帯は ほぼ 平らなので 影を 落とす ものに 入れない（ふちが 黒く 縁どられて テープに 見えない ように）
    P.bake_soft_shadow(solid, [body] + flags, dist=0.22 * S, floor=0.45, dark=(0.60, 0.52, 0.60), soften=3)

    # Godot の glTF 読みこみは、メッシュの 1 つ目の マテリアルに 頂点カラーを 使わない（pod.py と 同じ）。
    # 本体は 影の 要らない 光の 点を 1 つ目に、Flagella は 先の ふくらみ（PyloriFlagellumTip）を 1 つ目に する
    sparks = [o for o in face if "spark" in o.name]
    main_parts = sparks + [body, band] + [o for o in face if o not in sparks]
    print(f"  triangles: body {P.tri_count([body])}, band {P.tri_count([band])}, face {P.tri_count(face)}, "
          f"flagella {P.tri_count(flags)}  total {P.tri_count(main_parts + flags)}")
    main = C.join(main_parts, "pylori")
    fl = C.join(flags, "Flagella")
    # 1 つ目の マテリアルを 先の ふくらみに
    mats = list(fl.data.materials)
    if mats and mats[0].name != m_ftip.name:
        i_tip = [m.name for m in mats].index(m_ftip.name)
        idx = np.zeros(len(fl.data.polygons), dtype=np.int32)
        fl.data.polygons.foreach_get("material_index", idx)
        swap = {0: i_tip, i_tip: 0}
        idx = np.array([swap.get(int(k), int(k)) for k in idx], dtype=np.int32)
        mats[0], mats[i_tip] = mats[i_tip], mats[0]
        fl.data.materials.clear()
        for m in mats:
            fl.data.materials.append(m)
        fl.data.polygons.foreach_set("material_index", idx)
        fl.data.update()
    # 原点を 根もとの まん中に（ゆらす ときの 中心）
    from mathutils import Matrix
    pivot = np.mean(roots, axis=0)
    M = Matrix.Translation(tuple(pivot))
    fl.data.transform(M.inverted())
    fl.matrix_world = M
    fl.parent = main
    fl.matrix_parent_inverse = main.matrix_world.inverted()
    return main

"""くち（口）の ステージ。blender/stages.py の build_mouth が ここの build() を 呼ぶ。

  python -m blender.stages stage_mouth

目あては 納品の 雰囲気画 mood_mouth.png と 部品の 三面図（art/w3-stages の art/concepts/W3_stages/。
大きさと 色は spec.md：main の art/concepts/W3_stages/spec.md）。取り込みの 記録は docs/art_orders/W3_01_口_取り込みの結果.md：
ミクロごうの うしろから 見た、あたたかい 色の 口。ピンクの した（まんなかに みぞ、よこの すじ、少しの ぶつぶつ）、
左右に クリーム色の は（前歯・犬歯・奥歯）、のどへ むかって 段々に 暗く なる 赤い わ、のどの 入口に
ぶらさがる のどちんこ と 左右の 大きな へんとうせん。

形は 全部 式から 作る（stage_kit）：
  MouthShell  かべ（くちびる → ほお → うわあご → のどの わ → のどの くだ）。内向き。
  MouthFloor  ゆか（した ＋ したの まわりの ゆか ＋ のどの すべりだい）。上向きの 1 枚。
  Gums        はぐき（うえ・した）。はの ならびに そった 太い うね。
  Teeth       は 24 本（7 さいの はなちゃん：まえば 4・いときりば 2・おくば 6 が うえと したに）。
  Tonsils     へんとうせん。NC_Uvula（のどちんこ：Godot 側で ゆれる）・NC_Lips・Outside（くちびるの むこうの 明るい おそと）。

座標：+Y が おく（のど）。くちびるは y=-35、スタートは したの さきの 少し おく（START_Y）、ゴールは のどの 中（y=76）。
マーカーの 高さは floor_h() から 出す。
"""
from __future__ import annotations

import math
import random

import numpy as np

try:
    from . import common as C
    from . import stage_kit as K
except ImportError:
    import os
    import sys
    sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    from blender import common as C
    from blender import stage_kit as K

sstep, pchip, spow = K.sstep, K.pchip, K.spow

# ------------------------------------------------------------------ 色（sRGB）
# HEX：面の もとの 色＝納品の spec の 色見本（art/concepts/W3_stages/spec.md）。ゲームの 中の 色は Godot 側
#   （stage_db.gd の "look"：画像 × tex_tint × 頂点カラー × 光）で 決まる。soft（へんとうせん・のどちんこ）と lip は spec に ないので 雰囲気画から。
# 頂点カラー（かげの 倍率）は 雰囲気画（mood_mouth.png）で 測った 色の 比：REF の 色を 1 と して、その 場所の 絵の 色に する 倍率。
HEX = {
    "floor": "#F9949E", "wall": "#E96571", "gum": "#E4566C", "tooth": "#FBE6D2",
    "soft": "#EC565C", "lip": "#EE5F6A", "sky": "#FFFBEF",
}
REF = {"floor": "#FD8E96", "tooth": "#FBE6D2", "soft": "#F35D65"}
# かべの わ：おくへ 行くほど 暗い 赤（雰囲気画の わ：#BC333D → #A72A35 → #8F2634）。さいごは のどの おくの 暗い 赤（#681F2E。黒に しない）
RING_HEX = ["#BC333D", "#B4303B", "#A72A35", "#9B2834", "#8F2634", "#822331"]
DEEP_HEX = "#6A1F2E"

# ------------------------------------------------------------------ かべ（から）の 形
CZ = 2.5           # くちの まんなかの 高さ（いちばん 広い ところ）
Y_LIPS = -35.0
Y_END = 110.0
THROAT_R = 8.4     # のどの くだの 半径（雰囲気画の 大きな あなに ちかづける）
ROAD_UP = 1.3      # のどの くだの 底から「みち」までの 高さ
GOAL_Y = 76.0
START_Y = -12.0    # スタート（したの さきの すこし おく。カメラが まえばの 上に くる）
# のどの わ：(y, はばが へる, 天井が さがる, 床が あがる)。ここで 1 段ずつ せまく・暗く なる
RINGS = [(15.5, 4.0, 2.0, 1.0), (21.5, 3.6, 1.6, 0.9), (27.5, 3.2, 1.2, 0.7), (33.0, 2.8, 0.8, 0.5), (38.5, 2.8, 0.4, 0.2)]
RING_W = 0.95
THROAT_RIBS = [46.5, 54.0, 61.5, 69.0, 86.0, 94.0, 102.0]

MOUTH_A = 13.6     # くちの 中の はば（かたがわ）。spec の した 17 m に あわせた はならび ＋ ほお
_A = pchip([(-35, 10.5), (-33.2, 11.2), (-31, 12.6), (-28, 13.8), (-23, 13.8), (-12, 13.9), (6, 13.9), (13, MOUTH_A), (120, MOUTH_A)])
_TOP = pchip([(-35, 8.0), (-33.2, 8.7), (-31, 11.0), (-28, 13.0), (-22, 14.2), (-10, 14.5), (6, 14.3), (13, 14.0), (120, 14.0)])
_BOT = pchip([(-35, -3.0), (-33.2, -3.7), (-31, -6.4), (-28, -9.0), (-22, -9.8), (0, -9.5), (13, -8.5), (120, -8.5)])
_ys = np.linspace(40.0, 120.0, 1601)
_slope = 0.20 * sstep(40, 47, _ys) + 0.75 * sstep(82, 96, _ys)
_drop = np.concatenate([[0.0], np.cumsum((_slope[1:] + _slope[:-1]) * 0.5 * np.diff(_ys))])


RING_A = (MOUTH_A - THROAT_R) / sum(r[1] for r in RINGS)   # わの はばの へりかた（のどの くだが THROAT_R に なる ように）
RING_V = (22.5 - 2 * THROAT_R) / sum(r[2] + r[3] for r in RINGS)   # 天井と 床の へりかた（たても THROAT_R）


def ring_steps(y, col):
    k = RING_A if col == 1 else RING_V
    return sum(r[col] * k * sstep(r[0] - RING_W, r[0] + RING_W, y) for r in RINGS)


def shell(y):
    """y の 断面：(cx, cz, a, top, bot, n_up, n_dn)。断面は y が 一定の たての 面（スーパーだ円）。"""
    y = np.asarray(y, dtype=float)
    rib = 0.45 * sum(np.exp(-((y - r) / 1.3) ** 2) for r in THROAT_RIBS)
    drop = np.interp(y, _ys, _drop)
    a = _A(y) - ring_steps(y, 1) - rib
    top = _TOP(y) - ring_steps(y, 2) - drop - rib
    bot = _BOT(y) + ring_steps(y, 3) - drop + rib
    cz = CZ + ((top + bot) * 0.5 - CZ) * sstep(13, 34, y)
    cx = 6.0 * sstep(82, Y_END, y) ** 2
    box = sstep(-33, -27, y) * (1.0 - sstep(12, 19, y))   # くちの 中は 四角っぽく、のどの わは まるく
    return cx, cz, a, top, bot, 2.0 + 1.3 * box, 2.0 + 1.6 * box


UVULA_Y = 21.4


def drape(x, y):
    """のどちんこの ねもと：天井の わが まんなかで たれさがる（絵の M の 形）"""
    return 1.7 * np.exp(-((np.asarray(y, dtype=float) - UVULA_Y) / 2.4) ** 2) * np.exp(-(np.asarray(x, dtype=float) / 3.6) ** 2)


def ceil_z(x, y):
    cx, cz, a, top, _bot, nu, _nd = shell(y)
    u = np.clip(np.abs((np.asarray(x, dtype=float) - cx) / a), 0.0, 1.0)
    return cz + (top - cz) * (1.0 - u ** nu) ** (1.0 / nu) - drape(x, y)


def shell_floor_z(x, y):
    cx, cz, a, _top, bot, _nu, nd = shell(y)
    u = np.clip(np.abs((np.asarray(x, dtype=float) - cx) / a), 0.0, 1.0)
    return cz - (cz - bot) * (1.0 - u ** nd) ** (1.0 / nd)


# ------------------------------------------------------------------ はの ならび（アーチ）
ARCH_M = 2.5
ARCH_YB = 1.5     # はならびの おくの はし（いちばん おくの はの すこし うしろ。そこから おくは ほお と のど）
LOWER = {"W": 9.8, "yf": -19.0}
UPPER = {"W": 10.2, "yf": -19.8}
UPPER_CREST = (10.6, 9.3)   # うえの はぐきの てっぺん（まえ、おく）
GUM_W = 2.7        # はぐきの うねの はば（かたがわ）
GUM_H = 2.6


def arch_x(y, arch=LOWER):
    """アーチの y での x（かたがわ）"""
    L = ARCH_YB - arch["yf"]
    t = np.clip((ARCH_YB - np.asarray(y, dtype=float)) / L, 0.0, 1.0)
    return arch["W"] * (1.0 - t ** ARCH_M) ** (1.0 / ARCH_M)


def arch_curve(arch, step=0.25):
    """アーチを 弧の 長さで 等間かくに した 点の 列。右の おく（+x）→ まえ → 左の おく（−x）。
    返す：P（K×2）、T（接線）、N（外向き）、S（弧の 長さ）"""
    L = ARCH_YB - arch["yf"]
    phi = np.linspace(0.0, math.pi, 4001)
    x = arch["W"] * spow(np.cos(phi), 2.0 / ARCH_M)
    y = ARCH_YB - L * np.abs(np.sin(phi)) ** (2.0 / ARCH_M)
    d = np.concatenate([[0.0], np.cumsum(np.hypot(np.diff(x), np.diff(y)))])
    s = np.arange(0.0, d[-1] + step * 0.5, step)
    s[-1] = d[-1]
    P = np.stack([np.interp(s, d, x), np.interp(s, d, y)], axis=1)
    T = np.gradient(P, axis=0)
    T /= np.linalg.norm(T, axis=1, keepdims=True)
    N = np.stack([-T[:, 1], T[:, 0]], axis=1)   # 進む 向きの 左＝外がわ（右おく → まえ → 左おく の 回り）
    return P, T, N, s


# ------------------------------------------------------------------ ゆか（した）の 形
TIP_YS = -1.0      # ここから まえは したの さきの まるみ
TIP_Y = -15.5      # したの さき
TIP_K = 4.5
_TT = pchip([(-21, -4.5), (-17, -3.9), (-10, -3.45), (0, -3.2), (10, -3.1), (17, -2.7), (24, -3.1), (30, -3.7), (36, -4.5), (40, -5.0)])
_FM = pchip([(-34, -3.9), (-31.5, -5.8), (-28.5, -7.0), (-24, -6.8), (-12, -5.2), (0, -4.9), (14, -4.8), (22, -4.6), (40, -5.2)])
# したの ぶつぶつ（spec の 部品 4：0.3〜1.2 m の まるい ふくらみ、底は 平ら）を 少しだけ。(x, y, さしわたし m)。
# 雰囲気画の 2 つ（ひだりの 手前の 大きい の と、みぎの 先の の）＋ おくに 3 つ
PAPILLAE = [(-4.8, -9.5, 3.3), (3.8, -2.5, 2.6), (-2.8, 5.5, 2.2), (6.0, 8.5, 1.7), (-6.8, 1.5, 1.5)]
BUMP_H = 0.3         # 高さ ÷ さしわたし（spec の 表は 0.7 × 0.4 m、三面図は もっと ひくい 0.37。雰囲気画に あわせて ひくめ）
RIDGE_M = 2.1         # したの よこの すじ（雰囲気画の やわらかい しま）の 間かく m
RIDGE_H = 0.11


def tongue_w(y):
    """したの はば（かたがわ）。おくばの ところは はぐきの 下まで、のどの 手前は かべから かべまで。"""
    y = np.asarray(y, dtype=float)
    _cx, _cz, a, _t, _b, _nu, _nd = shell(y)
    k = sstep(ARCH_YB + 1.0, ARCH_YB + 10.0, y)    # はならびの うしろでは かべまで ひろがる
    return (arch_x(np.maximum(y, TIP_YS)) - GUM_W + 2.6) * (1.0 - k) + (a + 1.0) * k


def tongue_s(x, y):
    """したの 形の 中での 位置（0 = まんなか、1 = ふち）"""
    x = np.abs(np.asarray(x, dtype=float))
    y = np.asarray(y, dtype=float)
    lat = x / tongue_w(y)
    fwd = np.clip((TIP_YS - y) / (TIP_YS - TIP_Y), 0.0, None)
    return (lat ** TIP_K + fwd ** TIP_K) ** (1.0 / TIP_K)


def floor_h(x, y):
    """ゆかの 高さ（した・したの まわり・のどの すべりだい）"""
    x = np.asarray(x, dtype=float)
    y = np.asarray(y, dtype=float)
    _cx, _cz, a, _t, _b, _nu, _nd = shell(y)
    fm = _FM(y) + 0.9 * np.abs(x / np.maximum(a, 1.0)) ** 3
    s = tongue_s(x, y)
    groove = (0.6 * sstep(-14, -5, y) + 0.4 * sstep(6, 16, y)) * (1.0 - sstep(26, 36, y)) * np.exp(-(x / 1.6) ** 2)
    bumps = 0.0
    for px, py, dia in PAPILLAE:
        u = np.clip(np.hypot(x - px, y - py) / (dia * 0.5), 0.0, 1.0)
        bumps = bumps + BUMP_H * dia * (1.0 - u ** 2.2) ** 0.7
    ridge = RIDGE_H * np.cos(y * (2 * math.pi / RIDGE_M)) * (1.0 - sstep(0.45, 0.8, s)) * sstep(-13, -7, y) * (1.0 - sstep(16, 24, y))
    dome = _TT(y) - 0.7 * np.minimum(s, 1.2) ** 3.0 - groove + bumps + ridge
    rim = sstep(0.86, 1.0, s) ** 2
    h = dome * (1.0 - rim) + fm * rim
    # のどの くだの 中は、くだの 底より 少し 高い「みち」（まんなかが わずかに くぼむ）
    cx, _cz2, a2, _t2, bot, _nu2, _nd2 = shell(y)
    road = bot + ROAD_UP + 0.5 * ((x - cx) / np.maximum(a2, 1.0)) ** 2
    k = sstep(31, 39, y)
    return h * (1.0 - k) + road * k


def floor_half_width(y):
    """ゆかの 格子の はば：ゆかが かべ（から）と 出あう 所まで。格子の ふちを 出あう 線に そわせると、
    さかい目が ぎざぎざに ならない。"""
    y = np.asarray(y, dtype=float)
    cx, _cz, a, _t, _b, _nu, _nd = shell(y)
    lo, hi = np.zeros_like(y), a * 0.999
    for _ in range(40):
        mid = (lo + hi) * 0.5
        above = floor_h(cx + mid, y) > shell_floor_z(cx + mid, y)
        lo, hi = np.where(above, mid, lo), np.where(above, hi, mid)
    return np.maximum(lo, 1.0)


# ------------------------------------------------------------------ 部品
def build_shell(mat):
    ys = np.concatenate([np.arange(Y_LIPS, -27.0, 0.5), np.arange(-27.0, 12.0, 1.0), np.arange(12.0, 41.0, 0.3),
                         np.arange(41.0, Y_END, 1.2), [Y_END, Y_END + 0.6, Y_END + 0.9]])
    shrink = np.ones(len(ys))
    shrink[-2:] = (0.5, 0.02)       # おくの はしを とじる
    nu = 72
    th = -math.pi / 2 + np.linspace(0.0, 2 * math.pi, nu + 1)   # ぬい目は ゆかの 下（見えない）
    c, s = np.cos(th), np.sin(th)
    cx, cz, a, top, bot, n_up, n_dn = shell(ys)
    up = s[None, :] >= 0
    n = np.where(up, n_up[:, None], n_dn[:, None])
    b = np.where(up, (top - cz)[:, None], (cz - bot)[:, None])
    x = cx[:, None] + (a * shrink)[:, None] * spow(c[None, :], 2.0 / n)
    z = cz[:, None] + b * shrink[:, None] * spow(s[None, :], 2.0 / n)
    y = np.broadcast_to(ys[:, None], x.shape)
    z = z - drape(x, y) * np.clip(s[None, :], 0.0, 1.0)
    P = np.stack([x, y, z], axis=-1)
    ob = K.mesh_object("MouthShell", P.reshape(-1, 3), K.grid_faces(len(ys), nu + 1), mat)
    cen = lambda q: np.stack([np.interp(q[:, 1], ys, cx), q[:, 1], np.interp(q[:, 1], ys, cz)], axis=1) - q
    K.face_toward(ob, cen)
    # UV：まわりの 長さ と おくゆき（1 = 4 m）
    du = np.concatenate([np.zeros((len(ys), 1)), np.cumsum(np.linalg.norm(np.diff(P, axis=1), axis=2), axis=1)], axis=1)
    dv = np.concatenate([[0.0], np.cumsum(np.linalg.norm(np.diff(P[:, nu // 2], axis=0), axis=1))])
    K.set_uv(ob, np.stack([du, np.broadcast_to(dv[:, None], du.shape)], axis=-1).reshape(-1, 2) / K.TILE_M)
    # 色：わ ごとに 暗く、のどの おくは さらに 暗く
    tone = np.ones((len(ys), 3))
    for i, r in enumerate(RINGS):
        k = sstep(r[0] - RING_W, r[0] + RING_W, ys)[:, None]
        tone = tone * (1.0 - k) + K.ratio(RING_HEX[i + 1], RING_HEX[0])[None, :] * k
    k = (sstep(44, Y_END, ys) ** 0.8)[:, None]
    tone = tone * (1.0 - k) + K.ratio(DEEP_HEX, RING_HEX[0])[None, :] * k
    tone = np.repeat(tone, nu + 1, axis=0)
    # 大きな 筆むら（画像の くりかえしが 目立たない ように、面ごとに ゆっくり 明るさを 変える）
    q = P.reshape(-1, 3)
    wob = (np.sin(q[:, 0] * 0.21 + q[:, 2] * 0.13 + 1.3) * np.sin(q[:, 1] * 0.17 - q[:, 2] * 0.19 + 0.4)
           + 0.6 * np.sin(q[:, 0] * 0.09 - q[:, 1] * 0.11 + q[:, 2] * 0.23 + 2.1))
    k = (0.5 + 0.5 * np.clip(wob / 1.6, -1.0, 1.0))[:, None] * 0.10
    tone = tone * (1.0 - k) + tone * K.ratio("#B0303A", RING_HEX[0])[None, :] * k
    return ob, tone


def build_floor(mat):
    ys = np.concatenate([np.arange(-34.0, -17.0, 0.5), np.arange(-17.0, 25.0, 0.35), np.arange(25.0, 40.0, 0.5),
                         np.arange(40.0, Y_END, 1.25), [Y_END]])
    nu = 81
    p = np.linspace(-1.0, 1.0, nu)
    cx = shell(ys)[0]
    x = cx[:, None] + floor_half_width(ys)[:, None] * p[None, :] * 1.012
    y = np.broadcast_to(ys[:, None], x.shape)
    z = floor_h(x, y)
    z[:, 0] -= 0.25                 # ふちは かべの 中へ 少し しずめる
    z[:, -1] -= 0.25
    P = np.stack([x, y, z], axis=-1).reshape(-1, 3)
    ob = K.mesh_object("MouthFloor", P, K.grid_faces(len(ys), nu), mat)
    K.face_toward(ob, lambda q: np.tile([0.0, 0.0, 1.0], (len(q), 1)))
    K.set_uv(ob, P[:, :2] / K.TILE_M)
    # 色：したは 明るい ピンク、ふちは 少し こく、したの まわりの ゆかは 赤く、のどの すべりだいは おくへ 暗く
    s = tongue_s(x, y).reshape(-1)
    yy = y.reshape(-1)
    xx = x.reshape(-1)
    # 雰囲気画：したの まんなか #FA7785、ふち #F66B7C、ぶつぶつの 上 #FD8E96（REF）。したの そとの ゆかと のどの すべりだいは 暗く
    tone = np.tile(K.ratio("#FA7785", REF["floor"]), (len(P), 1))
    bump = np.zeros(len(P))
    for px, py, dia in PAPILLAE:
        bump = np.maximum(bump, 1.0 - sstep(0.15, 0.95, np.hypot(xx - px, yy - py) / (dia * 0.5)))
    foot = np.zeros(len(P))
    for px, py, dia in PAPILLAE:
        u = np.hypot(xx - px, yy - py) / (dia * 0.5)
        foot = np.maximum(foot, np.exp(-((u - 1.0) / 0.14) ** 2))
    tone = tone * (1.0 - bump[:, None]) + bump[:, None]
    tone = tone * (1.0 - 0.1 * foot[:, None])     # ぶつぶつの ねもとは 少し こく（雰囲気画の かげ）
    ridge = (np.cos(yy * (2 * math.pi / RIDGE_M)) * (1.0 - sstep(0.45, 0.8, s)) * sstep(-13, -7, yy) * (1.0 - sstep(16, 24, yy)))[:, None]
    tone = tone * (1.0 + 0.035 * ridge)          # すじの 山は 少し 明るく、谷は 少し 暗く（雰囲気画の しま）
    edge = (sstep(0.55, 0.92, s) * 0.8)[:, None]
    tone = tone * (1.0 - edge) + K.ratio("#F66B7C", REF["floor"])[None, :] * edge
    out = sstep(0.93, 1.06, s)[:, None]
    tone = tone * (1.0 - out) + K.ratio("#DC4658", REF["floor"])[None, :] * out
    line = (0.45 * np.exp(-(xx / 1.1) ** 2) * sstep(-15, -5, yy) * (1.0 - sstep(28, 36, yy)))[:, None]
    tone = tone * (1.0 - line) + K.ratio("#E9566E", REF["floor"])[None, :] * line
    for a_y, b_y, hexc in ((24.0, 40.0, "#D8475F"), (40.0, GOAL_Y, "#B23A50"), (GOAL_Y + 6.0, Y_END, "#5E1A2B")):
        k = sstep(a_y, b_y, yy)[:, None]
        tone = tone * (1.0 - k) + K.ratio(hexc, REF["floor"])[None, :] * k
    return ob, tone


# は（歯）の 大きさ：納品の spec（art/concepts/W3_stages/spec.md）の 表の m（はば × おくゆき × 高さ。高さは 根を ふくむ）。
# ゲームの 中では TOOTH_G 倍（口ぜんたいが spec の 約 2 倍：ゲームの カメラは 雰囲気画より 遠いので、絵と 同じ 見えかたに なる 大きさ）
TOOTH_SPEC = {"incisor": (1.25, 0.55, 2.0, 0.45), "canine": (0.9, 0.85, 2.2, 0.5), "molar": (1.8, 1.45, 2.4, 0.5)}
TOOTH_G = 2.2
TOOTH_GAP = 0.35       # はと はの すきま（m。こどもの はには すきまが ある）
GERM_GAP = 2.0         # むしばきんが 顔を 出す すきま（したの おくから 2・3 本目の あいだ）


def tooth_layout(arch, upper):
    """アーチに そった はの ならび。[(種類, s（弧の 位置）, はば, おくゆき, 高さ, 根の 長さ)]。
    まんなかから 左右に 6 本ずつ（7 さい：まえば 2・いときりば 1・おくば 3）。大きさは spec × TOOTH_G × 1 本ずつの 倍率。"""
    if upper:
        order = [("incisor", 1.15, 1.1), ("incisor", 0.9, 0.95), ("canine", 1.0, 1.05),
                 ("molar", 0.82, 0.9), ("molar", 0.92, 0.95), ("molar", 1.0, 1.0)]
    else:
        order = [("incisor", 0.95, 0.95), ("incisor", 1.0, 1.0), ("canine", 1.0, 1.0),
                 ("molar", 0.85, 0.92), ("molar", 0.95, 0.97), ("molar", 1.05, 1.0)]
    _P, _T, _N, S = arch_curve(arch)
    half = S[-1] * 0.5
    out = []
    pos = TOOTH_GAP * 0.5
    for i, (kind, kw, kh) in enumerate(order):
        sw, sd, sh, sr = TOOTH_SPEC[kind]
        w, d, h, r = sw * kw * TOOTH_G, sd * kw * TOOTH_G, sh * kh * TOOTH_G, sr * TOOTH_G
        for side in (-1, 1):
            out.append((kind, half + side * (pos + w * 0.5), w, d, h, r))
        pos += w + (GERM_GAP if (not upper and i == 4) else TOOTH_GAP)
    return out


def _lathe(zs, rx, ry, n_sec, nu):
    """たての 軸の まわりの 形（断面は スーパーだ円）。zs・rx・ry は 下から 上への 列。上下は とじる。
    返す：点、四角形、三角形（外向き）"""
    th = np.linspace(0.0, 2 * math.pi, nu, endpoint=False)
    cu, su = spow(np.cos(th), 2.0 / n_sec), spow(np.sin(th), 2.0 / n_sec)
    X = rx[:, None] * cu[None, :]
    Y = ry[:, None] * su[None, :]
    Z = np.broadcast_to(np.asarray(zs)[:, None], X.shape)
    body = np.stack([X, Y, Z], axis=-1).reshape(-1, 3)
    rows = len(zs)
    V = np.concatenate([body, [[0.0, 0.0, zs[0]]], [[0.0, 0.0, zs[-1]]]])
    quads = K.grid_faces(rows, nu, wrap_u=True)[:, ::-1]
    south, north = len(body), len(body) + 1
    tris = []
    for j in range(nu):
        j2 = (j + 1) % nu
        tris.append((south, j, j2))
        tris.append((north, (rows - 1) * nu + j2, (rows - 1) * nu + j))
    return V, quads, np.array(tris)


def tooth_mesh(kind, w, d, h, root, rng, fine=False):
    """は 1 本（はぐきの てっぺんが 原点、z が のびる 向き。根は z < 0 で はぐきに うまる）。
    形は 納品の 三面図（parts_mouth_front/_side.png）：
      まえば  うすい 板。正面は 角の まるい 四角、よこから 見ると さきへ うすく なる
      いときりば  たかい しずく。さきは とがらせず まるく
      おくば  まるい 箱。てっぺんに 大きな まるい やま（はばに 3 つ・おくゆきに 2 つ）
    返す：点、四角形、三角形、高さの 割合（0 = 根の さき、1 = てっぺん）"""
    hc = h - root                      # はぐきから 出て いる 高さ
    if kind == "molar":
        nu, nv = (88, 52) if fine else (40, 26)
        V, Q, T3 = K.superellipsoid(nu, nv, 0.42, 0.5)
        x, y, z = V[:, 0].copy(), V[:, 1].copy(), V[:, 2].copy()
        zt = (z + 1.0) * 0.5
        zz = -root + zt * h
        neck = 0.72 + 0.28 * sstep(-root * 0.6, hc * 0.3, zz)     # 根は ほそく、はぐきの 上で ふくらむ
        x *= neck
        y *= neck
        top = sstep(0.62, 0.95, zt)
        lobes = sum(np.exp(-(((x - cx) / 0.31) ** 2 + ((y - cy) / 0.38) ** 2))
                    for cx in (-0.6, 0.0, 0.6) for cy in (-0.45, 0.45))
        zz = zz + top * hc * (0.15 * np.clip(lobes, 0.0, 1.0) - 0.12)
        jit = 1.0 + rng.uniform(-0.03, 0.03)
        P = np.stack([x * w * 0.5 * jit, y * d * 0.5, zz], axis=1)
        return P, Q, T3, zt
    nz = 30
    zs = np.concatenate([np.linspace(-root, 0.0, 6)[:-1], np.linspace(0.0, hc, nz)])
    zc = np.clip(zs / hc, 0.0, 1.0)                 # はぐきから 上の 割合
    zr = np.clip(1.0 + zs / root, 0.0, 1.0)         # 根の さきから はぐきまでの 割合
    rootk = np.where(zs < 0, 0.45 + 0.4 * zr, 1.0)
    if kind == "incisor":
        body = 0.86 + 0.14 * sstep(0.0, 0.3, zc)
        cap = np.sqrt(np.clip(1.0 - (np.clip(zc - 0.8, 0.0, None) / 0.2) ** 2, 0.0, 1.0))
        rx = 0.5 * w * body * rootk * np.maximum(cap, 0.0) ** 0.5
        ry = 0.5 * d * (1.0 - 0.45 * sstep(0.25, 1.0, zc)) * rootk * np.maximum(cap, 0.0) ** 0.9
        n_sec = 3.0
    else:  # canine
        u = np.clip((zc - 0.3) / 0.7, 0.0, 1.0)
        prof = (0.88 + 0.12 * sstep(0.0, 0.3, zc)) * (1.0 - u ** 1.8) ** 0.62
        rx = 0.5 * w * prof * rootk
        ry = 0.5 * d * prof * rootk
        n_sec = 2.2
    rx[-1] = ry[-1] = 0.0
    V, Q, T3 = _lathe(zs, np.maximum(rx, 1e-3), np.maximum(ry, 1e-3), n_sec, 32)
    V[:, 0] *= 1.0 + rng.uniform(-0.03, 0.03)
    zt = np.concatenate([np.repeat((zs + root) / h, 32), [0.0, 1.0]])
    return V, Q, T3, zt


# むしば（した の いちばん おくの は、左右）：(ならびの 番号, あなの 位置（はば・おくゆき・高さの 割合）, 半径 m)
# 位置は はの 中の 向き：x ＝ ならびに そって、y ＝ −1 が した（舌）の がわ、z ＝ 1 が てっぺん
CAVITIES = {10: ((0.45, -0.72, 0.7), 0.95), 11: ((-0.4, -0.75, 0.74), 1.1)}


def build_teeth(mat, arch, upper, crest_fn, rng, tag):
    P, T, N, S = arch_curve(arch)
    objs = []
    tones = []
    for i, (kind, s, w, d, h, root) in enumerate(tooth_layout(arch, upper)):
        k = int(np.argmin(np.abs(S - s)))
        decayed = not upper and i in CAVITIES
        V, Q, T3, zt = tooth_mesh(kind, w, d, h, root, rng, fine=decayed)
        hc = h - root
        hole = np.zeros(len(V))
        if decayed:
            # むしばの あな：まるく へこませて、中を こげ茶に（この お話の げんいん。むしばきんは この そばに いる）
            (ax, ay, az), rad = CAVITIES[i]
            rel = V - np.array([ax * w * 0.5, ay * d * 0.5, az * hc])
            ang = np.arctan2(rel[:, 2], rel[:, 0])
            dist = np.linalg.norm(rel, axis=1) / (1.0 + 0.12 * np.sin(ang * 3.0 + i))   # まんまるに しない
            hole = 1.0 - sstep(rad * 0.55, rad, dist)
            V = V - (V - np.array([0.0, 0.0, hc * 0.45])) * (0.16 * sstep(0.2, 1.0, hole)[:, None])
        yaw = rng.uniform(-0.05, 0.05)
        tx = T[k] * math.cos(yaw) + N[k] * math.sin(yaw)
        ny = N[k] * math.cos(yaw) - T[k] * math.sin(yaw)
        lean = rng.uniform(-0.03, 0.03)
        zdir = -1.0 if upper else 1.0
        base = np.array([P[k, 0], P[k, 1], crest_fn(S[k])])
        W = (base[None, :] + V[:, 0:1] * np.array([tx[0], tx[1], 0.0])[None, :]
             + (V[:, 1:2] + V[:, 2:3] * lean) * np.array([ny[0], ny[1], 0.0])[None, :]
             + V[:, 2:3] * np.array([0.0, 0.0, zdir])[None, :])
        ob = K.blob_object(f"tooth_{tag}_{i}", W, Q, T3, mat)
        C.recalc_normals(ob, inside=False)
        objs.append(ob)
        g = sstep(0.25, 0.8, zt)[:, None]           # ねもとは 少し あたたかい 色
        tone = K.ratio("#F6D5BC", REF["tooth"])[None, :] * (1.0 - g) + g
        stain = sstep(0.0, 0.35, hole)[:, None]
        tone = tone * (1.0 - stain) + K.ratio("#DDB89E", REF["tooth"])[None, :] * stain
        pit = sstep(0.25, 0.9, hole)[:, None]
        tones.append(tone * (1.0 - pit) + K.ratio("#5E4244", REF["tooth"])[None, :] * pit)
    return objs, tones


def build_gum(mat, arch, upper, crest_fn, name):
    """はぐき：アーチに そった 太い うね。はの ところで ふくらみ、はと はの あいだで 少し もりあがる。"""
    P, T, N, S = arch_curve(arch, 0.5)
    lay = sorted(tooth_layout(arch, upper), key=lambda t: t[1])
    centers = np.array([t[1] for t in lay])
    widths = np.array([t[2] for t in lay])
    near = np.argmin(np.abs(S[:, None] - centers[None, :]), axis=1)
    ph = np.clip(np.abs(S - centers[near]) / (widths[near] * 0.5 + 0.75), 0.0, 1.0)   # 0 = はの まんなか、1 = はと はの あいだ
    bulge = 0.5 * (1.0 + np.cos(ph * math.pi))
    gw = GUM_W - 0.25 + 0.4 * bulge
    crest = crest_fn(S) + (-1.0 if upper else 1.0) * 0.4 * (1.0 - bulge)
    zdir = -1.0 if upper else 1.0
    m = 20
    ph2 = np.linspace(0.0, 2 * math.pi, m, endpoint=False)
    cu, cs = spow(np.cos(ph2), 2.0 / 3.2), spow(np.sin(ph2), 2.0 / 3.2)
    # おくの はしは かべに うめる（まっすぐ のばして しぼる）
    ext = np.array([1.5, 3.0, 3.6])
    Pk = np.concatenate([P[0] - T[0] * ext[::-1, None], P, P[-1] + T[-1] * ext[:, None]])
    Nk = np.concatenate([np.repeat(N[:1], 3, axis=0), N, np.repeat(N[-1:], 3, axis=0)])
    gwk = np.concatenate([gw[0] * np.array([0.05, 0.8, 1.0]), gw, gw[-1] * np.array([1.0, 0.8, 0.05])])
    ghk = np.concatenate([GUM_H * np.array([0.05, 0.8, 1.0]), np.full(len(S), GUM_H), GUM_H * np.array([1.0, 0.8, 0.05])])
    crk = np.concatenate([np.repeat(crest[:1], 3), crest, np.repeat(crest[-1:], 3)])
    zc = crk - zdir * GUM_H
    X = Pk[:, 0:1] + Nk[:, 0:1] * gwk[:, None] * cu[None, :]
    Y = Pk[:, 1:2] + Nk[:, 1:2] * gwk[:, None] * cu[None, :]
    Z = zc[:, None] + ghk[:, None] * cs[None, :]
    V = np.stack([X, Y, Z], axis=-1).reshape(-1, 3)
    ob = K.mesh_object(name, V, K.grid_faces(len(Pk), m, wrap_u=True), mat)
    C.recalc_normals(ob, inside=False)
    return ob


# のどちんこ と へんとうせん（spec の 部品 5・6）の 大きさ：spec の m × TOOTH_G
UVULA_SPEC = (0.7, 0.65, 1.7)
TONSIL_SPEC = (1.0, 0.7, 1.5)


def build_uvula(mat, root):
    """のどちんこ：天井から さがる しずく（正面は 花びん形：ねもとが ひろがり、くびれて、下が まるく ふくらむ）。
    原点は ねもと（Godot 側が ここを 中心に ゆらす）"""
    w, d, h = (v * TOOTH_G for v in UVULA_SPEC)
    UP = 2.4                        # ねもとから 上へ 2.4 m は 天井の 中（すきまが 見えない ように）
    t = np.linspace(-UP / h, 1.0, 34)          # 0 = ねもと、1 = 下の はし
    r = 0.31 * w + 0.4 * w * (1.0 - sstep(-0.1, 0.32, t)) ** 2 + 0.2 * w * np.exp(-((t - 0.76) / 0.17) ** 2)
    r = r * np.sqrt(np.clip(1.0 - np.clip((t - 0.84) / 0.16, 0.0, 1.0) ** 2, 0.0, 1.0))
    r[-1] = 0.02
    nu = 20
    th = np.linspace(0.0, 2 * math.pi, nu, endpoint=False)
    X = r[:, None] * np.cos(th)[None, :]
    Y = r[:, None] * np.sin(th)[None, :] * (d / w)
    Z = np.broadcast_to((-t * h)[:, None], X.shape)
    V = np.stack([X, Y, Z], axis=-1).reshape(-1, 3) + np.array(root)
    ob = K.mesh_object("NC_Uvula", V, K.grid_faces(len(t), nu, wrap_u=True), mat, location=tuple(root))
    K.face_toward(ob, lambda q: (q - np.array([root[0], root[1], 0.0])) * np.array([1.0, 1.0, 0.0]))
    return ob


def build_tonsils(mat):
    """へんとうせん：のどの 入口の 左右に 1 つずつ。まるい たまごで、うらは かべに うめる（三面図の よこ：うしろが 平ら）"""
    w, d, h = (v * TOOTH_G * TONSIL_K for v in TONSIL_SPEC)
    tons = []
    for sx in (-1, 1):
        V, Q, T3 = K.superellipsoid(24, 16, 0.92, 0.92)
        V[:, 1] = np.minimum(V[:, 1], 0.55)               # うしろ（おく）は 平ら
        a = float(shell(TONSIL_Y)[2])
        c = np.array([sx * (a - w * 0.5 - TONSIL_IN), TONSIL_Y, float(floor_h(sx * (a - w * 0.5 - TONSIL_IN), TONSIL_Y)) + h * 0.42])
        tons.append(K.blob_object(f"tonsil{sx}", V * np.array([w * 0.5, d * 0.5, h * 0.5]) + c, Q, T3, mat))
    return K.join_meshes(tons, "Tonsils")


TONSIL_Y = 29.0
TONSIL_IN = 0.4
TONSIL_K = 2.0   # spec の 2 倍（とおくに あるので、雰囲気画の 大きな まるい へんとうせんに 見える 大きさ）


def build_lips(mat):
    """くちびる：入口の ふちの まるい わ"""
    n, m = 72, 14
    th = np.linspace(0.0, 2 * math.pi, n, endpoint=False)
    ph = np.linspace(0.0, 2 * math.pi, m, endpoint=False)
    a, b, r = 11.9, 6.3, 1.8
    cx, cz = a * np.cos(th), CZ + b * np.sin(th)
    nx, nz = b * np.cos(th), a * np.sin(th)
    nl = np.hypot(nx, nz)
    nx, nz = nx / nl, nz / nl
    X = cx[:, None] + nx[:, None] * r * np.cos(ph)[None, :]
    Z = cz[:, None] + nz[:, None] * r * np.cos(ph)[None, :]
    Y = Y_LIPS + 0.4 + r * 0.8 * np.sin(ph)[None, :] + np.zeros_like(X)
    ob = K.mesh_object("NC_Lips", np.stack([X, Y, Z], axis=-1).reshape(-1, 3), K.grid_faces(n, m, wrap_u=True, wrap_v=True), mat)
    C.recalc_normals(ob, inside=False)
    return ob


def build_outside(mat):
    """くちびるの むこうの 明るい「おそと」。当たり判定つきの ふた。"""
    n = 40
    th = np.linspace(0.0, 2 * math.pi, n, endpoint=False)
    V = np.concatenate([[[0.0, Y_LIPS - 1.6, CZ]], np.stack([18.0 * np.cos(th), np.full(n, Y_LIPS - 1.6), CZ + 12.0 * np.sin(th)], axis=1)])
    F = np.array([(0, 1 + i, 1 + (i + 1) % n) for i in range(n)])
    ob = K.mesh_object("Outside", V, F, mat)
    K.face_toward(ob, lambda q: np.tile([0.0, 1.0, 0.0], (len(q), 1)))
    return ob


# ------------------------------------------------------------------ 組み立て
def build():
    rng = random.Random(7)
    mats = {k: K.surface_material("Stage" + k.capitalize(), v, emission=v if k == "sky" else None) for k, v in HEX.items()}
    lower_len = arch_curve(LOWER)[3][-1]
    upper_len = arch_curve(UPPER)[3][-1]

    def lower_crest(s):
        """したの はぐきの てっぺん：おくは 高く、まえは 低い（あごが ひらいて いる）"""
        f = np.abs(np.asarray(s, dtype=float) / lower_len - 0.5) * 2.0   # 0 = まえ、1 = おく
        return -5.4 + 2.8 * sstep(0.15, 0.85, f)

    def upper_crest(s):
        f = np.abs(np.asarray(s, dtype=float) / upper_len - 0.5) * 2.0
        return UPPER_CREST[0] + (UPPER_CREST[1] - UPPER_CREST[0]) * sstep(0.15, 0.85, f)

    shell_o, shell_tone = build_shell(mats["wall"])
    floor_o, floor_tone = build_floor(mats["floor"])
    gum_l = build_gum(mats["gum"], LOWER, False, lower_crest, "gum_lower")
    gum_u = build_gum(mats["gum"], UPPER, True, upper_crest, "gum_upper")
    teeth_l, tone_l = build_teeth(mats["tooth"], LOWER, False, lower_crest, rng, "l")
    teeth_u, tone_u = build_teeth(mats["tooth"], UPPER, True, upper_crest, rng, "u")
    for o, t in zip(teeth_l + teeth_u, tone_l + tone_u):
        K.set_colors(o, t)
    teeth = K.join_meshes(teeth_l + teeth_u, "Teeth")
    gums = K.join_meshes([gum_l, gum_u], "Gums")
    tonsils = build_tonsils(mats["soft"])
    uvula = build_uvula(mats["soft"], (0.0, UVULA_Y, float(ceil_z(0.0, UVULA_Y))))
    lips = build_lips(mats["lip"])
    outside = build_outside(mats["sky"])
    objs = [shell_o, floor_o, gums, teeth, tonsils, uvula, lips, outside]

    # かげの 焼きこみ：形が くっつく ところを やわらかく 暗く（赤みを のこす）
    ao = K.bake_ao(objs, reach=5.5, rays=24, smooth=2, exclude=("Outside",))
    K.set_colors(shell_o, shell_tone * K.shade(ao[shell_o.name], (0.58, 0.38, 0.46), 1.25))
    K.set_colors(floor_o, floor_tone * K.shade(ao[floor_o.name], (0.52, 0.28, 0.36), 1.25))
    K.set_colors(gums, K.shade(ao[gums.name], (0.6, 0.4, 0.46), 1.1))
    K.set_colors(teeth, K.get_colors(teeth) * K.shade(ao[teeth.name], (0.86, 0.68, 0.62), 1.0))
    K.set_colors(tonsils, K.ratio("#EC565C", REF["soft"])[None, :] * K.shade(ao[tonsils.name], (0.5, 0.28, 0.34), 1.2))
    K.set_colors(uvula, K.shade(ao[uvula.name], (0.6, 0.34, 0.4), 1.0))
    K.set_colors(lips, K.shade(ao[lips.name], (0.6, 0.34, 0.4), 1.0))
    oz = K.world_verts(outside)[:, 2]          # おそと：上は うすい 空色、下は あたたかい 白
    K.set_colors(outside, K.rgb("#FFF4DC")[None, :] + (K.rgb("#BFE3FF") - K.rgb("#FFF4DC"))[None, :] * sstep(CZ - 5.0, CZ + 6.0, oz)[:, None])
    print(f"  mouth: {K.triangle_count(objs)} triangles")

    # マーカー（高さは ゆかの 式から）
    def fz(x, y, up=1.2):
        return float(floor_h(x, y)) + up

    C.add_empty("MK_player", (0, START_Y, fz(0, START_Y, 1.5)))
    goal = (0.0, GOAL_Y, fz(0, GOAL_Y, 0.8))
    C.add_empty("MK_goal", goal)
    C.add_empty("MK_checkpoint_1", (0, 37, fz(0, 37, 0.5)))
    # むしばきん 4 ひき（雰囲気画：はと はの あいだから 顔を 出す）。左右 2 ひきずつ：
    # したの おくから 1・2 本目の あいだの すきま（GERM_GAP。むしばの はの となり）と、いちばん おくの はの うしろ。
    # 高さは はぐきの てっぺん（ゆかの 式の 外なので crest から）
    P, _T, N, S = arch_curve(LOWER)
    lay = sorted(tooth_layout(LOWER, False), key=lambda t: t[1])
    spots = [(lay[1][1] - lay[1][2] * 0.5 + lay[0][1] + lay[0][2] * 0.5) * 0.5,
             (lay[-2][1] + lay[-2][2] * 0.5 + lay[-1][1] - lay[-1][2] * 0.5) * 0.5,
             lay[0][1] - lay[0][2] * 0.5 - 1.3, lay[-1][1] + lay[-1][2] * 0.5 + 1.3]
    germ = []
    for s in spots:
        k = int(np.argmin(np.abs(S - s)))
        germ.append((P[k, 0] - N[k, 0] * 1.2, P[k, 1] - N[k, 1] * 1.2, float(lower_crest(S[k])) + 1.1))
    germ.sort(key=lambda p: (p[0] > 0, p[1]))
    for i, p in enumerate(germ):
        C.add_empty(f"MK_enemy_mushiba_{i + 1}", p)
    C.add_empty("MK_pickup_heart_item_1", (8, -1, fz(8, -1, 1.0)))
    C.add_empty("MK_card_tooth", (-10.5, -11.5, fz(-10.5, -11.5, 1.0)))
    C.add_empty("MK_sign_throat", (0, 27, fz(0, 27, 1.0)))
    for i, y in enumerate((START_Y, 5.0, 28.0, 52.0)):
        C.add_empty(f"MK_path_{i:03d}", (0, y, fz(0, y)))
    C.add_empty("MK_path_004", goal)
    return objs

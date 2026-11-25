"""い（胃）の かべの さいぼう（wallcell）。い（胃）の ステージの なかま（さわって おうえんする。動かない）。

納品された 3D 用の絵（art/concepts/W2_friends/ の wallcell_3d_*・wallcell_faces）から 測った 寸法で 作る。
寸法・色・絵との ちがいは docs/art_orders/W2_02_wallcell_3D化の結果.md。

・前は +Y、上は +Z、単位は m。本人の 右は +X（正面の 絵では 左）。
・寸法は 絵の 座標（ゆか ＝ z 0、てっぺん ＝ z 1.6）で 書き、原点を OZ に ずらして から 全体を SCALE（0.75）倍 する
  （ゲームでは 高さ 1.2 m。原点は 底から 0.97 m 上で、friend.gd が 置く 高さに 合わせて 底が ゆかの すぐ 上に くる）。
・体：角の 丸い 箱（超だ円体。正面と 真横の 外形の 幅を 高さ 0.1 m ごとに 測って 合わせた。下 半分が 少し 広い）。
・ねんえき：体の 上に かぶさる 1 つの かたまり（体を 5 cm ふくらませた 面＋高い こぶ＋低い こぶを なめらかに つないだ 形）。
  下の ふちは 大きな 波 3 つ（深さを 向きで かえて そろわない ように した）。高い こぶは 本人の 左うしろ、低い こぶは 右まえ（取り込みの 決め）。
  形は 式（陰関数）で、まん中から 外へ 向けた 線との 交わりで 面を 作る。
・顔（白目・黒目・光・口）は 体の 前の 面に はった うすい ふくらみ。表情シートの「通常」（線の 笑顔）で、目は 正面の 絵の 位置。
・うれしい 口（3D 用の 絵の 開いた 口と 舌）は 別の ノード MouthHappy（本体の 子）。線の 笑顔より 高く ふくらませて、
  見える ときは 線の 笑顔を すっぽり かくす。ゲームは おうえん される まで かくす（friend.gd）。
・色は 部品ごとに 1 色で、絵の 色の まま（い（胃）の 光を 2 回目で 変えた。下の COL）。ねんえきの ふちの 下の うすい 影と、
  下を 向いた 面の 少しの 暗さは 頂点カラー（Col）に 焼いて ある。
  シェーダー・テクスチャ・半透明は 使わない。作りの 道具は blender/pod.py と 共通。

実行: python -m blender.characters wallcell
"""
from __future__ import annotations

import math

import bpy
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


# ------------------------------------------------------------------ 寸法（m。絵の 座標：ゆか z 0、てっぺん z 1.6）
# 縮尺：絵ごとに 外形の 高さ ＝ 1.6 m（正面 1091 px、背面 1075 px、真横 1028 px → 1.47／1.49／1.56 mm/px）
# さいごに 全体を SCALE 倍 する（ゲームでは 高さ 1.2 m。船（1.4 m）が おうえんで ちかづいても 船が かくれない 大きさ）。
SCALE = 0.75
# 原点（1 回目の friend.gd が ゆかから 0.9 ＋ radius·0.3 ＝ 1.17 m に 置く 点）。ちぢめた あとで 原点の 0.97 m 下が 底。
# 2 回目から ゲームは モデルの 外形の 箱で いちばん 下を ゆかの 0.05 m 下に 置くので、原点の 高さは 関係ない（そのまま に した）。
# 絵の 座標では ゆかから 0.97 / SCALE。
OZ = 0.97 / SCALE

# 体：(( |x/a|^m + |y/b|^m )^(n/m) + |(z-zc)/c|^n)^(1/n) ＝ 1。c は まん中より 下が c0、上が c1
BODY = dict(a=0.662, b=0.550, m=2.2, n=2.7, zc=0.52, c0=0.54, c1=0.58)

# ねんえき（絵の 外形と ねんえきの 色の 所に 合わせた。docs の 2 章）
MUCUS = dict(
    off=0.05,                       # 体を ふくらませた 面が 土台（ふちは 体と ほぼ 同じ 幅）
    dc=(-0.10, -0.09, 1.10),        # 高い こぶ（本人の 左うしろ）の 中心と 半径
    dr=(0.505, 0.464, 0.495),
    lc=(0.27, 0.25, 1.05),          # 低い こぶ（右まえ）
    lr=(0.354, 0.312, 0.289),
    k=0.20, k2=0.15,                # つなぎめの なめらかさ（大きいほど なめらか）
    zl=0.912, zl2=-0.03, wa=0.07,    # 下の ふちの 高さ：zl + zl2·cos2φ − wa·cos(wn·(φ − wp)) − wa2·cos(φ − wp2)（φ ＝ 0 が 本人の 右）
    wn=3.0, wp=1.85,                # 大きな 波 3 つ（たれは 顔の まん中より 少し 左・右うしろ・左うしろ）
    wa2=0.02, wp2=2.6,              # ゆがみ（波の 深さを 向きで かえる。たれが そろわない ように）
    kl=0.14,                        # ふちの 丸み
)
MUCUS_C = (0.0, 0.0, 1.12)          # 面を 作る ときの まん中（ここから 見て 面が 1 回だけ 交わる）

# 顔（正面の 絵の 座標。u ＝ 本人の 右 ＋、z ＝ 絵の 高さ。3D の X ＝ u）
EYE_U = 0.246               # 白目の まん中（左右）
EYE_Z = 0.636
EYE_AB = (0.141, 0.168)     # 白目の 半径（横、たて）
PUPIL_IN = 0.052            # 黒目は 白目の まん中から 内がわ（はなの ほう）へ
PUPIL_DZ = -0.005
PUPIL_AB = (0.091, 0.113)
SPARK = (0.038, 0.056)      # 光の 点は 黒目の まん中から 内がわ・上（両目で 鏡）
SPARK_R = 0.022
MOUTH_HALF = 0.100          # 口（線の 笑顔）の はしまで（線の まん中）
MOUTH_END_Z = 0.415
MOUTH_LOW_Z = 0.360
MOUTH_W = 0.0195            # 線の 太さの 半分

# うれしい 口（3D 用の 絵の 開いた 口と 舌）。線の 笑顔（MOUTH_*）を すっぽり おおう 別の 部品 MouthHappy。
# 正面の 絵で 測った（口の 中 #962C1B：幅 u −0.168〜+0.130、高さ z 0.278〜0.463。上の ふちは 両はしが 少し 高い
# ゆるい 弓、下は 丸い U。舌 #E55E45 は 下 半分で、上の ふちが 山なり（まん中 z 0.384）。
# 絵の 口は 2 cm ほど 本人の 左へ よるが、線の 笑顔を どこでも おおう ように まん中に 置いた。
HAPPY_W = 0.150             # 口の 半幅
HAPPY_ZC = 0.452            # 下の U の 中心の 高さ（U は ここから 下へ HAPPY_B）
HAPPY_B = 0.174
HAPPY_P = 2.3               # U の 丸さ（超だ円の 指数）
HAPPY_TOP_RISE = 0.014      # 上の ふちの 両はしの 上がり（まん中は HAPPY_ZC）
TONGUE_TOP = 0.384          # 舌の 上の ふちの まん中
TONGUE_DROP = 0.050         # 舌の 上の ふちが はしで 下がる 量（u ＝ ±HAPPY_W で）
TONGUE_INSET = 0.006        # 舌は 口の ふちから これだけ 内がわ（ふちに こい 赤が 細く のこる）

H_WHITE = 0.010
H_PUPIL = 0.007
H_SPARK = 0.004
H_MOUTH = 0.006
H_HAPPY = 0.013             # 線の 笑顔（0.006）より 高く。ふちの 近くでも 線の 笑顔より 上に ある
H_TONGUE = 0.003
SINK = 0.005

# ------------------------------------------------------------------ 色（sRGB）
# 絵の 色の まま（2 回目。絵の 平らな 所の 中央値：体 正面 #F6A260・背面 #F3A161・真横 #F7A05C、ねんえき 正面 #B0E3E3・
# 背面 #B2E1E0・真横 #A8DFDE。spec は #ECA66F／#9EDCE5）。い（胃）の 光を 変えて（stage_db.gd の "look"。
# キャラクターの 光の 当たる がわが ほぼ 自分の 色）、色を ずらして おぎなう 必要が なくなった。docs の 9 章。
# 下は 1 回目の 記録（光を 変える 前）：
# 絵の 平らな 所の 中央値は 体 #F6A361、ねんえき #ADE1E1（spec は #ECA66F／#9EDCE5）。
# い（胃）の ステージは キャラクターに 当たる 光が 強い（たいようが カメラの がわから 当たり、まわりの 光 0.55・
# ミクロごうの ライト・トーンマップ linear）。絵の 色の ままだと、うしろから 見た 体が 黄色（255, 232, 129）、
# ねんえきが まっ白（253, 255, 255）に とんで「光る 黄色」や クリームの おかしに 見えた。
# 光は 緑・青を 約 1.45 倍・1.3 倍に する（赤は 255 で 止まる）。そこで 体は 明るさを 落とさずに 緑・青を へらした 色に して、
# ゲームの カメラから 見た 光の 当たる 面が 絵の 色 (255, 174, 104) に なる ように した（前の #CC8650 は カードで どんぐりの
# ような 茶色に なった。#E0945A では うしろが 黄色 (255, 215, 114) に とんだ）。カード・スタジオでは 絵より 赤い オレンジ。docs の 3 章。
COL = {
    "body": "#F3A161",
    "mucus": "#ADE0E0",
    "white": "#FCF3EC",     # 白目・光の 点（spec は #FFF9F1）
    "pupil": "#35251C",     # 黒目（spec は #202333。絵は こげ茶）
    "mouth": "#A93824",     # 口の 線（表情シートの「通常」）
    "mouth_open": "#962C1B",  # うれしい 口の 中（3D 用の 絵）
    "tongue": "#E55E45",      # 舌
}
ROUGH = {"body": 0.85, "mucus": 0.8, "white": 0.9, "spark": 0.5, "pupil": 0.45, "mouth": 0.9,
         "mouth_open": 0.9, "tongue": 0.8}


# ------------------------------------------------------------------ 体
def body_q(p):
    """体の 式の 値（1 で 面、小さいと 中）。p は (…, 3)。"""
    B = BODY
    x, y, z = p[..., 0], p[..., 1], p[..., 2]
    c = np.where(z < B["zc"], B["c0"], B["c1"])
    s = np.abs(x / B["a"]) ** B["m"] + np.abs(y / B["b"]) ** B["m"]
    return (s ** (B["n"] / B["m"]) + np.abs((z - B["zc"]) / c) ** B["n"]) ** (1.0 / B["n"])


def body_grad(p):
    B = BODY
    x, y, z = p[..., 0], p[..., 1], p[..., 2]
    m, n = B["m"], B["n"]
    c = np.where(z < B["zc"], B["c0"], B["c1"])
    s = np.abs(x / B["a"]) ** m + np.abs(y / B["b"]) ** m
    k = np.maximum(s, 1e-12) ** (n / m - 1.0)
    gx = k * np.abs(x / B["a"]) ** (m - 1.0) * np.sign(x) / B["a"]
    gy = k * np.abs(y / B["b"]) ** (m - 1.0) * np.sign(y) / B["b"]
    dz = (z - B["zc"]) / c
    gz = np.abs(dz) ** (n - 1.0) * np.sign(dz) / c
    g = np.stack([gx, gy, gz], axis=-1)
    return g / np.linalg.norm(g, axis=-1, keepdims=True)


def build_body(m_body, nu=60, nv=36):
    """まん中 (0, 0, zc) から 見た 向きごとに 面までの 距離 ＝ 1 / q（式が 1 次の 同次なので）。"""
    ctr = np.array([0.0, 0.0, BODY["zc"]])
    rings = P.unit_rings(nu, nv)
    poles = [np.array([0.0, 0.0, 1.0]), np.array([0.0, 0.0, -1.0])]

    def on(d):
        d = np.asarray(d, dtype=float)
        return ctr + d / body_q(ctr + d)[..., None]   # q は まん中から 1 次の 同次

    verts, faces = P.skin(on(rings), on(poles[0]), on(poles[1]))
    verts = np.array(verts) - np.array([0.0, 0.0, OZ])
    return P.mesh_obj("wallcell_body", verts, faces, m_body, inside=ctr - np.array([0.0, 0.0, OZ]))


# ------------------------------------------------------------------ ねんえき
def _smin(a, b, k):
    h = np.clip(0.5 + 0.5 * (b - a) / k, 0.0, 1.0)
    return b * (1.0 - h) + a * h - k * h * (1.0 - h)


def _ell(p, c, r):
    q = np.sqrt((((p - np.asarray(c)) / np.asarray(r)) ** 2).sum(axis=-1))
    return (q - 1.0) * min(r)


def mucus_field(p):
    """ねんえきの 式（負 ＝ 中）。絵の 座標。"""
    M = MUCUS
    base = (body_q(p) - 1.0) * 0.6 - M["off"]
    mu = _smin(_smin(base, _ell(p, M["dc"], M["dr"]), M["k"]), _ell(p, M["lc"], M["lr"]), M["k2"])
    phi = np.arctan2(p[..., 1], p[..., 0])
    zl = (M["zl"] + M["zl2"] * np.cos(2.0 * phi) - M["wa"] * np.cos(M["wn"] * (phi - M["wp"]))
          - M["wa2"] * np.cos(phi - M["wp2"]))
    return -_smin(-mu, -(zl - p[..., 2]), M["kl"])


def _march(dirs, ctr, field, t_max=1.3, steps=260, refine=24):
    """ctr から dirs の 向きに 進んで、はじめて 外に 出る 所（二分法で しぼる）。"""
    ts = np.linspace(0.0, t_max, steps)
    shp = dirs.shape[:-1]
    d = dirs.reshape(-1, 3)
    inside_prev = np.ones(len(d), dtype=bool)
    lo = np.zeros(len(d))
    hi = np.full(len(d), t_max)
    found = np.zeros(len(d), dtype=bool)
    for i in range(1, steps):
        v = field(ctr + d * ts[i])
        out = (v > 0.0) & ~found
        hi[out] = ts[i]
        lo[out] = ts[i - 1]
        found |= out
        if found.all():
            break
    for _ in range(refine):
        mid = 0.5 * (lo + hi)
        v = field(ctr + d * mid[:, None])
        o = v > 0.0
        hi = np.where(o, mid, hi)
        lo = np.where(o, lo, mid)
    return (ctr + d * (0.5 * (lo + hi))[:, None]).reshape(shp + (3,))


def mucus_elevations():
    """ふちの まわり（下 40°〜下 5°）だけ 細かく。上は あらく、体に うまる 底は もっと あらく。"""
    lo = list(np.linspace(-88.0, -42.0, 5))
    band = list(np.linspace(-40.0, -6.0, 28))
    up = list(np.linspace(-2.0, 86.0, 23))
    return np.radians(np.array(lo + band + up))


def build_mucus(m_mucus, nu=80):
    ctr = np.array(MUCUS_C)
    el = mucus_elevations()
    az = np.linspace(0.0, 2.0 * np.pi, nu, endpoint=False)
    E, A = np.meshgrid(el, az, indexing="ij")
    dirs = np.stack([np.cos(E) * np.cos(A), np.cos(E) * np.sin(A), np.sin(E)], axis=-1)
    rings = _march(dirs, ctr, mucus_field)
    top = _march(np.array([[0.0, 0.0, 1.0]]), ctr, mucus_field)[0]
    bot = _march(np.array([[0.0, 0.0, -1.0]]), ctr, mucus_field)[0]
    off = np.array([0.0, 0.0, OZ])
    # skin は 1 つ目の 輪の 前に start、さいごの 輪の あとに end を つなぐ（下 → 上 の 順）
    verts, faces = P.skin(rings - off, bot - off, top - off)
    return P.mesh_obj("wallcell_mucus", verts, faces, m_mucus, inside=ctr - off)


# ------------------------------------------------------------------ 顔：体の 前の 面に はる ふくらみ
def wrap(u, v, lift):
    """正面の 絵の 座標（u ＝ X、v ＝ 絵の 高さ）を 体の 前の 面へ まっすぐ 投影し、法線の 向きに lift 浮かせる（原点 OZ へ ずらす）。"""
    B = BODY
    u = np.asarray(u, dtype=float)
    v = np.asarray(v, dtype=float)
    c = np.where(v < B["zc"], B["c0"], B["c1"])
    t = np.clip(1.0 - np.abs((v - B["zc"]) / c) ** B["n"], 0.0, None) ** (B["m"] / B["n"])
    yy = B["b"] * np.clip(t - np.abs(u / B["a"]) ** B["m"], 1e-9, None) ** (1.0 / B["m"])
    p = np.stack([u, yy, v], axis=-1)
    nrm = body_grad(p)
    p = p + nrm * np.asarray(lift, dtype=float)[..., None]
    return p - np.array([0.0, 0.0, OZ])


def bump(s):
    s = np.clip(np.asarray(s, dtype=float), 0.0, 1.0)
    return (1.0 - s ** 4) ** 0.25


RINGS = (0.5, 0.78, 0.9, 0.96, 1.0)


def ellipse_height(u, v, c, ab, h):
    s = np.sqrt(((u - c[0]) / ab[0]) ** 2 + ((v - c[1]) / ab[1]) ** 2)
    return np.where(s < 1.0, h * bump(s), 0.0)


def decal_ellipse(name, material, c, ab, h, under=None, nu=32):
    th = np.linspace(0.0, 2.0 * np.pi, nu, endpoint=False)
    rings = [np.stack([c[0] + s * ab[0] * np.cos(th), c[1] + s * ab[1] * np.sin(th)], axis=-1) for s in RINGS + (1.0,)]
    return _decal(name, material, rings, np.array(c), h, under)


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


def _decal(name, material, rings2d, centre, h, under, inner=None):
    n_r = len(rings2d)
    rows = []
    for i, r2 in enumerate(rings2d):
        base = under(r2[:, 0], r2[:, 1]) if under is not None else np.zeros(len(r2))
        lift = base - SINK if i == n_r - 1 else base + h * bump(RINGS[i])
        rows.append(wrap(r2[:, 0], r2[:, 1], lift))
    ref = wrap(np.array(0.0), np.array(EYE_Z), np.array(-0.3))   # 体の 中の 点（面の 向きを そろえる）
    if inner is not None:
        base = under(inner[:, 0], inner[:, 1]) if under is not None else np.zeros(len(inner))
        rows.insert(0, wrap(inner[:, 0], inner[:, 1], base + h))
        verts, faces = P.skin(np.array(rows))
    else:
        b0 = under(np.array([centre[0]]), np.array([centre[1]]))[0] if under is not None else 0.0
        start = wrap(np.array(centre[0]), np.array(centre[1]), np.array(b0 + h))
        verts, faces = P.skin(np.array(rows), start=start)
    ob = P.mesh_obj(name, verts, faces, material, inside=ref)
    if inner is not None:
        import bmesh
        bm = bmesh.new()
        bm.from_mesh(ob.data)
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
        bm.to_mesh(ob.data)
        bm.free()
        ob.data.update()
    return ob


def build_face(m_white, m_pupil, m_spark, m_mouth):
    out = []
    eyes = []
    for sx in (-1.0, 1.0):   # sx ＝ 3D の X の 向き（+1 ＝ 本人の 右 ＝ 絵の 左）
        c = np.array([sx * EYE_U, EYE_Z])
        pc = c + np.array([-sx * PUPIL_IN, PUPIL_DZ])
        eyes.append((sx, c, pc))

    def whites(u, v):
        return sum(ellipse_height(u, v, c, EYE_AB, H_WHITE) for _, c, _ in eyes)

    def pupils(u, v):
        return sum(ellipse_height(u, v, pc, PUPIL_AB, H_PUPIL) for _, _, pc in eyes)

    for sx, c, pc in eyes:
        tag = "R" if sx > 0 else "L"
        out.append(decal_ellipse(f"wallcell_white{tag}", m_white, c, EYE_AB, H_WHITE, nu=32))
        out.append(decal_ellipse(f"wallcell_pupil{tag}", m_pupil, pc, PUPIL_AB, H_PUPIL, under=whites, nu=26))
        sc = pc + np.array([-sx * SPARK[0], SPARK[1]])
        out.append(decal_ellipse(f"wallcell_spark{tag}", m_spark, sc, (SPARK_R, SPARK_R), H_SPARK,
                                 under=lambda u, v: whites(u, v) + pupils(u, v), nu=16))
    sag = MOUTH_END_Z - MOUTH_LOW_Z
    rad = (MOUTH_HALF ** 2 + sag ** 2) / (2.0 * sag)
    half = math.asin(MOUTH_HALF / rad)
    ang = np.linspace(-half, half, 13)
    path = np.stack([rad * np.sin(ang), MOUTH_LOW_Z + rad * (1.0 - np.cos(ang))], axis=-1)
    out.append(decal_stroke("wallcell_mouth", m_mouth, path, MOUTH_W, H_MOUTH))
    return out


def _radial(outline, centre):
    """星形の 外形（N, 2）を まん中から 見た 角度 → 半径 の 表に する（なめらかな 高さの 式 用）。"""
    d = outline - centre
    ang = np.arctan2(d[:, 1], d[:, 0])
    rad = np.hypot(d[:, 0], d[:, 1])
    o = np.argsort(ang)
    ang, rad = ang[o], rad[o]
    ang = np.concatenate([ang[-1:] - 2.0 * np.pi, ang, ang[:1] + 2.0 * np.pi])
    rad = np.concatenate([rad[-1:], rad, rad[:1]])

    def s_of(u, v):
        du = np.asarray(u, dtype=float) - centre[0]
        dv = np.asarray(v, dtype=float) - centre[1]
        return np.hypot(du, dv) / np.interp(np.arctan2(dv, du), ang, rad)
    return s_of


def decal_poly(name, material, outline, centre, h, under=None):
    """星形の 外形（まん中 centre から 見て 1 回だけ 交わる）の ふくらみ。輪は 外形を まん中へ ちぢめた もの。"""
    outline = np.asarray(outline, dtype=float)
    centre = np.asarray(centre, dtype=float)
    rings = [centre + s * (outline - centre) for s in RINGS + (1.0,)]
    return _decal(name, material, rings, centre, h, under)


def happy_outline(n_top=24, n_low=40):
    """うれしい 口の 外形（正面の 絵の 座標 u, z）。右はし → 上の ふち → 左はし → 下の U → 右はし の 順。"""
    W, zc, b, p = HAPPY_W, HAPPY_ZC, HAPPY_B, HAPPY_P
    ut = np.linspace(W, -W, n_top)
    top = np.stack([ut, zc + HAPPY_TOP_RISE * (ut / W) ** 4], axis=-1)
    t = np.linspace(0.0, np.pi, n_low + 2)[1:-1]          # 左はし → 下 → 右はし（超だ円の 下 半分）
    c, sn = np.cos(t), np.sin(t)
    low = np.stack([-W * np.sign(c) * np.abs(c) ** (2.0 / p), zc - b * sn ** (2.0 / p)], axis=-1)
    return np.concatenate([top, low])


def _happy_low(u):
    """下の U の 高さ（u での ふちの z）。"""
    q = np.clip(1.0 - np.abs(np.asarray(u) / HAPPY_W) ** HAPPY_P, 0.0, 1.0)
    return HAPPY_ZC - HAPPY_B * q ** (1.0 / HAPPY_P)


def tongue_outline(n_top=24, n_low=36):
    """舌の 外形：上は 山なりの 弓、下は 口の U を TONGUE_INSET だけ 内がわへ。"""
    ins = TONGUE_INSET
    W = HAPPY_W - ins

    def arc(u):
        return TONGUE_TOP - TONGUE_DROP * (u / HAPPY_W) ** 2

    def low(u):
        return _happy_low(u * HAPPY_W / W) + ins

    # 弓と U の 交わる u（二分法）
    lo, hi = 0.0, W
    for _ in range(40):
        mid = 0.5 * (lo + hi)
        if arc(mid) > low(mid):
            lo = mid
        else:
            hi = mid
    ue = lo
    ut = np.linspace(ue, -ue, n_top)
    ul = np.linspace(-ue, ue, n_low + 2)[1:-1]
    return np.concatenate([np.stack([ut, arc(ut)], axis=-1), np.stack([ul, low(ul)], axis=-1)])


def build_happy_mouth(m_open, m_tongue):
    """うれしい 口（MouthHappy）：口の 中と 舌。線の 笑顔より 高く ふくらませて、見える ときは 線の 笑顔を かくす。"""
    out = happy_outline()
    c = np.array([0.0, 0.5 * (HAPPY_ZC + HAPPY_TOP_RISE * 0.5 + HAPPY_ZC - HAPPY_B)])
    s_mouth = _radial(out, c)

    def mouth_h(u, v):
        s = s_mouth(u, v)
        return np.where(s < 1.0, H_HAPPY * bump(s), 0.0)

    mouth = decal_poly("wallcell_mouth_open", m_open, out, c, H_HAPPY)
    tout = tongue_outline()
    tc = np.array([0.0, 0.5 * (TONGUE_TOP + _happy_low(0.0) + TONGUE_INSET)])
    tongue = decal_poly("wallcell_tongue", m_tongue, tout, tc, H_TONGUE, under=mouth_h)
    return [mouth, tongue]


# ------------------------------------------------------------------ 組み立て
def build_wallcell():
    m_body = P.mat("WallcellBody", COL["body"], ROUGH["body"])
    m_mucus = P.mat("WallcellMucus", COL["mucus"], ROUGH["mucus"])
    m_white = P.mat("WallcellWhite", COL["white"], ROUGH["white"])
    m_spark = P.mat("WallcellSpark", COL["white"], ROUGH["spark"])
    m_pupil = P.mat("WallcellPupil", COL["pupil"], ROUGH["pupil"])
    m_mouth = P.mat("WallcellMouth", COL["mouth"], ROUGH["mouth"])
    m_open = P.mat("WallcellMouthOpen", COL["mouth_open"], ROUGH["mouth_open"])
    m_tongue = P.mat("WallcellTongue", COL["tongue"], ROUGH["tongue"])

    body = build_body(m_body)
    mucus = build_mucus(m_mucus)
    face = build_face(m_white, m_pupil, m_spark, m_mouth)
    happy = build_happy_mouth(m_open, m_tongue)

    # ねんえきの ふちの 下の うすい 影（体）と、体に うまった ねんえきの 底（見えない）。顔は 暗く しない
    solid = [body, mucus]
    # ground：下を 向いた 面（ゆかに つく 底の まわり）を 少し 暗く して、ゆかに すわって 見える ように
    P.bake_soft_shadow(solid, solid, dist=0.16, floor=0.45, dark=(0.66, 0.52, 0.46), ground=0.1, soften=3)

    # Godot の glTF 読みこみは、メッシュの 1 つ目の マテリアルに 頂点カラーを 使わない（pod.py と 同じ）。
    # 影の 要らない 光の 点を 1 つ目に する
    sparks = [o for o in face if "spark" in o.name]
    parts = sparks + [body, mucus] + [o for o in face if o not in sparks]
    print(f"  triangles: body {P.tri_count([body])}, mucus {P.tri_count([mucus])}, face {P.tri_count(face)}"
          f", happy mouth {P.tri_count(happy)}  total {P.tri_count(parts + happy)}")
    ob = C.join(parts, "wallcell")
    # うれしい 口は 名前で さがす 別の 部品（ゲームは おうえんされる まで かくす。friend.gd）。原点は 本体と 同じ
    mh = C.join(happy, "MouthHappy")
    for o in (ob, mh):
        o.scale = (SCALE, SCALE, SCALE)
        C.set_active(o)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    mh.parent = ob
    mh.matrix_parent_inverse = ob.matrix_world.inverted()
    return ob

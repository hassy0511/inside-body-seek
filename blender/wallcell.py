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
・色は 部品ごとに 1 色。体と ねんえきは い（胃）の 光で 絵の 色に 見える ように 赤みを 足した（下の COL）。ねんえきの ふちの 下の うすい 影は 頂点カラー（Col）に 焼いて ある。
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
# 原点（friend.gd が ゆかから 0.9 ＋ radius·0.3 ＝ 1.17 m に 置く 点）。ちぢめた あとで 原点の 0.97 m 下が 底
# → 底は ゆかから 約 0.2 m（ゆれ ±0.15 で 0.05〜0.35 m）。絵の 座標では ゆかから 0.97 / SCALE。
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

H_WHITE = 0.010
H_PUPIL = 0.007
H_SPARK = 0.004
H_MOUTH = 0.006
SINK = 0.005

# ------------------------------------------------------------------ 色（sRGB）
# 絵の 平らな 所の 中央値は 体 #F6A361、ねんえき #ADE1E1（spec は #ECA66F／#9EDCE5）。
# い（胃）の ステージは キャラクターに 当たる 光が 強い（たいようが カメラの がわから 当たり、まわりの 光 0.55・
# ミクロごうの ライト・トーンマップ linear）。絵の 色の ままだと、うしろから 見た 体が 黄色（255, 232, 129）、
# ねんえきが まっ白（253, 255, 255）に とんで「光る 黄色」や クリームの おかしに 見えた。
# 光は 緑・青を 約 1.45 倍・1.3 倍に する（赤は 255 で 止まる）。そこで 体は 明るさを 落とさずに 緑・青を へらした 色に して、
# ゲームの カメラから 見た 光の 当たる 面が 絵の 色 (255, 174, 104) に なる ように した（前の #CC8650 は カードで どんぐりの
# ような 茶色に なった。#E0945A では うしろが 黄色 (255, 215, 114) に とんだ）。カード・スタジオでは 絵より 赤い オレンジ。docs の 3 章。
COL = {
    "body": "#E27C4E",
    "mucus": "#80C2CC",
    "white": "#FCF3EC",     # 白目・光の 点（spec は #FFF9F1）
    "pupil": "#35251C",     # 黒目（spec は #202333。絵は こげ茶）
    "mouth": "#A93824",     # 口の 線（表情シートの「通常」）
}
ROUGH = {"body": 0.85, "mucus": 0.8, "white": 0.9, "spark": 0.5, "pupil": 0.45, "mouth": 0.9}


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


# ------------------------------------------------------------------ 組み立て
def build_wallcell():
    m_body = P.mat("WallcellBody", COL["body"], ROUGH["body"])
    m_mucus = P.mat("WallcellMucus", COL["mucus"], ROUGH["mucus"])
    m_white = P.mat("WallcellWhite", COL["white"], ROUGH["white"])
    m_spark = P.mat("WallcellSpark", COL["white"], ROUGH["spark"])
    m_pupil = P.mat("WallcellPupil", COL["pupil"], ROUGH["pupil"])
    m_mouth = P.mat("WallcellMouth", COL["mouth"], ROUGH["mouth"])

    body = build_body(m_body)
    mucus = build_mucus(m_mucus)
    face = build_face(m_white, m_pupil, m_spark, m_mouth)

    # ねんえきの ふちの 下の うすい 影（体）と、体に うまった ねんえきの 底（見えない）。顔は 暗く しない
    solid = [body, mucus]
    P.bake_soft_shadow(solid, solid, dist=0.16, floor=0.45, dark=(0.66, 0.52, 0.46), soften=3)

    # Godot の glTF 読みこみは、メッシュの 1 つ目の マテリアルに 頂点カラーを 使わない（pod.py と 同じ）。
    # 影の 要らない 光の 点を 1 つ目に する
    sparks = [o for o in face if "spark" in o.name]
    parts = sparks + [body, mucus] + [o for o in face if o not in sparks]
    print(f"  triangles: body {P.tri_count([body])}, mucus {P.tri_count([mucus])}, face {P.tri_count(face)}"
          f"  total {P.tri_count(parts)}")
    ob = C.join(parts, "wallcell")
    ob.scale = (SCALE, SCALE, SCALE)
    C.set_active(ob)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return ob

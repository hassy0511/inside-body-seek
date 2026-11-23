"""むしばきん（mushiba）。口の ステージの てき。

納品された 3D 用の絵（art/concepts/W2_enemies/ の mushiba_3d_*・mushiba_turnaround・mushiba_3d_parts）から 測った 寸法で 作る。
寸法・色・絵との ちがいは docs/art_orders/W2_01_mushiba_3D化の結果.md。

・前は +Y、上は +Z、単位は m。原点は 体（球）の まん中。本人の 右は +X（正面の 絵では 左）。
・体の 半径は 0.665 m（当たり判定 enemy.gd の radius 0.7 に 合わせた。spec の 体径 0.85 m は 使わない）。
・顔（白目・黒目・光・まゆ・口）は 体の 面に はった うすい ふくらみ。正面の 絵の 位置で 置く（正面から まっすぐ 投影）。
・ドリルは 本人の 右の 黄色い 玉の 上。ななめ 前・外・少し 上を 向く（正面から 見ると 横、真横から 見ると 前）。
  円すい（3 段）と 黄色い えりは 別の 部品 Drill（原点は 根もと、ローカルの 上が 回転軸。いまは 回さない）。
・色は 部品ごとに 1 色（絵から 測った hex）。形が まじわる 所の うすい 影は 頂点カラー（Col）に 焼いて ある。
  シェーダーと テクスチャは 使わない。作りの 道具は blender/pod.py と 共通。

実行: python -m blender.characters mushiba
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


# ------------------------------------------------------------------ 寸法（m）
# 絵の 縮尺：正面の絵の 体の 半径 497 px ＝ R。ほかの 絵は 体の 半径で 合わせなおして 測る。
R = 0.665           # 体の 半径（当たり判定 0.7 の 内がわ）

# 顔（正面の 絵の 座標。体の 半径 ＝ 1、右 ＝ 絵の 右、上 ＝ 上）。3D の X は 絵の 右の 逆
EYE_C = (0.360, 0.098)      # 白目の まん中（絵：左 -0.346、右 +0.373）
EYE_AB = (0.215, 0.247)     # 白目の 半径（横、たて）
PUPIL_IN = 0.086            # 黒目は 白目の まん中から 内がわ（はなの ほう）へ
PUPIL_DZ = 0.006
PUPIL_AB = (0.126, 0.157)
SPARK = (0.066, 0.058)      # 光の 点は 黒目の まん中から 絵の 右上（両目とも 同じ 向き）
SPARK_R = 0.026
BROW_IN = (0.150, 0.225)    # まゆの 内の はし（丸い はしの 中心）
BROW_OUT = (0.470, 0.392)   # 外の はし
BROW_W = 0.047              # まゆの 太さの 半分
MOUTH_HALF = 0.165          # 口の はしまで（横）
MOUTH_END_Z = -0.178
MOUTH_LOW_Z = -0.252
MOUTH_W = 0.019             # 口の 線の 太さの 半分

# 面からの 高さ（m）
H_WHITE = 0.010
H_PUPIL = 0.007
H_SPARK = 0.004
H_BROW = 0.020
H_MOUTH = 0.007
SINK = 0.005        # ふちは 体の 面より これだけ 下へ もぐらせる（すきまが 見えない ように）

# ドリル（本人の 右）
BALL_DIR = (0.80, 0.50, -0.28)   # 黄色い 玉の 向き（正面の 絵：中心 (-0.82, -0.16)、真横の 絵：前後は ほぼ まん中）
BALL_D = 1.05 * R                   # 玉の 中心までの 距離（玉は 体に 半分 うまる）
BALL_R = 0.150
DRILL_DIR = (1.0, 0.70, 0.80)        # ななめ 前・外・少し 上（正面と 真横の どちらから 見ても 約 30° 上）
COLLAR_R = 0.115    # えり（黄色い 半球の カップ）の 半径
COLLAR_AT = 0.100   # えりの 前の 面は 玉の 中心から これだけ 先
CONE_R = 0.100      # 円すいの 根もとの 半径
CONE_L = 0.372      # 円すいの 長さ（えりの 前の 面から 先まで）
TIP_R = 0.024       # 先の 丸みの 半径
GROOVES = (0.36, 0.68)   # みぞ 2 本（根もとから の 割合）→ 3 段
GROOVE_DEPTH = 0.007
GROOVE_W = 0.012

# ------------------------------------------------------------------ 色（絵から 測った sRGB）
COL = {
    "body": "#524C59",      # 体（spec は #45434E。絵の 平らな 所の 中央値）
    "yellow": "#F9C320",    # 玉・えり（spec は #F2C744）
    "grey": "#ABA1A2",      # ドリル（取り込みの 測定値は #A09898）
    "white": "#FAF7F3",     # 白目・光の 点
    "pupil": "#252121",     # 黒目（spec は #202333）
    "brow": "#2F2B2D",
    "mouth": "#2A2526",
}


# ------------------------------------------------------------------ 顔：体の 面に はる ふくらみ
def wrap(u, v, lift):
    """正面の 絵の 座標（m。u ＝ 3D の X、v ＝ Z）を 体の 面へ まっすぐ 投影し、法線の 向きに lift 浮かせる。"""
    u = np.asarray(u, dtype=float)
    v = np.asarray(v, dtype=float)
    y = np.sqrt(np.maximum(R * R - u * u - v * v, 1e-9))
    p = np.stack([u, y, v], axis=-1)
    n = p / R
    return p + n * np.asarray(lift, dtype=float)[..., None]


def bump(s):
    """ふくらみの 断面（s ＝ 0 まん中 … 1 ふち）。上は 平らで、ふちは 丸く 落ちる。"""
    s = np.clip(np.asarray(s, dtype=float), 0.0, 1.0)
    return (1.0 - s ** 4) ** 0.25


RINGS = (0.5, 0.78, 0.9, 0.96, 1.0)


def ellipse_height(u, v, c, ab, h):
    s = np.sqrt(((u - c[0]) / ab[0]) ** 2 + ((v - c[1]) / ab[1]) ** 2)
    return np.where(s < 1.0, h * bump(s), 0.0)


def decal_ellipse(name, material, c, ab, h, under=None, nu=32):
    """だ円の ふくらみ（白目・黒目・光の 点）。c・ab は m。under(u, v) は 下に ある ふくらみの 高さ。"""
    th = np.linspace(0.0, 2.0 * np.pi, nu, endpoint=False)
    rings = []
    for s in RINGS + (1.0,):
        rings.append(np.stack([c[0] + s * ab[0] * np.cos(th), c[1] + s * ab[1] * np.sin(th)], axis=-1))
    return _decal(name, material, rings, np.array(c), h, under)


def decal_stroke(name, material, path, w, h, under=None, n_cap=5):
    """太さ 2w の 線の ふくらみ（まゆ・口）。はしは 丸い。path は (N, 2) の m。"""
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
    ob = _decal(name, material, rings[1:], None, h, under, inner=rings[0])
    return ob


def _decal(name, material, rings2d, centre, h, under, inner=None):
    """2D の 輪（まん中 → ふち、さいごは ふちを もぐらせる 輪）から ふくらみを 作る。"""
    n_r = len(rings2d)
    rows = []
    for i, r2 in enumerate(rings2d):
        base = under(r2[:, 0], r2[:, 1]) if under is not None else np.zeros(len(r2))
        if i == n_r - 1:
            lift = base - SINK
        else:
            lift = base + h * bump(RINGS[i])
        rows.append(wrap(r2[:, 0], r2[:, 1], lift))
    if inner is not None:
        base = under(inner[:, 0], inner[:, 1]) if under is not None else np.zeros(len(inner))
        rows.insert(0, wrap(inner[:, 0], inner[:, 1], base + h))
        verts, faces = P.skin(np.array(rows))
    else:
        b0 = under(np.array([centre[0]]), np.array([centre[1]]))[0] if under is not None else 0.0
        start = wrap(np.array(centre[0]), np.array(centre[1]), np.array(b0 + h))
        verts, faces = P.skin(np.array(rows), start=start)
    ob = P.mesh_obj(name, verts, faces, material, inside=(0.0, 0.0, 0.0))
    if inner is not None:
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


def build_face(m_white, m_pupil, m_spark, m_brow, m_mouth):
    out = []
    eyes = []
    for sx in (-1.0, 1.0):   # sx ＝ 3D の X の 向き（+1 ＝ 本人の 右 ＝ 絵の 左）
        c = np.array([sx * EYE_C[0], EYE_C[1]]) * R
        ab = np.array(EYE_AB) * R
        pc = c + np.array([-sx * PUPIL_IN, PUPIL_DZ]) * R
        pab = np.array(PUPIL_AB) * R
        eyes.append((c, ab, pc, pab))

    def whites(u, v):
        return sum(ellipse_height(u, v, c, ab, H_WHITE) for c, ab, _, _ in eyes)

    def pupils(u, v):
        return sum(ellipse_height(u, v, pc, pab, H_PUPIL) for _, _, pc, pab in eyes)

    for i, (c, ab, pc, pab) in enumerate(eyes):
        sx = -1.0 if i == 0 else 1.0
        out.append(decal_ellipse(f"mushiba_white{int(sx)}", m_white, c, ab, H_WHITE, nu=30))
        out.append(decal_ellipse(f"mushiba_pupil{int(sx)}", m_pupil, pc, pab, H_PUPIL, under=whites, nu=24))
        # 光の 点：絵の 右上 ＝ 3D の -X・上
        sc = pc + np.array([-SPARK[0], SPARK[1]]) * R
        out.append(decal_ellipse(f"mushiba_spark{int(sx)}", m_spark, sc, (SPARK_R * R, SPARK_R * R), H_SPARK,
                                 under=lambda u, v: whites(u, v) + pupils(u, v), nu=16))
        a = np.array([sx * BROW_IN[0], BROW_IN[1]]) * R
        b = np.array([sx * BROW_OUT[0], BROW_OUT[1]]) * R
        path = a + (b - a) * np.linspace(0.0, 1.0, 6)[:, None]
        out.append(decal_stroke(f"mushiba_brow{int(sx)}", m_brow, path, BROW_W * R, H_BROW,
                                under=lambda u, v: whites(u, v) + pupils(u, v)))
    # 口：円弧（はし (±0.165, -0.178)、いちばん 下 -0.252）
    sag = MOUTH_END_Z - MOUTH_LOW_Z
    rad = (MOUTH_HALF ** 2 + sag ** 2) / (2.0 * sag)
    half = math.asin(MOUTH_HALF / rad)
    ang = np.linspace(-half, half, 11)
    path = np.stack([rad * np.sin(ang), MOUTH_LOW_Z + rad * (1.0 - np.cos(ang))], axis=-1) * R
    out.append(decal_stroke("mushiba_mouth", m_mouth, path, MOUTH_W * R, H_MOUTH))
    return out


# ------------------------------------------------------------------ 体と ドリル
def build_body(m_body):
    return P.blob("mushiba_body", m_body, (0.0, 0.0, 0.0), (R, R, R), nu=44, nv=28)


def drill_frame():
    """ドリルの 根もと（えりの 前の 面の 中心）と 向きの 行列（列が X・Y・Z、Z ＝ ドリルの 軸）。"""
    bd = np.array(BALL_DIR) / np.linalg.norm(BALL_DIR)
    ball_c = bd * BALL_D
    d = np.array(DRILL_DIR) / np.linalg.norm(DRILL_DIR)
    return ball_c, ball_c + d * COLLAR_AT, P.frame(d, hint=(0.0, 0.0, 1.0))


def cone_profile():
    """円すいの 断面（半径, 高さ）。根もとの 丸い ふち、みぞ 2 本、丸い 先。"""
    pts = [(0.0, -0.02), (CONE_R - 0.012, -0.02), (CONE_R - 0.003, -0.012), (CONE_R, 0.0)]
    tip_h = CONE_L - TIP_R
    slope = (CONE_R - TIP_R) / tip_h

    def r_at(h):
        r = CONE_R - slope * h
        for g in GROOVES:
            x = (h - g * CONE_L) / GROOVE_W
            if abs(x) < 1.0:
                r -= GROOVE_DEPTH * (1.0 - x * x)
            if h > g * CONE_L:
                r -= 0.003    # 先の がわの 段は 少し 細い（段に 見える）
        return r

    hs = sorted(set(list(np.linspace(0.0, tip_h, 10)) +
                    [g * CONE_L + GROOVE_W * k for g in GROOVES for k in (-1.0, -0.5, 0.0, 0.5, 1.0)]))
    for h in hs[1:]:
        pts.append((r_at(h), h))
    r_end = r_at(tip_h)
    for a in np.linspace(0.0, 90.0, 6)[1:]:
        t = math.radians(a)
        pts.append((r_end * math.cos(t), tip_h + r_end * math.sin(t)))
    pts[-1] = (0.0, pts[-1][1])
    return pts


def collar_profile():
    """えり：玉に うまる 半球の カップ。前の 面は 丸い ふちで、円すいの 根もとを かこむ。"""
    pts = [(0.0, -COLLAR_R * 0.6)]
    for a in np.linspace(-80.0, 0.0, 7)[1:]:
        t = math.radians(a)
        pts.append((COLLAR_R * math.cos(t), -0.01 + COLLAR_R * 0.6 * math.sin(t)))
    rim = 0.016
    for a in np.linspace(0.0, 180.0, 7)[1:]:
        t = math.radians(a)
        pts.append((COLLAR_R - rim + rim * math.cos(t), -0.01 + rim * math.sin(t) * 1.2))
    pts.append((CONE_R - 0.004, -0.012))
    return pts


def build_drill(m_yellow, m_collar, m_grey):
    """玉（体に つく）と、Drill（えり＋円すい。ローカルの Z が 軸）。"""
    ball_c, base, m = drill_frame()
    ball = P.blob("mushiba_ball", m_yellow, ball_c, (BALL_R, BALL_R, BALL_R), nu=24, nv=14)
    collar = P.lathe("mushiba_collar", m_collar, collar_profile(), base, m[:, 2], nu=28, hint=m[:, 0])
    cone = P.lathe("mushiba_cone", m_grey, cone_profile(), base, m[:, 2], nu=28, hint=m[:, 0])
    # みぞは 少し 暗く（絵の 線の 色）
    groove_c = [base + m[:, 2] * g * CONE_L for g in GROOVES]

    def groove_tint(p):
        w = np.zeros(len(p))
        for g in groove_c:
            h = np.abs((p - g) @ m[:, 2]) / (GROOVE_W * 1.1)
            w = np.maximum(w, np.clip(1.0 - h, 0.0, 1.0))
        return 1.0 - 0.22 * w[:, None]

    P.tint_by(cone, groove_tint)
    return ball, collar, cone, base, m


# ------------------------------------------------------------------ 組み立て
def build_mushiba():
    m_body = P.mat("MushibaBody", COL["body"], 0.9)
    m_yellow = P.mat("MushibaYellow", COL["yellow"], 0.7)
    m_collar = P.mat("MushibaCollar", COL["yellow"], 0.7)   # 玉と 同じ 色。Drill の 1 つ目の マテリアル（下の 注）なので 玉とは 分ける
    m_grey = P.mat("MushibaGrey", COL["grey"], 0.6)
    m_white = P.mat("MushibaWhite", COL["white"], 0.9)
    m_spark = P.mat("MushibaSpark", COL["white"], 0.5)
    m_pupil = P.mat("MushibaPupil", COL["pupil"], 0.45)
    m_brow = P.mat("MushibaBrow", COL["brow"], 0.9)
    m_mouth = P.mat("MushibaMouth", COL["mouth"], 0.9)

    body = build_body(m_body)
    face = build_face(m_white, m_pupil, m_spark, m_brow, m_mouth)
    ball, collar, cone, base, m = build_drill(m_yellow, m_collar, m_grey)

    # 影：体と 玉と ドリルは おたがいに。顔の ふくらみは 暗く しない（はっきり 見せる）
    solid = [body, ball, collar, cone]
    P.bake_soft_shadow(solid, solid, dist=0.22, floor=0.45, dark=(0.58, 0.52, 0.56), soften=3)

    # Godot の glTF 読みこみは、メッシュの 1 つ目の マテリアルに 頂点カラーを 使わない（pod.py と 同じ）。
    # 影の 要らない 光の 点を 1 つ目に、Drill は えりを 1 つ目に する
    sparks = [o for o in face if "spark" in o.name]
    main_parts = sparks + [body, ball] + [o for o in face if o not in sparks]
    print(f"  triangles: body {P.tri_count([body])}, face {P.tri_count(face)}, ball {P.tri_count([ball])}, "
          f"drill {P.tri_count([collar, cone])}  total {P.tri_count(main_parts + [collar, cone])}")
    main = C.join(main_parts, "mushiba")
    drill = C.join([collar, cone], "Drill")
    # 原点を 根もとに、ローカルの Z を ドリルの 軸に（Godot では ローカルの Y。回す ときは その 軸で）
    mw = np.eye(4)
    mw[:3, :3] = m
    mw[:3, 3] = base
    from mathutils import Matrix
    M = Matrix([list(r) for r in mw])
    drill.data.transform(M.inverted())
    drill.matrix_world = M
    drill.parent = main
    drill.matrix_parent_inverse = main.matrix_world.inverted()
    return main

"""しょくどう（食道）の ステージ。blender/stages.py の build_esophagus が ここの build() を 呼ぶ。

  python -m blender.stages stage_esophagus

目あては 納品の 雰囲気画 mood_esophagus.png と 部品の 三面図（art/w3-stages の art/concepts/W3_stages/。
大きさと 色は spec.md の 順2）。取り込みの 記録は docs/art_orders/W3_01_食道_取り込みの結果.md：
ミクロごうの うしろから 見た、こい コーラルの 太い くだ。かべには 太い きんにくの わ（弧）が 間を あけて ならび、
明るい ゆかには い（胃）へ むかう 4 本の たてじわ。ゆかに 少しの ねんえきの しずく。入口の 近くの 左上で
きかんが 分かれ（クリーム色の なんこつの わ、ふたの こうとうがい）、奥へ 行くほど 赤く 暗く なり（黒に しない）、
さいごに い（胃）の 入口の ほそい わ（ふんもん）と その 中の ゴール。

食べものの かたまりは 作らない（たべて いない 人の しょくどうは からっぽ）。カルテ 2 の かたまりは
Godot 側が 場面の データ（"lumps"）で 出し、なみと いっしょに 動かす（src/level/peristalsis.gd）。

形は 全部 式から 作る（stage_kit）：
  EsoFloor     ゆか（くだの 下の 弧 ＋ たてじわ 4 本）。当たる。
  EsoWall      かべ（くだの のこり ＋ はじめと おわりの ふた）。当たる。きかんの 入口だけ あなを あける。
  NC_Trachea   きかんの くだ（行きどまり）。見える だけ。
  TracheaPlug  かべの きかんの あなの ぶんの 面。当たる だけ（Godot が 見えなく する。船は きかんに 入れない）。
  NC_Ring_NNN  きんにくの わ（1 つずつ べつの もの。原点は くだの まんなか）。Godot 側で なみの ときに しめる。
  NC_Cardia    い（胃）の 入口の わ（ふんもん）。
  NC_Cartilage きかんの なんこつの わ（C の 形。ひらいた がわが しょくどうの ほう）。
  NC_Epiglottis こうとうがい（ふた）。原点は ちょうつがい。とじた 形で 作り、Godot 側が ひらいた ところから とじる。
  NC_Mucus     ねんえきの しずく（少しだけ）。

座標：+Y が おく（い（胃）の ほう）。道は 前の しょくどうの 制御点で、よこの ゆれだけ 半分（長さと くだりかたは ほぼ 同じ）。
"""
from __future__ import annotations

import math
import random

import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

try:
    from . import common as C
    from . import stage_kit as K
except ImportError:
    import os
    import sys
    sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    from blender import common as C
    from blender import stage_kit as K

sstep, spow = K.sstep, K.spow

# ------------------------------------------------------------------ 色（sRGB）
# HEX：面の もとの 色＝spec の 色見本。ゲームの 中の 色は Godot 側（stage_db.gd の "look"）で 決まる。
# trachea（きかんの 中）と deep（おわりの ふた）は spec に ないので 雰囲気画から。
HEX = {
    "floor": "#FAA3A8", "wall": "#E1686F", "ring": "#D86A78", "flap": "#D76F80",
    "mucus": "#FBE1DB", "cartilage": "#F8EDE3", "trachea": "#8F2634", "deep": "#9F4351",
}

# ------------------------------------------------------------------ 道
# 前の しょくどうの 制御点。よこの ゆれ（x）だけ 半分に した：なみに のると 20 m/秒 で すすむので、
# 前の まがりかたでは カメラが まがりかどの 外がわの かべを 見て しまい、雰囲気画の「おくまで つづく くだ」が 見えなかった
_CTRL0 = [(0, 0, 0), (0, 28, -5), (9, 60, -14), (-11, 98, -26), (8, 140, -40), (-13, 182, -55),
          (11, 225, -72), (-9, 268, -88), (6, 308, -103), (-5, 345, -116), (0, 375, -125), (0, 398, -130)]
CTRL = [(x * 0.5, y, z) for x, y, z in _CTRL0]
BACK = 10.0        # スタートの うしろに のばす 長さ（カメラが ふたに ぶつからない）
AHEAD = 9.0        # 道の おわりの さきに のばす 長さ（ふんもんの むこうの い（胃）の 入口）

# ------------------------------------------------------------------ くだの 断面（ゆかの まんなか ＝ 中心線から FLOOR_D 下）
A = 7.2            # はば（かたがわ）。spec の 半径 5 m の 1.44 倍（ゲームの カメラから 雰囲気画の 広さに 見える）
B_UP = 6.2         # 中心線から 天井まで
B_DN = 5.0         # 中心線から ゆかまで
N_UP, N_DN = 2.2, 3.2   # 角の まるさ（大きいほど 四角。ゆかは 平らに）
FLOOR_PHI = 1.0    # ゆかの 弧（まっすぐ 下 ±この rad）
PATH_UP = 2.5      # 道の マーカーは ゆかから この 高さ

G = 2.0            # 部品の 倍率（spec の m × G。ゲームの カメラは 雰囲気画より 遠い）
RING_GAP = 7.5     # きんにくの わの 間かく m
RING_W = 1.2            # わの はば（くだの 長さ むき）の 半分
RING_H = 1.7              # かべから の 高さ（spec 0.65 m の 2.6 倍。雰囲気画の 太い わ）
RING_BACK = 2.7           # かべの 中へ うめる ふかさ（Godot で しめても すきまが 見えない）
FOLDS = [(-4.3, 0.0), (-1.5, 1.7), (1.5, 3.1), (4.3, 4.6)]   # たてじわ（よこの 位置 m、ゆれの 位相）
FOLD_H = 0.55 * G          # 1.1 m（spec 0.35 m × G より 高く：雰囲気画の たてじわは 太く はっきり）
FOLD_W = 0.85

FORK_S = 29.0      # きかんの 分かれ道（前と 同じ 0.065）
TR_R = 3.4         # きかんの 半径（なんこつの わ 2.5 m × G の 半分より 少し 大きく：わかれ道を 見せる）
TR_THETA = math.radians(162)   # 断面の どこから 出るか（0 ＝ 右、90 ＝ 天井、180 ＝ 左）
TR_LEN = 15.0
GOAL_BEFORE = 6.0  # ゴールは ふんもんの わの この m 手前（ひらけた ところに うかぶ）


# ------------------------------------------------------------------ 道
def _catmull(points, per=18):
    p = np.array(points, dtype=float)
    ext = np.concatenate([p[:1], p, p[-1:]])
    out = []
    for i in range(1, len(ext) - 2):
        p0, p1, p2, p3 = ext[i - 1], ext[i], ext[i + 1], ext[i + 2]
        for k in range(per):
            t = k / per
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t
                              + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3))
    out.append(p[-1])
    return np.array(out)


class Route:
    """道の 長さ s（m）から 中心・前・右・上 を 返す。s < 0 と s > L は まっすぐ のばす"""

    def __init__(self):
        pts = _catmull(CTRL)
        seg = np.linalg.norm(np.diff(pts, axis=0), axis=1)
        self.cum = np.concatenate([[0.0], np.cumsum(seg)])
        self.L = float(self.cum[-1])
        self.pts = pts
        self.t0 = (pts[1] - pts[0]) / np.linalg.norm(pts[1] - pts[0])
        self.t1 = (pts[-1] - pts[-2]) / np.linalg.norm(pts[-1] - pts[-2])

    def center(self, s):
        s = np.atleast_1d(np.asarray(s, dtype=float))
        sc = np.clip(s, 0.0, self.L)
        c = np.stack([np.interp(sc, self.cum, self.pts[:, k]) for k in range(3)], axis=-1)
        c = c + np.where(s[:, None] < 0, s[:, None] * self.t0[None, :], 0.0)
        c = c + np.where(s[:, None] > self.L, (s[:, None] - self.L) * self.t1[None, :], 0.0)
        return c

    def frame(self, s):
        """(中心, 前 t, 右 r, 上 u)。前は ±2 m の 差で なめらかに"""
        s = np.atleast_1d(np.asarray(s, dtype=float))
        c = self.center(s)
        t = self.center(s + 2.0) - self.center(s - 2.0)
        t /= np.linalg.norm(t, axis=1, keepdims=True)
        r = np.stack([t[:, 1], -t[:, 0], np.zeros(len(s))], axis=-1)
        r /= np.linalg.norm(r, axis=1, keepdims=True)
        u = np.cross(r, t)
        return c, t, r, u


def scale_at(s, L):
    """断面の 大きさ：おわりの ふんもん（い（胃）の 入口）で せまく なり、その むこうで 少し ひろがる"""
    s = np.asarray(s, dtype=float)
    sc = L - 8.0
    # ゴール（sc − GOAL_BEFORE）の ところは 0.66 の ひろさ：ゴールの 輪が まるごと ひらけた ところに うかび、
    # その うしろで ふんもんが きゅっと せまく なって 暗い 入口が 輪を かこむ（雰囲気画）。
    # ゴールの よこを すりぬけても、Godot 側が「ゴールの 面を こえたら ついた」に する（peristalsis.gd）
    wide = sstep(sc - 40.0, sc - GOAL_BEFORE - 2.0, s)
    tight = sstep(sc - GOAL_BEFORE + 1.0, sc - 1.0, s)
    after = sstep(sc + 1.5, sc + 7.0, s)
    return 1.0 - (0.34 * wide + 0.24 * tight) * (1.0 - after) - 0.3 * after


def section(theta):
    """断面の 形（中心からの よこ x、たて z）。theta = -π/2 が ゆかの まんなか"""
    c, s = np.cos(theta), np.sin(theta)
    up = s >= 0
    n = np.where(up, N_UP, N_DN)
    x = A * spow(c, 2.0 / n)
    z = np.where(up, B_UP, B_DN) * spow(s, 2.0 / n)
    return x, z


def fold_k(x, s):
    """たてじわの 上か（0〜1。いちばん 高い ところが 1）"""
    x = np.asarray(x, dtype=float)
    k = np.zeros(np.broadcast(x, s).shape)
    for x0, ph in FOLDS:
        xc = x0 + 0.45 * np.sin(s * 0.045 + ph) + 0.2 * np.sin(s * 0.13 + ph * 2.1)
        k = np.maximum(k, np.exp(-((x - xc) / FOLD_W) ** 2))
    return k * (1.0 - sstep(0.62 * A, 0.86 * A, np.abs(x)))


def fold_lift(x, s):
    """ゆかの たてじわと まんなかの ふくらみ（上へ の 高さ m）。ゆかの はしでは 0"""
    x = np.asarray(x, dtype=float)
    h = 0.3 * np.clip(1.0 - (x / (A * 0.8)) ** 2, 0.0, 1.0)
    for x0, ph in FOLDS:
        xc = x0 + 0.45 * np.sin(s * 0.045 + ph) + 0.2 * np.sin(s * 0.13 + ph * 2.1)
        hh = FOLD_H * (0.85 + 0.15 * np.sin(s * 0.07 + ph * 1.3))
        h = h + hh * np.exp(-((x - xc) / FOLD_W) ** 2)
    return h * (1.0 - sstep(0.62 * A, 0.86 * A, np.abs(x)))


def oriented(verts, faces, inward):
    """面の 向きを inward（頂点ごとの 内向き）に そろえる（多数決）"""
    v = verts[faces[:, 0]], verts[faces[:, 1]], verts[faces[:, 2]]
    n = np.cross(v[1] - v[0], v[2] - v[0])
    want = inward[faces[:, 0]]
    if float(np.sum(np.einsum("ij,ij->i", n, want))) < 0:
        faces = faces[:, ::-1].copy()
    return faces


# ------------------------------------------------------------------ くだ
def tube_grid(route, ss, thetas, lift=False):
    """s の 列 × theta の 列 の 点（N_s × N_t × 3）と、内向き"""
    c, t, r, u = route.frame(ss)
    f = scale_at(ss, route.L)[:, None]
    x, z = section(thetas)
    X = x[None, :] * f
    Z = z[None, :] * f
    if lift:
        Z = Z + fold_lift(X, ss[:, None]) * f
    P = c[:, None, :] + r[:, None, :] * X[..., None] + u[:, None, :] * Z[..., None]
    inward = c[:, None, :] - P
    return P, inward, X, Z


def build_floor(route, mat):
    ss = np.arange(-BACK, route.L + AHEAD + 1e-6, 0.75)
    th = np.linspace(-math.pi / 2 - FLOOR_PHI, -math.pi / 2 + FLOOR_PHI, 37)
    P, inward, X, Z = tube_grid(route, ss, th, lift=True)
    verts = P.reshape(-1, 3)
    faces = oriented(verts, K.grid_faces(len(ss), len(th)), inward.reshape(-1, 3))
    ob = K.mesh_object("EsoFloor", verts, faces, mat)
    arc = np.concatenate([np.zeros((len(ss), 1)), np.cumsum(np.linalg.norm(np.diff(P, axis=1), axis=2), axis=1)], axis=1)
    K.set_uv(ob, np.stack([arc, np.broadcast_to(ss[:, None], arc.shape)], axis=-1).reshape(-1, 2) / K.TILE_M)
    # 色：しわの 山は 少し 明るく、谷は 少し こく（雰囲気画 #FD8E8E と #F87174）。はしは かべの 色へ
    k = fold_k(X, ss[:, None])
    mid = 1.0 - sstep(0.55 * A, 0.8 * A, np.abs(X))
    tone = np.ones(X.shape + (3,))
    tone = tone * (1.0 + (0.14 * k ** 0.7 - 0.3 * (1.0 - k) ** 2) * mid)[..., None]
    edge = sstep(0.6 * A, 0.95 * A, np.abs(X))[..., None]
    tone = tone * (1.0 - edge) + K.ratio("#EF5C64", "#FD8E8E")[None, None, :] * edge
    return ob, tone.reshape(-1, 3), ss, th


def build_wall(route, mat, hole_axis):
    ss = np.arange(-BACK, route.L + AHEAD + 1e-6, 1.2)
    th = np.linspace(-math.pi / 2 + FLOOR_PHI, 3 * math.pi / 2 - FLOOR_PHI, 49)
    P, inward, X, Z = tube_grid(route, ss, th)
    ns, nt = len(ss), len(th)
    verts = P.reshape(-1, 3)
    faces = K.grid_faces(ns, nt)
    # きかんの 入口：きかんの じくから TR_R より 近い 面を ぬく
    a0, d = hole_axis
    cen = verts[faces].mean(axis=1)
    w = cen - a0
    along = w @ d
    dist = np.linalg.norm(w - along[:, None] * d[None, :], axis=1)
    keep = ~((dist < TR_R * 0.96) & (along > -3.0) & (along < 6.0))
    # あなの ぶんの 面は「当たるだけ」の ふた（TracheaPlug。Godot 側で 見えなく する）に のこす：
    # 船は きかんに 入れず、左の かべに そって とんでも かべは なめらかな まま（ふちに ひっかからない）
    plug = faces[~keep]
    used = np.unique(plug)
    remap = np.full(len(verts), -1, dtype=np.int64)
    remap[used] = np.arange(len(used))
    plug_o = K.mesh_object("TracheaPlug", verts[used], oriented(verts[used], remap[plug], inward.reshape(-1, 3)[used]), mat)
    faces = faces[keep]
    # はじめと おわりの ふた（ゆかの へりも ふくめて まるく とじる）
    caps = []
    base = len(verts)
    extra = []
    for si, s0 in ((0, ss[0]), (ns - 1, ss[-1])):
        c, t, r, u = route.frame([s0])
        f = float(scale_at([s0], route.L)[0])
        ring_t = np.linspace(-math.pi / 2, 3 * math.pi / 2, 64, endpoint=False)
        x, z = section(ring_t)
        pts = c[0][None, :] + r[0][None, :] * (x * f)[:, None] + u[0][None, :] * (z * f)[:, None]
        idx0 = base + len(extra)
        extra.extend(pts.tolist())
        extra.append(c[0].tolist())
        ci = base + len(extra) - 1
        for j in range(64):
            caps.append((idx0 + j, idx0 + (j + 1) % 64, ci))
    verts2 = np.concatenate([verts, np.array(extra)])
    quads = [tuple(f) for f in faces]
    inward_all = np.concatenate([inward.reshape(-1, 3), np.zeros((len(extra), 3))])
    quads_arr = np.array(quads)
    quads_arr = oriented(verts2, quads_arr, inward_all)
    # ふたは 中（くだの 中心）へ 向ける
    cap_arr = np.array(caps)
    tri_n = np.cross(verts2[cap_arr[:, 1]] - verts2[cap_arr[:, 0]], verts2[cap_arr[:, 2]] - verts2[cap_arr[:, 0]])
    cs, ct, _, _ = route.frame([ss[0], ss[-1]])
    want = np.where(np.arange(len(cap_arr))[:, None] < 64, ct[0][None, :], -ct[1][None, :])
    flip = np.einsum("ij,ij->i", tri_n, want) < 0
    cap_arr[flip] = cap_arr[flip][:, ::-1]
    import bpy
    me = bpy.data.meshes.new("EsoWall")
    me.from_pydata([tuple(v) for v in verts2], [], [tuple(q) for q in quads_arr] + [tuple(c) for c in cap_arr])
    me.polygons.foreach_set("use_smooth", np.ones(len(me.polygons), dtype=bool))
    me.update()
    me.materials.append(mat)
    ob = bpy.data.objects.new("EsoWall", me)
    C.link(ob)
    # UV（予備）：まわりの 長さ と s
    arc = np.concatenate([np.zeros((ns, 1)), np.cumsum(np.linalg.norm(np.diff(P, axis=1), axis=2), axis=1)], axis=1)
    uv = np.stack([arc, np.broadcast_to(ss[:, None], arc.shape)], axis=-1).reshape(-1, 2)
    uv = np.concatenate([uv, np.zeros((len(extra), 2))])
    K.set_uv(ob, uv / K.TILE_M)
    # 色：天井に 近いほど こく（雰囲気画：わの あいだの かべ #CC3642、よこの かべ #EB4C54）。ふたは おくの 赤
    zn = np.clip(Z / B_UP, -1.0, 1.0)
    top = 0.6 * sstep(0.0, 0.9, zn)[..., None]
    tone = np.ones(X.shape + (3,)) * (1.0 - top) + K.ratio("#CC3642", "#EB4C54")[None, None, :] * top
    q = P.reshape(-1, 3)
    wob = np.sin(q[:, 0] * 0.21 + q[:, 2] * 0.13 + 1.3) * np.sin(q[:, 1] * 0.17 - q[:, 2] * 0.19 + 0.4)
    tone = tone.reshape(-1, 3) * (1.0 - 0.05 * wob)[:, None]
    tone = np.concatenate([tone, np.tile(K.ratio("#A6303C", "#EB4C54"), (len(extra), 1))])
    return ob, tone, plug_o


# ------------------------------------------------------------------ きんにくの わ
def ring_mesh(route, s0, mat, name, scale=1.0, th_pad=0.12, fat=1.0):
    """かべに そう わの 弧（ゆかを のこして 天井と よこ）。原点は くだの 中心"""
    c, t, r, u = route.frame([s0])
    c, t, r, u = c[0], t[0], r[0], u[0]
    f = float(scale_at([s0], route.L)[0])
    th = np.linspace(-math.pi / 2 + FLOOR_PHI + th_pad, 3 * math.pi / 2 - FLOOR_PHI - th_pad, 29)
    x, z = section(th)
    x, z = x * f, z * f
    # 断面の 内向きの 法線（2D）
    dx, dz = np.gradient(x), np.gradient(z)
    nl = np.hypot(dx, dz)
    nx, nz = -dz / nl, dx / nl          # 曲線の 左 ＝ 内がわ（反時計回り）
    # はしは かべへ しずめる（まるい おわり）
    e = np.minimum(np.arange(len(th)), np.arange(len(th))[::-1]) / 5.0
    sink = 1.0 - sstep(0.0, 1.0, e)
    prof = np.linspace(0, 2 * math.pi, 11)[:-1]
    pu = np.cos(prof) * RING_W * fat                                   # くだの 長さ むき
    # pv：-RING_BACK 〜 +RING_H（かべ から 内へ）。かべの 中の がわは 少し ひろく（しめても すきまが 見えない）
    pv = np.where(np.sin(prof) > 0, np.sin(prof) * RING_H * fat, np.sin(prof) * RING_BACK)
    pu = pu * np.where(np.sin(prof) > 0, 1.0, 1.25)
    V = []
    crest = []
    for i in range(len(th)):
        # 下の ほう（カメラの 高さ）は ひくく：船が かべの 近くを とんでも カメラが わの 中に 入らない
        hf = 0.4 + 0.6 * float(sstep(-0.35, 0.45, z[i] / (B_UP * f)))
        lift = np.where(pv > 0, pv * hf, pv) - sink[i] * (RING_H * fat + 0.4)
        crest.extend((np.clip(np.sin(prof), 0.0, 1.0) * (1.0 - sink[i])).tolist())
        for j in range(len(prof)):
            lx = x[i] + nx[i] * lift[j]
            lz = z[i] + nz[i] * lift[j]
            V.append(t * pu[j] + r * lx + u * lz)
    V = np.array(V)
    faces = K.grid_faces(len(th), len(prof), wrap_u=True)
    # 外向き（わの 表面）に そろえる：わの 断面の 中心から 外
    core = []
    for i in range(len(th)):
        core.extend([r * (x[i] + nx[i] * RING_H * 0.2) + u * (z[i] + nz[i] * RING_H * 0.2)] * len(prof))
    out = V - np.array(core)
    faces = oriented(V, faces, out)
    ob = K.mesh_object(name, V + c, faces, mat, location=tuple(c))
    RING_CREST[name] = np.array(crest)
    return ob


RING_CREST = {}   # わの 名前 → 頂点ごとの「てっぺん らしさ」（0 ＝ かべの きわ、1 ＝ いちばん 高い ところ）


# ------------------------------------------------------------------ きかん・こうとうがい
def trachea_axis(route):
    c, t, r, u = route.frame([FORK_S])
    c, t, r, u = c[0], t[0], r[0], u[0]
    x, z = section(np.array([TR_THETA]))
    j = c + r * x[0] + u * z[0]                 # かべの 上の 入口の まんなか
    out = (j - c)
    out /= np.linalg.norm(out)
    d = out * 0.75 + u * 0.35 + t * 0.45        # 外へ、少し 上と おくへ
    d /= np.linalg.norm(d)
    return j, d, t, out


def build_trachea(route, mat, mat_c, mat_f):
    j, d, t, out = trachea_axis(route)
    a0 = j - d * 1.2
    # じくに 直角な 2 本
    e1 = np.cross(d, [0.0, 0.0, 1.0])
    e1 /= np.linalg.norm(e1)
    e2 = np.cross(d, e1)
    ls = np.linspace(0.0, TR_LEN, 22)
    ang = np.linspace(0, 2 * math.pi, 33)[:-1]
    rad = TR_R * (1.0 - 0.25 * sstep(TR_LEN * 0.5, TR_LEN, ls))
    P = a0[None, None, :] + d[None, None, :] * ls[:, None, None] + (np.cos(ang)[None, :, None] * e1 + np.sin(ang)[None, :, None] * e2) * rad[:, None, None]
    verts = P.reshape(-1, 3)
    faces = K.grid_faces(len(ls), len(ang), wrap_u=True)
    tip = len(verts)
    verts = np.concatenate([verts, [a0 + d * (TR_LEN + 1.0)]])
    last = (len(ls) - 1) * len(ang)
    tris = np.array([(last + k, last + (k + 1) % len(ang), tip) for k in range(len(ang))])
    axis_pt = a0[None, :] + np.outer(np.clip((verts - a0) @ d, 0, TR_LEN), d)
    inward = axis_pt - verts
    inward[-1] = -d
    faces = oriented(verts, faces, inward)
    n = np.cross(verts[tris[:, 1]] - verts[tris[:, 0]], verts[tris[:, 2]] - verts[tris[:, 0]])
    if float(np.sum(n @ (-d))) < 0:
        tris = tris[:, ::-1]
    import bpy
    me = bpy.data.meshes.new("NC_Trachea")
    me.from_pydata([tuple(v) for v in verts], [], [tuple(f) for f in faces] + [tuple(f) for f in tris])
    me.polygons.foreach_set("use_smooth", np.ones(len(me.polygons), dtype=bool))
    me.update()
    me.materials.append(mat)
    tr = bpy.data.objects.new("NC_Trachea", me)   # 見える だけ（当たるのは かべの TracheaPlug）
    C.link(tr)
    lsv = np.concatenate([np.repeat(ls, len(ang)), [TR_LEN + 1.0]])
    K.set_colors(tr, np.ones((len(verts), 3)) * (1.0 - 0.45 * sstep(1.0, TR_LEN, lsv))[:, None])
    # なんこつの わ：C の 形（しょくどうの がわ ＝ 後ろが ひらく）。入口の ふち と 中に 2 本
    rings = []
    for k, l0 in enumerate((-0.2, 2.8, 5.6, 8.4)):
        rr = TR_R * (1.0 - 0.25 * sstep(TR_LEN * 0.5, TR_LEN, l0)) - 0.05
        gap_dir = -out + d * (d @ out)                 # しょくどうの ほう（じくに 直角）
        gap_dir /= np.linalg.norm(gap_dir)
        g0 = math.atan2(gap_dir @ e2, gap_dir @ e1)
        # 入口の ふち（k = 0）は まるい わ。中の わは C の 形（しょくどうの がわが ひらく：本物の きかんの なんこつと 同じ）
        a = g0 + (np.linspace(0.0, 2 * math.pi, 48) if k == 0 else np.linspace(0.55, 2 * math.pi - 0.55, 40))
        prof = np.linspace(0, 2 * math.pi, 11)[:-1]
        V = []
        minor = 0.3 * G * (2.1 if k == 0 else 1.15)   # 入口の ふちの わは 太く（かべの あなの へりを かくす）
        for i, aa in enumerate(a):
            radial = math.cos(aa) * e1 + math.sin(aa) * e2
            endk = 9.0 if k == 0 else min(i, len(a) - 1 - i) / 4.0
            mk = 0.55 + 0.45 * float(sstep(0.0, 1.0, endk))
            for pp in prof:
                V.append(a0 + d * (l0 + math.cos(pp) * minor * 0.55 * mk) + radial * (rr - 0.15 - math.sin(pp) * minor * 0.5 * mk))
        V = np.array(V)
        fc = K.grid_faces(len(a), len(prof), wrap_u=True)
        core = np.repeat(np.array([a0 + d * l0 + (math.cos(aa) * e1 + math.sin(aa) * e2) * (rr - 0.15) for aa in a]), len(prof), axis=0)
        fc = oriented(V, fc, V - core)
        rings.append(K.mesh_object(f"cart{k}", V, fc, mat_c))
    cart = K.join_meshes(rings, "NC_Cartilage")
    flap = build_epiglottis(route, mat_f, j, d, t, out)
    return tr, cart, flap


EPI_W = 7.6     # こうとうがいの はば（spec 3.9 m × G。入口 6 m を おおう）
EPI_L = 7.4     # ちょうつがい から さきまで（spec 2.8 m × G より 長く：入口を おおう）
EPI_T = 0.45 * G


def build_epiglottis(route, mat, j, d, t, out):
    """とじた ところの ふた。原点は ちょうつがい（きかんの 入口の 上の ふち）。ふたは 入口の 面（きかんの じくに 直角）に おく：
    きかんは おくへ のびるので 入口は うしろ（スタートの ほう）を 向き、ふたの 広い 面が カメラから 見える。
    ローカル：X ＝ ちょうつがいの じく（よこ）、-Z ＝ ふたの さきの ほう（下）、+Y ＝ しょくどうの がわ。
    Godot 側で ローカル X の まわりに ＋ に まわすと しょくどうの ほうへ ひらく（雰囲気画の したの ように たれる）"""
    c, tt, r, u = route.frame([FORK_S])
    c, tt, r, u = c[0], tt[0], r[0], u[0]
    X = np.cross(d, np.array([0.0, 0.0, 1.0]))
    X /= np.linalg.norm(X)
    Y = -d
    Z = np.cross(X, Y)
    if Z[2] < 0:                      # +Z が 上を 向く ように
        X = -X
        Z = np.cross(X, Y)
    a0 = j - d * 1.2
    hinge = a0 + d * 1.0 + Z * (TR_R + 0.45)
    # 形：正面の 外形（三面図 4：上に ちょうつがいの ぼう、まん中で いちばん ひろく、下は まるい）
    nv, nu = 18, 20
    vs = np.linspace(0.0, 1.0, nv)
    half = EPI_W * 0.5 * (0.78 + 0.3 * np.sin(np.clip(vs, 0, 1) * math.pi * 0.85)) * np.sqrt(np.clip(1.0 - ((vs - 0.35) / 0.68) ** 6, 0.0, 1.0))
    half[0] = EPI_W * 0.5 * 0.86
    verts = []
    for side in (1.0, -1.0):        # 1 ＝ くだの 中がわの 面、-1 ＝ かべがわの 面
        for i, v in enumerate(vs):
            for k in range(nu):
                a = -1.0 + 2.0 * k / (nu - 1)
                xx = half[i] * a
                bulge = (1.0 - a * a) ** 0.5 * (1.0 - v * 0.4)
                yy = side * EPI_T * 0.5 * max(bulge, 0.15)
                zz = -v * EPI_L
                verts.append(hinge + X * xx + Y * (yy + EPI_T * 0.5) + Z * zz)
    verts = np.array(verts)
    fa = K.grid_faces(nv, nu)
    fb = fa + nv * nu
    fb = fb[:, ::-1]
    # ふちを つなぐ
    rim = []
    off = nv * nu
    border = [(0, k) for k in range(nu)] + [(i, nu - 1) for i in range(1, nv)] + [(nv - 1, k) for k in range(nu - 2, -1, -1)] + [(i, 0) for i in range(nv - 2, 0, -1)]
    for m in range(len(border)):
        i0, k0 = border[m]
        i1, k1 = border[(m + 1) % len(border)]
        aa, bb = i0 * nu + k0, i1 * nu + k1
        rim.append((aa, bb, bb + off, aa + off))
    faces = np.concatenate([fa, fb, np.array(rim)])
    cen = hinge + Z * (-EPI_L * 0.45) + Y * (EPI_T * 0.5)
    faces = oriented(verts, faces, verts - cen)
    ob = K.mesh_object("NC_Epiglottis", verts, faces, mat, location=tuple(hinge))
    # ローカルの 向きを 上の X・Y・Z に する（Godot 側が ローカル X で まわす）
    from mathutils import Matrix
    m = Matrix(((X[0], Y[0], Z[0]), (X[1], Y[1], Z[1]), (X[2], Y[2], Z[2])))
    me = ob.data
    inv = m.inverted()
    for vtx in me.vertices:
        vtx.co = inv @ vtx.co
    ob.rotation_euler = m.to_euler()
    me.update()
    return ob


# ------------------------------------------------------------------ ねんえきの しずく
def build_mucus(route, mat, floor_bvh):
    rng = random.Random(23)
    objs = []
    spots = []
    while len(spots) < 12:
        s = rng.uniform(12.0, route.L - 20.0)
        x = rng.choice((-1, 1)) * rng.uniform(2.2, 5.2)
        if all(abs(s - q) > 18.0 for q, _ in spots) and abs(s - FORK_S) > 8:
            spots.append((s, x))
    for i, (s, x) in enumerate(spots):
        c, t, r, u = route.frame([s])
        p = c[0] + r[0] * x
        hit = floor_bvh.ray_cast(Vector(p), Vector((0, 0, -1)), 20.0)
        if hit[0] is None:
            continue
        n = np.array(hit[1])
        sz = rng.uniform(0.8, 1.15) * 1.5
        w, dpt, h = 0.8 * G * sz, 0.6 * G * sz, 0.25 * G * sz
        v, q, tri = K.superellipsoid(20, 10, 0.9, 0.8)
        v = v.copy()
        v[:, 2] = np.where(v[:, 2] < 0, v[:, 2] * 0.15, v[:, 2])   # 平らな うら
        ex = np.cross(n, t[0])
        ex /= np.linalg.norm(ex)
        ey = np.cross(n, ex)
        pts = np.array(hit[0])[None, :] + (v[:, 0:1] * w * 0.5) * ex + (v[:, 1:2] * dpt * 0.5) * ey + (v[:, 2:3] * h - 0.05) * n
        objs.append(K.blob_object(f"drop{i}", pts, q, tri, mat))
    return K.join_meshes(objs, "NC_Mucus")


# ------------------------------------------------------------------ まとめ
def build():
    import bpy
    route = Route()
    L = route.L
    mats = {k: K.surface_material("Stage" + k.capitalize(), v) for k, v in HEX.items()}
    j, d, _t, _o = trachea_axis(route)
    floor_o, floor_tone, _ss, _th = build_floor(route, mats["floor"])
    wall_o, wall_tone, plug_o = build_wall(route, mats["wall"], (j - d * 1.2, d))
    tr, cart, flap = build_trachea(route, mats["trachea"], mats["cartilage"], mats["flap"])
    # きんにくの わ（わかれ道の まわりと ふんもんの 近くは あける）
    rings = []
    s = 12.0
    k = 0
    while s < L - 8.0 - GOAL_BEFORE - 7.0:
        if abs(s - FORK_S) > 8.5:
            rings.append(ring_mesh(route, s, mats["ring"], f"NC_Ring_{k:03d}"))
            k += 1
        s += RING_GAP
    cardia = ring_mesh(route, L - 8.0, mats["ring"], "NC_Cardia", th_pad=-0.35, fat=1.6)
    fbvh = BVHTree.FromObject(floor_o, bpy.context.evaluated_depsgraph_get())
    mucus = build_mucus(route, mats["mucus"], fbvh)
    objs = [floor_o, wall_o, plug_o, tr, cart, flap, mucus, cardia] + rings

    # かげの 焼きこみ（わの ねもと、ゆかの へり）。わは 動くので かべの かげは 弱め
    ao = K.bake_ao([floor_o, wall_o, tr, cart, mucus, cardia] + rings, reach=4.0, rays=16, smooth=2)
    K.set_colors(floor_o, floor_tone * K.shade(ao[floor_o.name], (0.62, 0.42, 0.48), 1.2))
    K.set_colors(wall_o, wall_tone * K.shade(ao[wall_o.name], (0.7, 0.5, 0.55), 1.2))
    for o in rings + [cardia]:
        # まるい わに 見せる：てっぺんは 明るく、かべの きわは こく（雰囲気画の わ #FD7D7E → きわ #CC3642）
        cr = RING_CREST[o.name]
        edge = K.ratio("#C2404C", "#FD7D7E")
        tone = edge[None, :] + (1.0 - edge[None, :]) * (cr ** 0.6)[:, None]
        K.set_colors(o, tone * K.shade(ao[o.name], (0.72, 0.5, 0.55), 1.0))
    K.set_colors(cart, K.shade(ao[cart.name], (0.8, 0.62, 0.6), 1.0))
    K.set_colors(mucus, np.ones((len(mucus.data.vertices), 3)))
    # ふたの かげ：ちょうつがいの ほうは こく、さきは 明るく、かべがわの 面は もっと こく（平らな 板に 見せない）
    fz = np.array([v.co.z for v in flap.data.vertices])
    fy = np.array([v.co.y for v in flap.data.vertices])
    tip = np.clip(-fz / EPI_L, 0.0, 1.0)
    ft = (0.62 + 0.48 * tip ** 0.8) * np.where(fy < EPI_T * 0.5, 0.72, 1.0)
    K.set_colors(flap, np.stack([ft, ft * 0.97, ft * 0.97], axis=-1))
    trc = K.get_colors(tr)
    K.set_colors(tr, trc * K.shade(ao[tr.name], (0.6, 0.4, 0.45), 1.0))
    print(f"  esophagus: L={L:.1f} m, rings={len(rings)}, {K.triangle_count(objs)} triangles")
    print(f"  fork (trachea mouth) at {tuple(round(float(v), 2) for v in j)}, axis {tuple(round(float(v), 2) for v in d)}")

    # マーカー（高さは ゆかの BVH から）
    def on_floor(s, x=0.0, up=0.0):
        c, t, r, u = route.frame([s])
        p = c[0] + r[0] * x
        hit = fbvh.ray_cast(Vector(p), Vector((0, 0, -1)), 30.0)
        z = hit[0].z if hit[0] is not None else p[2] - B_DN
        return (float(p[0]), float(p[1]), float(z + up))

    n = max(2, int(L / 8.0))
    for i in range(n + 1):
        C.add_empty(f"MK_path_{i:03d}", on_floor(L * i / n, 0.0, PATH_UP))
    C.add_empty("MK_player", on_floor(0.01 * L, 0.0, 1.2))
    goal_s = L - 8.0 - GOAL_BEFORE
    C.add_empty("MK_goal", on_floor(goal_s, 0.0, 0.8))
    # ゴールの かんばんは おかない：輪の 中に 板が 見えて しまう。場所の 名前と ミッションで わかる（雰囲気画にも ない）
    C.add_empty("MK_checkpoint_1", on_floor(0.33 * L, 0.0, 0.5))
    C.add_empty("MK_checkpoint_2", on_floor(0.66 * L, 0.0, 0.5))
    C.add_empty("MK_pickup_heart_item_1", on_floor(0.5 * L, 2.2, 1.0))
    C.add_empty("MK_card_epiglottis", on_floor(FORK_S, 0.0, 1.0))
    # きかんの かんばんは 入口の 下で 6 m 手前（カメラの ほう）：ひらいた ふたが かんばんと カメラの あいだに 入らない
    C.add_empty("MK_sign_trachea", on_floor(FORK_S - 6.0, -3.4, -0.3))
    return objs

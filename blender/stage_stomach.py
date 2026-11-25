"""い（胃）の ステージ。blender/stages.py の build_stomach が ここの build() を 呼ぶ。

  python -m blender.stages stage_stomach

目あては 納品の 雰囲気画 mood_stomach.png と 部品の 三面図（art/w3-stages の art/concepts/W3_stages/。
大きさと 色は spec.md の「順2」）。取り込みの 記録は docs/art_orders/W3_01_胃_取り込みの結果.md：
ミクロごうの うしろから 見た、あたたかい コーラル橙の 大きな おわん。明るい ゆかに よこへ のびる 太い ひだ、
こい 色の かべ、ゆかの くぼみに たまった いえき（胃液）の いけ（ふちは ゆかの 色で ひくく もりあがる）、
天井から さがる 食道からの 入口の 輪、右の かべの 下に 小さな 出口の 輪（ゆうもん）、左の かべぞいの 段（なかまと ピロリきんが いる）。
おくの かべは かさなる アーチで 赤橙へ 暗く なる。

形は 全部 式から 作る（stage_kit）：
  StomachShell  かべと 天井（たいらな 底の だ円の おわん。内向き）。入口と 出口の ところは 穴を あける
  StomachFloor  ゆか（ひだ・いけの くぼみと ふち・左の 段）。上向きの 1 枚
  Exit          出口の 輪 ＋ 先の みじかい くだ（当たる。くだの おくは 暗い 赤で とじる）
  NC_Entry      入口の 輪 ＋ 天井へ のびる くだ ＋ ふちの しずく（高い ところなので 当たらない）

いけの 水面は ここでは 作らない：Godot 側（src/entities/hazard_pool.gd）が マーカーの 高さに 平らな 円を 出す。
だから いけの ない 場面（とおりみち）では、からの くぼみ（ゆかの 色の ふちと、少し こい 底）に なる。
くぼみの 形（POOL_*）と 水面の 高さ・あぶない 円の 大きさは hazard_pool.gd と そろえて ある：
  水面は マーカーの 高さ。くぼみの 坂が 水面の 高さを よこぎる ところが ちょうど 半径 r（マーカー名の r）。
座標：+Y が おく（スタートは −Y の はし、ミクロごうは +Y を 向く）。ゆかの 高さは floor_h()。
"""
from __future__ import annotations

import math

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
# HEX：面の もとの 色＝spec の 色見本（順2 の 胃）。ゲームの 中の 色は Godot 側（stage_db.gd の "look"）で 決まる。
# 頂点カラー（かげの 倍率）は 雰囲気画で 測った 色の 比：REF の 色を 1 と して、その 場所の 絵の 色に する 倍率。
HEX = {"floor": "#FDA086", "wall": "#D45E5D", "ring": "#F3A28B"}
REF = {"floor": "#FC8F71", "wall": "#E7554E", "ring": "#F0856C"}
# 雰囲気画の 色（mood_stomach.png。測りかたは 記録の 3.2）
P_FLOOR_FAR = "#F67B68"
P_CREST = "#FFCCB4"        # ひだの 山（絵の いちばん 明るい 所は #FDB49A。光の ぶんを 引いて ひかえめ）
P_VALLEY = "#F7836A"
P_FOOT = "#E06A56"          # ひだの 手前の すそ（かげ）
P_BACK = "#DC6654"          # ひだの おく側の 坂（ゲームの カメラから ひだが 読める ように 絵より こい）
P_RIM = "#FFC8A8"          # いけの ふち（光の 当たる 側）
P_BASIN = "#E26E5A"        # いけの 底（から の とき 見える。水が あれば かくれる）
P_WALL_HIGH = "#D54444"
P_WALL_FAR = "#B7373C"
P_WALL_DEEP = "#A5313A"
P_EXIT = "#CA705C"           # 出口の 輪（雰囲気画 #E6685B。光の ぶん こく）
P_ENTRY = "#C46650"          # 入口の 輪（雰囲気画 #F0856C。下から 見あげる 面が 明るく 出る ぶん こく。見なおしで 約 1 わり こく）
P_HOLE = "#AA3036"
P_HOLE_DEEP = "#7E2430"
P_EXIT_HOLE = "#962832"     # 出口の 穴（雰囲気画 #AA3036。うしろからの 光が 入る ぶん こく）

# ------------------------------------------------------------------ おわんの 形
A, B = 30.0, 38.0          # ゆかの はば（かたがわ）・おくゆき（かたがわ）。spec の 60×76 m
P_XY = 2.4                 # 上から 見た 形（2 = だ円、大きいほど 四角い）
ZC = 4.5                   # かべが いちばん 外に ふくらむ 高さ（ここより 下は ほぼ まっすぐ）
C_DN, Q_DN = 6.0, 3.0      # 下がわ：ゆかの 下まで（ゆかと かべの さかいは ひろい まるい 入りすみ。雰囲気画の 左手前のように 坂で 上がる）
Q_UP = 2.6                 # 上がわ（天井）：まるい ドーム
_C_UP = pchip([(-40, 7.5), (-26, 9.0), (-10, 10.0), (10, 10.5), (40, 8.5)])   # 天井の 高さ（ZC から）。入口の 上は ひくめ
START = (2.5, -27.0)
START_TURN = 14.0          # スタートの 向き（おくから 右へ 何 ど）

# 入口（食道から）：天井から さがる 太い くだの 先の 輪。spec の 部品 3（外径 8、穴 5、おくゆき 1.6 m）× RING_G
RING_G = 1.5
ENTRY_XY = (0.0, -13.5)
ENTRY_LIP_Z = 7.8          # 輪の 下の はしの 高さ（ゆかから）。スタートの カメラの 画面の 上に 入る 高さ
ENTRY = {"r_out": 4.0 * RING_G, "r_in": 2.5 * RING_G, "depth": 1.6 * RING_G}
# 出口（ゆうもん）：右の かべの 下。spec の 部品 4（外径 6、穴 4、おくゆき 1.2 m）× RING_G
EXIT_Y = 21.0
EXIT = {"r_out": 3.0 * RING_G, "r_in": 2.0 * RING_G, "depth": 1.2 * RING_G}
EXIT_LIFT = 0.35           # 穴の 下の はしが ゆかから 何 m 上か
TUNNEL = 5.5               # 出口の 先の くだの ながさ（おくは 暗い 赤で とじる）

# いえきの いけ：(x, y, 半径 r)。r は マーカー名（MK_hazard_acid_r7_1 …）と 同じ。番号の 順
POOLS = [(-8.5, -15.0, 7.0), (6.5, 23.5, 5.0), (12.5, -5.0, 6.0)]
POOL_DEPTH = 0.55          # くぼみの 底（まわりの ゆかから）
POOL_LEVEL = 0.18          # 水面（まわりの ゆかから 下へ）。マーカーの 高さ
POOL_RIM = 0.32            # ふちの 高さ（spec：ひくい もりあがり 0.2 m）
POOL_FLAT = 3.8            # くぼみの まわりの たいらな ところ（r から 外へ m。ひだも おわんの 坂も ここで 消す）

# 左の かべぞいの 段（雰囲気画：かべの さいぼうと ピロリきんが のる 高い ところ）。ゆるい 坂で のぼれる
LEDGE_H = 2.3
LEDGE_X = -20.5            # 段の ふちの x（坂の まんなか）
LEDGE_W = 2.6              # 坂の はば（かたがわ）：2.3 m を 約 5 m で のぼる（いちばん 急な 所で 約 35 ど）
LEDGE_Y = (-21.0, 24.0)

# ひだ（spec の 部品 1。5.0×1.1×0.7 m）。雰囲気画では ゆかを よこぎる ながい うねなので、ながい 帯に した。
# ゲームの カメラ（ミクロごうの うしろ 5.2 m）から 山と かげが 読める ように、数を へらして 高く・はばひろく した
# （0.85 m × 7 本 では ゆかが たいらに 見えた。見なおしの 指摘）
FOLD_Y = [-22.5, -14.5, -5.5, 4.0, 14.0, 25.0]
FOLD_H = 1.3
FOLD_W = 2.0


def rho(x, y):
    """上から 見た おわんの 中での 位置（0 = まんなか、1 = かべの いちばん 外）"""
    return (np.abs(np.asarray(x, dtype=float) / A) ** P_XY + np.abs(np.asarray(y, dtype=float) / B) ** P_XY) ** (1.0 / P_XY)


def wall_low_z(x, y):
    """かべ（から）の 下がわの 面の 高さ。ゆかは ここより 上に ある 所だけ 作る"""
    r = np.clip(rho(x, y), 0.0, 1.0)
    return ZC - C_DN * np.clip(1.0 - r ** Q_DN, 0.0, 1.0) ** (1.0 / Q_DN)


def _ledge(x, y):
    x = np.asarray(x, dtype=float)
    y = np.asarray(y, dtype=float)
    edge = LEDGE_X + 1.3 * np.sin(y * 0.23 + 0.8) + 0.6 * np.sin(y * 0.61)
    k = sstep(edge + LEDGE_W, edge - LEDGE_W, x)
    k = k * sstep(LEDGE_Y[0] - 4.0, LEDGE_Y[0] + 3.0, y) * (1.0 - sstep(LEDGE_Y[1] - 3.0, LEDGE_Y[1] + 4.0, y))
    top = 0.18 * np.sin(y * 0.35 + 1.1) + 0.12 * np.sin(y * 0.9)       # 段の 上の ゆるい うねり
    return k * (LEDGE_H + top), k


def _base(x, y):
    """ひだを のせる 前の ゆか：まんなかは ほぼ 平ら、かべへ 向けて なめらかに もちあがる。左は 段"""
    r = rho(x, y)
    lg, _k = _ledge(x, y)
    roll = 0.22 * np.sin(np.asarray(x) * 0.13 + 0.4) * np.sin(np.asarray(y) * 0.09 + 1.3)
    return 0.35 * r ** 2 + 1.1 * r ** 8 + lg + roll


def _folds(x, y):
    x = np.asarray(x, dtype=float)
    y = np.asarray(y, dtype=float)
    h = np.zeros(np.broadcast(x, y).shape)
    for k, yk in enumerate(FOLD_Y):
        crest = yk + 2.2 * np.sin(x * 0.105 + k * 1.7) + 0.9 * np.sin(x * 0.27 + k * 0.9)
        amp = FOLD_H * (0.85 + 0.15 * np.sin(x * 0.07 + k))
        h = h + amp * np.exp(-((y - crest) / FOLD_W) ** 2)
    return h


def _pool_profile(d, r):
    """いけの くぼみ（まわりの ゆかを 0 と した 高さ）。d は まんなかからの きょり。
    底 −POOL_DEPTH（r−0.5 まで 平ら）→ r+2.1 で 0 へ なめらかに。ふちと 水の さかいは この 上に のせる
    べつの 部品（PoolRims：まわして 作った なめらかな わ）が 作る。ゆかは その 下に かくれる"""
    d = np.asarray(d, dtype=float)
    return -POOL_DEPTH * (1.0 - sstep(r - 0.5, r + 2.1, d))


# いけの ふち（spec の 部品 2 の「低い縁」）の 断面：(まんなかからの きょり − r, 水面からの 高さ)。
# d = r で ちょうど 水面を よこぎる（坂 1.2）。はじめと おわりは ゆかの 中に うまる
RIM_PROFILE = [(-0.62, -0.47), (-0.4, -0.3), (-0.2, -0.17), (0.0, 0.0), (0.15, 0.17), (0.32, 0.36),
               (0.55, POOL_LEVEL + POOL_RIM), (0.8, POOL_LEVEL + POOL_RIM - 0.05), (1.1, POOL_LEVEL + 0.14),
               (1.45, POOL_LEVEL + 0.03), (1.9, POOL_LEVEL - 0.08)]


def pool_ground(i):
    """いけ i の まわりの ゆかの 高さ（くぼみの 外の たいらな ところ）"""
    x, y, _r = POOLS[i]
    return float(_base(x, y))


def floor_h(x, y, folds=True):
    """ゆかの 高さ"""
    x = np.asarray(x, dtype=float)
    y = np.asarray(y, dtype=float)
    h = _base(x, y)
    f = _folds(x, y) if folds else 0.0
    r = rho(x, y)
    _lg, lk = _ledge(x, y)
    keep = (1.0 - sstep(0.8, 0.93, r)) * (1.0 - lk)
    gx, gy = goal_xy()
    keep = keep * sstep(3.0, 7.0, np.hypot(x - gx, y - gy))
    for i, (px, py, pr) in enumerate(POOLS):
        d = np.hypot(x - px, y - py)
        flat = 1.0 - sstep(pr + 2.1, pr + POOL_FLAT, d)        # くぼみの まわりは 平らに（おわんの 坂が 水面を つきぬけない）
        g = pool_ground(i)
        h = h * (1.0 - flat) + (g + _pool_profile(d, pr)) * flat
        keep = keep * (1.0 - flat)
    return h + f * keep


# ------------------------------------------------------------------ 出口の 位置
def _exit_frame():
    """出口の 輪の まんなか と 向き（かべの 外向き）"""
    y = EXIT_Y
    # ゆかの 高さで かべと であう x（ゆかの 右の はし）
    lo, hi = 0.0, A
    for _ in range(50):
        mid = (lo + hi) * 0.5
        if floor_h(mid, y, False) > wall_low_z(mid, y):
            lo = mid
        else:
            hi = mid
    xw = lo
    # 上から 見た 形の 外向きの 向き（だ円の こう配）
    gx = P_XY * (xw / A) ** (P_XY - 1) / A
    gy = P_XY * (abs(y) / B) ** (P_XY - 1) / B * math.copysign(1.0, y)
    n = np.array([gx, gy, 0.0])
    n /= np.linalg.norm(n)
    ground = float(floor_h(xw - 4.0 * n[0], y - 4.0 * n[1], False))
    c = np.array([xw, y, ground + EXIT_LIFT + EXIT["r_in"]]) - n * 1.4
    return c, n


# ゴールは 出口の 輪から 6 m 手前（3.6 m では、かべがわから 輪へ むかう とき カメラが 船に もぐりこみ、輪が 見えなかった。
# ブラウザ版の 見なおし）
GOAL_FROM_EXIT = 6.0


def goal_xy():
    c, n = _exit_frame_cached()
    p = c - n * GOAL_FROM_EXIT
    return float(p[0]), float(p[1])


_EXIT_CACHE = []


def _exit_frame_cached():
    if not _EXIT_CACHE:
        _EXIT_CACHE.append(None)            # floor_h → goal_xy の 入れ子を 止める（はじめは ゴールの まわりを 平らに しない）
        _EXIT_CACHE[0] = _exit_frame()
    if _EXIT_CACHE[0] is None:
        return np.array([1e4, 1e4, 0.0]), np.array([1.0, 0.0, 0.0])
    return _EXIT_CACHE[0]


# ------------------------------------------------------------------ 部品
def _lathe_profile(prof_r, prof_t, nu=64):
    """軸の まわりに 2D の 形（r, t）を まわした 点（軸は +Z、t が 軸の 向き）。返す：点（rows×nu×3）"""
    th = np.linspace(0.0, 2 * math.pi, nu, endpoint=False)
    X = prof_r[:, None] * np.cos(th)[None, :]
    Y = prof_r[:, None] * np.sin(th)[None, :]
    Z = np.broadcast_to(prof_t[:, None], X.shape)
    return np.stack([X, Y, Z], axis=-1)


def _collar_profile(ring, tunnel, behind, cap=True, flare=0.0):
    """輪（まるい くちびる）＋ 中の くだ の 断面。t = 0 が 輪の 正面の いちばん 前、+t が おく（かべの 外）。
    外がわは behind m おくまで のびて かべに うまる。返す：r, t, そして 1 点ずつの「輪 ↔ くだ」の 割合（0 = 輪、1 = くだの おく）"""
    ro, ri, dep = ring["r_out"], ring["r_in"], ring["depth"]
    rm, rl = (ro + ri) * 0.5, (ro - ri) * 0.5
    R, T, W = [], [], []
    for t in np.linspace(behind, dep * 0.5, 14)[:-1]:         # 外がわ（かべの 中から 前へ）。flare で らっぱの ように ひろがる
        u = (t - dep * 0.5) / max(behind - dep * 0.5, 1e-6)
        R.append(ro + flare * u ** 1.7); T.append(t); W.append(0.0)
    for a in np.linspace(0.0, math.pi, 17):                    # まるい くちびる（外 → 前 → 内）
        R.append(rm + rl * math.cos(a)); T.append(dep * 0.5 - dep * 0.5 * math.sin(a)); W.append(0.0)
    for t in np.linspace(dep * 0.5, tunnel, 14)[1:]:           # 中の くだ（おくへ）
        R.append(ri); T.append(t); W.append(float(sstep(dep * 0.5, tunnel, t)))
    if cap:
        for a in np.linspace(0.0, math.pi / 2, 7)[1:]:         # おくの ふた（まるく とじる）
            R.append(max(ri * math.cos(a), 0.02)); T.append(tunnel + ri * 0.55 * math.sin(a)); W.append(1.0)
    return np.array(R), np.array(T), np.array(W)


def _frame(axis):
    """axis を +Z に する 基底（3×3、行が x, y, z）"""
    z = np.asarray(axis, dtype=float)
    z = z / np.linalg.norm(z)
    ref = np.array([0.0, 0.0, 1.0]) if abs(z[2]) < 0.9 else np.array([1.0, 0.0, 0.0])
    x = np.cross(ref, z)
    x /= np.linalg.norm(x)
    y = np.cross(z, x)
    return np.stack([x, y, z])


def build_collar(name, ring, center, axis, tunnel, behind, mat, cap=True, nu=64, flare=0.0):
    """輪 ＋ くだ（axis の 向きに おくへ）。面は 外向き（中の くだは 軸の 向きを 向く）"""
    R, T, W = _collar_profile(ring, tunnel, behind, cap, flare)
    P = _lathe_profile(R, T, nu)
    F = _frame(axis)
    Wp = np.asarray(center)[None, None, :] + np.einsum("rnk,kj->rnj", P, F)
    ob = K.mesh_object(name, Wp.reshape(-1, 3), K.grid_faces(len(R), nu, wrap_u=True), mat)
    C.recalc_normals(ob, inside=False)
    # 外向きの はずが 中向きに なった とき（とじて いない 形）は 輪の まわりの 点で たしかめる
    K.face_toward(ob, lambda q: _away_from_axis(q, center, axis, ring))
    return ob, np.repeat(W, nu), np.repeat(T, nu)


def _away_from_axis(q, center, axis, ring):
    """輪の 外がわの 面は 軸から はなれる 向き、中の くだの 面は 軸へ 向く（ここは 多数決用：外がわ ＋ くちびる が 多い）"""
    a = np.asarray(axis, dtype=float)
    a = a / np.linalg.norm(a)
    v = q - np.asarray(center)
    radial = v - np.outer(v @ a, a)
    rl = np.linalg.norm(radial, axis=1, keepdims=True)
    out = radial / np.maximum(rl, 1e-6)
    rm = (ring["r_out"] + ring["r_in"]) * 0.5
    return np.where(rl > rm, out, -out)


def build_shell(mat, cut):
    """かべと 天井：たいらな 底の だ円の おわん（内向き）。cut(中心 N×3) が True の 面は けす（入口・出口の 穴）"""
    nv, nu = 70, 160
    phi = np.concatenate([np.linspace(-math.pi / 2, 0.0, 26)[:-1], np.linspace(0.0, math.pi / 2, nv - 25)])
    th = np.linspace(0.0, 2 * math.pi, nu, endpoint=False) - math.pi / 2     # ぬい目は スタートの うしろ
    up = phi[:, None] >= 0
    q = np.where(up, Q_UP, Q_DN)
    rr = spow(np.cos(phi)[:, None], 2.0 / q) * np.ones((1, nu))
    zu = spow(np.sin(phi)[:, None], 2.0 / q) * np.ones((1, nu))
    x = A * rr * spow(np.cos(th)[None, :], 2.0 / P_XY)
    y = B * rr * spow(np.sin(th)[None, :], 2.0 / P_XY)
    z = ZC + zu * np.where(up, _C_UP(y), C_DN)
    # おくの かべの かさなる アーチ（雰囲気画）：おくの まんなかを 中心に した わの もりあがり（内がわへ）
    far = np.clip(y / B, 0.0, 1.0)
    vn = np.stack([x / A, y / B, (z - ZC) / np.where(up, _C_UP(y), C_DN)], axis=-1)
    ang = np.arccos(np.clip(vn[..., 1] / np.maximum(np.linalg.norm(vn, axis=-1), 1e-6), -1.0, 1.0))   # おくの まんなか（0, B, ZC）からの 角度
    arches = sum(np.exp(-((ang - a0) / 0.06) ** 2) for a0 in (0.62, 0.9, 1.15)) * sstep(0.1, 0.5, far) * sstep(ZC - 2.0, ZC + 2.0, z)
    # 横の かべにも 少し まばらに つづける（雰囲気画は まわり 全部に かさなる アーチが ある。横は 太く ひくく）
    side = sum(np.exp(-((ang - a0) / 0.11) ** 2) for a0 in (1.45, 1.85)) * 1.3 * sstep(ZC - 3.0, ZC + 1.0, z) * (1.0 - sstep(ZC + 7.0, ZC + 10.0, z))
    arches = arches + side
    inward = np.stack([-x, -y, np.zeros_like(x)], axis=-1)
    inward /= np.maximum(np.linalg.norm(inward, axis=-1, keepdims=True), 1e-6)
    Pn = np.stack([x, y, z], axis=-1) + inward * (1.1 * arches)[..., None]
    pts = Pn.reshape(-1, 3)
    faces = K.grid_faces(nv, nu, wrap_u=True)
    cen = pts[faces].mean(axis=1)
    keep = ~cut(cen)
    ob = K.mesh_object("StomachShell", pts, faces[keep], mat)
    K.face_toward(ob, lambda c: np.stack([-c[:, 0], -c[:, 1], ZC - c[:, 2]], axis=1))
    du = np.concatenate([np.zeros((nv, 1)), np.cumsum(np.linalg.norm(np.diff(Pn, axis=1), axis=2), axis=1)], axis=1)[:, :nu]
    dv = np.concatenate([np.zeros((1, nu)), np.cumsum(np.linalg.norm(np.diff(Pn, axis=0), axis=2), axis=0)], axis=0)
    K.set_uv(ob, np.stack([du, dv], axis=-1).reshape(-1, 2) / K.TILE_M)
    # 色：下は 雰囲気画の 手前の かべ、上と おくは こく。アーチの みぞは さらに こく
    tone = np.tile(np.ones(3), (len(pts), 1))
    zz, yy = pts[:, 2], pts[:, 1]
    k = sstep(ZC, ZC + 9.0, zz)[:, None] * 0.45
    tone = tone * (1.0 - k) + K.ratio(P_WALL_HIGH, REF["wall"])[None, :] * k
    k = sstep(-5.0, 34.0, yy)[:, None]
    tone = tone * (1.0 - k) + tone * K.ratio(P_WALL_FAR, REF["wall"])[None, :] * k
    a1 = arches.reshape(-1)
    farr = far.reshape(-1)
    k = ((sstep(0.4, 0.9, farr) * 0.55 + (1.0 - sstep(0.4, 0.9, farr)) * 0.4) * (1.0 - np.clip(a1, 0.0, 1.0)))[:, None]
    tone = tone * (1.0 - k) + K.ratio(P_WALL_DEEP, REF["wall"])[None, :] * k
    # 大きな 筆むら（画像の くりかえしを かくす）
    wob = (np.sin(pts[:, 0] * 0.19 + pts[:, 2] * 0.13 + 1.3) * np.sin(pts[:, 1] * 0.15 - pts[:, 2] * 0.17 + 0.4)
           + 0.6 * np.sin(pts[:, 0] * 0.08 - pts[:, 1] * 0.1 + pts[:, 2] * 0.21 + 2.1))
    k = (0.5 + 0.5 * np.clip(wob / 1.6, -1.0, 1.0))[:, None] * 0.08
    tone = tone * (1.0 - k) + tone * 0.85 * k
    return ob, tone


def floor_edges(y):
    """y の 列で ゆかが かべと であう 左右の x"""
    y = np.asarray(y, dtype=float)
    out = []
    for sgn in (-1.0, 1.0):
        lo, hi = np.zeros_like(y), np.full_like(y, A)
        for _ in range(40):
            mid = (lo + hi) * 0.5
            above = floor_h(sgn * mid, y) > wall_low_z(sgn * mid, y)
            lo, hi = np.where(above, mid, lo), np.where(above, hi, mid)
        out.append(sgn * np.maximum(lo, 0.5))
    return out


def build_floor(mat):
    ys = np.concatenate([np.arange(-B + 0.6, B - 0.6, 0.36), [B - 0.6]])
    nu = 175
    xl, xr = floor_edges(ys)
    p = np.linspace(0.0, 1.0, nu)
    x = xl[:, None] + (xr - xl)[:, None] * p[None, :]
    x[:, 0] -= 0.25
    x[:, -1] += 0.25
    y = np.broadcast_to(ys[:, None], x.shape)
    z = floor_h(x, y)
    z[:, 0] -= 0.3                    # ふちは かべの 中へ しずめる
    z[:, -1] -= 0.3
    P = np.stack([x, y, z], axis=-1).reshape(-1, 3)
    ob = K.mesh_object("StomachFloor", P, K.grid_faces(len(ys), nu), mat)
    K.face_toward(ob, lambda q: np.tile([0.0, 0.0, 1.0], (len(q), 1)))
    K.set_uv(ob, P[:, :2] / K.TILE_M)
    xx, yy = P[:, 0], P[:, 1]
    tone = np.ones((len(P), 3))
    # ひだ：山の 上は 明るい すじ、すその 谷は こい（雰囲気画）。ゲームの カメラ（うしろ ななめ上）から 読める ように
    # 絵より 強めに つける。手前を 向く 坂の すそも こく（絵の ひだの 下の かげ）
    fold = _folds(xx, yy)
    base_wo = floor_h(xx, yy, folds=False)
    hf = np.clip((P[:, 2] - base_wo) / FOLD_H, 0.0, 1.0)
    crest = (sstep(0.55, 0.95, hf) * 1.0)[:, None]
    tone = tone * (1.0 - crest) + K.ratio(P_CREST, REF["floor"])[None, :] * crest
    slope = (floor_h(xx, yy + 0.2) - floor_h(xx, yy - 0.2)) / 0.4
    foot = (sstep(0.05, 0.3, hf) * (1.0 - sstep(0.4, 0.65, hf)) * np.clip(slope / 0.25, 0.0, 1.0) * 0.85)[:, None]
    tone = tone * (1.0 - foot) + K.ratio(P_FOOT, REF["floor"])[None, :] * foot
    valley = (np.clip(1.0 - fold / (FOLD_H * 0.3), 0.0, 1.0) * 0.35)[:, None] * (1.0 - crest)
    tone = tone * (1.0 - valley) + K.ratio(P_VALLEY, REF["floor"])[None, :] * valley
    # ひだの おく側の 坂（+Y を 向く 面）は こく：雰囲気画の ひだは 手前が 明るく、おくへ 下る 坂が 暗い
    back = (np.clip(-slope / 0.35, 0.0, 1.0) * 0.95)[:, None]
    tone = tone * (1.0 - back) + K.ratio(P_BACK, REF["floor"])[None, :] * back
    # いけ：ふちは 明るい ゆかの 色、底は こい（から の とき 見える）
    for i, (px, py, pr) in enumerate(POOLS):
        d = np.hypot(xx - px, yy - py)
        bot = (1.0 - sstep(pr - 0.6, pr + 0.2, d))[:, None]
        tone = tone * (1.0 - bot) + K.ratio(P_BASIN, REF["floor"])[None, :] * bot
    # おくは 少し こく
    k = sstep(-10.0, 34.0, yy)[:, None] * 0.8
    tone = tone * (1.0 - k) + tone * K.ratio(P_FLOOR_FAR, REF["floor"])[None, :] * k
    return ob, tone


def build_pool_rims(mat):
    """いけの ふち：まわして 作った なめらかな わ（水の ふちが まんまるに なる）。当たる（ミクロごうは のりこえる）"""
    obs, tones = [], []
    prof = np.array(RIM_PROFILE)
    for i, (px, py, pr) in enumerate(POOLS):
        level = pool_ground(i) - POOL_LEVEL
        P = _lathe_profile(pr + prof[:, 0], level + prof[:, 1], 128) + np.array([px, py, 0.0])
        ob = K.mesh_object(f"rim{i}", P.reshape(-1, 3), K.grid_faces(len(prof), 128, wrap_u=True), mat)
        K.face_toward(ob, lambda q: np.tile([0.0, 0.0, 1.0], (len(q), 1)))
        h = np.repeat(prof[:, 1], 128)
        top = sstep(-0.05, POOL_LEVEL + POOL_RIM, h)[:, None]
        wet = K.ratio(P_BASIN, REF["floor"])[None, :]
        tone = wet * (1.0 - top) + K.ratio(P_RIM, REF["floor"])[None, :] * top
        outer = sstep(0.7, 1.9, np.repeat(prof[:, 0], 128))[:, None]       # 外の すそは ゆかの 色へ
        tone = tone * (1.0 - outer) + outer
        obs.append(ob)
        tones.append(tone)
    return obs, tones


def build_entry(mats):
    """入口：天井から さがる くだ ＋ 先の 輪 ＋ しずく（雰囲気画の 上の まんなか）。高い ので 当たらない（NC_）"""
    x0, y0 = ENTRY_XY
    g = float(floor_h(x0, y0, False))
    center = np.array([x0, y0, g + ENTRY_LIP_Z])
    ceil_z = ZC + float(_C_UP(y0)) + 2.0
    ob, w, t = build_collar("entry_collar", ENTRY, center, (0.0, 0.0, 1.0), ceil_z - center[2] + 1.5, ceil_z - center[2] + 1.5, mats["ring"], cap=False, flare=7.0)
    # 色：輪は 入口の 色、中の くだは 上へ 暗い 赤（食道へ つづく）
    tone = np.tile(K.ratio(P_ENTRY, REF["ring"]), (len(w), 1))
    inner = sstep(0.0, 0.25, w)[:, None]
    tone = tone * (1.0 - inner) + K.ratio(P_HOLE, REF["ring"])[None, :] * inner
    deep = sstep(0.25, 1.0, w)[:, None]
    tone = tone * (1.0 - deep) + K.ratio(P_HOLE_DEEP, REF["ring"])[None, :] * deep
    out_k = (sstep(ENTRY["depth"] * 0.5, ENTRY["depth"] * 0.5 + 2.5, t) * (w == 0.0))[:, None]
    tone = tone * (1.0 - out_k) + K.ratio(P_WALL_HIGH, REF["ring"])[None, :] * out_k   # 天井へ ひろがる 外がわは かべの 色
    # しずく（輪の 手前の ふちから さがる）
    rm = (ENTRY["r_out"] + ENTRY["r_in"]) * 0.5
    V, Q, T3 = K.superellipsoid(20, 14, 1.0, 1.0)
    V[:, 2] = np.where(V[:, 2] < 0, V[:, 2] * 1.25, V[:, 2] * 0.8)
    drip = K.blob_object("drip", V * np.array([0.95, 0.85, 1.0]) + np.array([x0, y0 - rm, center[2] - 0.45]), Q, T3, mats["ring"])
    C.recalc_normals(drip, inside=False)
    return ob, tone, drip


def build_exit(mats):
    c, n = _exit_frame_cached()
    ob, w, _t = build_collar("Exit", EXIT, c, n, TUNNEL, 3.0, mats["ring"], cap=True)
    tone = np.tile(K.ratio(P_EXIT, REF["ring"]), (len(w), 1))
    inner = sstep(0.0, 0.3, w)[:, None]
    tone = tone * (1.0 - inner) + K.ratio(P_EXIT_HOLE, REF["ring"])[None, :] * inner
    deep = sstep(0.3, 1.0, w)[:, None]
    tone = tone * (1.0 - deep) + K.ratio(P_HOLE_DEEP, REF["ring"])[None, :] * deep
    return ob, tone


# ------------------------------------------------------------------ 組み立て
def build():
    _EXIT_CACHE.clear()
    mats = {k: K.surface_material("Stage" + k.capitalize(), v) for k, v in HEX.items()}
    c_exit, n_exit = _exit_frame_cached()
    x0, y0 = ENTRY_XY
    r_cut_in = (ENTRY["r_in"] + ENTRY["r_out"]) * 0.5
    r_cut_out = (EXIT["r_in"] + EXIT["r_out"]) * 0.5

    def cut(cen):
        a = np.hypot(cen[:, 0] - x0, cen[:, 1] - y0) < r_cut_in
        a &= cen[:, 2] > ZC + 2.0
        v = cen - c_exit
        along = v @ n_exit
        radial = np.linalg.norm(v - np.outer(along, n_exit), axis=1)
        b = (radial < r_cut_out) & (along > -2.0)
        return a | b

    shell_o, shell_tone = build_shell(mats["wall"], cut)
    floor_o, floor_tone = build_floor(mats["floor"])
    entry_o, entry_tone, drip = build_entry(mats)
    exit_o, exit_tone = build_exit(mats)
    rim_os, rim_tones = build_pool_rims(mats["floor"])
    for o, t in zip(rim_os, rim_tones):
        K.set_colors(o, t)
    rims = K.join_meshes(rim_os, "PoolRims")
    objs = [shell_o, floor_o, entry_o, drip, exit_o, rims]
    ao = K.bake_ao(objs, reach=6.0, rays=20, smooth=2)
    K.set_colors(shell_o, shell_tone * K.shade(ao[shell_o.name], (0.62, 0.42, 0.44), 1.2))
    K.set_colors(floor_o, floor_tone * K.shade(ao[floor_o.name], (0.66, 0.44, 0.42), 1.25))
    K.set_colors(entry_o, entry_tone * K.shade(ao[entry_o.name], (0.6, 0.4, 0.42), 1.0))
    K.set_colors(drip, K.shade(ao[drip.name], (0.7, 0.5, 0.5), 1.0))
    K.set_colors(exit_o, exit_tone * K.shade(ao[exit_o.name], (0.6, 0.4, 0.42), 1.0))
    K.set_colors(rims, K.get_colors(rims) * K.shade(ao[rims.name], (0.66, 0.44, 0.42), 1.25))
    entry = K.join_meshes([entry_o, drip], "NC_Entry")
    objs = [shell_o, floor_o, entry, exit_o, rims]
    print(f"  stomach: {K.triangle_count(objs)} triangles")

    # マーカー（高さは ゆかの 式から）
    def fz(x, y, up=1.2):
        return float(floor_h(x, y)) + up

    sx, sy = START
    # 少し 右を 向く：出口の 輪が 右上の ミッションの 箱の うらに 入らない ように（見なおしの 指摘）
    C.add_empty("MK_player", (sx, sy, fz(sx, sy, 1.5)), (0.0, 0.0, math.radians(-START_TURN)))
    gx, gy = goal_xy()
    goal = (gx, gy, fz(gx, gy, 0.8))
    C.add_empty("MK_goal", goal)
    for i, (px, py, pr) in enumerate(POOLS):
        C.add_empty(f"MK_hazard_acid_r{int(pr)}_{i + 1}", (px, py, pool_ground(i) - POOL_LEVEL))
    # なかま（かべの さいぼう）：左の 段に 2 つ、右おくの 段に 1 つ
    for i, (x, y) in enumerate([(-25.0, -9.0), (-24.5, 13.0), (4.0, 31.5)]):
        C.add_empty(f"MK_friend_wallcell_{i + 1}", (x, y, fz(x, y)))
    # ピロリきん：段の 上に 2、出口の そば、おくの まんなか、右の 手前
    for i, (x, y) in enumerate([(-24.5, 2.0), (-23.0, 20.0), (21.5, 9.5), (-6.0, 25.0), (19.0, -15.0)]):
        C.add_empty(f"MK_enemy_pylori_{i + 1}", (x, y, fz(x, y)))
    C.add_empty("MK_pickup_heart_item_1", (6.0, -17.0, fz(6.0, -17.0)))
    C.add_empty("MK_card_acid", (-0.5, -9.0, fz(-0.5, -9.0)))
    C.add_empty("MK_path_000", (sx, sy, fz(sx, sy)))
    C.add_empty("MK_path_001", (2.0, 4.0, fz(2.0, 4.0)))
    C.add_empty("MK_path_002", goal)
    return objs

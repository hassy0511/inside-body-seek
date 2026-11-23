"""ミクロごう（pod）と、中の パイロット。

納品された 3D 用の絵（art/concepts/W1_hero/ の pod_3d_*・pilot_3d_*・pod_turnaround）から 測った 寸法で 作る。
寸法・色・絵との ちがいは docs/art_orders/W1_01_pod_3D化の結果.md。

・前は +Y、上は +Z、単位は m。原点は 船体（たまご形）の まん中。
  全長 1.4 m（船首 +0.558 〜 プロペラの うしろ -0.842）。
・Godot が 名前で 探す 部品：Propeller（回る。原点は ハブ、回転軸は 前後）、Window（とうめいな ドーム）。
・色は 部品ごとに 1 色（絵から 測った hex）。形が まじわる 所の うすい 影は 頂点カラー（Col）に
  焼いて ある。シェーダーは 使わない（どの ステージの 光でも 同じ ように 見える）。
・形は ぜんぶ 式で 作る（ブーリアンなし）。たまごの 殻・ふち・内がわは 1 枚の なめらかな 面。

実行: python -m blender.characters pod
"""
from __future__ import annotations

import math

import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

try:
    from . import common as C
except ImportError:  # blender -b -P で直接実行したとき
    import os
    import sys
    sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    from blender import common as C


# ------------------------------------------------------------------ 寸法（m）
# 絵の 縮尺：正面の絵で 全長 1143 px ＝ 1.4 m（1 px ＝ 1.225 mm）。真横の絵は 1.19 倍して 測る。
HULL_A = 0.467      # 船体の 半分の 幅（正面 762 px）
HULL_B = 0.558      # 半分の 長さ（真横 912 px）
HULL_CT = 0.645     # いちばん 太い 高さから 上（正面：太い 所は 上から 52〜55%）
HULL_CB = 0.527     # いちばん 太い 高さから 下
HULL_Z0 = -0.059    # いちばん 太い 高さ（原点を 船体の まん中に する ため）
SHELL = 0.050       # 殻の 厚さ（正面の絵の クリーム色の ふち 約 40 px）
LIP = SHELL * 0.5   # ふちの 丸みの 半径
SILL_Z = -0.150     # ドームの 下の ふち（正面の絵は 上から 66%、真横の絵は 57〜62%。あいだを とった）
CUT_Y = -0.100      # ドームの うしろの ふちが、原点の 高さで 通る 前後の 位置
CUT_LEAN = math.radians(40.0)    # うしろの ふちの かたむき（上へ 行くほど 後ろへ）。pod_turnaround の 5 番目（後ろ上から）に 合わせた
CORNER = 0.26       # うしろの ふちと 下の ふちの 角の 丸み
DOME_AXIS = math.radians(60.0)   # ドームの まん中の 向き（前から 上へ）
GLASS_IN = 0.012    # ガラスは 殻の 面より これだけ 内がわ

PROP_Y = -0.752     # 羽根の まん中
PROP_Z = -0.04      # プロペラの 軸の 高さ（背面の絵：上から 53%）
PROP_R = 0.475      # 羽根の 先までの 半径
BLADE_LOBE = 0.175  # 羽根の 丸い 所の 半径
BLADE_T = 0.085     # 羽根の 厚さ
BLADE_PITCH = math.radians(12.0)
HUB_R = 0.145

# ------------------------------------------------------------------ 色（絵から 測った sRGB）
COL = {
    "hull": "#F3EBE1",      # 船体（spec は #F8F4E9。絵の 明るい 面の 色）
    "inside": "#8FA5B0",    # 船の 中（絵では ガラスごしに 青っぽい 灰色 #93A8B1）
    "yellow": "#FCC738",    # ひれ・羽根・脚の 先・座席（spec は #F2C744）
    "grey": "#8B8987",      # ハブ・脚
    "glass": "#B8E2EA",     # ドーム（spec）
    "port": "#85B6D5",      # 丸まど
    "dark": "#626C74",      # ハンドル・計器の 台
    "skin": "#FCC294",
    "blush": "#F6A58E",
    "hair": "#894927",
    "coat": "#F8E3C9",
    "band": "#C0702D",
    "lens": "#44BED0",
    "eye": "#3A2619",
    "white": "#FFF9F1",
    "mouth": "#B3523A",
}


def lin(hexcol: str):
    """sRGB の hex → リニア（Blender と glTF の 色は リニア）。"""
    h = hexcol.lstrip("#")
    out = []
    for i in (0, 2, 4):
        c = int(h[i:i + 2], 16) / 255.0
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return tuple(out)


def mat(name: str, hexcol: str, rough=0.9, alpha=1.0, emit=0.0):
    """単色の マテリアル。頂点カラー（Col）を かけ算する 形に つなぐ（glTF の COLOR_0 に なる）。片面だけ 描く。"""
    m = bpy.data.materials.get(name)
    if m is not None:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    m.use_backface_culling = True
    nt = m.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    col = lin(hexcol) + (1.0,)
    attr = nt.nodes.new("ShaderNodeVertexColor")
    attr.layer_name = "Col"
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.blend_type = "MULTIPLY"
    mix.inputs[0].default_value = 1.0
    nt.links.new(attr.outputs["Color"], mix.inputs[6])
    mix.inputs[7].default_value = col
    nt.links.new(mix.outputs[2], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = 0.0
    if emit > 0.0:
        bsdf.inputs["Emission Color"].default_value = col
        bsdf.inputs["Emission Strength"].default_value = emit
    if alpha < 1.0:
        bsdf.inputs["Alpha"].default_value = alpha
        if hasattr(m, "surface_render_method"):
            m.surface_render_method = "BLENDED"
        else:
            m.blend_method = "BLEND"
    m.diffuse_color = col[:3] + (alpha,)
    return m


# ------------------------------------------------------------------ メッシュの 道具
def skin(rings, start=None, end=None, closed=True, loop=False):
    """輪（nr, nu, 3）を 順に つないだ 面。start／end は 極の 点（三角の 扇で とじる）。loop は さいごの 輪を さいしょへ つなぐ。"""
    rings = np.asarray(rings, dtype=float)
    nr, nu, _ = rings.shape
    verts = [tuple(p) for p in rings.reshape(-1, 3)]
    faces = []
    cols = nu if closed else nu - 1
    for r in range(nr if loop else nr - 1):
        r1 = (r + 1) % nr
        for u in range(cols):
            u2 = (u + 1) % nu
            faces.append((r * nu + u, r * nu + u2, r1 * nu + u2, r1 * nu + u))
    if start is not None:
        i = len(verts)
        verts.append(tuple(start))
        for u in range(cols):
            faces.append((i, (u + 1) % nu, u))
    if end is not None:
        i = len(verts)
        verts.append(tuple(end))
        base = (nr - 1) * nu
        for u in range(cols):
            faces.append((i, base + u, base + (u + 1) % nu))
    return verts, faces


def mesh_obj(name, verts, faces, material, inside=None, invert=False, tint=None):
    """点と 面から オブジェクトを 作る。面は inside（中の 点）から 見て 外向きに そろえる。"""
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(map(float, v)) for v in verts], [], [tuple(f) for f in faces])
    me.update()
    v = np.array([p.co[:] for p in me.vertices])
    ref = np.array(inside if inside is not None else v.mean(axis=0), dtype=float)
    vol = 0.0
    for p in me.polygons:
        vol += p.area * (Vector(p.center) - Vector(ref)).dot(p.normal)
    if (vol < 0.0) != invert:
        me.flip_normals()
    for p in me.polygons:
        p.use_smooth = True
    ca = me.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    t = np.ones((len(me.vertices), 4), dtype=np.float32)
    if tint is not None:
        t[:, :3] = np.asarray(tint, dtype=np.float32).reshape(-1, 3) if np.ndim(tint) > 1 else np.asarray(tint, dtype=np.float32)
    ca.data.foreach_set("color", t.reshape(-1))
    me.materials.append(material)
    me.update()
    ob = bpy.data.objects.new(name, me)
    C.link(ob)
    return ob


def unit_rings(nu, nv):
    """単位球の 輪（極は ±Z で、輪には 入れない）。(nv-1, nu, 3)"""
    v = np.linspace(0.0, np.pi, nv + 1)[1:-1]
    u = np.linspace(0.0, 2.0 * np.pi, nu, endpoint=False)
    U, V = np.meshgrid(u, v)
    return np.stack([np.sin(V) * np.cos(U), np.sin(V) * np.sin(U), np.cos(V)], axis=-1)


def rot(rx=0.0, ry=0.0, rz=0.0):
    """X → Y → Z の 順に 回す 行列（度）。"""
    ax, ay, az = (math.radians(a) for a in (rx, ry, rz))
    mx = np.array([[1, 0, 0], [0, math.cos(ax), -math.sin(ax)], [0, math.sin(ax), math.cos(ax)]])
    my = np.array([[math.cos(ay), 0, math.sin(ay)], [0, 1, 0], [-math.sin(ay), 0, math.cos(ay)]])
    mz = np.array([[math.cos(az), -math.sin(az), 0], [math.sin(az), math.cos(az), 0], [0, 0, 1]])
    return mz @ my @ mx


def frame(axis, hint=(0.0, 0.0, 1.0)):
    """axis を ローカルの Z に する 行列（列が X・Y・Z）。hint は ローカルの X に 近づけたい 向き。"""
    z = np.asarray(axis, dtype=float)
    z = z / np.linalg.norm(z)
    h = np.asarray(hint, dtype=float)
    if abs(np.dot(h, z)) > 0.98:
        h = np.array([1.0, 0.0, 0.0])
    x = h - z * np.dot(h, z)
    x = x / np.linalg.norm(x)
    y = np.cross(z, x)
    return np.stack([x, y, z], axis=1)


def blob(name, material, center, radii, nu=16, nv=10, m=None, warp=None, tint=None):
    """だ円体。warp は 単位球の 点 (…, 3) を 変形する 関数。m は 向きの 行列。"""
    rings = unit_rings(nu, nv)
    pts = [rings, np.array([0.0, 0.0, 1.0]), np.array([0.0, 0.0, -1.0])]
    out = []
    for p in pts:
        if warp is not None:
            p = warp(p)
        p = p * np.asarray(radii, dtype=float)
        if m is not None:
            p = p @ np.asarray(m).T
        out.append(p + np.asarray(center, dtype=float))
    verts, faces = skin(out[0], out[1], out[2])
    return mesh_obj(name, verts, faces, material, inside=center, tint=tint)


def lathe(name, material, profile, origin, axis, nu=20, ell=(1.0, 1.0), hint=(0.0, 0.0, 1.0), tint=None, inside=None):
    """回転体。profile は (半径, 軸に そった 高さ) の 列。半径 0 の 端は 極に なる。ell で 断面を だ円に する。"""
    prof = [(float(r), float(h)) for r, h in profile]
    m = frame(axis, hint)
    u = np.linspace(0.0, 2.0 * np.pi, nu, endpoint=False)
    start = end = None
    if prof[0][0] <= 1e-9:
        start = np.array([0.0, 0.0, prof[0][1]])
        prof = prof[1:]
    if prof[-1][0] <= 1e-9:
        end = np.array([0.0, 0.0, prof[-1][1]])
        prof = prof[:-1]
    rings = np.array([[(r * ell[0] * math.cos(a), r * ell[1] * math.sin(a), h) for a in u] for r, h in prof])
    o = np.asarray(origin, dtype=float)
    rings = rings @ m.T + o
    if start is not None:
        start = start @ m.T + o
    if end is not None:
        end = end @ m.T + o
    verts, faces = skin(rings, start, end)
    mid = (rings.reshape(-1, 3)).mean(axis=0) if inside is None else inside
    return mesh_obj(name, verts, faces, material, inside=mid, tint=tint)


def teardrop(name, material, root, tip, radii, hint=(0.0, 0.0, 1.0), nu=12, n=8, a=1.55, b=0.62, bend=(0.0, 0.0, 0.0), taper=0.0, tip_pow=1.0, fix=None):
    """根もとが 太く、先が 丸い しずく形（ひれ・髪の はね）。radii は 根もとの 断面（hint の 向き、その 直角）。bend で 先を 曲げる。
    太さは (1 - t^a)^b × (1 - taper × t)。b ＝ 0.5 で 先が 丸く とじ、taper で 円すいに 近づく。tip_pow ＞ 1 で 輪を 先に 寄せる。
    fix は 点 (…, 3) を 直す 関数（船体の 中に 入りすぎた 根もとを 殻の 中へ 戻す、など）。
    直された 点だけで できた 面は 消す（どうせ 見えない。残すと 平らな 面が 殻の 丸みを 横切って 船の 中に 出る）。"""
    root = np.asarray(root, dtype=float)
    tip = np.asarray(tip, dtype=float)
    m = frame(tip - root, hint)
    u = np.linspace(0.0, 2.0 * np.pi, nu, endpoint=False)
    bend = np.asarray(bend, dtype=float)
    rings = []
    for i in range(n):
        t = 1.0 - (1.0 - i / float(n)) ** tip_pow
        w = (1.0 - t ** a) ** b * (1.0 - taper * t)
        c = root + (tip - root) * t + bend * (t * t)
        rings.append(c + w * (radii[0] * np.cos(u)[:, None] * m[:, 0] + radii[1] * np.sin(u)[:, None] * m[:, 1]))
    rings = np.array(rings)
    start = root
    moved = None
    if fix is not None:
        fixed = fix(rings)
        moved = np.linalg.norm(fixed - rings, axis=-1).reshape(-1) > 1e-6
        rings = fixed
        start = fix(root)
    verts, faces = skin(rings, start, tip + bend)
    if moved is not None:
        hidden = np.concatenate([moved, [True, False]])   # 根もとの 極は かくれて いる。先の 極は 見える
        faces = [f for f in faces if not all(hidden[i] for i in f)]
    ob = mesh_obj(name, verts, faces, material, inside=(root + tip) * 0.5)
    if moved is not None:
        _drop_loose(ob)
    return ob


def tube(name, material, path, radii, nu=10, loop=False, normals=None, up=(0.0, 0.0, 1.0), caps=True, scale=None, tint=None):
    """点の 列に そった くだ。断面は だ円（radii ＝（法線の 向き、その 直角））。法線は normals か up から 決める。
    とじない くだは 両はしを 丸く とじる。scale は 点ごとの 太さの 倍率。"""
    path = np.asarray(path, dtype=float)
    n = len(path)
    if loop:
        tan = np.roll(path, -1, axis=0) - np.roll(path, 1, axis=0)
    else:
        tan = np.gradient(path, axis=0)
    tan /= np.linalg.norm(tan, axis=-1, keepdims=True)
    nrm = np.asarray(normals, dtype=float) if normals is not None else np.tile(np.asarray(up, dtype=float), (n, 1))
    nrm = nrm - tan * np.sum(nrm * tan, axis=-1, keepdims=True)
    nrm /= np.linalg.norm(nrm, axis=-1, keepdims=True)
    bi = np.cross(tan, nrm)
    u = np.linspace(0.0, 2.0 * np.pi, nu, endpoint=False)
    sc = np.ones(n) if scale is None else np.asarray(scale, dtype=float)

    def ring(i, k=1.0, shift=0.0):
        c = path[i] + tan[i] * shift
        return c + k * sc[i] * (radii[0] * np.cos(u)[:, None] * nrm[i] + radii[1] * np.sin(u)[:, None] * bi[i])

    rings = [ring(i) for i in range(n)]
    start = end = None
    if not loop and caps:
        rc = min(radii)
        head = [ring(0, math.cos(math.radians(a)), -rc * sc[0] * math.sin(math.radians(a))) for a in (60.0, 30.0)]
        tail = [ring(n - 1, math.cos(math.radians(a)), rc * sc[-1] * math.sin(math.radians(a))) for a in (30.0, 60.0)]
        rings = head + rings + tail
        start = path[0] - tan[0] * rc * sc[0]
        end = path[-1] + tan[-1] * rc * sc[-1]
    verts, faces = skin(np.array(rings), start, end, loop=loop)
    inside = path.mean(axis=0) if not loop else None
    ob = mesh_obj(name, verts, faces, material, inside=inside, tint=tint)
    if loop:
        _closed_outward(ob)
    return ob


def bezier(p0, p1, p2, n):
    """3 点の なめらかな 道（2 次ベジェ）。"""
    p0, p1, p2 = (np.asarray(p, dtype=float) for p in (p0, p1, p2))
    t = np.linspace(0.0, 1.0, n)[:, None]
    return (1 - t) ** 2 * p0 + 2 * (1 - t) * t * p1 + t ** 2 * p2


def tint_by(ob, fn):
    """頂点カラーに 色を かける。fn は 点 (N, 3) → かける 色 (N, 3)。"""
    me = ob.data
    ca = me.color_attributes["Col"]
    col = np.zeros(len(me.vertices) * 4, dtype=np.float32)
    ca.data.foreach_get("color", col)
    col = col.reshape(-1, 4)
    pts = np.array([v.co[:] for v in me.vertices])
    col[:, :3] *= np.asarray(fn(pts), dtype=np.float32)
    ca.data.foreach_set("color", col.reshape(-1))
    me.update()


def ratio(to_hex, from_hex):
    """from の 色の マテリアルを to の 色に 見せる ための、頂点カラーの 倍率。"""
    return np.minimum(np.array(lin(to_hex)) / np.array(lin(from_hex)), 1.0)


def arc(r, h0, a0, a1, n, cx=None):
    """回転体の 角の 丸み：中心 (cx, h0) から 半径 r の 円弧の 点（度。0° ＝ 外向き、90° ＝ 軸の ＋）。"""
    out = []
    for i in range(n + 1):
        a = math.radians(a0 + (a1 - a0) * i / n)
        out.append(((cx or 0.0) + r * math.cos(a), h0 + r * math.sin(a)))
    return out


# ------------------------------------------------------------------ たまご形の 船体
HULL_O = np.array([0.0, 0.0, HULL_Z0])


def egg(d):
    """向き d（…, 3）の 船体の 面の 点。上半分と 下半分で 高さの 半径が ちがう たまご形。"""
    d = np.asarray(d, dtype=float)
    c = np.where(d[..., 2] >= 0.0, HULL_CT, HULL_CB)
    k = (d[..., 0] / HULL_A) ** 2 + (d[..., 1] / HULL_B) ** 2 + (d[..., 2] / c) ** 2
    return HULL_O + d / np.sqrt(k)[..., None]


def egg_normal(p):
    q = np.asarray(p, dtype=float) - HULL_O
    c = np.where(q[..., 2] >= 0.0, HULL_CT, HULL_CB)
    n = np.stack([q[..., 0] / HULL_A ** 2, q[..., 1] / HULL_B ** 2, q[..., 2] / c ** 2], axis=-1)
    return n / np.linalg.norm(n, axis=-1, keepdims=True)


def on_egg(p, lift=0.0):
    """点 p を 船体の 面へ（中心から 見た 向きの まま）。lift だけ 面から 外へ 浮かせる。"""
    q = egg(np.asarray(p, dtype=float) - HULL_O)
    return q + egg_normal(q) * lift


def into_shell(p, depth=SHELL * 0.6):
    """船体の 面より depth より 深く 入った 点を、殻の 厚みの 中まで 戻す（部品の 根もとが 船の 中へ 突き出ない ように）。"""
    p = np.asarray(p, dtype=float)
    v = p - HULL_O
    r = np.linalg.norm(v, axis=-1, keepdims=True)
    r_max = np.linalg.norm(egg(v) - HULL_O, axis=-1, keepdims=True) - depth
    return HULL_O + v * np.maximum(1.0, r_max / np.maximum(r, 1e-9))


def dome_field(p):
    """ドーム（ガラス）の 範囲で 正。下の ふち（水平）と うしろの ふち（後ろへ たおした 面）を 丸く つなぐ。"""
    u1 = p[..., 2] - SILL_Z
    u2 = (p[..., 1] - CUT_Y) * math.cos(CUT_LEAN) + p[..., 2] * math.sin(CUT_LEAN)
    h = np.maximum(CORNER - np.abs(u1 - u2), 0.0) / CORNER
    return np.minimum(u1, u2) - h * h * CORNER * 0.25


def dome_dirs(theta, phi):
    """ドームの 軸から 角度 theta、まわりの 角度 phi の 向き。"""
    a = np.array([0.0, math.cos(DOME_AXIS), math.sin(DOME_AXIS)])
    e1 = np.array([1.0, 0.0, 0.0])
    e2 = np.cross(a, e1)
    st = np.sin(theta)[..., None]
    return np.cos(theta)[..., None] * a + st * (np.cos(phi)[..., None] * e1 + np.sin(phi)[..., None] * e2)


def dome_edge(nu):
    """まわりの 角度ごとに、ドームの ふちの 角度 theta0（二分法）。"""
    phi = np.linspace(0.0, 2.0 * np.pi, nu, endpoint=False)
    lo = np.full(nu, 0.05)
    hi = np.full(nu, math.pi - 0.3)
    for _ in range(48):
        mid = (lo + hi) * 0.5
        inside = dome_field(egg(dome_dirs(mid, phi))) > 0.0
        lo = np.where(inside, mid, lo)
        hi = np.where(inside, hi, mid)
    return phi, (lo + hi) * 0.5


def build_hull(m_hull, m_glass, nu=72, n_out=22, n_lip=5, n_in=6, n_glass=8):
    """殻（外がわ → 丸い ふち → 内がわ）と ガラス。戻り値は (hull, glass)。"""
    phi, th0 = dome_edge(nu)
    edge = egg(dome_dirs(th0, phi))
    n_edge = egg_normal(edge)
    # ふちに そう 向き → ふちに 直角で ガラスの ほうを 向く 向き t
    along = np.roll(edge, -1, axis=0) - np.roll(edge, 1, axis=0)
    t = np.cross(along, n_edge)
    t /= np.linalg.norm(t, axis=-1, keepdims=True)
    toward = egg(dome_dirs(th0 * 0.9, phi)) - edge
    t *= np.sign(np.sum(t * toward, axis=-1))[:, None]

    rings = []
    tints = []
    cream = np.ones(3)
    grey = np.array(lin(COL["inside"])) / np.array(lin(COL["hull"]))
    # 外がわ：うしろ下の 極 → ふち
    for i in range(n_out - 1, 0, -1):
        rings.append(egg(dome_dirs(th0 + (i / float(n_out)) * (math.pi - th0), phi)))
        tints.append(cream)
    rings.append(edge)
    tints.append(cream)
    # 丸い ふち（半円）
    for k in range(1, n_lip + 1):
        a = math.pi * k / n_lip
        rings.append(edge + LIP * (math.sin(a) * t - (1.0 - math.cos(a)) * n_edge))
        tints.append(cream)
    # 内がわ：ふち → 極。ふちの すぐ 下で、頂点カラーで 灰色に 変える
    for s in [0.04] + [i / float(n_in) for i in range(1, n_in)]:
        p = egg(dome_dirs(th0 + s * (math.pi - th0), phi))
        rings.append(p - SHELL * egg_normal(p))
        tints.append(grey)
    pole = egg(dome_dirs(np.array([math.pi]), np.array([0.0])))[0]
    start = pole
    end = pole - SHELL * egg_normal(pole)
    verts, faces = skin(np.array(rings), start, end)
    tint = np.concatenate([np.repeat(np.array(tints), nu, axis=0), [cream], [grey]])
    # 殻は とじた 立体なので、体積で 面の 向きを 決める（中身の ある ほうが 内）
    hull = mesh_obj("pod_hull", verts, faces, m_hull, inside=(0.0, -0.3, -0.2 - SHELL), tint=tint)
    _closed_outward(hull)

    # ガラス：殻より 少し 内がわ。はしの 輪は ふちの 丸みの 中に かくれる（丸みの 半径より 浅いので）
    g_rings = []
    for j in range(1, n_glass + 1):
        s = j / float(n_glass)
        p = egg(dome_dirs(th0 * s, phi))
        g_rings.append(p - GLASS_IN * egg_normal(p))
    top = egg(dome_dirs(np.array([0.0]), np.array([0.0])))[0]
    top = top - GLASS_IN * egg_normal(top)
    gv, gf = skin(np.array(g_rings), top, None)
    glass = mesh_obj("Window", gv, gf, m_glass, inside=HULL_O)
    return hull, glass


def _drop_loose(ob):
    """どの 面にも 使われて いない 頂点を 消す。"""
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.update()


def _closed_outward(ob):
    """とじた メッシュの 面を 外向きに そろえる。"""
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.update()


# ------------------------------------------------------------------ 船の 部品
def build_fins(m_yellow):
    """左右の ひれ：だ円の 断面の 円すいで、先は 小さく 丸い。下 1/3、まん中より 少し うしろ。"""
    out = []
    for sx in (-1.0, 1.0):
        # 根もとは 船体の 中から 始めて、殻の 厚みの 中に おさめる（船体の 丸みに そって すきまなく 付き、船の 中へは 出ない）
        root = np.array([sx * 0.260, -0.115, -0.250])
        tip = np.array([sx * 0.660, -0.185, -0.350])
        # 断面の 長いほうは 前後（うしろ下がり）
        hint = np.array([0.0, math.cos(math.radians(16.0)), math.sin(math.radians(16.0))])
        out.append(teardrop(f"pod_fin{int(sx)}", m_yellow, root, tip, (0.326, 0.245), hint=hint, nu=20, n=12, a=2.2, b=0.5,
                            taper=0.50, tip_pow=1.8, fix=into_shell))
    return out


def build_legs(m_grey, m_yellow):
    """着陸脚 3 本（前の 左右＋うしろ 中央）：灰色の 円柱＋黄色い 丸い 先。"""
    out = []
    specs = [((-0.205, 0.180, -0.38), (-0.385, 0.285, -0.723)),
             ((0.205, 0.180, -0.38), (0.385, 0.285, -0.723)),
             ((0.0, -0.290, -0.36), (0.0, -0.470, -0.723))]
    for i, (a, b) in enumerate(specs):
        a = np.array(a)
        b = np.array(b)
        axis = b - a
        length = float(np.linalg.norm(axis))
        foot = 0.165   # 黄色い 先の 長さ
        r_leg, r_foot = 0.066, 0.080
        h0 = length - foot
        # 円柱は 輪を こまかく 入れる（影の 頂点カラーが 見える 所に 乗る ように）
        prof = [(r_leg, h0 + 0.03 - 0.03 * k) for k in range(int((h0 + 0.03) / 0.03) + 1)][::-1]
        out.append(lathe(f"pod_leg{i}", m_grey, prof, a, axis, nu=14))
        prof = [(r_leg * 0.9, h0 - 0.004), (r_foot - 0.014, h0), (r_foot - 0.004, h0 + 0.008), (r_foot, h0 + 0.022)]
        prof += [(r_foot, h0 + 0.022 + (length - r_foot - h0 - 0.022) * k / 2.0) for k in (1, 2)]
        prof += [(r_foot * math.cos(math.radians(t)), length - r_foot + r_foot * math.sin(math.radians(t))) for t in (22.5, 45.0, 67.5)]
        prof += [(0.0, length)]
        out.append(lathe(f"pod_foot{i}", m_yellow, prof, a, axis, nu=14))
    return out


def build_collar(m_grey):
    """プロペラの 手前の 太い 軸（回らない）。"""
    r = HUB_R + 0.008
    y0, y1 = -0.50, -0.664   # 前の はしは 殻の 厚みの 中（船の 中へ 出ない）
    prof = [(r, 0.0), (r, (y0 - y1) - 0.02)] + arc(0.02, (y0 - y1) - 0.02, 0.0, 90.0, 3, cx=r - 0.02)[1:] + [(0.0, y0 - y1)]
    return lathe("pod_collar", m_grey, prof, (0.0, y0, PROP_Z), (0.0, -1.0, 0.0), nu=24)


def petal_radius(u, lobe, neck_r, neck_d):
    """丸（半径 lobe）と、根もとの 小さな 丸（半径 neck_r、距離 neck_d、-X がわ）を つつんだ 形の、中心からの 距離。"""
    n = np.linspace(0.0, 2.0 * np.pi, 720, endpoint=False)
    h = np.maximum(lobe, -np.cos(n) * neck_d + neck_r)          # 支持関数
    c = np.cos(n[None, :] - u[..., None])
    r = np.where(c > 1e-3, h[None, :] / np.maximum(c, 1e-3), np.inf)
    return r.min(axis=-1)


def build_propeller(m_yellow, m_grey):
    """3 枚羽根＋ハブ。羽根は 丸い しずく形の 厚い 板（ふちは 半円）。原点は ハブ（あとで そろえる）。"""
    parts = []
    nu, n_flat, n_rim = 24, 2, 3
    edge = BLADE_T * 0.5
    lobe_c = PROP_R - BLADE_LOBE
    u = np.linspace(0.0, 2.0 * np.pi, nu, endpoint=False)
    rad = petal_radius(u, BLADE_LOBE, 0.062, lobe_c - 0.085)
    cu, su = np.cos(u), np.sin(u)

    def ring(inset, z):
        rr = np.maximum(rad - inset, 0.0)
        return np.stack([lobe_c + rr * cu, rr * su, np.full(nu, z)], axis=-1)

    rings = []
    for i in range(1, n_flat + 1):   # 表の 平らな 面（中心 → ふち）
        f = i / float(n_flat)
        rr = (rad - edge) * f
        rings.append(np.stack([lobe_c + rr * cu, rr * su, np.full(nu, edge)], axis=-1))
    for i in range(1, 2 * n_rim):    # ふちの 半円
        a = math.pi * i / (2 * n_rim)
        rings.append(ring(edge * (1.0 - math.sin(a)), edge * math.cos(a)))
    for i in range(n_flat, 0, -1):   # 裏
        f = i / float(n_flat)
        rr = (rad - edge) * f
        rings.append(np.stack([lobe_c + rr * cu, rr * su, np.full(nu, -edge)], axis=-1))
    rings = np.array(rings)
    top = np.array([lobe_c, 0.0, edge])
    bot = np.array([lobe_c, 0.0, -edge])
    pitch = rot(rx=math.degrees(BLADE_PITCH))
    # 羽根の ローカル（X ＝ 外向き、Y ＝ 幅、Z ＝ 厚さ）→ 船の 座標（外向き ＝ 上、幅 ＝ 左右、厚さ ＝ 前後）
    to_ship = np.array([[0.0, 1.0, 0.0], [0.0, 0.0, 1.0], [1.0, 0.0, 0.0]])
    for k in range(3):
        m = rot(ry=120.0 * k) @ to_ship @ pitch
        r2 = rings @ m.T + np.array([0.0, PROP_Y, PROP_Z])
        t2 = top @ m.T + np.array([0.0, PROP_Y, PROP_Z])
        b2 = bot @ m.T + np.array([0.0, PROP_Y, PROP_Z])
        verts, faces = skin(r2, t2, b2)
        parts.append(mesh_obj(f"blade{k}", verts, faces, m_yellow, inside=r2.reshape(-1, 3).mean(axis=0)))
    # ハブ：角の 丸い 円柱。うしろの 面に 丸い ふくらみ
    y0, y1 = -0.660, -0.826
    ln = y0 - y1
    r = HUB_R
    prof = [(0.0, 0.0), (r - 0.02, 0.0)] + arc(0.02, 0.02, -90.0, 0.0, 3, cx=r - 0.02)[1:]
    prof += [(r, ln - 0.028)] + arc(0.028, ln - 0.028, 0.0, 90.0, 4, cx=r - 0.028)[1:]
    prof += [(r * 0.62, ln), (r * 0.56, ln + 0.008), (r * 0.30, ln + 0.014), (0.0, ln + 0.016)]
    parts.append(lathe("hub", m_grey, prof, (0.0, y0, PROP_Z), (0.0, -1.0, 0.0), nu=24))
    return parts


def build_ports(m_port, m_hull):
    """左右の 丸まど：船体の 面に そった 青い 円ばんと、クリーム色の 低い ふち。"""
    out = []
    radius = 0.112
    for sx in (-1.0, 1.0):
        # 真横の絵は うしろから 23%、上から 43%。ドームの うしろの ふちに かからない ように、少し 後ろ・下に 置く
        c = on_egg(np.array([sx * 0.5, -0.335, 0.045]))
        n = egg_normal(c)
        m = frame(n, hint=(0.0, 0.0, 1.0))
        u = np.linspace(0.0, 2.0 * np.pi, 24, endpoint=False)

        def ring(rho, lift):
            flat = c + (np.cos(u)[:, None] * m[:, 0] + np.sin(u)[:, None] * m[:, 1]) * rho
            return on_egg(flat, lift)

        # 円ばん（少し へこんで 見える ように、ふちより 低い）
        disc = [ring(radius * f, 0.003 + 0.003 * (1.0 - f * f)) for f in (0.5, 1.0)]
        dv, df = skin(np.array(disc), start=on_egg(c, 0.006))
        out.append(mesh_obj(f"pod_port{int(sx)}", dv, df, m_port, inside=HULL_O))
        # ふち（低い 丸い 帯）
        tube_r = 0.012
        rim = []
        for k in range(6):
            a = math.pi * k / 5.0
            rim.append(ring(radius + tube_r * 0.7 - tube_r * math.cos(a), -0.003 + tube_r * 0.8 * math.sin(a)))
        rv, rf = skin(np.array(rim), closed=True)
        out.append(mesh_obj(f"pod_portrim{int(sx)}", rv, rf, m_hull, inside=HULL_O))
    return out


# ------------------------------------------------------------------ 船の 中（座席・ゆか・ハンドル）
SEAT_C = np.array([0.0, 0.07, -0.095])
WHEEL_C = np.array([0.0, 0.355, -0.060])
WHEEL_N = np.array([0.0, -0.82, 0.57]) / math.hypot(0.82, 0.57)   # ハンドルの 面の 向き（パイロットの 顔の ほう）
WHEEL_R = 0.095
FLOOR_Z = -0.245


def wheel_point(deg, r=WHEEL_R):
    """ハンドルの 輪の 上の 点（0° ＝ 右、90° ＝ 上）。"""
    ex = np.array([1.0, 0.0, 0.0])
    up = np.cross(WHEEL_N, ex)
    up = up if up[2] > 0 else -up
    a = math.radians(deg)
    return WHEEL_C + r * (math.cos(a) * ex + math.sin(a) * up)


def build_cockpit(m_yellow, m_grey, m_dark):
    out = []
    # ゆか：ドームの 下の ふちより 少し 下。殻の 内がわに かくれる 大きさ
    floor = lathe("pod_floor", m_grey, [(0.0, 0.0), (0.14, 0.0), (0.28, 0.0), (0.37, 0.0), (0.418, 0.0)],
                  (0.0, 0.0, FLOOR_Z), (0.0, 0.0, 1.0), nu=24, ell=(1.0, 1.21), hint=(1.0, 0.0, 0.0), inside=(0.0, 0.0, -0.6))
    tint_by(floor, lambda p: np.tile(ratio("#7C7B7C", COL["grey"]), (len(p), 1)))
    out.append(floor)
    # 座席：パイロットを うしろから かこむ 黄色い クッション（前から 見ると 左右に 見える）
    ang = np.radians(np.linspace(12.0, -192.0, 17))
    path = SEAT_C + 0.262 * np.stack([np.cos(ang), np.sin(ang), np.zeros_like(ang)], axis=-1)
    radial = np.stack([np.cos(ang), np.sin(ang), np.zeros_like(ang)], axis=-1)
    out.append(tube("pod_seat", m_yellow, path, (0.078, 0.130), nu=12, normals=radial))
    # 計器の 台と ハンドル
    out.append(blob("pod_dash", m_dark, (0.0, 0.385, -0.235), (0.215, 0.075, 0.070), nu=14, nv=8))
    ring = np.array([wheel_point(a) for a in np.linspace(0.0, 360.0, 24, endpoint=False)])
    out.append(tube("pod_wheel", m_dark, ring, (0.019, 0.019), nu=8, loop=True, normals=np.tile(WHEEL_N, (24, 1))))
    out.append(blob("pod_wheelhub", m_dark, WHEEL_C, (0.036, 0.036, 0.020), nu=12, nv=6, m=frame(WHEEL_N)))
    bar = np.array([wheel_point(180.0, WHEEL_R * 0.98), WHEEL_C, wheel_point(0.0, WHEEL_R * 0.98)])
    out.append(tube("pod_wheelbar", m_dark, bar, (0.010, 0.014), nu=6, normals=np.tile(WHEEL_N, (3, 1)), caps=False))
    low = np.array([WHEEL_C, wheel_point(270.0, WHEEL_R * 0.98)])
    out.append(tube("pod_wheellow", m_dark, low, (0.010, 0.014), nu=6, normals=np.tile(WHEEL_N, (2, 1)), caps=False))
    col = np.array([WHEEL_C - WHEEL_N * 0.01, np.array([0.0, 0.43, -0.22])])
    out.append(tube("pod_column", m_dark, col, (0.021, 0.021), nu=8, up=(1.0, 0.0, 0.0), caps=False))
    return out


# ------------------------------------------------------------------ パイロット（上半身）
# 船の 絵の 中の 大きさで 作る（頭が 髪こみで 幅 約 0.5 m。spec_3d の 単体の 寸法より 大きい）。
HEAD_C = np.array([0.0, 0.115, 0.185])
HEAD_R = np.array([0.200, 0.190, 0.172])
HAIR_C = np.array([0.0, 0.050, 0.240])
HAIR_R = np.array([0.234, 0.225, 0.200])


def _on_ellipsoid(c, r, d, lift=0.0):
    """中心 c・半径 r の だ円体の、向き d の 面の 点と 法線。"""
    d = np.asarray(d, dtype=float)
    q = d / np.sqrt(np.sum((d / r) ** 2, axis=-1, keepdims=True))
    n = q / (r * r)
    n = n / np.linalg.norm(n, axis=-1, keepdims=True)
    return c + q + n * lift, n


def face_point(x, z, lift=0.0):
    """顔（頭の 前の 面）の 点と 法線。x・z は 頭の 中心から。"""
    k = 1.0 - (x / HEAD_R[0]) ** 2 - (z / HEAD_R[2]) ** 2
    q = np.array([x, HEAD_R[1] * math.sqrt(max(k, 0.0)), z])
    n = q / (HEAD_R * HEAD_R)
    n = n / np.linalg.norm(n)
    return HEAD_C + q + n * lift, n


def hair_point(d, lift=0.0):
    return _on_ellipsoid(HAIR_C, HAIR_R, d, lift)


def build_pilot(m_skin, m_hair, m_coat, m_yellow, m_lens, m_band, m_eye, m_white, m_mouth):
    out = []
    # ---- 頭。ほおの 赤みは 頂点カラー
    head = blob("pilot_head", m_skin, HEAD_C, HEAD_R, nu=36, nv=20)
    cheeks = [face_point(sx * 0.122, -0.060)[0] for sx in (-1.0, 1.0)]
    blush = ratio(COL["blush"], COL["skin"])

    def cheek_tint(p):
        w = np.zeros(len(p))
        for c in cheeks:
            d = np.linalg.norm(p - c, axis=-1) / 0.055
            w = np.maximum(w, np.clip(1.0 - d, 0.0, 1.0) ** 1.3)
        return 1.0 + (blush - 1.0) * (0.85 * w)[:, None]

    tint_by(head, cheek_tint)
    out.append(head)
    for sx in (-1.0, 1.0):
        out.append(blob(f"pilot_ear{int(sx)}", m_skin, HEAD_C + np.array([sx * 0.196, -0.015, -0.025]), (0.030, 0.042, 0.052), nu=10, nv=6))
    # ---- 顔：目（白目・ひとみ・光の 点）、まゆ、はな、口
    for sx in (-1.0, 1.0):
        p, n = face_point(sx * 0.076, -0.016)
        m = frame(n, hint=(1.0, 0.0, 0.0))
        # 白目は 低く、ひとみは その 上に 高く 盛る（内がわに 寄せて、白目が 外がわに 細く のぞく）
        out.append(blob(f"pilot_eyewhite{int(sx)}", m_white, p - n * 0.0095, (0.041, 0.049, 0.012), nu=12, nv=6, m=m))
        eye_c = p - n * 0.007 - m[:, 0] * (sx * 0.005)
        eye_r = np.array([0.035, 0.046, 0.016])
        out.append(blob(f"pilot_eye{int(sx)}", m_eye, eye_c, eye_r, nu=14, nv=8, m=m))
        # 光の 点：ひとみの 面の 上（絵と 同じく、どちらの 目も 画像の 右上）
        q, qn = _on_ellipsoid(np.zeros(3), eye_r, np.array([-0.36, -0.40, 0.84]))
        out.append(blob(f"pilot_glint{int(sx)}", m_white, eye_c + m @ q, (0.010, 0.010, 0.003), nu=8, nv=4, m=frame(m @ qn, hint=(1.0, 0.0, 0.0))))
        brow = [face_point(sx * x, z, 0.003) for x, z in ((0.050, 0.060), (0.074, 0.069), (0.098, 0.061))]
        pts = bezier(brow[0][0], brow[1][0] * 2 - (brow[0][0] + brow[2][0]) * 0.5, brow[2][0], 7)
        out.append(tube(f"pilot_brow{int(sx)}", m_hair, pts, (0.005, 0.009), nu=6, normals=np.tile(brow[1][1], (7, 1))))
    p, n = face_point(0.0, -0.052)
    nose = blob("pilot_nose", m_skin, p - n * 0.003, (0.012, 0.011, 0.009), nu=8, nv=4, m=frame(n, hint=(1.0, 0.0, 0.0)))
    tint_by(nose, lambda q: np.tile(ratio("#F9B193", COL["skin"]), (len(q), 1)))
    out.append(nose)
    smile = []
    norms = []
    for x in np.linspace(-0.030, 0.030, 7):
        q, n = face_point(x, -0.090 + 0.014 * (x / 0.030) ** 2, 0.001)
        smile.append(q)
        norms.append(n)
    out.append(tube("pilot_mouth", m_mouth, np.array(smile), (0.004, 0.005), nu=6, normals=np.array(norms)))

    # ---- 髪：大きな かたまり 1 つ＋はね。前髪は ひたいに そわせる
    out.append(blob("pilot_hair", m_hair, HAIR_C, HAIR_R, nu=24, nv=14))
    tufts = [  # (根もとの 向き, 先の 向き, 長さ, 根もとの 太さ)。外へ はねて 少し たれる、丸い 先
        ((0.80, 0.20, 0.58), (0.80, 0.00, 0.40), 0.048, 0.078),
        ((-0.80, 0.20, 0.58), (-0.80, 0.00, 0.40), 0.048, 0.078),
        ((0.98, 0.12, 0.05), (0.75, 0.00, -0.60), 0.055, 0.082),
        ((-0.98, 0.12, 0.05), (-0.75, 0.00, -0.60), 0.055, 0.082),
        ((0.82, 0.00, -0.55), (0.35, -0.10, -0.90), 0.060, 0.075),
        ((-0.82, 0.00, -0.55), (-0.35, -0.10, -0.90), 0.060, 0.075),
        ((0.00, -0.85, 0.50), (0.00, -0.90, 0.10), 0.080, 0.090),
        ((0.55, -0.80, 0.00), (0.50, -0.70, -0.50), 0.080, 0.085),
        ((-0.55, -0.80, 0.00), (-0.50, -0.70, -0.50), 0.080, 0.085),
        ((0.00, -0.70, -0.65), (0.00, -0.50, -0.85), 0.065, 0.085),
        ((0.08, -0.05, 1.00), (0.35, -0.75, 0.55), 0.075, 0.050),
    ]
    for i, (d, tdir, ln, r) in enumerate(tufts):
        q, n = hair_point(d)
        tdir = np.asarray(tdir, dtype=float)
        tdir = tdir / np.linalg.norm(tdir)
        out.append(teardrop(f"pilot_tuft{i}", m_hair, q - n * 0.055, q + tdir * ln, (r, r * 0.72), hint=n, nu=9, n=6, a=1.7, b=0.62))
    bangs = [((0.030, 0.150), (-0.010, 0.058), 0.052), ((0.112, 0.128), (0.146, 0.040), 0.050), ((-0.100, 0.132), (-0.142, 0.040), 0.050)]
    for i, (a, b, w) in enumerate(bangs):
        ra, na = face_point(a[0], a[1], 0.012)
        tb, nb = face_point(b[0], b[1], 0.009)
        out.append(teardrop(f"pilot_bang{i}", m_hair, ra, tb, (w, 0.020), hint=(1.0, 0.0, 0.0), nu=10, n=7, a=1.8, b=0.6, bend=(na + nb) * 0.004))

    # ---- ゴーグル（頭の 上に 上げて ある）と バンド
    front = np.array([0.0, 0.66, 0.62])
    front = front / np.linalg.norm(front)
    for sx in (-1.0, 1.0):
        q, n = hair_point((sx * 0.42, 0.66, 0.62))
        rr, tr = 0.064, 0.019
        prof = [(rr + tr * math.cos(math.radians(a)), 0.010 + tr * math.sin(math.radians(a))) for a in np.linspace(-90.0, 270.0, 8, endpoint=False)]
        ob = lathe(f"pilot_goggle{int(sx)}", m_yellow, prof, q, n, nu=16)
        # 輪は 輪切りの 列を とじて 作る（さいごの 輪を さいしょへ つなぐ）
        out.append(_torus_from_lathe(ob))
        out.append(lathe(f"pilot_lens{int(sx)}", m_lens, [(rr - 0.004, 0.010), (rr * 0.72, 0.018), (rr * 0.38, 0.023), (0.0, 0.025)], q, n, nu=16, inside=q - n * 0.1))
    q, n = hair_point(front)
    out.append(blob("pilot_bridge", m_yellow, q + n * 0.010, (0.030, 0.016, 0.014), nu=8, nv=4, m=frame(n, hint=(1.0, 0.0, 0.0))))
    psi = np.linspace(0.0, 2.0 * np.pi, 24, endpoint=False)
    dirs = np.cos(psi)[:, None] * np.array([1.0, 0.0, 0.0]) + np.sin(psi)[:, None] * front
    pts, norms = hair_point(dirs, 0.003)
    out.append(tube("pilot_band", m_band, pts, (0.008, 0.018), nu=6, loop=True, normals=norms))

    # ---- からだ：上着（前の 合わせから 中の 服が 見える）、うで、そで口、手
    body = lathe("pilot_body", m_coat, [(0.150, 0.0), (0.154, 0.12), (0.148, 0.215), (0.130, 0.275), (0.100, 0.315), (0.060, 0.345), (0.0, 0.355)],
                 (0.0, 0.105, -0.32), (0.0, 0.0, 1.0), nu=20, ell=(1.0, 0.80), hint=(1.0, 0.0, 0.0))
    inner = ratio("#EDCFA4", COL["coat"])

    def coat_tint(p):
        ang = np.degrees(np.arctan2(p[:, 0], p[:, 1] - 0.105))
        w = np.clip(1.0 - np.abs(ang) / 22.0, 0.0, 1.0)
        w = np.where(w > 0.0, 1.0, 0.0) * 1.0
        return 1.0 + (inner - 1.0) * w[:, None]

    tint_by(body, coat_tint)
    out.append(body)
    for sx, deg in ((1.0, 22.0), (-1.0, 158.0)):
        hand = wheel_point(deg) + WHEEL_N * 0.012
        shoulder = np.array([sx * 0.128, 0.115, -0.050])
        elbow = np.array([sx * 0.200, 0.215, -0.130])
        fore = hand - elbow
        fore = fore / np.linalg.norm(fore)
        wrist = hand - fore * 0.052
        pts = bezier(shoulder, elbow, wrist, 8)
        out.append(tube(f"pilot_arm{int(sx)}", m_coat, pts, (0.046, 0.046), nu=10, up=(0.0, 0.0, 1.0), scale=np.linspace(1.08, 0.95, 8)))
        cuff = [(0.040, -0.004)] + arc(0.012, 0.010, -90.0, 0.0, 2, cx=0.044)[1:] + arc(0.012, 0.032, 0.0, 90.0, 2, cx=0.044) + [(0.036, 0.046)]
        out.append(lathe(f"pilot_cuff{int(sx)}", m_yellow, cuff, wrist - fore * 0.020, fore, nu=10))
        out.append(blob(f"pilot_hand{int(sx)}", m_skin, hand, (0.044, 0.046, 0.040), nu=12, nv=6))
    return out


def _torus_from_lathe(ob):
    """lathe で 作った「輪切りの 列」の はしを つないで、輪（トーラス）に とじる。"""
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bm.verts.ensure_lookup_table()
    edges = [e for e in bm.edges if e.is_boundary]
    bmesh.ops.bridge_loops(bm, edges=edges)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for f in bm.faces:
        f.smooth = True
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.update()
    return ob


# ------------------------------------------------------------------ うすい 影を 頂点カラーに 焼く
def _hemisphere(n):
    """上半球の 向き（コサインで 重みづけ）。"""
    out = []
    g = math.pi * (3.0 - math.sqrt(5.0))
    for i in range(n):
        r = math.sqrt((i + 0.5) / n)
        a = g * i
        out.append((r * math.cos(a), r * math.sin(a), math.sqrt(max(0.0, 1.0 - r * r))))
    return np.array(out)


def bake_soft_shadow(targets, occluders, dist=0.30, floor=0.45, dark=(0.56, 0.47, 0.44), ground=0.0, rays=40, soften=2):
    """形が まじわる 所・かげに なる 所を 暗くする（頂点カラー Col に かける）。

    頂点ごとに 上半球へ レイを 飛ばして、近くの 形に さえぎられる 割合を 数える。
    floor：これより 暗くは しない（ほかの 形の 中に うまった 点と、すぐ 外の 点を 同じ 暗さに そろえる）。
    dark：いちばん 暗い 所で かける 色（リニア。少し 赤みを 残して、黄や クリームが にごらない ように）。
    ground：下を 向いた 面を 少し 暗くする 量。
    soften：となりの 頂点と ならす 回数（頂点の あらさより 細かい 影は ギザギザに 見えるので、広げて ぼかす）。
    """
    verts = []
    polys = []
    for ob in occluders:
        base = len(verts)
        mw = ob.matrix_world
        verts += [mw @ v.co for v in ob.data.vertices]
        polys += [[base + i for i in p.vertices] for p in ob.data.polygons]
    bvh = BVHTree.FromPolygons(verts, polys, all_triangles=False, epsilon=0.0)
    hemi = _hemisphere(rays)
    dark = np.array(dark)
    for ob in targets:
        me = ob.data
        mw = ob.matrix_world
        nv = len(me.vertices)
        a = np.ones(nv)
        down = np.zeros(nv)
        for i, v in enumerate(me.vertices):
            n = np.array(v.normal)
            m = frame(n, hint=(0.3, 0.5, 0.8))
            o = mw @ v.co + Vector(n) * 0.004
            occ = 0.0
            for d in hemi @ m.T:
                hit = bvh.ray_cast(o, Vector(d), dist)
                if hit[0] is not None:
                    occ += 1.0 - hit[3] / dist
            a[i] = (max(1.0 - occ / rays, floor) - floor) / (1.0 - floor)
            down[i] = (0.5 - 0.5 * n[2]) ** 1.5
        if soften > 0 and len(me.edges) > 0:
            e = np.array([ed.vertices[:] for ed in me.edges])
            deg = np.bincount(e.reshape(-1), minlength=nv).astype(float)
            for _ in range(soften):
                acc = np.zeros(nv)
                np.add.at(acc, e[:, 0], a[e[:, 1]])
                np.add.at(acc, e[:, 1], a[e[:, 0]])
                a = 0.5 * a + 0.5 * acc / np.maximum(deg, 1.0)
        shade = (dark[None, :] + (1.0 - dark[None, :]) * a[:, None]) * (1.0 - ground * down)[:, None]
        ca = me.color_attributes["Col"]
        col = np.zeros(nv * 4, dtype=np.float32)
        ca.data.foreach_get("color", col)
        col = col.reshape(-1, 4)
        col[:, :3] *= shade
        ca.data.foreach_set("color", col.reshape(-1))
        me.update()


def tri_count(objs):
    return sum(len(p.vertices) - 2 for o in objs for p in o.data.polygons)


# ------------------------------------------------------------------ 組み立て
def build_pod():
    m_hull = mat("PodHull", COL["hull"], 0.9)
    m_yellow = mat("PodYellow", COL["yellow"], 0.85)
    m_grey = mat("PodGrey", COL["grey"], 0.85)
    m_port = mat("PodPort", COL["port"], 0.6)
    m_dark = mat("PodDark", COL["dark"], 0.8)
    m_glass = mat("PodGlass", COL["glass"], 0.15, alpha=0.26)
    m_glass.use_backface_culling = False   # 両面：ドームの むこうがわの 面も 描くと、あわの ように 青く 見える
    m_skin = mat("PilotSkin", COL["skin"], 0.9)
    m_hair = mat("PilotHair", COL["hair"], 0.95)
    m_coat = mat("PilotCoat", COL["coat"], 0.95)
    m_lens = mat("PilotLens", COL["lens"], 0.35)
    m_band = mat("PilotBand", COL["band"], 0.9)
    m_eye = mat("PilotEye", COL["eye"], 0.35)
    m_white = mat("PilotWhite", COL["white"], 0.5)
    m_mouth = mat("PilotMouth", COL["mouth"], 0.8)

    hull, glass = build_hull(m_hull, m_glass)
    ship = [hull] + build_fins(m_yellow) + build_legs(m_grey, m_yellow) + [build_collar(m_grey)] + build_ports(m_port, m_hull)
    cockpit = build_cockpit(m_yellow, m_grey, m_dark)
    pilot = build_pilot(m_skin, m_hair, m_coat, m_yellow, m_lens, m_band, m_eye, m_white, m_mouth)
    prop = build_propeller(m_yellow, m_grey)

    # 影：船体・ひれ・脚は おたがいに。中の ものは 近くの 形だけ（顔が 暗く ならない ように）。
    # 回る 羽根は 船体に 影を 落とさない。目の 白い 点は 暗く しない
    bake_soft_shadow(ship, ship + cockpit, dark=(0.62, 0.53, 0.50), ground=0.05)
    small = ("eye", "glint", "brow", "nose", "mouth")
    lit = [o for o in pilot if not any(k in o.name for k in small)]
    bake_soft_shadow(cockpit + lit, ship + cockpit + lit, dist=0.14, floor=0.5, dark=(0.74, 0.66, 0.63), soften=4)
    bake_soft_shadow(prop, prop + ship, dist=0.16, dark=(0.68, 0.59, 0.56), soften=4)

    # Godot の glTF 読みこみは、メッシュの 1 つ目の マテリアルにだけ 頂点カラーを 使わない（4.7 で 確認）。
    # 影が ほぼ 乗らない 丸まどの 円ばんを 1 つ目に して、船体の 影と 中の 色が 消えない ように する
    first = [o for o in ship if o.name.startswith("pod_port") and "rim" not in o.name]
    body = first + [o for o in ship + cockpit + pilot if o not in first]
    print(f"  triangles: ship {tri_count(ship)}, cockpit {tri_count(cockpit)}, pilot {tri_count(pilot)}, "
          f"propeller {tri_count(prop)}, window {tri_count([glass])}  total {tri_count(body + prop + [glass])}")
    main = C.join(body, "pod")
    propeller = C.join(prop, "Propeller")
    # 回転軸：Blender の Y 軸（Godot では Z 軸）。原点を ハブの 位置に。
    C.set_active(propeller)
    bpy.context.scene.cursor.location = (0.0, PROP_Y, PROP_Z)
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    for child in (glass, propeller):
        child.parent = main
        child.matrix_parent_inverse = main.matrix_world.inverted()
    return main

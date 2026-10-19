"""ステージ（臓器の中の地形）を Blender で作って GLB に書き出す。

実行: python -m blender.stages [stage_mouth ...]   /   blender -b -P blender/stages.py
出力: godot/assets/models/stages/<name>.glb

Godot 側（src/level/level.gd）は、GLB の中の Empty の名前を見てスポーンする。
  MK_player / MK_goal / MK_checkpoint_N / MK_path_NNN / MK_enemy_<kind>_N / MK_friend_<kind>_N
  MK_pickup_<kind>_N / MK_deliver_<kind>_N / MK_hazard_acid_rR_N / MK_gate_N / MK_neuron_N
  MK_sign_<key> / MK_card_<key> / MK_boss_<kind>
メッシュは自動で当たり判定（trimesh）がつく。名前が NC_ で始まるメッシュは当たり判定なし（かざり）。

座標：Blender の +Y が「前」。くだ（tube）は +Y 方向に進む。
"""
from __future__ import annotations

import math
import random

import bpy
import bmesh
from mathutils import Vector

try:
    from . import common as C
    from . import characters as CH
except ImportError:
    import os
    import sys
    sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    from blender import common as C
    from blender import characters as CH


# ------------------------------------------------------------------ 道（スプライン）
def catmull_rom(points, samples_per_seg=10):
    """制御点を通るなめらかな曲線を、こまかい点の列にする。"""
    pts = [Vector(p) for p in points]
    if len(pts) < 2:
        return pts
    ext = [pts[0]] + pts + [pts[-1]]
    out = []
    for i in range(1, len(ext) - 2):
        p0, p1, p2, p3 = ext[i - 1], ext[i], ext[i + 1], ext[i + 2]
        for s in range(samples_per_seg):
            t = s / samples_per_seg
            t2, t3 = t * t, t * t * t
            v = 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
            out.append(v)
    out.append(pts[-1])
    return out


def path_length(pts):
    return sum((pts[i] - pts[i - 1]).length for i in range(1, len(pts)))


def along(pts, frac):
    """道の frac（0〜1）の位置と向き"""
    total = path_length(pts)
    target = total * max(0.0, min(1.0, frac))
    acc = 0.0
    for i in range(1, len(pts)):
        seg = (pts[i] - pts[i - 1]).length
        if acc + seg >= target or i == len(pts) - 1:
            t = 0.0 if seg == 0 else (target - acc) / seg
            pos = pts[i - 1].lerp(pts[i], max(0.0, min(1.0, t)))
            d = (pts[i] - pts[i - 1]).normalized()
            return pos, d
        acc += seg
    return pts[-1], (pts[-1] - pts[-2]).normalized()


def side_of(d, amount):
    """進行方向 d に対して 右(+)/左(-) に amount ずらすベクトル"""
    right = Vector((d.y, -d.x, 0.0))
    if right.length < 1e-6:
        right = Vector((1, 0, 0))
    return right.normalized() * amount


def tube(name, pts, radius, mat, noise_strength=0.4, noise_scale=3.0, ribs=0.0, rib_every=3, caps=True, resolution=6, flip=True):
    """点の列に沿った くだ。内側から見るので法線は内向きにする。ribs>0 で ふし（しょくどう）"""
    cu = bpy.data.curves.new(name + "_curve", "CURVE")
    cu.dimensions = "3D"
    sp = cu.splines.new("POLY")
    sp.points.add(len(pts) - 1)
    for i, p in enumerate(pts):
        sp.points[i].co = (p.x, p.y, p.z, 1.0)
        if ribs > 0:
            sp.points[i].radius = 1.0 + ribs * (0.5 + 0.5 * math.sin(i * math.pi * 2 / rib_every))
    cu.bevel_depth = radius
    cu.bevel_resolution = resolution
    cu.use_fill_caps = caps
    ob = bpy.data.objects.new(name, cu)
    C.link(ob)
    C.set_active(ob)
    bpy.ops.object.convert(target="MESH")
    ob = bpy.context.active_object
    ob.name = name
    ob.data.materials.append(mat)
    if noise_strength > 0:
        C.displace_noise(ob, noise_strength, noise_scale, hash(name) % 100)
        C.apply_modifiers(ob)
    bpy.ops.object.shade_smooth()
    if flip:
        orient_inward(ob, pts)
    return ob


def solid_tube(name, pts, radius, mat, resolution=6, ribs=0.0, rib_every=3):
    """ブーリアン用の 外向きのくだ（ふたつき）"""
    return tube(name, pts, radius, mat, 0.0, 1.0, ribs, rib_every, True, resolution, flip=False)


def orient_inward(obj, _ref_points=None):
    """面の法線を内向きにそろえる。
    Godot の当たり判定（trimesh）は表面の片側しか当たらないので、内側から遊ぶ部屋・くだは
    必ず内向きでないといけない。閉じたメッシュなら Blender の「一貫した法線（外向き）」が
    確実なので、それを作ってから全部反転する。（中心線からの距離で面ごとに決める方法は、
    くだと部屋の合流部で床が裏返ることがあった）"""
    C.recalc_normals(obj, inside=False)
    C.flip_normals(obj)
    obj.data.update()


def bowl_z(x, y, scale, up=1.0):
    """だ円の部屋（中心 0,0,0）の床の高さ。scale=(a,b,c)。up だけ浮かせた値を返す。"""
    a, b, c = scale
    v = 1.0 - (x / a) ** 2 - (y / b) ** 2
    return -c * math.sqrt(max(v, 0.0)) + up


def ellipsoid_room(name, center, scale, mat, segments=40, rings=24, noise_strength=0.0, noise_scale=6.0, flip=True):
    o = C.add_sphere(name, 1.0, center, segments, rings, mat, scale=scale)
    C.set_active(o)
    bpy.ops.object.transform_apply(scale=True)
    if noise_strength > 0:
        C.displace_noise(o, noise_strength, noise_scale, hash(name) % 100)
        C.apply_modifiers(o)
    if flip:
        orient_inward(o, [Vector(center)])
    return o


def boolean_union(objs, name):
    """複数の閉じたメッシュを 1 つにする（内側からみる部屋用）。"""
    base = objs[0]
    for o in objs[1:]:
        m = base.modifiers.new("Union", "BOOLEAN")
        m.operation = "UNION"
        m.object = o
        try:
            m.solver = "EXACT"
        except Exception:
            pass
        C.set_active(base)
        bpy.ops.object.modifier_apply(modifier=m.name)
        bpy.data.objects.remove(o)
    base.name = name
    return base


def floor_bvh(obj):
    """ゆか（くだ）のメッシュから、上から下へレイを飛ばすための BVH を作る"""
    from mathutils.bvhtree import BVHTree
    depsgraph = bpy.context.evaluated_depsgraph_get()
    return BVHTree.FromObject(obj, depsgraph)


def scatter_on_floor(name, make_fn, count, pts, radius, seed, frac_range=(0.05, 0.95), spread=0.6, z_off=0.0, floor_obj=None):
    """道の床に 小物を ばらまく（make_fn() は 1 個分のオブジェクトを返す）。
    floor_obj を渡すと、でこぼこ（ノイズ）を含めた 本当のゆかの高さに置く。"""
    random.seed(seed)
    bvh = floor_bvh(floor_obj) if floor_obj is not None else None
    objs = []
    for i in range(count):
        f = random.uniform(*frac_range)
        pos, d = along(pts, f)
        s = random.uniform(-spread, spread) * radius
        p = pos + side_of(d, s)
        p.z = pos.z - math.sqrt(max(radius * radius - s * s, 0.0)) + z_off
        if bvh is not None:
            hit, _n, _i, _d = bvh.ray_cast(Vector((p.x, p.y, pos.z)), Vector((0, 0, -1)), radius * 2.5)
            if hit is not None:
                p.z = hit.z + z_off
        o = make_fn(i)
        o.location = p
        o.rotation_euler = (0, 0, random.uniform(0, math.pi * 2))
        objs.append(o)
    if not objs:
        return None
    joined = C.join(objs, name)
    return joined


def floor_point(pts, frac, radius, side=0.0, up=0.5):
    pos, d = along(pts, frac)
    p = pos + side_of(d, side * radius)
    p.z = pos.z - math.sqrt(max(radius * radius - (side * radius) ** 2, 0.0)) + up
    return p


def path_markers(pts, every_m=8.0):
    total = path_length(pts)
    n = max(2, int(total / every_m))
    for i in range(n + 1):
        pos, _ = along(pts, i / n)
        C.add_empty(f"MK_path_{i:03d}", pos)


def mk(name, pos, rot=(0, 0, 0)):
    return C.add_empty(name, pos, rot)


# ------------------------------------------------------------------ 1. くち
def build_mouth():
    pink = C.material("TonguePink", (0.93, 0.42, 0.52), 0.6)
    bud = C.material("TasteBud", (0.99, 0.62, 0.70), 0.6)
    gum = C.material("GumPink", (0.90, 0.36, 0.46), 0.75)
    palate = C.material("Palate", (0.97, 0.66, 0.70), 0.85)
    throat_m = C.material("Throat", (0.84, 0.32, 0.42), 0.8)
    tooth = C.material("ToothWhite", (1.0, 0.98, 0.93), 0.3)
    lip = C.material("Lip", (0.88, 0.30, 0.40), 0.7)
    outside = C.material("Outside", (0.82, 0.93, 1.0), 0.9, emission=(0.82, 0.93, 1.0), emission_strength=0.7)

    # 部屋（くちの なか）と した の形。マーカーの高さは この式から出す
    SC = (24.0, 33.0, 10.0)
    CZ = 2.5
    TC = (0.0, -3.0, -6.3)
    TS = (17.0, 24.0, 3.4)

    def cav_z(x, y, sign=-1):
        """部屋の床（sign=-1）/ 天井（sign=+1）の高さ"""
        v = 1.0 - (x / SC[0]) ** 2 - (y / SC[1]) ** 2
        return CZ + sign * SC[2] * math.sqrt(max(v, 0.0))

    def tongue_z(x, y):
        v = 1.0 - ((x - TC[0]) / TS[0]) ** 2 - ((y - TC[1]) / TS[1]) ** 2
        return TC[2] + TS[2] * math.sqrt(v) if v > 0 else -99.0

    def fz(x, y, up=1.2):
        """した か 部屋の床の、高い方"""
        return max(cav_z(x, y), tongue_z(x, y)) + up

    objs = []
    cavity = ellipsoid_room("cavity", (0, 0, CZ), SC, palate, 56, 32, 0.0, flip=False)
    # のど：おくの かべに あいた あな から ゆるく くだる（ゆかは 部屋の ゆかに つなげる）
    throat_ctrl = [(0, 18, 1.2), (0, 30, 0.3), (2, 44, -5), (-2, 60, -12), (2, 76, -19), (-1.5, 92, -26), (1, 108, -33), (0, 124, -40), (0, 140, -46), (0, 156, -52), (0, 166, -56)]
    throat_pts = catmull_rom([Vector(p) for p in throat_ctrl], 6)
    TR = 6.0
    throat = solid_tube("throat", throat_pts, TR, throat_m, ribs=0.10, rib_every=9)
    # のどの いりぐち：ひろい アーチ（まっすぐ すすんでも かべに ぶつからない）
    FR = 8.5
    fun_ctrl = [Vector((0, 13, 3.0)), Vector((0, 22, 2.6)), Vector((0, 32, 2.2))]
    funnel = solid_tube("throat_mouth", fun_ctrl, FR, throat_m)

    def fun_z(y, sign=-1):
        """いりぐちの アーチの ゆか（sign=-1）/ 天井（sign=+1）の高さ（x=0）"""
        t = max(0.0, min(1.0, (y - 13.0) / 19.0))
        return 3.0 + (2.2 - 3.0) * t + sign * FR

    cavity = boolean_union([cavity, throat, funnel], "MouthCavity")
    C.displace_noise(cavity, 0.25, 5.0, 12)
    C.apply_modifiers(cavity)
    bpy.ops.object.shade_smooth()
    orient_inward(cavity, [Vector((0, 0, CZ))] + throat_pts)
    # ブーリアンで のどの色が 消えるので、のどの まんなかの線に 近い面だけ あとから 色をつける
    cavity.data.materials.append(throat_m)
    for poly in cavity.data.polygons:
        c = poly.center
        if c.y > 20.0 and min((c - tp).length for tp in throat_pts[::3]) < TR + 3.2:
            poly.material_index = 1
    cavity.data.update()
    objs.append(cavity)

    # した：こい ピンクの ゆか
    tongue = C.add_sphere("Tongue", 1.0, TC, 48, 28, pink, scale=TS)
    C.set_active(tongue)
    bpy.ops.object.transform_apply(scale=True)
    C.displace_noise(tongue, 0.12, 2.0, 11)
    C.apply_modifiers(tongue)
    objs.append(tongue)
    tongue_bvh = floor_bvh(tongue)

    def tongue_top(x, y):
        """でこぼこを ふくめた 本当の したの おもての高さ"""
        hit, _n, _i, _d = tongue_bvh.ray_cast(Vector((x, y, 20.0)), Vector((0, 0, -1)), 60.0)
        return hit.z if hit is not None else tongue_z(x, y)

    # みらい（あじを かんじる ぶつぶつ）：かざり。おもてに 少し うめこむので うかない
    random.seed(17)
    buds = []
    while len(buds) < 150:
        u, v = random.uniform(-1, 1), random.uniform(-1, 1)
        if u * u + v * v > 0.80:
            continue
        x, y = TC[0] + u * TS[0], TC[1] + v * TS[1]
        if abs(x) < 1.0:
            continue
        r = random.uniform(0.25, 0.45)
        buds.append(C.add_sphere(f"bud{len(buds)}", r, (x, y, tongue_top(x, y) - r * 0.3), 8, 6, bud, scale=(1, 1, 0.65)))
    # おくの V の列（ゆうかくにゅうとう）：おおきめの ぶつぶつ
    for k in range(7):
        t = (k - 3) / 3.0
        x, y = t * 10.0, 13.0 - abs(t) * 8.0
        r = 0.85
        buds.append(C.add_sphere(f"vbud{k}", r, (x, y, tongue_top(x, y) - r * 0.35), 10, 8, bud, scale=(1, 1, 0.6)))
    objs.append(C.join(buds, "NC_TasteBuds"))
    # まんなかの すじ
    line_pts = [Vector((0, y, tongue_top(0, y) + 0.05)) for y in range(-24, 16, 2)]
    objs.append(tube("NC_TongueLine", line_pts, 0.30, gum, 0.0, 1.0, flip=False))

    # は：した 14 本・うえ 14 本。まえば（まんなか 6 本）は ほそくて たかい、おくば は ひろい。
    # ゆか／天井に 1.2 m うめこむので うかない。はぐき（かざり）が ねもとを つつむ
    RX, RY = SC[0] - 4.0, SC[1] - 6.0
    a0, a1 = math.radians(145), math.radians(395)
    n_teeth = 14
    teeth = []
    for row, sgn in (("lower", -1), ("upper", 1)):
        for i in range(n_teeth):
            a = a0 + (a1 - a0) * (i + 0.5) / n_teeth
            x, y = math.cos(a) * RX, math.sin(a) * RY
            front = 4 <= i <= 9
            w, d, h = (2.0, 1.6, 3.8) if front else (2.9, 2.3, 3.2)
            zc = cav_z(x, y, sgn) - sgn * (h * 0.5 - 1.2)
            teeth.append(C.add_box(f"tooth_{row}_{i}", (w, d, h), (x, y, zc), (0, 0, a + math.pi / 2), tooth, bevel=0.4))
        gpts = []
        for k in range(45):
            a = a0 - 0.05 + (a1 - a0 + 0.1) * k / 44
            x, y = math.cos(a) * (RX + 0.7), math.sin(a) * (RY + 0.7)
            gpts.append(Vector((x, y, cav_z(x, y, sgn) + sgn * 0.4)))
        objs.append(tube(f"NC_Gum_{row}", gpts, 1.3, gum, 0.0, 1.0, flip=False))
    teeth_o = C.join(teeth, "Teeth")
    C.apply_modifiers(teeth_o)
    C.shade_smooth(teeth_o, 60)
    objs.append(teeth_o)

    # くちびる：まえの かべの ふちの わ。その むこうに あかるい「おそと」
    lips = C.add_torus("Lips", 1.0, 0.36, (0, -30.8, CZ - 0.4), (math.radians(90), 0, 0), lip, 36, 12)
    lips.scale = (8.6, 3.9, 0.55)
    objs.append(lips)
    objs.append(C.add_cylinder("NC_Outside", 1.0, 0.3, (0, -32.3, CZ - 0.4), (math.radians(90), 0, 0), 28, outside, scale=(6.0, 2.9, 1.0)))
    # のどちんこ：天井から ぶらさがる（うえを うめこむ）。へんとう：のどの いりぐちの りょうわき
    uz = fun_z(24, 1)
    objs.append(C.add_sphere("NC_Uvula", 1.0, (0, 24, uz - 1.2), 12, 10, bud, scale=(0.9, 0.9, 2.0)))
    for sx in (-1, 1):
        objs.append(C.add_sphere(f"NC_Tonsil_{'l' if sx < 0 else 'r'}", 2.4, (sx * 9.2, 28.0, 0.3), 14, 10, bud, scale=(1, 1, 1.2)))
    # のどの かべの ぶつぶつ（リンパの こぶ）：かざり。かべに うめこむ
    cav_bvh = floor_bvh(cavity)
    random.seed(23)
    bumps = []
    for i in range(40):
        pos, d = along(throat_pts, random.uniform(0.12, 0.96))
        phi = random.choice((-1, 1)) * random.uniform(math.radians(35), math.radians(150))
        right = side_of(d, 1.0)
        dirn = Vector((0, 0, -1)) * math.cos(phi) + right * math.sin(phi)
        hit, _n, _i, _d = cav_bvh.ray_cast(pos, dirn, TR * 1.8)
        if hit is None:
            continue
        r = random.uniform(0.5, 0.9)
        bumps.append(C.add_sphere(f"tb{i}", r, hit - dirn * r * 0.35, 8, 6, bud))
    objs.append(C.join(bumps, "NC_ThroatBumps"))

    # マーカー（高さは ゆかの式から）
    mk("MK_player", (0, -22, fz(0, -22, 1.5)))
    goal = floor_point(throat_pts, 0.94, TR, 0.0, 0.8)
    mk("MK_goal", goal)
    mk("MK_checkpoint_1", floor_point(throat_pts, 0.12, TR, 0.0, 0.5))
    # むしばきん：はの そばの みぞに 4 ひき（よこ 2・おく 2）。スタートから 13 m より とおく
    for i, (x, y) in enumerate([(-15, -9), (-14.5, 13), (14.5, 13), (15, -9)]):
        mk(f"MK_enemy_mushiba_{i + 1}", (x, y, fz(x, y, 1.0)))
    mk("MK_pickup_heart_item_1", (9, -4, fz(9, -4, 1.0)))
    mk("MK_card_tooth", (-9.5, -19, fz(-9.5, -19, 1.0)))
    mk("MK_sign_throat", (0, 24, fun_z(24)))
    mk("MK_path_000", (0, -22, fz(0, -22)))
    mk("MK_path_001", (0, 0, fz(0, 0)))
    mk("MK_path_002", (0, 22, fun_z(22) + 1.0))
    mk("MK_path_003", floor_point(throat_pts, 0.15, TR, 0.0, 1.0))
    mk("MK_path_004", goal)
    return objs


# ------------------------------------------------------------------ 2. しょくどう
def build_esophagus():
    wall = C.material("EsophagusWall", (0.93, 0.46, 0.5), 0.85)
    band = C.material("EsophagusBand", (0.76, 0.27, 0.37), 0.8)
    fold = C.material("EsophagusFold", (0.96, 0.51, 0.56), 0.8)
    wall2 = C.material("TracheaWall", (0.97, 0.82, 0.76), 0.85)
    cart = C.material("TracheaRing", (1.0, 0.95, 0.9), 0.6)
    flap = C.material("Epiglottis", (0.86, 0.42, 0.52), 0.8)
    mucus = C.material("Mucus", (1.0, 0.88, 0.92), 0.2)
    # ながい くねくねの すべりだい（やく 450 m・ゆるやかに くだる）
    ctrl = [(0, 0, 0), (0, 28, -5), (9, 60, -14), (-11, 98, -26), (8, 140, -40), (-13, 182, -55),
            (11, 225, -72), (-9, 268, -88), (6, 308, -103), (-5, 345, -116), (0, 375, -125), (0, 398, -130)]
    pts = catmull_rom(ctrl, 18)
    R = 5.2
    RIBS, RIB_EVERY = 0.15, 6   # ふし（きんにくの しめつけ）：ふとい・ほそいを くりかえす

    def rib_factor(i):
        return 1.0 + RIBS * (0.5 + 0.5 * math.sin(i * math.pi * 2 / RIB_EVERY))

    total = path_length(pts)
    acc = [0.0]
    for i in range(1, len(pts)):
        acc.append(acc[-1] + (pts[i] - pts[i - 1]).length)

    def local_radius(frac):
        """ふしで 太さが かわるので、その場所の 本当の 半径"""
        target = total * max(0.0, min(1.0, frac))
        for i in range(1, len(pts)):
            seg = acc[i] - acc[i - 1]
            if acc[i] >= target or i == len(pts) - 1:
                t = 0.0 if seg == 0 else max(0.0, min(1.0, (target - acc[i - 1]) / seg))
                return R * (rib_factor(i - 1) * (1 - t) + rib_factor(i) * t)
        return R

    def fp(frac, side=0.0, up=0.5):
        return floor_point(pts, frac, local_radius(frac), side, up)

    main = solid_tube("esophagus", pts, R, wall, resolution=7, ribs=RIBS, rib_every=RIB_EVERY)
    main.data.materials.append(wall2)
    # きかん（くうきの みち）：始まりのすぐ先で 右に分かれる 行き止まり。ゆかは すこし ひくめに
    BR = 0.065
    pos, d = along(pts, BR)
    tr_pts = catmull_rom([pos + side_of(d, 1.5) + Vector((0, 0, -1.6)), pos + side_of(d, 9.0) + Vector((0, 3, -0.2)),
                          pos + side_of(d, 16.0) + Vector((0, 6, 2.0))], 6)
    TR = 3.6
    tr = solid_tube("trachea", tr_pts, TR, wall)
    tr.data.materials.append(wall2)
    for poly in tr.data.polygons:   # ブーリアン（INDEX）で 2 番目の色が きかんに のこる
        poly.material_index = 1
    main = boolean_union([main, tr], "Esophagus")
    C.displace_noise(main, 0.15, 2.5, 22)
    C.apply_modifiers(main)
    bpy.ops.object.shade_smooth()
    orient_inward(main, pts + tr_pts)
    objs = [main]
    bvh = floor_bvh(main)

    def on_floor(frac, side=0.0, up=0.0):
        """でこぼこを ふくめた 本当の ゆかの 高さに おく"""
        p0, d0 = along(pts, frac)
        p = p0 + side_of(d0, side * local_radius(frac))
        hit, _n, _i, _d = bvh.ray_cast(Vector((p.x, p.y, p0.z)), Vector((0, 0, -1)), R * 2.5)
        z = hit.z if hit is not None else fp(frac, side, 0.0).z
        return Vector((p.x, p.y, z + up))

    # 気管の入口をふさぐ「ふた」（こうとうがい）：かべから 5 m ほど おくで、すこし かたむいた ふた
    fi = 7
    fpos = tr_pts[fi]
    fd = (tr_pts[fi + 1] - tr_pts[fi - 1]).normalized()
    rot = fd.to_track_quat("Z", "Y").to_euler()
    rot.x += math.radians(12)
    objs.append(C.add_cylinder("Epiglottis", 3.9, 0.45, fpos, rot, 24, flap))
    # きかんの なんこつの わ（かざり）：しろっぽい わっかで「ちがう くだ」と わかる
    rings = []
    for i in (4, 6):   # かべ（side≒5.2）より おく、ふたより てまえ
        rd = (tr_pts[i + 1] - tr_pts[i - 1]).normalized()
        rings.append(C.add_torus(f"cart{i}", TR - 0.15, 0.32, tr_pts[i], rd.to_track_quat("Z", "Y").to_euler(), cart, 20, 6))
    # きんにくの わ（かざり）：ほそい ところに こい ピンクの おび。ゆかは ほぼ たいら
    for i in range(6, len(pts) - 2, RIB_EVERY):
        frac = acc[i] / total
        if abs(frac - BR) < 0.03 or frac > 0.965:
            continue   # わかれみち と ゴールの まわりは あけておく
        bd = (pts[i + 1] - pts[i - 1]).normalized()
        major = R * rib_factor(i) - 0.1
        rings.append(C.add_torus(f"band{i}", major, 0.5, pts[i] + Vector((0, 0, -0.25)), bd.to_track_quat("Z", "Y").to_euler(), band, 20, 6))
    # いの いりぐち（ふんもん）：ゴールの てまえの ひとまわり ほそい わ
    gpos, gd = along(pts, 0.955)
    rings.append(C.add_torus("cardia", local_radius(0.955) - 0.6, 0.6, gpos + Vector((0, 0, -0.1)), gd.to_track_quat("Z", "Y").to_euler(), band, 24, 8))
    objs.append(C.join(rings, "NC_MuscleBands"))
    # ねんまくの たてじわ（かざり）：ゆかに そって はしる やわらかい すじ。はやさと ゆかが わかる
    folds = []
    for k, deg in enumerate((-42, -15, 15, 42)):
        fpts = []
        for i in range(1, len(pts) - 1, 3):
            t = (pts[i + 1] - pts[i - 1]).normalized()
            r = side_of(t, 1.0)
            dn = t.cross(r)
            if dn.z > 0:
                dn = -dn
            th = math.radians(deg + 7.0 * math.sin(i * 0.21 + k * 1.7))
            off = dn * math.cos(th) + r * math.sin(th)
            fpts.append(pts[i] + off * (R * rib_factor(i) - 0.08))
        folds.append(tube(f"fold{k}", fpts, 0.26, fold, 0.0, 1.0, 0.0, 3, False, 1, flip=False))
    objs.append(C.join(folds, "NC_Folds"))
    # ねばねばの つば（かざり）：つるつる すべる かんじ
    random.seed(23)
    drops = []
    for i in range(14):
        f = random.uniform(0.03, 0.96)
        s = random.uniform(-0.7, 0.7)
        r = random.uniform(0.45, 0.75)
        drops.append(C.add_sphere(f"drop{i}", r, on_floor(f, s, 0.05), 10, 6, mucus, scale=(1.0, 1.4, 0.35)))
    objs.append(C.join(drops, "NC_Mucus"))
    # たべもののかたまり（床に・あたる）：さいしょの 1 つは カードの そば、ほかは ばらばら。まんなかは あけておく
    random.seed(21)
    foods = []
    spots = [(0.14, -0.35), (0.19, 0.3)]
    while len(spots) < 12:
        f = random.uniform(0.22, 0.93)
        s = random.choice((-1, 1)) * random.uniform(0.15, 0.55)
        if all(abs(f - g) > 0.035 for g, _ in spots) and all(abs(f - c) > 0.02 for c in (0.33, 0.5, 0.66)):
            spots.append((f, s))
    for i, (f, s) in enumerate(spots):
        o = CH.build_food()
        o.location = on_floor(f, s, 0.7)
        o.rotation_euler = (0, 0, random.uniform(0, math.pi * 2))
        foods.append(o)
    objs.append(C.join(foods, "FoodChunks"))
    # マーカー（道は ふとい ところでも ゆかから 6 m いないに なるよう すこし ひくめ）
    n = max(2, int(total / 8.0))
    for i in range(n + 1):
        p, _ = along(pts, i / n)
        mk(f"MK_path_{i:03d}", p + Vector((0, 0, -0.4)))
    mk("MK_player", fp(0.01, 0.0, 1.2))
    mk("MK_goal", fp(0.985, 0.0, 0.8))
    mk("MK_checkpoint_1", fp(0.33, 0.0, 0.5))
    mk("MK_checkpoint_2", fp(0.66, 0.0, 0.5))
    mk("MK_pickup_heart_item_1", fp(0.5, 0.4, 1.0))
    mk("MK_card_epiglottis", fp(BR, 0.0, 1.0))
    mk("MK_card_food", fp(0.14, 0.0, 1.0))
    mk("MK_sign_goal", fp(0.985, 0.0, 1.0))
    return objs


# ------------------------------------------------------------------ 3. い
def build_stomach():
    wall = C.material("StomachWall", (0.98, 0.72, 0.5), 0.85)
    rugae = C.material("Rugae", (0.95, 0.6, 0.45), 0.85)
    objs = []
    SC = (30, 38, 10)
    room = ellipsoid_room("room", (0, 0, 0), SC, wall, 56, 32, 0.0, flip=False)
    entry_pts = catmull_rom([Vector((0, 34, 16)), Vector((0, 36, 8)), Vector((0, 31, -2))], 6)
    exit_pts = catmull_rom([Vector((14, -24, -7)), Vector((22, -32, -8)), Vector((30, -42, -10))], 6)
    entry = solid_tube("entry", entry_pts, 4.0, wall)
    exit_t = solid_tube("exit", exit_pts, 4.0, wall)
    room = boolean_union([room, entry, exit_t], "StomachRoom")
    C.displace_noise(room, 0.8, 7.0, 32)
    C.apply_modifiers(room)
    bpy.ops.object.shade_smooth()
    orient_inward(room, [Vector((0, 0, 0))] + entry_pts + exit_pts)
    objs.append(room)
    # ひだ（かざり）：床の上の うねうねした帯
    bands = []
    for i in range(6):
        y = -24 + i * 9.5
        b = C.add_torus(f"ruga{i}", 22.0 - abs(y) * 0.35, 0.8, (0, y, -9.4), (0, 0, 0), rugae, 40, 8)
        b.scale = (1.0, 0.18, 0.6)
        bands.append(b)
    bands_o = C.join(bands, "NC_Rugae")
    objs.append(bands_o)
    # マーカー（床の高さは だ円の式から）
    def fz(x, y, up=1.2):
        return bowl_z(x, y, SC, up)
    mk("MK_player", (0, 26, fz(0, 26, 1.5)))
    mk("MK_goal", (23, -33, -12.0))
    mk("MK_hazard_acid_r7_1", (0, 2, fz(0, 2, 0.0)))
    mk("MK_hazard_acid_r5_2", (-12, 12, fz(-12, 12, 0.0)))
    mk("MK_hazard_acid_r6_3", (11, -12, fz(11, -12, 0.0)))
    for i, (x, y) in enumerate([(-19, -2), (17, 14), (-9, -22)]):
        mk(f"MK_friend_wallcell_{i + 1}", (x, y, fz(x, y)))
    for i, (x, y) in enumerate([(-15, 6), (-18, -10), (13, 20), (20, 4), (-3, -24)]):
        mk(f"MK_enemy_pylori_{i + 1}", (x, y, fz(x, y)))
    mk("MK_pickup_heart_item_1", (10, 24, fz(10, 24)))
    mk("MK_card_acid", (0, 11, fz(0, 11)))
    mk("MK_path_000", (0, 26, fz(0, 26)))
    mk("MK_path_001", (0, 0, fz(0, 0)))
    mk("MK_path_002", (23, -33, -12.0))
    return objs


# ------------------------------------------------------------------ 4. しょうちょう
def build_intestine():
    wall = C.material("IntestineWall", (0.98, 0.7, 0.68), 0.85)
    villi = C.material("VilliGreen", (0.6, 0.88, 0.6), 0.8)
    ctrl = [(0, 0, 0), (0, 30, 0), (18, 55, -2), (-12, 85, -3), (16, 115, -5), (-14, 150, -6), (0, 180, -8), (0, 205, -9)]
    pts = catmull_rom(ctrl, 8)
    R = 5.5
    objs = [tube("Intestine", pts, R, wall, 0.5, 3.0)]
    # じゅうもう（かざり・当たり判定なし）：床に たくさん
    def villus(i):
        # ねもとが 原点（ゆかの高さ）に来るように作る
        h = random.uniform(0.7, 1.2)
        o = C.add_cone(f"v{i}", 0.22, 0.12, h, (0, 0, 0), (0, 0, 0), 6, villi)
        for v in o.data.vertices:
            v.co.z += h / 2
        tip = C.add_sphere(f"vt{i}", 0.16, (0, 0, h), 8, 6, villi)
        return C.join([o, tip], f"villus{i}")
    objs.append(scatter_on_floor("NC_Villi", villus, 260, pts, R, 31, (0.02, 0.98), 0.75, -0.1, floor_obj=objs[0]))
    # マーカー
    path_markers(pts, 8.0)
    mk("MK_player", floor_point(pts, 0.01, R, 0.0, 1.2))
    mk("MK_goal", floor_point(pts, 0.985, R, 0.0, 0.8))
    mk("MK_checkpoint_1", floor_point(pts, 0.4, R, 0.0, 0.5))
    mk("MK_checkpoint_2", floor_point(pts, 0.75, R, 0.0, 0.5))
    fracs = [0.12, 0.22, 0.33, 0.47, 0.6, 0.72]
    for i, f in enumerate(fracs):
        side = (-0.4, 0.4, 0.0, 0.35, -0.35, 0.1)[i]
        mk(f"MK_pickup_nutrient_{i % 3}_{i + 1}", floor_point(pts, f, R, side, 1.0))
    mk("MK_deliver_villus_1", floor_point(pts, 0.52, R, -0.45, 0.2))
    mk("MK_deliver_villus_2", floor_point(pts, 0.93, R, 0.45, 0.2))
    for i, f in enumerate([0.3, 0.55, 0.8]):
        mk(f"MK_enemy_akudama_{i + 1}", floor_point(pts, f, R, 0.3 * (-1) ** i, 1.0))
    for i, f in enumerate([0.18, 0.45, 0.66]):
        mk(f"MK_friend_zendama_{i + 1}", floor_point(pts, f, R, -0.3 * (-1) ** i, 1.0))
    mk("MK_pickup_heart_item_1", floor_point(pts, 0.85, R, 0.0, 1.0))
    return objs


# ------------------------------------------------------------------ 5. けっかん
def build_vessel():
    wall = C.material("VesselWall", (0.75, 0.12, 0.18), 0.8)
    ctrl = [(0, 0, 0), (0, 30, -1), (-14, 60, -3), (10, 95, -5), (-8, 130, -6), (12, 165, -8), (0, 200, -10), (0, 225, -11)]
    pts = catmull_rom(ctrl, 8)
    R = 4.6
    objs = [tube("Vessel", pts, R, wall, 0.3, 3.0)]
    objs.append(scatter_on_floor("Cholesterol", lambda i: CH.build_cholesterol(), 7, pts, R, 41, (0.2, 0.9), 0.5, 0.6, floor_obj=objs[0]))
    # 血しょうの つぶ（かざり）
    random.seed(5)
    dots = []
    plasma = C.material("Plasma", (1.0, 0.75, 0.75), 0.5, emission=(0.5, 0.2, 0.2), emission_strength=0.6)
    for i in range(40):
        pos, d = along(pts, random.uniform(0.02, 0.98))
        p = pos + side_of(d, random.uniform(-0.6, 0.6) * R) + Vector((0, 0, random.uniform(-0.5, 0.6) * R))
        dots.append(C.add_sphere(f"plasma{i}", random.uniform(0.15, 0.35), p, 8, 6, plasma))
    objs.append(C.join(dots, "NC_Plasma"))
    path_markers(pts, 8.0)
    mk("MK_player", floor_point(pts, 0.01, R, 0.0, 1.2))
    mk("MK_goal", floor_point(pts, 0.985, R, 0.0, 0.8))
    mk("MK_checkpoint_1", floor_point(pts, 0.35, R, 0.0, 0.5))
    mk("MK_checkpoint_2", floor_point(pts, 0.7, R, 0.0, 0.5))
    for i, f in enumerate([0.05, 0.14, 0.24, 0.36, 0.5, 0.62, 0.74]):
        mk(f"MK_friend_rbc_{i + 1}", floor_point(pts, f, R, 0.3 * (-1) ** i, 1.0))
    mk("MK_pickup_heart_item_1", floor_point(pts, 0.55, R, 0.0, 1.0))
    mk("MK_card_cholesterol", floor_point(pts, 0.2, R, 0.0, 1.0))
    mk("MK_sign_heart", floor_point(pts, 0.96, R, 0.0, 1.0))
    return objs


# ------------------------------------------------------------------ 6/8. しんぞう（みぎ・ひだり）
def _heart_half(room_keys, entry_key, exit_key, left=False):
    """しんぞうの かたがわ：入口のくだ → しんぼう → べん → しんしつ → べん → 出口のくだ。
    ちは しんぞうを 2かい とおる（みぎ：からだ→はい、ひだり：はい→からだじゅう）。"""
    wall = C.material("HeartWallL" if left else "HeartWall", (0.8, 0.18, 0.26) if left else (0.85, 0.22, 0.3), 0.8)
    objs = []
    centers = [(0, 0, 0), (0, 36, 0)]
    rooms = []
    for i, c in enumerate(centers):
        scale = (14, 14, 8) if not (left and i == 1) else (15, 15, 9)  # ひだりの しんしつは 大きく（かべが あつい）
        rooms.append(ellipsoid_room(f"room{i}", c, scale, wall, 32, 20, 0.0, flip=False))
    tunnel = solid_tube("tunnel0", [Vector((0, 10, 0)), Vector((0, 26, 0))], 4.0, wall)
    entry_pts = [Vector((0, -34, 0)), Vector((0, -10, 0))]
    entry = solid_tube("entry", entry_pts, 4.0, wall)
    exit_pts = catmull_rom([Vector((0, 46, 0)), Vector((0, 62, 1)), Vector((0, 78, 6)), Vector((0, 90, 13))], 6)
    exit_t = solid_tube("exit", exit_pts, 4.0, wall)
    body = boolean_union(rooms + [tunnel, entry, exit_t], "HeartRooms")
    C.displace_noise(body, 0.3, 4.0, 61 if not left else 62)
    C.apply_modifiers(body)
    bpy.ops.object.shade_smooth()
    orient_inward(body)
    objs.append(body)
    # マーカー
    mk("MK_player", (0, -28, -2.8))
    mk("MK_goal", (0, 82, 4.0))
    mk("MK_gate_1", (0, 18, -4.0))
    mk("MK_gate_2", (0, 54, -3.6))
    for i, key in enumerate(room_keys):
        mk(f"MK_sign_{key}", (0, centers[i][1], -6.0))
    mk(f"MK_sign_{entry_key}", (0, -22, -2.5))
    mk(f"MK_sign_{exit_key}", (0, 66, 0.0))
    mk("MK_card_valve", (0, 12, -6.0))
    mk("MK_checkpoint_1", (0, 36, -7.5))
    mk("MK_pickup_heart_item_1", (6, 36, -6.5))
    pts = [Vector((0, -28, -3)), Vector((0, -12, -3)), Vector((0, 0, -7)), Vector((0, 18, -4)), Vector((0, 36, -7)), Vector((0, 54, -4)), Vector((0, 66, -2)), Vector((0, 82, 4))]
    path_markers(pts, 6.0)
    return objs


def build_heart():
    """みぎの しんぞう：だいじょうみゃく → みぎの しんぼう → みぎの しんしつ → はいどうみゃく（はいへ）"""
    return _heart_half(["ra", "rv"], "vein", "pa", left=False)


def build_heart2():
    """ひだりの しんぞう：はいじょうみゃく → ひだりの しんぼう → ひだりの しんしつ → だいどうみゃく（からだじゅうへ）"""
    return _heart_half(["la", "lv"], "pv", "aorta", left=True)


# ------------------------------------------------------------------ 7. はい
def build_lungs():
    wall = C.material("AlveolusWall", (0.93, 0.75, 0.85), 0.85)
    cap_r = C.material("CapRed", (0.9, 0.3, 0.35), 0.6)
    cap_b = C.material("CapBlue", (0.4, 0.5, 0.95), 0.6)
    objs = []
    room = ellipsoid_room("Alveolus", (0, 0, 0), (34, 34, 15), wall, 56, 32, 1.6, 5.0)
    objs.append(room)
    # 壁をはう 毛細血管（かざり）：赤と青の くだを ぐるっと
    random.seed(71)
    for k, matc in enumerate([cap_r, cap_b]):
        for j in range(3):
            a0 = random.uniform(0, math.pi * 2)
            ring = []
            for i in range(30):
                a = a0 + i * 0.22
                z = 2 + j * 3 + math.sin(i * 0.7 + k) * 2
                rr = 33.0 * math.sqrt(max(0.0, 1 - (z / 15.0) ** 2)) - 0.6
                ring.append(Vector((math.cos(a) * rr, math.sin(a) * rr, z)))
            objs.append(tube(f"NC_Capillary{k}{j}", ring, 0.35, matc, 0.0, 1.0, caps=True, resolution=3, flip=False))
    # さんその あわ（かざり）
    bubbles = []
    bub = C.material("Oxygen", (0.6, 0.85, 1.0), 0.3, emission=(0.3, 0.5, 0.9), emission_strength=0.8, alpha=0.7)
    for i in range(30):
        a = random.uniform(0, math.pi * 2)
        r = random.uniform(5, 28)
        bubbles.append(C.add_sphere(f"bubble{i}", random.uniform(0.3, 0.8), (math.cos(a) * r, math.sin(a) * r, random.uniform(-8, 6)), 10, 6, bub))
    objs.append(C.join(bubbles, "NC_Bubbles"))
    # マーカー
    mk("MK_player", (0, -26, -10))
    mk("MK_goal", (0, 28, -10))
    mk("MK_boss_boss_virus", (0, 6, -8))
    for i, (x, y) in enumerate([(-20, -8), (20, -6), (0, -16)]):
        mk(f"MK_friend_wbc_{i + 1}", (x, y, -11))
    for i, (x, y) in enumerate([(-14, 10), (14, 12), (-8, 20), (10, 22)]):
        mk(f"MK_enemy_virus_{i + 1}", (x, y, -11))
    mk("MK_pickup_heart_item_1", (-24, 8, -9))
    mk("MK_pickup_heart_item_2", (24, 10, -9))
    mk("MK_card_virus", (-10, 2, -11))
    mk("MK_path_000", (0, -26, -10))
    mk("MK_path_001", (0, 0, -14))
    mk("MK_path_002", (0, 28, -10))
    return objs


# ------------------------------------------------------------------ 8. のう
def build_brain():
    wall = C.material("BrainWall", (0.8, 0.72, 0.95), 0.85)
    spark = C.material("Spark", (1.0, 0.95, 0.6), 0.3, emission=(1.0, 0.85, 0.3), emission_strength=1.5)
    objs = []
    room = ellipsoid_room("BrainRoom", (0, 0, 0), (34, 38, 15), wall, 60, 36, 2.2, 4.0)
    objs.append(room)
    # 神経のせん（かざり）：ニューロン同士をつなぐ ひかる線
    random.seed(81)
    neuron_pos = []
    for i in range(5):
        a = math.radians(90 + i * 72)
        neuron_pos.append(Vector((math.cos(a) * 15, math.sin(a) * 15, -13.2)))
    lines = []
    for i in range(5):
        a, b = neuron_pos[i], neuron_pos[(i + 1) % 5]
        mid = (a + b) * 0.5 + Vector((0, 0, 3.0))
        lines.append(tube(f"line{i}", catmull_rom([a + Vector((0, 0, 1.8)), mid, b + Vector((0, 0, 1.8))], 8), 0.12, spark, 0.0, 1.0, caps=True, resolution=2, flip=False))
    objs.append(C.join(lines, "NC_Synapses"))
    sparks = []
    for i in range(40):
        a = random.uniform(0, math.pi * 2)
        r = random.uniform(4, 30)
        sparks.append(C.add_sphere(f"spark{i}", random.uniform(0.15, 0.4), (math.cos(a) * r, math.sin(a) * r, random.uniform(-9, 8)), 8, 6, spark))
    objs.append(C.join(sparks, "NC_Sparks"))
    # マーカー
    mk("MK_player", (0, -2, -14.5), (0, 0, 0))
    mk("MK_goal", (0, 30, -11))
    for i, p in enumerate(neuron_pos):
        mk(f"MK_neuron_{i + 1}", p)
    mk("MK_pickup_heart_item_1", (-22, 10, -9.5))
    mk("MK_path_000", (0, -28, -11))
    mk("MK_path_001", (0, 0, -15))
    mk("MK_path_002", (0, 30, -11))
    return objs


# ------------------------------------------------------------------ 9. はな
def build_nose():
    wall = C.material("NoseWall", (0.98, 0.78, 0.7), 0.85)
    hair = C.material("NoseHair", (0.3, 0.2, 0.15), 0.8)
    ctrl = [(0, 0, 0), (0, 30, 2), (4, 60, 8), (-5, 90, 16), (3, 120, 26), (0, 150, 36), (0, 170, 44)]
    pts = catmull_rom(ctrl, 8)
    R = 4.6
    objs = [tube("Nose", pts, R, wall, 0.3, 3.0, caps=False)]
    # はなげ：かべから 内がわへ（当たり判定あり）
    random.seed(91)
    hairs = []
    for i in range(34):
        f = random.uniform(0.3, 0.95)
        pos, d = along(pts, f)
        ang = random.uniform(math.radians(200), math.radians(340))  # 下半分
        right = side_of(d, 1.0)
        up = Vector((0, 0, 1))
        base = pos + (right * math.cos(ang) + up * math.sin(ang)) * (R - 0.2)
        inward = (pos - base).normalized()
        length = random.uniform(2.5, 4.5)
        h = C.add_cylinder(f"hair{i}", 0.13, length, base + inward * length / 2, inward.to_track_quat("Z", "Y").to_euler(), 6, hair)
        h.rotation_euler.rotate_axis("X", random.uniform(-0.3, 0.3))
        hairs.append(h)
    objs.append(C.join(hairs, "Hairs"))
    objs.append(scatter_on_floor("Dust", lambda i: CH.build_dust(), 6, pts, R, 93, (0.25, 0.9), 0.5, 0.5, floor_obj=objs[0]))
    # マーカー
    path_markers(pts, 8.0)
    mk("MK_player", floor_point(pts, 0.01, R, 0.0, 1.2))
    mk("MK_goal", floor_point(pts, 0.98, R, 0.0, 1.0))
    mk("MK_checkpoint_1", floor_point(pts, 0.35, R, 0.0, 0.5))
    mk("MK_checkpoint_2", floor_point(pts, 0.68, R, 0.0, 0.5))
    mk("MK_card_sneeze", floor_point(pts, 0.04, R, 0.0, 1.0))
    mk("MK_card_dust", floor_point(pts, 0.3, R, 0.0, 1.0))
    mk("MK_pickup_heart_item_1", floor_point(pts, 0.5, R, 0.0, 1.0))
    return objs


BUILDERS = {
    "stage_mouth": build_mouth,
    "stage_esophagus": build_esophagus,
    "stage_stomach": build_stomach,
    "stage_intestine": build_intestine,
    "stage_vessel": build_vessel,
    "stage_heart": build_heart,
    "stage_heart2": build_heart2,
    "stage_lungs": build_lungs,
    "stage_brain": build_brain,
    "stage_nose": build_nose,
}


def build_all(names=None, save_blend=False):
    names = names or list(BUILDERS.keys())
    for name in names:
        print(f"[stages] {name}")
        C.reset_scene()
        objs = BUILDERS[name]()
        markers = [o for o in bpy.data.objects if o.name.startswith("MK_")]
        C.export_glb([o for o in objs if o is not None] + markers, f"stages/{name}")
        if save_blend:
            C.save_blend(name)


if __name__ == "__main__":
    import sys
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    args = [a for a in argv if not a.startswith("-") and not a.endswith(".py")]
    unknown = [a for a in args if a not in BUILDERS]
    if unknown:
        sys.exit(f"unknown name(s) {unknown}; choices: {', '.join(BUILDERS)}")
    build_all(args or None)

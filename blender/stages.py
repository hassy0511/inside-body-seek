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
    pink = C.material("TonguePink", (0.98, 0.55, 0.62), 0.8)
    gum = C.material("GumPink", (0.95, 0.45, 0.55), 0.8)
    palate = C.material("Palate", (0.98, 0.7, 0.75), 0.8)
    tooth = C.material("ToothWhite", (1.0, 0.98, 0.94), 0.35)
    lip = C.material("Lip", (0.9, 0.35, 0.45), 0.7)

    objs = []
    cavity = ellipsoid_room("cavity", (0, 0, 2.0), (19, 26, 8.5), palate, 48, 28, 0.0, flip=False)
    throat_pts = catmull_rom([Vector((0, 14, -1)), Vector((0, 22, -3)), Vector((0, 30, -7)), Vector((0, 38, -14))], 6)
    throat = solid_tube("throat", throat_pts, 4.5, gum)
    cavity = boolean_union([cavity, throat], "MouthCavity")
    C.displace_noise(cavity, 0.25, 5.0, 12)
    C.apply_modifiers(cavity)
    bpy.ops.object.shade_smooth()
    orient_inward(cavity, [Vector((0, 0, 2.0))] + throat_pts)
    objs.append(cavity)
    tongue = C.add_sphere("Tongue", 1.0, (0, -1.0, -5.0), 40, 24, pink, scale=(13.5, 19.0, 2.6))
    C.set_active(tongue)
    bpy.ops.object.transform_apply(scale=True)
    C.displace_noise(tongue, 0.12, 2.0, 11)
    C.apply_modifiers(tongue)
    objs.append(tongue)
    # まんなかの みぞ
    groove = C.add_box("NC_TongueGroove", (0.6, 24, 0.2), (0, -1.0, -2.35), (0, 0, 0), gum)
    objs.append(groove)
    # は（した）：前の弧に 12 本、（うえ）：天井から 12 本
    teeth = []
    for row, zc, flip in (("lower", -4.3, 1), ("upper", 6.6, -1)):
        for i in range(12):
            a = math.radians(205 + i * (130 / 11))
            x, y = math.cos(a) * 16.5, math.sin(a) * 21.0 + 2.0
            w = 1.6 if 3 <= i <= 8 else 2.2
            h = 2.6 if 3 <= i <= 8 else 2.2
            t = C.add_box(f"tooth_{row}_{i}", (w, 1.6, h), (x, y, zc + flip * h * 0.5), (0, 0, a + math.pi / 2), tooth, bevel=0.35)
            teeth.append(t)
    teeth_o = C.join(teeth, "Teeth")
    C.apply_modifiers(teeth_o)
    C.shade_smooth(teeth_o, 60)
    objs.append(teeth_o)
    # くちびる（前の壁）
    lips = C.add_torus("Lips", 15.0, 2.2, (0, -22.0, 1.0), (math.radians(90), 0, 0), lip, 32, 12)
    lips.scale = (1.0, 1.0, 0.45)
    objs.append(lips)
    # のどちんこ
    uvula = C.add_sphere("NC_Uvula", 1.0, (0, 17, 5.5), 12, 8, lip, scale=(0.7, 0.7, 1.4))
    objs.append(uvula)

    # マーカー
    mk("MK_player", (0, -14, -2.0))
    mk("MK_goal", (0, 27, -8.5))
    mk("MK_enemy_mushiba_1", (-9.5, -9, -2.2))
    mk("MK_enemy_mushiba_2", (10, -4, -2.2))
    mk("MK_enemy_mushiba_3", (-6, 9, -2.2))
    mk("MK_pickup_heart_item_1", (7, 10, -2.0))
    mk("MK_card_tooth", (-11, -10, -2.0))
    mk("MK_sign_throat", (0, 22, -2))
    mk("MK_path_000", (0, -14, -2))
    mk("MK_path_001", (0, 0, -2))
    mk("MK_path_002", (0, 27, -8.5))
    return objs


# ------------------------------------------------------------------ 2. しょくどう
def build_esophagus():
    wall = C.material("EsophagusWall", (0.95, 0.5, 0.52), 0.85)
    wall2 = C.material("TracheaWall", (0.95, 0.75, 0.7), 0.85)
    flap = C.material("Epiglottis", (0.85, 0.4, 0.5), 0.8)
    ctrl = [(0, 0, 0), (0, 25, -4), (6, 50, -10), (-6, 80, -18), (0, 110, -27), (7, 140, -36), (0, 170, -44), (0, 190, -48)]
    pts = catmull_rom(ctrl, 8)
    R = 5.2
    main = solid_tube("esophagus", pts, R, wall, ribs=0.12, rib_every=4)
    # きかん（くうきの みち）：始まりのすぐ先で 右に分かれる 行き止まり
    pos, d = along(pts, 0.06)
    tr_pts = catmull_rom([pos + side_of(d, 1.5), pos + side_of(d, 9.0) + Vector((0, 3, 1.5)), pos + side_of(d, 16.0) + Vector((0, 6, 4.0))], 6)
    tr = solid_tube("trachea", tr_pts, 3.6, wall2)
    main = boolean_union([main, tr], "Esophagus")
    C.displace_noise(main, 0.3, 2.5, 22)
    C.apply_modifiers(main)
    bpy.ops.object.shade_smooth()
    orient_inward(main, pts + tr_pts)
    objs = [main]
    # 気管の入口をふさぐ「ふた」（こうとうがい）
    fpos = tr_pts[len(tr_pts) // 3]
    fd = (tr_pts[len(tr_pts) // 3 + 1] - fpos).normalized()
    rot = fd.to_track_quat("Z", "Y").to_euler()
    objs.append(C.add_cylinder("Epiglottis", 3.5, 0.4, fpos, rot, 20, flap))
    # たべもののかたまり（床に）
    food = scatter_on_floor("FoodChunks", lambda i: CH.build_food(), 7, pts, R, 21, (0.18, 0.92), 0.55, 0.7, floor_obj=main)
    objs.append(food)
    # マーカー
    path_markers(pts, 8.0)
    mk("MK_player", floor_point(pts, 0.01, R, 0.0, 1.2))
    mk("MK_goal", floor_point(pts, 0.985, R, 0.0, 0.8))
    mk("MK_checkpoint_1", floor_point(pts, 0.35, R, 0.0, 0.5))
    mk("MK_checkpoint_2", floor_point(pts, 0.68, R, 0.0, 0.5))
    mk("MK_pickup_heart_item_1", floor_point(pts, 0.5, R, 0.4, 1.0))
    mk("MK_card_epiglottis", floor_point(pts, 0.07, R, 0.0, 1.0))
    mk("MK_card_food", floor_point(pts, 0.2, R, 0.0, 1.0))
    mk("MK_sign_trachea", tr_pts[2] + Vector((0, 0, -1.5)))
    mk("MK_sign_esophagus", floor_point(pts, 0.1, R, -0.3, 1.0))
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

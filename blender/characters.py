"""キャラクター（プレイヤー・敵・なかま・アイテム）を Blender で作って GLB に書き出す。

実行: python -m blender.characters   /   blender -b -P blender/characters.py
出力: godot/assets/models/characters/<name>.glb

ぜんぶ「丸い・目がある・色がはっきり」の ローポリ。前は +Y（Godot では -Z）。
キャラデザを描き直したら、ここの関数を書きかえるか、同じ名前の GLB を手作業のモデルで上書きする。
"""
from __future__ import annotations

import math
import random

import bpy
from mathutils import Vector

try:
    from . import common as C
except ImportError:  # blender -b -P で直接実行したとき
    import os
    import sys
    sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    from blender import common as C


def curve_tube(name, points, radius, mat, resolution=4, smooth=True, taper=False):
    """点の列に沿った くだ（太さ radius）。ピロリきんの らせんや べん毛に使う。"""
    cu = bpy.data.curves.new(name + "_curve", "CURVE")
    cu.dimensions = "3D"
    sp = cu.splines.new("NURBS")
    sp.points.add(len(points) - 1)
    for i, p in enumerate(points):
        sp.points[i].co = (p[0], p[1], p[2], 1.0)
    sp.use_endpoint_u = True
    sp.order_u = min(4, len(points))
    cu.bevel_depth = radius
    cu.bevel_resolution = resolution
    cu.resolution_u = 8
    cu.use_fill_caps = True
    ob = bpy.data.objects.new(name, cu)
    C.link(ob)
    if taper:
        tp = bpy.data.curves.new(name + "_taper", "CURVE")
        tp.dimensions = "2D"
        ts = tp.splines.new("POLY")
        ts.points.add(1)
        ts.points[0].co = (0, 1.0, 0, 1)
        ts.points[1].co = (1, 0.15, 0, 1)
        tob = bpy.data.objects.new(name + "_taperobj", tp)
        C.link(tob)
        cu.taper_object = tob
    C.set_active(ob)
    bpy.ops.object.convert(target="MESH")
    ob = bpy.context.active_object
    ob.data.materials.append(mat)
    if smooth:
        bpy.ops.object.shade_smooth()
    if taper:
        bpy.data.objects.remove(tob)
    return ob


# ------------------------------------------------------------------ プレイヤー
def build_pod():
    white = C.material("PodWhite", (0.96, 0.96, 1.0), 0.5)
    glass = C.material("PodGlass", (0.55, 0.85, 1.0), 0.2, emission=(0.2, 0.4, 0.6), emission_strength=0.3)
    yellow = C.material("PodYellow", (1.0, 0.8, 0.25), 0.6)
    pink = C.material("PodPink", (1.0, 0.55, 0.7), 0.6)
    glow = C.material("PodGlow", (0.5, 0.95, 1.0), 0.3, emission=(0.4, 0.9, 1.0), emission_strength=2.0)
    skin = C.material("Skin", (1.0, 0.88, 0.78), 0.7)
    hair = C.material("Hair", (0.35, 0.22, 0.15), 0.8)

    body = C.add_sphere("pod_body", 0.6, (0, 0, 0), 28, 18, white, scale=(1.0, 1.25, 0.9))
    window = C.add_sphere("pod_window", 0.42, (0, 0.38, 0.12), 24, 14, glass, scale=(1.0, 0.7, 0.9))
    # まどの中の 主人公の かお
    face = C.add_sphere("pod_face", 0.2, (0, 0.42, 0.14), 16, 10, skin)
    hair_o = C.add_sphere("pod_hair", 0.21, (0, 0.40, 0.2), 16, 10, hair, scale=(1.05, 1.0, 0.7))
    parts = [body, window, face, hair_o]
    parts += C.eyes("pod", 0.56, 0.16, spacing=0.08, r=0.045, pupil=0.025)
    parts.append(C.smile("pod", 0.6, 0.07, 0.06, thickness=0.012))
    # ひれ
    for sx in (-1, 1):
        fin = C.add_box(f"pod_fin{sx}", (0.5, 0.45, 0.08), (sx * 0.62, -0.25, -0.05), (0, math.radians(sx * 25), 0), yellow, bevel=0.03)
        parts.append(fin)
    tail = C.add_box("pod_tailfin", (0.08, 0.4, 0.45), (0, -0.55, 0.35), (math.radians(-20), 0, 0), yellow, bevel=0.03)
    parts.append(tail)
    # おなかの ピンクの ライン
    band = C.add_torus("pod_band", 0.58, 0.05, (0, -0.1, 0), (math.radians(90), 0, 0), pink, 28, 8)
    band.scale = (1.0, 1.0, 1.0)
    parts.append(band)
    # うしろの プロペラ（別オブジェクト：Godot 側で "Propeller" を回す）
    ring = C.add_torus("pod_ring", 0.3, 0.06, (0, -0.78, 0), (math.radians(90), 0, 0), yellow, 20, 8)
    parts.append(ring)
    main = C.join(parts, "pod")
    C.apply_modifiers(main)
    C.shade_smooth(main, 50)

    blades = []
    for i in range(3):
        a = i * math.pi * 2 / 3
        b = C.add_box(f"blade{i}", (0.08, 0.04, 0.5), (0, -0.8, 0), (0, a, 0), glow)
        b.location = (0, -0.8, 0)
        blades.append(b)
    hub = C.add_sphere("hub", 0.09, (0, -0.8, 0), 12, 8, glow)
    prop = C.join(blades + [hub], "Propeller")
    # 回転軸：Blender の Y 軸（Godot では Z 軸）。原点をハブの位置に。
    C.set_active(prop)
    bpy.context.scene.cursor.location = (0, -0.8, 0)
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    prop.parent = main
    prop.matrix_parent_inverse = main.matrix_world.inverted()
    return main


def build_pico():
    blue = C.material("PicoBlue", (0.72, 0.9, 1.0), 0.4)
    dark = C.material("PicoDark", (0.3, 0.45, 0.6), 0.5)
    yellow = C.material("PodYellow", (1.0, 0.8, 0.25), 0.6)
    body = C.add_sphere("pico_body", 0.5, (0, 0, 0), 24, 16, blue)
    ant = C.add_cylinder("pico_ant", 0.03, 0.35, (0, 0, 0.62), (0, 0, 0), 8, dark)
    ball = C.add_sphere("pico_ball", 0.09, (0, 0, 0.82), 12, 8, yellow)
    parts = [body, ant, ball] + C.eyes("pico", 0.42, 0.08, spacing=0.17, r=0.09, pupil=0.045)
    parts.append(C.smile("pico", 0.47, -0.12, 0.14, thickness=0.025))
    for sx in (-1, 1):
        parts.append(C.add_sphere(f"pico_hand{sx}", 0.1, (sx * 0.55, 0.1, -0.1), 10, 6, dark))
    o = C.join(parts, "pico")
    C.shade_smooth(o, 50)
    return o


# ------------------------------------------------------------------ 敵
def build_mushiba():
    dark = C.material("MushibaDark", (0.22, 0.2, 0.28), 0.8)
    teeth = C.material("Teeth", (1.0, 1.0, 0.95), 0.4)
    metal = C.material("Metal", (0.6, 0.62, 0.68), 0.35, metallic=0.6)
    body = C.add_ico("mushiba_body", 0.6, (0, 0, 0), 2, dark)
    C.displace_noise(body, 0.08, 0.6, 1)
    C.subdivide(body, 1)
    parts = [body]
    parts += C.eyes("mushiba", 0.5, 0.18, spacing=0.22, r=0.11, pupil=0.06)
    # ギザギザの くち
    for i in range(5):
        x = -0.26 + i * 0.13
        parts.append(C.add_cone(f"mushiba_tooth{i}", 0.06, 0.0, 0.14, (x, 0.55, -0.12 - (i % 2) * 0.03), (math.radians(90 if i % 2 else -90), 0, 0), 6, teeth))
    # ドリル
    parts.append(C.add_cone("mushiba_drill", 0.12, 0.0, 0.45, (0.55, 0.3, -0.1), (math.radians(-90), 0, 0), 10, metal))
    parts.append(C.add_sphere("mushiba_hand", 0.12, (0.55, 0.05, -0.1), 10, 6, dark))
    # ツノ
    for sx in (-1, 1):
        parts.append(C.add_cone(f"mushiba_horn{sx}", 0.08, 0.0, 0.25, (sx * 0.3, 0.0, 0.6), (math.radians(sx * -20), 0, 0), 8, dark))
    o = C.join(parts, "mushiba")
    C.apply_modifiers(o)
    C.shade_smooth(o, 50)
    return o


def build_pylori():
    purple = C.material("PyloriPurple", (0.6, 0.42, 0.8), 0.6)
    light = C.material("PyloriLight", (0.8, 0.7, 0.95), 0.6)
    pts = []
    n = 26
    for i in range(n):
        t = i / (n - 1)
        a = t * math.pi * 3.0
        pts.append((math.cos(a) * 0.28, (t - 0.5) * 1.4, math.sin(a) * 0.28))
    body = curve_tube("pylori_body", pts, 0.17, purple, 5)
    parts = [body]
    # べん毛（うしろに 3 本）
    for k in range(3):
        a = k * math.pi * 2 / 3
        fl = [(math.cos(a) * 0.12, -0.75 - j * 0.1, math.sin(a) * 0.12 + math.sin(j * 1.3 + k) * 0.06) for j in range(7)]
        parts.append(curve_tube(f"pylori_fl{k}", fl, 0.03, light, 3, taper=True))
    parts += C.eyes("pylori", 0.78, 0.15, spacing=0.14, r=0.08, pupil=0.045)
    parts.append(C.smile("pylori", 0.84, 0.0, 0.08, thickness=0.018))
    o = C.join(parts, "pylori")
    C.shade_smooth(o, 60)
    return o


def build_akudama():
    purple = C.material("AkudamaPurple", (0.55, 0.2, 0.65), 0.7)
    body = C.add_sphere("akudama_body", 0.6, (0, 0, 0), 24, 16, purple, scale=(1.0, 1.0, 0.8))
    C.displace_noise(body, 0.05, 0.7, 2)
    parts = [body]
    parts += C.eyes("akudama", 0.5, 0.12, spacing=0.2, r=0.1, pupil=0.05)
    # へのじ くち：小さいトーラスを 上下さかさに
    frown = C.smile("akudama", 0.58, -0.24, 0.12, thickness=0.02)
    frown.rotation_euler = (math.radians(90), math.radians(180), 0)
    parts.append(frown)
    for sx in (-1, 1):
        parts.append(C.add_cone(f"akudama_brow{sx}", 0.05, 0.0, 0.22, (sx * 0.22, 0.5, 0.3), (math.radians(90), 0, math.radians(sx * -35)), 6, purple))
    o = C.join(parts, "akudama")
    C.apply_modifiers(o)
    C.shade_smooth(o, 50)
    return o


def build_virus(name="virus", radius=0.45, boss=False):
    green = C.material("VirusGreen", (0.35, 0.8, 0.45), 0.7)
    dark = C.material("VirusDark", (0.15, 0.5, 0.3), 0.7)
    body = C.add_ico(f"{name}_body", radius, (0, 0, 0), 2, green)
    parts = [body]
    # トゲ：正二十面体の頂点方向に
    dirs = []
    phi = (1 + 5 ** 0.5) / 2
    for a in (-1, 1):
        for b in (-1, 1):
            dirs += [(0, a, b * phi), (a, b * phi, 0), (b * phi, 0, a)]
    for i, d in enumerate(dirs):
        v = Vector(d).normalized()
        loc = v * (radius * 1.05)
        rot = v.to_track_quat("Z", "Y").to_euler()
        parts.append(C.add_cone(f"{name}_spike{i}", radius * 0.18, radius * 0.06, radius * 0.5, loc + v * radius * 0.2, rot, 8, dark))
        parts.append(C.add_sphere(f"{name}_knob{i}", radius * 0.12, loc + v * radius * 0.48, 8, 6, dark))
    parts += C.eyes(name, radius * 0.8, radius * 0.25, spacing=radius * 0.4, r=radius * 0.2, pupil=radius * 0.1)
    parts.append(C.smile(name, radius * 0.9, -radius * 0.15, radius * 0.25, thickness=radius * 0.05))
    if boss:
        gold = C.material("Gold", (1.0, 0.85, 0.3), 0.4, metallic=0.5)
        crown = C.add_cylinder(f"{name}_crown", radius * 0.45, radius * 0.3, (0, 0, radius * 1.05), (0, 0, 0), 8, gold)
        parts.append(crown)
        for i in range(8):
            a = i * math.pi / 4
            parts.append(C.add_cone(f"{name}_crownspike{i}", radius * 0.08, 0.0, radius * 0.3, (math.cos(a) * radius * 0.42, math.sin(a) * radius * 0.42, radius * 1.3), (0, 0, 0), 6, gold))
    o = C.join(parts, name)
    C.shade_smooth(o, 50)
    return o


def build_cholesterol():
    yellow = C.material("CholYellow", (0.95, 0.85, 0.35), 0.9)
    body = C.add_ico("cholesterol_body", 0.8, (0, 0, 0), 2, yellow)
    C.displace_noise(body, 0.25, 0.8, 3)
    parts = [body]
    for i in range(4):
        a = i * 1.6
        parts.append(C.add_ico(f"chol_lump{i}", 0.35, (math.cos(a) * 0.6, math.sin(a) * 0.6, (i % 2) * 0.4 - 0.2), 1, yellow))
    o = C.join(parts, "cholesterol")
    C.apply_modifiers(o)
    return o


def build_food():
    brown = C.material("FoodBrown", (0.75, 0.5, 0.3), 0.9)
    body = C.add_ico("food_body", 0.8, (0, 0, 0), 2, brown)
    C.displace_noise(body, 0.3, 1.0, 4)
    o = C.join([body], "food")
    C.apply_modifiers(o)
    return o


def build_dust():
    grey = C.material("DustGrey", (0.6, 0.58, 0.55), 1.0)
    body = C.add_ico("dust_body", 0.6, (0, 0, 0), 2, grey)
    C.displace_noise(body, 0.35, 0.5, 5)
    parts = [body]
    for i in range(8):
        a = i * 0.8
        parts.append(C.add_cylinder(f"dust_hair{i}", 0.02, 0.5, (math.cos(a) * 0.5, math.sin(a) * 0.5, math.sin(i) * 0.3), (math.radians(60 * i), math.radians(40 * i), 0), 5, grey))
    o = C.join(parts, "dust")
    C.apply_modifiers(o)
    return o


# ------------------------------------------------------------------ なかま
def build_rbc():
    red = C.material("RbcRed", (0.85, 0.15, 0.22), 0.6)
    dark = C.material("RbcDark", (0.6, 0.08, 0.15), 0.6)
    ring = C.add_torus("rbc_ring", 0.42, 0.26, (0, 0, 0), (0, 0, 0), red, 28, 14)
    center = C.add_sphere("rbc_center", 0.3, (0, 0, 0), 16, 10, dark, scale=(1.0, 1.0, 0.45))
    parts = [ring, center]
    parts += C.eyes("rbc", 0.45, 0.18, spacing=0.2, r=0.09, pupil=0.045)
    parts.append(C.smile("rbc", 0.55, 0.0, 0.1, thickness=0.02))
    o = C.join(parts, "rbc")
    C.shade_smooth(o, 50)
    return o


def build_wbc():
    white = C.material("WbcWhite", (0.98, 0.98, 0.94), 0.8)
    body = C.add_ico("wbc_body", 0.6, (0, 0, 0), 3, white)
    C.displace_noise(body, 0.12, 0.5, 6)
    parts = [body]
    for i in range(5):
        a = i * 1.26
        parts.append(C.add_sphere(f"wbc_bump{i}", 0.22, (math.cos(a) * 0.5, math.sin(a) * 0.5, (i % 2) * 0.5 - 0.25), 12, 8, white))
    parts += C.eyes("wbc", 0.5, 0.12, spacing=0.2, r=0.1, pupil=0.05)
    parts.append(C.smile("wbc", 0.58, -0.12, 0.14, thickness=0.025))
    # ヘルメット（ぼうえいたい）
    blue = C.material("HelmetBlue", (0.35, 0.55, 0.9), 0.5)
    helmet = C.add_sphere("wbc_helmet", 0.5, (0, -0.05, 0.3), 20, 12, blue, scale=(1.0, 1.0, 0.6))
    parts.append(helmet)
    o = C.join(parts, "wbc")
    C.apply_modifiers(o)
    C.shade_smooth(o, 50)
    return o


def build_zendama():
    green = C.material("ZendamaGreen", (0.45, 0.85, 0.5), 0.7)
    body = C.add_sphere("zendama_body", 0.55, (0, 0, 0), 24, 16, green, scale=(1.0, 1.1, 0.85))
    parts = [body]
    parts += C.eyes("zendama", 0.48, 0.1, spacing=0.18, r=0.09, pupil=0.045)
    parts.append(C.smile("zendama", 0.56, -0.1, 0.16, thickness=0.025))
    for sx in (-1, 1):
        parts.append(C.add_sphere(f"zendama_cheek{sx}", 0.06, (sx * 0.33, 0.45, -0.05), 8, 6, C.material("Cheek", (1.0, 0.6, 0.65), 0.8)))
    leaf = C.material("Leaf", (0.3, 0.65, 0.3), 0.7)
    parts.append(C.add_cone("zendama_leaf", 0.12, 0.0, 0.3, (0.05, 0.0, 0.62), (math.radians(20), math.radians(30), 0), 6, leaf))
    o = C.join(parts, "zendama")
    C.shade_smooth(o, 50)
    return o


def build_wallcell():
    peach = C.material("CellPeach", (1.0, 0.75, 0.6), 0.8)
    slime = C.material("Slime", (0.8, 0.95, 1.0), 0.3, alpha=0.6)
    body = C.add_box("wallcell_body", (1.1, 0.9, 0.9), (0, 0, 0), (0, 0, 0), peach, bevel=0.3)
    parts = [body]
    parts += C.eyes("wallcell", 0.4, 0.15, spacing=0.22, r=0.1, pupil=0.05)
    parts.append(C.smile("wallcell", 0.47, -0.1, 0.15, thickness=0.025))
    bubble = C.add_sphere("wallcell_mucus", 0.3, (0, 0, 0.6), 14, 10, slime, scale=(1.5, 1.2, 0.5))
    parts.append(bubble)
    o = C.join(parts, "wallcell")
    C.apply_modifiers(o)
    C.shade_smooth(o, 50)
    return o


def build_villus():
    green = C.material("VillusGreen", (0.55, 0.85, 0.55), 0.8)
    light = C.material("VillusLight", (0.75, 0.95, 0.7), 0.8)
    parts = []
    random.seed(7)
    for i in range(9):
        a = i * 0.7
        r = 0.0 if i == 0 else 0.55 + (i % 3) * 0.2
        h = 2.2 if i == 0 else 1.2 + random.random() * 0.8
        x, y = math.cos(a) * r, math.sin(a) * r
        stalk = C.add_cylinder(f"villus_stalk{i}", 0.28, h, (x, y, h / 2), (0, 0, 0), 12, green)
        tip = C.add_sphere(f"villus_tip{i}", 0.3, (x, y, h), 14, 10, light)
        parts += [stalk, tip]
    base = C.add_sphere("villus_base", 1.2, (0, 0, 0), 20, 10, green, scale=(1.0, 1.0, 0.25))
    parts.append(base)
    parts += C.eyes("villus", 0.3, 2.25, spacing=0.14, r=0.08, pupil=0.04)
    parts.append(C.smile("villus", 0.3, 2.1, 0.1, thickness=0.02))
    o = C.join(parts, "villus")
    C.shade_smooth(o, 50)
    return o


# ------------------------------------------------------------------ アイテム
def build_nutrient_a():
    """ビタミン：ほし"""
    mat = C.material("VitaminYellow", (1.0, 0.85, 0.2), 0.4, emission=(0.6, 0.5, 0.1), emission_strength=0.6)
    import bmesh
    me = bpy.data.meshes.new("nutrient_a")
    bm = bmesh.new()
    outer, inner = 0.45, 0.2
    top = bm.verts.new((0, 0, 0.12))
    bot = bm.verts.new((0, 0, -0.12))
    rim = []
    for i in range(10):
        a = math.pi / 2 + i * math.pi / 5
        r = outer if i % 2 == 0 else inner
        rim.append(bm.verts.new((math.cos(a) * r, 0, math.sin(a) * r)))
    for i in range(10):
        bm.faces.new((rim[i], rim[(i + 1) % 10], top))
        bm.faces.new((rim[(i + 1) % 10], rim[i], bot))
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new("nutrient_a", me)
    C.link(o)
    o.data.materials.append(mat)
    o.rotation_euler = (0, 0, math.radians(90))
    C.set_active(o)
    bpy.ops.object.transform_apply(rotation=True)
    return o


def build_nutrient_b():
    """ブドウとう：ひしがた"""
    mat = C.material("GlucoseBlue", (0.45, 0.8, 1.0), 0.3, emission=(0.2, 0.4, 0.6), emission_strength=0.6)
    bpy.ops.mesh.primitive_ico_sphere_add(radius=0.42, subdivisions=1)
    o = bpy.context.active_object
    o.name = "nutrient_b"
    o.scale = (0.7, 0.7, 1.2)
    o.data.materials.append(mat)
    C.set_active(o)
    bpy.ops.object.transform_apply(scale=True)
    return o


def build_nutrient_c():
    """アミノさん：まめ"""
    mat = C.material("AminoPink", (1.0, 0.55, 0.75), 0.5, emission=(0.5, 0.2, 0.35), emission_strength=0.5)
    a = C.add_sphere("nutrient_c1", 0.28, (-0.18, 0, 0), 14, 10, mat)
    b = C.add_sphere("nutrient_c2", 0.28, (0.18, 0, 0.08), 14, 10, mat)
    o = C.join([a, b], "nutrient_c")
    C.shade_smooth(o, 60)
    return o


def build_heart_item():
    mat = C.material("HeartRed", (1.0, 0.35, 0.45), 0.4, emission=(0.6, 0.15, 0.2), emission_strength=0.6)
    a = C.add_sphere("heart_l", 0.24, (-0.2, 0, 0.12), 14, 10, mat)
    b = C.add_sphere("heart_r", 0.24, (0.2, 0, 0.12), 14, 10, mat)
    c = C.add_cone("heart_tip", 0.4, 0.0, 0.5, (0, 0, -0.17), (math.radians(180), 0, 0), 4, mat)
    c.rotation_euler = (math.radians(180), 0, math.radians(45))
    o = C.join([a, b, c], "heart_item")
    C.shade_smooth(o, 60)
    return o


def build_neuron():
    lav = C.material("NeuronLav", (0.85, 0.78, 1.0), 0.6)
    core = C.material("NeuronCore", (1.0, 0.95, 0.6), 0.3, emission=(1.0, 0.9, 0.4), emission_strength=1.5)
    body = C.add_sphere("neuron_body", 0.55, (0, 0, 1.3), 20, 14, lav, scale=(1.0, 1.0, 0.85))
    nucleus = C.add_sphere("neuron_core", 0.25, (0, 0, 1.35), 14, 10, core)
    axon = C.add_cylinder("neuron_axon", 0.12, 1.3, (0, 0, 0.65), (0, 0, 0), 10, lav)
    parts = [body, nucleus, axon]
    for i in range(6):
        a = i * math.pi / 3
        d = Vector((math.cos(a) * 0.5, math.sin(a) * 0.5, 0.45)).normalized()
        loc = Vector((0, 0, 1.3)) + d * 0.7
        rot = d.to_track_quat("Z", "Y").to_euler()
        parts.append(C.add_cone(f"neuron_dend{i}", 0.1, 0.02, 0.6, loc, rot, 6, lav))
        parts.append(C.add_sphere(f"neuron_tip{i}", 0.07, Vector((0, 0, 1.3)) + d * 1.0, 8, 6, core))
    base = C.add_sphere("neuron_base", 0.4, (0, 0, 0), 14, 8, lav, scale=(1.0, 1.0, 0.3))
    parts.append(base)
    parts += C.eyes("neuron", 0.48, 1.4, spacing=0.16, r=0.08, pupil=0.04)
    parts.append(C.smile("neuron", 0.52, 1.25, 0.1, thickness=0.018))
    o = C.join(parts, "neuron")
    C.shade_smooth(o, 50)
    return o


BUILDERS = {
    "pod": build_pod,
    "pico": build_pico,
    "mushiba": build_mushiba,
    "pylori": build_pylori,
    "akudama": build_akudama,
    "virus": lambda: build_virus("virus", 0.45),
    "boss_virus": lambda: build_virus("boss_virus", 0.9, boss=True),
    "cholesterol": build_cholesterol,
    "food": build_food,
    "dust": build_dust,
    "rbc": build_rbc,
    "wbc": build_wbc,
    "zendama": build_zendama,
    "wallcell": build_wallcell,
    "villus": build_villus,
    "nutrient_a": build_nutrient_a,
    "nutrient_b": build_nutrient_b,
    "nutrient_c": build_nutrient_c,
    "heart_item": build_heart_item,
    "neuron": build_neuron,
}


def build_all(names=None, save_blend=False):
    names = names or list(BUILDERS.keys())
    for name in names:
        print(f"[characters] {name}")
        C.reset_scene()
        obj = BUILDERS[name]()
        C.export_glb([obj], f"characters/{name}")
        if save_blend:
            C.save_blend(f"char_{name}")


if __name__ == "__main__":
    import sys
    args = [a for a in sys.argv[1:] if not a.startswith("-")]
    build_all(args or None)

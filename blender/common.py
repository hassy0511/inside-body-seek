"""Blender（bpy）でモデルを作るときの共通ヘルパー。

・Blender 本体から:  blender -b -P blender/build_all.py
・pip の bpy から:    python -m blender.build_all   （python -m pip install bpy）

座標のきまり：Blender の +Y を「前」として作る（glTF で Godot の -Z = 前 になる）。
単位は m。キャラクターは だいたい半径 0.5〜1。
"""
from __future__ import annotations

import math
import os
import random

import bpy
import bmesh
from mathutils import Vector, Matrix, noise

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODELS_DIR = os.path.join(ROOT, "godot", "assets", "models")
BLEND_DIR = os.path.join(ROOT, "blender", "out")


# ------------------------------------------------------------------ シーン
def reset_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for block in (bpy.data.meshes, bpy.data.materials, bpy.data.objects, bpy.data.curves, bpy.data.textures):
        for item in list(block):
            try:
                block.remove(item)
            except Exception:
                pass


def material(name: str, color, roughness=0.75, emission=None, emission_strength=1.0, alpha=1.0, metallic=0.0):
    """Principled BSDF の単色マテリアル。Godot では StandardMaterial3D になる。"""
    r, g, b = color[:3]
    mat = bpy.data.materials.get(name)
    if mat is None:
        mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (r, g, b, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    if emission is not None:
        er, eg, eb = emission[:3]
        bsdf.inputs["Emission Color"].default_value = (er, eg, eb, 1.0)
        bsdf.inputs["Emission Strength"].default_value = emission_strength
    if alpha < 1.0:
        bsdf.inputs["Alpha"].default_value = alpha
        if hasattr(mat, "surface_render_method"):
            mat.surface_render_method = "BLENDED"
        else:
            mat.blend_method = "BLEND"
    mat.diffuse_color = (r, g, b, alpha)
    return mat


def link(obj) -> None:
    bpy.context.scene.collection.objects.link(obj)


def set_active(obj) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def shade_smooth(obj, angle_deg=40.0) -> None:
    set_active(obj)
    bpy.ops.object.shade_smooth()
    # 角ばった部分は自動でフラットに（Blender 4.1+ は smooth_by_angle モディファイア）
    try:
        bpy.ops.object.shade_auto_smooth(angle=math.radians(angle_deg))
    except Exception:
        try:
            obj.data.use_auto_smooth = True
            obj.data.auto_smooth_angle = math.radians(angle_deg)
        except Exception:
            pass


def apply_modifiers(obj) -> None:
    set_active(obj)
    for m in list(obj.modifiers):
        try:
            bpy.ops.object.modifier_apply(modifier=m.name)
        except Exception:
            pass


# ------------------------------------------------------------------ 形
def add_sphere(name, radius=1.0, location=(0, 0, 0), segments=24, rings=16, mat=None, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=radius, segments=segments, ring_count=rings, location=location)
    o = bpy.context.active_object
    o.name = name
    o.scale = scale
    if mat:
        o.data.materials.append(mat)
    bpy.ops.object.shade_smooth()
    return o


def add_ico(name, radius=1.0, location=(0, 0, 0), subdiv=2, mat=None, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_ico_sphere_add(radius=radius, subdivisions=subdiv, location=location)
    o = bpy.context.active_object
    o.name = name
    o.scale = scale
    if mat:
        o.data.materials.append(mat)
    return o


def add_cylinder(name, radius=0.5, depth=1.0, location=(0, 0, 0), rotation=(0, 0, 0), verts=16, mat=None, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_cylinder_add(radius=radius, depth=depth, location=location, rotation=rotation, vertices=verts)
    o = bpy.context.active_object
    o.name = name
    o.scale = scale
    if mat:
        o.data.materials.append(mat)
    return o


def add_cone(name, r1=0.5, r2=0.0, depth=1.0, location=(0, 0, 0), rotation=(0, 0, 0), verts=12, mat=None):
    bpy.ops.mesh.primitive_cone_add(radius1=r1, radius2=r2, depth=depth, location=location, rotation=rotation, vertices=verts)
    o = bpy.context.active_object
    o.name = name
    if mat:
        o.data.materials.append(mat)
    return o


def add_torus(name, major=1.0, minor=0.25, location=(0, 0, 0), rotation=(0, 0, 0), mat=None, seg_major=24, seg_minor=12):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, location=location, rotation=rotation, major_segments=seg_major, minor_segments=seg_minor)
    o = bpy.context.active_object
    o.name = name
    if mat:
        o.data.materials.append(mat)
    bpy.ops.object.shade_smooth()
    return o


def add_box(name, size=(1, 1, 1), location=(0, 0, 0), rotation=(0, 0, 0), mat=None, bevel=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location, rotation=rotation)
    o = bpy.context.active_object
    o.name = name
    o.scale = size
    if mat:
        o.data.materials.append(mat)
    if bevel > 0:
        m = o.modifiers.new("Bevel", "BEVEL")
        m.width = bevel
        m.segments = 3
    return o


def add_empty(name, location=(0, 0, 0), rotation=(0, 0, 0)):
    o = bpy.data.objects.new(name, None)
    o.location = location
    o.rotation_euler = rotation
    o.empty_display_type = "ARROWS"
    o.empty_display_size = 0.5
    link(o)
    return o


def eyes(parent_name, pos_y, z, spacing=0.3, r=0.12, pupil=0.06, x_center=0.0, look=(0, 1, 0)):
    """白目＋黒目。前（+Y）を向く。戻り値は [obj, ...]"""
    white = material("EyeWhite", (1, 1, 1), roughness=0.3)
    black = material("EyeBlack", (0.08, 0.08, 0.12), roughness=0.3)
    objs = []
    for i, sx in enumerate((-1, 1)):
        e = add_sphere(f"{parent_name}_eye{i}", r, (x_center + sx * spacing, pos_y, z), 12, 8, white)
        p = add_sphere(f"{parent_name}_pupil{i}", pupil, (x_center + sx * spacing, pos_y + r * 0.75, z + r * 0.1), 10, 6, black)
        objs += [e, p]
    return objs


def smile(parent_name, pos_y, z, width=0.3, mat=None, thickness=0.04):
    """にっこり口（トーラスの下半分を使う）。"""
    mat = mat or material("Mouth", (0.5, 0.1, 0.2))
    t = add_torus(f"{parent_name}_smile", width, thickness, (0, pos_y, z), (math.radians(90), 0, 0), mat, 20, 8)
    # 上半分を削る
    set_active(t)
    bm = bmesh.new()
    bm.from_mesh(t.data)
    for v in list(bm.verts):
        if v.co.z > 0.02:
            bm.verts.remove(v)
    bm.to_mesh(t.data)
    bm.free()
    return t


def join(objs, name):
    """複数オブジェクトを 1 つに結合して名前をつける。"""
    objs = [o for o in objs if o is not None]
    if len(objs) == 1:
        objs[0].name = name
        objs[0].data.name = name
        return objs[0]
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    o = bpy.context.active_object
    o.name = name
    o.data.name = name
    return o


def displace_noise(obj, strength=0.15, scale=1.5, seed=0):
    """ざらっとした有機的な表面にする。"""
    tex = bpy.data.textures.new(f"noise_{obj.name}_{seed}", "CLOUDS")
    tex.noise_scale = scale
    tex.noise_depth = 2
    m = obj.modifiers.new("Displace", "DISPLACE")
    m.texture = tex
    m.strength = strength
    m.mid_level = 0.5
    m.texture_coords = "GLOBAL"
    return m


def subdivide(obj, levels=1):
    m = obj.modifiers.new("Subd", "SUBSURF")
    m.levels = levels
    m.render_levels = levels
    return m


def flip_normals(obj):
    set_active(obj)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    for f in bm.faces:
        f.normal_flip()
    bm.to_mesh(obj.data)
    bm.free()


def recalc_normals(obj, inside=False):
    set_active(obj)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.normals_make_consistent(inside=inside)
    bpy.ops.object.mode_set(mode="OBJECT")


# ------------------------------------------------------------------ 書き出し
def export_glb(objs, rel_path: str, apply=True) -> str:
    """選択したオブジェクトを GLB に書き出す。rel_path は models/ からの相対（拡張子なし）。"""
    path = os.path.join(MODELS_DIR, rel_path + ".glb")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
        for c in o.children_recursive:
            c.select_set(True)
    kwargs = dict(filepath=path, export_format="GLB", use_selection=True, export_apply=apply,
                  export_yup=True, export_animations=False, export_skins=False, export_lights=False, export_cameras=False)
    try:
        bpy.ops.export_scene.gltf(**kwargs)
    except TypeError:
        kwargs.pop("export_lights", None)
        kwargs.pop("export_cameras", None)
        bpy.ops.export_scene.gltf(**kwargs)
    size = os.path.getsize(path)
    print(f"  -> {os.path.relpath(path, ROOT)}  ({size / 1024:.0f} KB)")
    return path


def save_blend(name: str) -> None:
    os.makedirs(BLEND_DIR, exist_ok=True)
    path = os.path.join(BLEND_DIR, name + ".blend")
    bpy.ops.wm.save_as_mainfile(filepath=path, compress=True)

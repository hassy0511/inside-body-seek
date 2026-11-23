"""ステージを「式から 直接」作る ときの 道具（numpy で 点を 計算して メッシュに する）。

blender/stage_mouth.py が 使う。ほかの 場所を 同じ 作りに 直す ときも ここを 使う。

・面の 名前（マテリアル名）は 役わりで つける：StageFloor / StageWall / StageGum / StageTooth / StageSoft / StageLip / StageSky。
  Godot 側（src/level/stage_look.gd）が この 名前を 見て、色・画像（tex_<場所>_<役わり>.png）・光りかたを 決める。
・頂点カラーは「かげの 倍率」（1 = そのまま、小さいほど 暗い）。色そのものは Godot 側の 設定と 画像が 持つ。
  倍率は 画面の 色（sRGB の 数字）に そのまま かかる：この ゲームの 描画（Compatibility）は 色の 計算を
  画面の 色の まま 行う（はかって 確かめた）。だから「この 色に 見せたい」ときは sRGB の 数字の 割り算で 出す（ratio）。
  形が くっつく ところの やわらかい 暗さ（bake_ao）と、奥へ 行くほど 暗く なる 段（かべの わ）を ここに 焼きこむ。
・UV は 1 = 4 m（発注書の「1 枚 = 4 m 四方」）。Godot 側は 世界座標の 3 方向投影を 使うので、UV は 予備。
"""
from __future__ import annotations

import math

import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

try:
    from . import common as C
except ImportError:
    import os
    import sys
    sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    from blender import common as C

COLOR_NAME = "Col"
TILE_M = 4.0


# ------------------------------------------------------------------ 数
def sstep(e0, e1, x):
    """なめらかな 段（0→1）"""
    t = np.clip((np.asarray(x, dtype=float) - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def pchip(table):
    """(x, 値) の 表を なめらかに つなぐ 関数を 返す（行きすぎない 3 次：Fritsch–Carlson）。表の 外は はしの 値。"""
    xs = np.array([p[0] for p in table], dtype=float)
    ys = np.array([p[1] for p in table], dtype=float)
    h = np.diff(xs)
    d = np.diff(ys) / h
    m = np.zeros_like(xs)
    m[0], m[-1] = d[0], d[-1]
    for i in range(1, len(xs) - 1):
        if d[i - 1] * d[i] > 0:
            w1, w2 = 2 * h[i] + h[i - 1], h[i] + 2 * h[i - 1]
            m[i] = (w1 + w2) / (w1 / d[i - 1] + w2 / d[i])

    def f(x):
        x = np.asarray(x, dtype=float)
        xc = np.clip(x, xs[0], xs[-1])
        i = np.clip(np.searchsorted(xs, xc, side="right") - 1, 0, len(xs) - 2)
        t = (xc - xs[i]) / h[i]
        t2, t3 = t * t, t * t * t
        return ((2 * t3 - 3 * t2 + 1) * ys[i] + (t3 - 2 * t2 + t) * h[i] * m[i]
                + (-2 * t3 + 3 * t2) * ys[i + 1] + (t3 - t2) * h[i] * m[i + 1])
    return f


def spow(v, e):
    """符号つきの べき（だ円を 四角っぽく する ときに 使う）"""
    return np.sign(v) * np.abs(v) ** e


def rgb(hex_color):
    """#RRGGBB → 0〜1 の RGB（画面の 色＝sRGB の 数字の まま。numpy）"""
    s = hex_color.lstrip("#")
    return np.array([int(s[i:i + 2], 16) for i in (0, 2, 4)], dtype=float) / 255.0


def linear(hex_color):
    """#RRGGBB → リニアの RGB（Blender の マテリアル用）"""
    c = rgb(hex_color)
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def ratio(dark_hex, base_hex):
    """base の 色の 面を dark の 色に 見せる ための 倍率"""
    return rgb(dark_hex) / rgb(base_hex)


# ------------------------------------------------------------------ マテリアル
def surface_material(name, hex_color, roughness=0.9, emission=None):
    """役わりの 名前の マテリアル。頂点カラー（倍率）× 色 を ベースカラーに つなぐ（GLB に COLOR_0 が 入る）。"""
    mat = bpy.data.materials.get(name)
    if mat is not None:
        return mat
    rgb = linear(hex_color)
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Base Color"].default_value = (rgb[0], rgb[1], rgb[2], 1.0)
    if emission is not None:
        e = linear(emission)
        bsdf.inputs["Emission Color"].default_value = (e[0], e[1], e[2], 1.0)
        bsdf.inputs["Emission Strength"].default_value = 1.0
    attr = nt.nodes.new("ShaderNodeVertexColor")
    attr.layer_name = COLOR_NAME
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.blend_type = "MULTIPLY"
    mix.inputs[0].default_value = 1.0
    mix.inputs[6].default_value = (rgb[0], rgb[1], rgb[2], 1.0)
    nt.links.new(attr.outputs["Color"], mix.inputs[7])
    nt.links.new(mix.outputs[2], bsdf.inputs["Base Color"])
    mat.diffuse_color = (rgb[0], rgb[1], rgb[2], 1.0)
    mat.use_backface_culling = True
    return mat


# ------------------------------------------------------------------ メッシュ
def grid_faces(nv, nu, wrap_u=False, wrap_v=False):
    """nv 行 × nu 列の 点の 格子を 四角形で つなぐ（番号は 行 × nu ＋ 列）"""
    iu = np.arange(nu if wrap_u else nu - 1)
    iv = np.arange(nv if wrap_v else nv - 1)
    a, b = np.meshgrid(iv, iu, indexing="ij")
    a2, b2 = (a + 1) % nv, (b + 1) % nu
    return np.stack([a * nu + b, a * nu + b2, a2 * nu + b2, a2 * nu + b], axis=-1).reshape(-1, 4)


def mesh_object(name, verts, faces, mat, location=(0.0, 0.0, 0.0)):
    """点（N×3）と 面（M×4 または M×3）から オブジェクトを 作る。なめらかな 陰影。"""
    verts = np.asarray(verts, dtype=float)
    faces = np.asarray(faces, dtype=np.int64)
    me = bpy.data.meshes.new(name)
    n = faces.shape[1]
    me.vertices.add(len(verts))
    me.vertices.foreach_set("co", (verts - np.array(location)).ravel())
    me.loops.add(faces.size)
    me.loops.foreach_set("vertex_index", faces.ravel())
    me.polygons.add(len(faces))
    me.polygons.foreach_set("loop_start", np.arange(0, faces.size, n))
    me.polygons.foreach_set("loop_total", np.full(len(faces), n))
    me.polygons.foreach_set("use_smooth", np.ones(len(faces), dtype=bool))
    me.update(calc_edges=True)
    me.validate()
    me.materials.append(mat)
    ob = bpy.data.objects.new(name, me)
    ob.location = location
    C.link(ob)
    return ob


def world_verts(ob):
    me = ob.data
    co = np.empty(len(me.vertices) * 3)
    me.vertices.foreach_get("co", co)
    return co.reshape(-1, 3) + np.array(ob.location)


def vertex_normals(ob):
    me = ob.data
    no = np.empty(len(me.vertices) * 3)
    me.vertices.foreach_get("normal", no)
    return no.reshape(-1, 3)


def faces_of(ob):
    return [tuple(p.vertices) for p in ob.data.polygons]


def face_toward(ob, direction_fn):
    """面の 向きを そろえる：direction_fn(面の 中心 N×3) が 返す 向きと 逆を 向いた 面が 多ければ 全部 うらがえす。
    （格子は 全部 同じ 回りなので、多数決で 足りる）"""
    me = ob.data
    n = len(me.polygons)
    cen = np.empty(n * 3)
    nor = np.empty(n * 3)
    me.polygons.foreach_get("center", cen)
    me.polygons.foreach_get("normal", nor)
    cen = cen.reshape(-1, 3) + np.array(ob.location)
    want = direction_fn(cen)
    if float(np.sum(np.einsum("ij,ij->i", nor.reshape(-1, 3), want))) < 0:
        me.flip_normals()
        me.update()
    return ob


def set_uv(ob, uv_per_vertex):
    """頂点ごとの UV（N×2、1 = 4 m）を 入れる"""
    me = ob.data
    layer = me.uv_layers.new(name="UVMap")
    idx = np.empty(len(me.loops), dtype=np.int64)
    me.loops.foreach_get("vertex_index", idx)
    layer.data.foreach_set("uv", np.asarray(uv_per_vertex, dtype=float)[idx].ravel())


def set_colors(ob, rgb):
    """頂点カラー（N×3、リニアの 倍率）を 入れる"""
    me = ob.data
    attr = me.color_attributes.get(COLOR_NAME) or me.color_attributes.new(COLOR_NAME, "FLOAT_COLOR", "POINT")
    rgba = np.concatenate([np.clip(rgb, 0.0, 1.0), np.ones((len(rgb), 1))], axis=1)
    attr.data.foreach_set("color", rgba.ravel())
    me.color_attributes.active_color = attr
    me.color_attributes.render_color_index = list(me.color_attributes).index(attr)


def get_colors(ob):
    attr = ob.data.color_attributes.get(COLOR_NAME)
    out = np.empty(len(ob.data.vertices) * 4)
    attr.data.foreach_get("color", out)
    return out.reshape(-1, 4)[:, :3]


def triangle_count(objs):
    return sum(len(p.vertices) - 2 for o in objs if o.type == "MESH" for p in o.data.polygons)


# ------------------------------------------------------------------ 形
def superellipsoid(nu=28, nv=18, e_xy=0.6, e_z=0.7):
    """まるい 箱（スーパーだ円体）の 単位の 点と 面。e が 小さいほど 四角い（1 = 球）。
    返す 点は −1〜1 の 箱の 中。面は 外向き。"""
    lat = np.linspace(-math.pi / 2, math.pi / 2, nv)[1:-1]
    lon = np.linspace(0, 2 * math.pi, nu, endpoint=False)
    la, lo = np.meshgrid(lat, lon, indexing="ij")
    x = spow(np.cos(la), e_z) * spow(np.cos(lo), e_xy)
    y = spow(np.cos(la), e_z) * spow(np.sin(lo), e_xy)
    z = spow(np.sin(la), e_z)
    body = np.stack([x, y, z], axis=-1).reshape(-1, 3)
    verts = np.concatenate([body, [[0, 0, -1.0]], [[0, 0, 1.0]]])
    rows = nv - 2
    quads = grid_faces(rows, nu, wrap_u=True)
    south, north = len(body), len(body) + 1
    tris = []
    for j in range(nu):
        j2 = (j + 1) % nu
        tris.append((south, j2, j))
        tris.append((north, (rows - 1) * nu + j, (rows - 1) * nu + j2))
    return verts, quads, np.array(tris)


def blob_object(name, verts, quads, tris, mat, location=(0.0, 0.0, 0.0)):
    """superellipsoid() の 点（変形ずみ）から オブジェクトを 作る（四角形と 三角形が まざる）"""
    me = bpy.data.meshes.new(name)
    faces = [tuple(q) for q in quads] + [tuple(t) for t in tris]
    me.from_pydata([tuple(v) for v in (np.asarray(verts) - np.array(location))], [], faces)
    me.polygons.foreach_set("use_smooth", np.ones(len(faces), dtype=bool))
    me.update()
    me.materials.append(mat)
    ob = bpy.data.objects.new(name, me)
    ob.location = location
    C.link(ob)
    return ob


def join_meshes(objs, name):
    """同じ 役わりの オブジェクトを 1 つに する（頂点カラーは のこる）。原点は そのまま 0。"""
    for o in objs:
        C.set_active(o)
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if len(objs) > 1:
        bpy.ops.object.select_all(action="DESELECT")
        for o in objs:
            o.select_set(True)
        bpy.context.view_layer.objects.active = objs[0]
        bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active if len(objs) > 1 else objs[0]
    o.name = name
    o.data.name = name
    return o


# ------------------------------------------------------------------ かげの 焼きこみ
def _hemisphere(n):
    """上半球の 向き（cos で 重みづけ：まっすぐ 上が 多い）。いつも 同じ 並び。"""
    out = []
    golden = math.pi * (3.0 - math.sqrt(5.0))
    for i in range(n):
        u = (i + 0.5) / n
        r = math.sqrt(u)
        t = i * golden
        out.append((r * math.cos(t), r * math.sin(t), math.sqrt(1.0 - u)))
    return np.array(out)


def bake_ao(objs, reach=5.0, rays=24, smooth=2, exclude=()):
    """形が 近くに ある ところを 暗く する（アンビエントオクルージョン）を 頂点ごとに 計算して 返す。
    {オブジェクト名: N 個の 0〜1（1 = ひらけて いる）}。reach m より 遠い 形は 数えない。
    exclude の 名前の オブジェクトは かげを 落とさない（光る「おそと」など）。"""
    verts, polys, base = [], [], 0
    for o in objs:
        if o.name in exclude:
            continue
        v = world_verts(o)
        verts.extend(map(tuple, v))
        polys.extend(tuple(i + base for i in p) for p in faces_of(o))
        base += len(v)
    bvh = BVHTree.FromPolygons(verts, polys, epsilon=0.0)
    hemi = _hemisphere(rays)
    out = {}
    for o in objs:
        v = world_verts(o)
        n = vertex_normals(o)
        # 法線を Z に する 基底
        ref = np.where(np.abs(n[:, 2:3]) < 0.9, np.array([[0.0, 0.0, 1.0]]), np.array([[1.0, 0.0, 0.0]]))
        t = np.cross(ref, n)
        t /= np.maximum(np.linalg.norm(t, axis=1, keepdims=True), 1e-9)
        b = np.cross(n, t)
        ao = np.ones(len(v))
        for i in range(len(v)):
            origin = Vector(v[i] + n[i] * 0.05)
            occ = 0.0
            dirs = hemi[:, 0:1] * t[i] + hemi[:, 1:2] * b[i] + hemi[:, 2:3] * n[i]
            for d in dirs.tolist():
                hit = bvh.ray_cast(origin, d, reach)
                if hit[0] is not None:
                    f = 1.0 - hit[3] / reach
                    occ += f * f
            ao[i] = 1.0 - occ / rays
        # となりの 頂点と ならす（つぶつぶを 消す）
        if smooth > 0:
            me = o.data
            e = np.empty(len(me.edges) * 2, dtype=np.int64)
            me.edges.foreach_get("vertices", e)
            e = e.reshape(-1, 2)
            for _ in range(smooth):
                acc = ao.copy()
                cnt = np.ones(len(ao))
                np.add.at(acc, e[:, 0], ao[e[:, 1]])
                np.add.at(acc, e[:, 1], ao[e[:, 0]])
                np.add.at(cnt, e[:, 0], 1)
                np.add.at(cnt, e[:, 1], 1)
                ao = acc / cnt
        out[o.name] = ao
    return out


def shade(ao, dark, power=1.0, floor=0.0):
    """ao（0〜1）を 色の 倍率（N×3）に する。暗い ところは dark（倍率の RGB）へ 寄る＝赤みを のこして 暗く なる。"""
    a = np.clip((np.asarray(ao) - floor) / (1.0 - floor), 0.0, 1.0) ** power
    dark = np.asarray(dark, dtype=float)
    return dark[None, :] + (1.0 - dark[None, :]) * a[:, None]

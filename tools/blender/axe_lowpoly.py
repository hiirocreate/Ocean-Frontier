"""Ocean Frontier: LAST TIDE — ゲームアイテム「斧」（scrap_axe）のローポリ3Dモデル生成スクリプト

使い方:
  Blender の Scripting タブに貼り付けて「Run Script」。
  コマンドライン: blender --background --python tools/blender/axe_lowpoly.py -- --export assets/items/models/axe.glb

仕様:
  - 木製の柄（円柱 10 セグメント）＋金属くずを叩き出した無骨な斧頭（変形した直方体と楔）＋革の巻き＋リベット
  - 全体 150〜200 三角形（実行時に数えて検証し、超えたらエラー）
  - マテリアル: 木 #8B4513 / 刃 #708090（＋巻き革 #4A3426）をベース色で自動生成して割り当て
  - 原点は柄の下端、+Z が上、刃は -Y 側（Godot へは glTF で +Y アップに変換される）
  - セル調の陰影と輪郭線はゲーム側の assets/shaders/toon_cel.gdshader / toon_outline.gdshader で付ける
独自制作（CC0扱い）。
"""
import sys

import bpy  # bpy を先に読み込む（pip 版 bpy では bmesh が bpy 経由で使えるようになる）
import bmesh
from mathutils import Vector

NAME = "Axe"
MAX_TRIS = 200
SEGMENTS = 10  # 円柱の分割数（仕様上限 12）

COLORS = {
    "Axe_Wood": "#8B4513",
    "Axe_Blade": "#708090",
    "Axe_Wrap": "#4A3426",
}


def srgb_to_linear(c: float) -> float:
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hex_rgba(h: str) -> tuple:
    h = h.lstrip("#")
    return tuple(srgb_to_linear(int(h[i:i + 2], 16) / 255.0) for i in (0, 2, 4)) + (1.0,)


def make_material(name: str, hex_color: str, metallic: float, roughness: float) -> bpy.types.Material:
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    if bsdf is None:
        nt.nodes.clear()
        bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
        out = nt.nodes.new("ShaderNodeOutputMaterial")
        nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    rgba = hex_rgba(hex_color)
    bsdf.inputs["Base Color"].default_value = rgba
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    mat.diffuse_color = rgba  # ソリッド表示でも同じ色
    return mat


def add_prism(bm, mat_index, segments, radius_bottom, radius_top, z0, z1, cap_bottom=True, cap_top=True, cx=0.0, cy=0.0):
    """円柱／円錐台（側面と蓋）を追加し、作った頂点を返す。三角形数 = 側面 2n + 蓋 (n-2)"""
    import math
    bottom, top = [], []
    for i in range(segments):
        a = 2 * math.pi * i / segments
        bottom.append(bm.verts.new((cx + radius_bottom * math.cos(a), cy + radius_bottom * math.sin(a), z0)))
        top.append(bm.verts.new((cx + radius_top * math.cos(a), cy + radius_top * math.sin(a), z1)))
    faces = []
    for i in range(segments):
        j = (i + 1) % segments
        faces.append(bm.faces.new((bottom[i], bottom[j], top[j], top[i])))
    if cap_bottom:
        faces.append(bm.faces.new(list(reversed(bottom))))
    if cap_top:
        faces.append(bm.faces.new(top))
    for f in faces:
        f.material_index = mat_index
    return bottom + top


def add_box(bm, mat_index, verts8):
    """8頂点（下面4→上面4、反時計回り）から六面体"""
    v = [bm.verts.new(p) for p in verts8]
    idx = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
    faces = [bm.faces.new([v[i] for i in f]) for f in idx]
    for f in faces:
        f.material_index = mat_index
    return faces


def build_axe() -> bpy.types.Object:
    old = bpy.data.objects.get(NAME)
    if old:
        bpy.data.objects.remove(old, do_unlink=True)
    mats = [
        make_material("Axe_Wood", COLORS["Axe_Wood"], 0.0, 0.85),
        make_material("Axe_Blade", COLORS["Axe_Blade"], 0.6, 0.55),
        make_material("Axe_Wrap", COLORS["Axe_Wrap"], 0.0, 0.9),
    ]
    WOOD, BLADE, WRAP = 0, 1, 2
    bm = bmesh.new()

    # 1) 木製の柄: 少し先細り（下 2.6cm → 上 2.2cm）、長さ 62cm
    add_prism(bm, WOOD, SEGMENTS, 0.026, 0.022, 0.0, 0.62)
    # 柄尻のこぶ（滑り止め）
    add_prism(bm, WOOD, SEGMENTS, 0.022, 0.032, -0.035, 0.0, cap_top=False)

    # 2) 握りの革巻き（柄よりわずかに太い円柱）
    add_prism(bm, WRAP, SEGMENTS, 0.030, 0.030, 0.06, 0.20)

    # 3) 斧頭の本体（金属くずを叩いて四角く固めた塊）: 柄の上端を包む
    add_box(bm, BLADE, [
        (-0.034, -0.040, 0.50), (0.034, -0.040, 0.50), (0.034, 0.045, 0.50), (-0.034, 0.045, 0.50),
        (-0.030, -0.036, 0.62), (0.030, -0.036, 0.62), (0.030, 0.041, 0.62), (-0.030, 0.041, 0.62),
    ])
    # 4) 刃（-Y 側へ伸びる楔。刃先は上下に広がり、厚みはゼロ近くまで薄くなる）
    blade = [bm.verts.new(p) for p in [
        (-0.026, -0.040, 0.505), (0.026, -0.040, 0.505), (0.026, -0.040, 0.615), (-0.026, -0.040, 0.615),  # 付け根
        (-0.012, -0.125, 0.470), (0.012, -0.125, 0.470), (0.012, -0.125, 0.640), (-0.012, -0.125, 0.640),  # 中ほど
        (0.0, -0.175, 0.430), (0.0, -0.182, 0.555), (0.0, -0.172, 0.680),  # 刃先（欠けのある不揃いな刃）
    ]]
    b = blade
    blade_faces = [
        (b[0], b[1], b[5], b[4]), (b[1], b[2], b[6], b[5]), (b[2], b[3], b[7], b[6]), (b[3], b[0], b[4], b[7]),
        (b[4], b[5], b[8]), (b[5], b[9], b[8]), (b[5], b[6], b[9]), (b[6], b[10], b[9]),
        (b[7], b[4], b[8]), (b[7], b[8], b[9]), (b[7], b[9], b[10]),
        (b[6], b[7], b[10]),
    ]
    for f in blade_faces:
        bm.faces.new(f).material_index = BLADE
    # 5) 背側のハンマー面（短い角柱）
    add_box(bm, BLADE, [
        (-0.026, 0.045, 0.515), (0.026, 0.045, 0.515), (0.026, 0.085, 0.522), (-0.026, 0.085, 0.522),
        (-0.024, 0.045, 0.605), (0.024, 0.045, 0.605), (0.024, 0.085, 0.598), (-0.024, 0.085, 0.598),
    ])
    # 6) 留めのリベット（左右に1つずつ、4角錐台）
    for sx in (-1, 1):
        for v in add_prism(bm, BLADE, 4, 0.010, 0.006, 0.0, 0.010, cap_bottom=False):
            # Z方向に作った小さな角錐台を X 方向へ倒して斧頭の側面へ移動
            x, y, z = v.co
            v.co = Vector((sx * (0.034 + z), y, 0.56 + x))

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    tris = len(bm.faces)

    mesh = bpy.data.meshes.new(NAME)
    bm.to_mesh(mesh)
    bm.free()
    for m in mats:
        mesh.materials.append(m)
    obj = bpy.data.objects.new(NAME, mesh)
    bpy.context.scene.collection.objects.link(obj)
    for p in mesh.polygons:
        p.use_smooth = False  # ローポリのフラットシェーディング
    if tris > MAX_TRIS:
        raise RuntimeError(f"三角形数 {tris} が上限 {MAX_TRIS} を超えています")
    print(f"[axe] 三角形数 = {tris} / 上限 {MAX_TRIS}, 頂点数 = {len(mesh.vertices)}, マテリアル = {[m.name for m in mats]}")
    return obj


def main() -> None:
    obj = build_axe()
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if "--export" in argv:
        path = argv[argv.index("--export") + 1]
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.export_scene.gltf(filepath=path, use_selection=True, export_format="GLB", export_apply=True)
        print(f"[axe] 書き出し: {path}")


if __name__ == "__main__":
    main()

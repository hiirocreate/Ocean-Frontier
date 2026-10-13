"""画像から生成した3Dキャラクター（TripoSR の頂点カラー付きメッシュ）をゲーム用に仕上げる Blender スクリプト。

処理: 読み込み → 向きと身長を正規化 → 軽量化（Android 向けに三角形数を削減）→ 人型の骨を自動配置
      → 自動ウェイト → 待機・歩行・作業・休憩のアニメーションを作成 → glb 書き出し（頂点カラー COLOR_0）

使い方（Blender 本体または pip の bpy）:
  blender --background --python tools/blender/rig_generated_character.py -- <入力.glb> <出力.glb> [--tris 5000] [--height 1.85] [--face -90]
独自制作（CC0扱い）。
"""
import math
import sys

import bpy  # pip 版 bpy では bmesh より先に読み込む
import bmesh
from mathutils import Matrix, Vector

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def arg(name: str, default: float) -> float:
    return float(ARGS[ARGS.index(name) + 1]) if name in ARGS else default


SRC, DST = ARGS[0], ARGS[1]
TARGET_TRIS = int(arg("--tris", 5000))
HEIGHT = arg("--height", 1.85)  # 既存の CharacterModel とほぼ同じ高さ（m）
FACE_ROT = arg("--face", -90.0)  # 正面を Godot の +Z（既存モデルと同じ向き）に合わせる回転（度、Z軸回り）

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
for o in bpy.context.scene.objects:
    o.select_set(o in meshes)
bpy.context.view_layer.objects.active = meshes[0]
if len(meshes) > 1:
    bpy.ops.object.join()
obj = bpy.context.view_layer.objects.active
obj.name = "Body"
# 親（空のノード）を外して変形を適用
bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
for o in list(bpy.context.scene.objects):
    if o.type != "MESH":
        bpy.data.objects.remove(o, do_unlink=True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

# ---- 向きの正規化 ----
# TripoSR の出力は「+Z が上・入力画像のカメラ（人物の正面）が +X」の座標で、glTF としては Y-up と解釈される。
# Blender に読み込むと上が -Y、正面が +X になるので、X 軸回りに -90° で起こし、Z 軸回りに -90° で正面を -Y
# （glTF/Godot の +Z、既存の CharacterModel と同じ向き）へ向ける。
me = obj.data
me.transform(Matrix.Rotation(-math.pi / 2, 4, "X"))
me.transform(Matrix.Rotation(math.radians(FACE_ROT), 4, "Z"))
# 足元を原点に、身長を HEIGHT に
co = [v.co.copy() for v in me.vertices]
mins = Vector((min(c[i] for c in co) for i in range(3)))
maxs = Vector((max(c[i] for c in co) for i in range(3)))
s = HEIGHT / (maxs.z - mins.z)
center = (mins + maxs) / 2
for v in me.vertices:
    v.co = Vector(((v.co.x - center.x) * s, (v.co.y - center.y) * s, (v.co.z - mins.z) * s))

# ---- 軽量化 ----
tris = sum(len(p.vertices) - 2 for p in me.polygons)
if tris > TARGET_TRIS:
    dec = obj.modifiers.new("Decimate", "DECIMATE")
    dec.ratio = TARGET_TRIS / tris
    bpy.ops.object.modifier_apply(modifier=dec.name)
bm = bmesh.new()
bm.from_mesh(me)
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])  # 等値面抽出の向きの揺れを直し、法線を外向きに揃える
bmesh.ops.triangulate(bm, faces=bm.faces[:])
bm.to_mesh(me)
bm.free()
for p in me.polygons:
    p.use_smooth = True
tris = len(me.polygons)

# ---- 人型の骨（身長比で配置）----
H = HEIGHT
co = [v.co.copy() for v in me.vertices]


def x_extent(z0: float, band: float = 0.03) -> tuple:
    xs = [c.x for c in co if abs(c.z - z0) < H * band]
    return (min(xs), max(xs)) if xs else (-0.1, 0.1)


hip = max(abs(v) for v in x_extent(H * 0.45)) * 0.45
# 画像から作ったメッシュは腕が胴体とつながっていることが多く、腕の骨を動かすと胴体が引き伸ばされる。
# そのため腕は胴体と一体（chest に追従）とし、動きは脚・腰・胴・頭で表現する。
BONES = [  # 名前, 親, 根元, 先端
    ("hips", None, (0, 0, H * 0.50), (0, 0, H * 0.58)),
    ("spine", "hips", (0, 0, H * 0.58), (0, 0, H * 0.72)),
    ("chest", "spine", (0, 0, H * 0.72), (0, 0, H * 0.82)),
    ("neck", "chest", (0, 0, H * 0.82), (0, 0, H * 0.86)),
    ("head", "neck", (0, 0, H * 0.86), (0, 0, H * 1.0)),
]
for side, sx in (("L", 1), ("R", -1)):
    BONES += [
        (f"thigh.{side}", "hips", (sx * hip, 0, H * 0.50), (sx * hip, 0, H * 0.27)),
        (f"shin.{side}", f"thigh.{side}", (sx * hip, 0, H * 0.27), (sx * hip, 0, H * 0.04)),
    ]

arm_data = bpy.data.armatures.new("Rig")
rig = bpy.data.objects.new("Rig", arm_data)
bpy.context.scene.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode="EDIT")
for n, p, a, b in BONES:
    eb = arm_data.edit_bones.new(n)
    eb.head, eb.tail = Vector(a), Vector(b)
    eb.align_roll(Vector((0, -1, 0)))  # 全ての骨で「X軸回りの正の回転＝前方へ」になるようロールを揃える
    if p:
        eb.parent = arm_data.edit_bones[p]
        eb.use_connect = (Vector(a) - arm_data.edit_bones[p].tail).length < 1e-4
bpy.ops.object.mode_set(mode="OBJECT")

# 自動ウェイト（失敗したら最も近い骨への割り当てで代用）
bpy.ops.object.select_all(action="DESELECT")
obj.select_set(True)
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
try:
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    ok = all(len(v.groups) > 0 for v in me.vertices[:200])
except RuntimeError:
    ok = False
if not ok:
    bpy.ops.object.parent_set(type="ARMATURE_NAME")
    segs = [(n, Vector(a), Vector(b)) for n, p, a, b in BONES]
    for v in me.vertices:
        best = min(segs, key=lambda sg: (v.co - (sg[1] + (sg[2] - sg[1]) * max(0.0, min(1.0, (v.co - sg[1]).dot(sg[2] - sg[1]) / max((sg[2] - sg[1]).length_squared, 1e-8))))).length)
        obj.vertex_groups[best[0]].add([v.index], 1.0, "REPLACE")
print(f"[rig] auto_weights={'ok' if ok else 'fallback'}")


# ---- アニメーション ----
def key(action_name: str, frames: dict, length: int) -> None:
    """frames: {bone: [(frame, (x, y, z) 度), ...]}。ループさせるため最後に先頭のキーを複製する"""
    act = bpy.data.actions.new(action_name)
    rig.animation_data_create()
    rig.animation_data.action = act
    for pb in rig.pose.bones:
        pb.rotation_mode = "XYZ"
        pb.rotation_euler = (0, 0, 0)
        pb.location = (0, 0, 0)
    for bone, ks in frames.items():
        pb = rig.pose.bones[bone]
        for f, rot in ks + [(length, ks[0][1])]:
            if bone == "hips" and len(rot) == 4:  # hips は (x, y, z, 上下の移動)
                pb.location = (0, rot[3], 0)
                pb.keyframe_insert("location", frame=f)
                rot = rot[:3]
            pb.rotation_euler = tuple(math.radians(r) for r in rot)
            pb.keyframe_insert("rotation_euler", frame=f)
    act.use_fake_user = True
    rig.animation_data.action = None


key("idle", {
    "chest": [(1, (2, 0, 0)), (30, (-1, 0, 0))],
    "head": [(1, (0, 0, 2)), (30, (2, 0, -2))],
}, 60)
key("walk", {
    "thigh.L": [(1, (25, 0, 0)), (11, (-25, 0, 0))],
    "thigh.R": [(1, (-25, 0, 0)), (11, (25, 0, 0))],
    "shin.L": [(1, (0, 0, 0)), (6, (-30, 0, 0)), (11, (0, 0, 0)), (16, (-5, 0, 0))],
    "shin.R": [(1, (0, 0, 0)), (6, (-5, 0, 0)), (11, (0, 0, 0)), (16, (-30, 0, 0))],
    "hips": [(1, (0, 3, 0, 0.0)), (6, (0, 0, 0, 0.025)), (11, (0, -3, 0, 0.0)), (16, (0, 0, 0, 0.025))],
    "spine": [(1, (4, 0, 0)), (11, (4, 0, 0))],
    "chest": [(1, (0, -5, 0)), (11, (0, 5, 0))],
}, 20)
# 前かがみで作業する（上下に体を揺らす）
key("work", {
    "spine": [(1, (14, 0, 0)), (8, (26, 0, 0))],
    "chest": [(1, (6, 0, 0)), (8, (12, 0, 0))],
    "head": [(1, (8, 0, 0)), (8, (4, 0, 0))],
    "thigh.L": [(1, (12, 0, 0)), (8, (18, 0, 0))],
    "thigh.R": [(1, (12, 0, 0)), (8, (18, 0, 0))],
    "shin.L": [(1, (-14, 0, 0)), (8, (-22, 0, 0))],
    "shin.R": [(1, (-14, 0, 0)), (8, (-22, 0, 0))],
    "hips": [(1, (0, 0, 0, -0.02)), (8, (0, 0, 0, -0.05))],
}, 16)
# 床に腰を下ろして膝を立てる
key("rest", {
    "hips": [(1, (0, 0, 0, -0.30)), (40, (0, 0, 0, -0.30))],
    "thigh.L": [(1, (85, 0, 0)), (40, (85, 0, 0))],
    "thigh.R": [(1, (85, 0, 0)), (40, (85, 0, 0))],
    "shin.L": [(1, (-85, 0, 0)), (40, (-85, 0, 0))],
    "shin.R": [(1, (-85, 0, 0)), (40, (-85, 0, 0))],
    "chest": [(1, (6, 0, 0)), (40, (9, 0, 0))],
    "head": [(1, (8, 0, 0)), (40, (12, 0, 0))],
}, 80)

# 頂点カラーをそのまま使う単純なマテリアル（ゲーム側でトゥーンに置き換える）
mat = bpy.data.materials.new("Body")
mat.use_nodes = True
nt = mat.node_tree
bsdf = nt.nodes["Principled BSDF"]
attr = nt.nodes.new("ShaderNodeVertexColor")
if me.color_attributes:
    attr.layer_name = me.color_attributes[0].name
nt.links.new(attr.outputs["Color"], bsdf.inputs["Base Color"])
bsdf.inputs["Roughness"].default_value = 0.9
me.materials.clear()
me.materials.append(mat)

# 書き出し時の姿勢がゲーム側の初期姿勢（rest）になるため、姿勢を必ず初期化してから書き出す
for pb in rig.pose.bones:
    pb.rotation_euler = (0, 0, 0)
    pb.location = (0, 0, 0)
bpy.context.scene.frame_set(1)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=DST, export_format="GLB", use_selection=True, export_animation_mode="ACTIONS",
                          export_vertex_color="ACTIVE", export_all_vertex_colors=False)
print(f"[rig] {DST}: 三角形 {tris}, 骨 {len(BONES)}, アニメーション idle/walk/work/rest")

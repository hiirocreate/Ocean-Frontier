class_name LowPoly
extends RefCounted
## プリミティブを組み合わせた仮モデル用ヘルパー（docs/ASSET_STATUS.md で仮素材として管理）。

static var _mats: Dictionary = {}


static func mat(color: Color, rough: float = 0.85, emission: float = 0.0) -> StandardMaterial3D:
	var key := "%s_%s_%s" % [color.to_html(), rough, emission]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	_mats[key] = m
	return m


static func box(size: Vector3, color: Color, pos: Vector3 = Vector3.ZERO, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	mi.mesh = m
	mi.material_override = mat(color)
	mi.position = pos
	mi.rotation_degrees = rot_deg
	return mi


static func cylinder(radius: float, height: float, color: Color, pos: Vector3 = Vector3.ZERO, segments: int = 7, rot_deg: Vector3 = Vector3.ZERO, top_radius: float = -1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.bottom_radius = radius
	m.top_radius = radius if top_radius < 0.0 else top_radius
	m.height = height
	m.radial_segments = segments
	m.rings = 1
	mi.mesh = m
	mi.material_override = mat(color)
	mi.position = pos
	mi.rotation_degrees = rot_deg
	return mi


static func sphere(radius: float, color: Color, pos: Vector3 = Vector3.ZERO, segments: int = 8, scale: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = segments
	m.rings = maxi(3, segments / 2)
	mi.mesh = m
	mi.material_override = mat(color)
	mi.position = pos
	mi.scale = scale
	return mi


static var _vc_mat: StandardMaterial3D


## 子孫の不透明な MeshInstance3D を頂点カラー付きの1つのメッシュに結合する（描画呼び出し削減）。
## 半透明のものは結合せず残す。root はシーンツリー外でもよい。
static func merge(root: Node3D) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := 0
	for mi in _mesh_instances(root):
		var mat := mi.material_override as StandardMaterial3D
		if mat == null or mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or mi.mesh == null:
			continue
		var xf := _relative_transform(mi, root)
		var arr := mi.mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var basis := xf.basis.inverse().transposed()
		var col := mat.albedo_color
		if idx.is_empty():
			idx = PackedInt32Array(range(verts.size()))
		for i in idx:
			st.set_color(col)
			st.set_normal((basis * norms[i]).normalized())
			st.add_vertex(xf * verts[i])
		mi.get_parent().remove_child(mi)
		mi.queue_free()
		count += 1
	var out := MeshInstance3D.new()
	if count > 0:
		out.mesh = st.commit()
	if _vc_mat == null:
		_vc_mat = StandardMaterial3D.new()
		_vc_mat.vertex_color_use_as_albedo = true
		_vc_mat.vertex_color_is_srgb = true  # 個別マテリアルの albedo（sRGB）と同じ見た目にする
		_vc_mat.roughness = 0.85
	out.material_override = _vc_mat
	return out


static func _mesh_instances(n: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for c in n.get_children():
		if c is MeshInstance3D:
			out.append(c)
		out.append_array(_mesh_instances(c))
	return out


static func _relative_transform(n: Node3D, root: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != root:
		xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf


## root 直下に結合メッシュを追加して返す（その場で結合）
static func merge_in_place(root: Node3D) -> Node3D:
	var merged := merge(root)
	if merged.mesh != null:
		root.add_child(merged)
	else:
		merged.free()
	return root

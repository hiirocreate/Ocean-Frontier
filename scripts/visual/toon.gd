class_name Toon
extends RefCounted
## セルルック用マテリアルの生成と適用（assets/shaders/toon_cel + toon_outline）。

const CEL := preload("res://assets/shaders/toon_cel.gdshader")
const OUTLINE := preload("res://assets/shaders/toon_outline.gdshader")


## 色（と頂点カラー）からセルルック＋輪郭線のマテリアルを作る
static func material(color: Color, use_vertex_color := false, outline_px := 3.5, bands := 2, extra := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = CEL
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("use_vertex_color", use_vertex_color)
	m.set_shader_parameter("bands", bands)
	for k in extra:
		m.set_shader_parameter(k, extra[k])
	if outline_px > 0.0:
		var o := ShaderMaterial.new()
		o.shader = OUTLINE
		o.set_shader_parameter("outline_px", outline_px)
		m.next_pass = o
	return m


## ノード以下の MeshInstance3D の StandardMaterial3D をセルルックに置き換える（色・頂点カラー・テクスチャを引き継ぐ）
static func apply(root: Node, outline_px := 3.5, bands := 2, extra := {}) -> int:
	var count := 0
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var src := mi.get_active_material(i) as BaseMaterial3D
			var col := src.albedo_color if src else Color.WHITE
			var vc: bool = src != null and src.vertex_color_use_as_albedo or mi.mesh.surface_get_format(i) & Mesh.ARRAY_FORMAT_COLOR != 0
			var m := material(col, vc, outline_px, bands, extra)
			if src and src.albedo_texture:
				m.set_shader_parameter("albedo_texture", src.albedo_texture)
				m.set_shader_parameter("use_texture", true)
			mi.set_surface_override_material(i, m)
			count += 1
	return count

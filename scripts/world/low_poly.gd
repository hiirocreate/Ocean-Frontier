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

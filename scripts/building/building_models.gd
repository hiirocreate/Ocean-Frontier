class_name BuildingModels
extends RefCounted
## 建築物の仮3Dモデル（プリミティブ構成）。タイル中心を原点、床上面(y≈0.08)に置く。
## 完成版では Blender 製 .glb に置き換える（ASSET_STATUS: bld_*）。

const WOOD := Color("8a5a33")
const WOOD_D := Color("6b4426")
const METAL := Color("6f7a80")
const RUST := Color("8a4b2a")
const CLOTH := Color("d9ccb0")


static func make(id: String, stored: int = 0) -> Node3D:
	var n := Node3D.new()
	var y := 0.08
	match id:
		"storage_box":
			n.add_child(LowPoly.box(Vector3(1.3, 0.8, 0.9), WOOD, Vector3(0, y + 0.4, 0)))
			n.add_child(LowPoly.box(Vector3(1.36, 0.12, 0.96), WOOD_D, Vector3(0, y + 0.84, 0)))
			n.add_child(LowPoly.box(Vector3(0.16, 0.2, 0.05), METAL, Vector3(0, y + 0.66, 0.47)))
		"workbench":
			n.add_child(LowPoly.box(Vector3(1.6, 0.1, 0.8), WOOD, Vector3(0, y + 0.85, 0)))
			for x in [-0.7, 0.7]:
				for z in [-0.32, 0.32]:
					n.add_child(LowPoly.box(Vector3(0.1, 0.85, 0.1), WOOD_D, Vector3(x, y + 0.42, z)))
			n.add_child(LowPoly.box(Vector3(0.3, 0.06, 0.12), METAL, Vector3(-0.4, y + 0.93, 0.1), Vector3(0, 30, 0)))
			n.add_child(LowPoly.box(Vector3(0.12, 0.16, 0.5), RUST, Vector3(0.45, y + 0.98, -0.1)))
		"water_purifier":
			n.add_child(LowPoly.cylinder(0.45, 0.6, Color("3d6f8a"), Vector3(0, y + 0.3, 0), 8))
			n.add_child(LowPoly.cylinder(0.55, 0.35, Color(0.8, 0.95, 1.0, 0.55), Vector3(0, y + 0.78, 0), 8, Vector3.ZERO, 0.05))
			n.add_child(LowPoly.cylinder(0.05, 0.4, METAL, Vector3(0.5, y + 0.2, 0), 5, Vector3(0, 0, 90)))
			for i in stored:
				n.add_child(LowPoly.cylinder(0.08, 0.3, Color("7ec8e3"), Vector3(-0.6 + i * 0.2, y + 0.15, 0.45), 6))
		"fishing_net":
			for x in [-0.8, 0.8]:
				n.add_child(LowPoly.cylinder(0.05, 1.2, WOOD_D, Vector3(x, y + 0.6, 0.85), 5))
			n.add_child(LowPoly.box(Vector3(1.6, 0.9, 0.03), Color(0.85, 0.82, 0.7, 0.6), Vector3(0, y + 0.55, 0.85)))
			for i in stored:
				n.add_child(LowPoly.sphere(0.12, Color("b0c4cc"), Vector3(-0.4 + i * 0.4, y + 0.3, 0.8), 6, Vector3(1.6, 0.6, 0.6)))
		"grill":
			n.add_child(LowPoly.cylinder(0.5, 0.18, METAL, Vector3(0, y + 0.45, 0), 8, Vector3.ZERO, 0.4))
			for a in 3:
				var ang := a * TAU / 3.0
				n.add_child(LowPoly.cylinder(0.04, 0.45, RUST, Vector3(cos(ang) * 0.35, y + 0.2, sin(ang) * 0.35), 5))
			n.add_child(LowPoly.sphere(0.18, Color(1.0, 0.55, 0.2), Vector3(0, y + 0.6, 0), 6, Vector3(1, 0.6, 1)))
		"bed":
			n.add_child(LowPoly.box(Vector3(1.0, 0.2, 1.8), WOOD, Vector3(0, y + 0.1, 0)))
			n.add_child(LowPoly.box(Vector3(0.92, 0.14, 1.7), CLOTH, Vector3(0, y + 0.26, 0)))
			n.add_child(LowPoly.box(Vector3(0.6, 0.12, 0.35), Color("b0a080"), Vector3(0, y + 0.38, -0.65)))
		"garden":
			n.add_child(LowPoly.box(Vector3(1.6, 0.35, 1.6), WOOD, Vector3(0, y + 0.18, 0)))
			n.add_child(LowPoly.box(Vector3(1.45, 0.06, 1.45), Color("4a3524"), Vector3(0, y + 0.36, 0)))
			for i in 4:
				var p := Vector3(-0.4 + (i % 2) * 0.8, y + 0.5, -0.4 + (i / 2) * 0.8)
				n.add_child(LowPoly.sphere(0.16 + (0.06 if i < stored else 0.0), Color("5e9c45"), p, 6, Vector3(1, 0.8, 1)))
		_:
			n.add_child(LowPoly.box(Vector3(1, 1, 1), Color.MAGENTA, Vector3(0, y + 0.5, 0)))
	return n

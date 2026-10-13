class_name ShipModels
extends RefCounted
## 船の仮3Dモデル（プリミティブ構成、頂点カラーで結合）。船首は -Z 方向。


static func make(type: String) -> Node3D:
	var n := Node3D.new()
	var hull := Color("6b4426")
	var deck := Color("9b6a3d")
	var sail := Color("e6d8b8")
	match type:
		"dinghy":
			_hull(n, Vector3(1.4, 0.5, 3.2), hull, deck)
			n.add_child(LowPoly.box(Vector3(1.2, 0.06, 0.2), deck, Vector3(0, 0.45, 0.4)))
		"sloop":
			_hull(n, Vector3(2.4, 0.9, 7.0), hull, deck)
			n.add_child(LowPoly.cylinder(0.1, 6.0, Color("5a3a20"), Vector3(0, 3.6, -0.5), 6))
			n.add_child(LowPoly.box(Vector3(0.05, 4.0, 3.0), sail, Vector3(0, 3.6, 1.0)))
		"schooner":
			_hull(n, Vector3(3.2, 1.2, 11.0), hull.darkened(0.1), deck)
			for z in [-2.5, 2.0]:
				n.add_child(LowPoly.cylinder(0.12, 8.0, Color("5a3a20"), Vector3(0, 4.8, z), 6))
				n.add_child(LowPoly.box(Vector3(0.05, 5.0, 3.4), sail, Vector3(0, 4.6, z + 1.7)))
			n.add_child(LowPoly.box(Vector3(2.4, 1.2, 2.4), Color("8a5a33"), Vector3(0, 1.4, 4.0)))
		"gunboat":
			_hull(n, Vector3(3.4, 1.4, 9.0), Color("4e5450"), Color("6e7470"))
			n.add_child(LowPoly.box(Vector3(2.2, 1.6, 2.6), Color("5e6460"), Vector3(0, 1.9, 1.5)))
			for x in [-1.2, 1.2]:
				n.add_child(LowPoly.cylinder(0.18, 1.8, Color("2a2e30"), Vector3(x, 1.4, -2.5), 6, Vector3(90, 0, 0)))
			n.add_child(LowPoly.cylinder(0.25, 1.5, Color("3a3e40"), Vector3(0, 3.2, 1.5), 6))
		_:
			_hull(n, Vector3(2, 0.8, 5), hull, deck)
	return LowPoly.merge_in_place(n)


static func _hull(n: Node3D, size: Vector3, hull: Color, deck: Color) -> void:
	n.add_child(LowPoly.box(size, hull, Vector3(0, size.y * 0.3, 0)))
	n.add_child(LowPoly.box(Vector3(size.x * 0.7, size.y * 0.8, size.z * 0.25), hull, Vector3(0, size.y * 0.25, -size.z * 0.55), Vector3(0, 45, 0)))
	n.add_child(LowPoly.box(Vector3(size.x * 0.9, 0.08, size.z * 0.92), deck, Vector3(0, size.y * 0.8, 0)))

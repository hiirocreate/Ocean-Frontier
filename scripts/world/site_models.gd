class_name SiteModels
extends RefCounted
## 探索地点の目印となる3Dモデル（仮素材・プリミティブ構成）。種類ごとに形と色を変え、遠くからでも判別できるようにする。

const RUST := Color("8a4b2a")
const STEEL := Color("6e6a66")
const WOOD := Color("6b4426")
const RELIC := Color("cfe8ff")
const WARM := Color("ffb35c")


static func make(type: String) -> Node3D:
	var n := Node3D.new()
	match type:
		"shipwreck":
			var hull := Node3D.new()
			hull.rotation_degrees = Vector3(-25, 30, 15)
			hull.add_child(LowPoly.box(Vector3(4, 2.2, 12), Color("5a4a3a"), Vector3(0, 0.5, 0)))
			hull.add_child(LowPoly.box(Vector3(3.6, 1.4, 4), Color("e0dccf"), Vector3(0, 2.2, -2)))
			hull.add_child(LowPoly.cylinder(0.15, 6, WOOD, Vector3(0, 4, 2), 5))
			n.add_child(hull)
		"drone_ship":
			n.add_child(LowPoly.box(Vector3(5, 1.8, 14), Color("8a9298"), Vector3(0, 0.4, 0)))
			n.add_child(LowPoly.box(Vector3(3, 2.5, 4), Color("a8b0b4"), Vector3(0, 2.4, 2)))
			n.add_child(LowPoly.cylinder(0.12, 5, STEEL, Vector3(0, 5, 2), 5))
			n.add_child(_light(Vector3(0, 7.6, 2), Color("ff5a4a"), 2.0))
		"underwater_wreck", "underwater_city":
			# 海面のブイと泡（下に何かが沈んでいる目印）
			n.add_child(LowPoly.cylinder(0.5, 1.2, Color("d8603a"), Vector3(0, 0.3, 0), 8))
			n.add_child(LowPoly.cylinder(0.08, 2.0, STEEL, Vector3(0, 1.6, 0), 5))
			for i in 6:
				var a := i * TAU / 6.0
				n.add_child(LowPoly.sphere(0.25 + 0.1 * (i % 2), Color(0.85, 0.95, 1.0, 0.6), Vector3(cos(a) * 3, 0.1, sin(a) * 3), 6))
			if type == "underwater_city":
				for i in 3:
					n.add_child(LowPoly.cylinder(0.6, 2.0, Color(0.7, 0.9, 1.0, 0.5), Vector3(-6 + i * 6, 0.6, 5), 8, Vector3.ZERO, 0.0))
				n.add_child(_light(Vector3(0, 2.5, 0), RELIC, 1.5))
		"ruin":
			for i in 4:
				var x := -6.0 + i * 4.0
				n.add_child(LowPoly.box(Vector3(1.2, 7 - i, 1.2), RUST, Vector3(x, (7 - i) / 2.0 - 1, (i % 2) * 3.0), Vector3(0, 0, (i - 1.5) * 6)))
			n.add_child(LowPoly.box(Vector3(14, 0.6, 7), STEEL, Vector3(0, 4, 1), Vector3(5, 0, -4)))
			n.add_child(LowPoly.box(Vector3(4, 3, 4), Color("7a6a5a"), Vector3(3, 6, 1)))
		"research_facility":
			n.add_child(LowPoly.cylinder(1.2, 1.5, Color("dcdcd4"), Vector3(0, 0.4, 0), 8))
			n.add_child(LowPoly.cylinder(0.1, 6, STEEL, Vector3(0, 4, 0), 5))
			n.add_child(LowPoly.box(Vector3(2.5, 0.1, 1.2), Color("2a4a6a"), Vector3(0, 6.5, 0), Vector3(0, 0, 20)))
			n.add_child(_light(Vector3(0, 7.2, 0), RELIC, 2.5))
		"special":
			for i in 7:
				var a := i * TAU / 7.0
				var h := 2.0 + (i % 3) * 1.5
				n.add_child(LowPoly.box(Vector3(0.8, h, 0.8), Color("5a1e24"), Vector3(cos(a) * 8, h / 2.0 - 0.5, sin(a) * 8), Vector3(0, a * 57.3, 10)))
			n.add_child(_light(Vector3(0, 1.5, 0), Color("c04a6a"), 3.0))
		"settlement":
			for i in 7:
				var a := i * TAU / 7.0
				var p := Vector3(cos(a) * 10, 0, sin(a) * 10)
				n.add_child(LowPoly.box(Vector3(6, 0.5, 6), Color("8a5a33"), p))
				n.add_child(LowPoly.box(Vector3(3.5, 2.5, 3.5), Color("c9b07a").lerp(Color("a85a3a"), float(i % 3) / 2.0), p + Vector3(0, 1.5, 0)))
				n.add_child(LowPoly.box(Vector3(4, 0.4, 4), Color("6a3a2a"), p + Vector3(0, 3.0, 0), Vector3(0, 0, 15)))
			n.add_child(LowPoly.cylinder(0.2, 12, WOOD, Vector3(0, 6, 0), 5))
			n.add_child(LowPoly.box(Vector3(0.05, 2, 3), Color("2aa69a"), Vector3(0, 10.5, 1.5)))
			n.add_child(_light(Vector3(0, 4, 0), WARM, 3.0))
		"fortress":
			for i in 4:
				var a := i * TAU / 4.0 + PI / 4
				n.add_child(LowPoly.box(Vector3(14, 5, 1.5), STEEL, Vector3(cos(a) * 8, 2, sin(a) * 8), Vector3(0, -a * 57.3 + 90, 0)))
			n.add_child(LowPoly.cylinder(2, 10, Color("4e5450"), Vector3(0, 4.5, 0), 6))
			n.add_child(LowPoly.box(Vector3(0.05, 2, 3), Color("4a5a3a"), Vector3(0, 11, 1.5)))
		"pirate_base":
			for i in 3:
				var hull := Node3D.new()
				hull.position = Vector3(-8 + i * 8, 0, (i % 2) * 5)
				hull.rotation_degrees = Vector3(0, i * 40, (i - 1) * 8)
				hull.add_child(LowPoly.box(Vector3(4, 2, 12), Color("2a2224"), Vector3(0, 0.4, 0)))
				hull.add_child(LowPoly.cylinder(0.15, 8, WOOD, Vector3(0, 5, 0), 5))
				hull.add_child(LowPoly.box(Vector3(0.05, 2.5, 3.5), Color("151515"), Vector3(0, 7.5, 1.8)))
				n.add_child(hull)
			n.add_child(_light(Vector3(0, 3, 0), Color("ff7a3a"), 2.0))
		_:
			n.add_child(LowPoly.cylinder(0.5, 2, Color.MAGENTA, Vector3(0, 1, 0)))
	return n


static func _light(pos: Vector3, color: Color, energy: float) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.add_child(LowPoly.sphere(0.3, color, Vector3.ZERO, 6))
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = 14.0
	n.add_child(l)
	return n

class_name Encounter
extends Node3D
## 海上での遭遇（漂流者の救助・元仲間との再会）。小舟と人物を表示し、近づくと話しかけられる。

var kind := "rescue"  # rescue / reunion
var member_id := ""
var _phase := 0.0


func setup(k: String, id: String, defn: Dictionary) -> void:
	kind = k
	member_id = id
	_phase = randf() * TAU
	# 壊れた小舟
	add_child(LowPoly.box(Vector3(1.4, 0.3, 2.6), Color("6b4426"), Vector3(0, 0.0, 0)))
	add_child(LowPoly.box(Vector3(1.2, 0.12, 2.3), Color("8a5a33"), Vector3(0, 0.18, 0)))
	add_child(LowPoly.box(Vector3(0.1, 0.5, 2.4), Color("5a3a20"), Vector3(0.65, 0.3, 0)))
	add_child(LowPoly.box(Vector3(0.1, 0.5, 2.4), Color("5a3a20"), Vector3(-0.65, 0.3, 0), Vector3(0, 0, -10)))
	var person := CharacterModel.new()
	person.apply_look(defn)
	person.position = Vector3(0, 0.2, 0.3)
	person.scale = Vector3.ONE * 0.95
	add_child(person)
	# 目印の旗（商人は潮流連合の青緑、漂流者は白い布）
	var flag_col := Color("2aa69a") if kind == "merchant" else Color("f0ece0")
	add_child(LowPoly.cylinder(0.04, 2.2, Color("6b4426"), Vector3(0.4, 1.2, -0.9), 5))
	add_child(LowPoly.box(Vector3(0.03, 0.5, 0.7), flag_col, Vector3(0.4, 2.0, -0.55)))
	if kind == "merchant":
		for i in 3:
			add_child(LowPoly.box(Vector3(0.5, 0.4, 0.5), Color("a07a4a"), Vector3(-0.3, 0.4 + i * 0.05, -0.6 + i * 0.6)))


func update_float(t: float, amp: float) -> void:
	position.y = OceanWaves.height(position.x, position.z, t, amp) * 0.8
	rotation.z = sin(t * 1.1 + _phase) * 0.06
	rotation.x = cos(t * 0.9 + _phase) * 0.05

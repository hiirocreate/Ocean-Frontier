class_name Debris
extends Node3D
## 漂流物。種類（kind）ごとに見た目が異なり、回収時に GameSession が抽選表から中身を決める。

var kind := "plank"
var drift := Vector3.ZERO
var collected := false
var _phase := 0.0
var _target: Node3D
var _t := 0.0


func setup(k: String, phase: float, drift_vel: Vector3) -> void:
	kind = k
	_phase = phase
	drift = drift_vel
	rotation.y = phase * 3.0
	match kind:
		"plank":
			add_child(LowPoly.box(Vector3(1.6, 0.14, 0.35), Color("9b6a3d"), Vector3.ZERO, Vector3(0, 0, 3)))
			add_child(LowPoly.box(Vector3(1.1, 0.12, 0.3), Color("7c4f2c"), Vector3(0.2, 0.08, 0.3), Vector3(0, 25, -4)))
		"barrel":
			add_child(LowPoly.cylinder(0.38, 0.95, Color("4f6f7a"), Vector3(0, 0.05, 0), 8, Vector3(80, 0, 0)))
			add_child(LowPoly.cylinder(0.4, 0.08, Color("2f3b40"), Vector3(0, 0.05, 0.25), 8, Vector3(80, 0, 0)))
			add_child(LowPoly.cylinder(0.4, 0.08, Color("2f3b40"), Vector3(0, 0.05, -0.25), 8, Vector3(80, 0, 0)))
		"crate":
			add_child(LowPoly.box(Vector3(0.9, 0.7, 0.9), Color("a07a4a"), Vector3(0, 0.1, 0), Vector3(0, 0, 6)))
			add_child(LowPoly.box(Vector3(0.95, 0.12, 0.2), Color("6e5130"), Vector3(0, 0.3, 0), Vector3(0, 0, 6)))
			add_child(LowPoly.box(Vector3(0.2, 0.12, 0.95), Color("6e5130"), Vector3(0, 0.3, 0), Vector3(0, 0, 6)))
	# 目印の小さな光（遠くからでも見つけやすく）
	add_child(LowPoly.sphere(0.08, Color(1.0, 0.9, 0.6), Vector3(0, 0.55, 0), 6))
	LowPoly.merge_in_place(self)


func update_float(t: float, amp: float, delta: float) -> void:
	if collected:
		_t += delta * 2.5
		if is_instance_valid(_target):
			global_position = global_position.lerp(_target.global_position + Vector3(0, 0.6, 0), minf(1.0, _t))
			scale = Vector3.ONE * maxf(0.05, 1.0 - _t)
		if _t >= 1.0:
			queue_free()
		return
	position += drift * delta
	position.y = OceanWaves.height(position.x, position.z, t, amp) + 0.05
	rotation.z = sin(t * 1.3 + _phase) * 0.12
	rotation.x = cos(t * 1.1 + _phase) * 0.1


func fly_to(target: Node3D) -> void:
	collected = true
	_target = target
	_t = 0.0

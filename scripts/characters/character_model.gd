class_name CharacterModel
extends Node3D
## 探索用キャラクターの仮モデル（ローポリのプリミティブ構成）。
## 外見パラメータは docs/CHARACTER_GUIDE.md の設定と一致させる。
## 完成版では Blender 製 .glb に置き換える（ASSET_STATUS: char_protagonist_model）。

@export var skin := Color("e8b996")
@export var hair := Color("2e2a2b")
@export var shirt := Color("d8cfb8")
@export var vest := Color("3f6b73")
@export var pants := Color("4a4f5e")
@export var scarf := Color("c2553d")

var _t := 0.0
var _arm_l: Node3D
var _arm_r: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _body: Node3D
var moving := false


func _ready() -> void:
	_body = Node3D.new()
	add_child(_body)
	_leg_l = _limb(Vector3(-0.13, 0.82, 0), 0.09, 0.8, pants, Color("3b2a20"))
	_leg_r = _limb(Vector3(0.13, 0.82, 0), 0.09, 0.8, pants, Color("3b2a20"))
	# 胴体（シャツ＋ベスト）
	_body.add_child(LowPoly.cylinder(0.24, 0.62, shirt, Vector3(0, 1.13, 0), 7, Vector3.ZERO, 0.2))
	_body.add_child(LowPoly.cylinder(0.255, 0.42, vest, Vector3(0, 1.08, 0.0), 7, Vector3.ZERO, 0.23))
	_body.add_child(LowPoly.box(Vector3(0.5, 0.08, 0.3), Color("5a3b26"), Vector3(0, 0.86, 0)))  # ベルト
	# スカーフ
	_body.add_child(LowPoly.cylinder(0.17, 0.1, scarf, Vector3(0, 1.45, 0), 7))
	_body.add_child(LowPoly.box(Vector3(0.1, 0.32, 0.05), scarf, Vector3(0.08, 1.3, 0.2), Vector3(10, 0, -12)))
	# 頭
	_body.add_child(LowPoly.sphere(0.2, skin, Vector3(0, 1.66, 0), 8, Vector3(1, 1.08, 1)))
	# 髪（ボサボサの短髪をいくつかの塊で）
	_body.add_child(LowPoly.sphere(0.215, hair, Vector3(0, 1.74, -0.03), 7, Vector3(1.02, 0.75, 1.0)))
	_body.add_child(LowPoly.box(Vector3(0.14, 0.1, 0.1), hair, Vector3(-0.08, 1.8, 0.14), Vector3(20, 0, 15)))
	_body.add_child(LowPoly.box(Vector3(0.12, 0.09, 0.1), hair, Vector3(0.09, 1.79, 0.15), Vector3(25, 0, -18)))
	# 目
	_body.add_child(LowPoly.box(Vector3(0.04, 0.05, 0.02), Color("1d2228"), Vector3(-0.07, 1.67, 0.19)))
	_body.add_child(LowPoly.box(Vector3(0.04, 0.05, 0.02), Color("1d2228"), Vector3(0.07, 1.67, 0.19)))
	# 腕
	_arm_l = _limb(Vector3(-0.32, 1.38, 0), 0.07, 0.62, shirt, skin)
	_arm_r = _limb(Vector3(0.32, 1.38, 0), 0.07, 0.62, shirt, skin)
	_body.add_child(_arm_l)
	_body.add_child(_arm_r)
	_body.add_child(_leg_l)
	_body.add_child(_leg_r)
	# 背中の小さな鞄（漂流者の唯一の持ち物）
	_body.add_child(LowPoly.box(Vector3(0.3, 0.32, 0.14), Color("7a5a3a"), Vector3(0, 1.12, -0.26)))


## 肩/股関節を支点にぶら下がる手足。
func _limb(pivot: Vector3, r: float, length: float, upper: Color, end_color: Color) -> Node3D:
	var n := Node3D.new()
	n.position = pivot
	n.add_child(LowPoly.cylinder(r, length * 0.8, upper, Vector3(0, -length * 0.4, 0), 6))
	n.add_child(LowPoly.sphere(r * 1.15, end_color, Vector3(0, -length * 0.85, 0.02), 6))
	return n


func _process(delta: float) -> void:
	_t += delta * (7.0 if moving else 1.6)
	var swing := sin(_t) * (0.55 if moving else 0.05)
	_arm_l.rotation.x = swing
	_arm_r.rotation.x = -swing
	_leg_l.rotation.x = -swing * 0.8 if moving else 0.0
	_leg_r.rotation.x = swing * 0.8 if moving else 0.0
	_body.position.y = absf(sin(_t)) * 0.04 if moving else sin(_t) * 0.01

class_name CharacterModel
extends Node3D
## 探索用キャラクターの仮モデル（ローポリのプリミティブ構成）。
## 外見パラメータは docs/CHARACTER_GUIDE.md の設定と一致させる。
## 生成した3Dモデル（assets/characters/models/<art_id>.glb、待機・歩行・作業・休憩のアニメーション付き）が
## あればそちらを使い、セルルック（Toon）で描く。なければこのプリミティブ構成で描く。

@export var skin := Color("e8b996")
@export var hair := Color("2e2a2b")
@export var shirt := Color("d8cfb8")
@export var vest := Color("3f6b73")
@export var pants := Color("4a4f5e")
@export var scarf := Color("c2553d")
var accessory := "scarf"
var hair_style := "messy"
var body: Dictionary = {}  # 体格（PlayerProfile.body_params_for）。空なら標準の大人体型
var face := "soft"

var _t := 0.0
var _arm_l: Node3D
var _arm_r: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _body: Node3D
var moving := false
var working := false  # 作業中（腕を振る）
var resting := false  # 休憩中（座る）
var _defn: Dictionary = {}
var _art: Node3D  # 生成モデル（ある場合）
var _anim: AnimationPlayer


## survivors.json の定義から外見を設定（add_child の前に呼ぶ）
func apply_look(defn: Dictionary) -> void:
	_defn = defn
	var c: Dictionary = defn.get("colors", {})
	skin = Color(str(c.get("skin", skin.to_html())))
	hair = Color(str(c.get("hair", hair.to_html())))
	shirt = Color(str(c.get("shirt", shirt.to_html())))
	vest = Color(str(c.get("outer", vest.to_html())))
	pants = Color(str(c.get("pants", pants.to_html())))
	scarf = Color(str(c.get("accent", scarf.to_html())))
	accessory = str(defn.get("accessory", ""))
	hair_style = str(defn.get("hair_style", "short"))
	face = str(defn.get("face", "soft"))
	if defn.has("age"):
		body = PlayerProfile.body_params_for(str(defn.get("gender", "male")), int(defn["age"]))


func _ready() -> void:
	if _setup_generated():
		return
	_body = Node3D.new()
	add_child(_body)
	_leg_l = _limb(Vector3(-0.13, 0.82, 0), 0.09, 0.8, pants, Color("3b2a20"))
	_leg_r = _limb(Vector3(0.13, 0.82, 0), 0.09, 0.8, pants, Color("3b2a20"))
	# 胴体（シャツ＋ベスト）
	_body.add_child(LowPoly.cylinder(0.24, 0.62, shirt, Vector3(0, 1.13, 0), 7, Vector3.ZERO, 0.2))
	_body.add_child(LowPoly.cylinder(0.255, 0.42, vest, Vector3(0, 1.08, 0.0), 7, Vector3.ZERO, 0.23))
	_body.add_child(LowPoly.box(Vector3(0.5, 0.08, 0.3), Color("5a3b26"), Vector3(0, 0.86, 0)))  # ベルト
	# スカーフ（主人公の手がかり）
	if accessory == "scarf":
		_body.add_child(LowPoly.cylinder(0.17, 0.1, scarf, Vector3(0, 1.45, 0), 7))
		_body.add_child(LowPoly.box(Vector3(0.1, 0.32, 0.05), scarf, Vector3(0.08, 1.3, 0.2), Vector3(10, 0, -12)))
	# 頭
	_body.add_child(LowPoly.sphere(0.2, skin, Vector3(0, 1.66, 0), 8, Vector3(1, 1.08, 1)))
	# 髪（2D立ち絵の hair_style と対応）
	_body.add_child(LowPoly.sphere(0.215, hair, Vector3(0, 1.74, -0.03), 7, Vector3(1.02, 0.75, 1.0)))
	match hair_style:
		"long", "long_wavy":
			_body.add_child(LowPoly.box(Vector3(0.4, 0.5, 0.14), hair, Vector3(0, 1.5, -0.14)))
		"spiky":
			for i in 4:
				_body.add_child(LowPoly.box(Vector3(0.07, 0.16, 0.07), hair, Vector3(-0.12 + i * 0.08, 1.9, 0.02), Vector3(0, 0, -20 + i * 13)))
		"tied":
			_body.add_child(LowPoly.sphere(0.08, hair, Vector3(0, 1.78, -0.22), 6))
		"crop":
			pass
		_:
			_body.add_child(LowPoly.box(Vector3(0.14, 0.1, 0.1), hair, Vector3(-0.08, 1.8, 0.14), Vector3(20, 0, 15)))
			_body.add_child(LowPoly.box(Vector3(0.12, 0.09, 0.1), hair, Vector3(0.09, 1.79, 0.15), Vector3(25, 0, -18)))
	match accessory:
		"glasses":
			_body.add_child(LowPoly.box(Vector3(0.3, 0.06, 0.02), Color("3a3a40"), Vector3(0, 1.67, 0.2)))
		"goggles":
			_body.add_child(LowPoly.box(Vector3(0.34, 0.08, 0.06), Color("6b5a3a"), Vector3(0, 1.8, 0.16)))
		"eyepatch":
			_body.add_child(LowPoly.box(Vector3(0.08, 0.08, 0.03), Color("151515"), Vector3(0.07, 1.67, 0.2)))
		"earrings":
			_body.add_child(LowPoly.sphere(0.03, scarf, Vector3(-0.2, 1.6, 0), 5))
			_body.add_child(LowPoly.sphere(0.03, scarf, Vector3(0.2, 1.6, 0), 5))
		"scar":
			_body.add_child(LowPoly.box(Vector3(0.22, 0.06, 0.05), hair, Vector3(0, 1.58, 0.18)))
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
	if face == "scarred":
		_body.add_child(LowPoly.box(Vector3(0.02, 0.08, 0.02), Color("9a5a50"), Vector3(-0.12, 1.62, 0.17)))
	_apply_body()
	# 描画呼び出しを減らすため、動かない部分と各手足をそれぞれ1メッシュに結合する
	for limb in [_arm_l, _arm_r, _leg_l, _leg_r]:
		LowPoly.merge_in_place(limb)
	var static_part := Node3D.new()
	for c in _body.get_children():
		if c is MeshInstance3D:
			_body.remove_child(c)
			static_part.add_child(c)
	_body.add_child(LowPoly.merge(static_part))
	static_part.free()


## 肩/股関節を支点にぶら下がる手足。
## 年齢・性別による体格。縮小だけでなく頭身・肩幅・手足の長さの比率を変える（仕様: 若年層の外見）
func _apply_body() -> void:
	if body.is_empty():
		return
	var limb := float(body["limb"])
	var head := float(body["head"])
	var shoulder := float(body["shoulder"])
	var lift := 0.82 * (limb - 1.0)
	for leg in [_leg_l, _leg_r]:
		leg.scale.y = limb
		leg.position.y = 0.82 * limb
	for c in _body.get_children():
		if c in [_leg_l, _leg_r, _arm_l, _arm_r] or not (c is Node3D):
			continue
		var n := c as Node3D
		if n.position.y >= 1.5:
			# 頭部：頭の中心（y=1.66）を基準に拡大
			n.position = Vector3(n.position.x * head, 1.66 + lift + (n.position.y - 1.66) * head, n.position.z * head)
			n.scale *= head
		else:
			n.position.y += lift
			if n.position.y > 0.95 + lift:
				n.scale.x *= shoulder
			else:
				n.scale.x *= float(body["hip"])
	for arm in [_arm_l, _arm_r]:
		arm.position = Vector3(arm.position.x * shoulder, arm.position.y + lift, arm.position.z)
		arm.scale.y = limb
	scale = Vector3.ONE * float(body["height"])
	rotation.x = float(body.get("posture", 0.0))


func _limb(pivot: Vector3, r: float, length: float, upper: Color, end_color: Color) -> Node3D:
	var n := Node3D.new()
	n.position = pivot
	n.add_child(LowPoly.cylinder(r, length * 0.8, upper, Vector3(0, -length * 0.4, 0), 6))
	n.add_child(LowPoly.sphere(r * 1.15, end_color, Vector3(0, -length * 0.85, 0.02), 6))
	return n


## 生成モデルを使う。体格は年齢帯・性別の身長比のみ反映（体型の差は生成画像側で描き分け済み）
func _setup_generated() -> bool:
	if not CharacterArt.enabled(_defn):
		return false
	var scene := CharacterArt.model_scene(CharacterArt.art_id(str(_defn.get("id", "")), _defn))
	if scene == null:
		return false
	_art = scene.instantiate() as Node3D
	add_child(_art)
	if not body.is_empty():
		_art.scale = Vector3.ONE * float(body.get("height", 1.0))
	Toon.apply(_art, 3.0, 2, CharacterArt.recolor_params(_defn))
	_anim = _art.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim:
		for a in ["idle", "walk", "work"]:
			if _anim.has_animation(a):
				_anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
		_anim.play("idle")
	return true


func _process(delta: float) -> void:
	if _art:
		if _anim:
			var want := "walk" if moving else ("work" if working else ("rest" if resting else "idle"))
			if _anim.current_animation != want and _anim.has_animation(want):
				_anim.play(want, 0.2)
		return
	_t += delta * (7.0 if moving else (5.0 if working else 1.6))
	var swing := sin(_t) * (0.55 if moving else 0.05)
	_arm_l.rotation.x = swing
	_arm_r.rotation.x = -swing
	if working and not moving:
		# 金槌を振るような動き
		_arm_r.rotation.x = -1.2 - absf(sin(_t)) * 0.9
		_arm_l.rotation.x = -0.4
	_leg_l.rotation.x = -swing * 0.8 if moving else (-1.4 if resting else 0.0)
	_leg_r.rotation.x = swing * 0.8 if moving else (-1.4 if resting else 0.0)
	var base_y := -0.45 if resting and not moving else 0.0
	_body.position.y = base_y + (absf(sin(_t)) * 0.04 if moving else sin(_t) * 0.01)

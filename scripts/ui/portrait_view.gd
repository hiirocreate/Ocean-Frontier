class_name PortraitView
extends Control
## 会話用の2D立ち絵（バストアップ）を図形で描く仮イラスト。
## 配色・髪型・装飾は survivors.json と共通で、3Dモデル（CharacterModel）と外見を一致させる。
## 正式なイラスト（assets/characters/portraits/<id>_<expression>.png）があればそちらを優先する。

const PLAYER_LOOK := {
	"colors": {"skin": "#e8b996", "hair": "#2e2a2b", "shirt": "#d8cfb8", "outer": "#3f6b73", "pants": "#4a4f5e", "accent": "#c2553d"},
	"accessory": "scarf", "hair_style": "messy",
}

var look: Dictionary = {}
var expression := "normal"
var _texture: Texture2D


func _init() -> void:
	custom_minimum_size = Vector2(240, 300)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## id: 仲間ID / "player"。defn: survivors.json の定義（player の場合は空）
func set_character(id: String, defn: Dictionary, expr: String = "normal") -> void:
	look = (defn if not defn.is_empty() else PLAYER_LOOK) if id == "player" else defn
	expression = expr if expr != "" else "normal"
	_texture = null
	material = null
	if CharacterArt.enabled(look):
		_texture = CharacterArt.portrait(CharacterArt.art_id(id, look), expression)
		if _texture:
			material = CharacterArt.portrait_material(look)
	queue_redraw()


func _c(key: String, def: String) -> Color:
	return Color(str(look.get("colors", {}).get(key, def)))


func _ellipse(center: Vector2, radii: Vector2, color: Color, points: int = 28) -> void:
	var pts := PackedVector2Array()
	for i in points:
		var a := TAU * i / points
		pts.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_colored_polygon(pts, color)


func _draw() -> void:
	if look.is_empty():
		return
	var w := size.x
	var h := size.y
	if _texture:
		# 縦横比を保って下端・中央揃え
		var ts := _texture.get_size()
		var k := minf(w / ts.x, h / ts.y)
		var r := Rect2(Vector2((w - ts.x * k) / 2.0, h - ts.y * k), ts * k)
		draw_texture_rect(_texture, r, false)
		return
	var s := minf(w / 240.0, h / 300.0)
	var o := Vector2((w - 240.0 * s) / 2.0, h - 300.0 * s)
	draw_set_transform(o, 0.0, Vector2(s, s))
	var skin := _c("skin", "#e8b996")
	var hair := _c("hair", "#2e2a2b")
	var outer := _c("outer", "#3f6b73")
	var shirt := _c("shirt", "#d8cfb8")
	var accent := _c("accent", "#c2553d")
	var shade := skin.darkened(0.18)
	var style := str(look.get("hair_style", "short"))
	var acc := str(look.get("accessory", ""))
	# 年齢・性別・顔の特徴による描き分け（主人公のみ。仲間は既定の大人体型）
	var band := str(look.get("age_band", "adult"))
	var female := str(look.get("gender", "")) == "female"
	var face_kind := str(look.get("face", "soft"))
	var sh := {"young": 0.78, "youth": 0.92, "adult": 1.0, "mature": 1.03}.get(band, 1.0) as float
	if female:
		sh *= 0.9
	var face_r := Vector2(52, 62)
	if band == "young":
		face_r = Vector2(54, 55)
	elif female:
		face_r = Vector2(49, 60)
	var eye_scale := {"young": 1.3, "youth": 1.12}.get(band, 1.0) as float
	if face_kind == "sharp":
		eye_scale *= 0.85
	# 背景の光輪
	_ellipse(Vector2(120, 140), Vector2(110, 110), Color(accent, 0.18))
	# 後ろ髪
	if style in ["long", "long_wavy"]:
		draw_colored_polygon(PackedVector2Array([Vector2(62, 90), Vector2(178, 90), Vector2(190, 230), Vector2(50, 230)]), hair.darkened(0.1))
	if style == "bob":
		draw_colored_polygon(PackedVector2Array([Vector2(62, 90), Vector2(178, 90), Vector2(182, 178), Vector2(58, 178)]), hair.darkened(0.1))
	if style == "tied":
		_ellipse(Vector2(120, 62), Vector2(22, 18), hair.darkened(0.15))
	# 肩と服
	var shp := PackedVector2Array()
	for v in [Vector2(20, 300), Vector2(40, 228), Vector2(95, 205), Vector2(145, 205), Vector2(200, 228), Vector2(220, 300)]:
		shp.append(Vector2(120 + (v.x - 120) * sh, v.y))
	draw_colored_polygon(shp, outer)
	draw_colored_polygon(PackedVector2Array([Vector2(98, 206), Vector2(142, 206), Vector2(120, 262)]), shirt)
	if acc == "scarf":
		draw_colored_polygon(PackedVector2Array([Vector2(92, 200), Vector2(148, 200), Vector2(140, 222), Vector2(100, 222)]), accent)
		draw_colored_polygon(PackedVector2Array([Vector2(126, 218), Vector2(140, 218), Vector2(150, 262), Vector2(134, 262)]), accent.darkened(0.15))
	# 首
	draw_rect(Rect2(108 if band == "young" or female else 106, 168, 24 if band == "young" or female else 28, 40), shade)
	# 顔
	_ellipse(Vector2(120, 122 + (6 if band == "young" else 0)), face_r, skin)
	_ellipse(Vector2(68, 128), Vector2(8, 13), shade)
	_ellipse(Vector2(172, 128), Vector2(8, 13), shade)
	# 目
	var eye_y := 124.0
	for x in [97.0, 143.0]:
		if expression == "smile":
			draw_arc(Vector2(x, eye_y + 4), 9, PI * 1.1, PI * 1.9, 10, Color("2a2420"), 3.0)
		elif expression == "tired":
			draw_line(Vector2(x - 9, eye_y + 2), Vector2(x + 9, eye_y + 2), Color("2a2420"), 3.0)
		else:
			var big: float = (1.25 if expression == "surprised" else 1.0) * eye_scale
			_ellipse(Vector2(x, eye_y), Vector2(10, 8) * big, Color("f8f6f0"))
			_ellipse(Vector2(x, eye_y), Vector2(5.5, 6.5) * big, accent.darkened(0.5))
			_ellipse(Vector2(x + 2, eye_y - 2), Vector2(1.8, 1.8), Color.WHITE)
	# 眉
	var brow := hair.darkened(0.2)
	for side in [-1.0, 1.0]:
		var cx: float = 120.0 + side * 23.0
		var inner := Vector2(cx - side * 10.0, 106)
		var outer_p := Vector2(cx + side * 10.0, 106)
		match expression:
			"angry":
				inner.y += 6
			"sad", "tired":
				inner.y -= 5
				outer_p.y += 3
			"surprised":
				inner.y -= 6
				outer_p.y -= 6
		draw_line(inner, outer_p, brow, 4.0)
	# 鼻・口
	draw_line(Vector2(120, 130), Vector2(116, 146), shade.darkened(0.1), 2.0)
	var mouth := Color("8a4a42")
	match expression:
		"smile":
			draw_arc(Vector2(120, 152), 13, 0.15 * PI, 0.85 * PI, 12, mouth, 3.0)
		"sad", "tired":
			draw_arc(Vector2(120, 166), 10, 1.2 * PI, 1.8 * PI, 10, mouth, 3.0)
		"angry":
			draw_line(Vector2(108, 160), Vector2(132, 157), mouth, 3.0)
		"surprised":
			_ellipse(Vector2(120, 160), Vector2(6, 8), mouth)
		_:
			draw_line(Vector2(110, 159), Vector2(130, 159), mouth, 3.0)
	# 顔の特徴・年齢の表現（誇張しすぎない）
	if female and band != "young":
		for side in [-1.0, 1.0]:
			var ex: float = 120.0 + side * 23.0 + side * 11.0
			draw_line(Vector2(ex, 120), Vector2(ex + side * 4.0, 116), Color("2a2420"), 2.0)
	if band == "mature":
		draw_line(Vector2(102, 140), Vector2(106, 152), shade.darkened(0.15), 1.5)
		draw_line(Vector2(138, 140), Vector2(134, 152), shade.darkened(0.15), 1.5)
		if not female:
			_ellipse(Vector2(120, 162), Vector2(30, 16), Color(hair.r, hair.g, hair.b, 0.18))
	match face_kind:
		"freckles":
			for f in [Vector2(92, 138), Vector2(99, 142), Vector2(96, 147), Vector2(148, 138), Vector2(141, 142), Vector2(144, 147)]:
				_ellipse(f, Vector2(1.6, 1.6), shade.darkened(0.25))
		"scarred":
			draw_line(Vector2(84, 128), Vector2(94, 146), Color("9a5a50"), 2.5)
	# 前髪
	match style:
		"spiky":
			draw_colored_polygon(PackedVector2Array([Vector2(64, 112), Vector2(70, 60), Vector2(86, 80), Vector2(98, 46), Vector2(114, 74), Vector2(128, 40), Vector2(140, 72), Vector2(158, 50), Vector2(164, 82), Vector2(178, 66), Vector2(176, 112), Vector2(150, 92), Vector2(120, 98), Vector2(90, 92)]), hair)
		"crop":
			draw_colored_polygon(PackedVector2Array([Vector2(68, 104), Vector2(76, 70), Vector2(120, 56), Vector2(164, 70), Vector2(172, 104), Vector2(150, 84), Vector2(90, 84)]), hair)
		"long", "long_wavy", "bob":
			draw_colored_polygon(PackedVector2Array([Vector2(62, 140), Vector2(66, 82), Vector2(96, 58), Vector2(144, 58), Vector2(174, 82), Vector2(178, 140), Vector2(166, 100), Vector2(130, 82), Vector2(104, 96), Vector2(76, 104)]), hair)
		"tied":
			draw_colored_polygon(PackedVector2Array([Vector2(66, 110), Vector2(74, 70), Vector2(120, 58), Vector2(166, 70), Vector2(174, 110), Vector2(156, 86), Vector2(84, 86)]), hair)
		_:  # messy
			draw_colored_polygon(PackedVector2Array([Vector2(64, 116), Vector2(68, 74), Vector2(100, 56), Vector2(146, 58), Vector2(176, 80), Vector2(176, 116), Vector2(162, 96), Vector2(150, 108), Vector2(136, 90), Vector2(118, 104), Vector2(104, 88), Vector2(86, 104), Vector2(78, 94)]), hair)
	# 装飾（外見から役割が分かるように）
	match acc:
		"glasses":
			for x in [97.0, 143.0]:
				draw_arc(Vector2(x, 124), 15, 0, TAU, 20, Color("3a3a40"), 3.0)
			draw_line(Vector2(112, 122), Vector2(128, 122), Color("3a3a40"), 3.0)
		"goggles":
			draw_rect(Rect2(66, 76, 108, 12), Color("4a3a2a"))
			for x in [98.0, 142.0]:
				_ellipse(Vector2(x, 82), Vector2(16, 13), Color("6b5a3a"))
				_ellipse(Vector2(x, 82), Vector2(11, 9), Color(0.6, 0.85, 0.95, 0.9))
		"scar":
			draw_line(Vector2(150, 108), Vector2(160, 150), Color("9a5a50"), 3.0)
			draw_colored_polygon(PackedVector2Array([Vector2(98, 150), Vector2(142, 150), Vector2(136, 158), Vector2(104, 158)]), hair.darkened(0.05))
		"earrings":
			_ellipse(Vector2(68, 146), Vector2(4, 6), accent)
			_ellipse(Vector2(172, 146), Vector2(4, 6), accent)
		"eyepatch":
			_ellipse(Vector2(143, 124), Vector2(15, 12), Color("151515"))
			draw_line(Vector2(70, 100), Vector2(172, 136), Color("151515"), 3.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

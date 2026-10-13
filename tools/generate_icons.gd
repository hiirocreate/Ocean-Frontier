extends SceneTree
## アイテムアイコン（64x64 PNG）を図形描画で生成し assets/items/<id>.png に保存する（独自素材）。
## 実行（描画が必要）: xvfb-run -a godot --path . --rendering-driver opengl3 --script res://tools/generate_icons.gd

const SIZE := 64
const CAT_COLORS := {"material": "8a6a4a", "consumable": "3f8a5a", "weapon": "8a3a3a", "armor": "5a5a7a", "tool": "3a6a8a", "ship_part": "2a5a6a", "story": "7a6a2a"}


class IconCanvas extends Control:
	var item_id := ""
	var category := ""
	var label_char := ""
	var font: Font

	func _draw() -> void:
		var c := Color(CAT_COLORS.get(category, "555555"))
		draw_rect(Rect2(0, 0, SIZE, SIZE), Color(0, 0, 0, 0))
		var bg := StyleBoxFlat.new()
		bg.bg_color = c.darkened(0.35)
		bg.border_color = c.lightened(0.3)
		bg.set_border_width_all(3)
		bg.set_corner_radius_all(12)
		draw_style_box(bg, Rect2(2, 2, SIZE - 4, SIZE - 4))
		var drew := _shape(item_id)
		if not drew:
			draw_string(font, Vector2(0, 44), label_char, HORIZONTAL_ALIGNMENT_CENTER, SIZE, 32, Color(1, 1, 1, 0.95))

	func _poly(points: Array, col: Color) -> void:
		draw_colored_polygon(PackedVector2Array(points), col)

	func _shape(id: String) -> bool:
		var w := Color("f0e6d0")
		match id:
			"wood", "hull_plank":
				for i in 3:
					draw_rect(Rect2(12, 16 + i * 12, 40, 9), Color("b07a45").lightened(i * 0.08))
					draw_line(Vector2(14, 20 + i * 12), Vector2(50, 20 + i * 12), Color("7a4a25"), 1.0)
			"scrap_metal", "armor_plate":
				_poly([Vector2(14, 44), Vector2(22, 18), Vector2(42, 14), Vector2(50, 36), Vector2(36, 50)], Color("9aa4a8"))
				draw_line(Vector2(22, 18), Vector2(36, 50), Color("6a7478"), 2.0)
			"rope":
				for r in [18, 12, 6]:
					draw_arc(Vector2(32, 34), r, 0, TAU, 24, Color("d8c08a"), 4.0)
			"cloth", "sail_cloth":
				_poly([Vector2(14, 18), Vector2(50, 14), Vector2(46, 48), Vector2(18, 50)], Color("e0d8c0"))
				draw_line(Vector2(16, 30), Vector2(48, 28), Color("b0a890"), 2.0)
			"plastic":
				_poly([Vector2(20, 14), Vector2(44, 18), Vector2(48, 46), Vector2(16, 44)], Color(0.7, 0.85, 0.95, 0.9))
			"stone":
				_poly([Vector2(14, 40), Vector2(20, 20), Vector2(40, 16), Vector2(50, 34), Vector2(40, 48), Vector2(22, 50)], Color("8a8a84"))
			"canned_food":
				draw_rect(Rect2(18, 18, 28, 30), Color("c0c4c8"))
				draw_rect(Rect2(18, 26, 28, 12), Color("c0503a"))
			"coconut", "potato":
				draw_circle(Vector2(32, 34), 15, Color("7a5a3a") if id == "coconut" else Color("c0a060"))
			"water_bottle":
				draw_rect(Rect2(24, 22, 16, 28), Color(0.6, 0.85, 1.0, 0.9))
				draw_rect(Rect2(27, 14, 10, 8), Color("3a7ab0"))
			"medkit", "medicine":
				draw_rect(Rect2(14, 18, 36, 30), w)
				draw_rect(Rect2(28, 22, 8, 22), Color("d03a3a"))
				draw_rect(Rect2(21, 29, 22, 8), Color("d03a3a"))
			"raw_fish", "cooked_fish":
				var fc := Color("8ab0c0") if id == "raw_fish" else Color("c0803a")
				_poly([Vector2(12, 32), Vector2(30, 20), Vector2(44, 32), Vector2(30, 44)], fc)
				_poly([Vector2(42, 32), Vector2(54, 22), Vector2(54, 42)], fc)
			"hammer":
				draw_line(Vector2(20, 50), Vector2(40, 22), Color("a07040"), 5.0)
				_poly([Vector2(30, 14), Vector2(50, 26), Vector2(46, 32), Vector2(26, 20)], Color("9aa4a8"))
			"repair_kit", "tool_parts", "repair_supplies":
				draw_arc(Vector2(32, 32), 12, 0, TAU, 8, Color("c0c4c8"), 6.0)
				draw_circle(Vector2(32, 32), 5, Color("c0c4c8"))
			"spear", "harpoon":
				draw_line(Vector2(14, 52), Vector2(46, 16), Color("a07040"), 4.0)
				_poly([Vector2(44, 12), Vector2(54, 10), Vector2(50, 20)], Color("c0c4c8"))
			"machete":
				_poly([Vector2(16, 48), Vector2(46, 14), Vector2(52, 18), Vector2(24, 50)], Color("c0c4c8"))
				draw_line(Vector2(14, 52), Vector2(22, 44), Color("5a3a20"), 5.0)
			"bow":
				draw_arc(Vector2(24, 32), 20, -1.2, 1.2, 16, Color("a07040"), 4.0)
				draw_line(Vector2(31, 13), Vector2(31, 51), w, 1.5)
			"pistol":
				_poly([Vector2(14, 22), Vector2(48, 22), Vector2(48, 30), Vector2(28, 30), Vector2(26, 48), Vector2(18, 48), Vector2(20, 30), Vector2(14, 30)], Color("4a4e52"))
			"ammo":
				for i in 3:
					draw_rect(Rect2(18 + i * 10, 22, 7, 22), Color("d0a040"))
			"leather_armor":
				_poly([Vector2(18, 16), Vector2(46, 16), Vector2(50, 48), Vector2(14, 48)], Color("8a5a3a"))
				draw_line(Vector2(32, 16), Vector2(32, 48), Color("5a3a20"), 2.0)
			"scrap_shield":
				_poly([Vector2(32, 12), Vector2(50, 20), Vector2(46, 42), Vector2(32, 52), Vector2(18, 42), Vector2(14, 20)], Color("8a949a"))
			"diving_gear", "oxygen_tank":
				draw_rect(Rect2(22, 14, 20, 36), Color("e0a030") if id == "oxygen_tank" else Color("3a8ab0"))
				draw_circle(Vector2(32, 30), 7, Color(0.7, 0.9, 1.0))
			"binoculars":
				draw_circle(Vector2(24, 34), 9, Color("3a3e42"))
				draw_circle(Vector2(40, 34), 9, Color("3a3e42"))
			"compass":
				draw_circle(Vector2(32, 32), 18, Color("c0a060"))
				_poly([Vector2(32, 16), Vector2(36, 32), Vector2(28, 32)], Color("d03a3a"))
			"sea_chart", "research_log", "decoded_report":
				draw_rect(Rect2(14, 16, 36, 32), Color("e8dcc0"))
				for i in 4:
					draw_line(Vector2(18, 22 + i * 6), Vector2(46, 22 + i * 6), Color("8a7a5a"), 1.5)
			"radio", "comm_device", "electronics":
				draw_rect(Rect2(14, 22, 36, 24), Color("3a4a3a") if id == "electronics" else Color("4a4e52"))
				draw_line(Vector2(42, 22), Vector2(48, 10), Color("c0c4c8"), 2.0)
				draw_circle(Vector2(24, 34), 5, Color("80d0a0"))
			"survey_kit", "resonance_scanner":
				draw_circle(Vector2(32, 34), 16, Color("2a4a6a"))
				draw_arc(Vector2(32, 34), 10, 0, TAU, 20, Color("cfe8ff"), 2.0)
				draw_line(Vector2(32, 34), Vector2(42, 26), Color("cfe8ff"), 2.0)
			"fuel":
				draw_rect(Rect2(18, 18, 28, 32), Color("b03a2a"))
				draw_rect(Rect2(36, 12, 8, 8), Color("4a4e52"))
			"rudder":
				_poly([Vector2(28, 12), Vector2(36, 12), Vector2(40, 50), Vector2(24, 50)], Color("a07040"))
			"engine_part":
				draw_rect(Rect2(14, 20, 36, 26), Color("5a5e62"))
				draw_circle(Vector2(26, 33), 6, Color("8a8e92"))
			"ship_cannon":
				draw_rect(Rect2(12, 26, 34, 12), Color("3a3e42"))
				draw_circle(Vector2(20, 44), 6, Color("6a4a2a"))
			"cargo_crate":
				draw_rect(Rect2(16, 18, 32, 30), Color("a07a4a"))
				draw_line(Vector2(16, 18), Vector2(48, 48), Color("6e5130"), 2.0)
			"old_key":
				draw_circle(Vector2(22, 32), 8, Color("c9a45a"))
				draw_line(Vector2(30, 32), Vector2(52, 32), Color("c9a45a"), 4.0)
				draw_line(Vector2(46, 32), Vector2(46, 40), Color("c9a45a"), 4.0)
			"encrypted_data":
				draw_rect(Rect2(18, 14, 28, 36), Color("2a3a4a"))
				draw_string(font, Vector2(18, 40), "01", HORIZONTAL_ALIGNMENT_CENTER, 28, 16, Color("80d0ff"))
			"relic":
				_poly([Vector2(32, 10), Vector2(46, 32), Vector2(32, 54), Vector2(18, 32)], Color("cfe8ff"))
				_poly([Vector2(32, 18), Vector2(40, 32), Vector2(32, 46), Vector2(24, 32)], Color("ffffff"))
			"old_letter":
				draw_rect(Rect2(14, 20, 36, 26), Color("e8dcc0"))
				_poly([Vector2(14, 20), Vector2(32, 34), Vector2(50, 20)], Color("c8bca0"))
			_:
				return false
		return true


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var data := GameData.load_default()
	var font: Font = load("res://assets/fonts/NotoSansJP-Regular.ttf")
	var vp := SubViewport.new()
	vp.size = Vector2i(SIZE, SIZE)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var canvas := IconCanvas.new()
	canvas.size = Vector2(SIZE, SIZE)
	canvas.font = font
	vp.add_child(canvas)
	DirAccess.make_dir_recursive_absolute("res://assets/items")
	var n := 0
	for id in data.items:
		canvas.item_id = id
		canvas.category = str(data.items[id].get("category", ""))
		canvas.label_char = str(data.items[id].get("name", "?")).substr(0, 1)
		canvas.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path("res://assets/items/%s.png" % id))
		n += 1
	print("アイコン %d 個を生成" % n)
	quit()

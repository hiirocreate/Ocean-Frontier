extends SceneTree
## assets/ui/icon.svg から Android ランチャー用アイコン（PNG）を生成する。
## 実行: godot --headless --path . --script res://tools/generate_launcher_icons.gd

func _initialize() -> void:
	var svg := FileAccess.get_file_as_string("res://assets/ui/icon.svg")
	for spec in [["icon_192.png", 192.0 / 128.0], ["icon_432_fg.png", 432.0 / 128.0]]:
		var img := Image.new()
		img.load_svg_from_string(svg, spec[1])
		img.save_png(ProjectSettings.globalize_path("res://assets/ui/" + spec[0]))
		print("生成: ", spec[0], " ", img.get_size())
	var bg := Image.create(432, 432, false, Image.FORMAT_RGBA8)
	bg.fill(Color("0b3a5c"))
	bg.save_png(ProjectSettings.globalize_path("res://assets/ui/icon_432_bg.png"))
	print("生成: icon_432_bg.png")
	quit()

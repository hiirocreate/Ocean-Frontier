extends SceneTree
## ビジュアル素材（SVG立ち絵・斧モデル・トゥーンシェーダー）の描画確認。
## xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --script res://tools/art/preview_assets.gd
## 出力: build/screenshots/art_preview.png

const SVG := "res://assets/characters/portraits/protagonist_youth_cel.svg"
const AXE := "res://assets/items/models/axe.glb"
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func check(cond: bool, msg: String) -> void:
	print("  ", "OK  " if cond else "FAIL", " ", msg)
	if not cond:
		failures.append(msg)


func load_axe() -> Node3D:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(ProjectSettings.globalize_path(AXE), state) != OK:
		return null
	return doc.generate_scene(state) as Node3D


func _run() -> void:
	var w := Node3D.new()
	root.add_child(w)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("3a5f7a")
	w.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -75, 0)
	sun.shadow_enabled = true
	w.add_child(sun)
	var cam := Camera3D.new()
	cam.position = Vector3(0.9, 0.75, 2.2)
	w.add_child(cam)
	cam.look_at(Vector3(0.9, 0.45, 0))

	# 斧（Blenderスクリプトで生成した glb）にトゥーンを適用
	var axe := load_axe()
	check(axe != null, "斧モデル（glb）を読み込める")
	if axe:
		w.add_child(axe)
		axe.scale = Vector3.ONE * 1.6
		axe.position = Vector3(0.35, 0.0, 0)
		axe.rotation_degrees = Vector3(0, 70, -12)
		var tris := 0
		for mi in axe.find_children("*", "MeshInstance3D", true, false):
			for s in (mi as MeshInstance3D).mesh.get_surface_count():
				tris += (mi as MeshInstance3D).mesh.surface_get_array_index_len(s) / 3
		check(tris >= 150 and tris <= 200, "斧の三角形数 %d（150〜200）" % tris)
		check(Toon.apply(axe) >= 3, "斧の3マテリアルをトゥーンに置換")
	# 2階調・3階調の比較用の球
	for i in 2:
		var sphere := MeshInstance3D.new()
		sphere.mesh = SphereMesh.new()
		(sphere.mesh as SphereMesh).radius = 0.22
		(sphere.mesh as SphereMesh).height = 0.44
		sphere.position = Vector3(1.05 + i * 0.55, 0.35, 0)
		sphere.material_override = Toon.material(Color("708090") if i == 0 else Color("8B4513"), false, 3.5, 2 + i)
		w.add_child(sphere)
	# 既存の主人公3Dモデル（頂点カラー）にも適用できること
	var model := CharacterModel.new()
	model.apply_look({})
	w.add_child(model)
	model.position = Vector3(1.3, 0.0, -0.9)
	check(Toon.apply(model) > 0, "既存のキャラクターモデル（頂点カラー）にトゥーンを適用")

	# SVG立ち絵（実行時ラスタライズ）
	var img := Image.new()
	var err := img.load_svg_from_string(FileAccess.get_file_as_string(SVG), 0.8)
	check(err == OK and img.get_width() == 480, "SVG立ち絵をラスタライズできる")
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var tr := TextureRect.new()
	tr.texture = ImageTexture.create_from_image(img)
	tr.position = Vector2(10, 40)
	tr.size = Vector2(480, 640)
	layer.add_child(tr)

	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://build/screenshots")
	if DisplayServer.get_name() != "headless":
		root.get_texture().get_image().save_png("res://build/screenshots/art_preview.png")
		print("  screenshot: art_preview")
	print("==== ART: %s ====" % ("OK" if failures.is_empty() else "%d件失敗" % failures.size()))
	quit(0 if failures.is_empty() else 1)

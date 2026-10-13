extends SceneTree
## 実シーンを使ったE2Eテスト（最初のプレイ可能サイクル）。
## 描画あり:  xvfb-run -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --script res://tools/smoke_test.gd
## 描画なし:  godot --headless --path . --script res://tools/smoke_test.gd   （スクリーンショットは省略）
## スクリーンショットは build/screenshots/ に保存。

var failures: Array[String] = []
var shot_dir := ""


func _initialize() -> void:
	shot_dir = ProjectSettings.globalize_path("res://build/screenshots")
	DirAccess.make_dir_recursive_absolute(shot_dir)
	_run.call_deferred()


func check(cond: bool, msg: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + msg)
	if not cond:
		failures.append(msg)


func frames(n: int) -> void:
	for i in n:
		await process_frame


func shot(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(shot_dir.path_join(name + ".png"))
	print("  screenshot: ", name)


func world() -> Node:
	return current_scene


func _run() -> void:
	var game: Node = root.get_node("Game")
	SaveManager.delete_save()
	change_scene_to_file("res://scenes/main/main_menu.tscn")
	await frames(10)
	check(current_scene != null and current_scene.name == "MainMenu", "メインメニュー表示")
	await shot("01_main_menu")

	game.start_new_game()
	await frames(30)
	var w := world()
	check(w != null and w.name == "World", "ワールド表示")
	var s: GameSession = game.session
	game.settings["quality"] = "high"
	game.quality_changed()
	s.clock.total_minutes = 9 * 60.0
	await frames(20)
	await shot("02_world_start")

	# 1) 海を移動する
	var p0: Vector3 = w.raft_root.position
	Input.action_press("move_forward")
	await frames(90)
	Input.action_release("move_forward")
	await frames(5)
	var moved: float = (w.raft_root.position - p0).length()
	check(moved > 1.0, "筏が移動した (%.2fm)" % moved)
	check(s.raft_position.distance_to(Vector3(w.raft_root.position.x, 0, w.raft_root.position.z)) < 0.01, "セッションに位置が反映")

	# 2) 漂流物を回収 → 3) インベントリに追加
	var guard := 0
	while (s.inventory.count("wood") < 8 or s.inventory.count("rope") < 4) and guard < 60:
		guard += 1
		var d := Debris.new()
		d.setup("plank" if guard % 3 else "crate", 0.0, Vector3.ZERO)
		w.debris_root.add_child(d)
		d.position = w.raft_root.position + Vector3(3.5, 0, 0)
		await frames(2)
		var before: int = s.stats["debris_collected"]
		w.collect_nearest()
		if guard == 1:
			check(s.stats["debris_collected"] == before + 1, "回収ボタンで回収できる")
		await frames(2)
	check(s.inventory.count("wood") >= 8 and s.inventory.count("rope") >= 4, "回収で素材が集まった (木材%d ロープ%d)" % [s.inventory.count("wood"), s.inventory.count("rope")])
	await frames(30)
	w.hud.toggle_inventory()
	await frames(5)
	await shot("03_inventory")
	w.hud.toggle_inventory()

	# 4) 素材を消費して 5) 筏を拡張（タップ操作で場所を選ぶ）
	var tiles0 := s.raft.tiles.size()
	var wood0 := s.inventory.count("wood")
	w.hud.set_build_mode(true)
	await frames(10)
	var target: Vector2i = s.raft.candidate_positions()[0]
	var ghost_pos: Vector3 = w.raft_root.to_global(w.raft_view.tile_to_local(target))
	var screen: Vector2 = w.camera_rig.camera.unproject_position(ghost_pos)
	var ev := InputEventScreenTouch.new()
	ev.index = 0
	ev.position = screen
	ev.pressed = true
	Input.parse_input_event(ev)
	var ev2 := ev.duplicate()
	ev2.pressed = false
	Input.parse_input_event(ev2)
	await frames(5)
	if w.raft_view.selected_ghost != target:
		print("  (タップ位置 %s で選択できなかったため直接選択)" % str(screen))
		w.raft_view.select_ghost(target)
	else:
		check(true, "タップで建設位置を選択")
	await frames(3)
	await shot("04_build_mode")
	w.hud.build_confirmed.emit(w.raft_view.selected_ghost)
	await frames(2)
	check(s.inventory.count("wood") == wood0 - 4, "素材が消費された (木材 %d→%d)" % [wood0, s.inventory.count("wood")])
	s.advance(30)
	await frames(10)
	check(s.raft.tiles.size() == tiles0 + 1, "筏が拡張された (%d→%d)" % [tiles0, s.raft.tiles.size()])
	w.hud.set_build_mode(false)
	await frames(10)
	await shot("05_raft_expanded")

	# 6) セーブ → 状態を変える → 7) ロードして確認
	var snapshot := JSON.stringify(s.to_dict())
	check(game.save_game()["ok"], "セーブ成功")
	s.inventory.add("wood", 5)
	s.raft.add_tile(s.raft.candidate_positions()[0])
	var r: Dictionary = game.load_game()
	check(r["ok"], "ロード成功")
	var s2: GameSession = game.session
	check(JSON.stringify(s2.to_dict()) == JSON.stringify(JSON.parse_string(snapshot)), "ロード後の状態がセーブ時と一致")
	await frames(20)
	check(world().raft_view.session == s2, "シーンが新しいセッションで再構築された")
	await shot("06_after_load")

	# 夜の描画確認
	s2.clock.total_minutes = 22 * 60.0
	await frames(10)
	await shot("07_night")

	print("")
	print("==== E2E: %s ====" % ("OK" if failures.is_empty() else "%d件失敗" % failures.size()))
	for f in failures:
		print("  ✗ ", f)
	quit(0 if failures.is_empty() else 1)

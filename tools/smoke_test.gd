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

	game.data.balance["events"]["chance_multiplier"] = 0.0  # E2Eではランダムイベントを止めて結果を安定させる
	# 主人公作成画面
	game.open_creation(false)
	await frames(20)
	var cc: Control = current_scene
	check(cc != null and cc.has_method("set_age"), "主人公作成画面が表示される")
	cc._name_edit.text = "ハル"
	cc._name_edit.text_changed.emit("ハル")
	cc._gender_buttons["female"].pressed.emit()
	check(not cc.set_age(9) and not cc.set_age(41), "範囲外の年齢は拒否される")
	check(cc.set_age(14) and int(cc._age_slider.value) == 14, "年齢入力とスライダーが同期する")
	cc._bg_buttons["drift_ship"].pressed.emit()
	cc._trait_checks["observant"].button_pressed = true
	await frames(10)
	await shot("00a_creation_basic")
	cc._tabs.current_tab = 2
	await frames(10)
	await shot("00b_creation_background")
	cc._tabs.current_tab = cc._tabs.get_tab_count() - 1
	await frames(10)
	await shot("00c_creation_confirm")
	check(cc.profile.age_band() == "young" and cc.profile.has_trait(game.data, "observant") and cc.profile.has_trait(game.data, "drift_veteran"), "作成内容がプロフィールに反映される")
	cc._start_button.pressed.emit()
	await frames(30)
	check(game.session != null and game.session.profile.name == "ハル" and game.session.profile.gender == "female" and game.session.profile.age == 14, "作成した主人公で開始される")
	check(game.session.inventory.count("wood") > 0, "背景の初期アイテムを所持")
	await frames(5)
	await shot("00d_young_start")
	# 以降は作成をスキップした既定の主人公で進行確認
	game.start_new_game()
	await frames(30)
	check(game.session.profile.name == "ナギ", "作成スキップ時は既定の主人公")
	var w := world()
	check(w != null and w.name == "World", "ワールド表示")
	var s: GameSession = game.session
	check(not s.pending_dialogue.is_empty() or w.hud.dialogue_panel.visible, "新しいゲームで第1章の導入が表示される")
	await frames(5)
	await shot("02a_intro")
	for i in 5:
		if w.hud.dialogue_panel.visible:
			w.hud.dialogue_panel.runner.advance()
	await frames(3)
	check(not w.hud.dialogue_panel.visible, "導入を読み終えると閉じる")
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

	# 2) 漂流物を回収 → 3) インベントリに追加（抽選の偏りで重量上限に達しないよう余裕を持たせる）
	s.inventory.max_weight += 100.0
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
	if DisplayServer.get_name() == "headless":
		print("  (ヘッドレスではタッチ入力が届かないため、タップ処理を直接呼び出し)")
		w._on_tap(screen)
	check(w.raft_view.selected_ghost == target, "タップで建設位置を選択")
	await frames(3)
	await shot("04_build_mode")
	w.hud.build_confirmed.emit("expand_raft", {"x": w.raft_view.selected_ghost.x, "z": w.raft_view.selected_ghost.y})
	await frames(2)
	check(s.inventory.count("wood") == wood0 - 4, "素材が消費された (木材 %d→%d)" % [wood0, s.inventory.count("wood")])
	s.advance(30)
	await frames(10)
	check(s.raft.tiles.size() == tiles0 + 1, "筏が拡張された (%d→%d)" % [tiles0, s.raft.tiles.size()])
	w.hud.set_build_mode(false)
	await frames(10)
	await shot("05_raft_expanded")

	# 建築物: 浄水器を建てて、タップで操作パネルを開く
	s.inventory.add_many({"wood": 6, "cloth": 4, "scrap_metal": 3, "plastic": 3, "hammer": 1}, true)
	w.hud.set_build_mode(true)
	w.hud.set_build_type("water_purifier")
	await frames(5)
	var btile: Vector2i = s.raft.building_candidates()[0]
	w.raft_view.select_ghost(btile)
	await frames(3)
	await shot("05b_build_purifier")
	w.hud.build_confirmed.emit(w.hud.build_action_id(), w.hud.build_params(btile))
	s.advance(40)
	await frames(5)
	check(s.raft.building_at(btile) != "", "浄水器を設置できた")
	w.hud.set_build_mode(false)
	s.advance(160)
	await frames(5)
	await create_timer(1.0).timeout  # カメラの追従が落ち着くまで待つ
	var bpos: Vector3 = w.raft_root.to_global(w.raft_view.tile_to_local(btile) + Vector3(0, 0.6, 0))
	var bscreen: Vector2 = w.camera_rig.camera.unproject_position(bpos)
	var t1 := InputEventScreenTouch.new()
	t1.position = bscreen
	t1.pressed = true
	Input.parse_input_event(t1)
	var t2 := t1.duplicate()
	t2.pressed = false
	Input.parse_input_event(t2)
	await frames(5)
	if not w.hud._building_panel.visible and DisplayServer.get_name() == "headless":
		print("  (ヘッドレスではタッチ入力が届かないため、タップ処理を直接呼び出し)")
		w._on_tap(bscreen)
	check(w.hud._building_panel.visible, "建築物をタップすると操作パネルが開く")
	await shot("05c_building_panel")
	var water0 := s.inventory.count("water_bottle")
	s.harvest(s.raft.building_at(btile))
	check(s.inventory.count("water_bottle") >= water0 + 1, "浄水器から水を収穫")
	w.hud.hide_building_panel()

	# 仲間: 漂流者を救助 → 2D会話 → 加入 → 作業を割り当て
	w.spawn_encounter("rescue", "mira")
	w.encounter.position = w.raft_root.position + Vector3(4.0, 0, 0)
	await frames(3)
	w.collect_nearest()
	await frames(3)
	check(w.hud.dialogue_panel.visible, "救助で会話が始まる")
	w.hud.dialogue_panel.runner.advance()
	await frames(20)
	await shot("08_dialogue")
	var cs: Array = w.hud.dialogue_panel.runner.choices()
	w.hud.dialogue_panel.runner.choose(int(cs.filter(func(c): return c["text"] == "筏に引き上げる")[0]["index"]))
	w.hud.dialogue_panel.runner.choose(0)
	w.hud.dialogue_panel.runner.advance()
	await frames(5)
	check(s.crew.is_aboard("mira"), "会話の選択で仲間が加入")
	check(not w.hud.dialogue_panel.visible, "会話が閉じる")
	check(w.encounter == null, "救助した小舟が消える")
	check(w.crew_root.get_child_count() == 1, "筏の上に仲間が表示される")
	w.hud.toggle_crew()
	await frames(5)
	check(s.crew.assign_job("mira", "fishing", s) == "", "作業を割り当て")
	w.hud.crew_panel.refresh()
	await frames(5)
	await shot("09_crew_panel")
	w.hud.toggle_crew()

	# 探索: 座礁した漁船へ移動 → 調べる → 探索
	w.raft_root.position = s.site_position("wreck_fishing_boat") + Vector3(14, 0, 8)
	await frames(5)
	await create_timer(0.7).timeout
	check(s.is_site_discovered("wreck_fishing_boat"), "近づくと地点を発見")
	check(w.hud.inspect_button.visible, "「調べる」ボタンが出る")
	w.hud.show_site_panel(s.nearby_site())
	await frames(5)
	await shot("10_site_panel")
	var exp0: int = s.stats.get("sites_explored", 0)
	var rr := s.actions.start("explore_surface", {"site": "wreck_fishing_boat"})
	check(rr["ok"], "探索を開始できる")
	s.advance(40)
	check(int(s.stats.get("sites_explored", 0)) == exp0 + 1, "探索が完了")
	w.hud._site_panel.visible = false
	# 戦闘
	s.inventory.add_many({"harpoon": 1}, true)
	s.start_combat("scavengers", "raft")
	await frames(5)
	check(w.hud.combat_panel.visible, "戦闘画面が出る")
	await shot("11_combat")
	w.hud.combat_panel._choose("fight")
	await frames(5)
	await shot("12_combat_result")
	check(s.pending_combat.is_empty(), "戦闘が解決")
	w.hud.combat_panel._result = {}
	await frames(3)
	# 海域の移動
	w.raft_root.position = Vector3(700, 0, 100)
	await frames(3)
	await create_timer(0.7).timeout
	check(s.zone_id == "rust_reef", "錆の礁に入った")
	await create_timer(3.2).timeout
	await shot("13_rust_reef")
	w.hud.toggle_map()
	await frames(5)
	await shot("14_map")
	w.hud.toggle_map()

	# 勢力のリーダー（悪役）との会話の場面
	s.pending_dialogue = {"id": "volg_radio", "nodes": game.data.dialogues["volg_radio"]["nodes"]}
	await frames(10)
	if w.hud.dialogue_panel.visible:
		w.hud.dialogue_panel.runner.advance()
	await frames(5)
	check(w.hud.dialogue_panel.visible and w.hud.dialogue_panel.portrait.visible, "悪役（ヴォルグ）の立ち絵付きの会話")
	await shot("14b_villain_dialogue")
	for i in 6:
		if not w.hud.dialogue_panel.visible:
			break
		var r: DialogueRunner = w.hud.dialogue_panel.runner
		if not r.choices().is_empty():
			r.choose(int(r.choices()[0]["index"]))
		else:
			r.advance()
		await frames(3)

	# 勢力・交易: 浮遊市場へ → 交易画面で買い物
	w.raft_root.position = s.site_position("tide_union_market") + Vector3(20, 0, 10)
	await frames(3)
	await create_timer(0.7).timeout
	check(s.zone_id == "tide_union_waters", "潮流連合の海に入った")
	check(w.hud.inspect_button.visible, "市場で「調べる」が出る")
	w.hud.show_site_panel(s.nearby_site())
	await frames(3)
	s.money = 200
	s.inventory.max_weight += 40.0
	w.hud._site_panel.visible = false
	w.hud.faction_panel.open_trade("tide_union")
	await frames(5)
	await shot("15_trade")
	var food0 := s.inventory.count("canned_food")
	check(Trade.buy(s, "tide_union", "canned_food", 3) == "", "市場で購入")
	check(s.inventory.count("canned_food") == food0 + 3, "購入品が増える")
	w.hud.faction_panel.visible = false
	w.hud.faction_panel.open_info()
	await frames(5)
	await shot("16_factions")
	w.hud.faction_panel.visible = false
	# 艦隊: 船を得て船員を乗せ、偵察に出す
	var ship := s.fleet.add_ship("sloop", s.clock.day())
	s.fleet.sailors_pool = 3
	s.fleet.add_sailors(ship, 3)
	s.inventory.add_many({"water_bottle": 4}, true)
	var mr := s.start_fleet_mission(ship, "scout", "merchant_convoy")
	check(mr["ok"], "艦隊任務を開始 %s" % str(mr.get("problems", [])))
	var dock := s.fleet.add_ship("gunboat", s.clock.day())
	await frames(5)
	check(w.ships_root.get_child_count() >= 1, "港の船が3Dで表示される")
	await shot("16b_docked_ship")
	w.hud.fleet_panel.open()
	await frames(5)
	await shot("17_fleet")
	s.advance(7 * 60)
	check(s.flags.get("scouted_merchant_convoy", false), "偵察任務が完了")
	w.hud.fleet_panel.visible = false

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

	# 嵐の描画確認
	s2.clock.total_minutes = 1440.0 * 2 + 11 * 60
	s2.set_weather("storm", 3)
	await create_timer(5.5).timeout
	await shot("18_storm")
	world().hud.quest_panel.open()
	await frames(5)
	await shot("19_record")
	world().hud.quest_panel.visible = false
	# 夜の描画確認
	s2.weather = {"type": "clear", "until": 0.0}
	s2.clock.total_minutes = 22 * 60.0
	await frames(10)
	await shot("07_night")

	# 作成後の名前・外見の変更（性別・年齢は固定）
	game.open_creation(true)
	await frames(20)
	var ce: Control = current_scene
	check(ce.edit_mode and ce._age_slider.editable == false and ce._gender_buttons["male"].disabled, "変更画面では性別・年齢を変更できない")
	ce._name_edit.text = "ナギサ"
	ce._name_edit.text_changed.emit("ナギサ")
	ce.profile.appearance["hair_color"] = str(game.data.appearance["hair_colors"].back()["id"])
	ce._refresh()
	await frames(5)
	await shot("00e_profile_edit")
	var age_before: int = game.session.profile.age
	ce._start_button.pressed.emit()
	await frames(30)
	check(game.session.profile.name == "ナギサ" and game.session.profile.appearance["hair_color"] == str(game.data.appearance["hair_colors"].back()["id"]) and game.session.profile.age == age_before and current_scene.name == "World", "名前の変更が反映されワールドに戻る")

	# エンディング画面
	s2.flags["pirate_crew_founded"] = true
	s2.story.ending = "keep_secret"
	game.show_ending()
	await frames(30)
	check(current_scene.name == "Ending", "エンディング画面が表示される")
	await create_timer(1.0).timeout
	await shot("20_ending")
	print("")
	print("==== E2E: %s ====" % ("OK" if failures.is_empty() else "%d件失敗" % failures.size()))
	for f in failures:
		print("  ✗ ", f)
	quit(0 if failures.is_empty() else 1)

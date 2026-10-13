extends SceneTree
## 描画負荷の計測（大きな筏・多数の設備・仲間5人）。描画呼び出し数とフレーム時間を画質ごとに出力する。
## 実行: xvfb-run -a godot --path . --rendering-driver opengl3 --script res://tools/perf_test.gd
## 注意: Xvfb + llvmpipe（CPU描画）での値は実機より大幅に遅い。描画呼び出し数の比較に使う。

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game: Node = root.get_node("Game")
	game.data.balance["events"]["chance_multiplier"] = 0.0
	game.start_new_game()
	for i in 30:
		await process_frame
	var w := current_scene
	var s: GameSession = game.session
	s.pending_dialogue = {}
	while s.raft.tiles.size() < 60:
		s.raft.add_tile(s.raft.candidate_positions()[0])
	var bids := ["storage_box", "workbench", "water_purifier", "fishing_net", "grill", "bed", "garden", "medical_station", "weapon_bench", "radio_station", "defense_wall", "research_desk"]
	var free := s.raft.building_candidates()
	for i in bids.size():
		s.raft.place_building(bids[i], free[i * 3], 60)
	for m in ["mira", "tobi", "garrett", "selene", "rook"]:
		s.crew.recruit(m, 1)
	for q in ["low", "medium", "high"]:
		game.settings["quality"] = q
		game.quality_changed()
		for i in 20:
			await process_frame
		var t0 := Time.get_ticks_usec()
		var frames := 60
		var calls := 0
		var prims := 0
		for i in frames:
			await process_frame
			calls = maxi(calls, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
			prims = maxi(prims, int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
		var ms := (Time.get_ticks_usec() - t0) / 1000.0 / frames
		print("PERF quality=%s draw_calls=%d primitives=%d frame_ms=%.1f objects=%d mem_MB=%.1f" % [q, calls, prims, ms,
			int(Performance.get_monitor(Performance.OBJECT_COUNT)), Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0])
	quit()

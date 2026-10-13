extends TestCase

const PATH := "user://test_saves/slot_test.json"


func before_each() -> void:
	SaveManager.delete_save(PATH)


func test_roundtrip_matches() -> void:
	var s := new_session(777)
	s.inventory.add_many({"wood": 10, "rope": 4, "hammer": 1})
	s.inventory.wear(int(s.inventory.instances[0]["uid"]), 5)
	s.actions.start("expand_raft", {"x": 2, "z": 0})
	s.advance(3)
	s.raft_position = Vector3(12.5, 0, -4)
	s.flags["test_flag"] = true
	var r := SaveManager.save_session(s, PATH)
	check(r["ok"], "保存成功 " + str(r["error"]))
	var l := SaveManager.load_session(s.data, PATH)
	check(l["ok"], "ロード成功 " + str(l["error"]))
	var s2: GameSession = l["session"]
	eq(JSON.stringify(s2.to_dict()), JSON.stringify(JSON.parse_string(JSON.stringify(s.to_dict()))), "保存前後で状態が一致")
	eq(s2.inventory.count("wood"), s.inventory.count("wood"), "木材")
	eq(s2.actions.jobs.size(), 1, "進行中の作業も保持")
	check(s2.flags.get("test_flag", false), "フラグ")


func test_job_completes_after_load_without_double_consumption() -> void:
	var s := new_session(1)
	s.inventory.stacks = {"wood": 4, "rope": 2}
	s.actions.start("expand_raft", {"x": 2, "z": 0})
	SaveManager.save_session(s, PATH)
	var s2: GameSession = SaveManager.load_session(s.data, PATH)["session"]
	eq(s2.inventory.count("wood"), 0, "預かり中の素材は在庫に戻らない")
	s2.advance(60)
	check(s2.raft.has_tile(Vector2i(2, 0)), "ロード後に完成")
	eq(s2.inventory.count("wood"), 0, "二重消費・二重返却なし")


func test_rng_continuity() -> void:
	var s := new_session(42)
	SaveManager.save_session(s, PATH)
	var a := s.collect_debris("crate")
	var s2: GameSession = SaveManager.load_session(s.data, PATH)["session"]
	var b := s2.collect_debris("crate")
	eq(JSON.stringify(b), JSON.stringify(a), "ロード後の抽選結果が一致")


func test_corrupted_file_detected_and_backup_used() -> void:
	var s := new_session(5)
	s.inventory.add("wood", 1)
	SaveManager.save_session(s, PATH)
	var good_wood := s.inventory.count("wood")
	s.inventory.add("wood", 3)
	SaveManager.save_session(s, PATH)
	# 本ファイルを壊す
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string("{\"format\":1,\"checksum\":\"x\",\"payload\":\"{}\"}")
	f.close()
	var l := SaveManager.load_session(s.data, PATH)
	check(l["ok"], "バックアップから復旧")
	check(l["recovered_from_backup"], "復旧フラグ")
	eq(l["session"].inventory.count("wood"), good_wood, "1つ前の状態")


func test_garbage_file_fails_safely() -> void:
	DirAccess.make_dir_recursive_absolute(PATH.get_base_dir())
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string("not json at all")
	f.close()
	var l := SaveManager.load_session(game_data(), PATH)
	check(not l["ok"], "壊れたデータは失敗として返す")
	check(str(l["error"]) != "", "エラー内容がある")


func test_missing_required_section() -> void:
	var s := GameSession.new(game_data())
	var r := s.from_dict({"clock": {}})
	check(not r["errors"].is_empty(), "必須項目の欠落を検出")


func test_future_format_rejected() -> void:
	DirAccess.make_dir_recursive_absolute(PATH.get_base_dir())
	var payload := "{}"
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"format": 99, "checksum": payload.md5_text(), "payload": payload}))
	f.close()
	check(not SaveManager.load_session(game_data(), PATH)["ok"], "未来の形式は拒否")

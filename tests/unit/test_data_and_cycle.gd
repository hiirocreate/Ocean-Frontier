extends TestCase
## データ検証と「最初のプレイ可能なサイクル」の統合テスト。


func test_shipped_data_is_valid() -> void:
	var errors := DataValidator.validate(game_data())
	eq(errors.size(), 0, "データ検証エラー: %s" % str(errors))


func test_validator_detects_bad_references() -> void:
	var d := game_data()
	d.actions["bad"] = {"id": "bad", "inputs": {"ghost": 1, "wood": -2}, "tools": [{"item": "wood"}], "facilities": ["nope"], "success_chance": 2}
	d.items["bad_icon"] = {"id": "bad_icon", "name": "x", "category": "material", "weight": 1, "icon": "res://nope.png"}
	d.items["no_icon"] = {"id": "no_icon", "name": "y", "category": "material", "weight": 1}
	var errors := DataValidator.validate(d)
	var joined := "\n".join(errors)
	check(joined.contains("ghost"), "存在しないアイテム参照")
	check(joined.contains("数量が不正"), "不正な数値")
	check(joined.contains("nope"), "存在しない設備")
	check(joined.contains("success_chance"), "確率範囲")
	check(joined.contains("アイコンが存在しません"), "存在しない画像パス")
	check(joined.contains("アイコンがありません"), "アイコン未設定")
	check(joined.contains("スタック不可"), "工具の種類")


func test_loot_is_deterministic() -> void:
	var a := new_session(99)
	var b := new_session(99)
	for i in 5:
		eq(JSON.stringify(a.collect_debris("plank")), JSON.stringify(b.collect_debris("plank")), "同じシードなら同じ結果")


func test_collect_respects_capacity() -> void:
	var s := new_session(3)
	s.inventory.max_weight = s.inventory.total_weight()
	var r := s.collect_debris("crate")
	eq(r["added"].size(), 0, "満杯なら何も入らない")
	check(not r["lost"].is_empty(), "失われた分が報告される")


## 移動 → 回収 → インベントリ追加 → 素材消費 → 筏拡張 → セーブ → ロード
func test_first_playable_cycle() -> void:
	var path := "user://test_saves/cycle.json"
	SaveManager.delete_save(path)
	var s := new_session(2024)
	var tiles0 := s.raft.tiles.size()
	s.raft_position = Vector3(30, 0, 10)  # 移動（3D側は raft_position を更新する）
	var guard := 0
	while (s.inventory.count("wood") < 4 or s.inventory.count("rope") < 2) and guard < 200:
		s.collect_debris("plank")
		guard += 1
	check(guard < 200, "回収で素材が集まる")
	var wood := s.inventory.count("wood")
	var rope := s.inventory.count("rope")
	var target: Vector2i = s.raft.candidate_positions()[0]
	var r := s.actions.start("expand_raft", {"x": target.x, "z": target.y})
	check(r["ok"], "拡張開始: %s" % str(r["problems"]))
	s.advance(20)
	eq(s.raft.tiles.size(), tiles0 + 1, "床が1枚増える")
	eq(s.inventory.count("wood"), wood - 4, "木材4消費")
	eq(s.inventory.count("rope"), rope - 2, "ロープ2消費")
	check(SaveManager.save_session(s, path)["ok"], "セーブ")
	var l := SaveManager.load_session(s.data, path)
	check(l["ok"], "ロード")
	var s2: GameSession = l["session"]
	check(s2.raft.has_tile(target), "拡張した床が残る")
	eq(s2.raft.tiles.size(), tiles0 + 1, "床枚数")
	eq(s2.inventory.count("wood"), wood - 4, "在庫一致")
	eq(s2.raft_position, Vector3(30, 0, 10), "位置一致")
	near(s2.clock.total_minutes, s.clock.total_minutes, 0.001, "時間一致")

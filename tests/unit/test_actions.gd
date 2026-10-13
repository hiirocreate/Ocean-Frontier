extends TestCase

var s: GameSession


func before_each() -> void:
	s = new_session()
	s.inventory.stacks.clear()
	s.inventory.instances.clear()


func _codes(problems: Array) -> Array:
	return problems.map(func(p): return p["code"])


func test_rejects_when_missing_items() -> void:
	s.inventory.add("wood", 1)
	var r := s.actions.start("expand_raft", {"x": 2, "z": 0})
	check(not r["ok"], "不足時は開始できない")
	var msgs: Array = r["problems"].map(func(p): return p["message"])
	check("木材が3個不足しています" in msgs, "木材不足メッセージ: %s" % str(msgs))
	check("ロープが2個不足しています" in msgs, "ロープ不足メッセージ")
	eq(s.inventory.count("wood"), 1, "何も消費されない")


func test_expand_raft_consumes_once() -> void:
	s.inventory.add_many({"wood": 8, "rope": 4})
	var r := s.actions.start("expand_raft", {"x": 2, "z": 0})
	check(r["ok"], "開始できる")
	eq(s.inventory.count("wood"), 4, "開始時に預かり")
	s.advance(5)
	check(not s.raft.has_tile(Vector2i(2, 0)), "途中では未完成")
	s.advance(30)
	check(s.raft.has_tile(Vector2i(2, 0)), "完成")
	eq(s.inventory.count("wood"), 4, "完了時に二重消費されない")
	eq(s.inventory.count("rope"), 2, "ロープ")
	eq(s.actions.jobs.size(), 0, "作業が残らない")


func test_same_tile_cannot_be_queued_twice() -> void:
	s.inventory.add_many({"wood": 8, "rope": 4})
	check(s.actions.start("expand_raft", {"x": 2, "z": 0})["ok"], "1回目")
	var r := s.actions.start("expand_raft", {"x": 2, "z": 0})
	check(not r["ok"], "同じ位置は不可")
	eq(s.inventory.count("wood"), 4, "2回目は消費しない")


func test_invalid_tile_position() -> void:
	s.inventory.add_many({"wood": 8, "rope": 4})
	var r := s.actions.start("expand_raft", {"x": 5, "z": 5})
	check(not r["ok"], "隣接しない位置は不可")
	check("effect" in _codes(r["problems"]), "効果条件の問題")


func test_cancel_refunds() -> void:
	s.inventory.add_many({"wood": 4, "rope": 2})
	var r := s.actions.start("expand_raft", {"x": 2, "z": 0})
	s.actions.cancel(int(r["job"]["id"]))
	eq(s.inventory.count("wood"), 4, "中断で返却")
	eq(s.inventory.count("rope"), 2, "ロープ返却")


func test_facility_required() -> void:
	s.inventory.add_many({"wood": 3, "scrap_metal": 2, "rope": 1, "hammer": 1})
	var r := s.actions.start("craft_spear")
	check("missing_facility" in _codes(r["problems"]), "作業台が必要")
	check(r["problems"].any(func(p): return p["message"] == "設備「作業台」が必要です"), "設備不足メッセージ")


func test_tool_required_and_wear() -> void:
	s.raft.place_building("workbench", Vector2i(0, 0), 100)
	s.inventory.add_many({"wood": 3, "scrap_metal": 2, "rope": 1})
	var r := s.actions.start("craft_spear")
	check("missing_tool" in _codes(r["problems"]), "金槌が必要")
	check(r["problems"].any(func(p): return p["message"] == "金槌が必要です"), "工具不足メッセージ")
	s.inventory.add("hammer", 1)
	r = s.actions.start("craft_spear")
	check(r["ok"], "工具があれば開始")
	s.advance(20)
	eq(s.inventory.count("spear"), 1, "槍ができる")
	near(float(s.inventory.instances.filter(func(i): return i["id"] == "hammer")[0]["durability"]), 38.0, 0.01, "金槌が摩耗")


func test_broken_tool_blocks() -> void:
	s.raft.place_building("workbench", Vector2i(0, 0), 100)
	s.inventory.add_many({"wood": 3, "scrap_metal": 2, "rope": 1, "hammer": 1})
	s.inventory.wear(int(s.inventory.instances[0]["uid"]), 100)
	var r := s.actions.start("craft_spear")
	check("tool_durability" in _codes(r["problems"]), "耐久度0の工具は使えない")


func test_tool_lost_midway_blocks_then_resumes() -> void:
	s.raft.place_building("workbench", Vector2i(0, 0), 100)
	s.inventory.add_many({"wood": 3, "scrap_metal": 2, "rope": 1, "hammer": 1})
	var r := s.actions.start("craft_spear")
	var uid := int(s.inventory.instances[0]["uid"])
	s.inventory.wear(uid, 100)
	s.advance(20)
	eq(s.actions.jobs[0]["state"], "blocked", "完了時に再検証されブロック")
	eq(s.inventory.count("spear"), 0, "未完成")
	s.inventory.repair_most_worn("hammer", 10)
	s.advance(1)
	eq(s.inventory.count("spear"), 1, "条件回復で完了")


func test_failure_loses_ratio() -> void:
	s.inventory.add_many({"plastic": 2, "wood": 1})
	s.rng.seed = 1
	# 失敗するまで乱数を調整: success_chance=0.8 の行動を、強制失敗させるため一時的に確率を0にする
	s.data.actions["boil_water"]["success_chance"] = 0.0
	var r := s.actions.start("boil_water")
	check(r["ok"], "開始")
	s.advance(40)
	eq(s.inventory.count("water_bottle"), 0, "失敗時は成果物なし")
	eq(s.inventory.count("plastic"), 0, "lose_ratio=1.0で全損")


func test_capacity_check() -> void:
	s.inventory.max_weight = 1.0
	s.inventory.add_many({"wood": 1})
	s.data.actions["craft_rope"]["outputs"] = {"scrap_metal": 2}
	s.inventory.max_weight = 1.0
	s.inventory.stacks = {"cloth": 3}
	var r := s.actions.start("craft_rope")
	check("no_capacity" in _codes(r["problems"]), "容量不足を検出")


func test_requirement_rows() -> void:
	s.inventory.add_many({"wood": 5, "rope": 1})
	var rows := s.actions.requirement_rows("expand_raft")
	eq(rows.size(), 2, "行数")
	eq(rows[0]["have"], 5, "所持数")
	check(rows[0]["ok"], "木材は足りる")
	check(not rows[1]["ok"], "ロープは不足")


func test_repair_action() -> void:
	s.inventory.add_many({"hammer": 1, "wood": 1, "scrap_metal": 1})
	var r := s.actions.start("repair_hammer")
	check(not r["ok"], "損耗していなければ修理不可")
	s.inventory.wear(int(s.inventory.instances[0]["uid"]), 30)
	r = s.actions.start("repair_hammer")
	check(r["ok"], "修理開始")
	s.advance(10)
	near(float(s.inventory.instances[0]["durability"]), 30.0, 0.01, "20回復")


func test_over_capacity_does_not_block_weight_reducing_actions() -> void:
	s.inventory.max_weight = 1.0
	s.inventory.add_many({"cloth": 30}, true)
	check(s.inventory.free_weight() < 0.0, "重量超過の状態")
	var r := s.actions.start("craft_rope")
	check(r["ok"], "重量が減る行動は重量超過でも実行できる %s" % str(r["problems"]))

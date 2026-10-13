extends TestCase

var s: GameSession


func before_each() -> void:
	s = new_session()
	s.inventory.stacks.clear()
	s.inventory.instances.clear()
	s.inventory.add_many({"wood": 30, "scrap_metal": 10, "rope": 6, "cloth": 6, "plastic": 4, "hammer": 1}, true)


func test_build_storage_box_increases_capacity() -> void:
	var cap0 := s.inventory.max_weight
	var r := s.actions.start("build_storage_box", {"x": 0, "z": 0})
	check(r["ok"], "建設開始 %s" % str(r["problems"]))
	s.advance(30)
	check(s.raft.building_at(Vector2i(0, 0)) != "", "設置された")
	near(s.inventory.max_weight, cap0 + 40.0, 0.01, "収納容量が加算")


func test_building_needs_floor_and_free_tile() -> void:
	var r := s.actions.start("build_storage_box", {"x": 7, "z": 7})
	check(not r["ok"], "床がない場所は不可")
	s.actions.start("build_workbench", {"x": 0, "z": 0})
	r = s.actions.start("build_storage_box", {"x": 0, "z": 0})
	check(not r["ok"], "建設中の場所は不可")
	s.advance(60)
	r = s.actions.start("build_storage_box", {"x": 0, "z": 0})
	check(not r["ok"], "設備がある場所は不可")
	check(r["problems"].any(func(p): return p["message"] == "そこにはすでに設備があります"), "理由表示")


func test_production_and_harvest() -> void:
	s.actions.start("build_water_purifier", {"x": 1, "z": 0})
	s.advance(30)
	var uid := s.raft.building_at(Vector2i(1, 0))
	check(uid != "", "浄水器")
	eq(s.harvest(uid), 0, "まだ生産されていない")
	s.advance(150 * 5)
	eq(int(s.raft.buildings[uid]["stored"]), 3, "上限3で止まる")
	var w0 := s.inventory.count("water_bottle")
	eq(s.harvest(uid), 3, "収穫")
	eq(s.inventory.count("water_bottle"), w0 + 3, "在庫に追加")
	eq(int(s.raft.buildings[uid]["stored"]), 0, "空になる")


func test_cook_requires_grill() -> void:
	s.inventory.add("raw_fish", 1)
	check(not s.actions.start("cook_fish")["ok"], "焚き火台なしでは焼けない")
	s.raft.place_building("grill", Vector2i(0, 1), 70)
	s.data.actions["cook_fish"]["success_chance"] = 1.0
	check(s.actions.start("cook_fish")["ok"], "焚き火台があれば焼ける")
	s.advance(15)
	eq(s.inventory.count("cooked_fish"), 1, "焼き魚")


func test_sleep_recovers_fatigue() -> void:
	s.raft.place_building("bed", Vector2i(1, 1), 60)
	s.survival.fatigue = 80
	check(s.actions.start("sleep")["ok"], "眠る")
	check(s.is_sleeping(), "睡眠中")
	s.advance(360)
	check(s.survival.fatigue < 20, "疲労回復: %f" % s.survival.fatigue)
	check(not s.is_sleeping(), "起きる")


func test_buildings_saved_and_loaded() -> void:
	var path := "user://test_saves/buildings.json"
	s.raft.place_building("water_purifier", Vector2i(1, 0), 60)
	s.raft.place_building("storage_box", Vector2i(0, 0), 80)
	s.update_capacity()
	s.advance(200)
	SaveManager.save_session(s, path)
	var s2: GameSession = SaveManager.load_session(s.data, path)["session"]
	eq(s2.raft.buildings.size(), 2, "建築物数")
	near(s2.inventory.max_weight, s.inventory.max_weight, 0.01, "容量も復元")
	eq(s2.raft.buildings[s2.raft.building_at(Vector2i(1, 0))]["stored"], 1, "生産状態")
	var uid := s2.raft.place_building("bed", Vector2i(1, 1), 60)
	check(not s2.raft.buildings.has(uid) or uid not in ["1", "2"], "UIDが重複しない")

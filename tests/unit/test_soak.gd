extends TestCase
## 長時間プレイの模擬（仕様46）: 全システムを動かしたまま20日分進め、破綻がないこと・セーブが壊れないことを確認する。


func test_twenty_days_all_systems() -> void:
	var s := new_session(4242)
	s.pending_dialogue = {}
	s.inventory.max_weight = 400
	s.inventory.add_many({"wood": 60, "rope": 20, "scrap_metal": 30, "cloth": 20, "plastic": 10, "hammer": 1, "canned_food": 30, "water_bottle": 40}, true)
	s.raft.place_building("water_purifier", Vector2i(0, 0), 60)
	s.raft.place_building("fishing_net", Vector2i(1, 0), 50)
	s.raft.place_building("bed", Vector2i(0, 1), 60)
	for m in ["mira", "tobi", "garrett"]:
		s.crew.recruit(m, 1)
	s.crew.assign_job("mira", "fishing", s)
	s.crew.assign_job("tobi", "gathering", s)
	s.crew.assign_job("garrett", "guard", s)
	var ship := s.fleet.add_ship("sloop", 1)
	s.fleet.sailors_pool = 3
	s.fleet.add_sailors(ship, 3)
	var t0 := Time.get_ticks_msec()
	var path := "user://test_saves/soak.json"
	for step in 20 * 48:  # 30分刻みで20日
		s.advance(30)
		if not s.pending_combat.is_empty():
			s.resolve_combat("fight")
		if not s.pending_dialogue.is_empty():
			s.pending_dialogue = {}
		if step % 48 == 10:
			for id in ["cooked_fish", "canned_food", "potato", "coconut", "water_bottle"]:
				if s.survival.hunger < 50 or s.survival.thirst < 50:
					s.use_item(id)
			for uid in s.raft.buildings:
				s.harvest(uid)
			if s.fleet.at_home(ship):
				s.start_fleet_mission(ship, "trade", "tide_union")
		if step % 240 == 0:
			check(SaveManager.save_session(s, path)["ok"], "途中セーブ %d" % step)
	var elapsed := Time.get_ticks_msec() - t0
	check(s.clock.day() >= 20, "20日経過")
	check(s.survival.health > 0.0, "生存している")
	check(s.inventory.total_weight() >= 0.0, "在庫が破綻しない")
	for id in s.inventory.stacks:
		check(int(s.inventory.stacks[id]) > 0, "負の在庫がない: %s" % id)
	check(s.factions.news_log.size() > 0, "勢力が動き続けている")
	var l := SaveManager.load_session(s.data, path)
	check(l["ok"], "長時間後もロードできる")
	var size := FileAccess.get_file_as_string(path).length()
	check(size < 400000, "セーブファイルが肥大化しない（%d bytes）" % size)
	check(elapsed < 60000, "処理時間が妥当（%d ms）" % elapsed)
	print("    soak: %d ms, save %d bytes, day %d, events %d" % [elapsed, size, s.clock.day(), s.events.history.size()])

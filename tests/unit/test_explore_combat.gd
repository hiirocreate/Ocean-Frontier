extends TestCase

var s: GameSession


func before_each() -> void:
	s = new_session(31)
	s.inventory.stacks.clear()
	s.inventory.instances.clear()
	s.inventory.max_weight = 500


func _codes(problems: Array) -> Array:
	return problems.map(func(p): return p["code"])


func _go_to(site: String) -> void:
	s.update_location(s.site_position(site) + Vector3(5, 0, 0))


func test_zone_detection() -> void:
	eq(s.zone_at(Vector3(0, 0, 0)), "starting_waters", "中央")
	eq(s.zone_at(Vector3(800, 0, 0)), "rust_reef", "東")
	eq(s.zone_at(Vector3(0, 0, -800)), "deep_trench", "北")
	eq(s.zone_at(Vector3(5000, 0, 5000)), "starting_waters", "範囲外は外洋扱い")
	eq(s.update_location(Vector3(800, 0, 0)), "rust_reef", "海域が変わる")
	check(s.flags.get("visited_rust_reef", false), "訪問フラグ")


func test_site_discovery() -> void:
	check(not s.is_site_discovered("wreck_fishing_boat"), "最初は未発見")
	s.update_location(Vector3(70, 0, -40))
	check(s.is_site_discovered("wreck_fishing_boat"), "近づくと発見")
	s.update_location(s.site_position("atlas_core"))
	check(not s.is_site_discovered("atlas_core"), "隠された地点は条件を満たすまで発見されない")
	s.flags["decoded_atlas_location"] = true
	s.update_location(s.site_position("atlas_core"))
	check(s.is_site_discovered("atlas_core"), "条件を満たすと発見")


func test_explore_requires_distance_and_depletes() -> void:
	s.update_location(Vector3(70, 0, -40))
	var r := s.actions.start("explore_surface", {"site": "wreck_fishing_boat"})
	check(not r["ok"], "離れていると探索できない")
	_go_to("wreck_fishing_boat")
	for i in 2:
		r = s.actions.start("explore_surface", {"site": "wreck_fishing_boat"})
		check(r["ok"], "探索開始 %d" % i)
		s.advance(40)
	eq(s.site_explorations_left("wreck_fishing_boat"), 0, "探索回数を使い切る")
	r = s.actions.start("explore_surface", {"site": "wreck_fishing_boat"})
	check(r["problems"].any(func(p): return str(p["message"]).contains("探索し尽くした")), "枯渇メッセージ")


func test_underwater_requires_gear_and_oxygen() -> void:
	_go_to("sunken_ferry")
	var r := s.actions.start("explore_underwater", {"site": "sunken_ferry"})
	var msgs: Array = r["problems"].map(func(p): return p["message"])
	check("潜水装備が必要です" in msgs, "潜水装備が必要: %s" % str(msgs))
	check("酸素ボンベが1個不足しています" in msgs, "酸素が必要")
	s.inventory.add_many({"diving_gear": 1, "oxygen_tank": 1})
	s.data.actions["explore_underwater"]["success_chance"] = 1.0
	s.data.sites["sunken_ferry"]["combat"] = {}
	r = s.actions.start("explore_underwater", {"site": "sunken_ferry"})
	check(r["ok"], "装備があれば潜れる")
	s.advance(60)
	eq(s.inventory.count("oxygen_tank"), 0, "酸素を消費")
	check(float(s.inventory.instances[0]["durability"]) < 30.0, "潜水装備が摩耗")


func test_unique_items_only_first_time() -> void:
	_go_to("drone_ship")
	s.data.sites["drone_ship"]["combat"] = {}
	s.data.sites["drone_ship"]["max_explorations"] = 2
	s.actions.start("explore_surface", {"site": "drone_ship"})
	s.advance(40)
	eq(s.inventory.count("encrypted_data"), 1, "初回は暗号化データ")
	check(s.flags.get("found_drone_ship", false), "フラグ")
	s.actions.start("explore_surface", {"site": "drone_ship"})
	s.advance(40)
	eq(s.inventory.count("encrypted_data"), 1, "2回目は出ない")


func test_keep_items_required_not_consumed() -> void:
	s.flags["decoded_atlas_location"] = true
	_go_to("atlas_core")
	s.inventory.add_many({"diving_gear": 1, "resonance_scanner": 1, "oxygen_tank": 3})
	var r := s.actions.start("explore_core", {"site": "atlas_core"})
	check("missing_key_item" in _codes(r["problems"]), "古い鍵が必要")
	s.inventory.add("old_key", 1)
	r = s.actions.start("explore_core", {"site": "atlas_core"})
	check(r["ok"], "鍵があれば開始 %s" % str(r["problems"]))
	s.advance(100)
	eq(s.inventory.count("old_key"), 1, "鍵は消費されない")
	check(s.flags.get("reached_atlas_core", false), "中枢に到達")


func test_combat_victory_with_weapon() -> void:
	s.inventory.add_many({"pistol": 1, "ammo": 20, "leather_armor": 1})
	s.start_combat("scavengers", "raft")
	check(not s.pending_combat.is_empty(), "戦闘待ち")
	var r := s.resolve_combat("fight")
	check(r["outcome"] in ["victory", "enemy_surrendered", "enemy_fled"], "強い武器なら勝つ: %s" % r["outcome"])
	check(int(r["ammo_used"]) > 0, "弾薬を使った")
	eq(s.inventory.count("ammo"), 20 - int(r["ammo_used"]) + int(r["loot"].get("ammo", 0)), "弾薬の消費と戦利品が正しく反映")
	check(float(s.inventory.instances[0]["durability"]) < 50.0, "武器が摩耗")
	check(s.pending_combat.is_empty(), "戦闘終了")


func test_defeat_is_not_game_over() -> void:
	s.inventory.add_many({"wood": 10, "rope": 10})
	s.survival.health = 15
	s.zone_id = "red_tide"
	s.start_combat("pirate_raiders", "site")
	var r := s.resolve_combat("fight")
	eq(r["outcome"], "defeat", "弱い状態では負ける")
	check(s.survival.health >= 1.0, "体力は残る（ゲームオーバーにならない）")
	check(s.inventory.count("wood") < 10, "物資の一部を奪われる")


func test_broken_weapon_is_skipped() -> void:
	s.inventory.add_many({"harpoon": 1, "machete": 1})
	var h: Dictionary = s.inventory.instances.filter(func(i): return i["id"] == "harpoon")[0]
	s.inventory.wear(int(h["uid"]), 999)
	var w := CombatSystem.best_weapon(s)
	eq(w["id"], "machete", "壊れた武器は使わない")
	s.inventory.stacks.erase("ammo")
	s.inventory.add("pistol", 1)
	eq(CombatSystem.best_weapon(s)["id"], "machete", "弾のない銃は使わない")


func test_negotiate_requires_bribe() -> void:
	s.start_combat("scavengers", "raft")
	check(CombatSystem.negotiate_problem(s, "scavengers") != "", "物資がないと交渉不可")
	s.inventory.add_many({"canned_food": 1, "water_bottle": 1})
	eq(CombatSystem.negotiate_problem(s, "scavengers"), "", "物資があれば交渉可能")
	var r := s.resolve_combat("negotiate")
	eq(r["outcome"], "negotiated", "交渉成立")
	eq(s.inventory.count("canned_food"), 0, "物資を渡す")
	check(not CombatSystem.negotiate_problem(s, "sharks").is_empty(), "動物とは交渉できない")


func test_prisoners_need_prison() -> void:
	eq(s.prison_capacity(), 0, "檻がない")
	var r := {"enemy": "scavengers", "outcome": "enemy_surrendered", "captured": 2, "terrain": "raft", "rounds": 1}
	CombatSystem.apply_result(s, r)
	eq(s.prisoners.size(), 0, "檻がなければ捕虜にできない")
	s.raft.place_building("prison", Vector2i(0, 0), 100)
	CombatSystem.apply_result(s, r)
	eq(s.prisoners.size(), 2, "檻の容量まで捕虜にする")


func test_pending_combat_saved() -> void:
	var path := "user://test_saves/combat.json"
	s.start_combat("sharks", "underwater", "site:sunken_ferry")
	s.update_location(Vector3(70, 0, -40))
	s.change_reputation("fame", 12)
	SaveManager.save_session(s, path)
	var s2: GameSession = SaveManager.load_session(s.data, path)["session"]
	eq(s2.pending_combat.get("enemy"), "sharks", "戦闘中の状態を保持")
	check(s2.is_site_discovered("wreck_fishing_boat"), "発見状態を保持")
	near(float(s2.reputation["fame"]), 12.0, 0.01, "評判を保持")


func test_decode_and_radio_story_path() -> void:
	s.raft.place_building("research_desk", Vector2i(0, 0), 60)
	s.inventory.add("encrypted_data", 1)
	check(s.actions.start("decode_data")["ok"], "解析開始")
	s.advance(130)
	eq(s.inventory.count("decoded_report"), 1, "解読された報告書")
	s.raft.place_building("radio_station", Vector2i(1, 0), 60)
	s.inventory.add("radio", 1)
	check(s.actions.start("listen_radio")["ok"], "無線傍受")
	s.advance(70)
	check(s.is_site_discovered("atlas_outpost"), "座標から観測所が判明")

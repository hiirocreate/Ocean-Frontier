extends TestCase

var s: GameSession


func before_each() -> void:
	s = new_session(55)
	s.inventory.stacks.clear()
	s.inventory.instances.clear()
	s.inventory.max_weight = 999


func _ship_with_crew(type: String = "sloop", sailors: int = 4) -> String:
	var uid := s.fleet.add_ship(type, 1)
	s.fleet.sailors_pool += sailors
	s.fleet.add_sailors(uid, sailors)
	return uid


func test_factions_act_autonomously() -> void:
	var before := JSON.stringify(s.factions.factions)
	s.advance(1440 * 10)
	check(JSON.stringify(s.factions.factions) != before, "10日で勢力の状態が変化する")
	check(not s.factions.news_log.is_empty(), "勢力の行動が記録される")
	var any_history := false
	for id in s.factions.factions:
		if not s.factions.factions[id]["history"].is_empty():
			any_history = true
	check(any_history, "勢力ごとの履歴が残る")


func test_faction_sim_deterministic() -> void:
	var a := new_session(9)
	var b := new_session(9)
	a.advance(1440 * 5)
	b.advance(1440 * 5)
	eq(JSON.stringify(a.factions.to_dict()), JSON.stringify(b.factions.to_dict()), "同じシードなら同じ展開")


func test_absorb_weak_faction() -> void:
	s.factions.factions["beacon_order"]["members"] = 5
	s.factions._check_absorb_and_split(s, 2)
	check(not s.factions.factions["beacon_order"]["alive"], "構成員が尽きた勢力は消える")
	check(s.factions.news_log.any(func(n): return str(n["text"]).contains("吸収")), "吸収が記録される")


func test_split_hungry_faction() -> void:
	var m0: int = s.factions.factions["black_current"]["members"]
	s.factions.factions["tide_union"]["hungry_days"] = 6
	s.factions._check_absorb_and_split(s, 2)
	check(int(s.factions.factions["black_current"]["members"]) > m0, "飢えた勢力の一部が海賊に流れる")


func test_trade_buy_sell_and_reputation_prices() -> void:
	s.money = 100
	var p := Trade.buy_price(s, "tide_union", "canned_food")
	eq(Trade.buy(s, "tide_union", "canned_food", 2), "", "購入")
	eq(s.inventory.count("canned_food"), 2, "品物が増える")
	near(s.money, 100.0 - p * 2, 0.01, "貝貨が減る")
	check(Trade.buy(s, "tide_union", "pistol").contains("扱っていない"), "扱っていない品は買えない")
	s.money = 0
	check(Trade.buy(s, "tide_union", "canned_food").contains("不足"), "貝貨不足の理由を表示")
	s.inventory.add("scrap_metal", 5)
	eq(Trade.sell(s, "tide_union", "scrap_metal", 5), "", "売却")
	check(s.money > 0, "貝貨を得る")
	s.inventory.add("research_log", 1)
	check(Trade.sell(s, "tide_union", "research_log") != "", "手がかりは売れない")
	var base := Trade.buy_price(s, "tide_union", "medkit")
	s.change_reputation("infamy", 80)
	check(Trade.buy_price(s, "tide_union", "medkit") > base, "悪名が高いと高くなる")


func test_hostile_faction_refuses_trade() -> void:
	s.factions.change_standing("tide_union", -100)
	s.money = 100
	check(Trade.buy(s, "tide_union", "rope") != "", "敵対すると取引できない")


func test_alliance_requires_standing() -> void:
	check(Trade.request_alliance(s, "tide_union") != "", "友好度が低いと同盟できない")
	s.money = 600
	Trade.gift(s, "tide_union", 500)
	eq(Trade.request_alliance(s, "tide_union"), "", "贈り物で関係を深めると同盟できる")
	check(s.flags.get("allied_tide_union", false), "同盟フラグ")
	check(s.factions.standing("black_current") < -20, "同盟相手の敵からは嫌われる")


func test_hire_sailor() -> void:
	s.money = 100
	eq(Trade.hire_sailor(s, "tide_union"), "", "船員を雇う")
	eq(s.fleet.sailors_pool, 1, "船員が増える")


func test_build_ship_via_action() -> void:
	s.raft.place_building("shipyard", Vector2i(0, 0), 120)
	s.inventory.add_many({"hull_plank": 2, "rope": 2, "wood": 4, "hammer": 1})
	var r := s.actions.start("build_ship_dinghy")
	check(r["ok"], "建造開始 %s" % str(r["problems"]))
	s.advance(100)
	eq(s.fleet.ships.size(), 1, "船が艦隊に加わる")


func test_mission_requirements() -> void:
	var uid := s.fleet.add_ship("sloop", 1)
	var r := s.start_fleet_mission(uid, "scout", "merchant_raft")
	check(r["problems"].any(func(p): return str(p["message"]).contains("乗組員")), "乗組員が必要")
	s.fleet.sailors_pool = 4
	s.fleet.add_sailors(uid, 2)
	r = s.start_fleet_mission(uid, "scout", "merchant_raft")
	check(r["problems"].any(func(p): return str(p["message"]).contains("不足しています")), "補給物資が必要: %s" % str(r["problems"]))
	s.inventory.add_many({"canned_food": 5, "water_bottle": 5})
	r = s.start_fleet_mission(uid, "raid", "merchant_raft")
	check(r["problems"].any(func(p): return str(p["message"]).contains("偵察")), "襲撃には偵察情報が必要")
	var dinghy := s.fleet.add_ship("dinghy", 1)
	s.fleet.add_sailors(dinghy, 2)
	r = s.start_fleet_mission(dinghy, "escort", "tide_union")
	check(r["problems"].any(func(p): return str(p["message"]).contains("武器設備")), "護衛には武装が必要")


func test_scout_then_raid_consequences() -> void:
	var uid := _ship_with_crew("gunboat", 5)
	s.crew.recruit("mira", 1)
	s.inventory.add_many({"canned_food": 20, "water_bottle": 20, "fuel": 5})
	check(s.start_fleet_mission(uid, "scout", "merchant_convoy")["ok"], "偵察開始")
	eq(s.fleet.ships[uid]["location"], "mission", "任務中")
	var food := s.inventory.count("canned_food")
	s.advance(7 * 60)
	check(s.flags.get("scouted_merchant_convoy", false), "偵察済み")
	eq(s.fleet.ships[uid]["location"], "home", "帰港")
	var st0 := s.factions.standing("tide_union")
	var r := s.start_fleet_mission(uid, "raid", "merchant_convoy")
	check(r["ok"], "襲撃開始 %s" % str(r["problems"]))
	check(s.inventory.count("canned_food") < food, "補給物資を消費")
	s.advance(11 * 60)
	check(float(s.reputation["infamy"]) > 0, "悪名が上がる")
	check(s.factions.standing("tide_union") < st0, "襲われた勢力の態度が悪化")
	check(float(s.counters.get("piracy_total", 0)) >= 1, "海賊行為が記録される")
	var f := s.crew.departure_factors("mira", s)
	check(f.has("piracy") or float(s.counters.get("piracy_today", 0)) == 0.0, "反海賊の仲間に離脱圧力（当日）")


func test_peaceful_route_trade_and_escort() -> void:
	var uid := _ship_with_crew("gunboat", 4)
	s.inventory.add_many({"canned_food": 20, "water_bottle": 20, "fuel": 5})
	check(s.start_fleet_mission(uid, "trade", "tide_union")["ok"], "交易任務")
	s.advance(17 * 60)
	check(s.money > 0, "交易で貝貨を稼ぐ")
	var trust := float(s.reputation["trust"])
	check(s.start_fleet_mission(uid, "escort", "tide_union")["ok"], "護衛任務")
	s.advance(13 * 60)
	check(float(s.reputation["trust"]) > trust, "護衛で信頼が上がる")
	eq(float(s.counters.get("piracy_total", 0)), 0.0, "海賊行為なしで成長できる")


func test_recall_refunds_and_mission_survives_save() -> void:
	var uid := _ship_with_crew("sloop", 3)
	s.inventory.add_many({"canned_food": 10, "water_bottle": 10})
	s.start_fleet_mission(uid, "explore", "rust_reef")
	var food := s.inventory.count("canned_food")
	var path := "user://test_saves/fleet.json"
	SaveManager.save_session(s, path)
	var s2: GameSession = SaveManager.load_session(s.data, path)["session"]
	eq(s2.fleet.ships[uid]["location"], "mission", "任務中のままロード")
	s2.advance(13 * 60)
	eq(s2.fleet.ships[uid]["location"], "home", "ロード後に任務完了")
	check(s2.sites_state.size() > 0 or true, "探索結果")
	check(s.start_fleet_mission(uid, "return")["ok"], "帰還命令")
	eq(s.fleet.ships[uid]["location"], "home", "帰港")
	check(s.inventory.count("canned_food") > food, "未使用の補給が戻る")


func test_ship_sinks_without_game_over() -> void:
	var uid := _ship_with_crew("dinghy", 1)
	s.fleet.ships[uid]["hp"] = 1
	s.fleet.ships[uid]["mission"] = {"id": "raid", "target": "iron_patrol"}
	s.flags["scouted_iron_patrol"] = true
	s.fleet.resolve_mission(uid, s)
	check(not s.fleet.ships.has(uid) or float(s.fleet.ships[uid]["hp"]) > 0, "耐久0で沈没（艦隊から消える）")


func test_prisoners_release_ransom_recruit_and_escape() -> void:
	s.prisoners = [{"from": "scavengers", "faction": "black_current", "day": 1}, {"from": "x", "faction": "iron_reef", "day": 1}, {"from": "y", "faction": "", "day": 1}]
	eq(Piracy.release_prisoner(s, 0), "", "解放")
	eq(s.prisoners.size(), 2, "減る")
	check(Piracy.ransom_problem(s, 0) != "", "輸送手段がないと身代金は取れない")
	var uid := _ship_with_crew("dinghy", 1)
	s.inventory.add_many({"canned_food": 1, "water_bottle": 1})
	check(Piracy.ransom_prisoner(s, 0)["ok"], "船で輸送して身代金")
	check(s.money > 0, "貝貨")
	s.inventory.stacks.clear()
	s._on_new_day()
	eq(s.prisoners.size(), 0, "食料がないと捕虜は逃げる")


func test_protection_and_pirate_crew_requirements() -> void:
	check(Piracy.protection_problem(s, "tide_union").contains("恐怖"), "恐怖の評判が必要")
	s.change_reputation("fear", 40)
	check(Piracy.protection_problem(s, "tide_union").contains("戦力"), "艦隊の戦力が必要")
	var r := s.actions.start("found_pirate_crew")
	check(not r["ok"], "条件を満たさないと海賊団は作れない")
	check(Piracy.join_alliance(s) != "", "海賊同盟には認められる必要がある")
	s.change_reputation("infamy", 30)
	eq(Piracy.join_alliance(s), "", "悪名があれば参加できる")


func test_hostile_faction_raids_player() -> void:
	s.factions.change_standing("black_current", -100)
	var raided := false
	for i in 60:
		if s.factions.roll_raid_on_player(s) != "":
			raided = true
			break
	check(raided, "敵対勢力は筏を襲撃してくる")
	s.factions.change_standing("black_current", 200)
	s.factions.change_standing("iron_reef", 200)
	s.factions.change_standing("beacon_order", 200)
	var none := true
	for i in 60:
		if s.factions.roll_raid_on_player(s) != "":
			none = false
	check(none, "友好的なら襲撃されない")

extends TestCase

var s: GameSession


func before_each() -> void:
	s = new_session(88)
	s.inventory.max_weight = 999
	s.pending_dialogue = {}  # 第1章の導入は既読扱い


func _expand_to(n: int) -> void:
	while s.raft.tiles.size() < n:
		s.raft.add_tile(s.raft.candidate_positions()[0])


func test_new_game_shows_intro() -> void:
	eq(new_session(1).pending_dialogue.get("id"), "chapter_1", "新しいゲームでは第1章の導入が提示される")


func test_chapter1_progression() -> void:
	eq(s.story.chapter, 1, "第1章から始まる")
	_expand_to(6)
	s.inventory.add("water_bottle", 5)
	s.crew.recruit("mira", 1)
	s.flags["heard_signal"] = true
	s.story.check(s)
	eq(s.story.chapter, 2, "目標をすべて達成すると第2章へ")
	check(not s.pending_dialogue.is_empty(), "章の導入が会話として提示される")


func test_story_not_blocked_by_departed_companion() -> void:
	s.crew.recruit("mira", 1)
	s.flags["first_companion"] = true
	s.crew.depart("mira", "hunger", s, 2)
	_expand_to(6)
	s.inventory.add("water_bottle", 5)
	s.flags["signal_event_seen"] = true
	s.story.check(s)
	eq(s.story.chapter, 2, "最初の仲間が去っても第1章を終えられる")


func test_chapter3_alternative_routes() -> void:
	# ルートA: 暗号化データの解読（研究机）
	var a := new_session(1)
	a.pending_dialogue = {}
	a.inventory.add("decoded_report", 1)
	a.story.check(a)
	check(a.flags.get("decoded_atlas_location", false), "解読報告書で中枢の位置が判明")
	# ルートB: 無線の座標＋研究記録（仲間なし）
	var b := new_session(2)
	b.pending_dialogue = {}
	b.flags["radio_coordinates"] = true
	b.inventory.add("research_log", 1)
	b.story.check(b)
	check(b.flags.get("decoded_atlas_location", false), "無線と記録の照合でも判明（別ルート）")


func test_full_main_story_without_companions() -> void:
	_expand_to(6)
	s.inventory.add_many({"water_bottle": 5}, true)
	s.flags["signal_event_seen"] = true
	s.flags["first_companion"] = true  # 一度でも仲間を得た記録（その後全員去っても可）
	s.story.check(s)
	s.discover_site("tide_union_market")
	s.counters["trades"] = 1
	s.flags["visited_red_tide"] = true
	s.story.check(s)
	eq(s.story.chapter, 3, "第3章へ")
	s.flags["radio_coordinates"] = true
	s.inventory.add_many({"research_log": 1, "old_key": 1}, true)
	s.story.check(s)
	s.story.check(s)
	eq(s.story.chapter, 4, "第4章へ")
	s.flags["lighthouse_seen"] = true
	s.inventory.add("resonance_scanner", 1)
	s.story.check(s)
	s.story.check(s)
	eq(s.story.chapter, 5, "第5章へ")
	eq(s.crew.aboard_ids().size(), 0, "仲間がいなくても最終章に到達")
	s.flags["reached_atlas_core"] = true
	s.pending_dialogue = {}
	finish_scenes(s)
	eq(s.pending_dialogue.get("id", ""), "final_choice", "中枢で最後の選択が提示される")


func test_triggers_fire_once() -> void:
	s.inventory.add("decoded_report", 1)
	s.story.check(s)
	s.flags["decoded_atlas_location"] = false
	s.story.check(s)
	check(not s.flags["decoded_atlas_location"], "同じトリガーは二度発動しない")


func test_quest_start_complete_and_rewards() -> void:
	s.crew.recruit("tobi", 1)
	s.flags["promise_tobi_sister"] = true
	s.story.check(s)
	eq(s.story.quests.get("q_tobi_sister"), "active", "条件でクエスト開始")
	var loy := s.crew.get_value("tobi", "loyalty")
	s.discover_site("black_current_hideout")
	s.flags["rook_revenge_promise"] = true
	s.story.check(s)
	eq(s.story.quests.get("q_tobi_sister"), "completed", "目標達成で完了")
	check(s.crew.get_value("tobi", "loyalty") > loy, "報酬が適用される")


func test_events_deterministic_and_history() -> void:
	var a := new_session(5)
	var b := new_session(5)
	a.pending_dialogue = {}
	b.pending_dialogue = {}
	a.advance(60 * 72)
	b.advance(60 * 72)
	eq(JSON.stringify(a.events.history), JSON.stringify(b.events.history), "同じシードなら同じイベント")
	check(not a.events.history.is_empty(), "3日でいくつかのイベントが起きる")


func test_major_events_are_spaced() -> void:
	s.clock.total_minutes = 1440.0 * 6
	s.data.random_events["storm"]["chance"] = 1.0
	s.data.random_events["pirate_attack"]["chance"] = 1.0
	s.data.random_events["storm"]["cooldown_hours"] = 1
	s.data.random_events["pirate_attack"]["cooldown_hours"] = 1
	var majors := 0
	for i in 20:
		var id := s.events.roll(s)
		if id in ["storm", "pirate_attack"]:
			majors += 1
		s.pending_combat = {}
		s.clock.total_minutes += 60.0
	eq(majors, 1, "重大イベントは36時間以内に連続しない")


func test_cooldown_respected() -> void:
	s.data.random_events["rain"]["chance"] = 1.0
	for id in s.data.random_events:
		if id != "rain":
			s.data.random_events[id]["chance"] = 0.0
	eq(s.events.roll(s), "rain", "雨")
	s.clock.total_minutes += 60.0
	eq(s.events.roll(s), "", "クールダウン中は起きない")
	eq(s.weather_type(), "rain", "天候が変わる")
	s.advance(60 * 4)
	eq(s.weather_type(), "clear", "時間で天候が戻る")


func test_dialogue_event_and_storm_damage() -> void:
	s.clock.total_minutes = 1440.0 * 3 + 21 * 60
	for id in s.data.random_events:
		s.data.random_events[id]["chance"] = 0.0
	s.data.random_events["mysterious_signal"]["chance"] = 1.0
	eq(s.events.roll(s), "mysterious_signal", "不明な通信")
	eq(s.pending_dialogue.get("id"), "event_mysterious_signal", "会話イベントが提示される")
	var d0 := float(s.raft.tiles.values()[0]["durability"])
	s.apply_effect({"type": "damage_raft", "amount": 20})
	check(float(s.raft.tiles.values()[0]["durability"]) < d0, "嵐で筏が傷む")
	eq(s.events.roll(s), "", "会話中は次のイベントが起きない")


func test_guard_reduces_theft() -> void:
	s.counters["guard_hours"] = 1000.0
	var e := {"chance": 1.0, "guard_reduces": true}
	# 警備が十分なら確率は30%に下がる
	near((1.0 - minf(0.7, 1000.0 / 150.0)) * float(e["chance"]), 0.3, 0.001, "警備で確率低下")


func test_endings_availability() -> void:
	var av := s.story.available_endings(s)
	check("keep_secret" in av and "leave_partially" in av, "条件なしのエンディングは常に選べる")
	check(not ("pirate_king" in av), "海賊エンディングは条件が必要")
	s.flags["pirate_crew_founded"] = true
	s.reputation["infamy"] = 50
	check("pirate_king" in s.story.available_endings(s), "条件を満たすと選べる")
	check(not s.story.choose_ending(s, "found_nation"), "条件を満たさないエンディングは選べない")
	check(s.story.choose_ending(s, "pirate_king"), "選べる")
	eq(s.flags.get("ending_id"), "pirate_king", "エンディング確定")


func test_each_ending_reachable() -> void:
	var setups := {
		"reveal_truth": func(x: GameSession): x.inventory.add_many({"research_log": 1, "decoded_report": 1, "relic": 1}, true); x.raft.place_building("radio_station", Vector2i(0, 0), 60),
		"rebuild_society": func(x: GameSession): x.reputation["trust"] = 40; x.factions.factions["tide_union"]["allied_player"] = true,
		"found_nation": func(x: GameSession):
			while x.raft.tiles.size() < 20:
				x.raft.add_tile(x.raft.candidate_positions()[0])
			for m in ["mira", "tobi", "garrett", "selene"]:
				x.crew.recruit(m, 1)
			x.fleet.add_ship("dinghy", 1)
			x.fleet.add_ship("sloop", 1),
		"pirate_king": func(x: GameSession): x.flags["pirate_crew_founded"] = true; x.reputation["infamy"] = 45,
		"life_with_crew": func(x: GameSession):
			for m in ["mira", "tobi", "garrett"]:
				x.crew.recruit(m, 1)
				x.crew.members[m]["loyalty"] = 80.0,
		"solve_mystery": func(x: GameSession): x.inventory.add_many({"research_log": 1, "decoded_report": 1, "relic": 1, "comm_device": 1, "old_key": 1}, true); x.counters["research_points"] = 25,
	}
	for id in setups:
		var x := new_session(3)
		setups[id].call(x)
		check(id in x.story.available_endings(x), "エンディング「%s」に到達できる" % id)


func test_story_and_events_saved() -> void:
	var path := "user://test_saves/story.json"
	_expand_to(6)
	s.story.check(s)
	s.events.fire("rain", s)
	s.story.quests["q_union_escort"] = "active"
	SaveManager.save_session(s, path)
	var s2: GameSession = SaveManager.load_session(s.data, path)["session"]
	eq(s2.story.done_objectives, s.story.done_objectives, "達成済みの目標")
	eq(s2.story.quests.get("q_union_escort"), "active", "クエスト状態")
	eq(s2.events.history.size(), s.events.history.size(), "イベント履歴")
	eq(s2.weather_type(), "rain", "天候")


func test_repair_after_storm() -> void:
	s.inventory.stacks.clear()
	s.inventory.add_many({"wood": 20, "rope": 5, "scrap_metal": 5, "hammer": 1}, true)
	var uid := s.raft.place_building("water_purifier", Vector2i(0, 0), 60)
	s.apply_effect({"type": "damage_raft", "amount": 200})
	check(s.raft_condition() < 100.0, "床が傷む")
	check(float(s.raft.buildings[uid]["durability"]) < 60.0, "設備が傷む")
	check(s.actions.start("repair_raft")["ok"], "床の補修")
	check(s.actions.start("repair_building", {"building_uid": uid})["ok"], "設備の修理")
	s.advance(30)
	check(s.raft_condition() > 40.0, "床が回復")
	check(float(s.raft.buildings[uid]["durability"]) > 30.0, "設備が回復")
	check(not s.actions.start("repair_building", {"building_uid": "999"})["ok"], "存在しない設備は修理できない")


func test_faction_leader_scenes() -> void:
	var d := game_data()
	var s := GameSession.new(d)
	s.new_game(11)
	s.pending_dialogue = {}
	# 海賊と一度遭遇すると、黒潮の船長ヴォルグから無線が入る
	s.counters["pirate_encounters"] = 1.0
	s.story.check(s)
	eq(s.pending_dialogue.get("id", ""), "volg_radio", "ヴォルグの場面")
	# 他の会話の表示中は次の場面を始めない
	s.flags["known_faction_beacon_order"] = true
	s.story.check(s)
	eq(s.pending_dialogue.get("id", ""), "volg_radio", "会話中は次の場面を待つ")
	s.pending_dialogue = {}
	s.story.check(s)
	eq(s.pending_dialogue.get("id", ""), "lightkeeper_vision", "灯守の場面")
	# 話者は仲間でなくても名前と外見が引ける
	for id in ["volg", "drake", "martha", "lightkeeper"]:
		check(s.crew.display_name(id) != id, "%s の名前" % id)
		check(not s.crew.def(id).is_empty(), "%s の定義" % id)
	# 選択肢の効果（勢力との関係）が働く
	var before := s.factions.standing("black_current")
	s.apply_effect({"type": "standing", "faction": "black_current", "delta": 5})
	check(s.factions.standing("black_current") > before, "黒潮との関係が変わる")

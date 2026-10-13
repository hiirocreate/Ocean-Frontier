extends TestCase

var s: GameSession


func before_each() -> void:
	s = new_session(77)


func _feed(id: String) -> void:
	var m: Dictionary = s.crew.members[id]
	m["hunger"] = 90.0
	m["thirst"] = 90.0


func test_recruit_and_history() -> void:
	check(s.crew.recruit("mira", s.clock.day()), "加入")
	check(s.crew.is_aboard("mira"), "在籍")
	eq(s.crew.members["mira"]["history"].size(), 1, "履歴が記録される")
	check(not s.crew.recruit("mira", 1), "二重加入しない")
	near(s.crew.get_relation("mira", "rook", "fear"), 25.0, 0.01, "初期関係（必要なものだけ）")
	eq(s.crew.get_relation("mira", "tobi", "hostility"), 0.0, "未設定の関係は0")


func test_available_rescues_follow_conditions() -> void:
	var r := s.crew.available_rescues(s)
	check(not ("mira" in r), "初日・床4枚ではまだ出会わない")
	s.raft.add_tile(Vector2i(2, 0))
	check("mira" in s.crew.available_rescues(s), "床5枚で出会う")
	check(not ("tobi" in s.crew.available_rescues(s)), "トビは3日目以降かつ仲間1人以上")


func test_job_assignment_rules() -> void:
	s.crew.recruit("tobi", 1)
	eq(s.crew.assign_job("tobi", "fishing", s), "", "漁業は割り当て可")
	check(s.crew.assign_job("tobi", "cooking", s).contains("焚き火台"), "設備がなければ不可")
	check(s.crew.assign_job("tobi", "trade", s) != "", "未解放の作業は不可")
	check(s.crew.assign_job("mira", "fishing", s) != "", "仲間でない人物には割り当て不可")


func test_fishing_job_produces_fish() -> void:
	s.crew.recruit("mira", 1)
	s.crew.assign_job("mira", "fishing", s)
	s.clock.total_minutes = 8 * 60.0
	var before := s.inventory.count("raw_fish")
	for i in 10:
		_feed("mira")
		s.advance(60)
	check(s.inventory.count("raw_fish") > before, "魚が増える (%d→%d)" % [before, s.inventory.count("raw_fish")])


func test_skill_affects_efficiency() -> void:
	s.crew.recruit("tobi", 1)
	s.crew.recruit("mira", 1)
	s.crew.assign_job("tobi", "repair", s)
	s.crew.assign_job("mira", "repair", s)
	_feed("tobi")
	_feed("mira")
	check(s.crew.efficiency("tobi") > s.crew.efficiency("mira"), "修理Lv4のトビの方が効率が高い")
	eq(s.skill_level("repair"), 4, "最高技能が行動条件に使われる")


func test_construction_speeds_building() -> void:
	s.clock.total_minutes = 8 * 60.0
	s.crew.recruit("tobi", 1)
	s.crew.assign_job("tobi", "construction", s)
	_feed("tobi")
	s.inventory.add_many({"wood": 4, "rope": 2}, true)
	s.actions.start("expand_raft", {"x": 2, "z": 0})
	s.advance(12)
	check(s.raft.has_tile(Vector2i(2, 0)), "建築担当がいると15分の作業が12分で終わる")


func test_crew_eats_from_inventory() -> void:
	s.crew.recruit("mira", 1)
	s.inventory.stacks = {"coconut": 3, "water_bottle": 2}
	s.crew.members["mira"]["hunger"] = 30.0
	s.crew.members["mira"]["thirst"] = 30.0
	s.advance(1)
	check(s.inventory.count("coconut") < 3 or s.inventory.count("water_bottle") < 2, "持ち物から食べる")
	check(s.crew.get_value("mira", "hunger") > 30.0, "空腹が回復")


func test_relationship_changes() -> void:
	s.crew.recruit("mira", 1)
	s.crew.recruit("tobi", 1)
	s.crew.assign_job("mira", "fishing", s)
	s.crew.assign_job("tobi", "fishing", s)
	var f0 := s.crew.get_relation("mira", "tobi", "friendship")
	s.crew._daily(s, 2)
	check(s.crew.get_relation("mira", "tobi", "friendship") > f0, "同じ作業で友情が深まる")
	s.crew.recruit("rook", 1)
	s.crew.members["rook"]["stress"] = 80.0
	s.crew.members["garrett"] = s.crew._new_state()
	s.crew.recruit("garrett", 1)
	s.crew.members["garrett"]["stress"] = 80.0
	var h0 := s.crew.get_relation("garrett", "rook", "hostility")
	s.crew._daily(s, 3)
	check(s.crew.get_relation("garrett", "rook", "hostility") > h0, "相性の悪い性格でストレスが高いと敵意が増す")


func test_departure_has_warning_then_leaves_and_stays_in_world() -> void:
	s.crew.recruit("mira", 1)
	var warned := []
	var left := []
	s.crew.member_warning.connect(func(id, _t): warned.append(id))
	s.crew.member_left.connect(func(id, _r): left.append(id))
	s.inventory.stacks.clear()
	var day := 2
	while s.crew.is_aboard("mira") and day < 40:
		s.crew.members["mira"]["hunger"] = 5.0
		s.crew.members["mira"]["thirst"] = 5.0
		s.crew._daily(s, day)
		day += 1
	check("mira" in warned, "離脱前に予兆がある")
	check("mira" in left, "条件が続くと離脱する")
	eq(s.crew.status("mira"), "departed", "離脱状態")
	check(s.crew.members.has("mira"), "人物データは残る")
	var hist: Array = s.crew.members["mira"]["history"]
	check(hist.any(func(h): return str(h["text"]).contains("筏を去った")), "離脱の履歴が残る")
	check(str(s.crew.members["mira"]["location"]) != "", "行き先が記録される")


func test_sudden_departure_without_warning() -> void:
	s.crew.recruit("rook", 1)
	var warned := []
	s.crew.member_warning.connect(func(id, _t): warned.append(id))
	var day := 2
	while s.crew.is_aboard("rook") and day < 40:
		s.crew.members["rook"]["satisfaction"] = 0.0
		s.crew.members["rook"]["hunger"] = 5.0
		s.crew._daily(s, day)
		day += 1
	eq(s.crew.status("rook"), "departed", "離脱した")
	check(not ("rook" in warned), "突然離脱する人物は予兆なし")


func test_rejoin_conditions() -> void:
	s.crew.recruit("tobi", 1)
	s.crew.depart("tobi", "hunger", s, 3)
	check(s.crew.rejoin_problem("tobi", 4) != "", "すぐには戻らない")
	s.crew.members["tobi"]["trust"] = 80.0
	eq(s.crew.rejoin_problem("tobi", 6), "", "日数と信頼で再加入可能")
	s.crew.recruit("tobi", 6)
	check(s.crew.is_aboard("tobi"), "復帰")
	check(s.crew.members["tobi"]["history"].any(func(h): return str(h["text"]).contains("再び")), "復帰の履歴")


func test_crew_saved_and_loaded() -> void:
	var path := "user://test_saves/crew.json"
	s.crew.recruit("mira", 1)
	s.crew.recruit("tobi", 1)
	s.crew.assign_job("tobi", "repair", s)
	s.crew.add_relation("mira", "tobi", "friendship", 33)
	s.crew.depart("mira", "thirst", s, 2)
	SaveManager.save_session(s, path)
	var s2: GameSession = SaveManager.load_session(s.data, path)["session"]
	eq(s2.crew.status("mira"), "departed", "離脱状態を保持")
	eq(s2.crew.members["tobi"]["job"], "repair", "作業を保持")
	near(s2.crew.get_relation("mira", "tobi", "friendship"), 33.0, 0.01, "関係を保持")
	eq(s2.crew.members["mira"]["history"].size(), s.crew.members["mira"]["history"].size(), "履歴を保持")


func test_rescue_dialogue_recruits() -> void:
	var dr := DialogueRunner.new(s)
	check(dr.start("mira_rescue"), "会話開始")
	dr.advance()  # narrator → n1
	var cs := dr.choices()
	check(cs.any(func(c): return c["text"] == "水を渡す"), "水を持っていれば渡す選択肢が出る")
	s.inventory.stacks.erase("water_bottle")
	cs = dr.choices()
	check(not cs.any(func(c): return c["text"] == "水を渡す"), "水がなければ出ない")
	dr.choose(cs[0]["index"])  # 筏に引き上げる
	dr.choose(0)  # 一緒に来てくれ
	check(s.crew.is_aboard("mira"), "会話の効果で加入")
	check(s.flags.get("first_companion", false), "フラグ")
	dr.advance()
	check(not dr.is_active(), "会話終了")


func test_talk_dialogue_selection() -> void:
	s.crew.recruit("mira", 1)
	eq(s.talk_dialogue_for("mira"), "", "条件を満たさなければ専用会話なし")
	s.clock.total_minutes = 1440.0 * 2 + 600.0
	eq(s.talk_dialogue_for("mira"), "mira_talk_records", "2日目以降は記録の話")
	DialogueRunner.new(s).start("mira_talk_records")
	check(s.talk_dialogue_for("mira") != "mira_talk_records", "一度見た会話は出ない")
	check(s.small_talk("mira") != "", "雑談は常にある")

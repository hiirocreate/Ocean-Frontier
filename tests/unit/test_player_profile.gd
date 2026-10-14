extends TestCase
## 主人公作成（性別・年齢・背景・特性）とシナリオ分岐の必須テスト

const BAND_AGES := {"young": 12, "youth": 17, "adult": 25, "mature": 35}


func _profile(d: GameData, g: String, a: int, bg: String = "amnesia", traits: Array = []) -> PlayerProfile:
	var p := PlayerProfile.create_default(d)
	p.gender = g
	p.age = a
	p.background_id = bg
	p.traits = traits
	p.appearance = PlayerProfile.default_appearance(g)
	p.finalize(d)
	return p


func _session(p: PlayerProfile, game_seed: int = 7) -> GameSession:
	var s := GameSession.new(game_data())
	s.new_game(game_seed, p)
	s.pending_dialogue = {}
	return s


func test_new_game_male_and_female() -> void:
	var d := game_data()
	for g in ["male", "female"]:
		var s := GameSession.new(d)
		s.new_game(1, _profile(d, g, 20))
		eq(s.profile.gender, g, "性別 %s で開始" % g)
		check(s.profile.validate(d).is_empty(), "設定が正しい")
		check(s.flags.get("gender_" + g, false), "物語フラグにも反映")


func test_age_band_boundaries() -> void:
	var expect := {10: "young", 15: "young", 16: "youth", 19: "youth", 20: "adult", 29: "adult", 30: "mature", 40: "mature"}
	for a in expect:
		eq(PlayerProfile.age_band_of(a), expect[a], "%d歳" % a)


func test_age_out_of_range_rejected() -> void:
	for a in [9, 41, -1, 100]:
		check(PlayerProfile.validate_age(a) != "", "%d歳は拒否" % a)
	check(PlayerProfile.validate_age(15.5) != "", "小数は拒否")
	check(PlayerProfile.validate_age("abc") != "", "文字列は拒否")
	eq(PlayerProfile.age_band_of(9), "", "範囲外は年齢帯なし")
	var p := _profile(game_data(), "male", 20)
	p.age = 41
	check(not p.validate(game_data()).is_empty(), "プロフィール全体の検証でも拒否")


func test_skip_creation_uses_defaults() -> void:
	var s := GameSession.new(game_data())
	s.new_game(3)
	check(s.profile.validate(s.data).is_empty(), "既定の主人公は正しい設定")
	eq(s.profile.background_id, "amnesia", "既定は記憶喪失")
	check(not s.pending_dialogue.is_empty(), "導入会話がある")


func test_background_trait_combinations() -> void:
	var d := game_data()
	var ids: Array = d.player_traits.keys()
	var combos: Array = [[]]
	for i in ids.size():
		combos.append([ids[i]])
		for j in range(i + 1, ids.size()):
			combos.append([ids[i], ids[j]])
	var valid := 0
	var rejected := 0
	for bg in d.backgrounds:
		for c in combos:
			var probs := PlayerProfile.trait_problems(d, c, bg)
			var p := _profile(d, "female", 18, bg, c)
			if probs.is_empty():
				valid += 1
				check(p.validate(d).is_empty(), "有効な組み合わせ %s %s" % [bg, c])
				for k in p.abilities:
					check(int(p.abilities[k]) >= 0 and int(p.abilities[k]) <= 4, "能力値が範囲内")
			else:
				rejected += 1
				check(not p.validate(d).is_empty(), "不正な組み合わせは検証で拒否 %s %s" % [bg, c])
	check(valid > 50, "多くの組み合わせが選べる (%d)" % valid)
	check(rejected > 0, "重複・排他は拒否される (%d)" % rejected)
	check(not PlayerProfile.trait_problems(d, ["drift_veteran"], "drift_ship").is_empty(), "背景で得た特性の重複を検出")
	check(not PlayerProfile.trait_problems(d, ["outdoorsy", "drift_veteran"], "amnesia").is_empty(), "排他の特性を検出")
	check(not PlayerProfile.trait_problems(d, ["observant", "negotiator", "first_aid"], "amnesia").is_empty(), "3個以上は拒否")


func test_profile_drives_dialogue_look_abilities_events() -> void:
	var d := game_data()
	var p := _profile(d, "female", 12, "drift_ship", ["repair_knack"])
	p.name = "ミナト"
	p.appearance["hair_color"] = "silver"
	var s := GameSession.new(d)
	s.new_game(5, p)
	var intro: Dictionary = s.pending_dialogue["nodes"]
	var dr := DialogueRunner.new(s)
	var shown := dr.display_node(intro["self"])
	check(str(shown["text"]).contains("ミナト") and str(shown["text"]).contains("12歳"), "導入会話が名前と年齢を参照")
	check(str(intro["start"]["text"]).contains(d.backgrounds["drift_ship"]["intro"]), "背景ごとの導入")
	var look := s.profile.look(d)
	eq(look["colors"]["hair"], "#c8c8d0", "外見データが髪色と一致")
	eq(look["age_band"], "young", "外見データの年齢帯")
	var young := PlayerProfile.body_params_for("female", 12)
	var adult := PlayerProfile.body_params_for("female", 25)
	check(young["head"] > adult["head"] and young["limb"] < adult["limb"], "若年層は縮小ではなく頭身・手足の比率が違う")
	check(young["height"] < adult["height"], "若年層は背が低い")
	check(PlayerProfile.body_params_for("male", 25)["shoulder"] > adult["shoulder"], "性別で体格表現が違う")
	eq(s.profile.ability("survival"), 1, "背景（漂流船育ち→漂流生活の経験者）")
	eq(s.profile.ability("repair"), 1, "選んだ特性")
	eq(s.profile.ability("learning"), 1, "年齢帯の小さな補正")
	check(s.survival.rate_mult < 1.0, "能力が生存システムに反映")
	check(s.inventory.count("rope") >= 3, "背景の初期アイテム")
	# 会話差分：トビとの初対面（漂流船育ち）
	dr = DialogueRunner.new(s)
	dr.start("tobi_rescue")
	var cs := dr.choices()
	check(cs.any(func(c): return str(c["text"]).contains("同じ船の子")), "背景で選択肢が追加される")
	# 年齢イベント
	check(Conditions.check(d.random_events["young_doubt"]["condition"], s) or s.crew.aboard_ids().is_empty(), "年齢帯イベントの条件")
	s.crew.recruit("mira", 1)
	s.clock.total_minutes = 1440.0 * 2 + 600
	check(Conditions.check(d.random_events["young_doubt"]["condition"], s), "若年層のイベントが起きうる")
	check(not Conditions.check(d.random_events["veteran_advice"]["condition"], s), "成人中期のイベントは起きない")


func test_npc_reaction_combines_personality() -> void:
	var d := game_data()
	var young := _session(_profile(d, "male", 11))
	var mature := _session(_profile(d, "male", 36))
	var g: Dictionary = d.survivors["garrett"]
	var sel: Dictionary = d.survivors["selene"]
	eq(young.profile.address_for(g), "坊主", "元軍人は若い男子を坊主と呼ぶ")
	eq(mature.profile.address_for(g), mature.profile.name, "成人は名前で呼ぶ")
	eq(young.profile.address_for(sel), "お若いの", "商人は性格に応じた呼び方")
	eq(young.profile.address_for(d.survivors["mira"]), young.profile.name, "研究者は年齢に関係なく名前で呼ぶ")
	var dy := DialogueRunner.new(young)
	dy.start("garrett_rescue")
	var dm := DialogueRunner.new(mature)
	dm.start("garrett_rescue")
	check(dy.choices().any(func(c): return str(c["text"]).contains("若くても")), "若い主人公には決意を示す選択肢")
	check(dm.choices().any(func(c): return str(c["text"]).contains("経験")), "年長の主人公には経験を語る選択肢")
	check(dy.choices().size() >= 2 and dm.choices().size() >= 2, "どちらも共通の選択肢は残る")


func test_save_load_keeps_profile_and_migrates_old_saves() -> void:
	var d := game_data()
	var p := _profile(d, "female", 33, "pirate_escapee", ["first_aid", "observant"])
	p.name = "シオ"
	p.appearance["face"] = "freckles"
	var s := _session(p)
	s.apply_effect({"type": "past_event", "text": "テストの記録"})
	var path := "user://test_saves/profile.json"
	SaveManager.save_session(s, path)
	var s2: GameSession = SaveManager.load_session(d, path)["session"]
	eq(JSON.stringify(s2.profile.to_dict()), JSON.stringify(s.profile.to_dict()), "セーブ・ロード後も主人公設定が同じ")
	eq(s2.profile.past_events.size(), 1, "過去の出来事の記録")
	# 旧形式（format 1・主人公情報なし）からの移行
	var old := s.to_dict()
	old.erase("profile")
	var payload := JSON.stringify(old)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"format": 1, "checksum": payload.md5_text(), "payload": payload}))
	f.close()
	var l := SaveManager.load_session(d, path)
	check(l["ok"], "旧セーブも読める")
	check(l["session"].profile.validate(d).is_empty(), "既定値で補完される")
	check(l["warnings"].any(func(w): return str(w).contains("旧形式")), "移行を記録")
	var bad := PlayerProfile.from_dict({"gender": "x", "age": 99, "background_id": "nope", "traits": ["drift_veteran", "outdoorsy"]}, d)
	check(bad["profile"].validate(d).is_empty(), "壊れた主人公データは安全な値に補正")


## 全性別×全年齢帯でメインストーリーを完結できる（仲間・特定の背景に依存しない）
func test_main_story_completable_for_all_profiles() -> void:
	var d := game_data()
	for g in ["male", "female"]:
		for band in BAND_AGES:
			var s := _session(_profile(d, g, BAND_AGES[band]))
			var tag := "%s/%s" % [g, band]
			while s.raft.tiles.size() < 6:
				s.raft.add_tile(s.raft.candidate_positions()[0])
			s.inventory.add_many({"water_bottle": 5}, true)
			s.flags["signal_event_seen"] = true
			s.flags["first_companion"] = true
			s.story.check(s)
			s.discover_site("tide_union_market")
			s.counters["trades"] = 1
			s.flags["visited_red_tide"] = true
			s.story.check(s)
			s.flags["radio_coordinates"] = true
			s.inventory.add_many({"research_log": 1, "old_key": 1, "resonance_scanner": 1}, true)
			s.flags["lighthouse_seen"] = true
			for i in 4:
				s.story.check(s)
			eq(s.story.chapter, 5, "%s: 最終章に到達" % tag)
			s.flags["reached_atlas_core"] = true
			s.pending_dialogue = {}
			finish_scenes(s)
			eq(s.pending_dialogue.get("id", ""), "final_choice", "%s: 最後の選択" % tag)
			check(str(s.story.recall_text(s)) != "", "%s: 回想の台詞" % tag)
			check(s.story.choose_ending(s, "keep_secret"), "%s: エンディング到達" % tag)


## 性別・年齢だけを理由に必須コンテンツ（仲間・エンディング・探索地点・章の目標）が消えない
func test_required_content_not_locked_by_gender_or_age() -> void:
	var d := game_data()
	var baseline := -1
	for g in ["male", "female"]:
		for band in BAND_AGES:
			for bg in d.backgrounds:
				var s := _session(_profile(d, g, BAND_AGES[band], bg))
				var tag := "%s/%s/%s" % [g, band, bg]
				for sid in d.survivors:
					var dr := DialogueRunner.new(s)
					dr.start(str(d.survivors[sid]["recruit"]["dialogue"]))
					var guard := 0
					while dr.is_active() and guard < 20:
						guard += 1
						var cs := dr.choices()
						if cs.is_empty():
							dr.advance()
						else:
							dr.choose(int(cs[0]["index"]))
					check(s.crew.is_aboard(sid), "%s: %sを仲間にできる" % [tag, sid])
				var av := s.story.available_endings(s)
				check("keep_secret" in av and "leave_partially" in av, "%s: 常に選べる結末" % tag)
				var n := 0
				for cid in d.chapters:
					n += d.chapters[cid]["objectives"].size()
				if baseline < 0:
					baseline = n
				eq(n, baseline, "%s: 章の目標は共通" % tag)
				var sites_ok := true
				for sid in d.sites:
					if bool(d.sites[sid].get("hidden", false)):
						continue
					s.update_location(s.site_position(sid))
					sites_ok = sites_ok and s.is_site_discovered(sid)
				check(sites_ok, "%s: すべての地点を発見できる" % tag)

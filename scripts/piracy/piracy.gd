class_name Piracy
extends RefCounted
## 海賊行為と捕虜（仕様28）。どの行為も評判・勢力の態度・仲間の反応（piracy_today）に影響する。


static func _record(s: GameSession, infamy: float, fear: float, trust: float) -> void:
	s.counters["piracy_today"] = float(s.counters.get("piracy_today", 0)) + 1.0
	s.counters["piracy_total"] = float(s.counters.get("piracy_total", 0)) + 1.0
	s.change_reputation("infamy", infamy)
	s.change_reputation("fear", fear)
	s.change_reputation("trust", trust)


## 保護料の要求（勢力の拠点で）。恐怖と艦隊の戦力が必要。
static func protection_problem(s: GameSession, faction: String) -> String:
	if s.data.factions.get(faction, {}).get("kind") == "pirate":
		return "海賊から保護料は取れない"
	if float(s.reputation.get("fear", 0)) < 25.0:
		return "恐怖の評判が足りない（25以上が必要）"
	var p := 0.0
	for uid in s.fleet.ships:
		if s.fleet.at_home(uid):
			p += s.fleet.power(uid, s)
	var need := float(s.factions.factions.get(faction, {}).get("defense", 50)) * 0.5
	if p < need:
		return "艦隊の戦力が足りない（%d／%d）" % [int(p), int(need)]
	if bool(s.flags.get("protection_paid_day_%d_%s" % [s.clock.day(), faction], false)):
		return "今日はもう取り立てた"
	return ""


static func demand_protection(s: GameSession, faction: String) -> Dictionary:
	var prob := protection_problem(s, faction)
	if prob != "":
		return {"ok": false, "error": prob}
	var coins := int(30 + float(s.reputation.get("fear", 0)) * 1.5)
	s.money += coins
	s.flags["protection_paid_day_%d_%s" % [s.clock.day(), faction]] = true
	s.factions.change_standing(faction, -15.0)
	_record(s, 5.0, 3.0, -4.0)
	return {"ok": true, "coins": coins}


## 通行料の要求（海上で出会った商人に）。恐怖が高いほど払わせやすい。成功しなければ戦闘になる。
static func demand_toll(s: GameSession) -> Dictionary:
	var chance := clampf(0.35 + float(s.reputation.get("fear", 0)) / 100.0, 0.0, 0.95)
	_record(s, 3.0, 2.0, -2.0)
	if s.rng.randf() < chance:
		var coins := s.rng.randi_range(15, 40)
		s.money += coins
		s.factions.change_standing("tide_union", -5.0)
		return {"ok": true, "coins": coins}
	s.start_combat("merchant_guards", "sea", "toll")
	return {"ok": false}


## 漂流物の強奪（商人の筏を襲う）
static func rob_drifter(s: GameSession) -> void:
	_record(s, 4.0, 2.0, -3.0)
	s.factions.change_standing("tide_union", -8.0)
	s.start_combat("merchant_guards", "sea", "rob")


## 海賊同盟への参加
static func alliance_problem(s: GameSession) -> String:
	if bool(s.flags.get("joined_pirate_alliance", false)):
		return "すでに海賊同盟の一員だ"
	if s.factions.standing("black_current") < 30.0 and float(s.reputation.get("infamy", 0)) < 25.0:
		return "黒潮に認められていない（友好度30以上か悪名25以上が必要）"
	return ""


static func join_alliance(s: GameSession) -> String:
	var p := alliance_problem(s)
	if p != "":
		return p
	s.flags["joined_pirate_alliance"] = true
	s.factions.change_standing("black_current", 25.0)
	s.factions.change_standing("iron_reef", -35.0)
	s.factions.change_standing("tide_union", -15.0)
	_record(s, 10.0, 5.0, -5.0)
	return ""


# ---------- 捕虜 ----------
static func release_prisoner(s: GameSession, index: int) -> String:
	if index < 0 or index >= s.prisoners.size():
		return "捕虜がいません"
	var p: Dictionary = s.prisoners[index]
	s.prisoners.remove_at(index)
	s.change_reputation("trust", 3.0)
	if str(p.get("faction", "")) != "":
		s.factions.change_standing(str(p["faction"]), 5.0)
	return ""


## 身代金：その勢力の拠点の近くにいるか、輸送できる船（食料と水が必要）があること
static func ransom_problem(s: GameSession, index: int) -> String:
	if index < 0 or index >= s.prisoners.size():
		return "捕虜がいません"
	var fac := str(s.prisoners[index].get("faction", ""))
	if fac == "" or not s.factions.factions.has(fac):
		return "身代金を払う勢力がない"
	var base := str(s.data.factions[fac].get("base_site", ""))
	if base != "" and s.is_site_discovered(base) and s.site_distance(base) <= 60.0:
		return ""
	var ship_ok := false
	for uid in s.fleet.ships:
		if s.fleet.at_home(uid) and s.fleet.crew_count(uid) >= 1:
			ship_ok = true
	if not ship_ok:
		return "捕虜を輸送できる船がない（拠点の近くなら直接引き渡せる）"
	var lack := s.inventory.missing({"canned_food": 1, "water_bottle": 1})
	if not lack.is_empty():
		return "輸送中の食料と水が不足しています"
	return ""


static func ransom_prisoner(s: GameSession, index: int) -> Dictionary:
	var prob := ransom_problem(s, index)
	if prob != "":
		return {"ok": false, "error": prob}
	var p: Dictionary = s.prisoners[index]
	var fac := str(p["faction"])
	var base := str(s.data.factions[fac].get("base_site", ""))
	if base == "" or s.site_distance(base) > 60.0:
		s.inventory.remove_many({"canned_food": 1, "water_bottle": 1})
	s.prisoners.remove_at(index)
	var coins := 40 + int(s.factions.strength(fac) * 0.2)
	s.money += coins
	s.factions.change_standing(fac, 2.0)
	s.change_reputation("fear", 1.0)
	return {"ok": true, "coins": coins}


## 捕虜を船員として迎える（恐怖か信頼が高いほど応じやすい）
static func recruit_prisoner(s: GameSession, index: int) -> Dictionary:
	if index < 0 or index >= s.prisoners.size():
		return {"ok": false, "error": "捕虜がいません"}
	var chance := 0.3 + maxf(float(s.reputation.get("fear", 0)), float(s.reputation.get("trust", 0))) / 150.0
	if s.rng.randf() < chance:
		s.prisoners.remove_at(index)
		s.fleet.sailors_pool += 1
		return {"ok": true}
	return {"ok": false, "error": "捕虜は首を縦に振らなかった"}


## 毎日: 捕虜は食料と水を1ずつ消費。足りないと逃走する。
static func daily_prisoners(s: GameSession) -> Array[String]:
	var out: Array[String] = []
	for i in range(s.prisoners.size() - 1, -1, -1):
		if s.inventory.remove_many({"canned_food": 1}) or s.inventory.remove_many({"potato": 1}) or s.inventory.remove_many({"raw_fish": 1}):
			if s.inventory.remove("water_bottle", 1):
				continue
		s.prisoners.remove_at(i)
		out.append("食料と水が足りず、捕虜が逃げ出した")
	return out

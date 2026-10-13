class_name Conditions
extends RefCounted
## データ駆動の条件式（仲間の加入・会話・イベント・クエストで共用）。
## 空の条件は常に真。複数キーはすべて満たす必要がある（AND）。

const KEYS := ["all", "any", "not", "day_min", "day_max", "tiles_min", "buildings_min", "crew_min", "crew_max",
	"flags_all", "flags_none", "has_items", "member_aboard", "member_departed", "member_met", "trust_min",
	"counter_min", "hour_between", "chance", "buildings_has", "site_discovered", "standing_min", "ship_type_owned", "prisoners_min",
	"departed_min", "reputation_min", "allied_count_min", "ships_min", "crew_loyalty_avg_min", "clue_count_min", "chapter_min",
	"player_gender", "player_age_min", "player_age_max", "player_age_band", "player_background", "player_trait", "ability_min", "site_explored"]


static func check(cond: Variant, s: GameSession) -> bool:
	if not (cond is Dictionary) or cond.is_empty():
		return true
	for k in cond:
		if not _check_one(str(k), cond[k], s):
			return false
	return true


static func _check_one(k: String, v: Variant, s: GameSession) -> bool:
	match k:
		"all":
			return v.all(func(c): return check(c, s))
		"any":
			return v.any(func(c): return check(c, s))
		"not":
			return not check(v, s)
		"day_min":
			return s.clock.day() >= int(v)
		"day_max":
			return s.clock.day() <= int(v)
		"tiles_min":
			return s.raft.tiles.size() >= int(v)
		"buildings_min":
			return s.raft.buildings.size() >= int(v)
		"crew_min":
			return s.crew.aboard_ids().size() >= int(v)
		"crew_max":
			return s.crew.aboard_ids().size() <= int(v)
		"flags_all":
			return v.all(func(f): return bool(s.flags.get(f, false)))
		"flags_none":
			return not v.any(func(f): return bool(s.flags.get(f, false)))
		"has_items":
			return s.inventory.has_all(v)
		"member_aboard":
			return s.crew.is_aboard(str(v))
		"member_departed":
			return s.crew.status(str(v)) == "departed"
		"member_met":
			return s.crew.status(str(v)) != "unmet"
		"trust_min":
			for id in v:
				if float(s.crew.get_value(str(id), "trust")) < float(v[id]):
					return false
			return true
		"counter_min":
			for c in v:
				if float(s.counters.get(c, 0.0)) < float(v[c]):
					return false
			return true
		"hour_between":
			var h := s.clock.hour()
			var a := int(v[0])
			var b := int(v[1])
			return (h >= a and h < b) if a <= b else (h >= a or h < b)
		"chance":
			return s.rng.randf() < float(v)
		"buildings_has":
			return s.raft.has_building(str(v))
		"site_discovered":
			return s.is_site_discovered(str(v))
		"standing_min":
			for f in v:
				if s.factions.standing(str(f)) < float(v[f]):
					return false
			return true
		"ship_type_owned":
			return s.fleet.ships.values().any(func(sh): return sh["type"] == str(v))
		"ships_min":
			return s.fleet.ships.size() >= int(v)
		"prisoners_min":
			return s.prisoners.size() >= int(v)
		"departed_min":
			return s.crew.departed_ids().size() >= int(v)
		"reputation_min":
			for rk in v:
				if float(s.reputation.get(rk, 0)) < float(v[rk]):
					return false
			return true
		"allied_count_min":
			var n := 0
			for f in s.factions.factions:
				if s.factions.factions[f].get("allied_player", false):
					n += 1
			return n >= int(v)
		"crew_loyalty_avg_min":
			var ids := s.crew.aboard_ids()
			if ids.is_empty():
				return false
			var total := 0.0
			for id in ids:
				total += s.crew.get_value(id, "loyalty")
			return total / ids.size() >= float(v)
		"clue_count_min":
			return s.clue_count() >= int(v)
		"chapter_min":
			return s.story.chapter >= int(v)
		"player_gender":
			return s.profile.gender == str(v)
		"player_age_min":
			return s.profile.age >= int(v)
		"player_age_max":
			return s.profile.age <= int(v)
		"player_age_band":
			return s.profile.age_band() in (v if v is Array else [v])
		"player_background":
			return s.profile.background_id in (v if v is Array else [v])
		"player_trait":
			return s.profile.has_trait(s.data, str(v))
		"site_explored":
			return int(s.sites_state.get(str(v), {}).get("explored", 0)) > 0
		"ability_min":
			for ab in v:
				if s.profile.ability(str(ab)) < int(v[ab]):
					return false
			return true
	GameLog.warn("未知の条件キー: %s" % k)
	return false


## データ検証用: 未知のキーを返す
static func unknown_keys(cond: Variant) -> Array[String]:
	var out: Array[String] = []
	if not (cond is Dictionary):
		return out
	for k in cond:
		if not (k in KEYS):
			out.append(str(k))
		elif k in ["all", "any"] and cond[k] is Array:
			for c in cond[k]:
				out.append_array(unknown_keys(c))
		elif k == "not":
			out.append_array(unknown_keys(cond[k]))
	return out

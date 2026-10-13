class_name DataValidator
extends RefCounted
## 開発用データ検証（仕様44）。問題点の文字列配列を返す（空なら正常）。

const KNOWN_EFFECTS := ["raft_add_tile", "repair_item", "place_building", "rest", "explore_site", "story_beat", "add_ship", "repair_ship", "fleet_mission", "found_pirate_crew"]
const KNOWN_USE_EFFECTS := ["health", "hunger", "thirst", "fatigue", "injury"]
const CATEGORIES := ["material", "consumable", "weapon", "armor", "tool", "ship_part", "story"]


static func validate(d: GameData) -> Array[String]:
	var e: Array[String] = []
	e.append_array(d.load_errors)
	_items(d, e)
	_actions(d, e)
	_buildings(d, e)
	_zones(d, e)
	_balance(d, e)
	_characters(d, e)
	_dialogues(d, e)
	_sites(d, e)
	_factions(d, e)
	return e


static func _factions(d: GameData, e: Array[String]) -> void:
	for fid in d.factions:
		var f: Dictionary = d.factions[fid]
		var o := "faction " + str(fid)
		var base := str(f.get("base_site", ""))
		if base != "" and not d.sites.has(base):
			e.append("%s: 拠点 '%s' が存在しません" % [o, base])
		for other in f.get("relations", {}):
			if not d.factions.has(str(other)):
				e.append("%s: 関係の相手 '%s' が存在しません" % [o, other])
		for item in f.get("market", {}).get("sells", {}):
			if not d.items.has(str(item)):
				e.append("%s: 販売品 '%s' が存在しません" % [o, item])
		for item in f.get("market", {}).get("buys", []):
			if not d.items.has(str(item)):
				e.append("%s: 買取品 '%s' が存在しません" % [o, item])
		if not d.enemies.has(str(f.get("raider_enemy", ""))):
			e.append("%s: raider_enemy が存在しません" % o)
	for sid in d.sites:
		var fac := str(d.sites[sid].get("faction", ""))
		if fac != "" and not d.factions.has(fac):
			e.append("site %s: 存在しない勢力 '%s'" % [sid, fac])
	for shid in d.ships:
		var sh: Dictionary = d.ships[shid]
		var ba := str(sh.get("build_action", ""))
		if not d.actions.has(ba) or d.actions[ba].get("effect_params", {}).get("ship") != shid:
			e.append("ship %s: 建造行動が不正" % shid)
		for item in sh.get("supply_per_day", {}):
			if not d.items.has(str(item)):
				e.append("ship %s: 補給品 '%s' が存在しません" % [shid, item])
		if int(sh.get("crew_min", 0)) > int(sh.get("crew_max", 0)):
			e.append("ship %s: crew_min > crew_max" % shid)
	for mid in d.missions:
		if not (str(d.missions[mid].get("target", "none")) in ["none", "raid_target", "faction", "zone"]):
			e.append("mission %s: 不正な target" % mid)
	for tid in d.raid_targets:
		var t: Dictionary = d.raid_targets[tid]
		if not d.factions.has(str(t.get("faction", ""))):
			e.append("raid_target %s: 存在しない勢力" % tid)
		_loot_table(d, e, "raid_target %s.loot" % tid, t.get("loot", {}))
		var cs := str(t.get("capture_ship", ""))
		if cs != "" and not d.ships.has(cs):
			e.append("raid_target %s: 存在しない船種 '%s'" % [tid, cs])


static func _loot_table(d: GameData, e: Array[String], owner: String, t: Variant) -> void:
	if not (t is Dictionary) or t.is_empty():
		return
	for en in t.get("entries", []):
		if not d.items.has(str(en.get("item", ""))):
			e.append("%s: 存在しないアイテム '%s'" % [owner, str(en.get("item"))])


static func _sites(d: GameData, e: Array[String]) -> void:
	for zid in d.zones:
		var b: Variant = d.zones[zid].get("bounds", [])
		if not (b is Array) or b.size() != 4 or float(b[0]) >= float(b[2]) or float(b[1]) >= float(b[3]):
			e.append("zone %s: bounds は [x0,z0,x1,z1]（x0<x1, z0<z1）" % zid)
	for sid in d.sites:
		var sd: Dictionary = d.sites[sid]
		var o := "site " + str(sid)
		if not d.zones.has(str(sd.get("zone", ""))):
			e.append("%s: 存在しない海域" % o)
		var pos: Variant = sd.get("position", [])
		if not (pos is Array) or pos.size() != 2:
			e.append("%s: position は [x,z]" % o)
		var ea := str(sd.get("explore_action", ""))
		if ea != "":
			if not d.actions.has(ea):
				e.append("%s: 探索行動 '%s' が存在しません" % [o, ea])
			elif d.actions[ea].get("effect") != "explore_site":
				e.append("%s: 探索行動の effect が explore_site ではありません" % o)
		_loot_table(d, e, o + ".loot", sd.get("loot", {}))
		_check_item_map(d, e, o + ".unique_items", sd.get("unique_items", {}))
		var cb: Dictionary = sd.get("combat", {})
		if not cb.is_empty() and not d.enemies.has(str(cb.get("group", ""))):
			e.append("%s: 存在しない敵 '%s'" % [o, str(cb.get("group"))])
		for k in Conditions.unknown_keys(sd.get("discover_condition", {})):
			e.append("%s: 未知の条件キー '%s'" % [o, k])
	for eid in d.enemies:
		var en: Dictionary = d.enemies[eid]
		_loot_table(d, e, "enemy %s.loot" % eid, en.get("loot", {}))
		_check_item_map(d, e, "enemy %s.bribe" % eid, en.get("bribe", {}))
		for k in ["attack", "defense", "hp", "morale"]:
			if not _num_ok(en.get(k), 0.0):
				e.append("enemy %s: %s が不正" % [eid, k])


const EFFECT_TYPES := ["recruit", "trust", "loyalty", "satisfaction", "stress", "relation", "flag", "counter", "give_item", "take_item", "message",
	"coins", "reputation", "standing", "piracy", "start_combat", "discover_site"]
const SPECIAL_SPEAKERS := ["player", "narrator"]


static func _characters(d: GameData, e: Array[String]) -> void:
	var skill_ids := {}
	for jid in d.jobs:
		var j: Dictionary = d.jobs[jid]
		if str(j.get("skill", "")) != "":
			skill_ids[str(j["skill"])] = true
		var fac := str(j.get("facility", ""))
		if fac != "" and not d.buildings.has(fac):
			e.append("job %s: 存在しない設備 '%s'" % [jid, fac])
		var o: Dictionary = j.get("output", {})
		match str(o.get("type", "none")):
			"item":
				if not d.items.has(str(o.get("item", ""))):
					e.append("job %s: 存在しないアイテム" % jid)
			"convert":
				_check_item_map(d, e, "job %s.from" % jid, o.get("from", {}))
				_check_item_map(d, e, "job %s.to" % jid, o.get("to", {}))
			"production_boost":
				if not d.buildings.has(str(o.get("building", ""))):
					e.append("job %s: 存在しない設備" % jid)
	if not d.jobs.has("idle"):
		e.append("jobs: 'idle' が必要です")
	for tid in d.traits:
		for c in d.traits[tid].get("clash_with", []):
			if not d.traits.has(str(c)):
				e.append("trait %s: 存在しない性格 '%s'" % [tid, c])
		for j in d.traits[tid].get("likes_jobs", []):
			if not d.jobs.has(str(j)):
				e.append("trait %s: 存在しない作業 '%s'" % [tid, j])
	for sid in d.survivors:
		var sv: Dictionary = d.survivors[sid]
		var o := "survivor " + str(sid)
		for t in sv.get("personality", []):
			if not d.traits.has(str(t)):
				e.append("%s: 存在しない性格 '%s'" % [o, t])
		for sk in sv.get("skills", {}):
			if not skill_ids.has(sk):
				e.append("%s: 未知の技能 '%s'" % [o, sk])
			elif int(sv["skills"][sk]) < 0 or int(sv["skills"][sk]) > 5:
				e.append("%s: 技能 %s は0〜5" % [o, sk])
		var rec: Dictionary = sv.get("recruit", {})
		if not d.dialogues.has(str(rec.get("dialogue", ""))):
			e.append("%s: 加入会話 '%s' が存在しません" % [o, str(rec.get("dialogue"))])
		for k in Conditions.unknown_keys(rec.get("condition", {})):
			e.append("%s: 加入条件の未知キー '%s'" % [o, k])
		for t in sv.get("talk", []):
			if not d.dialogues.has(str(t)):
				e.append("%s: 会話 '%s' が存在しません" % [o, t])
		for other in sv.get("relations", {}):
			if not d.survivors.has(str(other)):
				e.append("%s: 関係の相手 '%s' が存在しません" % [o, other])
			for kind in sv["relations"][other]:
				if not (kind in Crew.RELATION_KINDS):
					e.append("%s: 未知の関係 '%s'" % [o, kind])
		var portrait := str(sv.get("portrait", ""))
		if portrait != "" and not ResourceLoader.exists(portrait):
			e.append("%s: 立ち絵が存在しません %s" % [o, portrait])
		for ck in ["skin", "hair", "shirt", "outer", "pants", "accent"]:
			if not Color.html_is_valid(str(sv.get("colors", {}).get(ck, ""))):
				e.append("%s: colors.%s が不正" % [o, ck])


static func _dialogues(d: GameData, e: Array[String]) -> void:
	for did in d.dialogues:
		var nodes: Dictionary = d.dialogues[did].get("nodes", {})
		var o := "dialogue " + str(did)
		if not nodes.has("start"):
			e.append("%s: start ノードがありません" % o)
		for k in Conditions.unknown_keys(d.dialogues[did].get("condition", {})):
			e.append("%s: 未知の条件キー '%s'" % [o, k])
		for nid in nodes:
			var n: Dictionary = nodes[nid]
			var sp := str(n.get("speaker", ""))
			if not (sp in SPECIAL_SPEAKERS) and not d.survivors.has(sp):
				e.append("%s.%s: 存在しない話者 '%s'" % [o, nid, sp])
			var nexts: Array = []
			if n.has("next"):
				nexts.append(str(n["next"]))
			_check_effects(d, e, "%s.%s" % [o, nid], n.get("effects", []))
			for c in n.get("choices", []):
				nexts.append(str(c.get("next", "end")))
				_check_effects(d, e, "%s.%s" % [o, nid], c.get("effects", []))
				for k in Conditions.unknown_keys(c.get("condition", {})):
					e.append("%s.%s: 未知の条件キー '%s'" % [o, nid, k])
			if n.get("choices", []).is_empty() and not n.has("next"):
				e.append("%s.%s: next も choices もありません" % [o, nid])
			for nx in nexts:
				if nx != "end" and not nodes.has(nx):
					e.append("%s.%s: 存在しないノード '%s'" % [o, nid, nx])


static func _check_effects(d: GameData, e: Array[String], owner: String, effects: Array) -> void:
	for ef in effects:
		var t := str(ef.get("type", ""))
		if not (t in EFFECT_TYPES):
			e.append("%s: 未知の効果 '%s'" % [owner, t])
		if t in ["recruit", "trust", "loyalty", "satisfaction", "stress"] and not d.survivors.has(str(ef.get("target", ""))):
			e.append("%s: 存在しない人物 '%s'" % [owner, str(ef.get("target"))])
		if t == "relation" and (not d.survivors.has(str(ef.get("from", ""))) or not d.survivors.has(str(ef.get("to", "")))):
			e.append("%s: 関係の人物が存在しません" % owner)
		if t in ["give_item", "take_item"] and not d.items.has(str(ef.get("item", ""))):
			e.append("%s: 存在しないアイテム '%s'" % [owner, str(ef.get("item"))])
		if t == "standing" and not d.factions.has(str(ef.get("faction", ""))):
			e.append("%s: 存在しない勢力 '%s'" % [owner, str(ef.get("faction"))])
		if t == "reputation" and not (str(ef.get("kind", "")) in ["fame", "fear", "trust", "infamy"]):
			e.append("%s: 不正な評判の種類" % owner)
		if t == "start_combat" and not d.enemies.has(str(ef.get("enemy", ""))):
			e.append("%s: 存在しない敵 '%s'" % [owner, str(ef.get("enemy"))])
		if t == "discover_site" and not d.sites.has(str(ef.get("site", ""))):
			e.append("%s: 存在しない地点 '%s'" % [owner, str(ef.get("site"))])


static func _num_ok(v: Variant, min_v: float = 0.0) -> bool:
	return (v is float or v is int) and not is_nan(float(v)) and float(v) >= min_v


static func _items(d: GameData, e: Array[String]) -> void:
	for id in d.items:
		var it: Dictionary = d.items[id]
		if str(it.get("name", "")) == "":
			e.append("item %s: name がありません" % id)
		if not (it.get("category") in CATEGORIES):
			e.append("item %s: 不正なカテゴリ %s" % [id, str(it.get("category"))])
		if not _num_ok(it.get("weight")):
			e.append("item %s: weight が不正" % id)
		if not bool(it.get("stackable", true)) and not _num_ok(it.get("max_durability"), 1.0):
			e.append("item %s: スタック不可品には max_durability(>=1) が必要" % id)
		var icon := str(it.get("icon", ""))
		if icon != "" and not ResourceLoader.exists(icon):
			e.append("item %s: アイコンが存在しません %s" % [id, icon])
		for k in it.get("use_effects", {}):
			if not (k in KNOWN_USE_EFFECTS):
				e.append("item %s: 未知の use_effects '%s'" % [id, k])
		var ra := str(it.get("repair_action", ""))
		if ra != "" and not d.actions.has(ra):
			e.append("item %s: 修理行動 %s が存在しません" % [id, ra])


static func _check_item_map(d: GameData, e: Array[String], owner: String, m: Variant) -> void:
	if not (m is Dictionary):
		e.append("%s: アイテム指定が辞書ではありません" % owner)
		return
	for id in m:
		if not d.items.has(id):
			e.append("%s: 存在しないアイテム参照 '%s'" % [owner, id])
		if not _num_ok(m[id], 1.0) or float(m[id]) != floorf(float(m[id])):
			e.append("%s: '%s' の数量が不正 (%s)" % [owner, id, str(m[id])])


static func _actions(d: GameData, e: Array[String]) -> void:
	for id in d.actions:
		var a: Dictionary = d.actions[id]
		var owner: String = "action " + id
		_check_item_map(d, e, owner + ".inputs", a.get("inputs", {}))
		_check_item_map(d, e, owner + ".outputs", a.get("outputs", {}))
		if not _num_ok(a.get("duration_minutes", 0)):
			e.append("%s: duration_minutes が不正" % owner)
		var sc: Variant = a.get("success_chance", 1.0)
		if not _num_ok(sc) or float(sc) > 1.0:
			e.append("%s: success_chance は0〜1" % owner)
		for t in a.get("tools", []):
			var tid := str(t.get("item", ""))
			if not d.items.has(tid):
				e.append("%s: 存在しない工具 '%s'" % [owner, tid])
			elif bool(d.items[tid].get("stackable", true)):
				e.append("%s: 工具 '%s' はスタック不可である必要があります" % [owner, tid])
		for f in a.get("facilities", []):
			if not d.buildings.has(str(f)):
				e.append("%s: 存在しない設備 '%s'" % [owner, f])
		var eff := str(a.get("effect", ""))
		if eff == "place_building" and not d.buildings.has(str(a.get("effect_params", {}).get("building", ""))):
			e.append("%s: 建てる設備が存在しません" % owner)
		if eff != "" and not (eff in KNOWN_EFFECTS):
			e.append("%s: 未知の effect '%s'" % [owner, eff])
		if eff == "story_beat":
			for sid in a.get("effect_params", {}).get("reveal_sites", []):
				if not d.sites.has(str(sid)):
					e.append("%s: 存在しない地点 '%s'" % [owner, sid])
		for k in ["on_fail", "on_cancel"]:
			var lr: Variant = a.get(k, {}).get("lose_ratio", 0.0)
			if not _num_ok(lr) or float(lr) > 1.0:
				e.append("%s: %s.lose_ratio は0〜1" % [owner, k])
		_check_item_map(d, e, owner + ".keep_items", a.get("keep_items", {}))
		if eff == "add_ship" and not d.ships.has(str(a.get("effect_params", {}).get("ship", ""))):
			e.append("%s: 存在しない船種" % owner)
		if not (a.get("category") in ["raft", "craft", "build", "repair", "rest", "explore", "fleet"]):
			e.append("%s: 不正なカテゴリ %s" % [owner, str(a.get("category"))])
		if a.get("inputs", {}).is_empty() and a.get("outputs", {}).is_empty() and eff == "":
			e.append("%s: 入力・出力・効果がすべて空です" % owner)


static func _buildings(d: GameData, e: Array[String]) -> void:
	for id in d.buildings:
		var b: Dictionary = d.buildings[id]
		var ba := str(b.get("build_action", ""))
		if ba != "" and not d.actions.has(ba):
			e.append("building %s: 建築行動 %s が存在しません" % [id, ba])
		var prod: Dictionary = b.get("production", {})
		if not prod.is_empty():
			if not d.items.has(str(prod.get("item", ""))):
				e.append("building %s: 生産物 '%s' が存在しません" % [id, str(prod.get("item"))])
			if not _num_ok(prod.get("minutes"), 1.0) or not _num_ok(prod.get("max_stored"), 1.0):
				e.append("building %s: production の数値が不正" % id)
		if str(b.get("kind", "")) == "building":
			var ba2 := d.action(ba)
			if ba2.get("effect") != "place_building" or ba2.get("effect_params", {}).get("building") != id:
				e.append("building %s: 建築行動の effect_params.building が一致しません" % id)
		var model := str(b.get("model", ""))
		if model != "" and not ResourceLoader.exists(model):
			e.append("building %s: モデルが存在しません %s" % [id, model])


static func _zones(d: GameData, e: Array[String]) -> void:
	for id in d.zones:
		var z: Dictionary = d.zones[id]
		var tables: Dictionary = z.get("drift_tables", {})
		for k in z.get("debris_kinds", []):
			if not tables.has(str(k.get("kind", ""))):
				e.append("zone %s: 漂流物 '%s' の抽選表がありません" % [id, str(k.get("kind"))])
		for kind in tables:
			var t: Dictionary = tables[kind]
			var rolls: Variant = t.get("rolls", [])
			if not (rolls is Array) or rolls.size() != 2 or int(rolls[0]) > int(rolls[1]) or int(rolls[0]) < 0:
				e.append("zone %s.%s: rolls が不正" % [id, kind])
			for en in t.get("entries", []):
				if not d.items.has(str(en.get("item", ""))):
					e.append("zone %s.%s: 存在しないアイテム '%s'" % [id, kind, str(en.get("item"))])
				if not _num_ok(en.get("weight"), 0.0001):
					e.append("zone %s.%s: weight が不正" % [id, kind])
				if int(en.get("min", 1)) > int(en.get("max", 1)) or int(en.get("min", 1)) < 1:
					e.append("zone %s.%s: min/max が不正" % [id, kind])
		for ck in ["ocean_shallow_color", "ocean_deep_color", "fog_color"]:
			if not Color.html_is_valid(str(z.get(ck, ""))):
				e.append("zone %s: %s が不正な色" % [id, ck])


static func _balance(d: GameData, e: Array[String]) -> void:
	for key in ["time.game_minutes_per_real_second", "inventory.max_weight", "raft.base_speed",
			"raft.tile_size", "survival.hunger_per_hour", "survival.thirst_per_hour", "world.collect_range"]:
		if not _num_ok(d.bal(key), 0.0001):
			e.append("balance: %s が不正または未設定" % key)
	if not d.zones.has(str(d.bal("world.start_zone", ""))):
		e.append("balance: world.start_zone が存在しない海域です")
	_check_item_map(d, e, "balance.start_inventory", d.bal("start_inventory", {}))

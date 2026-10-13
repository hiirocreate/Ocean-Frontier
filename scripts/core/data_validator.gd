class_name DataValidator
extends RefCounted
## 開発用データ検証（仕様44）。問題点の文字列配列を返す（空なら正常）。

const KNOWN_EFFECTS := ["raft_add_tile", "repair_item"]
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
	return e


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
		if eff != "" and not (eff in KNOWN_EFFECTS):
			e.append("%s: 未知の effect '%s'" % [owner, eff])
		for k in ["on_fail", "on_cancel"]:
			var lr: Variant = a.get(k, {}).get("lose_ratio", 0.0)
			if not _num_ok(lr) or float(lr) > 1.0:
				e.append("%s: %s.lose_ratio は0〜1" % [owner, k])
		if a.get("inputs", {}).is_empty() and a.get("outputs", {}).is_empty() and eff == "":
			e.append("%s: 入力・出力・効果がすべて空です" % owner)


static func _buildings(d: GameData, e: Array[String]) -> void:
	for id in d.buildings:
		var b: Dictionary = d.buildings[id]
		var ba := str(b.get("build_action", ""))
		if ba != "" and not d.actions.has(ba):
			e.append("building %s: 建築行動 %s が存在しません" % [id, ba])
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

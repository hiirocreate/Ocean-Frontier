class_name FactionSim
extends RefCounted
## 勢力の状態と自律シミュレーション（仕様27）。プレイヤーの操作がなくても1日ごとに
## 交易・襲撃・同盟・分裂・吸収・拠点拡張を行う。すべての勢力は簡略化した数値モデルで更新し負荷を抑える。

signal news(text: String, important: bool)

var data: GameData
var factions: Dictionary = {}  # id -> 状態
var news_log: Array = []  # [{day, text}]
var _last_day := -1


func _init(game_data: GameData) -> void:
	data = game_data


func reset() -> void:
	factions.clear()
	for id in data.factions:
		var f: Dictionary = data.factions[id]
		factions[id] = {
			"alive": true, "members": int(f.get("members", 50)), "resources": f.get("resources", {}).duplicate(),
			"ships": int(f.get("ships", 1)), "armament": float(f.get("armament", 10)), "defense": float(f.get("defense", 10)),
			"economy": float(f.get("economy", 5)), "relations": f.get("relations", {}).duplicate(),
			"player_standing": float(f.get("player_standing", 0)), "allied_player": false, "allies": [], "history": [],
			"hungry_days": 0,
		}


func name_of(id: String) -> String:
	return str(data.factions.get(id, {}).get("name", id))


func alive_ids() -> Array[String]:
	var out: Array[String] = []
	for id in factions:
		if factions[id]["alive"]:
			out.append(id)
	out.sort()
	return out


func standing(id: String) -> float:
	return float(factions.get(id, {}).get("player_standing", 0.0))


func change_standing(id: String, delta: float) -> void:
	if factions.has(id):
		factions[id]["player_standing"] = clampf(standing(id) + delta, -100.0, 100.0)


func relation(a: String, b: String) -> float:
	return float(factions.get(a, {}).get("relations", {}).get(b, 0.0))


func change_relation(a: String, b: String, delta: float) -> void:
	for pair in [[a, b], [b, a]]:
		if factions.has(pair[0]):
			factions[pair[0]]["relations"][pair[1]] = clampf(relation(pair[0], pair[1]) + delta, -100.0, 100.0)


func is_hostile_to_player(id: String) -> bool:
	return standing(id) <= -30.0


func strength(id: String) -> float:
	var f: Dictionary = factions.get(id, {})
	return float(f.get("armament", 0)) * (1.0 + float(f.get("ships", 0)) * 0.1) + float(f.get("defense", 0)) * 0.5


func _log(day: int, text: String, important: bool = false, involved: Array = []) -> void:
	news_log.append({"day": day, "text": text})
	if news_log.size() > 40:
		news_log.remove_at(0)
	for id in involved:
		if factions.has(id):
			factions[id]["history"].append({"day": day, "text": text})
			if factions[id]["history"].size() > 20:
				factions[id]["history"].remove_at(0)
	news.emit(text, important)


## 日付が進んだ分だけ1日ずつ処理する
func tick(s: GameSession) -> void:
	var day := s.clock.day()
	if _last_day == -1:
		_last_day = day
	while _last_day < day:
		_last_day += 1
		_daily(s, _last_day)


func _daily(s: GameSession, day: int) -> void:
	var rng := s.rng
	for id in alive_ids():
		var f: Dictionary = factions[id]
		var res: Dictionary = f["resources"]
		var econ := float(f["economy"])
		res["food"] = float(res.get("food", 0)) + econ * 8.0 - float(f["members"]) * 0.06
		res["materials"] = float(res.get("materials", 0)) + econ * 5.0
		res["fuel"] = float(res.get("fuel", 0)) + econ * 1.5 - float(f["ships"]) * 0.3
		res["ammo"] = float(res.get("ammo", 0)) + (3.0 if data.factions[id].get("kind") in ["military", "pirate"] else 0.5)
		if float(res["food"]) < 0.0:
			f["hungry_days"] = int(f["hungry_days"]) + 1
			f["members"] = maxi(0, int(f["members"] * 0.95))
			res["food"] = 0.0
		else:
			f["hungry_days"] = 0
	for id in alive_ids():
		if not factions[id]["alive"]:
			continue
		_decide(s, id, day, rng)
	_check_absorb_and_split(s, day)


func _decide(s: GameSession, id: String, day: int, rng: RandomNumberGenerator) -> void:
	var def: Dictionary = data.factions[id]
	var f: Dictionary = factions[id]
	var goals: Array = def.get("goals", [])
	var aggression := float(def.get("aggression", 0.3))
	var others := alive_ids().filter(func(o): return o != id)
	if others.is_empty():
		return
	var roll := rng.randf()
	var hostile := others.filter(func(o): return relation(id, o) <= -40.0)
	var friendly := others.filter(func(o): return relation(id, o) > 0.0)
	if not hostile.is_empty() and roll < aggression * 0.35:
		_raid(id, hostile[rng.randi_range(0, hostile.size() - 1)], day, rng)
	elif not friendly.is_empty() and roll < 0.6:
		var t: String = friendly[rng.randi_range(0, friendly.size() - 1)]
		for k in ["food", "materials"]:
			f["resources"][k] = float(f["resources"].get(k, 0)) * 1.03
			factions[t]["resources"][k] = float(factions[t]["resources"].get(k, 0)) * 1.03
		change_relation(id, t, 2.0)
		if relation(id, t) >= 60.0 and not (t in f["allies"]):
			f["allies"].append(t)
			factions[t]["allies"].append(id)
			_log(day, "%sと%sが同盟を結んだ" % [name_of(id), name_of(t)], true, [id, t])
	elif ("expand" in goals) and float(f["resources"].get("materials", 0)) > 450.0:
		f["resources"]["materials"] = float(f["resources"]["materials"]) - 200.0
		f["defense"] = float(f["defense"]) + 4.0
		f["ships"] = int(f["ships"]) + 1
		_log(day, "%sが拠点を拡張し、船を増やした" % name_of(id), false, [id])


func _raid(attacker: String, target: String, day: int, rng: RandomNumberGenerator) -> void:
	var a := strength(attacker)
	var d := strength(target)
	var ok := rng.randf() < a / (a + d)
	change_relation(attacker, target, -6.0)
	if ok:
		for k in ["food", "materials", "fuel"]:
			var take := float(factions[target]["resources"].get(k, 0)) * 0.1
			factions[target]["resources"][k] = float(factions[target]["resources"].get(k, 0)) - take
			factions[attacker]["resources"][k] = float(factions[attacker]["resources"].get(k, 0)) + take
		if rng.randf() < 0.4 and int(factions[target]["ships"]) > 0:
			factions[target]["ships"] = int(factions[target]["ships"]) - 1
		_log(day, "%sが%sを襲撃し、物資を奪った" % [name_of(attacker), name_of(target)], true, [attacker, target])
	else:
		factions[attacker]["ships"] = maxi(0, int(factions[attacker]["ships"]) - 1)
		_log(day, "%sの襲撃は%sに撃退された" % [name_of(attacker), name_of(target)], false, [attacker, target])


## 吸収（構成員が尽きた勢力は最も友好的な勢力に吸収）と分裂（飢えが続く大勢力の一部が海賊に流れる）
func _check_absorb_and_split(s: GameSession, day: int) -> void:
	for id in alive_ids():
		var f: Dictionary = factions[id]
		if int(f["members"]) < 15:
			var best := ""
			var best_rel := -INF
			for o in alive_ids():
				if o != id and relation(o, id) > best_rel:
					best_rel = relation(o, id)
					best = o
			f["alive"] = false
			if best != "":
				factions[best]["members"] = int(factions[best]["members"]) + int(f["members"])
				factions[best]["ships"] = int(factions[best]["ships"]) + int(f["ships"])
				_log(day, "%sは%sに吸収された" % [name_of(id), name_of(best)], true, [id, best])
			else:
				_log(day, "%sは消滅した" % name_of(id), true, [id])
		elif int(f["hungry_days"]) >= 5 and int(f["members"]) > 60 and data.factions[id].get("kind") != "pirate":
			var leaving := int(f["members"] * 0.25)
			f["members"] = int(f["members"]) - leaving
			f["hungry_days"] = 0
			for o in alive_ids():
				if data.factions[o].get("kind") == "pirate":
					factions[o]["members"] = int(factions[o]["members"]) + leaving
					_log(day, "飢えに耐えかねた%sの一部（%d人）が分裂し、%sに加わった" % [name_of(id), leaving, name_of(o)], true, [id, o])
					break


## 敵対勢力によるプレイヤーへの襲撃判定（1日1回）。襲撃する場合は敵グループIDを返す。
func roll_raid_on_player(s: GameSession) -> String:
	var guard := minf(0.6, float(s.counters.get("guard_hours", 0.0)) / 200.0)
	for id in alive_ids():
		if not is_hostile_to_player(id):
			continue
		var def: Dictionary = data.factions[id]
		var chance := float(def.get("aggression", 0.3)) * 0.15 * (1.0 + float(s.reputation.get("infamy", 0)) / 50.0 + float(s.reputation.get("fame", 0)) / 100.0) * (1.0 - guard)
		if s.rng.randf() < chance:
			return str(def.get("raider_enemy", "pirate_raiders"))
	return ""


func to_dict() -> Dictionary:
	return {"factions": factions.duplicate(true), "news": news_log.duplicate(true), "last_day": _last_day}


func from_dict(d: Dictionary) -> Array[String]:
	var w: Array[String] = []
	reset()
	var fs: Variant = d.get("factions", {})
	if fs is Dictionary:
		for id in fs:
			if not factions.has(str(id)) or not (fs[id] is Dictionary):
				w.append("未知の勢力 '%s' を除外" % str(id))
				continue
			for k in factions[id]:
				if fs[id].has(k):
					factions[id][k] = fs[id][k]
			factions[id]["player_standing"] = clampf(float(factions[id]["player_standing"]), -100.0, 100.0)
			factions[id]["members"] = maxi(0, int(factions[id]["members"]))
			factions[id]["ships"] = maxi(0, int(factions[id]["ships"]))
	var n: Variant = d.get("news", [])
	news_log = n.duplicate(true) if n is Array else []
	_last_day = int(d.get("last_day", -1))
	return w

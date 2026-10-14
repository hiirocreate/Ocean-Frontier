class_name Crew
extends RefCounted
## 仲間（生存者）の状態・作業・人間関係・離脱を管理する。定義は GameData.survivors。
## 状態: unmet(未遭遇) / aboard(在籍) / departed(離脱。世界に残り再会・復帰の可能性あり)
## 人間関係は「A→Bの感情」を必要な種類だけ持つ疎なデータ（仕様25）。

signal member_joined(id: String)
signal member_left(id: String, reason: String)
signal member_warning(id: String, text: String)
signal changed

const STATS := ["health", "hunger", "thirst", "fatigue", "stress", "satisfaction", "loyalty", "trust"]
const RELATION_KINDS := ["trust", "friendship", "hostility", "respect", "jealousy", "fear", "intimacy"]
const REASONS := {
	"hunger": "食料不足", "thirst": "水不足", "low_satisfaction": "待遇への不満",
	"hostility": "仲間との対立", "piracy": "海賊行為への反発",
}

var data: GameData
var members: Dictionary = {}  # id -> 状態辞書
var relations: Dictionary = {}  # "a>b" -> {kind: value}
var _work_acc: Dictionary = {}  # id -> 作業の端数（セーブ対象）
var _leader_mult := 1.0  # 主人公の指揮（leadership）による作業効率補正。GameSession が設定
var _last_day: int = -1  # GameSession.new_game で初期化


func _init(game_data: GameData) -> void:
	data = game_data


## 人物の定義（仲間候補。無ければ勢力のリーダー・モブ）
func def(id: String) -> Dictionary:
	return data.survivors.get(id, data.npcs.get(id, {}))


func display_name(id: String) -> String:
	return str(def(id).get("name", id))


func status(id: String) -> String:
	return str(members.get(id, {}).get("status", "unmet"))


func is_aboard(id: String) -> bool:
	return status(id) == "aboard"


func aboard_ids() -> Array[String]:
	var out: Array[String] = []
	for id in members:
		if members[id]["status"] == "aboard":
			out.append(id)
	out.sort()
	return out


func departed_ids() -> Array[String]:
	var out: Array[String] = []
	for id in members:
		if members[id]["status"] == "departed":
			out.append(id)
	return out


func get_value(id: String, stat: String) -> float:
	return float(members.get(id, {}).get(stat, 0.0))


func change(id: String, stat: String, delta: float) -> void:
	if not members.has(id) or not (stat in STATS):
		return
	members[id][stat] = clampf(float(members[id][stat]) + delta, 0.0, 100.0)
	changed.emit()


func add_history(id: String, day: int, text: String) -> void:
	if members.has(id):
		members[id]["history"].append({"day": day, "text": text})


# ---------- 加入 ----------
func recruit(id: String, day: int) -> bool:
	if def(id).is_empty() or is_aboard(id):
		return false
	if not members.has(id):
		members[id] = _new_state()
		var rel: Dictionary = def(id).get("relations", {})
		for other in rel:
			for kind in rel[other]:
				set_relation(id, str(other), str(kind), float(rel[other][kind]))
	var m: Dictionary = members[id]
	m["status"] = "aboard"
	m["job"] = "idle"
	m["pressure"] = 0.0
	m["warned"] = false
	m["joined_day"] = day
	add_history(id, day, "仲間になった" if int(m.get("times_joined", 0)) == 0 else "再び仲間に加わった")
	m["times_joined"] = int(m.get("times_joined", 0)) + 1
	member_joined.emit(id)
	changed.emit()
	return true


func _new_state() -> Dictionary:
	return {
		"status": "unmet", "health": 70.0, "hunger": 40.0, "thirst": 35.0, "fatigue": 40.0, "stress": 40.0,
		"satisfaction": 50.0, "loyalty": 30.0, "trust": 35.0, "job": "idle", "pressure": 0.0, "warned": false,
		"history": [], "joined_day": 0, "departed_day": 0, "departed_reason": "", "location": "", "times_joined": 0,
	}


## 加入条件を満たした未遭遇の仲間（救助イベント候補）
func available_rescues(s: GameSession) -> Array[String]:
	var out: Array[String] = []
	for id in data.survivors:
		if status(id) != "unmet":
			continue
		var rec: Dictionary = def(id).get("recruit", {})
		if Conditions.check(rec.get("condition", {}), s):
			out.append(id)
	out.sort()
	return out


# ---------- 作業 ----------
func job_def(job_id: String) -> Dictionary:
	return data.jobs.get(job_id, {})


## 割り当て可能か。可能なら空文字、不可なら理由。
func job_problem(id: String, job_id: String, s: GameSession) -> String:
	if not is_aboard(id):
		return "%sは仲間にいません" % display_name(id)
	var j := job_def(job_id)
	if j.is_empty():
		return "不明な作業です"
	if not bool(j.get("available", true)):
		return "「%s」はまだ行えません" % j.get("name", job_id)
	var fac := str(j.get("facility", ""))
	if fac != "" and not s.raft.has_building(fac):
		return "設備「%s」が必要です" % data.building_name(fac)
	return ""


func assign_job(id: String, job_id: String, s: GameSession) -> String:
	var p := job_problem(id, job_id, s)
	if p == "":
		members[id]["job"] = job_id
		changed.emit()
	return p


func skill(id: String, skill_id: String) -> int:
	return int(def(id).get("skills", {}).get(skill_id, 0))


func best_skill(skill_id: String) -> int:
	var best := 0
	for id in aboard_ids():
		best = maxi(best, skill(id, skill_id))
	return best


func trait_value(id: String, key: String, default: float) -> float:
	var v := default
	for t in def(id).get("personality", []):
		var td: Dictionary = data.traits.get(t, {})
		if td.has(key):
			v *= float(td[key])
	return v


## 作業効率 = 技能 × 体調 × 性格（仕様24）
func efficiency(id: String) -> float:
	var m: Dictionary = members[id]
	var j := job_def(str(m["job"]))
	var sk := str(j.get("skill", ""))
	var e := 0.5 + 0.2 * (skill(id, sk) if sk != "" else 0)
	var cond := 1.0
	if float(m["hunger"]) < 25.0:
		cond -= 0.25
	if float(m["thirst"]) < 25.0:
		cond -= 0.3
	cond -= maxf(0.0, float(m["fatigue"]) - 60.0) / 100.0
	cond -= float(m["stress"]) / 400.0
	cond -= (100.0 - float(m["health"])) / 300.0
	e *= clampf(cond, 0.2, 1.0)
	e *= trait_value(id, "work_mult", 1.0)
	e *= _leader_mult
	return maxf(0.05, e)


func is_resting(s: GameSession) -> bool:
	var h := s.clock.hour()
	return h >= 22 or h < 6


## 行動（建築など）の進行ボーナス {category: 追加倍率}
func action_bonus(s: GameSession) -> Dictionary:
	var out := {}
	if is_resting(s):
		return out
	for id in aboard_ids():
		var j := job_def(str(members[id]["job"]))
		var o: Dictionary = j.get("output", {})
		if o.get("type") == "action_speed":
			for c in o.get("categories", []):
				out[c] = float(out.get(c, 0.0)) + float(o.get("bonus", 0.5)) * efficiency(id)
	return out


func production_multiplier(building_id: String, s: GameSession) -> float:
	var mult := 1.0
	if is_resting(s):
		return mult
	for id in aboard_ids():
		var o: Dictionary = job_def(str(members[id]["job"])).get("output", {})
		if o.get("type") == "production_boost" and o.get("building") == building_id:
			mult += float(o.get("multiplier", 0.5)) * efficiency(id)
	return mult


func speed_bonus(s: GameSession) -> float:
	var b := 0.0
	for id in aboard_ids():
		var o: Dictionary = job_def(str(members[id]["job"])).get("output", {})
		if o.get("type") == "speed_bonus":
			b += float(o.get("bonus", 0.1)) * efficiency(id)
	return b


func available_crew(s: GameSession) -> int:
	if is_resting(s):
		return 0
	return aboard_ids().filter(func(id): return s.fleet.member_ship(id) == "").size()


# ---------- 時間経過 ----------
func tick(minutes: float, s: GameSession) -> void:
	_leader_mult = s.ability_mult("leadership", 0.05)
	if minutes <= 0.0 or members.is_empty():
		return
	var h := minutes / 60.0
	var resting := is_resting(s)
	for id in aboard_ids():
		var m: Dictionary = members[id]
		if s.fleet.member_on_mission(id):
			continue  # 航海中は船の補給で過ごす
		m["hunger"] = clampf(float(m["hunger"]) - 4.0 * h, 0.0, 100.0)
		m["thirst"] = clampf(float(m["thirst"]) - 6.0 * h, 0.0, 100.0)
		var j := job_def(str(m["job"]))
		var fat := -10.0 if resting else float(j.get("fatigue_per_hour", 1.0))
		m["fatigue"] = clampf(float(m["fatigue"]) + fat * h, 0.0, 100.0)
		var dmg := 0.0
		if float(m["hunger"]) <= 0.0:
			dmg += 5.0
		if float(m["thirst"]) <= 0.0:
			dmg += 8.0
		if dmg > 0.0:
			m["health"] = clampf(float(m["health"]) - dmg * h, 1.0, 100.0)
		elif float(m["hunger"]) > 50.0 and float(m["thirst"]) > 50.0:
			m["health"] = clampf(float(m["health"]) + 1.5 * h, 0.0, 100.0)
		var stress_delta := -3.0 if resting else 0.5
		if float(m["hunger"]) < 25.0:
			stress_delta += 3.0
		if float(m["thirst"]) < 25.0:
			stress_delta += 4.0
		if float(m["fatigue"]) > 80.0:
			stress_delta += 2.0
		m["stress"] = clampf(float(m["stress"]) + stress_delta * trait_value(id, "stress_mult", 1.0) * h, 0.0, 100.0)
		_auto_consume(id, s)
		if not resting:
			_do_work(id, h, s)
	var day := s.clock.day()
	if _last_day == -1:
		_last_day = day
	while _last_day < day:
		_last_day += 1
		_daily(s, _last_day)


## 空腹・渇きのとき、持ち物から自動で食べる・飲む
func _auto_consume(id: String, s: GameSession) -> void:
	var m: Dictionary = members[id]
	if float(m["hunger"]) < 40.0:
		for item in ["cooked_fish", "canned_food", "potato", "coconut", "raw_fish"]:
			if s.inventory.remove(item, 1):
				m["hunger"] = clampf(float(m["hunger"]) + float(data.item(item).get("use_effects", {}).get("hunger", 10)), 0.0, 100.0)
				break
	if float(m["thirst"]) < 40.0:
		for item in ["water_bottle", "coconut"]:
			if s.inventory.remove(item, 1):
				m["thirst"] = clampf(float(m["thirst"]) + float(data.item(item).get("use_effects", {}).get("thirst", 10)), 0.0, 100.0)
				break


func _do_work(id: String, h: float, s: GameSession) -> void:
	var m: Dictionary = members[id]
	var job_id := str(m["job"])
	var j := job_def(job_id)
	var o: Dictionary = j.get("output", {})
	var eff := efficiency(id)
	var type := str(o.get("type", "none"))
	if type == "counter":
		var c := str(o.get("counter", ""))
		var learn := s.ability_mult("learning", 0.25) if c == "research_points" else 1.0  # 主人公の学習力
		s.counters[c] = float(s.counters.get(c, 0.0)) + float(o.get("per_hour", 0.0)) * eff * h * learn
	var acc := float(_work_acc.get(id, 0.0)) + float(o.get("per_hour", 0.0)) * eff * h
	var units := int(floor(acc))
	_work_acc[id] = acc - units
	if units > 0:
		match type:
			"loot":
				var table: Dictionary = s.data.zones.get(s.zone_id, {}).get("drift_tables", {}).get(str(o.get("table", "plank")), {})
				for i in units:
					var loot := LootRoller.roll_table(table, s.rng)
					if not s.inventory.can_add(loot):
						break
					s.inventory.add_many(loot)
			"item":
				var item := str(o["item"])
				if s.inventory.can_add({item: units}):
					s.inventory.add(item, units)
			"convert":
				for i in units:
					if not s.inventory.has_all(o["from"]):
						break
					s.inventory.remove_many(o["from"])
					s.inventory.add_many(o["to"], true)
			"repair":
				for inst in s.inventory.instances:
					if float(inst["durability"]) < s.inventory.max_durability(inst["id"]):
						s.inventory.repair_most_worn(inst["id"], float(units))
						break
	var liked := false
	for t in def(id).get("personality", []):
		if job_id in data.traits.get(t, {}).get("likes_jobs", []):
			liked = true
	if liked:
		m["satisfaction"] = clampf(float(m["satisfaction"]) + 0.5 * h, 0.0, 100.0)


# ---------- 1日ごとの処理：満足度・関係・離脱判定 ----------
func _daily(s: GameSession, day: int) -> void:
	var ids := aboard_ids()
	for id in ids:
		var m: Dictionary = members[id]
		var sat_delta := 0.0
		sat_delta += 5.0 if float(m["hunger"]) > 50.0 else -8.0
		sat_delta += 4.0 if float(m["thirst"]) > 50.0 else -10.0
		sat_delta -= float(m["stress"]) / 20.0
		sat_delta += 2.0 if s.raft.has_building("bed") else -1.0
		m["satisfaction"] = clampf(float(m["satisfaction"]) + sat_delta, 0.0, 100.0)
		# 忠誠心は満足度に少しずつ引き寄せられる
		m["loyalty"] = clampf(float(m["loyalty"]) + (float(m["satisfaction"]) - 50.0) / 25.0, 0.0, 100.0)
	_update_relations(s, ids)
	for id in ids:
		_evaluate_departure(id, s, day)


func _update_relations(s: GameSession, ids: Array[String]) -> void:
	for a in ids:
		for b in ids:
			if a == b:
				continue
			if members[a]["job"] == members[b]["job"] and members[a]["job"] != "idle":
				add_relation(a, b, "friendship", 2.0)
			if _traits_clash(a, b) and float(members[a]["stress"]) > 50.0:
				add_relation(a, b, "hostility", 3.0)
			elif get_relation(a, b, "hostility") > 0.0:
				add_relation(a, b, "hostility", -1.0)


func _traits_clash(a: String, b: String) -> bool:
	for ta in def(a).get("personality", []):
		for tb in def(b).get("personality", []):
			if tb in data.traits.get(ta, {}).get("clash_with", []):
				return true
	return false


## 離脱圧力の計算（仕様26）。予兆→離脱。sudden の人物は予兆なしで離脱しうる。
func departure_factors(id: String, s: GameSession) -> Dictionary:
	var m: Dictionary = members[id]
	var w: Dictionary = def(id).get("departure", {}).get("weights", {})
	var f := {}
	if float(m["hunger"]) < 20.0:
		f["hunger"] = 15.0 * float(w.get("hunger", 1.0))
	if float(m["thirst"]) < 20.0:
		f["thirst"] = 20.0 * float(w.get("thirst", 1.0))
	if float(m["satisfaction"]) < 30.0:
		f["low_satisfaction"] = (30.0 - float(m["satisfaction"])) * 0.6 * float(w.get("low_satisfaction", 1.0))
	var max_host := 0.0
	for other in aboard_ids():
		if other != id:
			max_host = maxf(max_host, get_relation(id, other, "hostility"))
	if max_host > 60.0:
		f["hostility"] = (max_host - 50.0) * 0.5 * float(w.get("hostility", 1.0))
	var piracy := float(s.counters.get("piracy_today", 0.0))
	if piracy > 0.0:
		f["piracy"] = piracy * 15.0 * float(w.get("piracy", 1.0))
	return f


func _evaluate_departure(id: String, s: GameSession, day: int) -> void:
	var m: Dictionary = members[id]
	var dep: Dictionary = def(id).get("departure", {})
	var f := departure_factors(id, s)
	var total := 0.0
	for k in f:
		total += float(f[k])
	if total <= 0.0:
		total = -10.0 if float(m["satisfaction"]) >= 60.0 else -2.0
	# 忠誠心が高いほど踏みとどまる
	total -= float(m["loyalty"]) / 25.0
	m["pressure"] = maxf(0.0, float(m["pressure"]) + total)
	var main_reason := ""
	var best := 0.0
	for k in f:
		if float(f[k]) > best:
			best = float(f[k])
			main_reason = k
	var warn_at := float(dep.get("warn_at", 60))
	var leave_at := float(dep.get("leave_at", 100))
	var sudden := bool(dep.get("sudden", false))
	if float(m["pressure"]) >= leave_at and (bool(m["warned"]) or sudden):
		depart(id, main_reason if main_reason != "" else "low_satisfaction", s, day)
	elif float(m["pressure"]) >= warn_at and not bool(m["warned"]) and not sudden:
		m["warned"] = true
		var text := "%sの様子がおかしい。%sについて不満を漏らしている……" % [display_name(id), REASONS.get(main_reason, "待遇")]
		add_history(id, day, "離脱の予兆: " + REASONS.get(main_reason, "不満"))
		member_warning.emit(id, text)
	elif float(m["pressure"]) < warn_at * 0.5:
		m["warned"] = false


## 離脱。人物データは保持し、行き先を記録する。
func depart(id: String, reason: String, s: GameSession, day: int) -> void:
	if not is_aboard(id):
		return
	var m: Dictionary = members[id]
	var dests: Array = def(id).get("departure", {}).get("destinations", ["independent"])
	var dest := str(dests[s.rng.randi_range(0, dests.size() - 1)]) if not dests.is_empty() else "independent"
	m["status"] = "departed"
	m["job"] = "idle"
	m["departed_day"] = day
	m["departed_reason"] = reason
	m["location"] = dest
	m["warned"] = false
	m["trust"] = clampf(float(m["trust"]) - 15.0, 0.0, 100.0)
	add_history(id, day, "筏を去った（理由: %s／行き先: %s）" % [REASONS.get(reason, reason), destination_name(dest)])
	member_left.emit(id, reason)
	changed.emit()


func destination_name(dest: String) -> String:
	if dest == "independent":
		return "独立"
	if dest == "pirate":
		return "海賊"
	if dest.begins_with("faction:"):
		return "勢力「%s」" % dest.substr(8)
	return dest


## 再加入の可否（仕様26: 再会・復帰）
func rejoin_problem(id: String, day: int) -> String:
	if status(id) != "departed":
		return "%sは離脱していません" % display_name(id)
	var r: Dictionary = def(id).get("rejoin", {})
	var m: Dictionary = members[id]
	if day - int(m["departed_day"]) < int(r.get("min_days_away", 0)):
		return "%sはまだ戻る気がないようだ" % display_name(id)
	if float(m["trust"]) < float(r.get("min_trust", 0)):
		return "%sはあなたを信頼していない" % display_name(id)
	return ""


# ---------- 人間関係 ----------
static func rel_key(a: String, b: String) -> String:
	return "%s>%s" % [a, b]


func get_relation(a: String, b: String, kind: String) -> float:
	return float(relations.get(rel_key(a, b), {}).get(kind, 0.0))


func set_relation(a: String, b: String, kind: String, value: float) -> void:
	if not (kind in RELATION_KINDS) or a == b:
		return
	var k := rel_key(a, b)
	if not relations.has(k):
		relations[k] = {}
	relations[k][kind] = clampf(value, -100.0, 100.0)


func add_relation(a: String, b: String, kind: String, delta: float) -> void:
	set_relation(a, b, kind, get_relation(a, b, kind) + delta)


func relations_of(a: String) -> Dictionary:
	var out := {}
	for k in relations:
		var parts: PackedStringArray = k.split(">")
		if parts[0] == a:
			out[parts[1]] = relations[k]
	return out


# ---------- 保存 ----------
func to_dict() -> Dictionary:
	return {"members": members.duplicate(true), "relations": relations.duplicate(true), "work_acc": _work_acc.duplicate(), "last_day": _last_day}


func from_dict(d: Dictionary) -> Array[String]:
	var w: Array[String] = []
	members.clear()
	relations.clear()
	_work_acc.clear()
	var ms: Variant = d.get("members", {})
	if ms is Dictionary:
		for id in ms:
			if def(str(id)).is_empty() or not (ms[id] is Dictionary):
				w.append("未知の仲間 '%s' を除外" % str(id))
				continue
			var st := _new_state()
			for k in st:
				if ms[id].has(k):
					st[k] = ms[id][k]
			for k in STATS:
				st[k] = clampf(float(st[k]), 0.0, 100.0)
			if not (st["status"] in ["unmet", "aboard", "departed"]):
				w.append("仲間 '%s' の状態が不正 → 離脱扱い" % id)
				st["status"] = "departed"
			if job_def(str(st["job"])).is_empty():
				st["job"] = "idle"
			if not (st["history"] is Array):
				st["history"] = []
			members[str(id)] = st
	var rs: Variant = d.get("relations", {})
	if rs is Dictionary:
		for k in rs:
			if rs[k] is Dictionary:
				relations[str(k)] = {}
				for kind in rs[k]:
					if kind in RELATION_KINDS:
						relations[str(k)][kind] = clampf(float(rs[k][kind]), -100.0, 100.0)
	var wa: Variant = d.get("work_acc", {})
	if wa is Dictionary:
		for k in wa:
			_work_acc[str(k)] = float(wa[k])
	_last_day = int(d.get("last_day", -1))
	return w

class_name Fleet
extends RefCounted
## 船舶と艦隊任務（仕様30）。任務は ActionSystem の「fleet_mission」行動として実行し、
## 補給物資の消費・必要条件の検証を共通処理に乗せる。

signal changed

var data: GameData
var ships: Dictionary = {}  # uid -> {type, name, hp, crew:[member_id], sailors:int, morale, location, mission, history}
var next_uid := 1
var sailors_pool := 0  # 雇った船員（どの船にも乗っていない人数）

const SHIP_NAMES := ["カモメ号", "潮風号", "希望号", "灯火号", "波乗り号", "夜明け号", "北極星号", "海燕号"]


func _init(game_data: GameData) -> void:
	data = game_data


func ship_def(uid: String) -> Dictionary:
	return data.ships.get(str(ships.get(uid, {}).get("type", "")), {})


func add_ship(type: String, day: int, ship_name: String = "") -> String:
	var d: Dictionary = data.ships.get(type, {})
	if d.is_empty():
		return ""
	var uid := str(next_uid)
	next_uid += 1
	if ship_name == "":
		ship_name = SHIP_NAMES[(next_uid - 2) % SHIP_NAMES.size()]
	ships[uid] = {"type": type, "name": ship_name, "hp": float(d.get("hp", 50)), "crew": [], "sailors": 0, "morale": 60.0,
		"location": "home", "mission": {}, "history": [{"day": day, "text": "%sとして艦隊に加わった" % d.get("name", type)}]}
	changed.emit()
	return uid


func crew_count(uid: String) -> int:
	var sh: Dictionary = ships.get(uid, {})
	return sh.get("crew", []).size() + int(sh.get("sailors", 0))


func at_home(uid: String) -> bool:
	return ships.has(uid) and ships[uid]["location"] == "home"


## 仲間を船に乗せる（筏の作業からは外れる）。問題があれば理由を返す。
func assign_member(uid: String, member_id: String, s: GameSession) -> String:
	if not at_home(uid):
		return "船が港にいません"
	if not s.crew.is_aboard(member_id):
		return "%sは仲間にいません" % s.crew.display_name(member_id)
	for other in ships:
		if member_id in ships[other]["crew"]:
			ships[other]["crew"].erase(member_id)
	if crew_count(uid) >= int(ship_def(uid).get("crew_max", 1)):
		return "定員がいっぱいです"
	ships[uid]["crew"].append(member_id)
	s.crew.members[member_id]["job"] = "idle"
	changed.emit()
	return ""


func unassign_member(uid: String, member_id: String) -> void:
	if ships.has(uid):
		ships[uid]["crew"].erase(member_id)
		changed.emit()


func member_ship(member_id: String) -> String:
	for uid in ships:
		if member_id in ships[uid]["crew"]:
			return uid
	return ""


func member_on_mission(member_id: String) -> bool:
	var uid := member_ship(member_id)
	return uid != "" and ships[uid]["location"] == "mission"


func add_sailors(uid: String, n: int) -> String:
	if not at_home(uid):
		return "船が港にいません"
	if n > 0 and sailors_pool < n:
		return "雇っている船員が足りません"
	if n > 0 and crew_count(uid) + n > int(ship_def(uid).get("crew_max", 1)):
		return "定員がいっぱいです"
	if n < 0 and int(ships[uid]["sailors"]) < -n:
		return "船員が乗っていません"
	ships[uid]["sailors"] = int(ships[uid]["sailors"]) + n
	sailors_pool -= n
	changed.emit()
	return ""


## 艦隊としての戦力（武装＋乗組員の警備技能＋船員）
func power(uid: String, s: GameSession) -> float:
	var sh: Dictionary = ships[uid]
	var p := float(ship_def(uid).get("armament", 0))
	for m in sh["crew"]:
		p += 2.0 + 2.0 * s.crew.skill(m, "guard")
	p += int(sh["sailors"]) * 1.5
	p *= 0.6 + 0.4 * float(sh["hp"]) / maxf(1.0, float(ship_def(uid).get("hp", 1)))
	p *= 0.7 + 0.3 * float(sh["morale"]) / 100.0
	return p


func mission_def(mission_id: String) -> Dictionary:
	return data.missions.get(mission_id, {})


## 任務に必要な補給物資 = 船種の1日あたり消費 × 日数（切り上げ）
func mission_supplies(uid: String, mission_id: String) -> Dictionary:
	var hours := float(mission_def(mission_id).get("hours", 0))
	if hours <= 0.0:
		return {}
	var days := ceili(hours / 24.0)
	var out := {}
	var per: Dictionary = ship_def(uid).get("supply_per_day", {})
	for item in per:
		var n := ceili(float(per[item]) * days)
		if n > 0:
			out[item] = n
	if mission_id == "repair":
		out = {"repair_supplies": 2}
	return out


## 任務の可否（ActionSystem の effect validate から呼ばれる）
func mission_problem(uid: String, mission_id: String, target: String, s: GameSession) -> String:
	if not ships.has(uid):
		return "船がありません"
	var m := mission_def(mission_id)
	if m.is_empty():
		return "不明な任務です"
	if not at_home(uid):
		return "%sは任務中です" % ships[uid]["name"]
	if float(ships[uid]["hp"]) <= 0.0:
		return "%sは航行できません（要修理）" % ships[uid]["name"]
	var need_crew := maxi(int(m.get("crew_min", 0)), int(ship_def(uid).get("crew_min", 1)) if mission_id != "repair" else 0)
	if crew_count(uid) < need_crew:
		return "乗組員があと%d人必要です" % (need_crew - crew_count(uid))
	if float(ship_def(uid).get("armament", 0)) < float(m.get("needs_armament", 0)):
		return "武器設備が不足しています（武装%d以上の船が必要）" % int(m.get("needs_armament", 0))
	match str(m.get("target", "none")):
		"raid_target":
			if not data.raid_targets.has(target):
				return "目標を選んでください"
			if mission_id == "raid" and not bool(s.flags.get("scouted_" + target, false)):
				return "対象の情報がありません（先に偵察してください）"
		"faction":
			if not s.factions.factions.has(target) or not s.factions.factions[target]["alive"]:
				return "相手の勢力を選んでください"
			if s.factions.is_hostile_to_player(target):
				return "%sとは敵対しています" % s.factions.name_of(target)
		"zone":
			if not data.zones.has(target):
				return "海域を選んでください"
	if mission_id == "repair":
		if not s.raft.has_building("shipyard"):
			return "設備「船舶修理台」が必要です"
		if float(ships[uid]["hp"]) >= float(ship_def(uid).get("hp", 1)):
			return "修理の必要がありません"
	return ""


func start_mission(uid: String, mission_id: String, target: String) -> void:
	ships[uid]["location"] = "mission"
	ships[uid]["mission"] = {"id": mission_id, "target": target}
	changed.emit()


## 任務の結果を計算して適用し、報告文を返す
func resolve_mission(uid: String, s: GameSession) -> Array[String]:
	var out: Array[String] = []
	var sh: Dictionary = ships[uid]
	var mid := str(sh["mission"].get("id", ""))
	var target := str(sh["mission"].get("target", ""))
	var m := mission_def(mid)
	var rng := s.rng
	var day := s.clock.day()
	var name := str(sh["name"])
	sh["location"] = "home"
	sh["mission"] = {}
	var risk := float(m.get("risk", 0.0))
	var dmg := 0.0
	if rng.randf() < risk:
		dmg = float(ship_def(uid).get("hp", 50)) * rng.randf_range(0.1, 0.35)
	match mid:
		"scout":
			s.flags["scouted_" + target] = true
			out.append("%sが%sを偵察した。警備の配置と航路が分かった" % [name, data.raid_targets[target]["name"]])
		"explore":
			var found := 0
			for sid in data.sites:
				var sd: Dictionary = data.sites[sid]
				if sd.get("zone") == target and not s.is_site_discovered(sid) and not bool(sd.get("hidden", false)):
					s.discover_site(sid)
					found += 1
					if found >= 2:
						break
			var loot := LootRoller.roll_table(data.zones[target].get("drift_tables", {}).get("crate", {}), rng)
			s.inventory.add_many(loot, true)
			out.append("%sが%sを探索した（新しい地点%d件、%s）" % [name, data.zones[target]["name"], found, s.describe_items(loot)])
		"trade":
			var income := int(float(m.get("income", 50)) * (1.0 + float(ship_def(uid).get("cargo", 20)) / 100.0) * Trade.price_factor(s, target, false))
			s.money += income
			s.factions.change_standing(target, 3.0)
			s.change_reputation("trust", 1.0)
			out.append("%sが%sとの交易で%d貝貨を稼いだ" % [name, s.factions.name_of(target), income])
		"escort":
			var income := int(float(m.get("income", 60)))
			if dmg > 0.0 and rng.randf() > power(uid, s) / (power(uid, s) + 25.0):
				income = income / 2
				out.append("護衛中に海賊に襲われ、輸送船の一部を失った")
			s.money += income
			s.factions.change_standing(target, 5.0)
			s.change_reputation("trust", 2.0)
			s.change_reputation("fame", 1.0)
			out.append("%sが%sの輸送船を護衛した（報酬%d貝貨）" % [name, s.factions.name_of(target), income])
		"raid":
			out.append_array(_resolve_raid(uid, target, s))
			dmg = 0.0  # 襲撃の損害は _resolve_raid 内で計算
		"repair":
			sh["hp"] = minf(float(ship_def(uid).get("hp", 50)), float(sh["hp"]) + float(ship_def(uid).get("hp", 50)) * 0.6)
			out.append("%sの修理が完了した" % name)
	if dmg > 0.0:
		sh["hp"] = maxf(0.0, float(sh["hp"]) - dmg)
		out.append("%sが損傷した（耐久 -%d）" % [name, int(dmg)])
	for line in out:
		sh["history"].append({"day": day, "text": line})
	if float(sh["hp"]) <= 0.0:
		out.append(_sink(uid, s))
	changed.emit()
	return out


func _resolve_raid(uid: String, target: String, s: GameSession) -> Array[String]:
	var out: Array[String] = []
	var t: Dictionary = data.raid_targets[target]
	var rng := s.rng
	var sh: Dictionary = ships[uid]
	var p := power(uid, s)
	var chance := clampf(p / (p + float(t.get("defense", 20))) + 0.15, 0.05, 0.95)
	s.counters["piracy_today"] = float(s.counters.get("piracy_today", 0)) + 1.0
	s.counters["piracy_total"] = float(s.counters.get("piracy_total", 0)) + 1.0
	var fac := str(t.get("faction", ""))
	if rng.randf() < chance:
		var loot := LootRoller.roll_table(t.get("loot", {}), rng)
		var cargo := float(ship_def(uid).get("cargo", 20))
		var got := {}
		var w := 0.0
		for id in loot:
			for i in int(loot[id]):
				if w + s.inventory.item_weight(id) > cargo:
					break
				w += s.inventory.item_weight(id)
				got[id] = int(got.get(id, 0)) + 1
		s.inventory.add_many(got, true)
		var coins: Array = t.get("coins", [0, 0])
		var c := rng.randi_range(int(coins[0]), int(coins[1]))
		s.money += c
		out.append("%sが%sを襲撃し、成功した（%s、%d貝貨）" % [sh["name"], t["name"], s.describe_items(got), c])
		if got.size() < loot.size():
			out.append("船の貨物容量が不足し、一部の戦利品を諦めた")
		var cap_ship := str(t.get("capture_ship", ""))
		if cap_ship != "" and rng.randf() < float(t.get("capture_chance", 0.0)):
			var nu := add_ship(cap_ship, s.clock.day(), "拿捕船%d号" % next_uid)
			ships[nu]["hp"] = float(data.ships[cap_ship]["hp"]) * 0.4
			out.append("%sを拿捕した！" % data.ships[cap_ship]["name"])
		if rng.randf() < 0.4:
			var cap := s.prison_capacity() - s.prisoners.size()
			if cap > 0:
				s.prisoners.append({"from": target, "faction": fac, "day": s.clock.day()})
				out.append("捕虜を1人連れ帰った")
		sh["hp"] = maxf(0.0, float(sh["hp"]) - float(t.get("defense", 20)) * rng.randf_range(0.2, 0.6))
		sh["morale"] = minf(100.0, float(sh["morale"]) + 5.0)
	else:
		var d := float(t.get("defense", 20)) * rng.randf_range(0.8, 1.6)
		sh["hp"] = maxf(0.0, float(sh["hp"]) - d)
		sh["morale"] = maxf(0.0, float(sh["morale"]) - 15.0)
		out.append("%sの襲撃は失敗した（耐久 -%d）" % [sh["name"], int(d)])
	for k in t.get("reputation", {}):
		s.change_reputation(str(k), float(t["reputation"][k]))
	if fac != "":
		s.factions.change_standing(fac, float(t.get("standing", -10)))
	return out


## 沈没。乗組員は救命艇で戻る（負傷）。
func _sink(uid: String, s: GameSession) -> String:
	var sh: Dictionary = ships[uid]
	for m in sh["crew"]:
		s.crew.change(m, "health", -30)
		s.crew.change(m, "stress", 20)
	sailors_pool += maxi(0, int(sh["sailors"]) - 1)
	ships.erase(uid)
	return "%sが沈没した……。乗組員は救命艇で戻ってきた" % sh["name"]


## 任務を打ち切る（帰還・退却）。退却は士気が下がる。
func recall(uid: String, retreat: bool) -> void:
	if not ships.has(uid):
		return
	ships[uid]["location"] = "home"
	ships[uid]["mission"] = {}
	if retreat:
		ships[uid]["morale"] = maxf(0.0, float(ships[uid]["morale"]) - 10.0)
	changed.emit()


func to_dict() -> Dictionary:
	return {"ships": ships.duplicate(true), "next_uid": next_uid, "sailors_pool": sailors_pool}


func from_dict(d: Dictionary, s: GameSession) -> Array[String]:
	var w: Array[String] = []
	ships.clear()
	var sh: Variant = d.get("ships", {})
	var max_uid := 0
	if sh is Dictionary:
		for uid in sh:
			var e: Variant = sh[uid]
			if not (e is Dictionary) or not data.ships.has(str(e.get("type", ""))):
				w.append("不正な船 '%s' を除外" % str(uid))
				continue
			var crew: Array = []
			for m in e.get("crew", []):
				if data.survivors.has(str(m)):
					crew.append(str(m))
			ships[str(uid)] = {"type": str(e["type"]), "name": str(e.get("name", "船")), "hp": clampf(float(e.get("hp", 0)), 0.0, float(data.ships[e["type"]].get("hp", 50))),
				"crew": crew, "sailors": maxi(0, int(e.get("sailors", 0))), "morale": clampf(float(e.get("morale", 50)), 0.0, 100.0),
				"location": "mission" if e.get("location") == "mission" else "home", "mission": e.get("mission", {}) if e.get("mission") is Dictionary else {},
				"history": e.get("history", []) if e.get("history") is Array else []}
			if str(uid).is_valid_int():
				max_uid = maxi(max_uid, int(uid))
	next_uid = maxi(int(d.get("next_uid", 1)), max_uid + 1)
	sailors_pool = maxi(0, int(d.get("sailors_pool", 0)))
	return w

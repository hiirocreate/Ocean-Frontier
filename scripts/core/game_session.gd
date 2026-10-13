class_name GameSession
extends RefCounted
## 1回のプレイの全状態を束ねる。シーン（3D表示）から独立しているため、ヘッドレスでテストできる。

signal message(text: String)

const SAVE_FORMAT_VERSION := 1

var data: GameData
var clock: GameClock
var inventory: Inventory
var survival: SurvivalState
var raft: Raft
var actions: ActionSystem
var crew: Crew
var counters: Dictionary = {}  # research_points, guard_hours, piracy_today など
var reputation: Dictionary = {"fame": 0.0, "fear": 0.0, "trust": 0.0, "infamy": 0.0}
var prisoners: Array = []  # [{from, faction, day}]
var sites_state: Dictionary = {}  # site_id -> {"discovered": bool, "explored": int}
var pending_combat: Dictionary = {}  # {"enemy": id, "terrain": String, "source": String}
var rng: RandomNumberGenerator
var zone_id: String = "starting_waters"
var raft_position: Vector3 = Vector3.ZERO
var raft_rotation: float = 0.0
var flags: Dictionary = {}
var stats: Dictionary = {"debris_collected": 0, "tiles_built": 0, "items_crafted": 0}
var seed_value: int = 0


func _init(game_data: GameData) -> void:
	data = game_data
	rng = RandomNumberGenerator.new()
	clock = GameClock.new()
	inventory = Inventory.new(data, float(data.bal("inventory.max_weight", 60.0)))
	survival = SurvivalState.new(data)
	raft = Raft.new()
	raft.max_radius = int(data.bal("raft.max_radius", 8))
	raft.tile_durability = float(data.bal("raft.tile_durability", 100))
	actions = ActionSystem.new(data, inventory, rng, self)
	actions.register_effect("raft_add_tile", _validate_raft_tile, _apply_raft_tile)
	actions.register_effect("repair_item", _validate_repair, _apply_repair)
	actions.register_effect("place_building", _validate_building, _apply_building)
	actions.register_effect("rest", func(_p, _e): return "", func(_p): message.emit("よく眠った。疲れが取れた"))
	actions.register_effect("explore_site", _validate_explore, _apply_explore)
	actions.register_effect("story_beat", func(_p, _e): return "", _apply_story_beat)
	raft.changed.connect(update_capacity)
	actions.job_completed.connect(_on_job_completed)
	actions.job_blocked.connect(func(_j, problems): message.emit("作業が中断待ち: " + str(problems[0]["message"])))
	survival.warning.connect(func(_s, text): message.emit(text))
	crew = Crew.new(data)
	crew.member_joined.connect(func(id): message.emit("%sが仲間になった" % crew.display_name(id)))
	crew.member_warning.connect(func(_id, text): message.emit(text))
	crew.member_left.connect(func(id, reason): message.emit("%sが筏を去った……（%s）" % [crew.display_name(id), Crew.REASONS.get(reason, reason)]))
	survival.collapsed.connect(_on_collapsed)


func new_game(game_seed: int = 0) -> void:
	seed_value = game_seed if game_seed != 0 else int(Time.get_unix_time_from_system())
	rng.seed = seed_value
	clock.total_minutes = float(data.bal("time.start_hour", 7)) * 60.0
	zone_id = str(data.bal("world.start_zone", "starting_waters"))
	for p in data.bal("raft.start_tiles", [[0, 0]]):
		raft.tiles[Raft.key(Vector2i(int(p[0]), int(p[1])))] = {"type": "raft_foundation", "durability": raft.tile_durability}
	inventory.add_many(data.bal("start_inventory", {}), true)
	update_capacity()


## ゲーム内時間を進める。
func advance(minutes: float) -> void:
	if minutes <= 0.0:
		return
	var day_before := clock.day()
	clock.advance(minutes)
	survival.resting = is_sleeping()
	survival.tick(minutes)
	actions.advance(minutes, survival.efficiency(), crew.action_bonus(self))
	_tick_production(minutes)
	crew.tick(minutes, self)
	if clock.day() != day_before:
		counters["piracy_today"] = 0.0


# ---- 外部条件（ActionSystem.context） ----
func has_facility(building_id: String) -> bool:
	return raft.has_building(building_id)


func skill_level(skill: String) -> int:
	return crew.best_skill(skill)


func available_crew() -> int:
	return crew.available_crew(self)


# ---- 仲間・会話の効果 ----
## 会話やイベントの効果を適用する（DialogueRunner・EventManager から共通で使用）
func apply_effect(e: Dictionary) -> void:
	var t := str(e.get("type", ""))
	var target := str(e.get("target", ""))
	match t:
		"recruit":
			crew.recruit(target, clock.day())
		"trust", "loyalty", "satisfaction", "stress":
			crew.change(target, t, float(e.get("delta", 0)))
		"relation":
			crew.add_relation(str(e.get("from", "")), str(e.get("to", "")), str(e.get("kind", "")), float(e.get("delta", 0)))
		"flag":
			flags[str(e.get("key", ""))] = e.get("value", true)
		"counter":
			counters[str(e.get("key", ""))] = float(counters.get(str(e.get("key", "")), 0.0)) + float(e.get("delta", 1))
		"give_item":
			var id := str(e.get("item", ""))
			if not inventory.add(id, int(e.get("n", 1))):
				message.emit("%sを受け取れなかった（持ち物がいっぱい）" % data.item_name(id))
		"take_item":
			inventory.remove(str(e.get("item", "")), int(e.get("n", 1)))
		"message":
			message.emit(str(e.get("text", "")))
		_:
			GameLog.warn("未知の効果: %s" % t)


## 仲間と話すときの会話ID（未読で条件を満たすもの）。なければ空文字。
func talk_dialogue_for(member_id: String) -> String:
	for did in crew.def(member_id).get("talk", []):
		if flags.get("seen_" + did, false):
			continue
		if Conditions.check(data.dialogues.get(did, {}).get("condition", {}), self):
			return did
	return ""


## 状態に応じたひとこと（会話データがないとき）
func small_talk(member_id: String) -> String:
	var m: Dictionary = crew.members.get(member_id, {})
	if m.is_empty():
		return ""
	if float(m["thirst"]) < 25.0:
		return "……水が欲しい。喉がからからだ。"
	if float(m["hunger"]) < 25.0:
		return "腹が減って力が出ない……。"
	if float(m["fatigue"]) > 75.0:
		return "少し休ませてくれ。もう限界だ。"
	if float(m["stress"]) > 70.0:
		return "最近、気が休まらないんだ。"
	if float(m["satisfaction"]) > 70.0:
		return "ここでの暮らしも悪くない。ありがとう。"
	return "今日も海は静かだな。"


# ---- 漂流物 ----
## 漂流物を回収する。入りきらない分は失われ、結果に含めて返す。
func collect_debris(kind: String) -> Dictionary:
	var zone: Dictionary = data.zones.get(zone_id, {})
	var table: Dictionary = zone.get("drift_tables", {}).get(kind, {})
	var loot := LootRoller.roll_table(table, rng)
	var added := {}
	var lost := {}
	for id in loot:
		var n := int(loot[id])
		var fit := n
		var w := inventory.item_weight(id)
		if w > 0.0:
			fit = mini(n, int(floor((inventory.free_weight() + 0.0001) / w)))
		if fit > 0 and inventory.add(id, fit):
			added[id] = fit
		if n - fit > 0:
			lost[id] = n - fit
	stats["debris_collected"] = int(stats["debris_collected"]) + 1
	survival.add_fatigue(0.5)
	if not added.is_empty():
		message.emit("回収: " + describe_items(added))
	if not lost.is_empty():
		message.emit("重量オーバーで持てなかった: " + describe_items(lost))
	if added.has("old_letter"):
		flags["found_old_letter"] = true
	return {"added": added, "lost": lost}


## 消耗品を使用する。成功時 true。
func use_item(id: String) -> bool:
	var def := data.item(id)
	var eff: Dictionary = def.get("use_effects", {})
	if eff.is_empty():
		message.emit("%sは使用できません" % data.item_name(id))
		return false
	if not inventory.remove(id, 1):
		message.emit("%sを持っていません" % data.item_name(id))
		return false
	survival.apply_effects(eff)
	message.emit("%sを使用した" % data.item_name(id))
	return true


func describe_items(items: Dictionary) -> String:
	var parts: Array[String] = []
	for id in items:
		parts.append("%s×%d" % [data.item_name(id), int(items[id])])
	return "、".join(parts)


# ---- 筏の拡張 ----
func _validate_raft_tile(params: Dictionary, exclude_job_id: int) -> String:
	if not params.has("x") or not params.has("z"):
		return "設置位置が指定されていません"
	var p := Vector2i(int(params["x"]), int(params["z"]))
	var reason := raft.placement_problem(p)
	if reason != "":
		return reason
	for j in actions.jobs_with_action("expand_raft"):
		if int(j["id"]) != exclude_job_id and int(j["params"].get("x", 1e9)) == p.x and int(j["params"].get("z", 1e9)) == p.y:
			return "その位置はすでに建設中です"
	return ""


func _apply_raft_tile(params: Dictionary) -> void:
	if raft.add_tile(Vector2i(int(params["x"]), int(params["z"]))):
		stats["tiles_built"] = int(stats["tiles_built"]) + 1


func pending_tiles() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for j in actions.jobs_with_action("expand_raft"):
		out.append(Vector2i(int(j["params"]["x"]), int(j["params"]["z"])))
	return out


# ---- 建築物 ----
## 所持重量上限 = 基本値 + 収納箱などの容量
func update_capacity() -> void:
	var cap := float(data.bal("inventory.max_weight", 60.0))
	for uid in raft.buildings:
		var b: Dictionary = raft.buildings[uid]
		if float(b["durability"]) > 0.0:
			cap += float(data.buildings.get(b["id"], {}).get("storage_capacity", 0))
	inventory.max_weight = cap


func _validate_building(params: Dictionary, exclude_job_id: int) -> String:
	var bid := str(params.get("building", ""))
	if not data.buildings.has(bid):
		return "不明な設備です"
	if not params.has("x") or not params.has("z"):
		return "設置位置が指定されていません"
	var p := Vector2i(int(params["x"]), int(params["z"]))
	var reason := raft.building_placement_problem(p)
	if reason != "":
		return reason
	for j in actions.jobs:
		if int(j["id"]) != exclude_job_id and str(data.action(j["action"]).get("effect", "")) == "place_building" \
				and int(j["params"].get("x", 1e9)) == p.x and int(j["params"].get("z", 1e9)) == p.y:
			return "その位置はすでに建設中です"
	return ""


func _apply_building(params: Dictionary) -> void:
	var bid := str(params["building"])
	var dur := float(data.buildings[bid].get("max_durability", 50))
	if raft.place_building(bid, Vector2i(int(params["x"]), int(params["z"])), dur) != "":
		stats["buildings_built"] = int(stats.get("buildings_built", 0)) + 1


## 建設中（予約済み）の建築物 [{tile: Vector2i, building: id}]
func pending_buildings() -> Array:
	var out: Array = []
	for j in actions.jobs:
		if str(data.action(j["action"]).get("effect", "")) == "place_building":
			out.append({"tile": Vector2i(int(j["params"]["x"]), int(j["params"]["z"])), "building": str(data.action(j["action"])["effect_params"]["building"])})
	return out


func build_action_for(building_id: String) -> String:
	return str(data.buildings.get(building_id, {}).get("build_action", ""))


func _tick_production(minutes: float) -> void:
	for uid in raft.buildings:
		var b: Dictionary = raft.buildings[uid]
		var prod: Dictionary = data.buildings.get(b["id"], {}).get("production", {})
		if prod.is_empty() or float(b["durability"]) <= 0.0:
			continue
		var maxs := int(prod.get("max_stored", 1))
		if int(b["stored"]) >= maxs:
			b["progress"] = 0.0
			continue
		b["progress"] = float(b["progress"]) + minutes * crew.production_multiplier(str(b["id"]), self)
		var per := maxf(1.0, float(prod.get("minutes", 60)))
		while float(b["progress"]) >= per and int(b["stored"]) < maxs:
			b["progress"] = float(b["progress"]) - per
			b["stored"] = int(b["stored"]) + 1


## 生産物を回収する。持てた数を返す。
func harvest(uid: String) -> int:
	if not raft.buildings.has(uid):
		return 0
	var b: Dictionary = raft.buildings[uid]
	var prod: Dictionary = data.buildings.get(b["id"], {}).get("production", {})
	if prod.is_empty() or int(b["stored"]) <= 0:
		message.emit("まだ何もできていません")
		return 0
	var id := str(prod["item"])
	var n := int(b["stored"])
	var w := inventory.item_weight(id)
	var fit := n if w <= 0.0 else mini(n, int(floor((inventory.free_weight() + 0.0001) / w)))
	if fit <= 0:
		message.emit("持ち物がいっぱいです")
		return 0
	inventory.add(id, fit)
	b["stored"] = n - fit
	message.emit("%sを%d個手に入れた" % [data.item_name(id), fit])
	return fit


func is_sleeping() -> bool:
	for j in actions.jobs:
		if data.action(j["action"]).get("category") == "rest" and j["state"] == "running":
			return true
	return false


# ---- 海域・探索地点 ----
func zone_at(pos: Vector3) -> String:
	for id in data.zones:
		var b: Array = data.zones[id].get("bounds", [])
		if b.size() == 4 and pos.x >= float(b[0]) and pos.z >= float(b[1]) and pos.x < float(b[2]) and pos.z < float(b[3]):
			return id
	return str(data.bal("world.open_sea_zone", "starting_waters"))


## 位置を更新し、海域の変化と探索地点の発見を処理する。変化があれば海域IDを返す。
func update_location(pos: Vector3) -> String:
	raft_position = Vector3(pos.x, 0, pos.z)
	var z := zone_at(raft_position)
	var changed_zone := ""
	if z != zone_id:
		zone_id = z
		changed_zone = z
		message.emit("「%s」に入った" % data.zones[z].get("name", z))
		flags["visited_" + z] = true
	for id in data.sites:
		if is_site_discovered(id):
			continue
		var sd: Dictionary = data.sites[id]
		if bool(sd.get("hidden", false)) and not Conditions.check(sd.get("discover_condition", {}), self):
			continue
		if site_distance(id) <= float(sd.get("discover_radius", 150)):
			discover_site(id)
	return changed_zone


func site_position(id: String) -> Vector3:
	var p: Array = data.sites.get(id, {}).get("position", [0, 0])
	return Vector3(float(p[0]), 0, float(p[1]))


func site_distance(id: String) -> float:
	return Vector2(raft_position.x, raft_position.z).distance_to(Vector2(site_position(id).x, site_position(id).z))


func is_site_discovered(id: String) -> bool:
	return bool(sites_state.get(id, {}).get("discovered", false))


func discover_site(id: String) -> void:
	if not data.sites.has(id) or is_site_discovered(id):
		return
	var st: Dictionary = sites_state.get(id, {"discovered": false, "explored": 0})
	st["discovered"] = true
	sites_state[id] = st
	message.emit("発見: %s" % data.sites[id].get("name", id))


func site_explorations_left(id: String) -> int:
	return int(data.sites.get(id, {}).get("max_explorations", 0)) - int(sites_state.get(id, {}).get("explored", 0))


## 近くにある（探索や訪問ができる）地点
func nearby_site(max_dist: float = 30.0) -> String:
	var best := ""
	var best_d := max_dist
	for id in data.sites:
		if not is_site_discovered(id):
			continue
		var d := site_distance(id)
		if d <= best_d:
			best_d = d
			best = id
	return best


func _validate_explore(params: Dictionary, _exclude: int) -> String:
	var id := str(params.get("site", ""))
	if not data.sites.has(id):
		return "探索地点が指定されていません"
	if site_distance(id) > float(data.bal("world.explore_range", 30.0)):
		return "%sから離れすぎています" % data.sites[id].get("name", id)
	if site_explorations_left(id) <= 0:
		return "%sはもう探索し尽くした" % data.sites[id].get("name", id)
	return ""


func _apply_explore(params: Dictionary) -> void:
	var id := str(params["site"])
	var sd: Dictionary = data.sites[id]
	var st: Dictionary = sites_state.get(id, {"discovered": true, "explored": 0})
	var first := int(st.get("explored", 0)) == 0
	st["explored"] = int(st.get("explored", 0)) + 1
	sites_state[id] = st
	var loot := LootRoller.roll_table(sd.get("loot", {}), rng)
	if first:
		var uniq: Dictionary = sd.get("unique_items", {})
		for k in uniq:
			loot[k] = int(loot.get(k, 0)) + int(uniq[k])
	var got := {}
	var lost := {}
	for k in loot:
		var clue := bool(data.item(k).get("clue", false))
		if inventory.add_many({k: int(loot[k])}, clue):  # 物語アイテムは重量超過でも必ず受け取る
			got[k] = loot[k]
		else:
			lost[k] = loot[k]
	if not got.is_empty():
		message.emit("%sで見つけた: %s" % [sd.get("name", id), describe_items(got)])
	if not lost.is_empty():
		message.emit("持ちきれず置いてきた: " + describe_items(lost))
	if first:
		for f in sd.get("flags", {}):
			flags[f] = sd["flags"][f]
	stats["sites_explored"] = int(stats.get("sites_explored", 0)) + 1
	var cb: Dictionary = sd.get("combat", {})
	if not cb.is_empty() and rng.randf() < float(cb.get("chance", 0.0)):
		var terrain := "underwater" if str(sd.get("type", "")).begins_with("underwater") or sd.get("explore_action", "") in ["explore_underwater", "explore_research", "explore_core"] else "site"
		start_combat(str(cb["group"]), terrain, "site:" + id)


func _apply_story_beat(params: Dictionary) -> void:
	var fl: Dictionary = params.get("flags", {})
	for f in fl:
		flags[f] = fl[f]
	for sid in params.get("reveal_sites", []):
		discover_site(str(sid))
	if str(params.get("text", "")) != "":
		message.emit(str(params["text"]))


# ---- 戦闘 ----
func start_combat(enemy_id: String, terrain: String = "raft", source: String = "") -> void:
	if not data.enemies.has(enemy_id):
		return
	pending_combat = {"enemy": enemy_id, "terrain": terrain, "source": source}
	message.emit("%sが現れた！" % data.enemies[enemy_id].get("name", enemy_id))


func resolve_combat(stance: String) -> Dictionary:
	if pending_combat.is_empty():
		return {}
	var r := CombatSystem.resolve(self, str(pending_combat["enemy"]), stance, str(pending_combat.get("terrain", "raft")))
	r["messages"] = CombatSystem.apply_result(self, r)
	pending_combat = {}
	return r


func change_reputation(kind: String, delta: float) -> void:
	if reputation.has(kind):
		reputation[kind] = clampf(float(reputation[kind]) + delta, 0.0, 100.0)


func prison_capacity() -> int:
	var cap := 0
	for uid in raft.buildings:
		cap += int(data.buildings.get(raft.buildings[uid]["id"], {}).get("prison_capacity", 0))
	return cap


# ---- 修理 ----
func _validate_repair(params: Dictionary, _exclude: int) -> String:
	var id := str(params.get("item", ""))
	if inventory.count(id) == 0:
		return "%sを持っていません" % data.item_name(id)
	if not inventory.is_damaged(id):
		return "%sは修理の必要がありません" % data.item_name(id)
	return ""


func _apply_repair(params: Dictionary) -> void:
	inventory.repair_most_worn(str(params["item"]), float(params.get("amount", 10)))


func _on_job_completed(job: Dictionary, result: Dictionary) -> void:
	var a := data.action(job["action"])
	survival.add_fatigue(float(a.get("fatigue", 0)))
	if result["success"]:
		if a.get("category") == "craft":
			stats["items_crafted"] = int(stats["items_crafted"]) + 1
		message.emit("完了: %s" % a.get("name", job["action"]))
	else:
		var lost: Dictionary = result.get("lost", {})
		message.emit("失敗: %s%s" % [a.get("name", job["action"]), ("（失った素材: %s）" % describe_items(lost)) if not lost.is_empty() else ""])


func _on_collapsed() -> void:
	var hours := float(data.bal("survival.collapse_recovery.skip_hours", 6))
	clock.advance(hours * 60.0)
	message.emit("あなたは倒れた……%d時間後、なんとか意識を取り戻した" % int(hours))


# ---- 保存 ----
func to_dict() -> Dictionary:
	return {
		"seed": seed_value,
		"rng_state": str(rng.state),
		"zone_id": zone_id,
		"clock": clock.to_dict(),
		"inventory": inventory.to_dict(),
		"survival": survival.to_dict(),
		"raft": raft.to_dict(),
		"raft_position": [raft_position.x, raft_position.y, raft_position.z],
		"raft_rotation": raft_rotation,
		"actions": actions.to_dict(),
		"flags": flags.duplicate(true),
		"stats": stats.duplicate(),
		"crew": crew.to_dict(),
		"counters": counters.duplicate(),
		"reputation": reputation.duplicate(),
		"prisoners": prisoners.duplicate(true),
		"sites_state": sites_state.duplicate(true),
		"pending_combat": pending_combat.duplicate(),
	}


## 保存データから復元。致命的な不整合は errors、補正したものは warnings に入る。
func from_dict(d: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	for k in ["clock", "inventory", "survival", "raft"]:
		if not (d.get(k) is Dictionary):
			errors.append("必須項目 '%s' がありません" % k)
	if not errors.is_empty():
		return {"errors": errors, "warnings": warnings}
	seed_value = int(d.get("seed", 0))
	rng.seed = seed_value
	var st := str(d.get("rng_state", ""))
	if st.is_valid_int():
		rng.state = st.to_int()
	zone_id = str(d.get("zone_id", "starting_waters"))
	if not data.zones.has(zone_id):
		warnings.append("未知の海域 '%s' → 初期海域へ" % zone_id)
		zone_id = str(data.bal("world.start_zone", "starting_waters"))
	clock.from_dict(d["clock"])
	warnings.append_array(inventory.from_dict(d["inventory"]))
	warnings.append_array(survival.from_dict(d["survival"]))
	warnings.append_array(raft.from_dict(d["raft"]))
	for uid in raft.buildings.keys():
		if not data.buildings.has(raft.buildings[uid]["id"]):
			warnings.append("未知の建築物 '%s' を除外" % raft.buildings[uid]["id"])
			raft.buildings.erase(uid)
	update_capacity()
	var acts: Variant = d.get("actions", {})
	warnings.append_array(actions.from_dict(acts if acts is Dictionary else {}))
	var rp: Variant = d.get("raft_position", [0, 0, 0])
	if rp is Array and rp.size() == 3:
		raft_position = Vector3(float(rp[0]), float(rp[1]), float(rp[2]))
	raft_rotation = float(d.get("raft_rotation", 0.0))
	var fl: Variant = d.get("flags", {})
	flags = fl.duplicate(true) if fl is Dictionary else {}
	var cr: Variant = d.get("crew", {})
	warnings.append_array(crew.from_dict(cr if cr is Dictionary else {}))
	var cn: Variant = d.get("counters", {})
	counters.clear()
	if cn is Dictionary:
		for k in cn:
			counters[str(k)] = float(cn[k])
	var rep: Variant = d.get("reputation", {})
	if rep is Dictionary:
		for k in reputation:
			reputation[k] = clampf(float(rep.get(k, 0.0)), 0.0, 100.0)
	var pr: Variant = d.get("prisoners", [])
	prisoners = pr.duplicate(true) if pr is Array else []
	sites_state.clear()
	var ss: Variant = d.get("sites_state", {})
	if ss is Dictionary:
		for k in ss:
			if data.sites.has(str(k)) and ss[k] is Dictionary:
				sites_state[str(k)] = {"discovered": bool(ss[k].get("discovered", false)), "explored": maxi(0, int(ss[k].get("explored", 0)))}
			else:
				warnings.append("未知の探索地点 '%s' を除外" % str(k))
	var pc: Variant = d.get("pending_combat", {})
	pending_combat = pc.duplicate() if pc is Dictionary and data.enemies.has(str(pc.get("enemy", ""))) else {}
	var sts: Variant = d.get("stats", {})
	if sts is Dictionary:
		for k in sts:
			stats[k] = int(sts[k])
	return {"errors": errors, "warnings": warnings}

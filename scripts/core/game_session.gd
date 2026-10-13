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
	actions.job_completed.connect(_on_job_completed)
	actions.job_blocked.connect(func(_j, problems): message.emit("作業が中断待ち: " + str(problems[0]["message"])))
	survival.warning.connect(func(_s, text): message.emit(text))
	survival.collapsed.connect(_on_collapsed)


func new_game(game_seed: int = 0) -> void:
	seed_value = game_seed if game_seed != 0 else int(Time.get_unix_time_from_system())
	rng.seed = seed_value
	clock.total_minutes = float(data.bal("time.start_hour", 7)) * 60.0
	zone_id = str(data.bal("world.start_zone", "starting_waters"))
	for p in data.bal("raft.start_tiles", [[0, 0]]):
		raft.tiles[Raft.key(Vector2i(int(p[0]), int(p[1])))] = {"type": "raft_foundation", "durability": raft.tile_durability}
	inventory.add_many(data.bal("start_inventory", {}), true)


## ゲーム内時間を進める。
func advance(minutes: float) -> void:
	if minutes <= 0.0:
		return
	clock.advance(minutes)
	survival.tick(minutes)
	actions.advance(minutes, survival.efficiency())


# ---- 外部条件（ActionSystem.context） ----
func has_facility(building_id: String) -> bool:
	return raft.has_building(building_id)


func skill_level(_skill: String) -> int:
	return 0  # 仲間システム（フェーズ4）で実装


func available_crew() -> int:
	return 0  # 仲間システム（フェーズ4）で実装


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
	var acts: Variant = d.get("actions", {})
	warnings.append_array(actions.from_dict(acts if acts is Dictionary else {}))
	var rp: Variant = d.get("raft_position", [0, 0, 0])
	if rp is Array and rp.size() == 3:
		raft_position = Vector3(float(rp[0]), float(rp[1]), float(rp[2]))
	raft_rotation = float(d.get("raft_rotation", 0.0))
	var fl: Variant = d.get("flags", {})
	flags = fl.duplicate(true) if fl is Dictionary else {}
	var sts: Variant = d.get("stats", {})
	if sts is Dictionary:
		for k in sts:
			stats[k] = int(sts[k])
	return {"errors": errors, "warnings": warnings}

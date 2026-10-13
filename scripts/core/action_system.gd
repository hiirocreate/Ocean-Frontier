class_name ActionSystem
extends RefCounted
## すべての行動（クラフト・建築・修理・筏拡張…）の必要条件検証と消費を一元管理する（仕様18）。
## - 開始時に inputs を在庫から「預かり」(escrow) に移すため、二重消費は構造上起こらない。
## - 時間のかかる行動は完了時に工具・設備・容量・効果条件を再検証し、満たさなければ blocked 状態で待機する。
## - 成功: 預かり品を消費し outputs と effect を適用。失敗: on_fail.lose_ratio 分を失い残りを返却。
## - 中断: on_cancel.lose_ratio 分を失い残りを返却。

signal job_started(job: Dictionary)
signal job_completed(job: Dictionary, result: Dictionary)
signal job_blocked(job: Dictionary, problems: Array)
signal job_cancelled(job: Dictionary, lost: Dictionary)

var data: GameData
var inventory: Inventory
var rng: RandomNumberGenerator
## 設備・技能・人数などの外部条件を問い合わせる先（GameSession）。
## 必要メソッド: has_facility(id)->bool, skill_level(skill)->int, available_crew()->int
var context: Object
var jobs: Array = []
var next_job_id: int = 1
## effect名 -> {"validate": Callable(params, exclude_job_id)->String, "apply": Callable(params)->void}
var effects: Dictionary = {}


func _init(game_data: GameData, inv: Inventory, random: RandomNumberGenerator, ctx: Object) -> void:
	data = game_data
	inventory = inv
	rng = random
	context = ctx


func register_effect(effect_name: String, validate: Callable, apply: Callable) -> void:
	effects[effect_name] = {"validate": validate, "apply": apply}


static func problem(code: String, message: String, extra: Dictionary = {}) -> Dictionary:
	var p := {"code": code, "message": message}
	p.merge(extra)
	return p


## 必要条件を一覧化（UI表示用）。各要素 {kind, id, name, need, have, ok}
func requirement_rows(action_id: String) -> Array:
	var a := data.action(action_id)
	var rows: Array = []
	var inputs: Dictionary = a.get("inputs", {})
	for id in inputs:
		var need := int(inputs[id])
		var have := inventory.count(id)
		rows.append({"kind": "item", "id": id, "name": data.item_name(id), "need": need, "have": have, "ok": have >= need})
	for t in a.get("tools", []):
		var tid := str(t["item"])
		var ok := not inventory.find_tool(tid, float(t.get("min_durability", 1))).is_empty()
		rows.append({"kind": "tool", "id": tid, "name": data.item_name(tid), "need": 1, "have": inventory.count(tid), "ok": ok})
	for f in a.get("facilities", []):
		var ok2: bool = context != null and context.has_facility(str(f))
		rows.append({"kind": "facility", "id": f, "name": data.building_name(str(f)), "need": 1, "have": 1 if ok2 else 0, "ok": ok2})
	return rows


## 実行可能か検証。問題がなければ空配列。
func check(action_id: String, params: Dictionary = {}, exclude_job_id: int = -1) -> Array:
	var a := data.action(action_id)
	if a.is_empty():
		return [problem("unknown_action", "不明な行動です: %s" % action_id)]
	var problems: Array = []
	var inputs: Dictionary = a.get("inputs", {})
	var lack := inventory.missing(inputs)
	for id in lack:
		problems.append(problem("missing_item",
			"%sが%d個不足しています" % [data.item_name(id), lack[id]],
			{"item": id, "need": int(inputs[id]), "have": inventory.count(id), "missing": lack[id]}))
	problems.append_array(_check_conditions(a, params, true, exclude_job_id))
	return problems


## アイテム数以外の条件（工具・設備・技能・人数・容量・効果）。
func _check_conditions(a: Dictionary, params: Dictionary, inputs_in_inventory: bool, exclude_job_id: int) -> Array:
	var problems: Array = []
	for t in a.get("tools", []):
		var tid := str(t["item"])
		var min_d := float(t.get("min_durability", 1))
		if inventory.count(tid) == 0:
			problems.append(problem("missing_tool", "%sが必要です" % data.item_name(tid), {"item": tid}))
		elif inventory.find_tool(tid, min_d).is_empty():
			problems.append(problem("tool_durability", "%sの耐久度が不足しています（修理が必要です）" % data.item_name(tid), {"item": tid}))
	for f in a.get("facilities", []):
		if context == null or not context.has_facility(str(f)):
			problems.append(problem("missing_facility", "設備「%s」が必要です" % data.building_name(str(f)), {"facility": f}))
	var skills: Dictionary = a.get("skills", {})
	for s in skills:
		var lv: int = context.skill_level(str(s)) if context else 0
		if lv < int(skills[s]):
			problems.append(problem("missing_skill", "技能「%s」Lv%dが必要です" % [s, int(skills[s])], {"skill": s}))
	var crew := int(a.get("min_crew", 0))
	if crew > 0:
		var avail: int = context.available_crew() if context else 0
		if avail < crew:
			problems.append(problem("missing_crew", "作業できる仲間があと%d人必要です" % (crew - avail)))
	var outputs: Dictionary = a.get("outputs", {})
	var delta := inventory.weight_of(outputs)
	if inputs_in_inventory:
		delta -= inventory.weight_of(a.get("inputs", {}))
	if delta > inventory.free_weight() + 0.0001:
		problems.append(problem("no_capacity", "所持重量の空き容量が不足しています（あと%.1f必要）" % (delta - inventory.free_weight())))
	var eff := str(a.get("effect", ""))
	if eff != "":
		if not effects.has(eff):
			problems.append(problem("unknown_effect", "効果 '%s' が未登録です" % eff))
		else:
			var msg: String = effects[eff]["validate"].call(_effect_params(a, params), exclude_job_id)
			if msg != "":
				problems.append(problem("effect", msg))
	return problems


func _effect_params(a: Dictionary, params: Dictionary) -> Dictionary:
	var p: Dictionary = a.get("effect_params", {}).duplicate()
	p.merge(params, true)
	return p


## 行動を開始する。戻り値 {"ok": bool, "problems": Array, "job": Dictionary, "result": Dictionary}
func start(action_id: String, params: Dictionary = {}) -> Dictionary:
	var problems := check(action_id, params)
	if not problems.is_empty():
		return {"ok": false, "problems": problems, "job": {}, "result": {}}
	var a := data.action(action_id)
	var inputs: Dictionary = a.get("inputs", {})
	var escrow := inventory.take(inputs) if not inputs.is_empty() else {"stacks": {}, "instances": []}
	if escrow.is_empty():
		return {"ok": false, "problems": [problem("missing_item", "素材を確保できませんでした")], "job": {}, "result": {}}
	var job := {
		"id": next_job_id, "action": action_id, "params": params.duplicate(),
		"escrow": escrow, "elapsed": 0.0, "duration": float(a.get("duration_minutes", 0)),
		"state": "running", "problems": [],
	}
	next_job_id += 1
	jobs.append(job)
	job_started.emit(job)
	var result := {}
	if job["duration"] <= 0.0:
		result = _try_complete(job)
	return {"ok": true, "problems": [], "job": job, "result": result}


## category_bonus: {カテゴリ: 追加倍率}（仲間の作業による加速）
func advance(minutes: float, efficiency: float = 1.0, category_bonus: Dictionary = {}) -> void:
	for job in jobs.duplicate():
		if job["state"] == "running":
			var cat := str(data.action(job["action"]).get("category", ""))
			job["elapsed"] = float(job["elapsed"]) + minutes * (efficiency + float(category_bonus.get(cat, 0.0)))
			if job["elapsed"] >= job["duration"]:
				_try_complete(job)
		elif job["state"] == "blocked":
			_try_complete(job)


func _try_complete(job: Dictionary) -> Dictionary:
	var a := data.action(job["action"])
	var problems := _check_conditions(a, job["params"], false, int(job["id"]))
	if not problems.is_empty():
		if job["state"] != "blocked" or job["problems"] != problems:
			job["state"] = "blocked"
			job["problems"] = problems
			job_blocked.emit(job, problems)
		return {}
	jobs.erase(job)
	var success := rng.randf() < float(a.get("success_chance", 1.0))
	var result := {"success": success, "action": job["action"], "outputs": {}, "lost": {}}
	for t in a.get("tools", []):
		var tool := inventory.find_tool(str(t["item"]), float(t.get("min_durability", 1)))
		if not tool.is_empty():
			inventory.wear(int(tool["uid"]), float(t.get("wear", 0)))
	if success:
		var outputs: Dictionary = a.get("outputs", {})
		inventory.add_many(outputs, true)
		result["outputs"] = outputs.duplicate()
		var eff := str(a.get("effect", ""))
		if eff != "":
			effects[eff]["apply"].call(_effect_params(a, job["params"]))
	else:
		result["lost"] = inventory.give_back(job["escrow"], float(a.get("on_fail", {}).get("lose_ratio", 0.5)))
	job["state"] = "done"
	job_completed.emit(job, result)
	return result


func cancel(job_id: int) -> Dictionary:
	for job in jobs:
		if int(job["id"]) == job_id:
			jobs.erase(job)
			var a := data.action(job["action"])
			var lost := inventory.give_back(job["escrow"], float(a.get("on_cancel", {}).get("lose_ratio", 0.0)))
			job["state"] = "cancelled"
			job_cancelled.emit(job, lost)
			return lost
	return {}


func jobs_with_action(action_id: String) -> Array:
	return jobs.filter(func(j): return j["action"] == action_id)


func to_dict() -> Dictionary:
	return {"jobs": jobs.duplicate(true), "next_job_id": next_job_id}


func from_dict(d: Dictionary) -> Array[String]:
	var w: Array[String] = []
	jobs.clear()
	var max_id := 0
	var list: Variant = d.get("jobs", [])
	if list is Array:
		for j in list:
			if not (j is Dictionary) or not data.actions.has(str(j.get("action", ""))):
				w.append("不正な作業データを除外")
				continue
			var job: Dictionary = j.duplicate(true)
			job["id"] = int(job.get("id", 0))
			job["elapsed"] = maxf(0.0, float(job.get("elapsed", 0.0)))
			job["duration"] = float(data.action(job["action"]).get("duration_minutes", 0))
			if not (job.get("escrow") is Dictionary):
				job["escrow"] = {"stacks": {}, "instances": []}
			if not (job.get("params") is Dictionary):
				job["params"] = {}
			job["state"] = "running" if job.get("state") != "blocked" else "blocked"
			job["problems"] = []
			jobs.append(job)
			max_id = maxi(max_id, job["id"])
	next_job_id = maxi(int(d.get("next_job_id", 1)), max_id + 1)
	return w

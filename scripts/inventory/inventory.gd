class_name Inventory
extends RefCounted
## プレイヤーの所持品（状態）。定義は GameData が持つ。
## スタック可能品は個数のみ、スタック不可品（工具・武器）は耐久度付きの個体として管理する。
## 追加・削除はすべてこのクラスを通す（重量制限と二重増減の防止を一元化）。

signal changed

var data: GameData
var stacks: Dictionary = {}  # item_id -> int
var instances: Array = []  # [{"uid": int, "id": String, "durability": float}]
var next_uid: int = 1
var max_weight: float = 60.0


func _init(game_data: GameData, capacity: float = 60.0) -> void:
	data = game_data
	max_weight = capacity


func is_known(id: String) -> bool:
	return data.items.has(id)


func is_stackable(id: String) -> bool:
	return bool(data.item(id).get("stackable", true))


func item_weight(id: String) -> float:
	return float(data.item(id).get("weight", 0.0))


func max_durability(id: String) -> float:
	return float(data.item(id).get("max_durability", 0.0))


func count(id: String) -> int:
	if is_stackable(id):
		return int(stacks.get(id, 0))
	var n := 0
	for inst in instances:
		if inst["id"] == id:
			n += 1
	return n


func total_weight() -> float:
	var w := 0.0
	for id in stacks:
		w += item_weight(id) * int(stacks[id])
	for inst in instances:
		w += item_weight(inst["id"])
	return w


func weight_of(items: Dictionary) -> float:
	var w := 0.0
	for id in items:
		w += item_weight(id) * int(items[id])
	return w


func free_weight() -> float:
	return max_weight - total_weight()


func can_add(items: Dictionary) -> bool:
	for id in items:
		if not is_known(id) or int(items[id]) < 0:
			return false
	return weight_of(items) <= free_weight() + 0.0001


## 1種類を追加。容量超過・未知IDの場合は何もせず false。
func add(id: String, n: int = 1) -> bool:
	return add_many({id: n})


## 複数種類をまとめて追加（全部入るときだけ追加する）。
func add_many(items: Dictionary, ignore_capacity: bool = false) -> bool:
	for id in items:
		if not is_known(id):
			GameLog.warn("未知のアイテムID: %s" % id)
			return false
		if int(items[id]) < 0:
			return false
	if not ignore_capacity and not can_add(items):
		return false
	for id in items:
		_add_raw(id, int(items[id]))
	if not items.is_empty():
		changed.emit()
	return true


func _add_raw(id: String, n: int) -> void:
	if n <= 0:
		return
	if is_stackable(id):
		stacks[id] = int(stacks.get(id, 0)) + n
	else:
		for i in n:
			instances.append({"uid": next_uid, "id": id, "durability": max_durability(id)})
			next_uid += 1


func has_all(items: Dictionary) -> bool:
	for id in items:
		if count(id) < int(items[id]):
			return false
	return true


## 不足分を {id: 不足数} で返す。
func missing(items: Dictionary) -> Dictionary:
	var out := {}
	for id in items:
		var lack := int(items[id]) - count(id)
		if lack > 0:
			out[id] = lack
	return out


func remove(id: String, n: int = 1) -> bool:
	return remove_many({id: n})


## まとめて削除（全部そろっているときだけ削除する）。
func remove_many(items: Dictionary) -> bool:
	return not take(items).is_empty() or items.is_empty()


## 指定品を取り出して預かり品（escrow）として返す。不足時は {} を返し何も変えない。
## escrow = {"stacks": {id: n}, "instances": [inst, ...]}
func take(items: Dictionary) -> Dictionary:
	if items.is_empty() or not has_all(items):
		return {}
	var escrow := {"stacks": {}, "instances": []}
	for id in items:
		var n := int(items[id])
		if n <= 0:
			continue
		if is_stackable(id):
			stacks[id] = int(stacks[id]) - n
			if stacks[id] <= 0:
				stacks.erase(id)
			escrow["stacks"][id] = n
		else:
			# 耐久度の低い個体から使う
			var owned := instances.filter(func(i): return i["id"] == id)
			owned.sort_custom(func(a, b): return a["durability"] < b["durability"])
			for k in n:
				instances.erase(owned[k])
				escrow["instances"].append(owned[k])
	changed.emit()
	return escrow


## 預かり品を戻す。lose_ratio 分は失われる（切り捨て）。容量制限は無視（預かり品の消失を防ぐため）。
## 戻らなかった分を {id: n} で返す。
func give_back(escrow: Dictionary, lose_ratio: float = 0.0) -> Dictionary:
	var lost := {}
	var st: Dictionary = escrow.get("stacks", {})
	for id in st:
		var n := int(st[id])
		var lose := int(floor(n * lose_ratio))
		if lose > 0:
			lost[id] = lose
		if is_known(id):
			_add_raw(id, n - lose)
	var insts: Array = escrow.get("instances", [])
	var lose_inst := int(floor(insts.size() * lose_ratio))
	for k in insts.size():
		var inst: Dictionary = insts[k]
		if k < lose_inst:
			lost[inst["id"]] = int(lost.get(inst["id"], 0)) + 1
		elif is_known(inst["id"]):
			instances.append(inst.duplicate())
	changed.emit()
	return lost


func get_instance(uid: int) -> Dictionary:
	for inst in instances:
		if int(inst["uid"]) == uid:
			return inst
	return {}


## 耐久度 min_dur 以上（かつ0より大）の個体のうち最も耐久度が高いものを返す。
func find_tool(id: String, min_dur: float = 1.0) -> Dictionary:
	var best := {}
	for inst in instances:
		if inst["id"] != id:
			continue
		var d := float(inst["durability"])
		if d <= 0.0 or d < min_dur:
			continue
		if best.is_empty() or d > float(best["durability"]):
			best = inst
	return best


func wear(uid: int, amount: float) -> void:
	var inst := get_instance(uid)
	if inst.is_empty():
		return
	inst["durability"] = maxf(0.0, float(inst["durability"]) - amount)
	changed.emit()


## 最も損耗した個体を修理する。修理した個体を返す。
func repair_most_worn(id: String, amount: float) -> Dictionary:
	var target := {}
	for inst in instances:
		if inst["id"] == id and float(inst["durability"]) < max_durability(id):
			if target.is_empty() or float(inst["durability"]) < float(target["durability"]):
				target = inst
	if target.is_empty():
		return {}
	target["durability"] = minf(max_durability(id), float(target["durability"]) + amount)
	changed.emit()
	return target


func is_damaged(id: String) -> bool:
	for inst in instances:
		if inst["id"] == id and float(inst["durability"]) < max_durability(id):
			return true
	return false


func to_dict() -> Dictionary:
	return {"stacks": stacks.duplicate(), "instances": instances.duplicate(true), "next_uid": next_uid}


## 保存データから復元。不正値は除外し警告一覧を返す。
func from_dict(d: Dictionary) -> Array[String]:
	var warnings: Array[String] = []
	stacks.clear()
	instances.clear()
	var pending_nonstack := {}
	var st: Variant = d.get("stacks", {})
	if st is Dictionary:
		for id in st:
			if not is_known(id):
				warnings.append("未知のアイテム '%s' を除外" % id)
				continue
			var n := int(st[id])
			if n <= 0:
				warnings.append("不正な数量 '%s'=%s を除外" % [id, str(st[id])])
				continue
			if not is_stackable(id):
				warnings.append("スタック不可アイテム '%s' がスタックに含まれていたため個体化" % id)
				pending_nonstack[id] = n
				continue
			stacks[id] = n
	var max_uid := 0
	var insts: Variant = d.get("instances", [])
	if insts is Array:
		for inst in insts:
			if not (inst is Dictionary) or not is_known(str(inst.get("id", ""))):
				warnings.append("不正な個体データを除外")
				continue
			var id := str(inst["id"])
			var uid := int(inst.get("uid", 0))
			var dur := clampf(float(inst.get("durability", 0.0)), 0.0, max_durability(id))
			instances.append({"uid": uid, "id": id, "durability": dur})
			max_uid = maxi(max_uid, uid)
	next_uid = maxi(int(d.get("next_uid", 1)), max_uid + 1)
	for id in pending_nonstack:
		_add_raw(id, int(pending_nonstack[id]))
	changed.emit()
	return warnings

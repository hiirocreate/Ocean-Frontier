class_name LootRoller
extends RefCounted
## 重み付き抽選。乱数は呼び出し側（GameSession）の RNG を使い、セーブとの整合性を保つ。


static func pick_weighted(entries: Array, rng: RandomNumberGenerator, weight_key: String = "weight") -> Dictionary:
	var total := 0.0
	for e in entries:
		total += maxf(0.0, float(e.get(weight_key, 0.0)))
	if total <= 0.0:
		return {}
	var r := rng.randf() * total
	for e in entries:
		r -= maxf(0.0, float(e.get(weight_key, 0.0)))
		if r <= 0.0:
			return e
	return entries.back()


## drift_table = {"rolls": [min,max], "entries": [{item,min,max,weight}]}
static func roll_table(table: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var out := {}
	var rolls: Array = table.get("rolls", [1, 1])
	var n := rng.randi_range(int(rolls[0]), int(rolls[1]))
	for i in n:
		var e := pick_weighted(table.get("entries", []), rng)
		if e.is_empty():
			continue
		var id := str(e["item"])
		out[id] = int(out.get(id, 0)) + rng.randi_range(int(e.get("min", 1)), int(e.get("max", 1)))
	return out

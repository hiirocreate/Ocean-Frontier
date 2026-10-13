class_name Raft
extends RefCounted
## 筏の床タイル（グリッド座標）と、その上の建築物を管理する。

signal changed

var tiles: Dictionary = {}  # "x,z" -> {"type": String, "durability": float}
var buildings: Dictionary = {}  # uid(String) -> {"id": String, "tile": "x,z", "durability": float}
var max_radius: int = 8
var tile_durability: float = 100.0


static func key(p: Vector2i) -> String:
	return "%d,%d" % [p.x, p.y]


static func parse_key(k: String) -> Vector2i:
	var parts := k.split(",")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return Vector2i(999999, 999999)
	return Vector2i(int(parts[0]), int(parts[1]))


func has_tile(p: Vector2i) -> bool:
	return tiles.has(key(p))


func tile_positions() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for k in tiles:
		out.append(parse_key(k))
	return out


func is_adjacent(p: Vector2i) -> bool:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if has_tile(p + d):
			return true
	return false


## 設置可能なら空文字、不可なら理由を返す。
func placement_problem(p: Vector2i) -> String:
	if has_tile(p):
		return "そこにはすでに床があります"
	if absi(p.x) > max_radius or absi(p.y) > max_radius:
		return "これ以上筏を広げられません（最大範囲）"
	if not tiles.is_empty() and not is_adjacent(p):
		return "既存の床に隣接していません"
	return ""


func candidate_positions() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var seen := {}
	for p in tile_positions():
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q: Vector2i = p + d
			var k := key(q)
			if seen.has(k):
				continue
			seen[k] = true
			if placement_problem(q) == "":
				out.append(q)
	return out


func add_tile(p: Vector2i, type: String = "raft_foundation") -> bool:
	if placement_problem(p) != "":
		return false
	tiles[key(p)] = {"type": type, "durability": tile_durability}
	changed.emit()
	return true


func has_building(building_id: String) -> bool:
	for uid in buildings:
		if buildings[uid]["id"] == building_id:
			return true
	return false


## グリッドの中心（ローカル座標、タイル単位）
func center() -> Vector2:
	if tiles.is_empty():
		return Vector2.ZERO
	var sum := Vector2.ZERO
	for p in tile_positions():
		sum += Vector2(p)
	return sum / tiles.size()


func to_dict() -> Dictionary:
	return {"tiles": tiles.duplicate(true), "buildings": buildings.duplicate(true)}


func from_dict(d: Dictionary) -> Array[String]:
	var w: Array[String] = []
	tiles.clear()
	buildings.clear()
	var t: Variant = d.get("tiles", {})
	if t is Dictionary:
		for k in t:
			var p := parse_key(str(k))
			if p.x == 999999 or not (t[k] is Dictionary):
				w.append("不正な床タイル '%s' を除外" % str(k))
				continue
			tiles[key(p)] = {
				"type": str(t[k].get("type", "raft_foundation")),
				"durability": clampf(float(t[k].get("durability", tile_durability)), 0.0, tile_durability),
			}
	if tiles.is_empty():
		w.append("床タイルが0枚のため初期タイルを復元")
		tiles[key(Vector2i.ZERO)] = {"type": "raft_foundation", "durability": tile_durability}
	var b: Variant = d.get("buildings", {})
	if b is Dictionary:
		for uid in b:
			if b[uid] is Dictionary and tiles.has(str(b[uid].get("tile", ""))):
				buildings[str(uid)] = b[uid].duplicate()
			else:
				w.append("床のない建築物 '%s' を除外" % str(uid))
	changed.emit()
	return w

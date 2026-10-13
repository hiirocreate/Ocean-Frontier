class_name RaftView
extends Node3D
## Raft（データ）の3D表示。床タイル・建築物・建設中の足場・建築モード時の候補（ゴースト）を描く。
## 物理レイヤー: 2=建設候補ゴースト, 4=建築物（タップで操作）

signal ghost_selected(tile: Vector2i)

const WOOD := [Color("8a5a33"), Color("9b6a3d"), Color("7c4f2c"), Color("a4743f")]
const ROPE := Color("c9b07a")
const NO_TILE := Vector2i(999999, 999999)

var session: GameSession
var tile_size := 2.0
var _tiles_root: Node3D
var _buildings_root: Node3D
var _ghost_root: Node3D
var _pending_root: Node3D
var build_mode := false
var build_type := "tile"  # "tile" または建築物ID
var selected_ghost := NO_TILE
var _signature := ""
var _check_timer := 0.0


func setup(s: GameSession) -> void:
	session = s
	tile_size = float(s.data.bal("raft.tile_size", 2.0))
	for n in ["_tiles_root", "_buildings_root", "_ghost_root", "_pending_root"]:
		var node := Node3D.new()
		node.name = n
		add_child(node)
		set(n, node)
	session.raft.changed.connect(rebuild)
	session.actions.job_started.connect(func(_j): _rebuild_pending(); _rebuild_ghosts())
	session.actions.job_completed.connect(func(_j, _r): _rebuild_pending(); _rebuild_ghosts())
	session.actions.job_cancelled.connect(func(_j, _l): _rebuild_pending(); _rebuild_ghosts())
	rebuild()


## タイル(0,0)をローカル原点とする（拡張しても既存タイルの位置は動かない）
func tile_to_local(p: Vector2i) -> Vector3:
	return Vector3(p.x * tile_size, 0, p.y * tile_size)


func center_local() -> Vector3:
	var c := session.raft.center()
	return Vector3(c.x * tile_size, 0, c.y * tile_size)


## 筏の中心から外周までのおおよその半径（回収範囲などに使用）
func radius() -> float:
	var r := 0.0
	var c := center_local()
	for p in session.raft.tile_positions():
		r = maxf(r, (tile_to_local(p) - c).length())
	return r + tile_size * 0.7


## 主人公が立つ位置（建築物のない、中心に最も近いタイル）
func stand_position() -> Vector3:
	var c := center_local()
	var best := c
	var best_d := INF
	for p in session.raft.tile_positions():
		if session.raft.building_at(p) != "":
			continue
		var d := (tile_to_local(p) - c).length()
		if d < best_d:
			best_d = d
			best = tile_to_local(p)
	return best


func rebuild() -> void:
	for c in _tiles_root.get_children():
		c.queue_free()
	for p in session.raft.tile_positions():
		_tiles_root.add_child(_make_tile(p))
	_rebuild_buildings()
	_rebuild_pending()
	_rebuild_ghosts()


func _process(delta: float) -> void:
	_check_timer += delta
	if _check_timer < 1.0 or session == null:
		return
	_check_timer = 0.0
	# 生産物の数が変わったら見た目を更新
	var sig := ""
	for uid in session.raft.buildings:
		sig += "%s:%d;" % [uid, int(session.raft.buildings[uid]["stored"])]
	if sig != _signature:
		_rebuild_buildings()


func _make_tile(p: Vector2i) -> Node3D:
	var n := Node3D.new()
	n.position = tile_to_local(p)
	var h := hash(Raft.key(p))
	var plank_w := tile_size / 4.0
	for i in 4:
		var c: Color = WOOD[(h + i) % WOOD.size()]
		var jitter := float((h >> i) % 7) * 0.01
		n.add_child(LowPoly.box(Vector3(plank_w * 0.92, 0.16, tile_size * (0.97 - jitter)), c,
			Vector3(-tile_size / 2 + plank_w * (i + 0.5), 0.0, 0)))
	for z in [-0.6, 0.6]:
		n.add_child(LowPoly.cylinder(0.18, tile_size * 0.95, Color("6b4426"), Vector3(0, -0.2, z * tile_size * 0.5), 6, Vector3(0, 0, 90)))
	n.add_child(LowPoly.box(Vector3(tile_size * 0.98, 0.04, 0.08), ROPE, Vector3(0, 0.09, -tile_size * 0.36)))
	n.add_child(LowPoly.box(Vector3(tile_size * 0.98, 0.04, 0.08), ROPE, Vector3(0, 0.09, tile_size * 0.36)))
	return n


func _rebuild_buildings() -> void:
	for c in _buildings_root.get_children():
		c.queue_free()
	_signature = ""
	for uid in session.raft.buildings:
		var b: Dictionary = session.raft.buildings[uid]
		_signature += "%s:%d;" % [uid, int(b["stored"])]
		var body := StaticBody3D.new()
		body.collision_layer = 4
		body.set_meta("building_uid", uid)
		body.position = tile_to_local(Raft.parse_key(b["tile"]))
		var shape := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(tile_size * 0.9, 1.2, tile_size * 0.9)
		shape.shape = bs
		shape.position.y = 0.6
		body.add_child(shape)
		body.add_child(BuildingModels.make(b["id"], int(b["stored"])))
		_buildings_root.add_child(body)


func _rebuild_pending() -> void:
	if session == null:
		return
	for c in _pending_root.get_children():
		c.queue_free()
	for p in session.pending_tiles():
		var n := _scaffold()
		n.position = tile_to_local(p)
		n.add_child(LowPoly.box(Vector3(tile_size * 0.9, 0.12, tile_size * 0.9), Color(0.75, 0.55, 0.3, 0.55), Vector3(0, -0.02, 0)))
		_pending_root.add_child(n)
	for pb in session.pending_buildings():
		var n := _scaffold()
		n.position = tile_to_local(pb["tile"])
		_pending_root.add_child(n)


func _scaffold() -> Node3D:
	var n := Node3D.new()
	for x in [-1, 1]:
		for z in [-1, 1]:
			n.add_child(LowPoly.cylinder(0.05, 1.1, Color("6b4426"), Vector3(x * tile_size * 0.4, 0.55, z * tile_size * 0.4), 5))
	n.add_child(LowPoly.box(Vector3(tile_size * 0.85, 0.05, 0.05), Color("6b4426"), Vector3(0, 1.0, tile_size * 0.4)))
	n.add_child(LowPoly.box(Vector3(tile_size * 0.85, 0.05, 0.05), Color("6b4426"), Vector3(0, 1.0, -tile_size * 0.4)))
	return n


func set_build_mode(on: bool, type: String = "tile") -> void:
	build_mode = on
	build_type = type
	selected_ghost = NO_TILE
	_rebuild_ghosts()


func select_ghost(p: Vector2i) -> void:
	selected_ghost = p
	_rebuild_ghosts()
	ghost_selected.emit(p)


func _rebuild_ghosts() -> void:
	if _ghost_root == null:
		return
	for c in _ghost_root.get_children():
		c.queue_free()
	if not build_mode:
		return
	var candidates: Array[Vector2i] = []
	var blocked: Array = []
	if build_type == "tile":
		candidates = session.raft.candidate_positions()
		blocked = session.pending_tiles()
	else:
		candidates = session.raft.building_candidates()
		blocked = session.pending_buildings().map(func(pb): return pb["tile"])
	var y := 0.12 if build_type == "tile" else 0.2
	for p in candidates:
		if p in blocked:
			continue
		var sel := p == selected_ghost
		var body := StaticBody3D.new()
		body.position = tile_to_local(p)
		body.set_meta("tile", p)
		body.collision_layer = 2
		var shape := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(tile_size, 0.8, tile_size)
		shape.shape = bs
		body.add_child(shape)
		var col := Color(0.95, 0.75, 0.3, 0.75) if sel else Color(0.4, 0.95, 0.75, 0.38)
		body.add_child(LowPoly.box(Vector3(tile_size * 0.94, 0.1, tile_size * 0.94), col, Vector3(0, y, 0)))
		if sel and build_type != "tile":
			var preview := BuildingModels.make(build_type)
			preview.position.y = 0.05
			body.add_child(preview)
		_ghost_root.add_child(body)

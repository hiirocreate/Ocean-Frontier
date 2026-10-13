extends Node3D
## 3D探索シーン。海・空・光・筏・主人公・漂流物・カメラ・HUDを構築し、入力を GameSession に橋渡しする。

const DAY_SKY_TOP := Color("3f8fc9")
const DAY_HORIZON := Color("a9d8e6")
const NIGHT_SKY_TOP := Color("0a1626")
const NIGHT_HORIZON := Color("1d3446")
const SUNSET := Color("f0a060")

var session: GameSession
var raft_root: Node3D
var raft_view: RaftView
var player: CharacterModel
var camera_rig: CameraRig
var hud: Hud
var ocean: MeshInstance3D
var ocean_mat: ShaderMaterial
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var lantern: OmniLight3D
var env: Environment
var sky_mat: ProceduralSkyMaterial
var debris_root: Node3D
var wave_amp := 0.45
var _time := 0.0
var _velocity := Vector3.ZERO
var _nearest: Debris
var _autosave_timer := 0.0
var _zone: Dictionary


func _ready() -> void:
	if Game.session == null:
		# 直接このシーンを起動した場合（開発用）
		Game.session = GameSession.new(Game.data)
		Game.session.new_game()
	session = Game.session
	_zone = session.data.zones.get(session.zone_id, {})
	_build_environment()
	_build_ocean()
	_build_raft()
	debris_root = Node3D.new()
	add_child(debris_root)
	camera_rig = CameraRig.new()
	add_child(camera_rig)
	camera_rig.target = raft_root
	camera_rig.global_position = raft_root.global_position
	hud = Hud.new()
	add_child(hud)
	hud.setup(session)
	camera_rig.ui_blocker = hud.is_point_on_ui
	camera_rig.tapped.connect(_on_tap)
	hud.collect_pressed.connect(collect_nearest)
	hud.build_mode_changed.connect(func(on, t): raft_view.set_build_mode(on, t))
	hud.build_confirmed.connect(_on_build_confirmed)
	raft_view.ghost_selected.connect(func(t): hud.select_build_tile(t))
	Game.settings_changed.connect(_apply_quality)
	_apply_quality()
	Game.running = true
	_fill_debris(true)
	GameLog.info("ワールド開始: %s" % session.clock.label())


func _exit_tree() -> void:
	Game.running = false


# ---------- 構築 ----------
func _build_environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = DAY_SKY_TOP
	sky_mat.sky_horizon_color = DAY_HORIZON
	sky_mat.ground_horizon_color = DAY_HORIZON
	sky_mat.ground_bottom_color = Color(_zone.get("ocean_deep_color", "#0b4f78"))
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("7fa6b8")
	env.ambient_light_energy = 0.5
	# Compatibility レンダラーでは Filmic + 空の反射で白飛びしたため、線形トーンマップ・反射無効にし
	# 海面のフレネルはシェーダー側で表現する（docs/DECISIONS.md D-008）
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.fog_enabled = true
	env.fog_light_color = Color(_zone.get("fog_color", "#a9d8e6"))
	env.fog_light_energy = 0.8
	env.fog_density = 0.0035
	env.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)
	moon = DirectionalLight3D.new()
	moon.light_color = Color("9db8e8")
	moon.rotation = Vector3(deg_to_rad(-50.0), deg_to_rad(140.0), 0)
	add_child(moon)


func _build_ocean() -> void:
	ocean = MeshInstance3D.new()
	ocean_mat = ShaderMaterial.new()
	ocean_mat.shader = load("res://scripts/world/ocean.gdshader")
	ocean_mat.set_shader_parameter("shallow_color", Color(_zone.get("ocean_shallow_color", "#1fb3b0")))
	ocean_mat.set_shader_parameter("deep_color", Color(_zone.get("ocean_deep_color", "#0b4f78")))
	ocean_mat.set_shader_parameter("wave_height", wave_amp)
	ocean_mat.set_shader_parameter("horizon_color", Color(_zone.get("fog_color", "#a9d8e6")))
	ocean.material_override = ocean_mat
	add_child(ocean)
	# 遠景用の平らな大きい海（地平線まで）
	var far := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(1200, 1200)
	far.mesh = pm
	far.position.y = -0.6
	far.material_override = LowPoly.mat(Color(_zone.get("ocean_deep_color", "#0b4f78")), 0.4)
	far.name = "FarOcean"
	ocean.add_child(far)


func _set_ocean_mesh(subdiv: int) -> void:
	var m := PlaneMesh.new()
	m.size = Vector2(240, 240)
	m.subdivide_width = subdiv
	m.subdivide_depth = subdiv
	ocean.mesh = m


func _build_raft() -> void:
	raft_root = Node3D.new()
	raft_root.position = session.raft_position
	raft_root.rotation.y = session.raft_rotation
	add_child(raft_root)
	raft_view = RaftView.new()
	raft_root.add_child(raft_view)
	raft_view.setup(session)
	player = CharacterModel.new()
	raft_root.add_child(player)
	player.position = raft_view.stand_position() + Vector3(0, 0.08, 0)
	session.raft.changed.connect(func(): player.position = raft_view.stand_position() + Vector3(0, 0.08, 0))
	# 帆柱（筏の目印）
	var mast := Node3D.new()
	mast.add_child(LowPoly.cylinder(0.07, 3.2, Color("6b4426"), Vector3(0, 1.6, 0), 6))
	mast.add_child(LowPoly.box(Vector3(0.04, 1.6, 1.3), Color("e6d8b8"), Vector3(0, 2.2, 0.65)))
	# 夜に灯るランタン（安全な拠点＝暖色の光。ART_GUIDE参照）
	mast.add_child(LowPoly.box(Vector3(0.18, 0.24, 0.18), Color("3a2a1c"), Vector3(0.12, 1.5, 0)))
	mast.add_child(LowPoly.sphere(0.08, Color("ffcf7a"), Vector3(0.12, 1.5, 0), 6))
	lantern = OmniLight3D.new()
	lantern.light_color = Color("ffb35c")
	lantern.omni_range = 7.0
	lantern.position = Vector3(0.12, 1.5, 0)
	mast.add_child(lantern)
	mast.position = raft_view.tile_to_local(Vector2i(0, 0)) + Vector3(-0.6, 0, -0.6)
	raft_root.add_child(mast)


func _apply_quality() -> void:
	var q := Game.quality_preset()
	sun.shadow_enabled = q["shadows"]
	_set_ocean_mesh(int(q["ocean_subdiv"]))
	get_viewport().scaling_3d_scale = float(q["render_scale"])


# ---------- 毎フレーム ----------
func _process(delta: float) -> void:
	_time += delta
	ocean_mat.set_shader_parameter("time_sec", _time)
	_update_movement(delta)
	_update_lighting()
	_update_debris(delta)
	_autosave_timer += delta
	if _autosave_timer > 120.0:
		_autosave_timer = 0.0
		SaveManager.save_session(session)


func _input_vector() -> Vector2:
	if hud.is_modal_open() or session.is_sleeping():
		return Vector2.ZERO
	var v := hud.joystick.value
	if v == Vector2.ZERO:
		v = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	return v


func _update_movement(delta: float) -> void:
	var input := _input_vector()
	var tiles := session.raft.tiles.size()
	var speed := float(session.data.bal("raft.base_speed", 4.0))
	speed *= maxf(float(session.data.bal("raft.min_speed_ratio", 0.4)), 1.0 - float(session.data.bal("raft.speed_penalty_per_tile", 0.02)) * (tiles - 1))
	speed *= session.survival.efficiency()
	var desired := camera_rig.to_world_dir(input) * speed
	_velocity = _velocity.lerp(desired, minf(1.0, delta * 2.0))
	raft_root.position += _velocity * delta
	var c := raft_root.position
	raft_root.position.y = OceanWaves.height(c.x, c.z, _time, wave_amp) * 0.6 - 0.05
	raft_root.rotation.x = (OceanWaves.height(c.x, c.z + 2.0, _time, wave_amp) - OceanWaves.height(c.x, c.z - 2.0, _time, wave_amp)) * 0.06
	raft_root.rotation.z = -(OceanWaves.height(c.x + 2.0, c.z, _time, wave_amp) - OceanWaves.height(c.x - 2.0, c.z, _time, wave_amp)) * 0.06
	player.moving = input.length() > 0.1
	if player.moving:
		var target_yaw := atan2(_velocity.x, _velocity.z) - raft_root.rotation.y
		player.rotation.y = lerp_angle(player.rotation.y, target_yaw, minf(1.0, delta * 8.0))
	session.raft_position = Vector3(raft_root.position.x, 0, raft_root.position.z)
	session.raft_rotation = raft_root.rotation.y
	# 海面メッシュは筏に追従（波はワールド座標で計算されるので継ぎ目は出ない）
	ocean.position = Vector3(snappedf(c.x, 4.0), 0, snappedf(c.z, 4.0))


func _update_lighting() -> void:
	var tod := session.clock.time_of_day()
	# 6時に日の出、18時に日没
	var sun_angle := (tod - 0.25) * TAU
	sun.rotation = Vector3(-sin(sun_angle) * PI * 0.45 - 0.08, deg_to_rad(-35.0), 0)
	var daylight := clampf(sin(sun_angle) * 1.6 + 0.25, 0.0, 1.0)
	var dusk := clampf(1.0 - absf(sin(sun_angle)) * 3.0, 0.0, 1.0)
	sun.light_energy = lerpf(0.0, 0.95, daylight)
	sun.visible = daylight > 0.01
	moon.light_energy = (1.0 - daylight) * 0.35
	moon.visible = daylight < 0.99
	lantern.light_energy = (1.0 - daylight) * 1.6
	sun.light_color = Color.WHITE.lerp(SUNSET, dusk * 0.8)
	sky_mat.sky_top_color = NIGHT_SKY_TOP.lerp(DAY_SKY_TOP, daylight)
	sky_mat.sky_top_color = sky_mat.sky_top_color.lerp(Color("6a5a8a"), dusk * 0.4)
	var horizon := NIGHT_HORIZON.lerp(Color(_zone.get("fog_color", "#a9d8e6")), daylight).lerp(SUNSET, dusk * 0.5)
	sky_mat.sky_horizon_color = horizon
	sky_mat.ground_horizon_color = horizon
	env.fog_light_color = horizon
	ocean_mat.set_shader_parameter("horizon_color", horizon)
	env.ambient_light_color = Color("3a5070").lerp(Color("8fb4c4"), daylight)
	env.ambient_light_energy = lerpf(0.45, 0.55, daylight)


# ---------- 漂流物 ----------
func _fill_debris(initial: bool) -> void:
	var target := int(float(session.data.bal("world.debris_target_count", 14)) * float(Game.quality_preset()["debris_mult"]))
	var rmin := float(session.data.bal("world.debris_spawn_radius_min", 18.0))
	var rmax := float(session.data.bal("world.debris_spawn_radius_max", 55.0))
	var guard := 0
	while debris_root.get_child_count() < target and guard < 50:
		guard += 1
		var kind := str(LootRoller.pick_weighted(_zone.get("debris_kinds", []), _visual_rng()).get("kind", "plank"))
		var d := Debris.new()
		var ang := randf() * TAU
		var dist := randf_range(6.0 if initial else rmin, rmax)
		var cur := Vector3(1, 0, 0.4).normalized() * float(session.data.bal("world.current_speed", 0.6))
		d.setup(kind, randf() * TAU, cur + Vector3(randf_range(-0.2, 0.2), 0, randf_range(-0.2, 0.2)))
		debris_root.add_child(d)
		d.position = raft_root.position + Vector3(cos(ang), 0, sin(ang)) * dist


## 見た目だけの抽選（漂流物の種類）。中身の抽選はセッションのRNGで行う。
var _vrng := RandomNumberGenerator.new()
func _visual_rng() -> RandomNumberGenerator:
	return _vrng


func _update_debris(delta: float) -> void:
	var despawn := float(session.data.bal("world.debris_despawn_radius", 75.0))
	var reach := raft_view.radius() + float(session.data.bal("world.collect_range", 4.0))
	var center := raft_root.to_global(raft_view.center_local())
	_nearest = null
	var best := INF
	for d in debris_root.get_children():
		var deb := d as Debris
		deb.update_float(_time, wave_amp, delta)
		if deb.collected:
			continue
		var dist := Vector2(deb.position.x - center.x, deb.position.z - center.z).length()
		if dist > despawn:
			deb.queue_free()
		elif dist < reach and dist < best:
			best = dist
			_nearest = deb
	if debris_root.get_child_count() < int(session.data.bal("world.debris_target_count", 14)) * 0.7:
		_fill_debris(false)
	hud.set_collect_available(_nearest != null, "回収（%s）" % _kind_name(_nearest.kind) if _nearest else "回収")


func _kind_name(kind: String) -> String:
	return {"plank": "木材の束", "barrel": "樽", "crate": "木箱"}.get(kind, kind)


func collect_nearest() -> void:
	if _nearest == null or _nearest.collected:
		hud.show_toast("近くに回収できる漂流物がありません", UiTheme.C_WARN)
		return
	session.collect_debris(_nearest.kind)
	_nearest.fly_to(player)
	_nearest = null


# ---------- 建築 ----------
func _on_tap(screen_pos: Vector2) -> void:
	var cam := camera_rig.camera
	var from := cam.project_ray_origin(screen_pos)
	var mask := 2 if raft_view.build_mode else 4
	var q := PhysicsRayQueryParameters3D.create(from, from + cam.project_ray_normal(screen_pos) * 200.0, mask)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		if not raft_view.build_mode:
			hud.hide_building_panel()
		return
	if raft_view.build_mode and hit["collider"].has_meta("tile"):
		raft_view.select_ghost(hit["collider"].get_meta("tile"))
	elif hit["collider"].has_meta("building_uid"):
		hud.show_building_panel(hit["collider"].get_meta("building_uid"))


func _on_build_confirmed(action_id: String, params: Dictionary) -> void:
	var r := session.actions.start(action_id, params)
	if r["ok"]:
		hud.show_toast("「%s」を開始しました" % session.data.action(action_id).get("name", ""), UiTheme.C_OK)
		raft_view.select_ghost(RaftView.NO_TILE)
	else:
		hud.show_toast(str(r["problems"][0]["message"]), UiTheme.C_WARN)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("collect"):
		collect_nearest()
	elif event.is_action_pressed("build_mode"):
		hud.set_build_mode(not hud.build_mode)
	elif event.is_action_pressed("inventory"):
		hud.toggle_inventory()
	elif event.is_action_pressed("menu"):
		hud.toggle_menu()

extends Node
## オートロード "Game"。データ・現在のセッション・設定・シーン遷移を保持する。
## ゲームロジックは GameSession 側にあり、ここは薄い窓口に留める。

signal session_changed
signal message(text: String)
signal settings_changed

const SETTINGS_PATH := "user://settings.cfg"
const MAIN_MENU := "res://scenes/main/main_menu.tscn"
const WORLD := "res://scenes/world/world.tscn"

var data: GameData
var session: GameSession
var running: bool = false  # 3Dワールド表示中のみ時間を進める
var settings := {"quality": "medium", "master_volume": 1.0}
var data_errors: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	data = GameData.load_default()
	data_errors = DataValidator.validate(data)
	for e in data_errors:
		GameLog.error("データ検証: " + e)
	load_settings()
	get_tree().set_auto_accept_quit(false)
	GameLog.info("起動 v%s / データ問題 %d件" % [ProjectSettings.get_setting("application/config/version"), data_errors.size()])


func _setup_input() -> void:
	var keys := {
		"move_forward": [KEY_W, KEY_UP], "move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"collect": [KEY_E, KEY_SPACE], "build_mode": [KEY_B], "inventory": [KEY_I, KEY_TAB], "crew": [KEY_C],
		"menu": [KEY_ESCAPE],
	}
	for action in keys:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for k in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)


func _process(delta: float) -> void:
	if running and session and not get_tree().paused:
		var rate := float(data.bal("time.game_minutes_per_real_second", 1.0))
		if session.is_sleeping():
			rate *= float(data.bal("time.sleep_speed_multiplier", 40.0))
		session.advance(delta * rate)


func start_new_game() -> void:
	_set_session(GameSession.new(data))
	session.new_game()
	session.message.emit("目が覚めると、小さな筏の上だった。何も思い出せない……")
	get_tree().change_scene_to_file(WORLD)


func continue_game() -> Dictionary:
	var r := SaveManager.load_session(data)
	if r["ok"]:
		_set_session(r["session"])
		get_tree().change_scene_to_file(WORLD)
		if r["recovered_from_backup"]:
			session.message.emit("セーブデータが破損していたため、バックアップから復旧しました")
	return r


func save_game() -> Dictionary:
	if session == null:
		return {"ok": false, "error": "セッションがありません"}
	var r := SaveManager.save_session(session)
	message.emit("セーブしました" if r["ok"] else "セーブに失敗しました: " + str(r["error"]))
	return r


func load_game() -> Dictionary:
	var r := SaveManager.load_session(data)
	if r["ok"]:
		_set_session(r["session"])
		get_tree().reload_current_scene()
	else:
		message.emit("ロードに失敗しました: " + str(r["error"]))
	return r


func return_to_menu() -> void:
	running = false
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU)


func _set_session(s: GameSession) -> void:
	session = s
	session.message.connect(func(t): message.emit(t))
	session_changed.emit()


# ---- 設定（画質など） ----
func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		for k in settings:
			settings[k] = cfg.get_value("settings", k, settings[k])
	if not (settings["quality"] in ["low", "medium", "high"]):
		settings["quality"] = "medium"


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for k in settings:
		cfg.set_value("settings", k, settings[k])
	cfg.save(SETTINGS_PATH)


func quality_changed() -> void:
	settings_changed.emit()


## 画質プリセット。world.gd が参照して描画設定を切り替える。
func quality_preset() -> Dictionary:
	match settings["quality"]:
		"low":
			return {"shadows": false, "ocean_subdiv": 40, "render_scale": 0.75, "fog": true, "debris_mult": 0.7}
		"high":
			return {"shadows": true, "ocean_subdiv": 80, "render_scale": 1.0, "fog": true, "debris_mult": 1.2}
		_:
			return {"shadows": true, "ocean_subdiv": 64, "render_scale": 1.0, "fog": true, "debris_mult": 1.0}


## Android でのバックグラウンド移行・終了時に自動セーブする。
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			if running and session:
				SaveManager.save_session(session)
		NOTIFICATION_WM_CLOSE_REQUEST:
			if running and session:
				SaveManager.save_session(session)
			get_tree().quit()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			if running:
				message.emit("__toggle_menu__")

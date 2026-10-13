class_name CameraRig
extends Node3D
## 対象を中心に回る三人称カメラ。画面ドラッグで回転、ピンチ/ホイールでズーム。
## 短いタップは tapped シグナルで通知（建築モードの位置選択に使用）。

signal tapped(screen_pos: Vector2)

var target: Node3D
var yaw := deg_to_rad(35.0)
var pitch := deg_to_rad(-32.0)
var distance := 14.0
var min_distance := 6.0
var max_distance := 40.0
var camera: Camera3D
## UI上の点なら true を返す関数（UI操作中にカメラが動かないように）
var ui_blocker: Callable
var _touches := {}  # index -> {"pos": Vector2, "start": Vector2, "time": int}
var _pinch_start := 0.0
var _dist_start := 0.0


func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = 60.0
	camera.far = 600.0
	add_child(camera)


func _process(delta: float) -> void:
	if target:
		global_position = global_position.lerp(target.global_position, minf(1.0, delta * 6.0))
	var off := Vector3(0, 0, distance).rotated(Vector3.RIGHT, pitch).rotated(Vector3.UP, yaw)
	camera.position = off + Vector3(0, 1.0, 0)
	camera.look_at(global_position + Vector3(0, 1.0, 0), Vector3.UP)


## 移動入力をカメラ基準のワールド方向に変換する
func to_world_dir(input: Vector2) -> Vector3:
	return Vector3(input.x, 0, input.y).rotated(Vector3.UP, yaw)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if ui_blocker.is_valid() and ui_blocker.call(event.position):
				return
			_touches[event.index] = {"pos": event.position, "start": event.position, "time": Time.get_ticks_msec()}
			if _touches.size() == 2:
				_pinch_start = _pinch_len()
				_dist_start = distance
		else:
			var t: Dictionary = _touches.get(event.index, {})
			_touches.erase(event.index)
			if not t.is_empty() and _touches.is_empty():
				if (event.position - t["start"]).length() < 18.0 and Time.get_ticks_msec() - int(t["time"]) < 350:
					tapped.emit(event.position)
	elif event is InputEventScreenDrag and _touches.has(event.index):
		_touches[event.index]["pos"] = event.position
		if _touches.size() >= 2:
			if _pinch_start > 1.0:
				distance = clampf(_dist_start * _pinch_start / maxf(1.0, _pinch_len()), min_distance, max_distance)
		else:
			yaw -= event.relative.x * 0.006
			pitch = clampf(pitch - event.relative.y * 0.004, deg_to_rad(-75.0), deg_to_rad(-8.0))
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = maxf(min_distance, distance * 0.9)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = minf(max_distance, distance * 1.1)


func _pinch_len() -> float:
	var pts: Array = _touches.values()
	if pts.size() < 2:
		return 0.0
	return (pts[0]["pos"] as Vector2).distance_to(pts[1]["pos"])

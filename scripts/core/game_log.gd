class_name GameLog
extends RefCounted
## ゲーム全体のログ。メモリ上のリングバッファと user://logs/game.log に記録する。

const LOG_PATH := "user://logs/game.log"
const MAX_LINES := 300

static var lines: Array[String] = []
static var file_logging := true


static func info(msg: String) -> void:
	_write("INFO", msg)


static func warn(msg: String) -> void:
	_write("WARN", msg)
	push_warning(msg)


static func error(msg: String) -> void:
	_write("ERROR", msg)
	push_error(msg)


static func _write(level: String, msg: String) -> void:
	var line := "[%s] %s %s" % [Time.get_datetime_string_from_system(), level, msg]
	lines.append(line)
	if lines.size() > MAX_LINES:
		lines.remove_at(0)
	if level == "INFO":
		print(line)
	if not file_logging:
		return
	DirAccess.make_dir_recursive_absolute("user://logs")
	var mode := FileAccess.READ_WRITE if FileAccess.file_exists(LOG_PATH) else FileAccess.WRITE
	var f := FileAccess.open(LOG_PATH, mode)
	if f:
		f.seek_end()
		f.store_line(line)

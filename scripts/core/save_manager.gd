class_name SaveManager
extends RefCounted
## ローカルセーブ。
## ファイル形式: {"format": 1, "game_version": "...", "saved_at": unix, "checksum": md5(payload), "payload": "<session JSON文字列>"}
## 書き込み手順: .tmp に書く → 読み戻して検証 → 既存を .bak に退避 → .tmp を本ファイルに置換（異常終了時の破損防止）。
## 読み込み時に本ファイルが壊れていれば .bak から復旧する。

const DEFAULT_PATH := "user://saves/slot1.json"


static func save_session(session: GameSession, path: String = DEFAULT_PATH) -> Dictionary:
	var payload := JSON.stringify(session.to_dict())
	var doc := {
		"format": GameSession.SAVE_FORMAT_VERSION,
		"game_version": str(ProjectSettings.get_setting("application/config/version", "0.0.0")),
		"saved_at": int(Time.get_unix_time_from_system()),
		"checksum": payload.md5_text(),
		"payload": payload,
	}
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return _fail("一時ファイルを開けません: %s (%s)" % [tmp, error_string(FileAccess.get_open_error())])
	f.store_string(JSON.stringify(doc))
	f.close()
	var verify := _read_doc(tmp)
	if not verify["ok"]:
		return _fail("書き込み検証に失敗: " + verify["error"])
	var abs_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(abs_path + ".bak")
		DirAccess.rename_absolute(abs_path, abs_path + ".bak")
	var err := DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), abs_path)
	if err != OK:
		return _fail("セーブファイルの置換に失敗: %s" % error_string(err))
	GameLog.info("セーブ完了: %s" % path)
	return {"ok": true, "error": ""}


static func _fail(msg: String) -> Dictionary:
	GameLog.error("セーブ失敗: " + msg)
	return {"ok": false, "error": msg}


static func has_save(path: String = DEFAULT_PATH) -> bool:
	return FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak")


## ファイルを読み、形式とチェックサムを検証して session 辞書を返す。
static func _read_doc(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "ファイルがありません: " + path}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return {"ok": false, "error": "JSON解析エラー (%d行): %s" % [json.get_error_line(), json.get_error_message()]}
	var doc: Variant = json.data
	if not (doc is Dictionary) or not (doc.get("payload") is String):
		return {"ok": false, "error": "セーブ形式が不正です"}
	var fmt := int(doc.get("format", 0))
	if fmt <= 0 or fmt > GameSession.SAVE_FORMAT_VERSION:
		return {"ok": false, "error": "対応していないセーブ形式バージョン: %d" % fmt}
	var payload: String = doc["payload"]
	if payload.md5_text() != str(doc.get("checksum", "")):
		return {"ok": false, "error": "チェックサム不一致（データ破損）"}
	var pj := JSON.new()
	if pj.parse(payload) != OK or not (pj.data is Dictionary):
		return {"ok": false, "error": "本体データの解析に失敗"}
	return {"ok": true, "error": "", "session": pj.data, "format": fmt}


## セッションを読み込む。戻り値 {"ok", "session", "error", "warnings", "recovered_from_backup"}
static func load_session(data: GameData, path: String = DEFAULT_PATH) -> Dictionary:
	var result := _try_load(data, path)
	if result["ok"]:
		return result
	GameLog.error("ロード失敗 (%s): %s" % [path, result["error"]])
	var bak := _try_load(data, path + ".bak")
	if bak["ok"]:
		GameLog.warn("バックアップから復旧しました: %s.bak" % path)
		bak["recovered_from_backup"] = true
		bak["error"] = result["error"]
		return bak
	return result


static func _try_load(data: GameData, path: String) -> Dictionary:
	var out := {"ok": false, "session": null, "error": "", "warnings": [], "recovered_from_backup": false}
	var doc := _read_doc(path)
	if not doc["ok"]:
		out["error"] = doc["error"]
		return out
	var s := GameSession.new(data)
	var r := s.from_dict(doc["session"])
	if not r["errors"].is_empty():
		out["error"] = "; ".join(r["errors"])
		return out
	for w in r["warnings"]:
		GameLog.warn("ロード補正: " + w)
	out["ok"] = true
	out["session"] = s
	out["warnings"] = r["warnings"]
	return out


static func delete_save(path: String = DEFAULT_PATH) -> void:
	for p in [path, path + ".bak", path + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

class_name UpdateChecker
extends Node
## 新しいビルドの確認。GitHub Releases の「debug-latest」に置いた version.json を読み、
## 手元のビルド番号（build_info.json）より新しければ update_available を送る。
## 通信できない・タイムアウト・手元でのビルド（番号 0）のときは何もしない（ゲームはオフラインのまま遊べる）。

signal update_available(info: Dictionary)

const VERSION_URL := "https://github.com/hiirocreate/Ocean-Frontier/releases/download/debug-latest/version.json"
const APK_URL := "https://github.com/hiirocreate/Ocean-Frontier/releases/download/debug-latest/ocean_frontier_debug.apk"
const BUILD_INFO := "res://build_info.json"

var _http: HTTPRequest


## このアプリのビルド番号（GitHub Actions の実行番号。手元でのビルドは 0）
static func local_build() -> int:
	var f := FileAccess.open(BUILD_INFO, FileAccess.READ)
	if f == null:
		return 0
	var d: Variant = JSON.parse_string(f.get_as_text())
	return int(d.get("build", 0)) if d is Dictionary else 0


## version.json の内容と手元のビルド番号から、更新を案内すべきか判定する（不正な内容なら空）
static func newer_info(remote: Variant, local: int) -> Dictionary:
	if not (remote is Dictionary) or local <= 0:
		return {}
	var build := int(remote.get("build", 0))
	if build <= local:
		return {}
	var url := str(remote.get("apk_url", APK_URL))
	if not url.begins_with("https://github.com/hiirocreate/Ocean-Frontier/"):
		url = APK_URL  # 想定外の場所へは案内しない
	return {"build": build, "notes": str(remote.get("notes", "")), "apk_url": url}


func check() -> void:
	var local := local_build()
	if local <= 0:
		return
	_http = HTTPRequest.new()
	_http.timeout = 6.0
	_http.max_redirects = 8
	add_child(_http)
	_http.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, body: PackedByteArray):
		_http.queue_free()
		if result != HTTPRequest.RESULT_SUCCESS or code != 200:
			return
		var info := newer_info(JSON.parse_string(body.get_string_from_utf8()), local)
		if not info.is_empty():
			update_available.emit(info))
	if _http.request(VERSION_URL) != OK:
		_http.queue_free()

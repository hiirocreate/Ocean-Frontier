extends SceneTree
## データ検証ツール: godot --headless --path . --script res://tools/validate_data.gd

func _initialize() -> void:
	GameLog.file_logging = false
	var d := GameData.load_default()
	var errors := DataValidator.validate(d)
	print("アイテム %d / 行動 %d / 建築 %d / 海域 %d" % [d.items.size(), d.actions.size(), d.buildings.size(), d.zones.size()])
	if errors.is_empty():
		print("データ検証: OK")
		quit(0)
		return
	for e in errors:
		print("  ✗ ", e)
	print("データ検証: %d件の問題" % errors.size())
	quit(1)

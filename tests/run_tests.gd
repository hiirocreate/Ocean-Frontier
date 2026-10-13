extends SceneTree
## テストランナー: godot --headless --path . --script res://tests/run_tests.gd
## tests/unit/test_*.gd の test_* メソッドをすべて実行する。失敗時は終了コード1。

func _initialize() -> void:
	GameLog.file_logging = false
	var total := 0
	var failed: Array[String] = []
	var files := Array(DirAccess.get_files_at("res://tests/unit"))
	files.sort()
	for f in files:
		if not (f.begins_with("test_") and f.ends_with(".gd")):
			continue
		var script: Variant = load("res://tests/unit/" + f)
		if script == null or not script.can_instantiate():
			failed.append("%s: 読み込み失敗" % f)
			continue
		for m in script.get_script_method_list():
			var name: String = m["name"]
			if not name.begins_with("test_"):
				continue
			var tc: TestCase = script.new()
			tc.current_test = "%s::%s" % [f.get_basename(), name]
			tc.before_each()
			tc.call(name)
			total += 1
			if tc.assertions == 0:
				tc.failures.append("%s: アサーションが実行されていません（実行時エラーの可能性）" % tc.current_test)
			if tc.failures.is_empty():
				print("  PASS ", tc.current_test)
			else:
				print("  FAIL ", tc.current_test)
				failed.append_array(tc.failures)
	print("")
	print("==== テスト結果: %d件中 %d件失敗 ====" % [total, _count_tests(failed)])
	for msg in failed:
		print("  ✗ ", msg)
	quit(1 if not failed.is_empty() or total == 0 else 0)


func _count_tests(failed: Array[String]) -> int:
	var names := {}
	for f in failed:
		names[f.split(": ")[0]] = true
	return names.size()

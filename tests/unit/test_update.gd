extends TestCase
## 更新の確認（ビルド番号の比較とダウンロード先の検証）


func test_newer_build_is_reported() -> void:
	var info := UpdateChecker.newer_info({"build": 12, "notes": "修正", "apk_url": UpdateChecker.APK_URL}, 10)
	eq(int(info.get("build", 0)), 12, "新しいビルド番号")
	eq(str(info.get("apk_url", "")), UpdateChecker.APK_URL, "ダウンロード先")


func test_same_or_older_build_is_ignored() -> void:
	check(UpdateChecker.newer_info({"build": 10}, 10).is_empty(), "同じ番号は案内しない")
	check(UpdateChecker.newer_info({"build": 9}, 10).is_empty(), "古い番号は案内しない")


func test_local_dev_build_and_bad_data_are_ignored() -> void:
	check(UpdateChecker.newer_info({"build": 99}, 0).is_empty(), "手元のビルド（0）は確認しない")
	check(UpdateChecker.newer_info(null, 5).is_empty(), "壊れた応答は無視")
	check(UpdateChecker.newer_info("not json", 5).is_empty(), "文字列の応答は無視")


func test_unexpected_download_url_is_replaced() -> void:
	var info := UpdateChecker.newer_info({"build": 8, "apk_url": "https://example.com/evil.apk"}, 5)
	eq(str(info["apk_url"]), UpdateChecker.APK_URL, "想定外の場所へは案内しない")

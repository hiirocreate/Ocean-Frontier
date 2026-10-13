extends TestCase

var inv: Inventory


func before_each() -> void:
	inv = Inventory.new(game_data(), 20.0)


func test_add_stackable() -> void:
	check(inv.add("wood", 3), "木材を追加できる")
	eq(inv.count("wood"), 3, "木材数")
	inv.add("wood", 2)
	eq(inv.count("wood"), 5, "加算")


func test_unknown_item_rejected() -> void:
	check(not inv.add("no_such_item", 1), "未知IDは拒否")
	eq(inv.stacks.size(), 0, "何も追加されない")


func test_capacity_limit() -> void:
	check(inv.add("wood", 20), "20kgちょうど入る")
	check(not inv.add("wood", 1), "容量超過は拒否")
	eq(inv.count("wood"), 20, "数量は変わらない")


func test_add_many_is_atomic() -> void:
	check(not inv.add_many({"wood": 10, "scrap_metal": 10}), "合計25kgは拒否")
	eq(inv.count("wood"), 0, "一部だけ追加されない")


func test_non_stackable_instances() -> void:
	inv.add("hammer", 2)
	eq(inv.count("hammer"), 2, "個体数")
	eq(inv.instances.size(), 2, "個体リスト")
	near(float(inv.instances[0]["durability"]), 40.0, 0.01, "初期耐久度=最大")
	check(inv.instances[0]["uid"] != inv.instances[1]["uid"], "UIDは一意")


func test_remove_atomic() -> void:
	inv.add_many({"wood": 3, "rope": 1})
	check(not inv.remove_many({"wood": 2, "rope": 2}), "不足時は削除しない")
	eq(inv.count("wood"), 3, "木材そのまま")
	check(inv.remove_many({"wood": 2, "rope": 1}), "削除成功")
	eq(inv.count("wood"), 1, "残り")
	eq(inv.count("rope"), 0, "ロープ0")
	check(not inv.stacks.has("rope"), "0個のスタックは消える")


func test_broken_tool_unusable_and_repair() -> void:
	inv.add("hammer", 1)
	var uid := int(inv.instances[0]["uid"])
	inv.wear(uid, 100)
	near(float(inv.get_instance(uid)["durability"]), 0.0, 0.01, "耐久度は0で止まる")
	check(inv.find_tool("hammer", 1).is_empty(), "耐久度0の工具は使えない")
	inv.repair_most_worn("hammer", 15)
	near(float(inv.get_instance(uid)["durability"]), 15.0, 0.01, "修理で回復")
	check(not inv.find_tool("hammer", 1).is_empty(), "修理後は使える")
	inv.repair_most_worn("hammer", 1000)
	near(float(inv.get_instance(uid)["durability"]), 40.0, 0.01, "最大値を超えない")


func test_take_and_give_back() -> void:
	inv.add_many({"wood": 4})
	var esc := inv.take({"wood": 4})
	eq(inv.count("wood"), 0, "預かり中は在庫から消える")
	var lost := inv.give_back(esc, 0.5)
	eq(inv.count("wood"), 2, "半分返却")
	eq(lost.get("wood", 0), 2, "損失2")


func test_serialization_roundtrip() -> void:
	inv.add_many({"wood": 5, "hammer": 1})
	inv.wear(int(inv.instances[0]["uid"]), 7)
	var d: Dictionary = JSON.parse_string(JSON.stringify(inv.to_dict()))
	var inv2 := Inventory.new(game_data(), 20.0)
	var w := inv2.from_dict(d)
	eq(w.size(), 0, "警告なし")
	eq(inv2.count("wood"), 5, "木材")
	near(float(inv2.instances[0]["durability"]), 33.0, 0.01, "耐久度")
	inv2.add("hammer", 1)
	check(inv2.instances[0]["uid"] != inv2.instances[1]["uid"], "ロード後もUIDが重複しない")


func test_from_dict_sanitizes() -> void:
	var w := inv.from_dict({"stacks": {"wood": -3, "ghost": 2, "rope": 2}, "instances": [{"id": "hammer", "uid": 5, "durability": 999}, "bad"]})
	eq(inv.count("wood"), 0, "負数は除外")
	eq(inv.count("rope"), 2, "正常値は残る")
	near(float(inv.instances[0]["durability"]), 40.0, 0.01, "耐久度を最大値に補正")
	check(w.size() >= 3, "警告が出る")

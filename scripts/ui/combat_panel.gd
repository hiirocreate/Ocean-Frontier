class_name CombatPanel
extends PanelContainer
## 戦闘画面。戦力の内訳・勝率の目安を示し、「戦う／逃げる／交渉する」を選ばせ、結果を表示する（仕様32）。

var session: GameSession
var _box: VBoxContainer
var _result: Dictionary = {}


func setup(s: GameSession) -> void:
	session = s
	custom_minimum_size = Vector2(760, 0)
	add_theme_stylebox_override("panel", UiTheme.box(Color(0.12, 0.04, 0.05, 0.96), Color(0.9, 0.4, 0.35, 0.7), 14, 16))
	visible = false
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 8)
	add_child(_box)


func _process(_delta: float) -> void:
	if session == null:
		return
	var want := not session.pending_combat.is_empty() or not _result.is_empty()
	if want and not visible:
		visible = true
		Audio.play_sfx("sfx_alert")
		_refresh()
	elif not want and visible:
		visible = false


func _clear() -> void:
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()


func _refresh() -> void:
	_clear()
	if not _result.is_empty():
		_show_result()
		return
	var enemy_id := str(session.pending_combat["enemy"])
	var terrain := str(session.pending_combat.get("terrain", "raft"))
	var e_def: Dictionary = session.data.enemies.get(enemy_id, {})
	var p := CombatSystem.player_force(session, terrain)
	var e := CombatSystem.enemy_force(session, enemy_id)
	_box.add_child(UiTheme.label("⚔ %sが襲いかかってきた！" % e["name"], 28, Color("ffb0a0")))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 30)
	var left := VBoxContainer.new()
	left.add_child(UiTheme.label("こちら", 20, UiTheme.C_GOLD))
	left.add_child(UiTheme.label("攻撃 %d  防御 %d  耐久 %d  士気 %d" % [int(p["attack"]), int(p["defense"]), int(p["hp"]), int(p["morale"])], 17))
	for f in p["factors"]:
		left.add_child(UiTheme.label("・" + f, 15, Color(0.85, 0.88, 0.9)))
	h.add_child(left)
	var face := str(e_def.get("portrait", ""))
	if face != "" and session.data.npcs.has(face):
		var pv := PortraitView.new()
		pv.custom_minimum_size = Vector2(170, 215)
		pv.set_character(face, session.data.npcs[face], "angry")
		h.add_child(pv)
	var right := VBoxContainer.new()
	right.add_child(UiTheme.label(str(e["name"]), 20, Color("ffb0a0")))
	right.add_child(UiTheme.label("攻撃 %d  防御 %d  耐久 %d  士気 %d" % [int(e["attack"]), int(e["defense"]), int(e["hp"]), int(e["morale"])], 17))
	var danger := int(session.data.zones.get(session.zone_id, {}).get("danger", 1))
	if danger > 1:
		right.add_child(UiTheme.label("・危険な海域（強さ×%.1f）" % (1.0 + 0.2 * (danger - 1)), 15, Color(0.85, 0.88, 0.9)))
	h.add_child(right)
	_box.add_child(h)
	var est := CombatSystem.estimate(p, e)
	var col := UiTheme.C_OK if est > 0.6 else (UiTheme.C_GOLD if est > 0.35 else UiTheme.C_WARN)
	_box.add_child(UiTheme.label("勝てる見込み: %d%%" % int(est * 100), 20, col))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var fight := UiTheme.button("戦う", Vector2(200, 70))
	fight.pressed.connect(_choose.bind("fight"))
	row.add_child(fight)
	var flee := UiTheme.button("逃げる", Vector2(200, 70))
	flee.pressed.connect(_choose.bind("retreat"))
	row.add_child(flee)
	var nego := UiTheme.button("交渉する", Vector2(200, 70))
	var np := CombatSystem.negotiate_problem(session, enemy_id)
	nego.disabled = np != ""
	nego.pressed.connect(_choose.bind("negotiate"))
	row.add_child(nego)
	_box.add_child(row)
	if np != "":
		_box.add_child(UiTheme.label("交渉: " + np, 15, Color(0.8, 0.8, 0.8)))
	elif not e_def.get("bribe", {}).is_empty():
		_box.add_child(UiTheme.label("交渉: %sを渡して見逃してもらう" % session.describe_items(e_def["bribe"]), 15, Color(0.8, 0.8, 0.8)))


func _choose(stance: String) -> void:
	_result = session.resolve_combat(stance)
	Audio.play_sfx("sfx_hit")
	var good: bool = _result.get("outcome", "") in ["victory", "enemy_surrendered", "enemy_fled", "negotiated"]
	Audio.play_sfx("sfx_success" if good else "sfx_fail")
	_refresh()


func _show_result() -> void:
	var r := _result
	var good: bool = r["outcome"] in ["victory", "enemy_surrendered", "enemy_fled", "negotiated", "retreated"]
	_box.add_child(UiTheme.label(CombatSystem.outcome_text(r["outcome"]), 30, UiTheme.C_OK if good and r["outcome"] != "retreated" else (UiTheme.C_GOLD if good else UiTheme.C_WARN)))
	var log: Array = r.get("log", [])
	for i in range(maxi(0, log.size() - 6), log.size()):
		_box.add_child(UiTheme.label(str(log[i]), 16, Color(0.85, 0.88, 0.9)))
	if float(r.get("damage_taken", 0)) > 0.0:
		_box.add_child(UiTheme.label("受けた損害: %d" % int(r["damage_taken"]), 17))
	for m in r.get("messages", []):
		_box.add_child(UiTheme.label(str(m), 18, UiTheme.C_GOLD))
	if r["outcome"] == "defeat":
		_box.add_child(UiTheme.label("命は助かった。だが、傷は深い……", 17, UiTheme.C_WARN))
	var ok := UiTheme.button("閉じる", Vector2(200, 64))
	ok.pressed.connect(func():
		_result = {}
		visible = false)
	_box.add_child(ok)

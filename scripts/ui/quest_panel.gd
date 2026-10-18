class_name QuestPanel
extends PanelContainer
## 記録画面: 物語の章と目標（ヒント付き）・依頼（サイドクエスト）・手がかり・出来事の履歴（仕様36 クエスト）

var session: GameSession
var _box: VBoxContainer


func setup(s: GameSession) -> void:
	session = s
	ScreenLayout.fit(self, Vector2(980, 600))
	add_theme_stylebox_override("panel", UiTheme.box(Color(0.04, 0.11, 0.16, 0.97), UiTheme.C_PANEL_BORDER, 14))
	visible = false
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(sc)
	_box = VBoxContainer.new()
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_box.add_theme_constant_override("separation", 6)
	sc.add_child(_box)


func open() -> void:
	visible = true
	refresh()


func refresh() -> void:
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()
	var head := HBoxContainer.new()
	var ch := session.story.chapter_def()
	head.add_child(UiTheme.label("第%d章　%s" % [session.story.chapter, ch.get("title", "")], 28, UiTheme.C_GOLD))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	var close := UiTheme.button("閉じる", Vector2(120, 56))
	close.pressed.connect(func(): visible = false)
	head.add_child(close)
	_box.add_child(head)
	var intro := UiTheme.label(str(ch.get("intro", "")), 16, Color(0.82, 0.88, 0.9))
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(intro)
	for o in ch.get("objectives", []):
		var done := session.story.objective_done_flag(str(o["id"]))
		_box.add_child(UiTheme.label("%s %s" % ["✓" if done else "□", o["text"]], 19, UiTheme.C_OK if done else UiTheme.C_TEXT))
		if not done:
			_box.add_child(UiTheme.label("　ヒント: " + str(o.get("hint", "")), 15, Color(0.75, 0.8, 0.82)))
	if session.story.ending != "":
		_box.add_child(UiTheme.label("結末: " + str(session.data.endings[session.story.ending]["name"]), 19, UiTheme.C_GOLD))
	_box.add_child(UiTheme.label("依頼", 22, UiTheme.C_GOLD))
	var any_q := false
	for qid in session.data.quests:
		var st := str(session.story.quests.get(qid, ""))
		if st == "":
			continue
		any_q = true
		var q: Dictionary = session.data.quests[qid]
		var giver := str(q.get("giver", ""))
		var who := ("（%s）" % session.crew.display_name(giver)) if giver != "" else ""
		_box.add_child(UiTheme.label("%s %s%s" % ["✓" if st == "completed" else "◆", q["name"], who], 19, UiTheme.C_OK if st == "completed" else UiTheme.C_TEXT))
		if st == "active":
			var desc := UiTheme.label("　" + str(q.get("description", "")), 15, Color(0.8, 0.85, 0.87))
			desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_box.add_child(desc)
			for o in q.get("objectives", []):
				var ok := Conditions.check(o.get("condition", {}), session)
				_box.add_child(UiTheme.label("　%s %s" % ["✓" if ok else "・", o["text"]], 15, UiTheme.C_OK if ok else Color(0.85, 0.88, 0.9)))
	if not any_q:
		_box.add_child(UiTheme.label("まだ依頼はない。", 15))
	_box.add_child(UiTheme.label("手がかり", 22, UiTheme.C_GOLD))
	var clues: Array = []
	for id in session.data.items:
		if bool(session.data.items[id].get("clue", false)) and session.inventory.count(id) > 0:
			clues.append(session.data.item_name(id))
	_box.add_child(UiTheme.label("、".join(clues) if not clues.is_empty() else "まだ何も見つけていない。", 16))
	_box.add_child(UiTheme.label("出来事", 22, UiTheme.C_GOLD))
	var h: Array = session.events.history
	for i in range(h.size() - 1, maxi(-1, h.size() - 8), -1):
		var ev: Dictionary = session.data.random_events.get(h[i]["id"], {})
		_box.add_child(UiTheme.label("%d日目 %02d時: %s" % [int(h[i]["day"]), int(h[i]["hour"]), ev.get("name", h[i]["id"])], 15))
	if h.is_empty():
		_box.add_child(UiTheme.label("まだ大きな出来事はない。", 15))

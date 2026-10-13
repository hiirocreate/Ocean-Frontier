class_name FactionPanel
extends PanelContainer
## 勢力情報・評判・海の噂（仕様27, 29, 36）と、勢力拠点での交易・外交画面。

var session: GameSession
var _box: VBoxContainer
var mode := "info"  # info / trade
var trade_faction := ""

const REP_NAMES := [["fame", "名声"], ["fear", "恐怖"], ["trust", "信頼"], ["infamy", "悪名"]]


func setup(s: GameSession) -> void:
	session = s
	custom_minimum_size = Vector2(1000, 600)
	add_theme_stylebox_override("panel", UiTheme.box(Color(0.04, 0.11, 0.16, 0.97), UiTheme.C_PANEL_BORDER, 14))
	visible = false
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(sc)
	_box = VBoxContainer.new()
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_box.add_theme_constant_override("separation", 6)
	sc.add_child(_box)


func open_info() -> void:
	mode = "info"
	visible = true
	refresh()


func open_trade(faction: String) -> void:
	mode = "trade"
	trade_faction = faction
	visible = true
	refresh()


func _clear() -> void:
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()


func _header(title: String) -> void:
	var head := HBoxContainer.new()
	head.add_child(UiTheme.label(title, 26, UiTheme.C_GOLD))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	head.add_child(UiTheme.label("貝貨 %d" % int(session.money), 20, UiTheme.C_GOLD))
	var close := UiTheme.button("閉じる", Vector2(120, 56))
	close.pressed.connect(func(): visible = false)
	head.add_child(close)
	_box.add_child(head)


func refresh() -> void:
	_clear()
	if mode == "trade":
		_show_trade()
	else:
		_show_info()


func is_known(fid: String) -> bool:
	var base := str(session.data.factions[fid].get("base_site", ""))
	return (base != "" and session.is_site_discovered(base)) or session.flags.get("known_faction_" + fid, false) or fid == "tide_union" and session.flags.get("knows_tide_union", false)


func _show_info() -> void:
	_header("勢力と評判")
	var rep := HBoxContainer.new()
	rep.add_theme_constant_override("separation", 16)
	for r in REP_NAMES:
		rep.add_child(UiTheme.label("%s %d" % [r[1], int(session.reputation.get(r[0], 0))], 19))
	_box.add_child(rep)
	for fid in session.data.factions:
		var d: Dictionary = session.data.factions[fid]
		var f: Dictionary = session.factions.factions.get(fid, {})
		if not is_known(fid):
			continue
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", UiTheme.box(Color(0.08, 0.2, 0.26, 0.9), Color(0, 0, 0, 0), 10, 10))
		var v := VBoxContainer.new()
		panel.add_child(v)
		var st := session.factions.standing(fid)
		var att := "友好" if st >= 30 else ("敵対" if st <= -30 else "中立")
		var col := UiTheme.C_OK if st >= 30 else (UiTheme.C_WARN if st <= -30 else UiTheme.C_TEXT)
		var title := "%s（%s）— あなたへの態度: %s %d" % [d["name"], d.get("leader", ""), att, int(st)]
		if not f.get("alive", true):
			title = "%s — 消滅" % d["name"]
		v.add_child(UiTheme.label(title, 19, col))
		var desc := UiTheme.label(str(d.get("description", "")), 15, Color(0.8, 0.86, 0.88))
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(desc)
		v.add_child(UiTheme.label("構成員 約%d人　船 %d隻　武装 %d　防御 %d%s" % [int(f.get("members", 0)), int(f.get("ships", 0)), int(f.get("armament", 0)), int(f.get("defense", 0)), "　【同盟】" if f.get("allied_player", false) else ""], 15))
		var rels: Array = []
		for o in f.get("relations", {}):
			var rv := float(f["relations"][o])
			rels.append("%s %s" % [session.factions.name_of(o), "友好" if rv >= 30 else ("敵対" if rv <= -30 else "中立")])
		v.add_child(UiTheme.label("関係: " + "、".join(rels), 15))
		var hist: Array = f.get("history", [])
		for i in range(maxi(0, hist.size() - 2), hist.size()):
			v.add_child(UiTheme.label("%d日目: %s" % [int(hist[i]["day"]), hist[i]["text"]], 14, Color(0.75, 0.8, 0.82)))
		_box.add_child(panel)
	_box.add_child(UiTheme.label("海の噂", 20, UiTheme.C_GOLD))
	var news := session.factions.news_log
	if news.is_empty():
		_box.add_child(UiTheme.label("まだ何も聞こえてこない。", 15))
	for i in range(news.size() - 1, maxi(-1, news.size() - 8), -1):
		_box.add_child(UiTheme.label("%d日目: %s" % [int(news[i]["day"]), news[i]["text"]], 15))


func _show_trade() -> void:
	var fid := trade_faction
	var d: Dictionary = session.data.factions[fid]
	_header("%s — 交易と外交" % d["name"])
	var prob := Trade.trade_problem(session, fid)
	if prob != "":
		_box.add_child(UiTheme.label(prob, 18, UiTheme.C_WARN))
	else:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 24)
		var buy := VBoxContainer.new()
		buy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buy.add_child(UiTheme.label("買う", 20, UiTheme.C_GOLD))
		for item in d.get("market", {}).get("sells", {}):
			var price := Trade.buy_price(session, fid, item)
			var row := HBoxContainer.new()
			row.add_child(_icon(item))
			var l := UiTheme.label("%s　%d貝貨" % [session.data.item_name(item), price], 16)
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(l)
			var b := UiTheme.button("買う", Vector2(90, 44))
			b.add_theme_font_size_override("font_size", 16)
			b.disabled = session.money < price
			b.pressed.connect(func(): _do(Trade.buy(session, fid, item, 1)))
			row.add_child(b)
			buy.add_child(row)
		h.add_child(buy)
		var sell := VBoxContainer.new()
		sell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sell.add_child(UiTheme.label("売る", 20, UiTheme.C_GOLD))
		for item in d.get("market", {}).get("buys", []):
			var have := session.inventory.count(item)
			if have <= 0:
				continue
			var row := HBoxContainer.new()
			row.add_child(_icon(item))
			var l := UiTheme.label("%s ×%d　%d貝貨" % [session.data.item_name(item), have, Trade.sell_price(session, fid, item)], 16)
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(l)
			var b := UiTheme.button("売る", Vector2(90, 44))
			b.add_theme_font_size_override("font_size", 16)
			b.pressed.connect(func(): _do(Trade.sell(session, fid, item, 1)))
			row.add_child(b)
			sell.add_child(row)
		if sell.get_child_count() == 1:
			sell.add_child(UiTheme.label("買い取ってもらえる品を持っていない", 15))
		h.add_child(sell)
		_box.add_child(h)
	_box.add_child(UiTheme.label("外交", 20, UiTheme.C_GOLD))
	var dip := HBoxContainer.new()
	dip.add_theme_constant_override("separation", 10)
	dip.add_child(_btn("贈り物（50貝貨）", func(): _do(Trade.gift(session, fid, 50)), session.money < 50))
	var ap := Trade.alliance_problem(session, fid)
	dip.add_child(_btn("同盟を申し込む", func(): _do(Trade.request_alliance(session, fid), "%sと同盟を結んだ" % d["name"]), ap != ""))
	if int(d.get("hire_cost", 0)) > 0:
		dip.add_child(_btn("船員を雇う（%d貝貨）" % int(d["hire_cost"]), func(): _do(Trade.hire_sailor(session, fid), "船員を雇った")))
	_box.add_child(dip)
	if ap != "":
		_box.add_child(UiTheme.label("同盟: " + ap, 14, Color(0.8, 0.8, 0.8)))
	var pir := HBoxContainer.new()
	pir.add_theme_constant_override("separation", 10)
	if d.get("kind") == "pirate":
		var jp := Piracy.alliance_problem(session)
		pir.add_child(_btn("海賊同盟に加わる", func(): _do(Piracy.join_alliance(session), "海賊同盟に加わった"), jp != ""))
		if jp != "":
			_box.add_child(UiTheme.label("海賊同盟: " + jp, 14, Color(0.8, 0.8, 0.8)))
	else:
		var pp := Piracy.protection_problem(session, fid)
		pir.add_child(_btn("保護料を要求する", func():
			var r := Piracy.demand_protection(session, fid)
			_do("" if r["ok"] else str(r["error"]), "保護料%d貝貨を取り立てた" % r.get("coins", 0)), pp != ""))
		if pp != "":
			_box.add_child(UiTheme.label("保護料: " + pp, 14, Color(0.8, 0.8, 0.8)))
	_box.add_child(pir)


func _icon(item: String) -> Control:
	var tr := TextureRect.new()
	tr.texture = session.data.item_icon(item)
	tr.custom_minimum_size = Vector2(40, 40)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return tr


func _btn(text: String, cb: Callable, disabled: bool = false) -> Button:
	var b := UiTheme.button(text, Vector2(0, 52))
	b.add_theme_font_size_override("font_size", 17)
	b.disabled = disabled
	b.pressed.connect(cb)
	return b


func _do(err: String, ok_text: String = "") -> void:
	if err != "":
		Game.message.emit(err)
	elif ok_text != "":
		Game.message.emit(ok_text)
	refresh()

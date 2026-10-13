class_name Trade
extends RefCounted
## 交易と外交（仕様27〜29）。価格は勢力のプレイヤーへの態度と評判（信頼・悪名）で変わる。
## 通貨は「貝貨」（GameSession.money）。


## 価格倍率。buying=true はプレイヤーが買うとき（高いほど不利）。
static func price_factor(s: GameSession, faction: String, buying: bool) -> float:
	var st := s.factions.standing(faction)
	var trust := float(s.reputation.get("trust", 0))
	var infamy := float(s.reputation.get("infamy", 0))
	var m := 1.0 - st / 400.0 - trust * 0.002 + infamy * 0.004
	if s.factions.factions.get(faction, {}).get("allied_player", false):
		m -= 0.1
	m = clampf(m, 0.7, 1.6)
	return m if buying else 1.0 / m


static func buy_price(s: GameSession, faction: String, item: String) -> int:
	var base := float(s.data.factions.get(faction, {}).get("market", {}).get("sells", {}).get(item, 0))
	return maxi(1, int(round(base * price_factor(s, faction, true))))


static func sell_price(s: GameSession, faction: String, item: String) -> int:
	var base := float(s.data.item(item).get("sell_price", 0)) * 0.7
	return maxi(0, int(round(base * price_factor(s, faction, false))))


static func trade_problem(s: GameSession, faction: String) -> String:
	if not s.factions.factions.has(faction) or not s.factions.factions[faction]["alive"]:
		return "その勢力はもう存在しない"
	if s.factions.standing(faction) <= -50.0:
		return "%sはあなたとの取引を拒んでいる" % s.factions.name_of(faction)
	return ""


static func buy(s: GameSession, faction: String, item: String, n: int = 1) -> String:
	var p := trade_problem(s, faction)
	if p != "":
		return p
	if not s.data.factions[faction].get("market", {}).get("sells", {}).has(item):
		return "その品は扱っていない"
	var cost := buy_price(s, faction, item) * n
	if s.money < cost:
		return "貝貨が%d不足しています" % (cost - int(s.money))
	if not s.inventory.can_add({item: n}):
		return "所持重量の空き容量が不足しています"
	s.money -= cost
	s.inventory.add(item, n)
	s.counters["trades"] = float(s.counters.get("trades", 0)) + 1.0
	s.factions.change_standing(faction, 0.5)
	return ""


static func sell(s: GameSession, faction: String, item: String, n: int = 1) -> String:
	var p := trade_problem(s, faction)
	if p != "":
		return p
	if not (item in s.data.factions[faction].get("market", {}).get("buys", [])):
		return "その品は買い取ってもらえない"
	if s.inventory.count(item) < n:
		return "%sが%d個不足しています" % [s.data.item_name(item), n - s.inventory.count(item)]
	if bool(s.data.item(item).get("clue", false)):
		return "物語の手がかりは売れない"
	s.inventory.remove(item, n)
	s.money += sell_price(s, faction, item) * n
	s.counters["trades"] = float(s.counters.get("trades", 0)) + 1.0
	s.factions.change_standing(faction, 0.3)
	return ""


# ---------- 外交 ----------
static func gift(s: GameSession, faction: String, coins: int) -> String:
	if s.money < coins:
		return "貝貨が足りません"
	s.money -= coins
	s.factions.change_standing(faction, coins / 10.0)
	s.change_reputation("trust", coins / 50.0)
	return ""


static func alliance_problem(s: GameSession, faction: String) -> String:
	if s.factions.factions.get(faction, {}).get("allied_player", false):
		return "すでに同盟を結んでいる"
	if s.factions.standing(faction) < 60.0:
		return "同盟には友好度60以上が必要（現在%d）" % int(s.factions.standing(faction))
	return ""


static func request_alliance(s: GameSession, faction: String) -> String:
	var p := alliance_problem(s, faction)
	if p != "":
		return p
	s.factions.factions[faction]["allied_player"] = true
	s.flags["allied_" + faction] = true
	for other in s.factions.alive_ids():
		if s.factions.relation(faction, other) <= -40.0:
			s.factions.change_standing(other, -15.0)
	s.change_reputation("fame", 5.0)
	return ""


static func hire_sailor(s: GameSession, faction: String) -> String:
	var cost := int(s.data.factions.get(faction, {}).get("hire_cost", 0))
	if cost <= 0:
		return "ここでは船員を雇えない"
	if s.factions.standing(faction) < 0.0:
		return "%sの者はあなたの船に乗りたがらない" % s.factions.name_of(faction)
	if s.money < cost:
		return "貝貨が%d不足しています" % (cost - int(s.money))
	s.money -= cost
	s.fleet.sailors_pool += 1
	return ""

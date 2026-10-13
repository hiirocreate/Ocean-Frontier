class_name CombatSystem
extends RefCounted
## 戦闘の計算（仕様32）。体力・武器・耐久度・弾薬・防具・技能・仲間の支援・地形・天候・戦力差・士気を反映し、
## 勝利／敗北／退却／降伏（捕虜）／装備破損などの結果を返す。敗北してもゲームオーバーにはしない。
## 結果の適用（apply_result）もここで一元的に行う（重複実装の防止）。

const MAX_ROUNDS := 8
const TERRAIN := {"raft": {"defense": 1.2, "attack": 1.0}, "site": {"defense": 0.9, "attack": 1.0}, "underwater": {"defense": 0.8, "attack": 0.7}, "sea": {"defense": 1.0, "attack": 1.0}}


## 使える最良の武器（弾薬が必要な武器は弾薬がある場合のみ）
static func best_weapon(s: GameSession) -> Dictionary:
	var best := {}
	var best_atk := 0.0
	for inst in s.inventory.instances:
		var c: Dictionary = s.data.item(inst["id"]).get("combat", {})
		if c.get("slot") != "weapon" or float(inst["durability"]) <= 0.0:
			continue
		var ammo := str(c.get("ammo", ""))
		if ammo != "" and s.inventory.count(ammo) <= 0:
			continue
		if float(c.get("attack", 0)) > best_atk:
			best_atk = float(c.get("attack", 0))
			best = inst
	return best


static func _best_defense_item(s: GameSession, slot: String) -> Dictionary:
	var best := {}
	var best_def := 0.0
	for inst in s.inventory.instances:
		var c: Dictionary = s.data.item(inst["id"]).get("combat", {})
		if c.get("slot") == slot and float(inst["durability"]) > 0.0 and float(c.get("defense", 0)) > best_def:
			best_def = float(c.get("defense", 0))
			best = inst
	return best


## プレイヤー側の戦力。factors は画面表示用の内訳。
static func player_force(s: GameSession, terrain: String = "raft") -> Dictionary:
	var f := {"factors": []}
	var weapon := best_weapon(s)
	var atk := 4.0
	if not weapon.is_empty():
		atk = float(s.data.item(weapon["id"])["combat"]["attack"])
		f["factors"].append("武器: %s（攻撃%d）" % [s.data.item_name(weapon["id"]), int(atk)])
	else:
		f["factors"].append("武器なし（素手 攻撃4）")
	var defense := 1.0
	var armor := _best_defense_item(s, "armor")
	var shield := _best_defense_item(s, "shield")
	for it in [armor, shield]:
		if not it.is_empty():
			var d := float(s.data.item(it["id"])["combat"]["defense"])
			defense += d
			f["factors"].append("防具: %s（防御%d）" % [s.data.item_name(it["id"]), int(d)])
	if terrain == "raft":
		for uid in s.raft.buildings:
			var b: Dictionary = s.raft.buildings[uid]
			var cd := float(s.data.buildings.get(b["id"], {}).get("combat_defense", 0))
			if cd > 0.0 and float(b["durability"]) > 0.0:
				defense += cd
				f["factors"].append("%s（防御+%d）" % [s.data.building_name(b["id"]), int(cd)])
	var eff := s.survival.efficiency()
	if eff < 0.99:
		f["factors"].append("体調不良（効率%d%%）" % int(eff * 100))
	atk *= eff
	var hp := s.survival.health
	var support := 0.0
	var morale := 50.0
	var crew_ids: Array = s.crew.aboard_ids() if terrain in ["raft", "sea"] else []
	for id in crew_ids:
		var m: Dictionary = s.crew.members[id]
		var health := float(m["health"]) / 100.0
		support += (2.0 + 1.5 * s.crew.skill(id, "guard")) * health
		hp += float(m["health"]) * 0.5
		morale += (float(m["loyalty"]) - 50.0) * 0.1
	if support > 0.0:
		f["factors"].append("仲間の支援（%d人, 攻撃+%d）" % [crew_ids.size(), int(support)])
	atk += support
	var t: Dictionary = TERRAIN.get(terrain, TERRAIN["sea"])
	atk *= float(t["attack"])
	defense *= float(t["defense"])
	if terrain != "raft":
		f["factors"].append("地形: %s" % {"site": "探索地点", "underwater": "水中（不利）", "sea": "海上"}.get(terrain, terrain))
	var weather := float(s.flags.get("weather_combat_mult", 1.0))
	if weather < 1.0:
		f["factors"].append("悪天候")
	atk *= weather
	morale += float(s.reputation.get("fame", 0)) * 0.2
	f["attack"] = atk
	f["defense"] = defense
	f["hp"] = hp
	f["morale"] = clampf(morale, 10.0, 100.0)
	f["weapon_uid"] = int(weapon.get("uid", -1))
	f["armor_uids"] = [int(armor.get("uid", -1)), int(shield.get("uid", -1))]
	return f


static func enemy_force(s: GameSession, enemy_id: String) -> Dictionary:
	var e: Dictionary = s.data.enemies.get(enemy_id, {})
	var danger := int(s.data.zones.get(s.zone_id, {}).get("danger", 1))
	var scale := 1.0 + 0.2 * (danger - 1)
	return {"name": e.get("name", enemy_id), "attack": float(e.get("attack", 5)) * scale, "defense": float(e.get("defense", 1)) * scale,
		"hp": float(e.get("hp", 30)) * scale, "morale": float(e.get("morale", 50))}


## 勝率の目安（表示用、0〜1）
static func estimate(p: Dictionary, e: Dictionary) -> float:
	var p_dps: float = maxf(1.0, p["attack"] - e["defense"] * 0.5)
	var e_dps: float = maxf(1.0, e["attack"] - p["defense"] * 0.5)
	var p_time: float = e["hp"] / p_dps
	var e_time: float = p["hp"] / e_dps
	return clampf(e_time / (p_time + e_time), 0.02, 0.98)


static func negotiate_problem(s: GameSession, enemy_id: String) -> String:
	var e: Dictionary = s.data.enemies.get(enemy_id, {})
	if not bool(e.get("can_negotiate", false)):
		return "交渉できる相手ではない"
	var bribe: Dictionary = e.get("bribe", {})
	var lack := s.inventory.missing(bribe)
	if not lack.is_empty():
		return "交渉に必要な物資が足りない（%s）" % s.describe_items(lack)
	return ""


## 戦闘を解決する。stance: fight / retreat / negotiate
static func resolve(s: GameSession, enemy_id: String, stance: String, terrain: String = "raft") -> Dictionary:
	var rng := s.rng
	var e_def: Dictionary = s.data.enemies.get(enemy_id, {})
	var p := player_force(s, terrain)
	var e := enemy_force(s, enemy_id)
	var r := {"enemy": enemy_id, "stance": stance, "outcome": "", "log": [], "rounds": 0, "damage_taken": 0.0,
		"loot": {}, "lost": {}, "captured": 0, "ammo_used": 0, "terrain": terrain}
	if stance == "negotiate":
		var prob := negotiate_problem(s, enemy_id)
		if prob == "":
			r["outcome"] = "negotiated"
			r["paid"] = e_def.get("bribe", {}).duplicate()
			r["log"].append("物資を差し出し、%sは引き上げていった。" % e["name"])
			return r
		r["log"].append(prob + "。戦うしかない！")
	if stance == "retreat":
		var chance := 0.55 + 0.05 * s.crew.best_skill("navigation") - 0.05 * int(s.data.zones.get(s.zone_id, {}).get("danger", 1))
		if rng.randf() < chance:
			var dmg: float = e["attack"] * rng.randf_range(0.2, 0.6)
			r["damage_taken"] = dmg
			r["outcome"] = "retreated"
			r["log"].append("全力で距離を取り、逃げ切った。（被害 %d）" % int(dmg))
			return r
		r["log"].append("逃げ切れなかった！")
	var p_hp: float = p["hp"]
	var e_hp: float = e["hp"]
	var p_hp0 := p_hp
	var e_hp0 := e_hp
	var weapon_ammo := ""
	if int(p["weapon_uid"]) >= 0:
		weapon_ammo = str(s.data.item(s.inventory.get_instance(int(p["weapon_uid"]))["id"]).get("combat", {}).get("ammo", ""))
	for i in MAX_ROUNDS:
		r["rounds"] = i + 1
		var pd: float = maxf(1.0, p["attack"] * rng.randf_range(0.8, 1.2) - e["defense"] * 0.5)
		var ed: float = maxf(1.0, e["attack"] * rng.randf_range(0.8, 1.2) - p["defense"] * 0.5)
		if weapon_ammo != "":
			if s.inventory.count(weapon_ammo) - int(r["ammo_used"]) > 0:
				r["ammo_used"] = int(r["ammo_used"]) + 1
			else:
				pd *= 0.3
				r["log"].append("弾が尽きた！")
				weapon_ammo = ""
		e_hp -= pd
		r["log"].append("第%d合: 与えた損害 %d ／ 受けた損害 %d" % [i + 1, int(pd), int(ed)])
		if e_hp <= 0.0:
			r["outcome"] = "victory"
			break
		p_hp -= ed
		r["damage_taken"] = float(r["damage_taken"]) + ed
		if p_hp <= 0.0:
			r["outcome"] = "defeat"
			break
		# 士気判定（損害が大きいと逃走・降伏）
		if e_hp < e_hp0 * 0.35 and rng.randf() * 100.0 > e["morale"]:
			r["outcome"] = "enemy_surrendered" if bool(e_def.get("can_capture", false)) else "enemy_fled"
			break
		if p_hp < p_hp0 * 0.3 and rng.randf() * 100.0 > p["morale"]:
			r["outcome"] = "retreated"
			r["log"].append("仲間が浮き足立ち、退却した。")
			break
	if r["outcome"] == "":
		r["outcome"] = "enemy_fled" if e_hp / e_hp0 < p_hp / p_hp0 else "retreated"
	match r["outcome"]:
		"victory", "enemy_surrendered", "enemy_fled":
			r["loot"] = LootRoller.roll_table(e_def.get("loot", {}), rng) if r["outcome"] != "enemy_fled" else {}
			if r["outcome"] == "enemy_surrendered":
				r["captured"] = rng.randi_range(1, 2)
		"defeat":
			# 敗北: 素材の一部を奪われる
			for id in s.inventory.stacks:
				var cat := str(s.data.item(id).get("category", ""))
				if cat in ["material", "consumable"]:
					var n := int(floor(int(s.inventory.stacks[id]) * 0.3))
					if n > 0:
						r["lost"][id] = n
	r["weapon_uid"] = p["weapon_uid"]
	r["armor_uids"] = p["armor_uids"]
	return r


## 戦闘結果をセッションに反映する（体力・負傷・仲間・装備の耐久・弾薬・戦利品・捕虜・評判）
static func apply_result(s: GameSession, r: Dictionary) -> Array[String]:
	var msgs: Array[String] = []
	var enemy: Dictionary = s.data.enemies.get(r["enemy"], {})
	var dmg := float(r.get("damage_taken", 0.0))
	var crew_ids: Array = s.crew.aboard_ids() if r.get("terrain") in ["raft", "sea"] else []
	var player_share := dmg if crew_ids.is_empty() else dmg * 0.6
	s.survival.health = maxf(1.0, s.survival.health - player_share)
	s.survival.injury = clampf(s.survival.injury + player_share * 0.4, 0.0, 100.0)
	for id in crew_ids:
		s.crew.change(id, "health", -dmg * 0.4 / crew_ids.size())
		s.crew.change(id, "stress", 5.0 + dmg * 0.1)
	if r.has("paid"):
		s.inventory.remove_many(r["paid"])
	var rounds := int(r.get("rounds", 0))
	if int(r.get("weapon_uid", -1)) >= 0 and rounds > 0:
		var uid := int(r["weapon_uid"])
		s.inventory.wear(uid, rounds * 1.5)
		var inst := s.inventory.get_instance(uid)
		if not inst.is_empty() and float(inst["durability"]) <= 0.0:
			msgs.append("%sが壊れた！" % s.data.item_name(inst["id"]))
	for uid in r.get("armor_uids", []):
		if int(uid) >= 0 and rounds > 0:
			s.inventory.wear(int(uid), rounds * 1.0)
	if int(r.get("ammo_used", 0)) > 0:
		s.inventory.remove("ammo", int(r["ammo_used"]))
	if not r.get("lost", {}).is_empty():
		s.inventory.remove_many(r["lost"])
		msgs.append("奪われた: " + s.describe_items(r["lost"]))
	if not r.get("loot", {}).is_empty():
		var got := {}
		for id in r["loot"]:
			if s.inventory.add(id, int(r["loot"][id])):
				got[id] = r["loot"][id]
		if not got.is_empty():
			msgs.append("戦利品: " + s.describe_items(got))
	if int(r.get("captured", 0)) > 0:
		var cap := s.prison_capacity() - s.prisoners.size()
		var n := mini(int(r["captured"]), cap)
		for i in n:
			s.prisoners.append({"from": r["enemy"], "faction": str(enemy.get("faction", "")), "day": s.clock.day()})
		if n > 0:
			msgs.append("%d人を捕虜にした" % n)
		elif cap <= 0:
			msgs.append("捕虜を収容する場所がないため、降伏した者を解放した")
	if r["outcome"] in ["victory", "enemy_surrendered"]:
		for k in enemy.get("reputation", {}):
			s.change_reputation(str(k), float(enemy["reputation"][k]))
		s.stats["battles_won"] = int(s.stats.get("battles_won", 0)) + 1
	elif r["outcome"] == "defeat":
		s.stats["battles_lost"] = int(s.stats.get("battles_lost", 0)) + 1
	return msgs


static func outcome_text(outcome: String) -> String:
	return {"victory": "勝利", "enemy_surrendered": "敵が降伏した", "enemy_fled": "敵は逃げ去った", "defeat": "敗北……",
		"retreated": "退却した", "negotiated": "交渉成立"}.get(outcome, outcome)

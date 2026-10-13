class_name SurvivalState
extends RefCounted
## 体力・空腹・水分・疲労・負傷。値はすべて 0〜100。
## hunger/thirst は「満たされ度」(100=満腹)、fatigue/injury は高いほど悪い。

signal warning(stat: String, text: String)
signal collapsed

const STATS := ["health", "hunger", "thirst", "fatigue", "injury"]

var data: GameData
var health: float = 100.0
var hunger: float = 80.0
var thirst: float = 80.0
var fatigue: float = 0.0
var injury: float = 0.0
var resting: bool = false
var collapse_count: int = 0
var rate_mult := 1.0  # 主人公の能力（漂流生活の経験など）による空腹・渇きの進み方
var fatigue_mult := 1.0
var _warned := {}


func _init(game_data: GameData) -> void:
	data = game_data


func _b(key: String, def: float) -> float:
	return float(data.bal("survival." + key, def))


func tick(minutes: float) -> void:
	if minutes <= 0.0:
		return
	var h := minutes / 60.0
	hunger = clampf(hunger - _b("hunger_per_hour", 4.0) * rate_mult * h, 0.0, 100.0)
	thirst = clampf(thirst - _b("thirst_per_hour", 6.0) * rate_mult * h, 0.0, 100.0)
	if resting:
		fatigue = clampf(fatigue - _b("fatigue_recovery_per_hour_resting", 12.0) * h, 0.0, 100.0)
	else:
		fatigue = clampf(fatigue + _b("fatigue_per_hour", 2.5) * fatigue_mult * h, 0.0, 100.0)
	var dmg := 0.0
	if hunger <= 0.0:
		dmg += _b("starvation_damage_per_hour", 6.0) * h
	if thirst <= 0.0:
		dmg += _b("dehydration_damage_per_hour", 9.0) * h
	dmg += injury * _b("injury_damage_per_hour", 0.05) * h
	if dmg > 0.0:
		health = clampf(health - dmg, 0.0, 100.0)
	elif hunger >= _b("regen_min_food", 50) and thirst >= _b("regen_min_food", 50):
		health = clampf(health + _b("natural_regen_per_hour", 1.0) * h, 0.0, 100.0)
	_check_warnings()
	if health <= 0.0:
		_collapse()


func add_fatigue(amount: float) -> void:
	fatigue = clampf(fatigue + amount, 0.0, 100.0)


## 作業・移動の効率（0.3〜1.0）。空腹・渇き・疲労・負傷で低下する。
func efficiency() -> float:
	var low := _b("low_threshold", 25)
	var e := 1.0
	if hunger < low:
		e -= 0.2 * (1.0 - hunger / low)
	if thirst < low:
		e -= 0.25 * (1.0 - thirst / low)
	if fatigue > 70.0:
		e -= 0.25 * (fatigue - 70.0) / 30.0
	e -= 0.2 * injury / 100.0
	return clampf(e, 0.3, 1.0)


func apply_effects(effects: Dictionary) -> void:
	for k in effects:
		if k in STATS:
			set(k, clampf(float(get(k)) + float(effects[k]), 0.0, 100.0))
	_check_warnings()


func _check_warnings() -> void:
	var low := _b("low_threshold", 25)
	_warn_if("hunger", hunger < low, "空腹です。何か食べてください")
	_warn_if("thirst", thirst < low, "喉が渇いています。水を飲んでください")
	_warn_if("fatigue", fatigue > 80.0, "疲労が溜まっています。休息が必要です")
	_warn_if("health", health < 30.0, "体力が危険な状態です")


func _warn_if(stat: String, cond: bool, text: String) -> void:
	if cond and not _warned.get(stat, false):
		_warned[stat] = true
		warning.emit(stat, text)
	elif not cond:
		_warned[stat] = false


## 体力0でも即ゲームオーバーにはしない（仕様32）。気絶して一定時間後に回復する。
func _collapse() -> void:
	var rec: Dictionary = data.bal("survival.collapse_recovery", {})
	health = float(rec.get("health", 25))
	hunger = maxf(hunger, float(rec.get("hunger", 30)))
	thirst = maxf(thirst, float(rec.get("thirst", 30)))
	fatigue = float(rec.get("fatigue", 20))
	collapse_count += 1
	collapsed.emit()


func to_dict() -> Dictionary:
	var d := {"resting": resting, "collapse_count": collapse_count}
	for s in STATS:
		d[s] = get(s)
	return d


func from_dict(d: Dictionary) -> Array[String]:
	var w: Array[String] = []
	for s in STATS:
		var v: Variant = d.get(s, get(s))
		if not (v is float or v is int):
			w.append("生存値 %s が不正" % s)
			continue
		var f := float(v)
		if is_nan(f) or f < 0.0 or f > 100.0:
			w.append("生存値 %s=%s を範囲内に補正" % [s, str(v)])
			f = 0.0 if is_nan(f) else clampf(f, 0.0, 100.0)
		set(s, f)
	resting = bool(d.get("resting", false))
	collapse_count = int(d.get("collapse_count", 0))
	return w

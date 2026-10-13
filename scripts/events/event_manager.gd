class_name EventManager
extends RefCounted
## 条件付きランダムイベント（仕様34）。ゲーム内1時間ごとに抽選し、条件・確率・クールダウン・履歴を管理する。
## 重大イベント（severity=major）は一定時間内に連続しない。乱数はセッションのRNGを使い、セーブとの整合性を保つ。

var data: GameData
var last_fired: Dictionary = {}  # id -> total_minutes
var history: Array = []  # [{id, day, hour}]
var last_major := -99999.0
var _acc := 0.0


func _init(game_data: GameData) -> void:
	data = game_data


func tick(minutes: float, s: GameSession) -> void:
	_acc += minutes
	while _acc >= 60.0:
		_acc -= 60.0
		roll(s)


## 1時間分の抽選。発生したイベントIDを返す（なければ空文字）。
func roll(s: GameSession) -> String:
	if not s.pending_combat.is_empty() or not s.pending_dialogue.is_empty():
		return ""
	var now := s.clock.total_minutes
	var spacing := float(data.bal("events.major_spacing_hours", 36)) * 60.0
	var guard := minf(0.7, float(s.counters.get("guard_hours", 0.0)) / 150.0)
	for id in data.random_events:
		var e: Dictionary = data.random_events[id]
		if last_fired.has(id) and now - float(last_fired[id]) < float(e.get("cooldown_hours", 24)) * 60.0:
			continue
		var major := str(e.get("severity", "minor")) == "major"
		if major and now - last_major < spacing:
			continue
		if not Conditions.check(e.get("condition", {}), s):
			continue
		var chance := float(e.get("chance", 0.0)) * float(data.bal("events.chance_multiplier", 1.0))
		if bool(e.get("guard_reduces", false)):
			chance *= 1.0 - guard
		if s.rng.randf() >= chance:
			continue
		fire(id, s)
		return id
	return ""


func fire(id: String, s: GameSession) -> void:
	var e: Dictionary = data.random_events[id]
	var now := s.clock.total_minutes
	last_fired[id] = now
	if str(e.get("severity", "minor")) == "major":
		last_major = now
	history.append({"id": id, "day": s.clock.day(), "hour": s.clock.hour()})
	if history.size() > 50:
		history.remove_at(0)
	if e.get("dialogue") is Dictionary and not e["dialogue"].is_empty():
		s.pending_dialogue = {"id": "event_" + id, "nodes": e["dialogue"]}
	for ef in e.get("effects", []):
		s.apply_effect(ef)


func to_dict() -> Dictionary:
	return {"last_fired": last_fired.duplicate(), "history": history.duplicate(true), "last_major": last_major, "acc": _acc}


func from_dict(d: Dictionary) -> Array[String]:
	var w: Array[String] = []
	last_fired.clear()
	var lf: Variant = d.get("last_fired", {})
	if lf is Dictionary:
		for k in lf:
			if data.random_events.has(str(k)):
				last_fired[str(k)] = float(lf[k])
	history = d.get("history", []).duplicate(true) if d.get("history") is Array else []
	last_major = float(d.get("last_major", -99999.0))
	_acc = clampf(float(d.get("acc", 0.0)), 0.0, 60.0)
	return w

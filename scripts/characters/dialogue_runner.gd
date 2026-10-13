class_name DialogueRunner
extends RefCounted
## 会話の進行。選択肢の条件判定と効果の適用は GameSession を通して行う。

signal node_changed(node: Dictionary)
signal finished(dialogue_id: String)

var session: GameSession
var dialogue_id := ""
var node_id := ""
var nodes: Dictionary = {}


func _init(s: GameSession) -> void:
	session = s


func start(id: String) -> bool:
	var d: Dictionary = session.data.dialogues.get(id, {})
	if d.is_empty():
		GameLog.warn("会話が見つかりません: " + id)
		return false
	dialogue_id = id
	nodes = d.get("nodes", {})
	session.flags["seen_" + id] = true
	_go("start")
	return true


## データにない会話（雑談・再会など）をその場で組み立てて開始する
func start_inline(id: String, inline_nodes: Dictionary) -> bool:
	dialogue_id = id
	nodes = inline_nodes
	_go("start")
	return true


func is_active() -> bool:
	return node_id != ""


func current() -> Dictionary:
	return nodes.get(node_id, {})


## 表示用のノード：主人公の設定に応じた台詞差分（variants）を選び、{name} などを置換する（仕様: シナリオ分岐）
func display_node(n: Dictionary) -> Dictionary:
	var out := n.duplicate(true)
	for v in n.get("variants", []):
		if Conditions.check(v.get("condition", {}), session):
			out["text"] = v.get("text", out.get("text", ""))
			if v.has("expression"):
				out["expression"] = v["expression"]
			break
	var sp := str(out.get("speaker", ""))
	out["text"] = session.profile.format_text(str(out.get("text", "")), session.data.survivors.get(sp, {}))
	return out


## 表示可能な選択肢（条件を満たすもの）。[{index, text}]
func choices() -> Array:
	var out: Array = []
	var cs: Array = current().get("choices", [])
	for i in cs.size():
		if Conditions.check(cs[i].get("condition", {}), session):
			out.append({"index": i, "text": session.profile.format_text(str(cs[i].get("text", "")))})
	return out


## 選択肢がないノードで「次へ」
func advance() -> void:
	var n := current()
	if not n.get("choices", []).is_empty():
		return
	_go(str(n.get("next", "end")))


func choose(index: int) -> void:
	var cs: Array = current().get("choices", [])
	if index < 0 or index >= cs.size():
		return
	var c: Dictionary = cs[index]
	if not Conditions.check(c.get("condition", {}), session):
		return
	apply_effects(c.get("effects", []))
	_go(str(c.get("next", "end")))


func _go(id: String) -> void:
	if id == "end" or not nodes.has(id):
		node_id = ""
		finished.emit(dialogue_id)
		return
	node_id = id
	apply_effects(nodes[id].get("effects", []))
	node_changed.emit(display_node(nodes[id]))


func apply_effects(effects: Array) -> void:
	for e in effects:
		session.apply_effect(e)

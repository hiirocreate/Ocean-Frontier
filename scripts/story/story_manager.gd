class_name StoryManager
extends RefCounted
## 章構成・目標・物語トリガー・サイドクエスト・エンディング（仕様33, 35）。
## 目標はデータの条件式で判定し、代替手段を持たせて特定の仲間やランダムイベントに依存させない。

signal chapter_started(chapter: int)
signal objective_done(text: String)
signal quest_changed(id: String, state: String)

var data: GameData
var chapter: int = 1
var done_objectives: Array = []
var fired_triggers: Array = []
var quests: Dictionary = {}  # id -> "active" / "completed"
var ending := ""


func _init(game_data: GameData) -> void:
	data = game_data


func chapter_def(n: int = -1) -> Dictionary:
	var target := chapter if n < 0 else n
	for id in data.chapters:
		if int(data.chapters[id].get("number", 0)) == target:
			return data.chapters[id]
	return {}


func objective_done_flag(obj_id: String) -> bool:
	return obj_id in done_objectives


## 定期的に呼ばれ、トリガー・目標・章の進行・クエストを判定する
func check(s: GameSession) -> void:
	for tid in data.story_flags:
		if tid in fired_triggers:
			continue
		var t: Dictionary = data.story_flags[tid]
		if Conditions.check(t.get("condition", {}), s):
			fired_triggers.append(tid)
			for e in t.get("effects", []):
				s.apply_effect(e)
	var ch := chapter_def()
	if ch.is_empty():
		return
	var all_done := true
	for o in ch.get("objectives", []):
		var oid := str(o["id"])
		if oid in done_objectives:
			continue
		if Conditions.check(o.get("condition", {}), s):
			done_objectives.append(oid)
			objective_done.emit(str(o["text"]))
			s.message.emit("目標達成: %s" % o["text"])
		else:
			all_done = false
	if all_done and ending == "":
		_advance_chapter(s)
	elif chapter == 5 and "ch5_core" in done_objectives and ending == "" and s.pending_dialogue.is_empty():
		s.pending_dialogue = {"id": "final_choice", "nodes": final_choice_nodes(s)}
	_check_quests(s)


func _advance_chapter(s: GameSession) -> void:
	var ch := chapter_def()
	if str(ch.get("outro", "")) != "":
		s.message.emit(str(ch["outro"]))
	if chapter_def(chapter + 1).is_empty():
		return
	chapter += 1
	s.flags["chapter"] = chapter
	var nx := chapter_def()
	s.message.emit("第%d章「%s」" % [chapter, nx.get("title", "")])
	s.pending_dialogue = {"id": "chapter_%d" % chapter, "nodes": {"start": {"speaker": "narrator", "text": "第%d章　%s\n\n%s" % [chapter, nx.get("title", ""), nx.get("intro", "")], "next": "end"}}}
	chapter_started.emit(chapter)


func _check_quests(s: GameSession) -> void:
	for qid in data.quests:
		var q: Dictionary = data.quests[qid]
		var st := str(quests.get(qid, ""))
		if st == "":
			var giver := str(q.get("giver", ""))
			if giver != "" and not s.crew.is_aboard(giver) and not s.crew.members.has(giver):
				continue
			if Conditions.check(q.get("start", {}), s):
				quests[qid] = "active"
				s.message.emit("新しい依頼: %s" % q["name"])
				quest_changed.emit(qid, "active")
		elif st == "active":
			if q.get("objectives", []).all(func(o): return Conditions.check(o.get("condition", {}), s)):
				quests[qid] = "completed"
				for e in q.get("rewards", []):
					var tgt := str(e.get("target", ""))
					if tgt != "" and not s.crew.members.has(tgt):
						continue  # 去った仲間への報酬は適用しない（進行は止めない）
					s.apply_effect(e)
				s.message.emit("依頼達成: %s" % q["name"])
				quest_changed.emit(qid, "completed")


# ---------- エンディング ----------
func available_endings(s: GameSession) -> Array[String]:
	var out: Array[String] = []
	for id in data.endings:
		if Conditions.check(data.endings[id].get("condition", {}), s):
			out.append(id)
	out.sort_custom(func(a, b): return int(data.endings[a].get("priority", 0)) > int(data.endings[b].get("priority", 0)))
	return out


func final_choice_nodes(s: GameSession) -> Dictionary:
	var choices: Array = []
	for id in available_endings(s):
		choices.append({"text": str(data.endings[id]["description"]), "next": "end", "effects": [{"type": "flag", "key": "ending_pick", "value": id}]})
	return {
		"start": {"speaker": "narrator", "text": "中枢の奥で、巨大な装置が脈打っている。世界中の潮流を、ここから操っていたのだ。\nあなたの手には、全てを変える力がある。", "next": "choose"},
		"choose": {"speaker": "narrator", "text": "——どうする？", "choices": choices},
	}


func choose_ending(s: GameSession, id: String) -> bool:
	if not (id in available_endings(s)):
		return false
	ending = id
	s.flags["ending_chosen"] = true
	s.flags["ending_id"] = id
	return true


func to_dict() -> Dictionary:
	return {"chapter": chapter, "done": done_objectives.duplicate(), "fired": fired_triggers.duplicate(), "quests": quests.duplicate(), "ending": ending}


func from_dict(d: Dictionary) -> Array[String]:
	var w: Array[String] = []
	chapter = clampi(int(d.get("chapter", 1)), 1, maxi(1, data.chapters.size()))
	done_objectives = d.get("done", []).duplicate() if d.get("done") is Array else []
	fired_triggers = d.get("fired", []).duplicate() if d.get("fired") is Array else []
	quests.clear()
	var q: Variant = d.get("quests", {})
	if q is Dictionary:
		for k in q:
			if data.quests.has(str(k)) and q[k] in ["active", "completed"]:
				quests[str(k)] = q[k]
			else:
				w.append("不正なクエスト '%s' を除外" % str(k))
	ending = str(d.get("ending", ""))
	if ending != "" and not data.endings.has(ending):
		w.append("不明なエンディング '%s' をリセット" % ending)
		ending = ""
	return w

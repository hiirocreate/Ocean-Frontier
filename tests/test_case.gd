class_name TestCase
extends RefCounted
## 最小限のテスト基底クラス。test_ で始まるメソッドが自動実行される。

var failures: Array[String] = []
var assertions: int = 0
var current_test: String = ""


func before_each() -> void:
	pass


func check(cond: bool, msg: String) -> void:
	assertions += 1
	if not cond:
		failures.append("%s: %s" % [current_test, msg])


func eq(actual: Variant, expected: Variant, msg: String = "") -> void:
	check(actual == expected, "%s 期待値=%s 実際=%s" % [msg, str(expected), str(actual)])


func near(actual: float, expected: float, eps: float = 0.001, msg: String = "") -> void:
	check(absf(actual - expected) <= eps, "%s 期待値≈%s 実際=%s" % [msg, str(expected), str(actual)])


## テスト用のデータ（本番データを読み込む）
static func game_data() -> GameData:
	return GameData.load_default()


static func new_session(game_seed: int = 12345) -> GameSession:
	var s := GameSession.new(game_data())
	s.new_game(game_seed)
	return s


## 物語の会話の場面（勢力のリーダーとの会話など）を読み終えたことにして、最後の選択まで進める
func finish_scenes(s: GameSession) -> void:
	for i in 12:
		s.story.check(s)
		if s.pending_dialogue.is_empty() or str(s.pending_dialogue.get("id", "")) == "final_choice":
			return
		s.pending_dialogue = {}

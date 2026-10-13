extends Node
## オートロード "Audio"。効果音・環境音・BGM（tools/generate_audio.py で合成した独自素材）を再生する。
## 音声ファイルが無くてもエラーにならない（警告を1回出すだけ）。

const DIR := "res://assets/audio/"
const LOOPS := ["amb_ocean", "amb_rain", "amb_storm", "bgm_day", "bgm_night", "bgm_combat"]

var _streams := {}
var _sfx_players: Array[AudioStreamPlayer] = []
var _ambient := {}  # id -> AudioStreamPlayer
var _music: AudioStreamPlayer
var _music_id := ""
var _missing_warned := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_sfx_players.append(p)
	_music = AudioStreamPlayer.new()
	add_child(_music)
	get_tree().node_added.connect(_on_node_added)


func _stream(id: String) -> AudioStream:
	if _streams.has(id):
		return _streams[id]
	var path := DIR + id + ".wav"
	if not ResourceLoader.exists(path):
		if not _missing_warned.has(id):
			_missing_warned[id] = true
			GameLog.warn("音声ファイルがありません: " + path)
		return null
	var s: AudioStream = load(path)  # ループ設定は .import（edit/loop_mode=2）で行う
	_streams[id] = s
	return s


func _volume_db(scale: float = 1.0) -> float:
	var v := float(Game.settings.get("master_volume", 1.0)) * scale
	return linear_to_db(maxf(0.0001, v))


func play_sfx(id: String, volume: float = 1.0) -> void:
	var s := _stream(id)
	if s == null:
		return
	for p in _sfx_players:
		if not p.playing:
			p.stream = s
			p.volume_db = _volume_db(volume)
			p.pitch_scale = randf_range(0.95, 1.05)
			p.play()
			return


## 環境音の音量を設定（0で停止）。毎フレーム呼んでよい。
func set_ambient(id: String, volume: float) -> void:
	if not _ambient.has(id):
		if volume <= 0.001:
			return
		var s := _stream(id)
		if s == null:
			return
		var p := AudioStreamPlayer.new()
		p.stream = s
		add_child(p)
		_ambient[id] = p
	var pl: AudioStreamPlayer = _ambient[id]
	if volume <= 0.001:
		if pl.playing:
			pl.stop()
		return
	pl.volume_db = _volume_db(volume)
	if not pl.playing:
		pl.play()


func stop_all_ambient() -> void:
	for id in _ambient:
		_ambient[id].stop()


## BGMを切り替える（同じ曲なら何もしない）。空文字で停止。
func set_music(id: String, volume: float = 0.6) -> void:
	if id == _music_id:
		_music.volume_db = _volume_db(volume)
		return
	_music_id = id
	if id == "":
		_music.stop()
		return
	var s := _stream(id)
	if s == null:
		return
	_music.stream = s
	_music.volume_db = _volume_db(volume)
	_music.play()


## すべてのボタンにクリック音を付ける
func _on_node_added(n: Node) -> void:
	if n is BaseButton and not n.has_meta("no_click_sound"):
		n.pressed.connect(func(): play_sfx("sfx_click", 0.5))

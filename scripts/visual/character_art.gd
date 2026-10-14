class_name CharacterArt
extends RefCounted
## 生成した立ち絵・3Dモデル（assets/characters/）の検索と、主人公の髪色・肌の色の置き換え設定。
## 素材がなければ null を返し、呼び出し側は従来の図形描画・プリミティブ構成にフォールバックする。

const PORTRAIT_DIR := "res://assets/characters/portraits/"
const MODEL_DIR := "res://assets/characters/models/"
const RECOLOR_2D := preload("res://assets/shaders/portrait_recolor.gdshader")
const DEFAULT_SKIN := "#e8b996"  # 基準の肌色（外見「明るい肌」と同じ。これを選ぶと生成画像の肌のまま）

static var _cache := {}


## 素材のID。主人公は性別×年齢帯（player_male_youth など）、仲間は survivors.json の id
static func art_id(id: String, defn: Dictionary) -> String:
	if defn.has("art_id"):
		return str(defn["art_id"])
	return id if id != "player" else ""


## 生成素材を使うか（主人公は作成画面で「シンプル表示」を選ぶと従来の描画）
static func enabled(defn: Dictionary) -> bool:
	return str(defn.get("art_mode", "illust")) != "simple"


static func portrait(aid: String, expression: String) -> Texture2D:
	if aid == "":
		return null
	for e in [expression, "normal"]:
		for ext in ["webp", "png"]:
			var path := "%s%s_%s.%s" % [PORTRAIT_DIR, aid, e, ext]
			if _cache.has(path):
				return _cache[path]
			if ResourceLoader.exists(path):
				_cache[path] = load(path)
				return _cache[path]
	return null


static func model_scene(aid: String) -> PackedScene:
	if aid == "":
		return null
	var path := "%s%s.glb" % [MODEL_DIR, aid]
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cache[path]


## 主人公の髪色・肌の色の置き換えパラメータ（仲間は置き換えない）
static func recolor_params(defn: Dictionary) -> Dictionary:
	if not str(defn.get("art_id", "")).begins_with("player_"):
		return {}
	var c: Dictionary = defn.get("colors", {})
	return {"hair_recolor": true, "hair_target": Color(str(c.get("hair", "#2e2a2b"))),
		"skin_recolor": true, "skin_target": Color(str(c.get("skin", DEFAULT_SKIN))), "skin_source": Color(DEFAULT_SKIN)}


static func portrait_material(defn: Dictionary) -> ShaderMaterial:
	var p := recolor_params(defn)
	if p.is_empty():
		return null
	var m := ShaderMaterial.new()
	m.shader = RECOLOR_2D
	for k in p:
		m.set_shader_parameter(k, p[k])
	return m

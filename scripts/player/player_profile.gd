class_name PlayerProfile
extends RefCounted
## 主人公データ（単一の情報源）。会話・イベント・NPC反応・モデル表示・能力・セーブはすべてこれを参照する。
## 年齢帯の判定・台詞の置換・初期能力の計算はここに集約し、各システムで重複実装しない。

const SCHEMA_VERSION := 1
const AGE_MIN := 10
const AGE_MAX := 40
const GENDERS := ["male", "female"]
const ABILITIES := ["survival", "repair", "perception", "negotiation", "medicine", "navigation", "combat", "leadership", "learning", "adaptability"]
const MAX_TRAITS := 2

var player_id := ""
var name := "ナギ"
var gender := "male"
var age := 22
var appearance: Dictionary = {}
var background_id := "amnesia"
var traits: Array = []
var initial_inventory: Dictionary = {}
var abilities: Dictionary = {}
var story_flags: Dictionary = {}
var past_events: Array = []  # [{day, text}] 過去・背景に関する出来事の記録


static func default_appearance(g: String = "male") -> Dictionary:
	return {"hair_style": "messy" if g == "male" else "bob", "hair_color": "black", "skin_color": "light", "face": "soft", "outfit": "castaway", "accessory": "scarf"}


## 主人公作成をスキップした場合・古いセーブの移行時の既定値
static func create_default(data: GameData) -> PlayerProfile:
	var p := PlayerProfile.new()
	p.player_id = "p%d" % (Time.get_unix_time_from_system() as int)
	p.appearance = default_appearance(p.gender)
	p.finalize(data)
	return p


## 年齢帯（共通関数）。範囲外は近い帯に丸めず空文字を返す。
static func age_band_of(a: int) -> String:
	if a < AGE_MIN or a > AGE_MAX:
		return ""
	if a <= 15:
		return "young"
	if a <= 19:
		return "youth"
	if a <= 29:
		return "adult"
	return "mature"


func age_band() -> String:
	return age_band_of(age)


static func validate_age(a: Variant) -> String:
	if not (a is int or (a is float and float(a) == floorf(float(a)))):
		return "年齢は整数で入力してください"
	if int(a) < AGE_MIN or int(a) > AGE_MAX:
		return "年齢は%d〜%d歳の範囲で選んでください" % [AGE_MIN, AGE_MAX]
	return ""


## 設定全体の検証。問題の一覧（空なら正常）
func validate(data: GameData) -> Array[String]:
	var e: Array[String] = []
	if name.strip_edges() == "":
		e.append("名前を入力してください")
	elif name.length() > 12:
		e.append("名前は12文字以内にしてください")
	if not (gender in GENDERS):
		e.append("性別を選んでください")
	var ae := validate_age(age)
	if ae != "":
		e.append(ae)
	if not data.backgrounds.has(background_id):
		e.append("過去の背景を選んでください")
	e.append_array(trait_problems(data, traits, background_id))
	var opts: Dictionary = data.appearance
	for k in [["hair_style", "hair_styles"], ["hair_color", "hair_colors"], ["skin_color", "skin_colors"], ["face", "faces"], ["outfit", "outfits"], ["accessory", "accessories"]]:
		var ids: Array = opts.get(k[1], []).map(func(o): return o["id"])
		if not (str(appearance.get(k[0], "")) in ids):
			e.append("外見「%s」の値が不正です" % k[0])
	return e


## 特性の組み合わせ検証（背景で既に得ている特性・排他関係・個数）
static func trait_problems(data: GameData, t: Array, bg: String) -> Array[String]:
	var e: Array[String] = []
	if t.size() > MAX_TRAITS:
		e.append("初期特性は%d個までです" % MAX_TRAITS)
	var seen := {}
	var granted := str(data.backgrounds.get(bg, {}).get("grants_trait", ""))
	for id in t:
		if not data.player_traits.has(str(id)):
			e.append("不明な特性です: %s" % id)
			continue
		if seen.has(id):
			e.append("同じ特性は重ねて選べません")
		seen[id] = true
		if str(id) == granted:
			e.append("「%s」は背景で既に身についています" % data.player_traits[id]["name"])
		for ex in data.player_traits[id].get("exclusive_with", []):
			if ex in t or ex == granted:
				e.append("「%s」と「%s」は同時に選べません" % [data.player_traits[id]["name"], data.player_traits.get(ex, {}).get("name", ex)])
	return e


## 背景・年齢帯・特性から初期能力と初期アイテムを計算する（共通関数）
func finalize(data: GameData) -> void:
	abilities = {}
	for a in ABILITIES:
		abilities[a] = 0
	var sources: Array = [data.backgrounds.get(background_id, {}).get("abilities", {})]
	var band: Dictionary = data.age_bands.get(age_band(), {})
	sources.append(band.get("abilities", {}))
	for t in all_traits(data):
		sources.append(data.player_traits.get(t, {}).get("abilities", {}))
	for src in sources:
		for k in src:
			abilities[k] = int(abilities.get(k, 0)) + int(src[k])
	initial_inventory = data.backgrounds.get(background_id, {}).get("initial_items", {}).duplicate()
	story_flags = data.backgrounds.get(background_id, {}).get("flags", {}).duplicate()
	story_flags["gender_" + gender] = true
	story_flags["age_" + age_band()] = true


## 選んだ特性＋背景で得た特性
func all_traits(data: GameData) -> Array:
	var out := traits.duplicate()
	var g := str(data.backgrounds.get(background_id, {}).get("grants_trait", ""))
	if g != "" and not (g in out):
		out.append(g)
	return out


func ability(id: String) -> int:
	return int(abilities.get(id, 0))


func has_trait(data: GameData, id: String) -> bool:
	return id in all_traits(data)


# ---------- 台詞・呼称 ----------
## NPCの呼びかけ。年齢と性別に、相手の性格（survivors.json の address 設定）を組み合わせる。
func address_for(speaker_def: Dictionary) -> String:
	var style := str(speaker_def.get("address_style", "name"))
	var band := age_band()
	match style:
		"military":
			return "坊主" if band == "young" and gender == "male" else ("嬢ちゃん" if band == "young" else name)
		"merchant":
			return "お若いの" if band in ["young", "youth"] else ("旦那" if gender == "male" else "姐さん")
		"pirate":
			return "小僧" if band == "young" and gender == "male" else ("お嬢" if band == "young" else "船長")
		"kid":
			return ("兄ちゃん" if gender == "male" else "姉ちゃん") if band != "young" else name
		_:
			return name


func pronoun() -> String:
	return "彼" if gender == "male" else "彼女"


## 台詞中の {name} {address} {age} {pronoun} を置換する
func format_text(text: String, speaker_def: Dictionary = {}) -> String:
	return text.replace("{name}", name).replace("{address}", address_for(speaker_def)).replace("{age}", str(age)).replace("{pronoun}", pronoun())


# ---------- 外見（2D/3D共通の見た目データ） ----------
func look(data: GameData) -> Dictionary:
	var opts: Dictionary = data.appearance
	var hair := _opt(opts, "hair_colors", str(appearance.get("hair_color", "black")))
	var skin := _opt(opts, "skin_colors", str(appearance.get("skin_color", "light")))
	var outfit := _opt(opts, "outfits", str(appearance.get("outfit", "castaway")))
	var acc := str(appearance.get("accessory", "scarf"))
	return {
		"colors": {"skin": skin.get("color", "#e8b996"), "hair": hair.get("color", "#2e2a2b"), "shirt": outfit.get("shirt", "#d8cfb8"),
			"outer": outfit.get("outer", "#3f6b73"), "pants": outfit.get("pants", "#4a4f5e"), "accent": "#c2553d"},
		"hair_style": str(appearance.get("hair_style", "messy")), "accessory": "" if acc == "none" else acc,
		"face": str(appearance.get("face", "soft")), "gender": gender, "age": age, "age_band": age_band(),
	}


static func _opt(opts: Dictionary, key: String, id: String) -> Dictionary:
	for o in opts.get(key, []):
		if o["id"] == id:
			return o
	return opts.get(key, [{}])[0] if not opts.get(key, []).is_empty() else {}


## 体格パラメータ（3Dモデル用）。若年層は縮小ではなく頭身・体格の比率自体を変える。
func body_params() -> Dictionary:
	return body_params_for(gender, age)


static func body_params_for(g: String, a: int) -> Dictionary:
	var band := age_band_of(clampi(a, AGE_MIN, AGE_MAX))
	var p := {"height": 1.0, "head": 1.0, "shoulder": 1.0, "limb": 1.0, "hip": 1.0, "posture": 0.0}
	match band:
		"young":
			var t := float(a - 10) / 5.0  # 10歳→0, 15歳→1
			p = {"height": lerpf(0.74, 0.88, t), "head": lerpf(1.18, 1.08, t), "shoulder": lerpf(0.78, 0.88, t), "limb": lerpf(0.82, 0.92, t), "hip": 0.9, "posture": 0.0}
		"youth":
			p = {"height": 0.95, "head": 1.03, "shoulder": 0.94, "limb": 0.97, "hip": 0.95, "posture": 0.0}
		"mature":
			p = {"height": 1.0, "head": 1.0, "shoulder": 1.04, "limb": 1.0, "hip": 1.03, "posture": 0.04}
	if g == "female":
		p["height"] *= 0.95
		p["shoulder"] *= 0.9
		p["hip"] *= 1.08
	return p


# ---------- 保存 ----------
func to_dict() -> Dictionary:
	return {"schema": SCHEMA_VERSION, "player_id": player_id, "name": name, "gender": gender, "age": age, "appearance": appearance.duplicate(),
		"background_id": background_id, "traits": traits.duplicate(), "initial_inventory": initial_inventory.duplicate(),
		"abilities": abilities.duplicate(), "story_flags": story_flags.duplicate(), "past_events": past_events.duplicate(true)}


## 復元。不正な値は既定値に置き換え、警告を返す（年齢・性別は保存値を尊重し、範囲外のみ補正）
static func from_dict(d: Dictionary, data: GameData) -> Dictionary:
	var w: Array[String] = []
	var p := PlayerProfile.new()
	p.player_id = str(d.get("player_id", "p0"))
	p.name = str(d.get("name", "ナギ")).substr(0, 12)
	if p.name.strip_edges() == "":
		p.name = "ナギ"
	p.gender = str(d.get("gender", "male"))
	if not (p.gender in GENDERS):
		w.append("主人公の性別が不正 → 既定値")
		p.gender = "male"
	p.age = int(d.get("age", 22))
	if validate_age(p.age) != "":
		w.append("主人公の年齢が範囲外 → 補正")
		p.age = clampi(p.age, AGE_MIN, AGE_MAX)
	p.appearance = default_appearance(p.gender)
	var ap: Variant = d.get("appearance", {})
	if ap is Dictionary:
		for k in ap:
			p.appearance[str(k)] = str(ap[k])
	p.background_id = str(d.get("background_id", "amnesia"))
	if not data.backgrounds.has(p.background_id):
		w.append("不明な背景 → 記憶喪失")
		p.background_id = "amnesia"
	var t: Variant = d.get("traits", [])
	p.traits = (t as Array).filter(func(x): return data.player_traits.has(str(x))) if t is Array else []
	if not trait_problems(data, p.traits, p.background_id).is_empty():
		w.append("初期特性の組み合わせが不正 → 解除")
		p.traits = []
	for e in p.validate(data):
		if e.begins_with("外見"):
			w.append(e + " → 既定値")
			p.appearance = default_appearance(p.gender)
			break
	p.finalize(data)
	var sf: Variant = d.get("story_flags", {})
	if sf is Dictionary:
		for k in sf:
			p.story_flags[str(k)] = sf[k]
	var pe: Variant = d.get("past_events", [])
	p.past_events = pe.duplicate(true) if pe is Array else []
	return {"profile": p, "warnings": w}

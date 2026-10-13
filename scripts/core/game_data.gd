class_name GameData
extends RefCounted
## data/ 以下のJSON定義を読み込み、IDで参照できるようにする。
## 定義データ（静的）であり、プレイヤーの所持状態などは持たない。

## キー: [ファイル（または同じ形式の複数ファイルの配列）, リストのキー]
const DATA_FILES := {
	"items": [["res://data/items/items.json", "res://data/items/items_equipment.json", "res://data/items/items_story.json"], "items"],
	"actions": [["res://data/recipes/actions.json", "res://data/recipes/actions_extra.json"], "actions"],
	"sites": ["res://data/world/sites.json", "sites"],
	"enemies": ["res://data/combat/enemies.json", "enemies"],
	"buildings": ["res://data/buildings/buildings.json", "buildings"],
	"zones": ["res://data/world/world_zones.json", "zones"],
	"survivors": ["res://data/characters/survivors.json", "survivors"],
	"dialogues": ["res://data/characters/dialogue.json", "dialogues"],
	"jobs": ["res://data/characters/jobs.json", "jobs"],
	"traits": ["res://data/characters/traits.json", "traits"],
	"factions": ["res://data/factions/factions.json", "factions"],
	"ships": ["res://data/ships/ships.json", "ships"],
	"missions": ["res://data/ships/fleet_missions.json", "missions"],
	"raid_targets": ["res://data/piracy/raid_targets.json", "raid_targets"],
}
const BALANCE_FILE := "res://data/balance_config.json"

var items: Dictionary = {}
var actions: Dictionary = {}
var buildings: Dictionary = {}
var zones: Dictionary = {}
var survivors: Dictionary = {}
var sites: Dictionary = {}
var enemies: Dictionary = {}
var dialogues: Dictionary = {}
var jobs: Dictionary = {}
var traits: Dictionary = {}
var factions: Dictionary = {}
var ships: Dictionary = {}
var missions: Dictionary = {}
var raid_targets: Dictionary = {}
var balance: Dictionary = {}
var load_errors: Array[String] = []


static func load_default() -> GameData:
	var d := GameData.new()
	d.load_all()
	return d


func load_all() -> bool:
	load_errors.clear()
	items = _load_list("items")
	actions = _load_list("actions")
	buildings = _load_list("buildings")
	zones = _load_list("zones")
	survivors = _load_list("survivors")
	sites = _load_list("sites")
	enemies = _load_list("enemies")
	dialogues = _load_list("dialogues")
	jobs = _load_list("jobs")
	traits = _load_list("traits")
	factions = _load_list("factions")
	ships = _load_list("ships")
	missions = _load_list("missions")
	raid_targets = _load_list("raid_targets")
	var b: Variant = _read_json(BALANCE_FILE)
	balance = b if b is Dictionary else {}
	for e in load_errors:
		GameLog.error("データ読み込み: " + e)
	return load_errors.is_empty()


func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		load_errors.append("%s: ファイルが存在しません" % path)
		return null
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		load_errors.append("%s:%d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return null
	return json.data


func _load_list(key: String) -> Dictionary:
	var out := {}
	var paths: Variant = DATA_FILES[key][0]
	if paths is String:
		paths = [paths]
	var list_key: String = DATA_FILES[key][1]
	for path in paths:
		var root: Variant = _read_json(path)
		if root == null:
			continue
		if not (root is Dictionary) or not (root.get(list_key) is Array):
			load_errors.append("%s: '%s' 配列がありません" % [path, list_key])
			continue
		for entry in root[list_key]:
			if not (entry is Dictionary) or not entry.has("id"):
				load_errors.append("%s: idのない項目があります" % path)
				continue
			var id := str(entry["id"])
			if out.has(id):
				load_errors.append("%s: ID重複 '%s'" % [path, id])
				continue
			out[id] = entry
	return out


## "survival.hunger_per_hour" のようなドット区切りでバランス値を取得する。
func bal(path: String, default: Variant = null) -> Variant:
	var cur: Variant = balance
	for part in path.split("."):
		if cur is Dictionary and cur.has(part):
			cur = cur[part]
		else:
			return default
	return cur


func item(id: String) -> Dictionary:
	return items.get(id, {})


func item_name(id: String) -> String:
	return str(items.get(id, {}).get("name", id))


func action(id: String) -> Dictionary:
	return actions.get(id, {})


func building_name(id: String) -> String:
	return str(buildings.get(id, {}).get("name", id))

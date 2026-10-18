extends TestCase
## 生成キャラクター素材（立ち絵・3Dモデル）の網羅と、無い場合のフォールバック

const EXPRESSIONS := ["normal", "smile", "sad", "angry", "surprised"]


func _player_look(d: GameData, g: String, a: int) -> Dictionary:
	var p := PlayerProfile.create_default(d)
	p.gender = g
	p.age = a
	p.appearance = PlayerProfile.default_appearance(g)
	p.finalize(d)
	return p.look(d)


func test_every_character_has_portrait_and_model() -> void:
	var d := game_data()
	for id in d.survivors:
		var aid := CharacterArt.art_id(str(id), d.survivors[id])
		for e in EXPRESSIONS:
			check(CharacterArt.portrait(aid, e) != null, "%s の立ち絵（%s）" % [id, e])
		check(CharacterArt.model_scene(aid) != null, "%s の3Dモデル" % id)
	for g in PlayerProfile.GENDERS:
		for a in [12, 17, 25, 35]:
			var look := _player_look(d, g, a)
			var aid := CharacterArt.art_id("player", look)
			check(aid.begins_with("player_%s_" % g), "主人公の素材ID %s" % aid)
			# 表情が無い場合も通常の表情で必ず表示できる
			for e in EXPRESSIONS:
				check(CharacterArt.portrait(aid, e) != null, "%s の立ち絵（%s）" % [aid, e])
			check(CharacterArt.model_scene(aid) != null, "%s の3Dモデル" % aid)


func test_generated_model_has_animations_and_light_mesh() -> void:
	var d := game_data()
	var scene := CharacterArt.model_scene(CharacterArt.art_id("mira", d.survivors["mira"]))
	check(scene != null, "モデルを読み込める")
	if scene == null:
		return
	var n := scene.instantiate()
	var ap := n.find_child("AnimationPlayer", true, false) as AnimationPlayer
	check(ap != null, "AnimationPlayer がある")
	if ap:
		for a in ["idle", "walk", "work", "rest"]:
			check(ap.has_animation(a), "アニメーション %s" % a)
	var tris := 0
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		for s in (mi as MeshInstance3D).mesh.get_surface_count():
			tris += (mi as MeshInstance3D).mesh.surface_get_array_index_len(s) / 3
	check(tris > 500 and tris <= 6000, "三角形数 %d（Android 向けに 6000 以下）" % tris)
	n.free()


func test_simple_mode_and_missing_art_fall_back() -> void:
	var d := game_data()
	var look := _player_look(d, "female", 25)
	look["art_mode"] = "simple"
	check(not CharacterArt.enabled(look), "シンプル表示では生成素材を使わない")
	check(CharacterArt.portrait("no_such_character", "normal") == null, "素材が無ければ null（図形描画にフォールバック）")
	check(CharacterArt.model_scene("") == null, "IDが空なら null")
	var m := CharacterModel.new()
	m.apply_look(look)
	m._ready()
	check(m._art == null, "シンプル表示の主人公はプリミティブ構成で描く")
	m.free()


func test_recolor_only_for_player() -> void:
	var d := game_data()
	var look := _player_look(d, "male", 17)
	var p := CharacterArt.recolor_params(look)
	check(bool(p.get("hair_recolor", false)), "主人公は髪色を置き換える")
	eq((p["hair_target"] as Color).to_html(false), Color(str(look["colors"]["hair"])).to_html(false), "選んだ髪色")
	check(CharacterArt.recolor_params(d.survivors["mira"]).is_empty(), "仲間は置き換えない")


func test_npc_art_and_leaders() -> void:
	var d := game_data()
	for id in d.npcs:
		var defn: Dictionary = d.npcs[id]
		check(CharacterArt.portrait(CharacterArt.art_id(id, defn), "normal") != null, "%s の立ち絵" % id)
		check(CharacterArt.model_scene(CharacterArt.art_id(id, defn)) != null, "%s の3Dモデル" % id)
	for id in ["volg", "drake", "martha", "lightkeeper"]:
		for e in EXPRESSIONS:
			check(CharacterArt.portrait(id, e) != null, "%s の表情 %s" % [id, e])
	# 戦闘相手（人間）には立ち絵が割り当てられている
	for eid in d.enemies:
		if str(d.enemies[eid].get("kind", "")) == "human":
			check(d.npcs.has(str(d.enemies[eid].get("portrait", ""))), "%s の立ち絵の割り当て" % eid)


func test_outfit_recolor_follows_selection() -> void:
	var d := game_data()
	var p := PlayerProfile.create_default(d)
	p.appearance = PlayerProfile.default_appearance("male")
	p.finalize(d)
	check(not CharacterArt.recolor_params(p.look(d)).has("outer_recolor"), "既定の衣装は生成素材のまま")
	p.appearance["outfit"] = "lab"
	var rc := CharacterArt.recolor_params(p.look(d))
	check(bool(rc.get("outer_recolor", false)), "衣装を変えると上着の色を置き換える")
	eq((rc["outer_target"] as Color).to_html(false), Color(str(p.look(d)["colors"]["outer"])).to_html(false), "選んだ衣装の色")


func test_player_portraits_have_outer_mask() -> void:
	# 上着（フードを含む）のマスク。無いと衣装の色が顔より下にしか反映されない
	for g in PlayerProfile.GENDERS:
		for band in ["young", "youth", "adult", "mature"]:
			for e in ["normal", "smile", "sad", "surprised"]:
				var tex := CharacterArt.portrait("player_%s_%s" % [g, band], e)
				check(CharacterArt.outer_mask(tex) != null, "player_%s_%s_%s の上着マスク" % [g, band, e])
	check(CharacterArt.outer_mask(null) == null, "立ち絵が無ければマスクも無い")

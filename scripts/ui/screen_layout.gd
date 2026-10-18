class_name ScreenLayout
extends RefCounted
## 画面の向き（横画面／縦画面）への対応。
## - 端末の向きに合わせて UI の基準解像度を切り替える（横 1280x720 / 縦 720x1280）
## - fit() で登録したパネルは、画面より大きくならないよう最小サイズを縮め、位置を付け直す
## - 向きが変わると Game.layout_changed(portrait) が送られ、HUD などが配置を切り替える

const LANDSCAPE := Vector2i(1280, 720)
const PORTRAIT := Vector2i(720, 1280)
const GROUP := "screen_fit"


static func is_portrait_size(window_size: Vector2) -> bool:
	return window_size.y > window_size.x


## ウィンドウの大きさから縦横を判定し、UI の基準解像度を設定する。縦なら true
static func apply_scale(window: Window) -> bool:
	var portrait := is_portrait_size(Vector2(window.size))
	window.content_scale_size = PORTRAIT if portrait else LANDSCAPE
	return portrait


## 現在の UI 座標系で縦画面か
static func portrait(node: Node) -> bool:
	return node.is_inside_tree() and is_portrait_size(node.get_viewport().get_visible_rect().size)


## パネルの設計上の大きさを登録する。画面に収まるよう縮め、preset で位置を付け直す
static func fit(c: Control, design: Vector2, preset := Control.PRESET_CENTER, margin := 0) -> void:
	c.set_meta("fit_design", design)
	c.set_meta("fit_preset", preset)
	c.set_meta("fit_margin", margin)
	c.add_to_group(GROUP)
	if c.is_inside_tree():
		apply(c)
	else:
		c.tree_entered.connect(apply.bind(c), CONNECT_ONE_SHOT)


static func apply(c: Control) -> void:
	if not c.is_inside_tree() or not c.has_meta("fit_design"):
		return
	var vp := c.get_viewport().get_visible_rect().size
	var d: Vector2 = c.get_meta("fit_design")
	c.custom_minimum_size = Vector2(minf(d.x, vp.x - 24.0), minf(d.y, vp.y - 160.0) if d.y > 0.0 else 0.0)
	c.size = c.custom_minimum_size
	c.set_anchors_and_offsets_preset(int(c.get_meta("fit_preset")), Control.PRESET_MODE_MINSIZE, int(c.get_meta("fit_margin")))
	c.grow_horizontal = Control.GROW_DIRECTION_BOTH


static func apply_all(tree: SceneTree) -> void:
	for n in tree.get_nodes_in_group(GROUP):
		apply(n as Control)

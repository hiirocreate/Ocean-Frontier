class_name ScreenLayout
extends RefCounted
## 画面の向き（横画面／縦画面）への対応。
## - 端末の向きに合わせて UI の基準解像度を切り替える（横 1280x720 / 縦 720x1280）
## - fit() で登録したパネルは、画面より大きくならないよう最小サイズを縮め、位置を付け直す。
##   中身がそれでも収まらない場合はパネル全体を縮小し、必ず画面内に収める（中身が変わるたびに再計算）
## - 向きが変わると Game.layout_changed(portrait) が送られ、HUD などが配置を切り替える

const LANDSCAPE := Vector2i(1280, 720)
const PORTRAIT := Vector2i(720, 1280)
const GROUP := "screen_fit"


## スクロール領域の中のボタンや枠が指の操作を受け止めてしまうと、なぞってもスクロールできない。
## スクロール領域内の部品は操作を親（スクロール領域）にも渡す設定にする（ボタンは押せるまま）
static func touch_scroll_friendly(n: Node) -> void:
	if not (n is Control) or n is ScrollContainer or n is ScrollBar or n is Range or n is LineEdit or n is TextEdit:
		return
	var c := n as Control
	if c.mouse_filter != Control.MOUSE_FILTER_STOP:
		return
	var p := c.get_parent()
	while p != null and not (p is ScrollContainer):
		p = p.get_parent()
	if p != null:
		c.mouse_filter = Control.MOUSE_FILTER_PASS


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
## shift / shift_portrait: 配置後にずらす量（横画面／縦画面。画面端のボタンを避けるため）
static func fit(c: Control, design: Vector2, preset := Control.PRESET_CENTER, margin := 0, shift := Vector2.ZERO, shift_portrait := Vector2.ZERO) -> void:
	c.set_meta("fit_design", design)
	c.set_meta("fit_shift", [shift, shift_portrait])
	c.set_meta("fit_preset", preset)
	c.set_meta("fit_margin", margin)
	c.add_to_group(GROUP)
	c.minimum_size_changed.connect(_queue_apply.bind(c))
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
	var sh: Vector2 = c.get_meta("fit_shift")[1 if is_portrait_size(vp) else 0]
	c.offset_left += sh.x
	c.offset_right += sh.x
	c.offset_top += sh.y
	c.offset_bottom += sh.y
	# 中身の最小サイズが画面に収まらなければ、配置の基準点（中央・角）を中心に全体を縮小する
	var need := c.get_combined_minimum_size()
	var room := vp - Vector2(24.0, 24.0) - Vector2.ONE * 2.0 * float(c.get_meta("fit_margin"))
	var k := minf(1.0, minf(room.x / maxf(need.x, 1.0), room.y / maxf(need.y, 1.0)))
	c.pivot_offset = c.size * Vector2(c.anchor_left, c.anchor_top)
	c.scale = Vector2(k, k)


static func _queue_apply(c: Control) -> void:
	if c.has_meta("fit_queued"):
		return
	c.set_meta("fit_queued", true)
	(func():
		c.remove_meta("fit_queued")
		apply(c)).call_deferred()


static func apply_all(tree: SceneTree) -> void:
	for n in tree.get_nodes_in_group(GROUP):
		apply(n as Control)


## 一覧と詳細の2列: 横画面では左右、縦画面では上下に並べる（side は一覧側。横画面の幅／縦画面の高さ）
static func split(box: BoxContainer, side: Control, side_w := 230.0, side_h := 170.0) -> void:
	var f := func(p: bool) -> void:
		if not is_instance_valid(box):
			return
		box.vertical = p
		side.custom_minimum_size = Vector2(0, side_h) if p else Vector2(side_w, 0)
	var game := (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Game")
	if game:
		game.layout_changed.connect(f)
		f.call(game.portrait)

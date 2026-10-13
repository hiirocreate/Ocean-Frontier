class_name UiTheme
extends RefCounted
## 共通UIテーマ。日本語フォント（Noto Sans JP, OFL）と、タッチ操作向けの大きめの部品サイズ。

const FONT_PATH := "res://assets/fonts/NotoSansJP-Regular.ttf"
const C_PANEL := Color(0.05, 0.13, 0.19, 0.88)
const C_PANEL_BORDER := Color(0.45, 0.78, 0.82, 0.55)
const C_BUTTON := Color(0.10, 0.30, 0.38, 0.95)
const C_BUTTON_HOVER := Color(0.14, 0.40, 0.48, 0.98)
const C_BUTTON_PRESSED := Color(0.85, 0.62, 0.30, 0.98)
const C_TEXT := Color(0.93, 0.96, 0.95)
const C_WARN := Color(1.0, 0.55, 0.42)
const C_OK := Color(0.55, 0.92, 0.65)
const C_GOLD := Color(0.95, 0.80, 0.45)

static var _theme: Theme


static func get_theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	if ResourceLoader.exists(FONT_PATH):
		t.default_font = load(FONT_PATH)
	else:
		GameLog.warn("日本語フォントが見つかりません: " + FONT_PATH)
	t.default_font_size = 22
	t.set_stylebox("panel", "PanelContainer", box(C_PANEL, C_PANEL_BORDER, 14))
	t.set_stylebox("panel", "Panel", box(C_PANEL, C_PANEL_BORDER, 14))
	t.set_stylebox("normal", "Button", box(C_BUTTON, Color(1, 1, 1, 0.12), 12))
	t.set_stylebox("hover", "Button", box(C_BUTTON_HOVER, Color(1, 1, 1, 0.25), 12))
	t.set_stylebox("pressed", "Button", box(C_BUTTON_PRESSED, Color(1, 1, 1, 0.3), 12))
	t.set_stylebox("disabled", "Button", box(Color(0.15, 0.18, 0.2, 0.8), Color(1, 1, 1, 0.05), 12))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", C_TEXT)
	t.set_color("font_disabled_color", "Button", Color(0.6, 0.65, 0.66))
	t.set_color("font_color", "Label", C_TEXT)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.6))
	t.set_constant("outline_size", "Label", 3)
	t.set_stylebox("background", "ProgressBar", box(Color(0, 0, 0, 0.45), Color(0, 0, 0, 0), 6, 2))
	t.set_stylebox("fill", "ProgressBar", box(C_OK, Color(0, 0, 0, 0), 6, 2))
	t.set_font_size("font_size", "ProgressBar", 14)
	t.set_stylebox("tab_selected", "TabContainer", box(C_BUTTON_PRESSED, Color(0, 0, 0, 0), 8))
	t.set_stylebox("tab_unselected", "TabContainer", box(C_BUTTON, Color(0, 0, 0, 0), 8))
	t.set_stylebox("panel", "TabContainer", StyleBoxEmpty.new())
	_theme = t
	return t


static func box(bg: Color, border: Color, radius: int, pad: int = 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2 if border.a > 0 else 0)
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad * 0.6
	s.content_margin_bottom = pad * 0.6
	return s


static func label(text: String, size: int = 22, color: Color = C_TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func button(text: String, min_size: Vector2 = Vector2(0, 64)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	return b

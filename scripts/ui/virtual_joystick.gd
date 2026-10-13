class_name VirtualJoystick
extends Control
## タッチ用仮想スティック。押した指のインデックスを追跡し、範囲外へドラッグしても入力を維持する。

var value := Vector2.ZERO
var radius := 90.0
var _touch := -1
var _knob_pos := Vector2.ZERO


func _init() -> void:
	custom_minimum_size = Vector2(radius * 2.4, radius * 2.4)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _center() -> Vector2:
	return size / 2.0


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var local: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		if event.pressed and _touch == -1 and Rect2(Vector2.ZERO, size).has_point(local):
			_touch = event.index
			_update(local)
			get_viewport().set_input_as_handled()
		elif not event.pressed and event.index == _touch:
			_touch = -1
			value = Vector2.ZERO
			_knob_pos = Vector2.ZERO
			queue_redraw()
	elif event is InputEventScreenDrag and event.index == _touch:
		_update(get_global_transform_with_canvas().affine_inverse() * event.position)
		get_viewport().set_input_as_handled()


func _update(local: Vector2) -> void:
	var d := local - _center()
	if d.length() > radius:
		d = d.normalized() * radius
	_knob_pos = d
	value = d / radius
	if value.length() < 0.12:
		value = Vector2.ZERO
	queue_redraw()


func is_active() -> bool:
	return _touch != -1


func _draw() -> void:
	var c := _center()
	draw_circle(c, radius, Color(0.05, 0.15, 0.2, 0.35))
	draw_arc(c, radius, 0, TAU, 40, Color(0.7, 0.95, 1.0, 0.45), 3.0, true)
	draw_circle(c + _knob_pos, radius * 0.42, Color(0.85, 0.95, 1.0, 0.55 if _touch != -1 else 0.35))

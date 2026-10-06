class_name Tactil
extends Control
## Joystick y botones en pantalla para jugar desde el celular o la tablet.

const BOTONES := [
	["cambio", "Cambio"], ["largo", "Largo"], ["tiro", "Tiro"],
	["correr", "Correr"], ["gambeta", "Gambeta"], ["pase", "Pase"],
	["hueco", "Al hueco"],
]

var _mv := Vector2()
var _stick_id := -1
var _stick_c := Vector2()
var _toques := {}        # índice de toque -> acción
var _held := {}


static func hay_tactil() -> bool:
	return DisplayServer.is_touchscreen_available() or OS.has_feature("web_android") or OS.has_feature("web_ios") or OS.has_feature("mobile")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for b in BOTONES:
		_held[b[0]] = false


func estado() -> Dictionary:
	var d = _held.duplicate()
	d["mv"] = _mv
	return d


func _radio() -> float:
	return clampf(minf(size.x, size.y) * 0.13, 52.0, 110.0)


func _stick_base() -> Vector2:
	return Vector2(_radio() * 1.5, size.y - _radio() * 1.5)


func _btn_pos(i: int) -> Vector2:
	var r = _radio() * 0.5
	var gap = r * 2.35
	var col = i % 3
	var fila = i / 3
	return Vector2(size.x - gap * (3 - col) + r * 0.2, size.y - gap * (3 - fila) + r * 0.3)


func _btn_at(p: Vector2) -> String:
	var r = _radio() * 0.5
	for i in BOTONES.size():
		if p.distance_to(_btn_pos(i)) < r * 1.15:
			return BOTONES[i][0]
	return ""


func _input(e: InputEvent) -> void:
	if not visible:
		return
	if e is InputEventScreenTouch:
		var t = e as InputEventScreenTouch
		if t.pressed:
			var b = _btn_at(t.position)
			if b != "":
				_toques[t.index] = b
				_held[b] = true
			elif t.position.x < size.x * 0.45 and _stick_id == -1:
				_stick_id = t.index
				_stick_c = t.position
				_mv = Vector2()
		else:
			if _toques.has(t.index):
				_held[_toques[t.index]] = false
				_toques.erase(t.index)
			if t.index == _stick_id:
				_stick_id = -1
				_mv = Vector2()
		queue_redraw()
	elif e is InputEventScreenDrag:
		var dr = e as InputEventScreenDrag
		if dr.index == _stick_id:
			var d = (dr.position - _stick_c) / _radio()
			if d.length() > 1.0:
				d = d.normalized()
			_mv = d
			queue_redraw()


func _draw() -> void:
	var r = _radio()
	var base = _stick_base() if _stick_id == -1 else _stick_c
	draw_circle(base, r, Color(0.024, 0.07, 0.13, 0.28))
	draw_arc(base, r, 0, TAU, 40, Color(0.95, 0.93, 0.88, 0.5), 2.0)
	draw_circle(base + _mv * r * 0.6, r * 0.4, Color(0.95, 0.93, 0.88, 0.55))
	var f = UI.fuente("titulo")
	for i in BOTONES.size():
		var c = _btn_pos(i)
		var k: String = BOTONES[i][0]
		var on: bool = _held[k]
		var amarillo = k in ["tiro", "pase"]
		var fill = Color(0.95, 0.71, 0.12, 0.8) if amarillo else Color(0.024, 0.07, 0.13, 0.55)
		if on:
			fill = fill.lightened(0.3)
		draw_circle(c, r * 0.5, fill)
		draw_arc(c, r * 0.5, 0, TAU, 32, Color(0.95, 0.93, 0.88, 0.9), 2.0)
		var txt: String = BOTONES[i][1]
		var fs = int(r * 0.24)
		var tw = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(f, c + Vector2(-tw / 2, fs * 0.35), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("#10223a") if amarillo else Color(0.95, 0.93, 0.88))

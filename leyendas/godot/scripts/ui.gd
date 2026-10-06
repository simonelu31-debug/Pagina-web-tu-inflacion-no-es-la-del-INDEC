class_name UI
extends RefCounted
## Colores, fuentes y piezas de interfaz compartidas.

const BG := Color("#0c2240")
const BG2 := Color("#12305a")
const LINEA := Color("#2a5585")
const TEXTO := Color("#f1ece0")
const APAGADO := Color("#a8bdd4")
const CELESTE := Color("#75aadb")
const SOL := Color("#f3b61f")
const ROJO := Color("#d0453a")

static var _f := {}


static func fuente(cual: String) -> Font:
	if _f.has(cual):
		return _f[cual]
	var path = {"titulo": "res://fonts/BigShoulders-900.woff2", "texto": "res://fonts/BigShoulders-600.woff2", "mono": "res://fonts/VT323.woff2"}[cual]
	var f: Font = load(path)
	_f[cual] = f
	return f


static func tema() -> Theme:
	var t = Theme.new()
	t.default_font = fuente("texto")
	t.default_font_size = 22
	t.set_color("font_color", "Label", TEXTO)
	var normal = StyleBoxFlat.new()
	normal.bg_color = Color(0, 0, 0, 0)
	normal.border_color = TEXTO
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(4)
	normal.content_margin_left = 16
	normal.content_margin_right = 16
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6
	var hover = normal.duplicate()
	hover.bg_color = Color(1, 1, 1, 0.08)
	var pressed = normal.duplicate()
	pressed.bg_color = TEXTO
	var focus = normal.duplicate()
	focus.border_color = SOL
	focus.set_border_width_all(3)
	focus.bg_color = Color(0, 0, 0, 0)
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("focus", "Button", focus)
	t.set_stylebox("disabled", "Button", normal)
	t.set_color("font_color", "Button", TEXTO)
	t.set_color("font_hover_color", "Button", TEXTO)
	t.set_color("font_pressed_color", "Button", BG)
	t.set_color("font_focus_color", "Button", TEXTO)
	t.set_color("font_disabled_color", "Button", APAGADO)
	t.set_font_size("font_size", "Button", 22)
	var sc = StyleBoxFlat.new()
	sc.bg_color = Color(1, 1, 1, 0.08)
	t.set_stylebox("panel", "ScrollContainer", sc)
	return t


static func label(txt: String, size := 22, color := TEXTO, cual := "texto") -> Label:
	var l = Label.new()
	l.text = txt
	l.add_theme_font_override("font", fuente(cual))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


## Botón amarillo principal con sombra, como en la versión web.
static func boton(txt: String, principal := false, size := 24) -> Button:
	var b = Button.new()
	b.text = txt
	b.add_theme_font_override("font", fuente("titulo"))
	b.add_theme_font_size_override("font_size", size)
	if principal:
		var n = StyleBoxFlat.new()
		n.bg_color = SOL
		n.set_corner_radius_all(4)
		n.shadow_color = TEXTO
		n.shadow_offset = Vector2(4, 4)
		n.shadow_size = 0
		n.content_margin_left = 24
		n.content_margin_right = 24
		n.content_margin_top = 8
		n.content_margin_bottom = 8
		var h = n.duplicate()
		h.bg_color = SOL.lightened(0.12)
		var p = n.duplicate()
		p.shadow_offset = Vector2(2, 2)
		var f = n.duplicate()
		f.border_color = TEXTO
		f.set_border_width_all(3)
		b.add_theme_stylebox_override("normal", n)
		b.add_theme_stylebox_override("hover", h)
		b.add_theme_stylebox_override("pressed", p)
		b.add_theme_stylebox_override("focus", f)
		for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(k, Color("#10223a"))
	return b


static func panel(color := Color(0.024, 0.07, 0.13, 0.86), borde := TEXTO, ancho := 2) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = borde
	s.set_border_width_all(ancho)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	return s

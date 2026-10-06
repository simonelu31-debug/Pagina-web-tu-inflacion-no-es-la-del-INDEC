class_name Menu
extends Control
## Portada, elección de equipos y planteles.

signal jugar

const TEXTO_CONTROLES := """[Flechas] mover · [Shift] correr (gasta resistencia)
Con la pelota: [S] pase · [Q] pase al hueco · [W] pase largo o centro · [D] remate (mantené para cargar; con Shift sale fuerte, sin Shift sale colocado con rosca; si además apretás W, vaselina) · [E] gambeta
Sin la pelota: [S] quite (mantené cerca del rival) · [D] barrida · [Q] presión con un compañero · [A] cambiar de jugador
Tiro libre: mantené [D] y apuntá con las flechas (arriba/abajo: palo; izquierda/derecha: comba)
Penal: mantené [D] y apuntá; atajando, elegí el lado con las flechas
[V] cambiar cámara · [P] pausa · Joystick: A pase, B remate, X al hueco, Y largo, LB cambio, RB/RT correr, LT gambeta"""

var _pantalla: Control
var _activo := "local"
var _ficha: PanelContainer


func _ready() -> void:
	theme = UI.tema()
	_ajustar()
	get_viewport().size_changed.connect(_ajustar)
	portada()


func _ajustar() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size


func _limpiar() -> void:
	for c in get_children():
		c.queue_free()
	_ficha = null


func _fondo(rayas := true) -> void:
	var bg = ColorRect.new()
	bg.color = UI.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	if rayas:
		var r = Rayas.new()
		r.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(r)


func _margen(m := 36) -> MarginContainer:
	var mc = MarginContainer.new()
	mc.set_anchors_preset(Control.PRESET_FULL_RECT)
	for k in ["left", "right", "top", "bottom"]:
		mc.add_theme_constant_override("margin_" + k, m)
	add_child(mc)
	return mc


func _seg(opciones: Array, valor: int, al_elegir: Callable) -> HBoxContainer:
	var hb = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 0)
	var botones: Array = []
	for i in opciones.size():
		var b = Button.new()
		b.text = opciones[i][0]
		b.toggle_mode = true
		b.button_pressed = opciones[i][1] == valor
		botones.append(b)
		hb.add_child(b)
	for i in botones.size():
		var b: Button = botones[i]
		var v = opciones[i][1]
		b.pressed.connect(func():
			for o in botones:
				o.button_pressed = o == b
			al_elegir.call(v))
	return hb


# =========================================================
# Portada
# =========================================================
func portada() -> void:
	_limpiar()
	_fondo()
	var mc = _margen(48)
	var cc = CenterContainer.new()
	mc.add_child(cc)
	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	vb.custom_minimum_size = Vector2(min(900, get_viewport_rect().size.x - 96), 0)
	cc.add_child(vb)
	vb.add_child(UI.label("Primera División, tabla histórica", 24, UI.APAGADO))
	var t = Control.new()
	t.custom_minimum_size = Vector2(0, 196)
	vb.add_child(t)
	for cfg in [[Vector2(8, 8), UI.SOL], [Vector2(4, 4), UI.CELESTE], [Vector2(0, 0), UI.TEXTO]]:
		var l = UI.label("Leyendas del\nfútbol argentino", 96, cfg[1], "titulo")
		l.position = cfg[0]
		l.add_theme_constant_override("line_spacing", -34)
		t.add_child(l)
	var lede = UI.label("Los 20 clubes con más puntos de la historia, armados con los mejores jugadores que pasaron por cada uno. Ahora en 3D, hecho con Godot.", 24)
	lede.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(lede)
	var sel: Dictionary = Datos.sel
	var g = GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 18)
	g.add_theme_constant_override("v_separation", 10)
	vb.add_child(g)
	g.add_child(UI.label("Duración", 24))
	g.add_child(_seg([["3 min", 3], ["5 min", 5], ["8 min", 8]], sel["minutos"], func(v): sel["minutos"] = v))
	g.add_child(UI.label("Dificultad", 24))
	g.add_child(_seg([["Amateur", 0], ["Profesional", 1], ["Leyenda", 2]], sel["dificultad"], func(v): sel["dificultad"] = v))
	g.add_child(UI.label("Cámara", 24))
	g.add_child(_seg([["Transmisión", 0], ["Cerca", 1], ["Aérea", 2]], sel["camara"], func(v): sel["camara"] = v))
	var hb = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	vb.add_child(hb)
	var go = UI.boton("Elegir equipos", true, 30)
	go.pressed.connect(equipos)
	hb.add_child(go)
	var demo = UI.boton("Ver un partido", false, 24)
	demo.tooltip_text = "La máquina juega contra la máquina"
	demo.pressed.connect(func():
		Datos.sel["auto"] = true
		jugar.emit())
	hb.add_child(demo)
	var ctl = UI.boton("Controles", false, 24)
	ctl.pressed.connect(_ver_controles)
	hb.add_child(ctl)
	var k = UI.label("Flechas mover · Shift correr · S pase · Q al hueco · W largo · D remate · E gambeta · A cambio. También con joystick y pantalla táctil.", 18, UI.APAGADO)
	k.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(k)
	go.call_deferred("grab_focus")


func _ver_controles() -> void:
	var pc = PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UI.panel(Color(UI.BG2, 0.98), UI.SOL, 2))
	add_child(pc)
	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	pc.add_child(vb)
	vb.add_child(UI.label("Controles", 44, UI.TEXTO, "titulo"))
	var t = UI.label(TEXTO_CONTROLES, 21)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size = Vector2(minf(820, size.x - 80), 0)
	vb.add_child(t)
	var ok = UI.boton("Cerrar", true, 24)
	ok.pressed.connect(pc.queue_free)
	var cc = CenterContainer.new()
	cc.add_child(ok)
	vb.add_child(cc)
	pc.reset_size()
	pc.position = (size - pc.get_combined_minimum_size()) / 2.0
	ok.call_deferred("grab_focus")


# =========================================================
# Equipos
# =========================================================
func _cabecera(titulo: String, volver: Callable, sig_txt: String, sig: Callable) -> VBoxContainer:
	var mc = _margen(28)
	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	mc.add_child(vb)
	var hb = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	vb.add_child(hb)
	var back = UI.boton("Volver", false, 22)
	back.pressed.connect(volver)
	hb.add_child(back)
	hb.add_child(UI.label(titulo, 52, UI.TEXTO, "titulo"))
	var sp = Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(sp)
	var nx = UI.boton(sig_txt, true, 28)
	nx.pressed.connect(sig)
	hb.add_child(nx)
	nx.call_deferred("grab_focus")
	return vb


func equipos() -> void:
	Datos.sel.erase("auto")
	_limpiar()
	_fondo(false)
	var vb = _cabecera("Elegí los equipos", portada, "Ver planteles", planteles)
	var hb = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 26)
	hb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(hb)
	var sc = ScrollContainer.new()
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.size_flags_stretch_ratio = 1.3
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hb.add_child(sc)
	var lista = VBoxContainer.new()
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lista.add_theme_constant_override("separation", 2)
	sc.add_child(lista)
	var der = VBoxContainer.new()
	der.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	der.add_theme_constant_override("separation", 14)
	hb.add_child(der)
	_tabla(lista)
	_slots(der)
	var src = UI.label("Puntos de la tabla histórica de Primera División (Promiedos, septiembre de 2026), con el sistema de puntos de cada época.", 16, UI.APAGADO)
	src.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	der.add_child(src)


func _tabla(lista: VBoxContainer) -> void:
	for c in lista.get_children():
		c.queue_free()
	var sel: Dictionary = Datos.sel
	var i = 0
	for e in Datos.equipos:
		i += 1
		var b = Button.new()
		b.custom_minimum_size = Vector2(0, 40)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var st = StyleBoxFlat.new()
		st.bg_color = Color(0, 0, 0, 0)
		if e["id"] == sel["local"]:
			st.bg_color = Color(UI.SOL, 0.3)
		elif e["id"] == sel["visita"]:
			st.bg_color = Color(UI.CELESTE, 0.3)
		st.border_color = UI.LINEA
		st.border_width_bottom = 1
		st.content_margin_left = 6
		var hv = st.duplicate()
		hv.bg_color = st.bg_color.lerp(Color(1, 1, 1, 0.12), 0.5)
		var fc = hv.duplicate()
		fc.border_color = UI.SOL
		fc.set_border_width_all(2)
		b.add_theme_stylebox_override("normal", st)
		b.add_theme_stylebox_override("hover", hv)
		b.add_theme_stylebox_override("pressed", hv)
		b.add_theme_stylebox_override("focus", fc)
		var row = HBoxContainer.new()
		row.set_anchors_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 8
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 12)
		b.add_child(row)
		var n = UI.label("%2d" % i, 26, UI.APAGADO, "mono")
		n.custom_minimum_size = Vector2(30, 0)
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(n)
		var ic = TextureRect.new()
		ic.texture = KitArt.shirt_icon(e["camisetas"][0], 64)
		ic.custom_minimum_size = Vector2(32, 32)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(ic)
		var nm = UI.label(e["nombre"], 22)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(nm)
		var pts = UI.label(str(int(e["puntos"])), 24, UI.TEXTO, "mono")
		pts.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(pts)
		var sp = Control.new()
		sp.custom_minimum_size = Vector2(6, 0)
		row.add_child(sp)
		var id: String = e["id"]
		b.pressed.connect(func():
			var otro: String = sel["visita"] if _activo == "local" else sel["local"]
			if id == otro:
				return
			sel[_activo] = id
			sel["kit_l" if _activo == "local" else "kit_v"] = 0
			sel["linea_l" if _activo == "local" else "linea_v"] = Datos._linea_vacia()
			_activo = "visita" if _activo == "local" else "local"
			equipos())
		lista.add_child(b)


func _slots(der: VBoxContainer) -> void:
	var sel: Dictionary = Datos.sel
	for cual in ["local", "visita"]:
		var e: Dictionary = Datos.equipo(sel[cual])
		var kk = "kit_l" if cual == "local" else "kit_v"
		var pc = PanelContainer.new()
		var st = StyleBoxFlat.new()
		st.bg_color = UI.BG2
		st.border_color = UI.SOL if _activo == cual else UI.LINEA
		st.set_border_width_all(2)
		st.set_corner_radius_all(6)
		st.content_margin_left = 16
		st.content_margin_right = 16
		st.content_margin_top = 12
		st.content_margin_bottom = 12
		if _activo == cual:
			st.shadow_color = UI.SOL
			st.shadow_offset = Vector2(4, 4)
		pc.add_theme_stylebox_override("panel", st)
		der.add_child(pc)
		var vb = VBoxContainer.new()
		pc.add_child(vb)
		var who = UI.label("Local, lo manejás vos" if cual == "local" else "Visitante, lo maneja la máquina", 18, UI.APAGADO)
		vb.add_child(who)
		vb.add_child(UI.label(e["nombre"], 38, UI.TEXTO, "titulo"))
		vb.add_child(UI.label("Esquema %s. Elegí camiseta:" % e["esquema"], 18, UI.APAGADO))
		var kits = HBoxContainer.new()
		kits.add_theme_constant_override("separation", 10)
		vb.add_child(kits)
		var ks: Array = e["camisetas"]
		for i in ks.size():
			var kb = Button.new()
			kb.icon = KitArt.shirt_icon(ks[i], 64)
			kb.text = ks[i]["name"]
			kb.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
			kb.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			kb.add_theme_font_override("font", UI.fuente("mono"))
			kb.add_theme_constant_override("icon_max_width", 46)
			kb.toggle_mode = true
			kb.button_pressed = sel[kk] == i
			kb.pressed.connect(func():
				sel[kk] = i
				equipos())
			kits.add_child(kb)
		var cambiar = Button.new()
		cambiar.text = "Elegir este equipo en la tabla" if _activo != cual else "Elegí el club en la tabla ←"
		cambiar.flat = true
		cambiar.add_theme_color_override("font_color", UI.APAGADO)
		cambiar.pressed.connect(func():
			_activo = cual
			equipos())
		vb.add_child(cambiar)


# =========================================================
# Planteles
# =========================================================
func planteles() -> void:
	_limpiar()
	_fondo(false)
	var vb = _cabecera("Planteles", equipos, "Al campo", func(): jugar.emit())
	var leg = UI.label("Cada puesto tiene titular y suplente. Tocá ⇄ para que entre el suplente. Tocá un jugador para ver su ficha.", 18, UI.APAGADO)
	leg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(leg)
	var sc = ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(sc)
	var hb = HBoxContainer.new()
	hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_theme_constant_override("separation", 30)
	sc.add_child(hb)
	var sel: Dictionary = Datos.sel
	for cual in ["local", "visita"]:
		var e: Dictionary = Datos.equipo(sel[cual])
		var linea: Array = sel["linea_l" if cual == "local" else "linea_v"]
		var kit: Dictionary = e["camisetas"][sel["kit_l" if cual == "local" else "kit_v"]]
		var col = VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 0)
		hb.add_child(col)
		col.add_child(UI.label(e["nombre"], 34, UI.TEXTO, "titulo"))
		col.add_child(UI.label(("Local" if cual == "local" else "Visitante") + ", " + e["esquema"], 18, UI.APAGADO))
		var js: Array = e["jugadores"]
		for i in 11:
			var sup: bool = linea[i] == 1
			var a: Dictionary = js[i + 11] if sup else js[i]
			var b: Dictionary = js[i] if sup else js[i + 11]
			var k: Dictionary = Datos.kits_arquero[0 if cual == "local" else 1] if a["pos"] == "ARQ" else kit
			col.add_child(_fila(a, b, k, linea, i))
	if _ficha == null:
		_ficha = PanelContainer.new()
		_ficha.add_theme_stylebox_override("panel", UI.panel(Color(UI.BG2, 0.97), UI.SOL, 2))
		_ficha.visible = false
		_ficha.set_anchors_preset(Control.PRESET_CENTER)
		add_child(_ficha)


func _fila(a: Dictionary, b: Dictionary, k: Dictionary, linea: Array, i: int) -> Control:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.custom_minimum_size = Vector2(0, 58)
	var r = Retrato.new()
	r.d = a
	r.kit = k
	r.custom_minimum_size = Vector2(44, 52)
	row.add_child(r)
	var info = Button.new()
	info.flat = true
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.custom_minimum_size = Vector2(0, 52)
	info.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var iv = VBoxContainer.new()
	iv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	iv.add_theme_constant_override("separation", -4)
	iv.set_anchors_preset(Control.PRESET_FULL_RECT)
	info.add_child(iv)
	var nm = UI.label(a["n"], 21)
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	iv.add_child(nm)
	var esp = []
	for x in a["esp"]:
		esp.append(Datos.ESPECIALIDADES[x].to_lower())
	var ps = UI.label(a["pos"] + (" · " + ", ".join(esp) if not esp.is_empty() else ""), 16, UI.APAGADO)
	ps.mouse_filter = Control.MOUSE_FILTER_IGNORE
	iv.add_child(ps)
	info.pressed.connect(func(): _mostrar_ficha(a))
	row.add_child(info)
	var md = UI.label(str(int(a["o"])), 30, UI.TEXTO, "mono")
	row.add_child(md)
	var sw = Button.new()
	sw.text = "⇄"
	sw.custom_minimum_size = Vector2(44, 38)
	sw.tooltip_text = "Poner a %s de titular" % b["n"]
	sw.pressed.connect(func():
		linea[i] = 0 if linea[i] == 1 else 1
		planteles())
	row.add_child(sw)
	var bk = VBoxContainer.new()
	bk.custom_minimum_size = Vector2(170, 0)
	bk.add_theme_constant_override("separation", -6)
	bk.add_child(UI.label("Suplente", 15, UI.APAGADO))
	bk.add_child(UI.label("%s %d" % [b["n"], int(b["o"])], 17))
	row.add_child(bk)
	var holder = VBoxContainer.new()
	holder.add_theme_constant_override("separation", 0)
	holder.add_child(row)
	var sep = ColorRect.new()
	sep.color = UI.LINEA
	sep.custom_minimum_size = Vector2(0, 1)
	holder.add_child(sep)
	return holder


func _mostrar_ficha(j: Dictionary) -> void:
	for c in _ficha.get_children():
		c.queue_free()
	var vb = VBoxContainer.new()
	vb.custom_minimum_size = Vector2(420, 0)
	_ficha.add_child(vb)
	var hb = HBoxContainer.new()
	vb.add_child(hb)
	var t = UI.label(j["n"], 34, UI.TEXTO, "titulo")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(t)
	hb.add_child(UI.label(str(int(j["o"])), 40, UI.SOL, "mono"))
	vb.add_child(UI.label(Datos.PUESTOS.get(j["pos"], j["pos"]), 20, UI.APAGADO))
	for at in Datos.ATRIBUTOS if j["pos"] != "ARQ" else [["arq", "Arquero"], ["vel", "Velocidad"], ["pas", "Pase"], ["fis", "Físico"]]:
		var r = HBoxContainer.new()
		var l = UI.label(at[1], 20)
		l.custom_minimum_size = Vector2(120, 0)
		r.add_child(l)
		var v: float = j[at[0]]
		var bar = ProgressBar.new()
		bar.min_value = 0
		bar.max_value = 99
		bar.value = v
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(220, 14)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var fill = StyleBoxFlat.new()
		fill.bg_color = UI.SOL if v >= 85 else (UI.CELESTE if v >= 70 else UI.APAGADO)
		var bgs = StyleBoxFlat.new()
		bgs.bg_color = Color(1, 1, 1, 0.1)
		bar.add_theme_stylebox_override("fill", fill)
		bar.add_theme_stylebox_override("background", bgs)
		r.add_child(bar)
		r.add_child(UI.label(" %d" % int(v), 22, UI.TEXTO, "mono"))
		vb.add_child(r)
	if not j["esp"].is_empty():
		var esp = []
		for x in j["esp"]:
			esp.append(Datos.ESPECIALIDADES[x])
		var e = UI.label("Especialidades: " + ", ".join(esp), 20, UI.SOL)
		vb.add_child(e)
		var expl = UI.label(_explica(j["esp"]), 16, UI.APAGADO)
		expl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		expl.custom_minimum_size = Vector2(420, 0)
		vb.add_child(expl)
	var ok = UI.boton("Cerrar", true, 22)
	ok.pressed.connect(func(): _ficha.visible = false)
	var cc = CenterContainer.new()
	cc.add_child(ok)
	vb.add_child(cc)
	_ficha.visible = true
	_ficha.reset_size()
	_ficha.position = (size - _ficha.size) / 2.0
	ok.call_deferred("grab_focus")


func _explica(esp: Array) -> String:
	var t = {
		"tl": "Tiros libres y penales más precisos y con más comba.",
		"gam": "Su amague deja más rivales en el camino y cuesta más quitarle la pelota.",
		"cab": "Salta más alto y cabecea con más fuerza y dirección.",
		"pot": "Su remate sale más rápido y con caída.",
		"vis": "Pases y pases al hueco más precisos.",
		"vel": "Más rápido que el resto en su puesto.",
		"muro": "Más efectivo en el quite y la barrida.",
		"arq": "Más reflejos y alcance para atajar.",
	}
	var a = []
	for e in esp:
		a.append(t[e])
	return " ".join(a)


# =========================================================
# Piezas dibujadas
# =========================================================
class Rayas:
	extends Control

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var x = 0.0
		var i = 0
		while x < size.x:
			draw_rect(Rect2(x, 0, 90, size.y), Color(0.047, 0.133, 0.251) if i % 2 == 0 else Color(0.055, 0.15, 0.275))
			x += 90
			i += 1


class Retrato:
	extends Control
	var d: Dictionary
	var kit: Dictionary

	func _draw() -> void:
		draw_rect(Rect2(Vector2(), size), Color(1, 1, 1, 0.07))
		var W = size.x
		var sc = 58.0
		var sx = W / 2.0
		var sy = size.y * 0.36 + 1.67 * sc
		var skin = Color(Jugador3D.PIEL[clampi(int(d["sk"]), 0, 3)])
		# brazos y torso
		for s in [-1.0, 1.0]:
			var ax = sx + s * 0.31 * sc
			var ay = sy - 1.43 * sc
			draw_rect(Rect2(ax - 0.07 * sc, ay, 0.14 * sc, 0.2 * sc), Color(kit["base"]))
			draw_rect(Rect2(ax - 0.06 * sc, ay + 0.2 * sc, 0.12 * sc, 0.24 * sc), skin)
		var tx = sx - 0.26 * sc
		var ty = sy - 1.5 * sc
		var tex = KitArt.torso_texture(kit)
		draw_texture_rect_region(tex, Rect2(tx, ty, 0.52 * sc, 0.54 * sc), Rect2(64, 0, 128, 96))
		draw_rect(Rect2(sx - 0.1 * sc, ty, 0.2 * sc, 0.05 * sc), Color(kit["collar"]))
		var hx = sx
		var hy = sy - 1.67 * sc
		var r = 0.16 * sc
		draw_rect(Rect2(hx - 0.06 * sc, hy + r * 0.6, 0.12 * sc, 0.12 * sc), skin)
		draw_circle(Vector2(hx, hy), r, skin)
		draw_rect(Rect2(hx - r * 0.42, hy - r * 0.05, r * 0.16, r * 0.16), Color("#1b130e"))
		draw_rect(Rect2(hx + r * 0.26, hy - r * 0.05, r * 0.16, r * 0.16), Color("#1b130e"))
		var hc = Color(d["hc"])
		match d["hs"]:
			"corto", "peinado":
				_cap(hx, hy, r, hc)
				if d["hs"] == "peinado":
					draw_rect(Rect2(hx - r * 1.02, hy - r * 0.4, r * 0.3, r * 0.5), hc)
					draw_rect(Rect2(hx + r * 0.72, hy - r * 0.4, r * 0.3, r * 0.5), hc)
			"rizado":
				var a = PI * 0.9
				while a <= PI * 2.1:
					draw_circle(Vector2(hx + cos(a) * r * 0.92, hy + sin(a) * r * 0.92 - r * 0.05), r * 0.42, hc)
					a += 0.32
				_cap(hx, hy, r, hc)
			"largo":
				_cap(hx, hy, r, hc)
				draw_rect(Rect2(hx - r * 1.08, hy - r * 0.3, r * 0.42, r * 1.55), hc)
				draw_rect(Rect2(hx + r * 0.66, hy - r * 0.3, r * 0.42, r * 1.55), hc)
			"entradas":
				draw_circle(Vector2(hx - r * 0.8, hy - r * 0.15), r * 0.36, hc)
				draw_circle(Vector2(hx + r * 0.8, hy - r * 0.15), r * 0.36, hc)
		if d["band"]:
			draw_rect(Rect2(hx - r * 1.04, hy - r * 0.6, r * 2.08, r * 0.26), Color("#f4f1ea"))
		if d["mus"]:
			draw_rect(Rect2(hx - r * 0.38, hy + r * 0.3, r * 0.76, r * 0.16), hc)

	func _cap(hx: float, hy: float, r: float, c: Color) -> void:
		var pts = PackedVector2Array()
		var a = PI * 1.02
		while a <= PI * 1.98:
			pts.append(Vector2(hx + cos(a) * r * 1.04, hy - r * 0.06 + sin(a) * r * 1.04))
			a += 0.08
		draw_colored_polygon(pts, c)

class_name Partido
extends Node3D
## Escena del partido: corre el motor (Sim) a 60 pasos por segundo, dibuja
## todo en 3D, maneja la cámara, la repetición de los goles y el HUD.

signal terminado(destino: String)   # "equipos", "revancha" o "menu"

const DT := 1.0 / 60.0
const HIST_MAX := 480
const CAMARAS := ["Transmisión", "Cerca", "Aérea"]
const VIS_PELOTA := 1.9     # la pelota se dibuja más grande para que se vea
const VIS_JUGADOR := 1.1

var sim: Sim
var est: Estadio
var son: Sonido
var opts: Dictionary
var vistas := {}
var pelota: MeshInstance3D
var pelota_sombra: MeshInstance3D
var cam: Camera3D
var cam_modo := 0
var cam_x := 0.0
var acc := 0.0
var pausado := false
var fin := false
var _prev_ball := Vector3()

# repetición
var hist: Array = []
var frame_n := 0
var gol_n := -1
var rep_activa := false
var rep_frames: Array = []
var rep_i := 0.0
var rep_hecha := true

# HUD
var hud: CanvasLayer
var lbl_local: Label
var lbl_visita: Label
var lbl_reloj: Label
var chip_l: ColorRect
var chip_v: ColorRect
var lbl_msg: Label
var capa: Control
var capa_box: VBoxContainer
var banner_rep: Label
var marcas: Control
var radar: Control
var tactil: Tactil
var lbl_cam: Label
var _tactil_prev := {}
var tarjeta: ColorRect


func iniciar(o: Dictionary) -> void:
	opts = o
	sim = Sim.new()
	var home: Dictionary = Datos.equipo(o["local"])
	var away: Dictionary = Datos.equipo(o["visita"])
	sim.setup({"home": home, "away": away, "kit_h": o["kit_l"], "kit_a": o["kit_v"], "line_h": o["linea_l"], "line_a": o["linea_v"], "min": o["minutos"], "diff": o["dificultad"], "datos": Datos, "seed": randi()})
	sim.auto = o.get("auto", false)
	cam_modo = o.get("camara", 0)
	son = Sonido.new()
	add_child(son)
	est = Estadio.new()
	add_child(est)
	est.build(sim.T[0].kit, sim.T[1].kit, UI.fuente("titulo"))
	var fnum = UI.fuente("titulo")
	for S in sim.T:
		for p in S.ps:
			var v = Jugador3D.new()
			v.build(p.d, S.gk_kit if p.gk else S.kit, p.num, fnum)
			v.scale = Vector3.ONE * VIS_JUGADOR
			add_child(v)
			vistas[p] = v
	_pelota()
	cam = Camera3D.new()
	cam.fov = 34
	cam.far = 400
	add_child(cam)
	cam.current = true
	cam_x = 0.0
	_hud()
	son.iniciar_ambiente()
	_actualizar_vistas(0.0)
	_camara(1.0, true)


func w(x: float, y: float, z := 0.0) -> Vector3:
	return Vector3(x - Sim.L / 2.0, z, y - Sim.W / 2.0)


func _pelota() -> void:
	pelota = MeshInstance3D.new()
	var sp = SphereMesh.new()
	sp.radius = Sim.BR
	sp.height = Sim.BR * 2
	sp.radial_segments = 16
	sp.rings = 8
	pelota.mesh = sp
	var m = StandardMaterial3D.new()
	m.albedo_texture = KitArt.ball_texture()
	m.roughness = 0.55
	pelota.material_override = m
	pelota.scale = Vector3.ONE * VIS_PELOTA
	add_child(pelota)
	pelota_sombra = MeshInstance3D.new()
	var q = QuadMesh.new()
	q.size = Vector2(0.42, 0.42)
	pelota_sombra.mesh = q
	var sm = StandardMaterial3D.new()
	sm.albedo_texture = KitArt.blob_texture()
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pelota_sombra.material_override = sm
	pelota_sombra.rotation.x = -PI / 2.0
	pelota_sombra.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(pelota_sombra)


# =========================================================
# Bucle
# =========================================================
func _process(delta: float) -> void:
	if sim == null:
		return
	delta = minf(delta, 0.1)
	if pausado:
		_hud_update()
		return
	if rep_activa:
		_repeticion(delta)
		_hud_update()
		return
	_leer_entrada()
	acc += delta
	var pasos = 0
	while acc >= DT and pasos < 5:
		sim.step(DT)
		pasos += 1
		acc -= DT
		_grabar()
		_eventos()
		if sim.state != "juego":
			for k in ["pass_p", "long_p", "thru_p", "switch_p", "feint_p", "shoot_p"]:
				sim.inp[k] = false
	if pasos == 5:
		acc = 0.0
	_actualizar_vistas(delta)
	_camara(delta)
	_hud_update()
	# fin de la celebración: repetición
	if sim.state == "gol" and sim.st_t <= 0.0 and not rep_hecha:
		_empezar_repeticion()
	if sim.state == "gol":
		son.tension(1.0)
	elif sim.b_owner and sim.prog(sim.T[sim.b_owner.side], sim.b_pos.x) > 0.78:
		son.tension(0.55)
	else:
		son.tension(0.0)


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("pausa"):
		alternar_pausa()
		get_viewport().set_input_as_handled()
	elif e.is_action_pressed("camara"):
		cambiar_camara()
	elif rep_activa and (e.is_action_pressed("pase") or e.is_action_pressed("tiro") or e.is_action_pressed("largo")):
		_terminar_repeticion()


func _leer_entrada() -> void:
	var I = sim.inp
	var mv = Input.get_vector("izq", "der", "arr", "abj")
	var t = tactil.estado() if tactil and tactil.visible else {}
	if not t.is_empty():
		mv += t["mv"]
	if mv.length() > 1.0:
		mv = mv.normalized()
	I["mv"] = mv
	var held = func(a: String, k: String) -> bool:
		return Input.is_action_pressed(a) or (not t.is_empty() and t[k])
	var edge = func(a: String, k: String) -> bool:
		var tp: bool = not t.is_empty() and t[k] and not _tactil_prev.get(k, false)
		return Input.is_action_just_pressed(a) or tp
	I["sprint"] = held.call("correr", "correr")
	I["shoot"] = held.call("tiro", "tiro")
	I["pass"] = held.call("pase", "pase")
	I["long"] = held.call("largo", "largo")
	I["thru"] = held.call("hueco", "hueco")
	if edge.call("pase", "pase"):
		I["pass_p"] = true
	if edge.call("largo", "largo"):
		I["long_p"] = true
	if edge.call("hueco", "hueco"):
		I["thru_p"] = true
	if edge.call("cambio", "cambio"):
		I["switch_p"] = true
	if edge.call("gambeta", "gambeta"):
		I["feint_p"] = true
	if edge.call("tiro", "tiro"):
		I["shoot_p"] = true
	if not t.is_empty():
		_tactil_prev = t.duplicate()


# =========================================================
# Vistas 3D
# =========================================================
func _estado_de(p: Sim.Jug) -> Dictionary:
	return {
		"pos": w(p.pos.x, p.pos.y), "face": p.face, "spd": p.vel.length(), "anim": p.anim,
		"act": p.act, "act_t": p.act_t, "act_dir": p.act_dir, "act_h": p.act_h, "sprint": p.sprint,
	}


func _grabar() -> void:
	var ps = {}
	for S in sim.T:
		for p in S.ps:
			ps[p] = _estado_de(p)
	hist.append({"n": frame_n, "ps": ps, "b": w(sim.b_pos.x, sim.b_pos.y, sim.b_z)})
	frame_n += 1
	if hist.size() > HIST_MAX:
		hist.pop_front()


func _actualizar_vistas(delta: float) -> void:
	var hum = sim.human if not sim.auto else null
	for p in vistas:
		var v: Jugador3D = vistas[p]
		if p.off:
			v.visible = false
			continue
		v.pose(_estado_de(p), delta)
		v.marca.visible = p == hum and sim.state != "gol"
	_poner_pelota(w(sim.b_pos.x, sim.b_pos.y, sim.b_z), sim.b_spin, delta)


func _poner_pelota(bp: Vector3, spin: float, delta: float) -> void:
	var d = bp - _prev_ball
	d.y = 0
	var dist = d.length()
	if dist > 0.0001 and dist < 3.0:
		var axis = Vector3(d.z, 0, -d.x).normalized()
		pelota.transform.basis = Basis(axis, dist / (Sim.BR * VIS_PELOTA)) * pelota.transform.basis
	if absf(spin) > 0.5 and bp.y > 0.05:
		pelota.transform.basis = Basis(Vector3.UP, spin * delta * 2.0) * pelota.transform.basis
	pelota.transform.basis = pelota.transform.basis.orthonormalized().scaled(Vector3.ONE * VIS_PELOTA)
	pelota.position = bp + Vector3(0, Sim.BR * VIS_PELOTA, 0)
	pelota_sombra.position = Vector3(bp.x, 0.025, bp.z)
	var s = 1.0 + bp.y * 0.35
	pelota_sombra.scale = Vector3(s, s, s)
	_prev_ball = bp


# =========================================================
# Cámara
# =========================================================
func cambiar_camara() -> void:
	cam_modo = (cam_modo + 1) % CAMARAS.size()
	Datos.sel["camara"] = cam_modo
	if lbl_cam:
		lbl_cam.text = "Cámara: " + CAMARAS[cam_modo]
		lbl_cam.modulate.a = 1.0
		var tw = create_tween()
		tw.tween_interval(1.2)
		tw.tween_property(lbl_cam, "modulate:a", 0.0, 0.5)


func _camara(delta: float, instant := false) -> void:
	var b = w(sim.b_pos.x, sim.b_pos.y, sim.b_z)
	var lead = sim.b_vel.x * 0.35
	var lim = 33.0 if cam_modo == 0 else (40.0 if cam_modo == 1 else 30.0)
	var tx = clampf(b.x + lead, -lim, lim)
	var k = 1.0 if instant else minf(1.0, delta * (2.2 if cam_modo != 1 else 3.0))
	cam_x = lerpf(cam_x, tx, k)
	var pos: Vector3
	var mira: Vector3
	match cam_modo:
		0:
			pos = Vector3(cam_x, 17.0, 47.0 + b.z * 0.2)
			mira = Vector3(cam_x, 0.0, b.z * 0.55 + 2.0)
			cam.fov = 31
		1:
			pos = Vector3(cam_x, 11.5, b.z * 0.55 + 27.0)
			mira = Vector3(cam_x, 0.5, b.z * 0.7 + 1.0)
			cam.fov = 42
		_:
			pos = Vector3(cam_x * 0.9, 62.0, b.z * 0.3 + 30.0)
			mira = Vector3(cam_x * 0.9, 0.0, b.z * 0.3 + 1.0)
			cam.fov = 40
	if instant:
		cam.position = pos
	else:
		cam.position = cam.position.lerp(pos, minf(1.0, delta * 3.0))
	cam.look_at(mira)


# =========================================================
# Repetición
# =========================================================
func _empezar_repeticion() -> void:
	rep_frames = []
	for f in hist:
		if f["n"] >= gol_n - 190 and f["n"] <= gol_n + 35:
			rep_frames.append(f)
	if rep_frames.size() < 30 or opts.get("sin_repeticion", false):
		_terminar_repeticion()
		return
	rep_activa = true
	rep_i = 0.0
	banner_rep.visible = true
	_ocultar_capa()
	var f0: Dictionary = rep_frames[0]
	_prev_ball = f0["b"]


func _repeticion(delta: float) -> void:
	var idx = int(rep_i)
	if idx >= rep_frames.size() - 1:
		_terminar_repeticion()
		return
	var f: Dictionary = rep_frames[idx]
	var lento: bool = f["n"] > gol_n - 75
	rep_i += delta * 60.0 * (0.42 if lento else 1.0)
	var ps: Dictionary = f["ps"]
	for p in vistas:
		var v: Jugador3D = vistas[p]
		if ps.has(p):
			v.visible = true
			v.pose(ps[p], delta)
			v.marca.visible = false
		else:
			v.visible = false
	var bp: Vector3 = f["b"]
	_poner_pelota(bp, 0.0, delta)
	# cámara detrás del arco, del lado del gol
	var lado = 1.0 if (rep_frames[rep_frames.size() - 1]["b"] as Vector3).x > 0 else -1.0
	var pos = Vector3(lado * 70.0, 9.0, bp.z * 0.5 + 10.0 * -signf(bp.z + 0.01))
	cam.position = cam.position.lerp(pos, minf(1.0, delta * 2.0)) if rep_i > 2.0 else pos
	cam.fov = 26
	cam.look_at(bp + Vector3(0, 0.6, 0))


func _terminar_repeticion() -> void:
	rep_activa = false
	rep_hecha = true
	banner_rep.visible = false
	sim.hold_after_goal = false
	est.festejo(true, 0.0)
	est.festejo(false, 0.0)
	_ocultar_capa()
	for p in vistas:
		vistas[p].visible = not p.off
	_camara(1.0, true)


# =========================================================
# Eventos del motor
# =========================================================
func _eventos() -> void:
	for e in sim.events:
		match e["t"]:
			"silbato", "falta":
				son.play("silbato")
			"pase":
				son.play("patada", -4.0, randf_range(0.9, 1.1))
			"remate":
				son.play("remate", 0.0, randf_range(0.9, 1.05))
			"cabezazo":
				son.play("cabezazo", -2.0)
			"quite":
				son.play("quite", -6.0)
			"palo":
				son.play("palo", -2.0)
				son.play("uh", -3.0)
			"atajada":
				son.play("uh", -2.0)
			"pique":
				if e.get("v", 0.0) > 3.5:
					son.play("pique", -12.0)
			"tarjeta":
				_mostrar_tarjeta(e["color"])
			"gol":
				_gol(e["side"])
			"entretiempo":
				son.play("silbato_largo")
				_resumen("Entretiempo", [["Segundo tiempo", _segundo_tiempo]])
			"final":
				son.play("silbato")
				get_tree().create_timer(0.45).timeout.connect(func(): son.play("silbato"))
				get_tree().create_timer(0.9).timeout.connect(func(): son.play("silbato_largo"))
				fin = true
				_resumen("Final", [["Revancha", func(): terminado.emit("revancha")], ["Cambiar equipos", func(): terminado.emit("equipos")]])
	sim.events.clear()


func _gol(side: int) -> void:
	son.play("gol", 2.0)
	son.play("red", -2.0)
	gol_n = frame_n - 1
	rep_hecha = false
	sim.hold_after_goal = true
	var b = w(sim.b_pos.x, sim.b_pos.y, sim.b_z)
	est.sacudir_red(1 if b.x > 0 else 0, b, 0.55)
	est.festejo(side == 0, 1.0)
	var lg: Dictionary = sim.last_goal
	_capa_mensaje("¡Gooool!", lg["name"], "%s %d - %d %s" % [sim.T[0].team["codigo"], sim.score[0], sim.score[1], sim.T[1].team["codigo"]], true)


func _segundo_tiempo() -> void:
	_ocultar_capa()
	sim.second_half()


func _volver_a_pausa() -> void:
	pausado = false
	alternar_pausa()


func _alternar_sonido(b: Button) -> void:
	son.muted = not son.muted
	b.text = "Sin sonido" if son.muted else "Sonido"


func alternar_pausa() -> void:
	if fin or sim.state in ["entretiempo", "final"]:
		return
	pausado = not pausado
	if pausado:
		_resumen("Pausa", [["Seguir jugando", func(): alternar_pausa()], ["Controles", func(): _controles()], ["Abandonar partido", func(): terminado.emit("equipos")]])
	else:
		_ocultar_capa()


# =========================================================
# HUD
# =========================================================
func _hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)
	var root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UI.tema()
	hud.add_child(root)
	var ajustar = func():
		root.position = Vector2.ZERO
		root.size = get_viewport().get_visible_rect().size
	ajustar.call()
	get_viewport().size_changed.connect(ajustar)

	marcas = Marcas.new()
	marcas.partido = self
	marcas.set_anchors_preset(Control.PRESET_FULL_RECT)
	marcas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(marcas)

	var sb = PanelContainer.new()
	sb.add_theme_stylebox_override("panel", UI.panel(Color(0.024, 0.07, 0.13, 0.86), UI.TEXTO, 2))
	sb.position = Vector2(14, 12)
	root.add_child(sb)
	var hb = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	sb.add_child(hb)
	chip_l = ColorRect.new()
	chip_l.custom_minimum_size = Vector2(9, 24)
	chip_l.color = Color(sim.T[0].kit["base"])
	hb.add_child(chip_l)
	lbl_local = UI.label("", 32, UI.TEXTO, "mono")
	hb.add_child(lbl_local)
	lbl_visita = UI.label("", 32, UI.TEXTO, "mono")
	hb.add_child(lbl_visita)
	chip_v = ColorRect.new()
	chip_v.custom_minimum_size = Vector2(9, 24)
	chip_v.color = Color(sim.T[1].kit["base"])
	hb.add_child(chip_v)
	var rel = PanelContainer.new()
	rel.add_theme_stylebox_override("panel", UI.panel(UI.TEXTO, UI.TEXTO, 0))
	hb.add_child(rel)
	lbl_reloj = UI.label("00'", 32, Color("#06121f"), "mono")
	rel.add_child(lbl_reloj)

	lbl_msg = UI.label("", 30, UI.SOL, "mono")
	var mp = PanelContainer.new()
	mp.add_theme_stylebox_override("panel", UI.panel(Color(0.024, 0.07, 0.13, 0.86), Color(0, 0, 0, 0), 0))
	mp.position = Vector2(14, 64)
	mp.add_child(lbl_msg)
	mp.name = "msg"
	root.add_child(mp)

	tarjeta = ColorRect.new()
	tarjeta.size = Vector2(22, 30)
	tarjeta.position = Vector2(14, 108)
	tarjeta.visible = false
	root.add_child(tarjeta)

	radar = Radar.new()
	radar.partido = self
	radar.anchor_left = 1.0
	radar.anchor_right = 1.0
	radar.offset_left = -194
	radar.offset_right = -14
	radar.offset_top = 12
	radar.offset_bottom = 12 + 180 * 68.0 / 105.0
	radar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(radar)

	banner_rep = UI.label("● REPETICIÓN", 30, UI.TEXTO, "mono")
	banner_rep.anchor_left = 1.0
	banner_rep.anchor_right = 1.0
	banner_rep.offset_left = -230
	banner_rep.offset_top = 140
	banner_rep.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	banner_rep.add_theme_constant_override("shadow_offset_x", 2)
	banner_rep.add_theme_constant_override("shadow_offset_y", 2)
	banner_rep.visible = false
	root.add_child(banner_rep)

	lbl_cam = UI.label("", 26, UI.TEXTO, "mono")
	lbl_cam.anchor_left = 0.5
	lbl_cam.anchor_right = 0.5
	lbl_cam.offset_left = -150
	lbl_cam.offset_right = 150
	lbl_cam.offset_top = 14
	lbl_cam.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_cam.modulate.a = 0.0
	root.add_child(lbl_cam)

	var bb = HBoxContainer.new()
	bb.anchor_left = 1.0
	bb.anchor_right = 1.0
	bb.anchor_top = 1.0
	bb.anchor_bottom = 1.0
	bb.offset_left = -330
	bb.offset_right = -12
	bb.offset_top = -48
	bb.offset_bottom = -10
	bb.alignment = BoxContainer.ALIGNMENT_END
	bb.add_theme_constant_override("separation", 8)
	root.add_child(bb)
	for par in [["Cámara", func(): cambiar_camara()], ["Sonido", Callable()], ["Pausa", func(): alternar_pausa()]]:
		var b = Button.new()
		b.text = par[0]
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_override("font", UI.fuente("mono"))
		b.add_theme_font_size_override("font_size", 24)
		var stb = UI.panel(Color(0.024, 0.07, 0.13, 0.8), UI.TEXTO, 2)
		b.add_theme_stylebox_override("normal", stb)
		b.add_theme_stylebox_override("hover", stb)
		b.add_theme_stylebox_override("pressed", stb)
		b.add_theme_color_override("font_pressed_color", UI.SOL)
		bb.add_child(b)
		if par[0] == "Sonido":
			b.pressed.connect(_alternar_sonido.bind(b))
		else:
			b.pressed.connect(par[1])

	tactil = Tactil.new()
	tactil.set_anchors_preset(Control.PRESET_FULL_RECT)
	tactil.visible = Tactil.hay_tactil()
	root.add_child(tactil)

	capa = Control.new()
	capa.set_anchors_preset(Control.PRESET_FULL_RECT)
	capa.mouse_filter = Control.MOUSE_FILTER_STOP
	capa.visible = false
	root.add_child(capa)
	var bg = ColorRect.new()
	bg.name = "fondo"
	bg.color = Color(0.016, 0.055, 0.1, 0.76)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	capa.add_child(bg)
	var cc = CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	capa.add_child(cc)
	capa_box = VBoxContainer.new()
	capa_box.alignment = BoxContainer.ALIGNMENT_CENTER
	capa_box.add_theme_constant_override("separation", 8)
	cc.add_child(capa_box)


func _hud_update() -> void:
	lbl_local.text = "%s %d" % [sim.T[0].team["codigo"], sim.score[0]]
	lbl_visita.text = "%d %s" % [sim.score[1], sim.T[1].team["codigo"]]
	lbl_reloj.text = "%02d'" % sim.cur_min()
	var mp: Control = lbl_msg.get_parent()
	mp.visible = sim.msg_t > 0.0 and sim.msg != "" and not rep_activa
	lbl_msg.text = sim.msg
	marcas.queue_redraw()
	radar.queue_redraw()


func _mostrar_tarjeta(c: String) -> void:
	tarjeta.color = Color("#f3d21f") if c == "amarilla" else Color("#d0202a")
	tarjeta.visible = true
	get_tree().create_timer(2.0).timeout.connect(func(): tarjeta.visible = false)


func _limpiar_capa() -> void:
	for c in capa_box.get_children():
		c.queue_free()


func _ocultar_capa() -> void:
	capa.visible = false
	_limpiar_capa()


func _grande(txt: String) -> Label:
	var l = UI.label(txt, 120, UI.SOL, "titulo")
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_shadow_color", Color("#b83228"))
	l.add_theme_constant_override("shadow_offset_x", 5)
	l.add_theme_constant_override("shadow_offset_y", 5)
	return l


func _capa_mensaje(titulo: String, sub: String, res: String, clara: bool) -> void:
	_limpiar_capa()
	capa.visible = true
	capa.mouse_filter = Control.MOUSE_FILTER_IGNORE if clara else Control.MOUSE_FILTER_STOP
	capa.get_node("fondo").visible = not clara
	capa_box.add_child(_grande(titulo))
	if sub != "":
		var s = UI.label(sub, 36, UI.TEXTO, "titulo")
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		s.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		s.add_theme_constant_override("shadow_offset_x", 2)
		s.add_theme_constant_override("shadow_offset_y", 2)
		capa_box.add_child(s)
	var r = UI.label(res, 56, UI.TEXTO, "mono")
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	r.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	r.add_theme_constant_override("shadow_offset_x", 2)
	r.add_theme_constant_override("shadow_offset_y", 2)
	capa_box.add_child(r)


func _resumen(titulo: String, botones: Array) -> void:
	var res = "%s %d - %d %s" % [sim.T[0].team["codigo"], sim.score[0], sim.score[1], sim.T[1].team["codigo"]]
	_capa_mensaje(titulo, "", res, false)
	if not sim.goals.is_empty():
		var g = []
		for x in sim.goals:
			g.append("%s %d' (%s)" % [x["name"], x["min"], sim.T[x["side"]].team["codigo"]])
		var gl = UI.label("Goles: " + ", ".join(g), 22, UI.APAGADO)
		gl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		gl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		gl.custom_minimum_size = Vector2(640, 0)
		capa_box.add_child(gl)
	if titulo != "Pausa":
		capa_box.add_child(_tabla_stats())
	var rb = HBoxContainer.new()
	rb.alignment = BoxContainer.ALIGNMENT_CENTER
	rb.add_theme_constant_override("separation", 14)
	capa_box.add_child(rb)
	var first: Button = null
	for i in botones.size():
		var b = UI.boton(botones[i][0], i == 0)
		b.pressed.connect(botones[i][1])
		rb.add_child(b)
		if first == null:
			first = b
	if first:
		first.call_deferred("grab_focus")


func _tabla_stats() -> Control:
	var st = sim.stats
	var pos_t: float = st["posesion"][0] + st["posesion"][1]
	var filas = [
		["%.0f%%" % (100.0 * st["posesion"][0] / maxf(pos_t, 1.0)), "Posesión", "%.0f%%" % (100.0 * st["posesion"][1] / maxf(pos_t, 1.0))],
		[str(st["tiros"][0]), "Remates", str(st["tiros"][1])],
		[str(st["al_arco"][0]), "Al arco", str(st["al_arco"][1])],
		[str(st["corners"][0]), "Córners", str(st["corners"][1])],
		[str(st["faltas"][0]), "Faltas", str(st["faltas"][1])],
	]
	var g = GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 26)
	g.add_theme_constant_override("v_separation", 0)
	for f in filas:
		for i in 3:
			var l = UI.label(f[i], 26 if i != 1 else 22, UI.TEXTO if i != 1 else UI.APAGADO, "mono" if i != 1 else "texto")
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.custom_minimum_size = Vector2(90 if i != 1 else 110, 0)
			g.add_child(l)
	var cc = CenterContainer.new()
	cc.add_child(g)
	return cc


func _controles() -> void:
	_limpiar_capa()
	capa_box.add_child(_grande("Controles"))
	var txt = UI.label(Menu.TEXTO_CONTROLES, 22, UI.TEXTO)
	txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	txt.custom_minimum_size = Vector2(760, 0)
	capa_box.add_child(txt)
	var b = UI.boton("Volver", true)
	b.pressed.connect(_volver_a_pausa)
	var cc = CenterContainer.new()
	cc.add_child(b)
	capa_box.add_child(cc)
	b.call_deferred("grab_focus")


# =========================================================
# Piezas del HUD que se dibujan a mano
# =========================================================
class Marcas:
	extends Control
	var partido: Partido

	func _draw() -> void:
		var P = partido
		if P == null or P.rep_activa:
			return
		var s = P.sim
		var h = s.human
		if h == null or s.auto or h.off:
			return
		var cam = P.cam
		var head = P.w(h.pos.x, h.pos.y, 2.25)
		if cam.is_position_behind(head):
			return
		var sp = cam.unproject_position(head)
		var f = UI.fuente("mono")
		var nm: String = h.d["corto"]
		var tw = f.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x + 10
		draw_rect(Rect2(sp.x - tw / 2, sp.y - 30, tw, 20), Color(0.024, 0.07, 0.13, 0.75))
		draw_string(f, Vector2(sp.x - tw / 2 + 5, sp.y - 14), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UI.TEXTO)
		draw_colored_polygon(PackedVector2Array([sp + Vector2(-6, -8), sp + Vector2(6, -8), sp + Vector2(0, 0)]), UI.SOL)
		# resistencia
		var feet = cam.unproject_position(P.w(h.pos.x, h.pos.y, 0.0))
		var bw = 46.0
		draw_rect(Rect2(feet.x - bw / 2 - 1, feet.y + 10, bw + 2, 6), Color(0.024, 0.07, 0.13, 0.8))
		var sc = Color("#5fc46a") if h.sta > 0.5 else (UI.SOL if h.sta > 0.25 else UI.ROJO)
		draw_rect(Rect2(feet.x - bw / 2, feet.y + 11, bw * h.sta, 4), sc)
		# potencia del remate
		if s.power > 0.0:
			draw_rect(Rect2(feet.x - bw / 2 - 1, feet.y + 18, bw + 2, 8), Color(0.024, 0.07, 0.13, 0.85))
			draw_rect(Rect2(feet.x - bw / 2, feet.y + 19, bw * s.power, 6), UI.ROJO if s.power > 0.85 else UI.SOL)


class Radar:
	extends Control
	var partido: Partido

	func _draw() -> void:
		var P = partido
		if P == null:
			return
		var s = P.sim
		var r = Rect2(Vector2(), size)
		draw_rect(r, Color(0.2, 0.36, 0.19, 0.82))
		draw_rect(r, Color(0.94, 0.93, 0.87, 0.7), false, 1.0)
		draw_line(Vector2(size.x / 2, 0), Vector2(size.x / 2, size.y), Color(0.94, 0.93, 0.87, 0.5), 1.0)
		for S in s.T:
			var c = Color(S.kit["base"])
			if c.get_luminance() > 0.8:
				c = Color(S.kit["alt"])
			for p in S.ps:
				var q = Vector2(p.pos.x / Sim.L * size.x, p.pos.y / Sim.W * size.y)
				draw_rect(Rect2(q - Vector2(2.5, 2.5), Vector2(5, 5)), c)
				if p == s.human and not s.auto:
					draw_rect(Rect2(q - Vector2(4.5, 4.5), Vector2(9, 9)), UI.SOL, false, 1.5)
		var bq = Vector2(s.b_pos.x / Sim.L * size.x, s.b_pos.y / Sim.W * size.y)
		draw_circle(bq, 2.5, Color.WHITE)

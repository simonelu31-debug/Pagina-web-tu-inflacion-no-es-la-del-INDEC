extends Node
## Raíz del juego: alterna entre los menús y el partido.

var menu: Menu
var partido: Partido


func _ready() -> void:
	_acciones()
	Datos.cargar()
	var args = OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--camara="):
			Datos.sel["camara"] = int(a.substr(9))
	if "--demo" in args:
		Datos.sel["auto"] = true
		_jugar()
	elif "--prueba-gol" in args:
		Datos.sel["local"] = "hur"
		Datos.sel["visita"] = "cha"
		_jugar()
		var s = partido.sim
		s.state = "juego"
		var p = s.T[0].ps[9]
		s.give_ball(p)
		p.pos = Vector2(88, 30)
		s.b_pos = Vector2(88.6, 30)
		s.shoot(p, 0.7, 0.8, true, false)
	elif "--equipos" in args:
		_menu("equipos")
	elif "--planteles" in args:
		_menu("portada")
		menu.planteles()
	else:
		_menu("portada")
	# Capturas automáticas para pruebas: -- --captura=/ruta/base --cada=2 --cuantas=4
	for a in args:
		if a.begins_with("--captura="):
			_capturas(a.substr(10), args)


func _capturas(base: String, args: PackedStringArray) -> void:
	var cada = 2.0
	var cuantas = 1
	for a in args:
		if a.begins_with("--cada="):
			cada = float(a.substr(7))
		elif a.begins_with("--cuantas="):
			cuantas = int(a.substr(10))
	for i in cuantas:
		await get_tree().create_timer(cada).timeout
		var img = get_viewport().get_texture().get_image()
		img.save_png("%s_%02d.png" % [base, i])
	get_tree().quit()


func _acciones() -> void:
	var teclas = {
		"izq": [KEY_LEFT], "der": [KEY_RIGHT], "arr": [KEY_UP], "abj": [KEY_DOWN],
		"pase": [KEY_S, KEY_X, KEY_SPACE], "largo": [KEY_W], "tiro": [KEY_D, KEY_C],
		"cambio": [KEY_A, KEY_Z], "correr": [KEY_SHIFT], "hueco": [KEY_Q], "gambeta": [KEY_E],
		"pausa": [KEY_P, KEY_ESCAPE], "camara": [KEY_V],
	}
	var botones = {
		"pase": [JOY_BUTTON_A], "tiro": [JOY_BUTTON_B], "hueco": [JOY_BUTTON_X], "largo": [JOY_BUTTON_Y],
		"cambio": [JOY_BUTTON_LEFT_SHOULDER], "correr": [JOY_BUTTON_RIGHT_SHOULDER], "pausa": [JOY_BUTTON_START],
		"camara": [JOY_BUTTON_BACK], "izq": [JOY_BUTTON_DPAD_LEFT], "der": [JOY_BUTTON_DPAD_RIGHT],
		"arr": [JOY_BUTTON_DPAD_UP], "abj": [JOY_BUTTON_DPAD_DOWN],
	}
	var ejes = {
		"izq": [JOY_AXIS_LEFT_X, -1.0], "der": [JOY_AXIS_LEFT_X, 1.0], "arr": [JOY_AXIS_LEFT_Y, -1.0],
		"abj": [JOY_AXIS_LEFT_Y, 1.0], "correr": [JOY_AXIS_TRIGGER_RIGHT, 1.0], "gambeta": [JOY_AXIS_TRIGGER_LEFT, 1.0],
	}
	for a in teclas:
		if not InputMap.has_action(a):
			InputMap.add_action(a, 0.25)
		for k in teclas[a]:
			var e = InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event(a, e)
		for b in botones.get(a, []):
			var jb = InputEventJoypadButton.new()
			jb.button_index = b
			InputMap.action_add_event(a, jb)
		if ejes.has(a):
			var jm = InputEventJoypadMotion.new()
			jm.axis = ejes[a][0]
			jm.axis_value = ejes[a][1]
			InputMap.action_add_event(a, jm)


func _menu(pantalla: String) -> void:
	if partido:
		partido.queue_free()
		partido = null
	if menu == null:
		menu = Menu.new()
		menu.jugar.connect(_jugar)
		add_child(menu)
	match pantalla:
		"equipos":
			menu.equipos()
		_:
			menu.portada()


func _jugar() -> void:
	if menu:
		menu.queue_free()
		menu = null
	if partido:
		partido.queue_free()
	partido = Partido.new()
	add_child(partido)
	partido.terminado.connect(_fin_partido)
	partido.iniciar(Datos.sel)


func _fin_partido(destino: String) -> void:
	if destino == "revancha":
		_jugar()
	else:
		Datos.sel.erase("auto")
		_menu(destino)


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and e.keycode == KEY_F11:
		var full = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)

extends SceneTree
## Muestra jugadores de cerca con distintas camisetas y poses (prueba visual).
func _initialize() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/equipos.json"))
	var root3 := Node3D.new()
	root.add_child(root3)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("#2b4a2a")
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.6)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	root3.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.shadow_enabled = true
	root3.add_child(sun)
	var poses := ["", "", "", "", "", "", "", ""]
	var ids := ["riv", "riv", "boc", "boc", "nob", "nob", "vel", "vel"]
	if OS.get_cmdline_user_args().has("--poses"):
		poses = ["", "correr", "patada", "barrida", "palomita", "cabezazo", "festejo", "caida"]
		ids = ["riv", "boc", "slo", "cha", "nob", "ban", "est", "vel"]
	for i in poses.size():
		var e: Dictionary
		for t in data["equipos"]:
			if t["id"] == ids[i]:
				e = t
		var j: Dictionary = e["jugadores"][8 if i % 2 == 0 else 9]
		j["esp"] = []
		var kit: Dictionary = e["camisetas"][0]
		if poses[i] == "palomita":
			kit = data["kits_arquero"][0]
		var v := Jugador3D.new()
		v.build(j, kit, 10, load("res://fonts/BigShoulders-900.woff2"))
		root3.add_child(v)
		var st := {"pos": Vector3((i - 3.5) * 1.05, 0, 0), "face": Vector2(0.35, 1).normalized() if i % 2 == 0 else Vector2(-0.35, -1).normalized(), "spd": 7.0 if poses[i] == "correr" else 0.0, "anim": 1.3, "act": poses[i], "act_t": 0.15, "act_dir": Vector2(1, 0), "act_h": 0.5, "sprint": poses[i] == "correr"}
		if poses[i] == "palomita":
			st["act_t"] = 0.6
		if poses[i] == "cabezazo":
			st["act_t"] = 0.25
		if poses[i] == "caida":
			st["act_t"] = 0.3
		v.pose(st, 0.016)
	var cam := Camera3D.new()
	root3.add_child(cam)
	cam.look_at_from_position(Vector3(0, 1.6, 5.2), Vector3(0, 1.1, 0))
	cam.fov = 60
	await process_frame
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("/tmp/claude-0/shots/modelo.png")
	quit()

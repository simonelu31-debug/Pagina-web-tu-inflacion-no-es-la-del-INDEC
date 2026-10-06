extends SceneTree
## Simula partidos completos entre todos los clubes, sin gráficos.
## godot --headless --path leyendas/godot --script res://tests/prueba_sim.gd

func _initialize() -> void:
	var datos = root.get_node_or_null("Datos")
	if datos == null:
		datos = load("res://scripts/datos.gd").new()
		datos.name = "Datos"
		root.add_child(datos)
	datos.cargar()
	var eq: Array = datos.equipos
	var goles := 0
	var partidos := 0
	var tiros := 0
	var faltas := 0
	var penales := 0
	var t0 := Time.get_ticks_msec()
	for i in eq.size():
		var s := Sim.new()
		s.setup({"home": eq[i], "away": eq[(i + 7) % eq.size()], "kit_h": 0, "kit_a": 0, "line_h": [], "line_a": [], "min": 5, "diff": 1, "datos": datos, "seed": 1000 + i})
		s.auto = true
		var n := 0
		while n < 60 * 60 * 8:
			n += 1
			if s.state == "penal" and s.pen.get("t", 0.0) < 0.02:
				penales += 1
			s.step(1.0 / 60.0)
			s.events.clear()
			if s.state == "entretiempo":
				s.second_half()
			elif s.state == "final":
				break
		goles += s.score[0] + s.score[1]
		tiros += s.stats["tiros"][0] + s.stats["tiros"][1]
		faltas += s.stats["faltas"][0] + s.stats["faltas"][1]
		partidos += 1
		print("%s %d - %d %s  tiros %d-%d  pos %.0f%%  faltas %d" % [eq[i]["codigo"], s.score[0], s.score[1], eq[(i + 7) % eq.size()]["codigo"], s.stats["tiros"][0], s.stats["tiros"][1], 100.0 * s.stats["posesion"][0] / maxf(1.0, s.stats["posesion"][0] + s.stats["posesion"][1]), s.stats["faltas"][0] + s.stats["faltas"][1]])
	print("partidos %d goles %d (%.2f por partido) tiros %d faltas %d penales %d  en %d ms" % [partidos, goles, float(goles) / partidos, tiros, faltas, penales, Time.get_ticks_msec() - t0])
	quit()

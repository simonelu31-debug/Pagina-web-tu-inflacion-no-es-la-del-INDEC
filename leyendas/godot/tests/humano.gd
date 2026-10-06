extends SceneTree
## Simula a una persona apretando botones durante partidos completos.
func _initialize() -> void:
	var datos = root.get_node("Datos")
	datos.cargar()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var tot := {}
	for m in 4:
		var s := Sim.new()
		s.setup({"home": datos.equipos[m * 3], "away": datos.equipos[m * 3 + 1], "kit_h": 0, "kit_a": 0, "line_h": [], "line_a": [], "min": 5, "diff": m % 3, "datos": datos, "seed": 40 + m})
		var shoot_hold := 0.0
		for n in 60 * 60 * 8:
			var h = s.human
			var I = s.inp
			if h:
				var S = s.T[0]
				var goal := Vector2(s.att_x(S), 34)
				var tgt: Vector2 = goal if s.b_owner == h else s.b_pos
				I["mv"] = (tgt - h.pos).normalized() if h.pos.distance_to(tgt) > 0.5 else Vector2()
				I["sprint"] = rng.randf() < 0.6
				I["pass"] = rng.randf() < 0.3
				I["thru"] = rng.randf() < 0.1
				I["long"] = false
				if s.b_owner == h:
					if h.pos.distance_to(goal) < 24 and shoot_hold <= 0.0 and rng.randf() < 0.05:
						shoot_hold = rng.randf_range(0.2, 0.9)
					var r := rng.randf()
					if r < 0.008: I["pass_p"] = true
					elif r < 0.012: I["thru_p"] = true
					elif r < 0.015: I["long_p"] = true
					elif r < 0.02: I["feint_p"] = true
				else:
					var r2 := rng.randf()
					if r2 < 0.01: I["switch_p"] = true
					elif r2 < 0.014: I["shoot_p"] = true
				if s.state == "penal" or (s.sp.get("tipo", "") == "libre" and s.sp.get("taker") == h):
					if shoot_hold <= 0.0:
						shoot_hold = 0.6
				I["shoot"] = shoot_hold > 0.0
				shoot_hold -= 1.0 / 60.0
				I["mv"] += Vector2(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.3, 0.3))
			s.step(1.0 / 60.0)
			for e in s.events:
				tot[e["t"]] = tot.get(e["t"], 0) + 1
			s.events.clear()
			if s.state == "entretiempo":
				s.second_half()
			elif s.state == "final":
				break
		print("partido %d: %d-%d tiros %s faltas %s" % [m, s.score[0], s.score[1], s.stats["tiros"], s.stats["faltas"]])
	print(tot)
	quit()

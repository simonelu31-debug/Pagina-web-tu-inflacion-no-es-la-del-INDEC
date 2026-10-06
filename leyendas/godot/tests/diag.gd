extends SceneTree
func _initialize() -> void:
	var datos = root.get_node("Datos")
	datos.cargar()
	var cnt := {}
	var zona := [0.0, 0.0, 0.0]
	var libre := 0.0
	var total := 0.0
	var reinicios := {}
	for i in 6:
		var s := Sim.new()
		s.setup({"home": datos.equipos[i], "away": datos.equipos[(i + 5) % 20], "kit_h": 0, "kit_a": 0, "line_h": [], "line_a": [], "min": 5, "diff": 1, "datos": datos, "seed": 77 + i})
		s.auto = true
		var prev_sp := ""
		for n in 60 * 60 * 6:
			s.step(1.0 / 60.0)
			for e in s.events:
				cnt[e["t"]] = cnt.get(e["t"], 0) + 1
			s.events.clear()
			var spk: String = s.sp.get("tipo", "")
			if spk != prev_sp and spk != "":
				reinicios[spk] = reinicios.get(spk, 0) + 1
			prev_sp = spk
			if s.state == "juego":
				total += 1
				var x := s.b_pos.x / 105.0
				zona[0 if x < 0.25 else (2 if x > 0.75 else 1)] += 1
				if s.b_owner == null:
					libre += 1
			if n == 60 * 60 * 6 - 1 or s.state == "final":
				cnt["al_arco"] = cnt.get("al_arco", 0) + s.stats["al_arco"][0] + s.stats["al_arco"][1]
				cnt["corners"] = cnt.get("corners", 0) + s.stats["corners"][0] + s.stats["corners"][1]
			if s.state == "entretiempo":
				s.second_half()
			elif s.state == "final":
				break
	print(cnt)
	print("reinicios ", reinicios)
	print("zonas %.2f %.2f %.2f  pelota libre %.2f" % [zona[0] / total, zona[1] / total, zona[2] / total, libre / total])
	quit()

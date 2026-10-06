class_name Jugador3D
extends Node3D
## Jugador armado con piezas simples (cápsulas, cilindros y esferas) y
## animado por código. Mira hacia +Z local.

const PIEL := ["#f2cba6", "#dcaa7f", "#b77d54", "#7b4b2d"]

var pelvis: Node3D
var torso: Node3D
var cabeza: Node3D
var hombro := [null, null]
var codo := [null, null]
var cadera := [null, null]
var rodilla := [null, null]
var sombra: MeshInstance3D
var marca: MeshInstance3D
var numero: Label3D
var fase := 0.0
var _salto := 0.0


static func mat(c: Color, rough := 0.85) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


## Tubo elíptico con tapa arriba. UV: u da la vuelta empezando por la espalda
## (el frente queda en u = 0.5), v va de arriba (0) a abajo (1).
static func tubo(r_top: float, r_bot: float, h: float, prof: float) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n = 18
	for i in n:
		var a0 = float(i) / n
		var a1 = float(i + 1) / n
		var p = func(a: float, top: bool) -> Vector3:
			var ang = a * TAU
			var r = r_top if top else r_bot
			return Vector3(-sin(ang) * r, h / 2.0 if top else -h / 2.0, -cos(ang) * r * prof)
		var nrm = func(a: float) -> Vector3:
			var ang = a * TAU
			return Vector3(-sin(ang), 0, -cos(ang) / prof).normalized()
		var verts = [[p.call(a0, true), Vector2(a0, 0), nrm.call(a0)], [p.call(a1, true), Vector2(a1, 0), nrm.call(a1)], [p.call(a1, false), Vector2(a1, 1), nrm.call(a1)], [p.call(a0, false), Vector2(a0, 1), nrm.call(a0)]]
		for k in [0, 1, 2, 0, 2, 3]:
			st.set_normal(verts[k][2])
			st.set_uv(verts[k][1])
			st.add_vertex(verts[k][0])
		# tapa (hombros)
		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(0.5, 0.0))
		st.add_vertex(Vector3(0, h / 2.0, 0))
		st.set_uv(Vector2(a1, 0.0))
		st.add_vertex(p.call(a1, true))
		st.set_uv(Vector2(a0, 0.0))
		st.add_vertex(p.call(a0, true))
	return st.commit()


static func capsula(r: float, h: float, m: Material) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	var c = CapsuleMesh.new()
	c.radius = r
	c.height = h
	c.radial_segments = 10
	c.rings = 3
	mi.mesh = c
	mi.material_override = m
	return mi


func build(d: Dictionary, kit: Dictionary, num: int, font: Font) -> void:
	var skin = mat(Color(PIEL[clampi(int(d["sk"]), 0, 3)]), 0.7)
	var shirt = StandardMaterial3D.new()
	shirt.albedo_texture = KitArt.torso_texture(kit)
	shirt.roughness = 0.8
	var sleeve = mat(Color(kit["base"]))
	if kit["pat"] in ["stripes", "tri"]:
		sleeve = mat(Color(kit["alt"]))
	if kit["pat"] == "halves":
		sleeve = mat(Color(kit["alt"]))
	var shorts = mat(Color(kit["shorts"]))
	var socks = mat(Color(kit["socks"]))
	var boots = mat(Color("#161616"), 0.5)
	var hair = mat(Color(d["hc"]), 0.9)

	pelvis = Node3D.new()
	pelvis.position = Vector3(0, 0.93, 0)
	add_child(pelvis)

	torso = Node3D.new()
	pelvis.add_child(torso)
	var tm = MeshInstance3D.new()
	tm.mesh = tubo(0.205, 0.175, 0.56, 0.62)
	tm.material_override = shirt
	tm.position = Vector3(0, 0.3, 0)
	torso.add_child(tm)
	var sh = MeshInstance3D.new()
	var cyl2 = CylinderMesh.new()
	cyl2.top_radius = 0.18
	cyl2.bottom_radius = 0.19
	cyl2.height = 0.2
	cyl2.radial_segments = 12
	sh.mesh = cyl2
	sh.material_override = shorts
	sh.position = Vector3(0, -0.02, 0)
	sh.scale = Vector3(1, 1, 0.68)
	pelvis.add_child(sh)

	# cabeza
	cabeza = Node3D.new()
	cabeza.position = Vector3(0, 0.64, 0)
	torso.add_child(cabeza)
	var cuello = capsula(0.055, 0.16, skin)
	cuello.position = Vector3(0, -0.03, 0)
	cabeza.add_child(cuello)
	var hm = MeshInstance3D.new()
	var sp = SphereMesh.new()
	sp.radius = 0.115
	sp.height = 0.25
	sp.radial_segments = 14
	sp.rings = 8
	hm.mesh = sp
	hm.material_override = skin
	hm.position = Vector3(0, 0.13, 0)
	cabeza.add_child(hm)
	_pelo(d, hair, skin)

	# brazos
	for i in 2:
		var s = -1.0 if i == 0 else 1.0
		var h = Node3D.new()
		h.position = Vector3(s * 0.25, 0.52, 0)
		torso.add_child(h)
		hombro[i] = h
		var up = capsula(0.062, 0.3, sleeve)
		up.position = Vector3(0, -0.13, 0)
		h.add_child(up)
		var c = Node3D.new()
		c.position = Vector3(0, -0.27, 0)
		h.add_child(c)
		codo[i] = c
		var fa = capsula(0.05, 0.3, skin)
		fa.position = Vector3(0, -0.13, 0)
		c.add_child(fa)

	# piernas
	for i in 2:
		var s2 = -1.0 if i == 0 else 1.0
		var hip = Node3D.new()
		hip.position = Vector3(s2 * 0.1, -0.05, 0)
		pelvis.add_child(hip)
		cadera[i] = hip
		var th = capsula(0.078, 0.44, skin)
		th.position = Vector3(0, -0.2, 0)
		hip.add_child(th)
		var k = Node3D.new()
		k.position = Vector3(0, -0.42, 0)
		hip.add_child(k)
		rodilla[i] = k
		var sn = capsula(0.062, 0.42, socks)
		sn.position = Vector3(0, -0.2, 0)
		k.add_child(sn)
		var bt = MeshInstance3D.new()
		var bm = BoxMesh.new()
		bm.size = Vector3(0.1, 0.07, 0.24)
		bt.mesh = bm
		bt.material_override = boots
		bt.position = Vector3(0, -0.43, 0.05)
		k.add_child(bt)

	# número en la espalda
	numero = Label3D.new()
	numero.text = str(num)
	numero.font = font
	numero.font_size = 64
	numero.pixel_size = 0.0034
	numero.modulate = Color(kit["num"])
	numero.outline_size = 0
	numero.position = Vector3(0, 0.32, -0.125)
	numero.rotation.y = PI
	numero.double_sided = false
	numero.shaded = true
	torso.add_child(numero)

	# sombra redonda (ayuda a leer la altura de saltos y caídas)
	sombra = MeshInstance3D.new()
	var q = QuadMesh.new()
	q.size = Vector2(1.1, 1.1)
	sombra.mesh = q
	var sm = StandardMaterial3D.new()
	sm.albedo_texture = KitArt.blob_texture()
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.cull_mode = BaseMaterial3D.CULL_DISABLED
	sombra.material_override = sm
	sombra.rotation.x = -PI / 2.0
	sombra.position.y = 0.02
	sombra.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sombra)

	# aro del jugador que maneja la persona
	marca = MeshInstance3D.new()
	var tor = TorusMesh.new()
	tor.inner_radius = 0.55
	tor.outer_radius = 0.68
	tor.rings = 24
	tor.ring_segments = 4
	marca.mesh = tor
	var mm = StandardMaterial3D.new()
	mm.albedo_color = Color("#f3b61f")
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marca.material_override = mm
	marca.scale = Vector3(1, 0.05, 1)
	marca.position.y = 0.03
	marca.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marca.visible = false
	add_child(marca)


func _pelo(d: Dictionary, hair: Material, skin: Material) -> void:
	var hs: String = d["hs"]
	var top = Vector3(0, 0.13, 0)
	var add_sphere = func(r: float, pos: Vector3, scl: Vector3, m: Material) -> MeshInstance3D:
		var mi = MeshInstance3D.new()
		var sp = SphereMesh.new()
		sp.radius = r
		sp.height = r * 2
		sp.radial_segments = 12
		sp.rings = 6
		mi.mesh = sp
		mi.material_override = m
		mi.position = pos
		mi.scale = scl
		cabeza.add_child(mi)
		return mi
	match hs:
		"corto":
			add_sphere.call(0.121, top + Vector3(0, 0.03, -0.012), Vector3(1, 0.8, 1), hair)
		"peinado":
			add_sphere.call(0.123, top + Vector3(0, 0.035, -0.015), Vector3(1.0, 0.78, 1.04), hair)
		"rizado":
			add_sphere.call(0.15, top + Vector3(0, 0.05, -0.02), Vector3(1.05, 0.85, 1.05), hair)
		"largo":
			add_sphere.call(0.125, top + Vector3(0, 0.03, -0.015), Vector3(1.02, 0.85, 1.05), hair)
			var back = MeshInstance3D.new()
			var bm = BoxMesh.new()
			bm.size = Vector3(0.24, 0.24, 0.08)
			back.mesh = bm
			back.material_override = hair
			back.position = top + Vector3(0, -0.1, -0.08)
			cabeza.add_child(back)
		"entradas":
			add_sphere.call(0.118, top + Vector3(0, 0.0, -0.035), Vector3(1.0, 0.7, 0.9), hair)
		"pelado":
			pass
		_:
			add_sphere.call(0.121, top + Vector3(0, 0.03, -0.012), Vector3(1, 0.8, 1), hair)
	if d["band"]:
		var b = MeshInstance3D.new()
		var tm = TorusMesh.new()
		tm.inner_radius = 0.112
		tm.outer_radius = 0.13
		tm.rings = 16
		tm.ring_segments = 4
		b.mesh = tm
		b.material_override = mat(Color("#f4f1ea"))
		b.position = top + Vector3(0, 0.05, 0)
		b.rotation.x = 0.15
		cabeza.add_child(b)
	if d["mus"]:
		var mo = MeshInstance3D.new()
		var mb = BoxMesh.new()
		mb.size = Vector3(0.09, 0.022, 0.03)
		mo.mesh = mb
		mo.material_override = hair
		mo.position = top + Vector3(0, -0.04, 0.105)
		cabeza.add_child(mo)
	# ojos
	var eye = mat(Color("#1b130e"))
	for s in [-1.0, 1.0]:
		var e = MeshInstance3D.new()
		var em = SphereMesh.new()
		em.radius = 0.014
		em.height = 0.028
		em.radial_segments = 6
		em.rings = 3
		e.mesh = em
		e.material_override = eye
		e.position = top + Vector3(s * 0.04, 0.015, 0.103)
		cabeza.add_child(e)


## Pone la pose a partir del estado del motor (o de la repetición).
## st: pos(Vector3), face(Vector2), spd, anim, act, act_t, act_dir(Vector2), act_h, sprint
func pose(st: Dictionary, dt: float) -> void:
	var face: Vector2 = st["face"]
	var p3: Vector3 = st["pos"]
	position = p3
	rotation = Vector3(0, atan2(face.x, face.y), 0)
	var spd: float = st["spd"]
	var run = clampf(spd / 7.5, 0.0, 1.0)
	var ph: float = st["anim"] * 2.6
	var act: String = st["act"]
	var at: float = st["act_t"]
	var sprint: bool = st["sprint"]

	# valores base: carrera
	var amp = 0.25 + run * (0.75 if sprint else 0.55)
	var sw = sin(ph) * amp * minf(1.0, run * 2.2)
	var lean = run * (0.28 if sprint else 0.17)
	pelvis.position = Vector3(0, 0.93 - absf(sin(ph)) * 0.04 * run, 0)
	pelvis.rotation = Vector3(0, 0, 0)
	torso.rotation = Vector3(lean, sin(ph) * 0.12 * run, 0)
	cabeza.rotation = Vector3(-lean * 0.6, 0, 0)
	for i in 2:
		var s = 1.0 if i == 0 else -1.0
		cadera[i].rotation = Vector3(-s * sw, 0, 0)
		rodilla[i].rotation = Vector3(maxf(0.0, s * sin(ph + 0.9)) * 1.3 * run + 0.05, 0, 0)
		hombro[i].rotation = Vector3(s * sw * 0.9, 0, (-0.12 if i == 0 else 0.12))
		codo[i].rotation = Vector3(-0.5 - run * 0.9, 0, 0)
	if run < 0.05:
		var br = sin(Time.get_ticks_msec() / 600.0 + position.x) * 0.02
		torso.rotation.x = br
		for i in 2:
			hombro[i].rotation = Vector3(0.05, 0, (-0.1 if i == 0 else 0.1))
			codo[i].rotation = Vector3(-0.25, 0, 0)

	match act:
		"patada", "volea":
			var k = clampf(1.0 - at / 0.35, 0.0, 1.0)
			var swing = -1.4 * sin(k * PI * 0.5) + 1.3 * smoothstep(0.35, 1.0, k) * 1.6
			cadera[0].rotation.x = swing
			rodilla[0].rotation.x = 1.1 * (1.0 - k)
			cadera[1].rotation.x = 0.15
			rodilla[1].rotation.x = 0.25
			torso.rotation.x = -0.15 + 0.25 * k
			hombro[1].rotation = Vector3(-0.5, 0, 0.9)
			hombro[0].rotation = Vector3(0.6, 0, -0.5)
			if act == "volea":
				torso.rotation.z = -0.5
		"barrida":
			pelvis.position.y = 0.32
			torso.rotation.x = -1.15
			cadera[0].rotation.x = -1.45
			rodilla[0].rotation.x = 0.05
			cadera[1].rotation.x = -0.9
			rodilla[1].rotation.x = 1.3
			hombro[0].rotation = Vector3(-0.4, 0, -1.0)
			hombro[1].rotation = Vector3(-0.4, 0, 1.0)
		"palomita":
			var dv: Vector2 = st["act_dir"]
			var k2 = clampf(1.0 - at, 0.0, 1.0)
			var lado = signf(Vector2(cos(rotation.y), -sin(rotation.y)).dot(dv))
			if lado == 0.0:
				lado = 1.0
			var tilt = minf(1.0, k2 * 4.0) * 1.35
			var h: float = st["act_h"]
			pelvis.position.y = 0.55 + h * 0.9 * sin(minf(1.0, k2 * 2.0) * PI * 0.5) - (0.35 if k2 > 0.6 else 0.0)
			pelvis.rotation.z = -lado * tilt
			for i in 2:
				hombro[i].rotation = Vector3(0, 0, (-1.0 if i == 0 else 1.0) * 2.7)
				codo[i].rotation = Vector3(0, 0, 0)
		"cabezazo":
			var k3 = clampf(1.0 - at / 0.5, 0.0, 1.0)
			pelvis.position.y += sin(k3 * PI) * 0.45
			cabeza.rotation.x = -0.6 + sin(k3 * PI) * 0.9
			torso.rotation.x = -0.3 + sin(k3 * PI) * 0.4
			for i in 2:
				hombro[i].rotation = Vector3(-0.8, 0, (-0.6 if i == 0 else 0.6))
		"festejo":
			var t = Time.get_ticks_msec() / 1000.0
			pelvis.position.y += absf(sin(t * 7.0)) * 0.22
			for i in 2:
				hombro[i].rotation = Vector3(-2.9 + sin(t * 9.0 + i) * 0.3, 0, (-0.3 if i == 0 else 0.3))
				codo[i].rotation = Vector3(-0.2, 0, 0)
		"caida":
			var k4 = clampf(1.0 - at / 1.0, 0.0, 1.0)
			var fall = minf(1.0, k4 * 3.0)
			pelvis.position.y = 0.93 - fall * 0.72
			torso.rotation.x = -fall * 1.45
			cadera[0].rotation.x = -fall * 1.3
			cadera[1].rotation.x = -fall * 1.1
			hombro[0].rotation = Vector3(-1.5 * fall, 0, -1.0)
			hombro[1].rotation = Vector3(-1.5 * fall, 0, 1.0)
		"gambeta":
			var dv2: Vector2 = st["act_dir"]
			var lado2 = signf(Vector2(cos(rotation.y), -sin(rotation.y)).dot(dv2))
			torso.rotation.z = -lado2 * 0.3
			pelvis.rotation.z = lado2 * 0.12
		"quite":
			cadera[0].rotation.x = -0.9
			rodilla[0].rotation.x = 0.1
			torso.rotation.x = 0.35
		"atrapa", "pecho":
			for i in 2:
				hombro[i].rotation = Vector3(-1.4, 0, (-0.25 if i == 0 else 0.25))
				codo[i].rotation = Vector3(-0.6, 0, 0)
		"saque":
			for i in 2:
				hombro[i].rotation = Vector3(-2.8, 0, 0)
				codo[i].rotation = Vector3(-0.9, 0, 0)
	sombra.position.y = 0.02 - position.y
	var hgt = maxf(0.0, pelvis.position.y - 0.93)
	sombra.scale = Vector3.ONE * (1.0 + hgt * 0.4)

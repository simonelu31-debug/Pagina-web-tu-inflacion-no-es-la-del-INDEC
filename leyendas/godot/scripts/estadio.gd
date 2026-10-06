class_name Estadio
extends Node3D
## Cancha, arcos, tribunas con hinchada, carteles, luces y cielo.
## Origen en el centro de la cancha: X a lo largo (105 m), Z a lo ancho (68 m).

const L := 105.0
const W := 68.0

const CESPED := """
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
uniform vec3 g1 : source_color = vec3(0.14, 0.25, 0.105);
uniform vec3 g2 : source_color = vec3(0.17, 0.295, 0.125);
uniform vec3 pista : source_color = vec3(0.13, 0.22, 0.10);
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float seg(vec2 p, vec2 a, vec2 b) { vec2 pa = p - a; vec2 ba = b - a; float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0); return length(pa - ba * h); }
float rect(vec2 p, vec2 a, vec2 b) {
	vec2 c = (a + b) * 0.5; vec2 h = (b - a) * 0.5; vec2 q = abs(p - c) - h;
	return abs(length(max(q, 0.0)) + min(max(q.x, q.y), 0.0));
}
void fragment() {
	vec2 f = vec2(wp.x + 52.5, wp.z + 34.0);
	bool dentro = f.x > -4.0 && f.x < 109.0 && f.y > -4.0 && f.y < 72.0;
	float s = step(0.5, fract(f.x / 15.0));
	vec3 col = mix(g1, g2, s);
	if (!dentro) col = pista;
	float n = noise(f * 1.3) * 0.45 + noise(f * 6.0) * 0.25 + noise(f * 0.18) * 0.6;
	col *= 0.84 + n * 0.24;
	// desgaste en las áreas chicas y el círculo central
	float wear = max(max(1.0 - length((f - vec2(3.0, 34.0)) / vec2(4.0, 6.0)), 1.0 - length((f - vec2(102.0, 34.0)) / vec2(4.0, 6.0))), 0.0);
	col = mix(col, vec3(0.36, 0.33, 0.20), wear * 0.55 * noise(f * 2.5));
	float d = 1000.0;
	d = min(d, rect(f, vec2(0.0), vec2(105.0, 68.0)));
	d = min(d, seg(f, vec2(52.5, 0.0), vec2(52.5, 68.0)));
	d = min(d, abs(length(f - vec2(52.5, 34.0)) - 9.15));
	d = min(d, max(0.0, length(f - vec2(52.5, 34.0)) - 0.11));
	d = min(d, rect(f, vec2(0.0, 13.84), vec2(16.5, 54.16)));
	d = min(d, rect(f, vec2(88.5, 13.84), vec2(105.0, 54.16)));
	d = min(d, rect(f, vec2(0.0, 24.84), vec2(5.5, 43.16)));
	d = min(d, rect(f, vec2(99.5, 24.84), vec2(105.0, 43.16)));
	d = min(d, max(0.0, length(f - vec2(11.0, 34.0)) - 0.09));
	d = min(d, max(0.0, length(f - vec2(94.0, 34.0)) - 0.09));
	if (f.x > 16.5) d = min(d, abs(length(f - vec2(11.0, 34.0)) - 9.15));
	if (f.x < 88.5) d = min(d, abs(length(f - vec2(94.0, 34.0)) - 9.15));
	if (f.x >= 0.0 && f.x <= 105.0 && f.y >= 0.0 && f.y <= 68.0) {
		d = min(d, abs(length(f - vec2(0.0, 0.0)) - 1.0));
		d = min(d, abs(length(f - vec2(105.0, 0.0)) - 1.0));
		d = min(d, abs(length(f - vec2(0.0, 68.0)) - 1.0));
		d = min(d, abs(length(f - vec2(105.0, 68.0)) - 1.0));
	}
	float w = 0.06;
	float aa = fwidth(d) * 0.9 + 0.002;
	float line = 1.0 - smoothstep(w - aa, w + aa, d);
	col = mix(col, vec3(0.92, 0.92, 0.88), line * 0.93);
	ALBEDO = col;
	ROUGHNESS = 0.95;
}
"""

const HINCHADA := """
shader_type spatial;
render_mode cull_disabled, specular_disabled;
uniform float local_salta = 0.0;
uniform float visita_salta = 0.0;
varying vec3 c;
void vertex() {
	float ph = INSTANCE_CUSTOM.x * 6.2831;
	float lado = INSTANCE_CUSTOM.y;
	float e = lado > 0.66 ? visita_salta : (lado > 0.33 ? local_salta : max(local_salta, visita_salta) * 0.3);
	float j = 0.03 * sin(TIME * 1.7 + ph) + e * abs(sin(TIME * 8.0 + ph)) * 0.45;
	VERTEX.y += j;
	if (VERTEX.y > 0.25) VERTEX.x += e * sin(TIME * 10.0 + ph) * 0.12;
	c = COLOR.rgb;
}
void fragment() { ALBEDO = c * 0.78; ROUGHNESS = 1.0; }
"""

const RED := """
shader_type spatial;
render_mode cull_disabled, specular_disabled;
uniform sampler2D grid : filter_linear_mipmap, repeat_enable;
uniform vec3 golpe = vec3(0.0, -100.0, 0.0);
uniform float amp = 0.0;
uniform float hacia = 1.0;
void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float d = distance(w, golpe);
	VERTEX.x += hacia * amp * exp(-d * d * 0.7);
}
void fragment() {
	vec4 g = texture(grid, UV);
	if (g.a < 0.5) discard;
	ALBEDO = vec3(0.93, 0.93, 0.9);
	ROUGHNESS = 1.0;
}
"""

var redes: Array = []          # ShaderMaterial de cada red (0 = x negativa, 1 = x positiva)
var hinchada_mat: ShaderMaterial
var font: Font


func build(kit_local: Dictionary, kit_visita: Dictionary, fuente: Font) -> void:
	font = fuente
	_ambiente()
	_suelo()
	for s in [-1.0, 1.0]:
		_arco(s)
	_tribunas(kit_local, kit_visita)
	_carteles()
	_torres()


func _ambiente() -> void:
	var env = Environment.new()
	var sky = Sky.new()
	var sm = ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("#2f5f9e")
	sm.sky_horizon_color = Color("#b9cfe0")
	sm.ground_horizon_color = Color("#8aa0a8")
	sm.ground_bottom_color = Color("#2b3a2c")
	sm.sun_angle_max = 30.0
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	var we = WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -38, 0)
	sun.light_energy = 1.1
	sun.light_color = Color("#fff4e0")
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 110.0
	sun.shadow_bias = 0.03
	sun.shadow_blur = 1.2
	add_child(sun)


func _suelo() -> void:
	var mi = MeshInstance3D.new()
	var pm = PlaneMesh.new()
	pm.size = Vector2(190, 150)
	pm.subdivide_width = 4
	pm.subdivide_depth = 4
	mi.mesh = pm
	var sm = ShaderMaterial.new()
	var sh = Shader.new()
	sh.code = CESPED
	sm.shader = sh
	mi.material_override = sm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _grid_texture() -> ImageTexture:
	var S = 32
	var img = Image.create(S, S, true, Image.FORMAT_RGBA8)
	for y in S:
		for x in S:
			var a = 1.0 if (x < 3 or y < 3) else 0.0
			img.set_pixel(x, y, Color(1, 1, 1, a))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _arco(s: float) -> void:
	var gx = s * L / 2.0
	var post = StandardMaterial3D.new()
	post.albedo_color = Color("#f6f3ea")
	post.roughness = 0.35
	var hy = 2.44
	var hz = 3.66
	for z in [-hz, hz]:
		var p = MeshInstance3D.new()
		var c = CylinderMesh.new()
		c.top_radius = 0.06
		c.bottom_radius = 0.06
		c.height = hy
		p.mesh = c
		p.material_override = post
		p.position = Vector3(gx, hy / 2.0, z)
		add_child(p)
	var cb = MeshInstance3D.new()
	var c2 = CylinderMesh.new()
	c2.top_radius = 0.06
	c2.bottom_radius = 0.06
	c2.height = hz * 2 + 0.12
	cb.mesh = c2
	cb.material_override = post
	cb.position = Vector3(gx, hy, 0)
	cb.rotation.x = PI / 2.0
	add_child(cb)
	# red: techo, fondo y costados, subdivididos para que se puedan mover
	var depth = 2.0
	var back_h = 2.0
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bx = gx + s * depth
	var quad = func(a: Vector3, b: Vector3, c: Vector3, d: Vector3, cells: Vector2) -> void:
		var nu = 10
		var nv = 6
		for i in nu:
			for j in nv:
				var u0 = float(i) / nu
				var u1 = float(i + 1) / nu
				var v0 = float(j) / nv
				var v1 = float(j + 1) / nv
				var P = func(u: float, v: float) -> Vector3:
					return a.lerp(b, u).lerp(d.lerp(c, u), v)
				var pts = [P.call(u0, v0), P.call(u1, v0), P.call(u1, v1), P.call(u0, v1)]
				var uvs = [Vector2(u0, v0) * cells, Vector2(u1, v0) * cells, Vector2(u1, v1) * cells, Vector2(u0, v1) * cells]
				for k in [0, 1, 2, 0, 2, 3]:
					st.set_uv(uvs[k])
					st.add_vertex(pts[k])
	# techo
	quad.call(Vector3(gx, hy, -hz), Vector3(gx, hy, hz), Vector3(bx, back_h, hz), Vector3(bx, back_h, -hz), Vector2(28, 8))
	# fondo
	quad.call(Vector3(bx, back_h, -hz), Vector3(bx, back_h, hz), Vector3(bx, 0, hz), Vector3(bx, 0, -hz), Vector2(28, 8))
	# costados
	for z in [-hz, hz]:
		quad.call(Vector3(gx, hy, z), Vector3(bx, back_h, z), Vector3(bx, 0, z), Vector3(gx, 0, z), Vector2(8, 10))
	st.generate_normals()
	var net = MeshInstance3D.new()
	net.mesh = st.commit()
	var sm = ShaderMaterial.new()
	var sh = Shader.new()
	sh.code = RED
	sm.shader = sh
	sm.set_shader_parameter("grid", _grid_texture())
	sm.set_shader_parameter("hacia", s)
	net.material_override = sm
	net.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(net)
	redes.append(sm)
	# soportes de la red
	for z in [-hz, hz]:
		var r = MeshInstance3D.new()
		var cm = CylinderMesh.new()
		cm.top_radius = 0.025
		cm.bottom_radius = 0.025
		cm.height = back_h
		r.mesh = cm
		r.material_override = post
		r.position = Vector3(bx, back_h / 2.0, z)
		add_child(r)


func sacudir_red(lado: int, punto: Vector3, fuerza: float) -> void:
	var sm: ShaderMaterial = redes[lado]
	sm.set_shader_parameter("golpe", punto)
	var tw = create_tween()
	tw.tween_method(func(v: float): sm.set_shader_parameter("amp", v), fuerza, 0.0, 1.2).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _tribunas(kl: Dictionary, kv: Dictionary) -> void:
	var cemento = StandardMaterial3D.new()
	cemento.albedo_color = Color("#6f6d66")
	cemento.roughness = 1.0
	var techo = StandardMaterial3D.new()
	techo.albedo_color = Color("#3d4450")
	var gradas = []
	# fondo (lado lejano a la cámara), detrás de cada arco y un poco del lado cercano
	gradas.append({"a": Vector3(-78, 0, -42), "b": Vector3(78, 0, -42), "dir": Vector3(0, 0, -1), "filas": 16, "techo": true})
	gradas.append({"a": Vector3(-63, 0, 42), "b": Vector3(-63, 0, -42), "dir": Vector3(-1, 0, 0), "filas": 13, "techo": false})
	gradas.append({"a": Vector3(63, 0, -42), "b": Vector3(63, 0, 42), "dir": Vector3(1, 0, 0), "filas": 13, "techo": false})
	var pal = [Color("#6b5a4a"), Color("#8a7d6b"), Color("#4a4f57"), Color("#9b8f7a"), Color("#57493d"), Color("#3e3a36"), Color("#7d6d5a"), Color("#c9c2b0"), Color("#2e3440")]
	var tc = [Color(kl["base"]), Color(kl["alt"]), Color(kv["base"]), Color(kv["alt"])]
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	var bm = BoxMesh.new()
	bm.size = Vector3(0.42, 0.62, 0.32)
	mm.mesh = bm
	var xforms = []
	var cols = []
	var custom = []
	for g in gradas:
		var a: Vector3 = g["a"]
		var b: Vector3 = g["b"]
		var dir: Vector3 = g["dir"]
		var largo = a.distance_to(b)
		var along = (b - a).normalized()
		var filas: int = g["filas"]
		for f in filas:
			var paso = MeshInstance3D.new()
			var pb = BoxMesh.new()
			pb.size = Vector3(largo, 0.62 * (f + 1), 0.9)
			paso.mesh = pb
			paso.material_override = cemento
			var centro = (a + b) / 2.0 + dir * (f * 0.9 + 0.45)
			paso.position = centro + Vector3(0, 0.31 * (f + 1), 0)
			paso.rotation.y = atan2(along.z, -along.x) + PI if absf(along.x) > 0.5 else atan2(along.z, along.x)
			if absf(along.z) > 0.5:
				paso.rotation.y = PI / 2.0
			else:
				paso.rotation.y = 0.0
			add_child(paso)
			var n = int(largo / 0.62)
			for i in n:
				if randf() < 0.1:
					continue
				var t = (i + randf() * 0.4) / n
				var p = a.lerp(b, t) + dir * (f * 0.9 + 0.5) + Vector3(0, 0.62 * (f + 1) + 0.31, 0)
				var basis = Basis(Vector3.UP, atan2(-dir.x, -dir.z))
				xforms.append(Transform3D(basis, p))
				var lado = 0.0
				var c: Color = pal[randi() % pal.size()]
				if randf() < 0.45:
					var home = p.x < 0.0 if absf(along.x) > 0.5 else p.x < 0.0
					if randf() < 0.75:
						c = tc[0 if randf() < 0.6 else 1] if home else tc[2 if randf() < 0.6 else 3]
						lado = 0.5 if home else 0.9
				cols.append(c)
				custom.append(Color(randf(), lado, 0, 0))
		if g["techo"]:
			var roof = MeshInstance3D.new()
			var rb = BoxMesh.new()
			rb.size = Vector3(largo, 0.3, filas * 0.9 + 3)
			roof.mesh = rb
			roof.material_override = techo
			roof.position = (a + b) / 2.0 + dir * (filas * 0.9 / 2.0 + 0.5) + Vector3(0, 0.62 * filas + 6.5, 0)
			add_child(roof)
			for k in 7:
				var col = MeshInstance3D.new()
				var cm = CylinderMesh.new()
				cm.top_radius = 0.18
				cm.bottom_radius = 0.18
				cm.height = 0.62 * filas + 6.5
				col.mesh = cm
				col.material_override = techo
				col.position = a.lerp(b, k / 6.0) + dir * (filas * 0.9 + 0.8) + Vector3(0, cm.height / 2.0, 0)
				add_child(col)
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		mm.set_instance_color(i, cols[i])
		mm.set_instance_custom_data(i, custom[i])
	var mmi = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	hinchada_mat = ShaderMaterial.new()
	var sh = Shader.new()
	sh.code = HINCHADA
	hinchada_mat.shader = sh
	mmi.material_override = hinchada_mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


func festejo(lado_local: bool, v: float) -> void:
	hinchada_mat.set_shader_parameter("local_salta" if lado_local else "visita_salta", v)


func _carteles() -> void:
	var textos = ["LEYENDAS", "FÚTBOL ARGENTINO", "TABLA HISTÓRICA", "PRIMERA DIVISIÓN", "DESDE 1891", "20 CLUBES", "LA PELOTA NO SE MANCHA"]
	var colores = [[Color("#0c2240"), Color("#f3b61f")], [Color("#e8dfc8"), Color("#7a2e25")], [Color("#75aadb"), Color("#ffffff")], [Color("#7a2e25"), Color("#e8dfc8")]]
	var k = 0
	for side in [-1.0, 1.0]:
		var z = side * (W / 2.0 + 4.2)
		var x = -60.0
		while x < 60.0:
			var w = 9.6
			var par: Array = colores[k % colores.size()]
			var b = MeshInstance3D.new()
			var bm = BoxMesh.new()
			bm.size = Vector3(w - 0.15, 0.9, 0.12)
			b.mesh = bm
			var m = StandardMaterial3D.new()
			m.albedo_color = par[0]
			m.roughness = 0.6
			b.material_override = m
			b.position = Vector3(x + w / 2.0, 0.45, z)
			add_child(b)
			var lb = Label3D.new()
			lb.text = textos[k % textos.size()]
			lb.font = font
			lb.font_size = 96
			lb.pixel_size = 0.0068
			lb.modulate = par[1]
			lb.outline_size = 0
			lb.shaded = true
			lb.double_sided = false
			lb.position = b.position + Vector3(0, 0, -side * 0.07)
			if side > 0:
				lb.rotation.y = PI
			add_child(lb)
			x += w
			k += 1
	# detrás de los arcos
	for s in [-1.0, 1.0]:
		var zz = -30.0
		while zz < 30.0:
			var par2: Array = colores[k % colores.size()]
			var b2 = MeshInstance3D.new()
			var bm2 = BoxMesh.new()
			bm2.size = Vector3(0.12, 0.9, 9.4)
			b2.mesh = bm2
			var m2 = StandardMaterial3D.new()
			m2.albedo_color = par2[0]
			b2.material_override = m2
			b2.position = Vector3(s * (L / 2.0 + 5.5), 0.45, zz + 4.8)
			add_child(b2)
			zz += 9.6
			k += 1


func _torres() -> void:
	var metal = StandardMaterial3D.new()
	metal.albedo_color = Color("#5c6370")
	var luz = StandardMaterial3D.new()
	luz.albedo_color = Color("#fffbe8")
	luz.emission_enabled = true
	luz.emission = Color("#fff6d8")
	luz.emission_energy_multiplier = 1.6
	for p in [Vector3(-66, 0, -50), Vector3(66, 0, -50), Vector3(-66, 0, 50), Vector3(66, 0, 50)]:
		var t = MeshInstance3D.new()
		var c = CylinderMesh.new()
		c.top_radius = 0.35
		c.bottom_radius = 0.7
		c.height = 38
		t.mesh = c
		t.material_override = metal
		t.position = p + Vector3(0, 19, 0)
		add_child(t)
		var panel = MeshInstance3D.new()
		var bm = BoxMesh.new()
		bm.size = Vector3(5, 3, 0.5)
		panel.mesh = bm
		panel.material_override = luz
		panel.position = p + Vector3(0, 38.5, 0)
		panel.look_at_from_position(panel.position, Vector3(0, 0, 0))
		add_child(panel)

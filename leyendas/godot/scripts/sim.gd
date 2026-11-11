class_name Sim
extends RefCounted
## Motor del partido. No sabe nada de gráficos: trabaja en metros sobre una
## cancha de 105 x 68 (x a lo largo, y a lo ancho, z altura) y avanza en pasos
## fijos de 1/60 s. El equipo 0 lo maneja la persona, el 1 la máquina.

const L := 105.0
const W := 68.0
const GY0 := 34.0 - 3.66
const GY1 := 34.0 + 3.66
const CROSS := 2.44
const GRAV := 9.8
const BR := 0.11
const AREA_X := 16.5
const AREA_Y := 20.16
const KD := 0.011          # resistencia del aire
const KM := 0.013          # efecto Magnus (curva)
const FR0 := 1.5           # roce de la pelota rodando
const FR1 := 0.12
const AIQ := [0.86, 0.97, 1.08]

class Jug:
	var side = 0
	var idx = 0
	var num = 1
	var role = ""
	var bx = 0.0
	var by = 0.0
	var gk = false
	var d: Dictionary
	var pos = Vector2()
	var vel = Vector2()
	var dv = Vector2()
	var face = Vector2(1, 0)
	var sta = 1.0
	var sprint = false
	var touch = 0.0
	var tk = 0.0
	var stun = 0.0
	var recv = 0.0
	var recv_pt = Vector2()
	var dec = 0.0
	var hold = 0.0
	var tgt = Vector2()
	var has_tgt = false
	var anim = 0.0
	var act = ""
	var act_t = 0.0
	var act_dir = Vector2()
	var act_h = 0.0
	var feint = 0.0
	var feint_cd = 0.0
	var feint_dir = Vector2()
	var slide = 0.0
	var slide_dir = Vector2()
	var dive = 0.0
	var dive_v = Vector2()
	var react = 0.0
	var run_t = 0.0
	var run_pt = Vector2()
	var press_t = 0.0
	var yellow = 0
	var off = false

	func esp(e: String) -> bool:
		return e in d["esp"]


class Lado:
	var team: Dictionary
	var kit: Dictionary
	var gk_kit: Dictionary
	var dir = 1
	var side = 0
	var ps: Array = []
	var expulsados: Array = []
	var ch1: Jug = null
	var ch2: Jug = null
	var ch1d = 99.0
	var bp = Vector2()
	var q = 1.0
	var press2 = false


# --- estado del partido ---
var T: Array = []
var datos: Object = null   # el nodo Datos (planteles y formaciones)
var rng := RandomNumberGenerator.new()
var b_pos := Vector2(L / 2, W / 2)
var b_z := 0.0
var b_vel := Vector2()
var b_vz := 0.0
var b_spin := 0.0
var b_top := 0.0
var b_owner: Jug = null
var b_last := 0
var b_kicker: Jug = null
var b_shot := false        # la pelota viaja como remate
var b_shot_side := 0
var b_fresh := 0.0        # recién pateada: los que están al lado no llegan a reaccionar

var time := 0.0
var half := 1
var half_len := 150.0
var score := [0, 0]
var state := "saque"
var st_t := 1.0
var diff := 1
var human: Jug = null
var auto := false           # true = la máquina maneja también al equipo 0
var hold_after_goal := false
var goal_against := 0
var last_goal := {}
var goals: Array = []
var events: Array = []
var msg := ""
var msg_t := 0.0
var auto_t := 0.0
var power := 0.0
var aim_hold := 0.0
var sp := {}                # pelota parada en curso
var stats := {"tiros": [0, 0], "al_arco": [0, 0], "posesion": [0.0, 0.0], "faltas": [0, 0], "corners": [0, 0]}
var pen := {}               # penal en curso
var inp := {
	"mv": Vector2(), "sprint": false, "shoot": false, "pass": false, "long": false,
	"pass_p": false, "long_p": false, "thru_p": false, "switch_p": false, "feint_p": false,
	"shoot_p": false, "thru": false,
}


# =========================================================
# Armado
# =========================================================
func setup(o: Dictionary) -> void:
	datos = o["datos"]
	rng.seed = o.get("seed", randi())
	diff = o["diff"]
	half_len = o["min"] * 30.0
	T = [_mk_side(o["home"], o["kit_h"], o["line_h"], 0, 1), _mk_side(o["away"], o["kit_a"], o["line_a"], 1, -1)]
	T[1].q = AIQ[diff]
	T[0].q = 0.97
	_kits_distintos()
	set_kickoff(0)


func _mk_side(team: Dictionary, kit_i: int, linea: Array, side: int, dir: int) -> Lado:
	var S = Lado.new()
	S.team = team
	S.kit = team["camisetas"][clampi(kit_i, 0, team["camisetas"].size() - 1)]
	S.gk_kit = datos.kits_arquero[side]
	S.dir = dir
	S.side = side
	var f: Array = datos.formaciones[team["esquema"]]
	var once: Array = datos.once(team, linea)
	var nums = [1, 4, 2, 6, 3, 5, 8, 7, 11, 9, 10] if team["esquema"] == "4-3-3" else [1, 4, 2, 6, 3, 5, 8, 7, 10, 9, 11]
	for i in 11:
		var p = Jug.new()
		p.side = side
		p.idx = i
		p.num = nums[i]
		p.role = f[i][0]
		p.bx = f[i][1]
		p.by = f[i][2]
		p.gk = p.role == "ARQ"
		p.d = once[i]
		p.anim = rng.randf() * 6.0
		S.ps.append(p)
	return S


## Si las dos camisetas se parecen mucho, el visitante usa la alternativa.
func _kits_distintos() -> void:
	var a: Color = Color.html(T[0].kit["base"])
	var b: Color = Color.html(T[1].kit["base"])
	var da = absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)
	if da < 0.45:
		for k in T[1].team["camisetas"]:
			var c = Color.html(k["base"])
			if absf(a.r - c.r) + absf(a.g - c.g) + absf(a.b - c.b) >= 0.45:
				T[1].kit = k
				break


# =========================================================
# Utilidades
# =========================================================
func att_x(S: Lado) -> float:
	return L if S.dir > 0 else 0.0


func own_x(S: Lado) -> float:
	return 0.0 if S.dir > 0 else L


func prog(S: Lado, x: float) -> float:
	return x / L if S.dir > 0 else 1.0 - x / L


func wpos(S: Lado, fx: float, fy: float) -> Vector2:
	return Vector2(fx * L if S.dir > 0 else L - fx * L, fy * W if S.dir > 0 else (1.0 - fy) * W)


func en_area(S: Lado, v: Vector2, margen := 0.0) -> bool:
	## ¿Está v dentro del área que defiende S?
	return absf(v.x - own_x(S)) < AREA_X + margen and absf(v.y - 34.0) < AREA_Y + margen


func nearest(S: Lado, v: Vector2, no_gk := true, excl: Jug = null) -> Jug:
	var best: Jug = null
	var bd = 1e9
	for p in S.ps:
		if (no_gk and p.gk) or p == excl:
			continue
		var dd = p.pos.distance_to(v)
		if dd < bd:
			bd = dd
			best = p
	return best


func max_spd(p: Jug) -> float:
	return (5.4 + p.d["vel"] / 100.0 * 3.1) * (0.8 + 0.2 * p.sta)


func flash(t: String) -> void:
	msg = t
	msg_t = 1.6


func cur_min() -> int:
	return mini(45, int(floor(time / half_len * 45.0))) + (45 if half == 2 else 0)


func ev(t: String, extra := {}) -> void:
	var e = {"t": t}
	e.merge(extra)
	events.append(e)


func rnd() -> float:
	return rng.randf()


func gk_of(S: Lado) -> Jug:
	for p in S.ps:
		if p.gk:
			return p
	return null


# =========================================================
# Saques y reanudaciones
# =========================================================
func _reset_p(p: Jug) -> void:
	p.vel = Vector2()
	p.dv = Vector2()
	p.touch = 0.0
	p.tk = 0.0
	p.stun = 0.0
	p.recv = 0.0
	p.dec = 0.3
	p.hold = 0.0
	p.has_tgt = false
	p.act = ""
	p.act_t = 0.0
	p.slide = 0.0
	p.dive = 0.0
	p.feint = 0.0
	p.run_t = 0.0


func _reset_ball() -> void:
	b_vel = Vector2()
	b_vz = 0.0
	b_z = 0.0
	b_spin = 0.0
	b_top = 0.0
	b_kicker = null
	b_shot = false


func set_kickoff(ks: int) -> void:
	for S in T:
		for p in S.ps:
			var fx: float = 0.02 if p.gk else p.bx * 0.47
			if S.side != ks:
				fx = minf(fx, 0.40)
			p.pos = wpos(S, fx, p.by)
			p.face = Vector2(S.dir, 0)
			_reset_p(p)
	var KT: Lado = T[ks]
	var fw = KT.ps.filter(func(p): return not p.gk)
	fw.sort_custom(func(a, b): return a.bx > b.bx)
	var a: Jug = fw[0]
	var b: Jug = fw[1]
	a.pos = Vector2(L / 2 - KT.dir * 0.4, W / 2)
	b.pos = Vector2(L / 2 - KT.dir * 3.0, W / 2 + 5)
	b_pos = Vector2(L / 2, W / 2)
	_reset_ball()
	give_ball(a)
	sp = {"tipo": "saque", "t": 0.0, "taker": a}
	if ks != 0:
		human = nearest(T[0], Vector2(L / 2, W / 2))
	state = "saque"
	st_t = 1.2
	power = 0.0
	ev("silbato")


func restart(S: Lado, x: float, y: float, kind: String, label: String) -> void:
	_reset_ball()
	var p: Jug
	if kind == "arco":
		p = gk_of(S)
	else:
		p = nearest(S, Vector2(x, y))
	b_pos = Vector2(x, y)
	p.pos = Vector2(x, y) - _dir_to_center(Vector2(x, y), S) * 0.5
	if kind == "lateral":
		p.pos = Vector2(x, clampf(y, -0.3, W + 0.3))
	_reset_p(p)
	p.face = _dir_to_center(Vector2(x, y), S)
	if kind == "corner":
		var gx = att_x(S)
		p.face = (Vector2(gx - S.dir * 11, 34) - b_pos).normalized()
	give_ball(p)
	p.dec = 0.6
	if p.side == 0 and not p.gk:
		human = p
	var dist_min = 9.15 if kind in ["corner", "libre", "arco"] else 3.0
	if kind == "corner":
		_ubicar_corner(S)
	for q in T[1 - S.side].ps:
		if q.gk:
			continue
		var dd = q.pos.distance_to(b_pos)
		if dd < dist_min:
			var away = (q.pos - b_pos).normalized() if dd > 0.01 else Vector2(-S.dir, 0)
			q.pos = b_pos + away * (dist_min + 0.3)
			q.pos.x = clampf(q.pos.x, 0.5, L - 0.5)
			q.pos.y = clampf(q.pos.y, 0.5, W - 0.5)
	if kind == "libre":
		_armar_barrera(S)
	for q in S.ps:
		if q != p:
			q.vel = Vector2()
	sp = {"tipo": kind, "t": 0.0, "taker": p}
	state = "saque"
	st_t = 0.9
	flash(label)
	if kind == "corner":
		stats["corners"][S.side] += 1


func _dir_to_center(v: Vector2, S: Lado) -> Vector2:
	var c = Vector2(L / 2 + S.dir * 10, W / 2)
	return (c - v).normalized()


func _ubicar_corner(S: Lado) -> void:
	var O: Lado = T[1 - S.side]
	var gx = att_x(S)
	var spots = [Vector2(-7, -3), Vector2(-9, 2), Vector2(-5.5, 4.5), Vector2(-12, -1), Vector2(-14, 6)]
	var k = 0
	var atq = S.ps.filter(func(p): return not p.gk and p != b_owner)
	atq.sort_custom(func(a, b): return a.d["cab"] > b.d["cab"])
	for p in atq:
		if k < spots.size() and p.role != "LD" and p.role != "LI":
			var s: Vector2 = spots[k]
			p.pos = Vector2(gx + S.dir * s.x, 34 + s.y + rng.randf_range(-1, 1))
			k += 1
	var dk = 0
	for q in O.ps:
		if q.gk:
			q.pos = Vector2(own_x(O) + O.dir * 0.6, 34)
			continue
		if q.role in ["DFC", "LD", "LI", "MCD"] or dk < 6:
			var s2: Vector2 = spots[dk % spots.size()]
			q.pos = Vector2(gx + S.dir * (s2.x + 1.2), 34 + s2.y * 0.9 + (0.8 if dk % 2 == 0 else -0.8))
			dk += 1


func _armar_barrera(S: Lado) -> void:
	var O: Lado = T[1 - S.side]
	var goal = Vector2(own_x(O), 34)
	var dg = b_pos.distance_to(goal)
	if dg > 32:
		return
	var dirg = (goal - b_pos).normalized()
	var perp = Vector2(-dirg.y, dirg.x)
	var n = 4 if dg < 24 else 3
	var cands = O.ps.filter(func(p): return not p.gk)
	cands.sort_custom(func(a, b): return a.pos.distance_to(b_pos) < b.pos.distance_to(b_pos))
	for i in mini(n, cands.size()):
		var q: Jug = cands[i]
		q.pos = b_pos + dirg * 9.15 + perp * ((i - (n - 1) / 2.0) * 0.62 + 0.4)
		q.vel = Vector2()
		q.has_tgt = true
		q.tgt = q.pos
		q.hold = 2.0   # se quedan quietos en la barrera
	var gk = gk_of(O)
	if gk:
		gk.pos = Vector2(own_x(O) + O.dir * 0.5, 34 - perp.y * 1.6)


func give_ball(p: Jug) -> void:
	b_owner = p
	b_last = p.side
	b_vz = 0.0
	b_z = 0.0
	b_spin = 0.0
	b_top = 0.0
	b_shot = false
	p.recv = 0.0
	p.hold = 0.0
	p.dec = maxf(p.dec, 0.35 + rng.randf() * 0.35)
	if p.side == 0 and not p.gk:
		human = p


# =========================================================
# Movimiento
# =========================================================
func move_to(p: Jug, t: Vector2, mul: float, sprint := false) -> void:
	var dd = t - p.pos
	var dist = dd.length()
	p.sprint = sprint and p.sta > 0.08
	if dist < 0.25:
		p.dv = Vector2()
		return
	var spd = minf(max_spd(p) * mul * (1.22 if p.sprint else 1.0), dist * 2.6)
	p.dv = dd / dist * spd


func integrate(p: Jug, dt: float) -> void:
	p.touch -= dt
	p.tk -= dt
	p.stun -= dt
	p.feint_cd -= dt
	p.run_t -= dt
	p.act_t -= dt
	if p.act_t <= 0.0 and p.act != "festejo":
		p.act = ""
	var dv = p.dv
	if p.slide > 0.0:
		p.slide -= dt
		var s = p.slide_dir * (3.0 + 7.0 * clampf(p.slide / 0.6, 0, 1))
		p.vel = s
		p.pos += p.vel * dt
		if p.slide <= 0.0:
			p.stun = maxf(p.stun, 0.45)
		_clamp_pos(p)
		return
	if p.dive > 0.0:
		p.dive -= dt
		p.vel = p.dive_v * clampf(p.dive / 0.5, 0.2, 1.0)
		p.pos += p.vel * dt
		if p.dive <= 0.0:
			p.stun = maxf(p.stun, 0.55)
		_clamp_pos(p)
		return
	if p.feint > 0.0:
		p.feint -= dt
		dv = p.feint_dir * max_spd(p) * 1.05 + p.dv * 0.35
	if p.stun > 0.0:
		dv *= 0.25
	var acc = (13.0 + p.d["ace"] / 100.0 * 9.0) * dt
	if b_owner == p:
		acc *= 0.85
	var dlt = dv - p.vel
	if dlt.length() > acc:
		p.vel += dlt.normalized() * acc
	else:
		p.vel = dv
	p.pos += p.vel * dt
	_clamp_pos(p)
	var spd = p.vel.length()
	if spd > 0.35:
		var want = p.vel / spd
		if b_owner == p:
			# con la pelota se gira más lento: la gambeta importa
			var max_turn = (6.0 + p.d["reg"] / 100.0 * 7.0) * dt * (0.6 if p.sprint else 1.0)
			var ang = p.face.angle_to(want)
			p.face = p.face.rotated(clampf(ang, -max_turn, max_turn))
		else:
			p.face = p.face.slerp(want, minf(1.0, 14.0 * dt)).normalized()
	p.anim += spd * dt * 2.3
	# resistencia
	var mx = max_spd(p)
	if p.sprint and spd > mx * 0.9:
		p.sta -= dt * 0.085 * (1.45 - p.d["res"] / 100.0)
	elif spd < mx * 0.6:
		p.sta += dt * (0.035 + p.d["res"] / 100.0 * 0.03)
	else:
		p.sta += dt * 0.008
	p.sta = clampf(p.sta, 0.0, 1.0)
	if p.sta < 0.08:
		p.sprint = false


func _clamp_pos(p: Jug) -> void:
	p.pos.x = clampf(p.pos.x, -3.0, L + 3.0)
	p.pos.y = clampf(p.pos.y, -2.5, W + 2.5)


func separate() -> void:
	var all: Array = T[0].ps + T[1].ps
	for i in all.size():
		var a: Jug = all[i]
		for j in range(i + 1, all.size()):
			var b: Jug = all[j]
			var dd = b.pos - a.pos
			var dist = dd.length()
			if dist > 0.001 and dist < 0.75:
				var wa = 0.5 + (b.d["fis"] - a.d["fis"]) / 400.0
				var k = (0.75 - dist) / dist
				a.pos -= dd * k * wa
				b.pos += dd * k * (1.0 - wa)


# =========================================================
# Pelota
# =========================================================
## Velocidad inicial para que una pelota rodando recorra `dist` y llegue a `v1`.
func v0_para(dist: float, v1: float) -> float:
	var c = FR0 / FR1
	var lo = v1
	var hi = 45.0
	for _i in 30:
		var v0 = (lo + hi) * 0.5
		var t1 = log((v0 + c) / (v1 + c)) / FR1
		var dd = (v0 - v1) / FR1 - c * t1
		if dd < dist:
			lo = v0
		else:
			hi = v0
	return (lo + hi) * 0.5


## Tiempo que tarda una pelota rodando en recorrer `dist` saliendo a `v0`.
func t_rodando(dist: float, v0: float) -> float:
	var t = 0.0
	var v = v0
	var dd = 0.0
	var h = 0.05
	while dd < dist and t < 6.0 and v > 0.2:
		dd += v * h
		v -= (FR0 + FR1 * v) * h
		t += h
	return t


func dribble(dt: float) -> void:
	var o = b_owner
	if o == null:
		return
	var spd = o.vel.length()
	var mx = max_spd(o)
	o.anim += 0.0
	var r = 0.5 + clampf(spd / mx, 0, 1) * 0.25
	if o.sprint and spd > mx * 0.8:
		# al correr se adelanta la pelota: más rápido pero más fácil de perder
		var largo = 0.7 + (1.0 - o.d["reg"] / 100.0) * 1.9
		r += largo * (0.5 + 0.5 * sin(o.anim * 2.4))
	if o.feint > 0.0:
		r = 0.45
	var tgt = o.pos + o.face * r
	var prev = b_pos
	b_pos = b_pos.lerp(tgt, minf(1.0, dt * 16.0))
	b_vel = (b_pos - prev) / dt
	b_z = 0.0
	b_vz = 0.0
	if b_pos.distance_to(o.pos) > 3.0:
		b_owner = null


func kick(p: Jug, dir: Vector2, speed: float, vz: float, err: float, spin := 0.0, top := 0.0) -> void:
	var a = dir.angle() + rng.randfn(0.0, err * 0.6)
	b_owner = null
	b_vel = Vector2.from_angle(a) * speed
	b_vz = vz
	b_z = maxf(b_z, 0.03)
	b_spin = spin
	b_top = top
	b_kicker = p
	b_last = p.side
	b_shot = false
	b_fresh = 0.16
	p.touch = 0.3
	p.act = "patada"
	p.act_t = 0.35
	p.act_dir = dir
	p.act_h = 1.0 if speed > 20 else 0.6


func ball_phys(dt: float) -> void:
	if b_owner:
		return
	var air = b_z > 0.001 or b_vz > 0.0
	var v3 = Vector3(b_vel.x, b_vel.y, b_vz)
	var spd = v3.length()
	if air:
		var drag = -v3 * spd * KD
		var hv = b_vel.length()
		var lat = Vector2(-b_vel.y, b_vel.x) * KM * b_spin
		b_vel += (Vector2(drag.x, drag.y) + lat) * dt
		b_vz += (drag.z - GRAV + KM * 0.6 * -b_top * hv * 0.5) * dt
		b_spin *= 1.0 - 0.25 * dt
	else:
		var sp2 = b_vel.length()
		if sp2 > 0.0:
			var dec = (FR0 + FR1 * sp2) * dt
			var ns = maxf(0.0, sp2 - dec)
			b_vel *= ns / sp2
			b_vel += Vector2(-b_vel.y, b_vel.x) * KM * b_spin * 0.25 * dt
		b_spin *= 1.0 - 1.5 * dt
	b_pos += b_vel * dt
	b_z += b_vz * dt
	if b_z <= 0.0:
		b_z = 0.0
		if b_vz < -1.3:
			b_vz = -b_vz * 0.52
			b_vel *= 0.86
			b_vel += b_vel.normalized() * b_top * 0.15
			b_spin *= 0.6
			b_top *= 0.5
			if b_vz > 2.5:
				ev("pique", {"v": b_vz})
		else:
			b_vz = 0.0
	_posts()


func _posts() -> void:
	for gx in [0.0, L]:
		if absf(b_pos.x - gx) > 1.0:
			continue
		# palos
		if b_z < CROSS + BR:
			for py in [GY0, GY1]:
				var c = Vector2(gx, py)
				var dd = b_pos - c
				var dist = dd.length()
				if dist < 0.06 + BR and dist > 0.0001:
					var n = dd / dist
					var vn = b_vel.dot(n)
					if vn < 0:
						b_vel -= n * vn * 1.6
						b_vel *= 0.85
						b_pos = c + n * (0.06 + BR + 0.01)
						b_spin *= 0.3
						ev("palo")
						b_shot = false
		# travesaño
		if b_pos.y > GY0 and b_pos.y < GY1:
			var c2 = Vector2(gx, CROSS)
			var dd2 = Vector2(b_pos.x, b_z) - c2
			var dist2 = dd2.length()
			if dist2 < 0.06 + BR and dist2 > 0.0001:
				var n2 = dd2 / dist2
				var vv = Vector2(b_vel.x, b_vz)
				var vn2 = vv.dot(n2)
				if vn2 < 0:
					vv -= n2 * vn2 * 1.55
					b_vel.x = vv.x * 0.85
					b_vz = vv.y * 0.85
					b_pos.x = gx + n2.x * (0.06 + BR + 0.01)
					b_z = CROSS + n2.y * (0.06 + BR + 0.01)
					ev("palo")
					b_shot = false


func net_clamp() -> void:
	var depth = 2.0
	if b_pos.x < 0.0 or b_pos.x > L:
		var gx = 0.0 if b_pos.x < 0.0 else L
		var back = gx - depth if gx == 0.0 else gx + depth
		if (gx == 0.0 and b_pos.x < back) or (gx == L and b_pos.x > back):
			b_pos.x = back
			b_vel.x = -b_vel.x * 0.1
			b_vel.y *= 0.4
			b_vz *= 0.4
		b_pos.y = clampf(b_pos.y, GY0 + BR, GY1 - BR)
		if b_z > CROSS - BR:
			b_z = CROSS - BR
			b_vz = minf(0.0, b_vz)
		b_vel *= 0.97


# =========================================================
# Acciones con la pelota
# =========================================================
func pressure_on(p: Jug) -> float:
	var near = 99.0
	for o in T[1 - p.side].ps:
		near = minf(near, o.pos.distance_to(p.pos))
	return clampf((4.0 - near) / 3.0, 0.0, 1.0)


func do_pass(p: Jug, q: Jug, lofted: bool) -> void:
	var d0 = q.pos.distance_to(p.pos)
	var lead_t = d0 / (14.0 if lofted else 17.0)
	var tgt = q.pos + q.vel * lead_t * 0.85
	var dist = tgt.distance_to(p.pos)
	var prs = pressure_on(p)
	var err = (100.0 - p.d["pas"]) / 100.0 * 0.09 * (1.0 + prs * 0.7) * (1.3 if lofted else 1.0)
	if p.esp("vis"):
		err *= 0.6
	if lofted:
		_lob_to(p, tgt, dist, err, 2.0 if dist > 25 else 1.4)
	else:
		var v1 = clampf(6.0 + dist * 0.1, 6.0, 12.0)
		var v0 = v0_para(dist, v1) * (1.0 + rng.randfn(0, err * 0.4))
		kick(p, tgt - p.pos, v0, 0.0, err)
	q.recv = 1.6
	q.recv_pt = tgt
	if p.side == 0 and not q.gk:
		human = q
	ev("pase", {"fuerza": 0.4})


func _lob_to(p: Jug, tgt: Vector2, dist: float, err: float, alt: float) -> void:
	var tf = clampf(0.7 + dist * 0.028 * alt * 0.6, 0.9, 2.6)
	var vz = GRAV * tf / 2.0
	var vh = (exp(KD * dist * 0.85) - 1.0) / (KD * 0.85 * tf)
	kick(p, tgt - p.pos, vh, vz, err, rng.randfn(0, 1.5), -2.0)


func do_through(p: Jug, q: Jug) -> void:
	var S: Lado = T[p.side]
	var goal = Vector2(att_x(S), 34)
	var run = q.vel if q.vel.length() > 2.0 else (goal - q.pos).normalized() * 6.0
	run = run.normalized()
	if run.x * S.dir < 0.1:
		run = (run + Vector2(S.dir, 0) * 0.8).normalized()
	var lead = clampf(7.0 + q.d["vel"] * 0.04, 7.0, 12.0)
	var tgt = q.pos + run * lead
	tgt.x = clampf(tgt.x, 2, L - 2)
	tgt.y = clampf(tgt.y, 2, W - 2)
	var dist = tgt.distance_to(p.pos)
	var err = (100.0 - p.d["pas"]) / 100.0 * 0.08 * (1.0 + pressure_on(p) * 0.6)
	if p.esp("vis"):
		err *= 0.55
	var v0 = v0_para(dist, 3.2)
	kick(p, tgt - p.pos, v0, 0.0, err)
	q.recv = 2.4
	q.recv_pt = tgt
	q.run_t = 2.0
	q.run_pt = tgt
	if p.side == 0 and not q.gk:
		human = q
	ev("pase", {"fuerza": 0.5})


func do_cross(p: Jug) -> void:
	var S: Lado = T[p.side]
	var gx = att_x(S)
	var box = S.ps.filter(func(m): return m != p and absf(m.pos.x - gx) < 18 and absf(m.pos.y - 34) < 15)
	var tgt = Vector2(gx - S.dir * rng.randf_range(6, 11), 34 + rng.randf_range(-5, 5))
	if not box.is_empty():
		box.sort_custom(func(a, b): return a.d["cab"] > b.d["cab"])
		var m: Jug = box[0] if rnd() < 0.6 else box[rng.randi() % box.size()]
		tgt = m.pos + m.vel * 0.8
		m.recv = 1.8
		m.recv_pt = tgt
	var dist = tgt.distance_to(p.pos)
	var err = (100.0 - p.d["pas"]) / 100.0 * 0.1
	var tf = clampf(0.8 + dist * 0.025, 1.0, 1.7)
	var vz = GRAV * tf / 2.0 * 0.92
	var vh = (exp(KD * dist * 0.85) - 1.0) / (KD * 0.85 * tf) * 1.04
	var curl = -signf((tgt - p.pos).normalized().cross(Vector2(S.dir, 0))) * 4.0
	kick(p, tgt - p.pos, vh, vz, err, curl * 0.5, -1.0)
	ev("pase", {"fuerza": 0.6})


## Remate. aim: -1..1 a lo ancho del arco; finesse: colocado con rosca; chip: vaselina.
func shoot(p: Jug, power: float, aim: float, finesse := false, chip := false) -> void:
	var S: Lado = T[p.side]
	var gx = att_x(S)
	var ty = 34.0 + aim * 3.15
	var tgt = Vector2(gx, ty)
	var dist = tgt.distance_to(p.pos)
	var prs = pressure_on(p)
	var tir: float = p.d["tir"]
	var err = (100.0 - tir) / 100.0 * 0.075 + power * power * 0.025 + prs * 0.03 + maxf(0, dist - 20) * 0.0015
	var spd = 17.0 + power * 13.0 + tir / 100.0 * 3.0
	if p.esp("pot"):
		spd += 3.0
	var vz = 0.6 + power * 3.0 + rng.randfn(0, 0.9) * (1.15 - tir / 110.0) + dist * 0.035
	var spin = 0.0
	var top = 0.0
	if chip:
		spd = clampf(dist * 0.62, 9, 19)
		vz = clampf(dist * 0.42, 5.5, 9.5)
		err *= 1.2
		top = 3.0
	elif finesse:
		spd *= 0.86
		err *= 0.8
		var side = signf(34.0 - ty) if absf(ty - 34) > 0.5 else (1.0 if rnd() < 0.5 else -1.0)
		var dirn = (tgt - p.pos).normalized()
		var perp = Vector2(-dirn.y, dirn.x)
		var s_dir = signf(perp.dot(Vector2(0, side)))
		spin = s_dir * (6.0 + tir / 100.0 * 7.0)
		var alpha = KM * absf(spin) * dist / (2.0 * spd)
		tgt = p.pos + dirn.rotated(-s_dir * alpha) * dist
	else:
		top = 4.0 + power * 6.0 if p.esp("pot") else 2.0 + power * 3.0
	kick(p, tgt - p.pos, spd, vz, err, spin, top)
	b_shot = true
	b_shot_side = p.side
	stats["tiros"][p.side] += 1
	_mark_react(T[1 - p.side])
	ev("remate", {"fuerza": power})


func _mark_react(O: Lado) -> void:
	var gk = gk_of(O)
	if gk:
		gk.react = 0.08 + (100.0 - gk.d["arq"]) / 500.0


func free_kick_shot(p: Jug, aim: float, power: float, curl: float) -> void:
	## Tiro libre con comba: curl -1..1 define hacia dónde dobla.
	var S: Lado = T[p.side]
	var gx = att_x(S)
	var ty = 34.0 + aim * 3.2
	var tgt = Vector2(gx, ty)
	var dist = tgt.distance_to(p.pos)
	var tir: float = p.d["tir"]
	var tl = p.esp("tl")
	var spd = 21.0 + power * 8.0 + (2.0 if tl else 0.0)
	var err = (100.0 - tir) / 100.0 * 0.06 * (0.5 if tl else 1.0) + power * 0.02
	var dirn = (tgt - p.pos).normalized()
	var spin = curl * (9.0 + (5.0 if tl else 0.0))
	var alpha = KM * spin * dist / (2.0 * spd)
	var vz = 4.2 + dist * 0.06 + power * 1.6 + rng.randfn(0, 0.4) * (0.6 if tl else 1.0)
	kick(p, dirn.rotated(-alpha), spd, vz, err, spin, 5.0)
	b_shot = true
	b_shot_side = p.side
	stats["tiros"][p.side] += 1
	_mark_react(T[1 - p.side])
	ev("remate", {"fuerza": power})


func do_feint(p: Jug, want: Vector2) -> void:
	if p.feint_cd > 0.0 or p.sta < 0.06:
		return
	var S: Lado = T[p.side]
	var near: Jug = null
	var nd = 99.0
	for o in T[1 - p.side].ps:
		var dd = o.pos.distance_to(p.pos)
		if dd < nd:
			nd = dd
			near = o
	var side = Vector2(-p.face.y, p.face.x)
	if want.length() > 0.2:
		side = want.normalized()
	elif near:
		var rel = (p.pos - near.pos)
		side = side * signf(side.dot(rel) + 0.001)
	p.feint = 0.32
	p.feint_cd = 1.1
	p.feint_dir = (side * 0.9 + Vector2(S.dir, 0) * 0.35).normalized()
	p.sta -= 0.03
	p.act = "gambeta"
	p.act_t = 0.4
	p.act_dir = p.feint_dir
	# los que están cerca y no leen el amague quedan pagando
	var bonus = 12.0 if p.esp("gam") else 0.0
	for o in T[1 - p.side].ps:
		if o.gk:
			continue
		if o.pos.distance_to(p.pos) < 2.6:
			var ch = 0.35 + (p.d["reg"] + bonus - o.d["def"]) / 120.0
			if rnd() < ch:
				o.stun = maxf(o.stun, 0.55)
				o.tk = maxf(o.tk, 0.9)
	ev("gambeta")


# =========================================================
# Quites, barridas y faltas
# =========================================================
func try_tackle(q: Jug, o: Jug, hum: bool) -> void:
	if q.tk > 0.0:
		return
	q.tk = 0.45 if hum else 0.9 + rnd() * 0.5
	q.act = "quite"
	q.act_t = 0.3
	q.act_dir = (b_pos - q.pos).normalized()
	var pr = 0.3 + (q.d["def"] - o.d["reg"]) / 160.0 + (q.d["fis"] - o.d["fis"]) / 500.0
	if hum:
		pr += 0.08
	if q.esp("muro"):
		pr += 0.08
	if o.esp("gam"):
		pr -= 0.06
	if o.feint > 0.0:
		pr *= 0.2
	if b_pos.distance_to(o.pos) > 1.1:
		pr += 0.15     # la llevaba lejos del pie
	if q.side == 1:
		pr *= [0.8, 1.0, 1.18][diff]
	if b_pos.distance_to(q.pos) > 1.5:
		pr *= 0.4
	if rnd() < pr:
		o.stun = 0.5
		o.touch = 0.4
		ev("quite")
		if rnd() < 0.62:
			give_ball(q)
		else:
			_loose(q, (b_pos - q.pos).normalized())
	else:
		q.stun = maxf(q.stun, 0.12)
		if rnd() < 0.04:
			_foul(q, o, false)


func start_slide(q: Jug, dir: Vector2) -> void:
	if q.slide > 0.0 or q.stun > 0.0 or q.gk:
		return
	q.slide = 0.6
	q.slide_dir = dir.normalized() if dir.length() > 0.1 else q.face
	q.act = "barrida"
	q.act_t = 1.0
	q.act_dir = q.slide_dir
	q.sta -= 0.03
	q.tk = 1.2


func _check_slides() -> void:
	for S in T:
		for q in S.ps:
			if q.slide <= 0.0:
				continue
			var bd = q.pos.distance_to(b_pos)
			var o = b_owner
			if bd < 1.05 and b_z < 0.6:
				var behind = false
				if o and o.side != q.side:
					behind = o.face.dot(q.slide_dir) > 0.55
				var pr = 0.72 + (q.d["def"] - (o.d["reg"] if o else 60.0)) / 220.0
				if rnd() < pr and not (behind and rnd() < 0.55):
					if o and o.side != q.side:
						o.stun = 0.6
						o.act = "caida"
						o.act_t = 0.8
					_loose(q, q.slide_dir)
					ev("quite")
				elif o and o.side != q.side:
					_foul(q, o, behind)
				q.slide = minf(q.slide, 0.15)
			elif o and o.side != q.side and q.pos.distance_to(o.pos) < 0.85:
				_foul(q, o, o.face.dot(q.slide_dir) > 0.55)
				q.slide = minf(q.slide, 0.15)


func _loose(q: Jug, dir: Vector2) -> void:
	b_owner = null
	b_vel = dir.normalized() * rng.randf_range(4, 8) + Vector2(rng.randfn(0, 2), rng.randfn(0, 2))
	b_vz = rng.randf_range(0, 1.5)
	b_last = q.side
	b_kicker = q
	q.touch = 0.25


func _foul(q: Jug, o: Jug, behind: bool) -> void:
	if state != "juego":
		return
	stats["faltas"][q.side] += 1
	o.stun = 0.9
	o.act = "caida"
	o.act_t = 1.2
	ev("falta")
	var card = ""
	if behind and rnd() < 0.55:
		card = "amarilla"
	elif rnd() < 0.12:
		card = "amarilla"
	if card == "amarilla":
		q.yellow += 1
		if q.yellow >= 2:
			card = "roja"
	var S: Lado = T[o.side]
	var O: Lado = T[q.side]
	var spot = o.pos
	spot.x = clampf(spot.x, 1, L - 1)
	spot.y = clampf(spot.y, 1, W - 1)
	var label = "Falta de " + q.d["corto"]
	if card == "amarilla":
		label = "Amarilla para " + q.d["corto"]
		ev("tarjeta", {"color": "amarilla"})
	elif card == "roja":
		label = "¡Roja para " + q.d["corto"] + "!"
		ev("tarjeta", {"color": "roja"})
	if card == "roja":
		_expulsar(q)
	if en_area(O, spot):
		set_penalty(S, label)
	else:
		restart(S, spot.x, spot.y, "libre", label)


func _expulsar(q: Jug) -> void:
	var S: Lado = T[q.side]
	S.ps.erase(q)
	S.expulsados.append(q)
	q.off = true
	if human == q:
		human = nearest(S, b_pos)
	if b_owner == q:
		b_owner = null


# =========================================================
# Penales
# =========================================================
func set_penalty(S: Lado, label: String) -> void:
	var O: Lado = T[1 - S.side]
	var gx = own_x(O)
	var spot = Vector2(gx + O.dir * 11.0, 34)
	_reset_ball()
	b_pos = spot
	var taker: Jug = null
	var best = -1.0
	for p in S.ps:
		if p.gk:
			continue
		var s: float = p.d["tir"] + (8.0 if p.esp("tl") else 0.0)
		if s > best:
			best = s
			taker = p
	for SS in T:
		for p in SS.ps:
			_reset_p(p)
			if p.gk and SS == O:
				p.pos = Vector2(gx + O.dir * 0.3, 34)
				p.face = Vector2(O.dir, 0)
			elif p.gk:
				p.pos = Vector2(own_x(SS) + SS.dir * 2.0, 34)
			elif p != taker:
				var fx = gx + O.dir * rng.randf_range(19.0, 26.0)
				p.pos = Vector2(fx, 34 + rng.randf_range(-16, 16))
				p.face = Vector2(-O.dir, 0)
	taker.pos = spot + (spot - Vector2(gx, 34)).normalized() * 2.2
	taker.face = (Vector2(gx, 34) - taker.pos).normalized()
	give_ball(taker)
	b_pos = spot
	if taker.side == 0:
		human = taker
	pen = {"taker": taker, "t": 0.0, "gk": gk_of(O), "pateado": false, "aim": 0.0}
	sp = {}
	state = "penal"
	st_t = 0.0
	flash("¡Penal! " + label)
	ev("silbato")


func _penalty_step(dt: float) -> void:
	var taker: Jug = pen["taker"]
	pen["t"] += dt
	b_owner = null
	b_vel = Vector2()
	if pen["pateado"]:
		return
	var kick_now = false
	var aim = 0.0
	var pw = 0.6
	if taker.side == 0 and not auto:
		if inp["shoot"]:
			power = minf(1.0, power + dt * 1.2)
		elif power > 0.0:
			kick_now = true
			pw = power
			aim = clampf(inp["mv"].y, -1, 1) * 0.92
			if absf(aim) < 0.2:
				aim = 0.0
		elif pen["t"] > 10.0:
			kick_now = true
			aim = rng.randf_range(-0.9, 0.9)
	elif pen["t"] > 1.6:
		kick_now = true
		aim = [-0.8, 0.0, 0.8][rng.randi() % 3] + rng.randf_range(-0.12, 0.12)
		pw = rng.randf_range(0.35, 0.75)
	if not kick_now:
		return
	pen["pateado"] = true
	power = 0.0
	taker.pos = b_pos - taker.face * 0.5
	var gk: Jug = pen["gk"]
	var S: Lado = T[taker.side]
	var err = (100.0 - taker.d["tir"]) / 100.0 * 0.05 + pw * pw * 0.04
	var ty = 34.0 + aim * 3.1
	kick(taker, Vector2(att_x(S), ty) - b_pos, 17.0 + pw * 11.0, 0.3 + pw * 2.4 + rng.randfn(0, 0.5), err)
	b_shot = true
	b_shot_side = taker.side
	stats["tiros"][taker.side] += 1
	# el arquero adivina
	if gk:
		var side = 0.0
		if gk.side == 0 and not auto:
			side = signf(inp["mv"].y) if absf(inp["mv"].y) > 0.3 else 0.0
		else:
			var guess = rnd()
			var real = signf(aim) if absf(aim) > 0.3 else 0.0
			var ok = guess < 0.34 + gk.d["arq"] / 400.0
			side = real if ok else ([-1.0, 0.0, 1.0][rng.randi() % 3])
		gk.react = 0.0
		if side != 0.0:
			gk.dive = 0.6
			gk.dive_v = Vector2(-S.dir * 0.5, side * (3.2 + gk.d["arq"] * 0.03))
			gk.act = "palomita"
			gk.act_t = 1.1
			gk.act_dir = Vector2(0, side)
			gk.act_h = 0.5
	state = "juego"
	pen = {}
	ev("remate", {"fuerza": pw})


# =========================================================
# Arquero
# =========================================================
func gk_ai(p: Jug, S: Lado, O: Lado, dt: float) -> void:
	var gx = own_x(S)
	var d = float(S.dir)
	if b_owner == p:
		p.hold += dt
		p.dv = Vector2()
		if p.hold > 1.2:
			_gk_distribute(p, S, O)
		return
	p.react -= dt
	if p.dive > 0.0:
		return
	# atajar un remate
	if b_owner == null and signf(b_vel.x) == -d and absf(b_vel.x) > 6.0:
		var t = (p.pos.x - b_pos.x) / b_vel.x
		if t > 0.0 and t < 1.3:
			var py = b_pos.y + b_vel.y * t
			var pz = b_z + b_vz * t - 0.5 * GRAV * t * t
			if py > GY0 - 1.5 and py < GY1 + 1.5 and pz < CROSS + 0.6:
				var dy = py - p.pos.y
				var run_t = absf(dy) / (max_spd(p) * 1.2)
				if absf(dy) < 0.6 or (run_t < t * 0.7 and absf(dy) < 2.0):
					move_to(p, Vector2(p.pos.x, clampf(py, GY0 - 0.5, GY1 + 0.5)), 1.5)
					return
				if p.react <= 0.0 and t < 0.75:
					var reach = 2.2 + p.d["arq"] / 100.0 * 1.5
					var vy = clampf(dy / maxf(t, 0.25), -reach / 0.4, reach / 0.4)
					p.dive = 0.55
					p.dive_v = Vector2(d * 0.8, vy)
					p.act = "palomita"
					p.act_t = 1.0
					p.act_dir = Vector2(0, signf(dy))
					p.act_h = clampf(pz / 2.2, 0.0, 1.0)
					return
				move_to(p, Vector2(gx + d * 0.5, clampf(py, GY0, GY1)), 1.4)
				return
	var in_box = en_area(S, b_pos)
	var bd = p.pos.distance_to(b_pos)
	# salir a cortar centros o pelotas sueltas
	if b_owner == null and in_box and (bd < 10.0 or (b_z > 1.2 and absf(b_pos.x - gx) < 7.0)):
		var tt = clampf(bd / 7.0, 0.05, 0.7)
		move_to(p, b_pos + b_vel * tt, 1.35, true)
		return
	if b_owner and b_owner.side != S.side and in_box and bd < 6.0:
		move_to(p, b_pos, 1.25, true)
		return
	var dist_g = b_pos.distance_to(Vector2(gx, 34))
	var off = clampf(dist_g * 0.09, 0.6, 5.0)
	if dist_g > 50:
		off = 7.0 + (dist_g - 50) * 0.15
	var ang = (b_pos - Vector2(gx, 34)).angle()
	var t2 = Vector2(gx, 34) + Vector2.from_angle(ang) * off
	t2.y = clampf(t2.y, GY0 + 0.4, GY1 - 0.4) if off < 6 else clampf(t2.y, 28, 40)
	move_to(p, t2, 1.0)


func _gk_distribute(p: Jug, S: Lado, O: Lado) -> void:
	var m = best_pass(p, S, O, Vector2(), false, false)
	if m and m.pos.distance_to(p.pos) < 32 and laneblock(p, m, O) < 1.0:
		do_pass(p, m, m.pos.distance_to(p.pos) > 26)
		p.act = "saque"
		p.act_t = 0.5
	else:
		var tgt = Vector2(L / 2 + S.dir * rng.randf_range(0, 18), rng.randf_range(14, 54))
		var far = best_pass(p, S, O, Vector2(S.dir, 0), false, true)
		if far:
			tgt = far.pos
		_lob_to(p, tgt, tgt.distance_to(p.pos), 0.08, 2.2)
	if p.side == 0:
		human = nearest(S, b_pos + b_vel)


# =========================================================
# IA de campo
# =========================================================
func laneblock(p: Jug, q: Jug, O: Lado) -> float:
	var d = q.pos - p.pos
	var dd = d.length_squared()
	var block = 0.0
	for o in O.ps:
		var t = clampf((o.pos - p.pos).dot(d) / dd, 0.0, 1.0)
		var k = (p.pos + d * t).distance_to(o.pos)
		if k < 2.2:
			block += 2.2 - k
	return block


func space_of(v: Vector2, O: Lado) -> float:
	var s = 99.0
	for o in O.ps:
		s = minf(s, o.pos.distance_to(v))
	return s


func best_pass(p: Jug, S: Lado, O: Lado, dir: Vector2, fwd: bool, long_p := false) -> Jug:
	var best: Jug = null
	var bs = -1e9
	for q in S.ps:
		if q == p:
			continue
		var d = q.pos - p.pos
		var dist = d.length()
		if dist < 4.0 or dist > (62.0 if long_p else 44.0):
			continue
		if q.gk and dir == Vector2():
			continue
		var block = laneblock(p, q, O)
		var space = space_of(q.pos, O)
		var gain = (prog(S, q.pos.x) - prog(S, p.pos.x)) * L
		var s = 0.0
		if space < 1.6:
			block += 2.0
		if dir != Vector2():
			var c = d.dot(dir) / dist
			if c < 0.45:
				continue
			s = c * 45.0 + (minf(dist, 40.0) * 0.3 if long_p else -dist * 0.35) - block * (1.0 if long_p else 4.0) + minf(space, 8.0) * 0.6
		else:
			if fwd and gain < 3.0:
				continue
			s = gain * (0.9 if fwd else 0.45) + minf(space, 10.0) * 1.3 - block * 9.0 - dist * 0.12
		if s > bs:
			bs = s
			best = q
	return best


func best_through(p: Jug, S: Lado, O: Lado, dir: Vector2) -> Jug:
	var best: Jug = null
	var bs = -1e9
	for q in S.ps:
		if q == p or q.gk:
			continue
		var d = q.pos - p.pos
		var dist = d.length()
		if dist < 5.0 or dist > 40.0:
			continue
		var gain = (prog(S, q.pos.x) - prog(S, p.pos.x)) * L
		var s = gain * 1.2 + (12.0 if q.run_t > 0 else 0.0) - laneblock(p, q, O) * 3.0
		if dir != Vector2():
			var c = d.dot(dir) / dist
			if c < 0.3:
				continue
			s += c * 30.0
		if gain < -2.0:
			s -= 30.0
		if s > bs:
			bs = s
			best = q
	return best


func carrier_ai(p: Jug, S: Lado, O: Lado, dt: float, q: float) -> void:
	var gx = att_x(S)
	var goal = Vector2(gx, 34)
	var dg = p.pos.distance_to(goal)
	var near = 99.0
	var n_opp: Jug = null
	for o in O.ps:
		var dd = o.pos.distance_to(p.pos)
		if dd < near:
			near = dd
			n_opp = o
	p.dec -= dt
	if near < 2.2 and p.dec > 0.12:
		p.dec = 0.12
	if p.dec <= 0.0:
		p.dec = (0.32 + rnd() * 0.35) / q
		var opts = []
		var noise = (1.08 - q) * 18.0
		# remate
		if dg < 30.0 and (absf(p.pos.y - 34) < 17.0 or dg < 13.0):
			var blockers = 0
			for o in O.ps:
				if o.gk:
					continue
				var to = (o.pos - p.pos)
				var dirg = (goal - p.pos).normalized()
				if to.dot(dirg) > 0 and absf(to.cross(dirg)) < 1.4 and to.length() < dg:
					blockers += 1
			var s_sh: float = (30.0 - dg) * 3.2 - blockers * 9.0 + p.d["tir"] * 0.25 - 12.0
			if dg < 12:
				s_sh += 25
			opts.append(["tiro", s_sh + rng.randfn(0, noise)])
		# pase
		var prs = near < 1.9
		var m = best_pass(p, S, O, Vector2(), not prs)
		if m:
			var gain = (prog(S, m.pos.x) - prog(S, p.pos.x)) * L
			var s_p = -4.0 + gain * 0.75 + minf(space_of(m.pos, O), 9.0) * 1.2 - laneblock(p, m, O) * 7.0 + (20.0 if prs else 0.0)
			if gain < 0.0 and not prs:
				s_p -= 10.0
			opts.append(["pase", s_p + rng.randfn(0, noise), m])
		# al hueco
		var r = best_through(p, S, O, Vector2())
		if r and r.run_t > 0.0 and prog(S, p.pos.x) > 0.35:
			var dest = r.pos + (r.run_pt - r.pos).normalized() * 8.0
			var libre = space_of(dest, O)
			var s_t = -6.0 + p.d["pas"] * 0.12 + minf(libre, 10.0) * 2.2 - laneblock(p, r, O) * 6.0 + (prog(S, r.pos.x) - prog(S, p.pos.x)) * L * 0.5
			opts.append(["hueco", s_t + rng.randfn(0, noise), r])
		# centro
		if prog(S, p.pos.x) > 0.8 and absf(p.pos.y - 34) > 13.0:
			var inbox = 0
			for t in S.ps:
				if absf(t.pos.x - gx) < 18 and absf(t.pos.y - 34) < 15:
					inbox += 1
			opts.append(["centro", 8.0 + inbox * 9.0 + rng.randfn(0, noise)])
		# gambeta
		if n_opp and near < 2.6 and p.feint_cd <= 0.0 and p.sta > 0.15:
			var s_f = -20.0 + p.d["reg"] * 0.4 + (14.0 if p.esp("gam") else 0.0)
			opts.append(["gambeta", s_f + rng.randfn(0, noise)])
		# conducir
		var ahead = space_of(p.pos + Vector2(S.dir * 6, 0), O)
		var s_c = 12.0 + minf(ahead, 12.0) * 1.9 + p.d["reg"] * 0.12 - (22.0 if prs else 0.0)
		if prog(S, p.pos.x) < 0.72:
			s_c += 5.0
		opts.append(["conducir", s_c + rng.randfn(0, noise)])
		var best = opts[0]
		for o in opts:
			if o[1] > best[1]:
				best = o
		match best[0]:
			"tiro":
				var gk = gk_of(O)
				var side = 1.0 if gk and gk.pos.y < 34 else -1.0
				var chip = gk != null and absf(gk.pos.x - gx) > 6.0 and dg < 22.0 and rnd() < 0.5
				shoot(p, 0.45 + rnd() * 0.45, side * (0.45 + rnd() * 0.45), rnd() < 0.45 + p.d["tir"] / 300.0, chip)
				return
			"pase":
				var mm: Jug = best[2]
				do_pass(p, mm, mm.pos.distance_to(p.pos) > 28.0)
				return
			"hueco":
				do_through(p, best[2])
				return
			"centro":
				do_cross(p)
				return
			"gambeta":
				do_feint(p, Vector2())
		p.tgt = goal - Vector2(S.dir * 6, 0)
		p.tgt.y = 34 + (p.pos.y - 34) * 0.6
		if n_opp and near < 6.0:
			var rel = p.pos - n_opp.pos
			var sd = signf(rel.y) if absf(rel.y) > 0.2 else (1.0 if rnd() < 0.5 else -1.0)
			p.tgt = Vector2(p.pos.x + S.dir * 6, clampf(p.pos.y + sd * 6, 2, W - 2))
		p.has_tgt = true
	if not p.has_tgt:
		p.tgt = goal
	var sprint = near > 5.0 and p.sta > 0.35 and prog(S, p.pos.x) > 0.3
	move_to(p, p.tgt, (1.0 if near > 6 else 0.95) * q, sprint)


func form_target(p: Jug, S: Lado, our_ball: bool) -> Vector2:
	var pr = prog(S, b_pos.x)
	var adv = clampf(pr - 0.3, 0.0, 0.55) * (0.5 + 0.6 * p.bx)
	adv += (0.05 + 0.05 * p.bx) if our_ball else -0.03
	var fx = clampf(p.bx * 0.5 + adv, 0.04, 0.95)
	var bny = b_pos.y / W if S.dir > 0 else 1.0 - b_pos.y / W
	var fy = p.by
	if our_ball:
		if p.role in ["ED", "EI"]:
			fy = 0.07 if p.by < 0.5 else 0.93
		fy = clampf(fy + (bny - 0.5) * 0.25, 0.04, 0.96)
		# los laterales pasan al ataque por su banda
		if p.role in ["LD", "LI"] and absf(bny - p.by) < 0.35 and pr > 0.45:
			fx += 0.2
			fy = 0.05 if p.by < 0.5 else 0.95
		if p.role == "MP":
			fx = clampf(pr + 0.12, 0.45, 0.85)
	else:
		fy = clampf(0.5 + (p.by - 0.5) * 0.75 + (bny - 0.5) * 0.4, 0.05, 0.95)
		if p.bx < 0.7:
			fx = maxf(0.04, minf(fx, pr - 0.03))
		# línea defensiva compacta
		if p.role in ["LD", "LI", "DFC"]:
			fx = clampf(minf(fx, pr - 0.12), 0.06, 0.4)
	return wpos(S, fx, fy)


func ai(p: Jug, S: Lado, O: Lado, dt: float) -> void:
	var own = b_owner
	var q = S.q
	if p.gk:
		gk_ai(p, S, O, dt)
		return
	if own == p:
		carrier_ai(p, S, O, dt, q)
		return
	if p.hold > 0.0:
		p.hold -= dt
		p.dv = Vector2()
		return
	if own == null and p.recv > 0.0:
		p.recv -= dt
		var pt = intercept_point(p)
		move_to(p, pt, 1.15 * q, p.pos.distance_to(pt) > 3.0)
		return
	p.recv = 0.0
	var our_ball = own != null and own.side == S.side
	if not our_ball:
		var press = p == S.ch1 or (S.press2 and p == S.ch2)
		if press and own and S.side == 0 and human and not auto:
			var hd = human.pos.distance_to(S.bp)
			if hd < S.ch1d and not S.press2:
				press = false
		if press:
			if own:
				_press(p, own, S, dt, q)
			else:
				var pt2 = intercept_point(p)
				move_to(p, pt2, 1.15 * q, p.pos.distance_to(pt2) > 3.0)
			return
		if p == S.ch1 or p == S.ch2:
			var gx = own_x(S)
			move_to(p, S.bp + (Vector2(gx, 34) - S.bp) * 0.28, q)
			return
		# marca en la zona
		if own and p.role in ["LD", "LI", "DFC", "MCD"]:
			var base = form_target(p, S, false)
			var mark: Jug = null
			var md = 11.0
			for o in O.ps:
				if o.gk or o == own:
					continue
				var dd = o.pos.distance_to(base)
				if dd < md:
					md = dd
					mark = o
			if mark:
				var goal = Vector2(own_x(S), 34)
				var tg = mark.pos + (goal - mark.pos).normalized() * 1.6
				move_to(p, tg, q, tg.distance_to(p.pos) > 6)
				return
	else:
		# desmarques en ataque
		if p.run_t > 0.0:
			move_to(p, p.run_pt, q, true)
			return
		if p.role in ["DC", "ED", "EI", "MP"] and own != p and prog(S, own.pos.x) > 0.28 and p.sta > 0.35:
			if rnd() < dt * (0.28 + p.d["vel"] / 400.0) and prog(S, p.pos.x) < 0.9:
				var last_def = 0.0
				for o in O.ps:
					if not o.gk:
						last_def = maxf(last_def, prog(S, o.pos.x))
				var fx = clampf(last_def + 0.05, prog(S, p.pos.x) + 0.06, 0.94)
				var fy = clampf(p.pos.y + rng.randf_range(-8, 8), 6, W - 6)
				var tgt = Vector2(fx * L if S.dir > 0 else L - fx * L, fy)
				p.run_t = 2.0
				p.run_pt = tgt
				move_to(p, tgt, q, true)
				return
	var t2 = form_target(p, S, our_ball)
	var far = t2.distance_to(p.pos) > 8.0
	move_to(p, t2, (1.1 if far else 0.85) * q, far and t2.distance_to(p.pos) > 14.0)


func _press(p: Jug, o: Jug, S: Lado, dt: float, q: float) -> void:
	var goal = Vector2(own_x(S), 34)
	var dd = p.pos.distance_to(o.pos)
	# contención: se para entre el rival y el arco y espera el momento
	var gap = 2.4 if p.press_t < 1.0 else 1.1
	var spot = o.pos + (goal - o.pos).normalized() * gap
	if dd > 3.2:
		p.press_t = 0.0
		move_to(p, spot + o.vel * 0.3, 1.05 * q, dd > 9.0)
	else:
		move_to(p, spot + o.vel * 0.2, 0.95 * q)
		p.press_t += dt * q
		var rate = (0.45 + p.d["def"] / 100.0) * q
		if p.tk <= 0.0 and b_pos.distance_to(p.pos) < 1.5 and rnd() < dt * rate * 2.2:
			try_tackle(p, o, false)
		elif p.d["def"] > 72 and o.face.dot((p.pos - o.pos).normalized()) < -0.3 and rnd() < dt * 0.15 * q:
			start_slide(p, b_pos - p.pos)


func intercept_point(p: Jug) -> Vector2:
	var spd = max_spd(p) * 1.1
	var pt = b_pos
	var v = b_vel
	var bp = b_pos
	var t = 0.0
	while t < 2.5:
		t += 0.1
		var s = v.length()
		if s > 0:
			var ns = maxf(0.0, s - (FR0 + FR1 * s) * 0.1)
			v = v / s * ns
		bp += v * 0.1
		if p.pos.distance_to(bp) / spd <= t:
			return bp
		pt = bp
	return pt


func compute_chasers() -> void:
	var t = 0.35
	var px = b_pos if b_owner else b_pos + b_vel * t
	for S in T:
		var c = []
		for p in S.ps:
			if p.gk or (p == human and S.side == 0 and not auto):
				continue
			c.append([p.pos.distance_to(px), p])
		c.sort_custom(func(a, b): return a[0] < b[0])
		S.ch1 = c[0][1] if c.size() > 0 else null
		S.ch1d = c[0][0] if c.size() > 0 else 99.0
		S.ch2 = c[1][1] if c.size() > 1 else null
		S.bp = px


# =========================================================
# Control humano
# =========================================================
func human_ctl(dt: float) -> void:
	var p = human
	if p == null or auto or p.off:
		return
	var S: Lado = T[0]
	var O: Lado = T[1]
	var mv: Vector2 = inp["mv"]
	var m = mv.length()
	var own = b_owner == p
	S.press2 = inp["thru"] and not own and (b_owner == null or b_owner.side == 1)
	p.sprint = inp["sprint"] and p.sta > 0.08
	if m > 0.15:
		var spd = max_spd(p) * (1.22 if p.sprint else 1.0) * minf(1.0, m)
		p.dv = mv / m * spd
	elif not own and b_owner == null and p.recv > 0.0:
		p.recv -= dt
		move_to(p, b_pos + b_vel * 0.25, 1.15)
	else:
		p.dv = Vector2()
	if own:
		var dir: Vector2 = mv / m if m > 0.15 else p.face
		if inp["pass_p"]:
			var q = best_pass(p, S, O, dir, false)
			if q == null:
				q = best_pass(p, S, O, Vector2(), false)
			if q:
				do_pass(p, q, false)
			power = 0.0
		elif inp["thru_p"]:
			var q2 = best_through(p, S, O, dir)
			if q2:
				do_through(p, q2)
			power = 0.0
		elif inp["long_p"] and not inp["shoot"] and power == 0.0:
			var gx = att_x(S)
			if prog(S, p.pos.x) > 0.75 and absf(p.pos.y - 34) > 12 and (m < 0.15 or dir.x * S.dir > 0.3):
				do_cross(p)
			else:
				var q3 = best_pass(p, S, O, dir, false, true)
				if q3:
					do_pass(p, q3, true)
			power = 0.0
		elif inp["feint_p"]:
			do_feint(p, mv)
		elif inp["shoot"]:
			power = minf(1.0, power + dt * 1.35)
			if inp["long"]:
				aim_hold = 1.0
		elif power > 0.0:
			var aim = clampf(mv.y, -1, 1) * 0.92 if absf(mv.y) > 0.2 else _smart_aim(p)
			shoot(p, power, aim, not inp["sprint"], aim_hold > 0.0 or inp["long"])
			power = 0.0
			aim_hold = 0.0
	else:
		if not inp["shoot"]:
			power = 0.0
		if inp["switch_p"]:
			var n = nearest(S, b_pos + b_vel * 0.3, true, p)
			if n:
				human = n
				auto_t = 1.0
		if inp["pass"] and b_owner and b_owner.side == 1 and p.pos.distance_to(b_pos) < 1.6:
			try_tackle(p, b_owner, true)
		if inp["shoot_p"] and b_owner and b_owner.side == 1 and p.pos.distance_to(b_pos) < 5.0:
			start_slide(p, (b_pos + b_vel * 0.2 - p.pos) if m < 0.15 else mv)


func _smart_aim(p: Jug) -> float:
	var gk = gk_of(T[1 - p.side])
	var side = 1.0 if gk and gk.pos.y < 34 else -1.0
	return side * rng.randf_range(0.35, 0.8)


func auto_switch(dt: float) -> void:
	auto_t -= dt
	var h = human
	if h == null or (b_owner and b_owner.side == 0) or auto_t > 0.0:
		return
	var n = nearest(T[0], b_pos + b_vel * 0.3, true)
	if n == null:
		return
	var hd = h.pos.distance_to(b_pos)
	var nd = n.pos.distance_to(b_pos)
	if n != h and hd > 11.0 and nd < hd * 0.6:
		human = n
		auto_t = 1.2


# =========================================================
# Contacto con la pelota
# =========================================================
func contact(dt: float) -> void:
	b_fresh -= dt
	_check_slides()
	if b_owner:
		var o = b_owner
		var O: Lado = T[1 - o.side]
		# pelota adelantada: el rival la puede tocar antes
		for q in O.ps:
			if q.stun > 0.0 or q.touch > 0.0 or q.slide > 0.0:
				continue
			var qb = q.pos.distance_to(b_pos)
			if qb < 0.7 and qb < o.pos.distance_to(b_pos) - 0.25:
				if rnd() < 0.5 + (q.d["def"] - o.d["reg"]) / 150.0:
					ev("quite")
					give_ball(q)
					o.touch = 0.3
					return
		return
	var best: Jug = null
	var bd = 1e9
	var kind = ""
	for S in T:
		for p in S.ps:
			if p.touch > 0.0 or (p.stun > 0.0 and p.dive <= 0.0):
				continue
			var dist = p.pos.distance_to(b_pos)
			if p.gk and en_area(S, b_pos, 0.5):
				var R = 0.95 + p.d["arq"] / 100.0 * 0.45
				var H = 2.45
				if p.dive > 0.0:
					R = 1.15 + p.d["arq"] / 100.0 * 0.55
					H = 0.6 + p.act_h * 2.2
				if dist < R and b_z < H and dist < bd:
					bd = dist
					best = p
					kind = "manos"
				continue
			if dist < 0.85 and b_z < 0.95 and dist < bd:
				bd = dist
				best = p
				kind = "pie"
			elif dist < 0.95 and b_z >= 0.95 and b_z < 1.5 and dist < bd:
				bd = dist
				best = p
				kind = "pecho"
			elif dist < 1.0 and b_z >= 1.5 and b_z < 2.0 + p.d["cab"] / 100.0 * 0.9 and dist < bd:
				bd = dist
				best = p
				kind = "cabeza"
	if best == null:
		return
	var p = best
	var S: Lado = T[p.side]
	var O: Lado = T[1 - p.side]
	var spd = b_vel.length()
	# un rival que intercepta una pelota rápida necesita reflejos
	if kind != "manos" and b_kicker and b_kicker.side != p.side and spd > 6.0:
		var ch = clampf(0.3 + p.d["def"] / 260.0 - (spd - 6.0) / 22.0 - b_fresh * 3.0, 0.08, 0.9)
		if p == human and not auto:
			ch += 0.25
		if rnd() > ch:
			p.touch = 0.22
			return
	match kind:
		"manos":
			_gk_save(p, S, spd, bd)
		"cabeza":
			_header(p, S, O)
		"pecho", "pie":
			_first_touch(p, S, O, spd, kind)


func _gk_save(p: Jug, S: Lado, spd: float, dist: float) -> void:
	var shot = b_shot and b_shot_side != p.side
	if not shot and spd < 14.0:
		give_ball(p)
		p.act = "atrapa"
		p.act_t = 0.4
		return
	var arq: float = p.d["arq"]
	var ch = 0.62 + arq / 190.0 - maxf(0.0, spd - 14.0) / 45.0 - dist / 3.5 * 0.3
	if p.esp("arq"):
		ch += 0.08
	if p.side == 1:
		ch *= [0.93, 1.0, 1.06][diff]
	if rnd() < ch:
		stats["al_arco"][1 - p.side] += 1
		if spd < 21.0 and rnd() < 0.45 + arq / 300.0:
			give_ball(p)
			p.act = "atrapa"
			p.act_t = 0.5
			flash("¡Atajada de " + p.d["corto"] + "!")
		else:
			if rnd() < 0.5:
				# la manda al córner
				var lado = signf(b_pos.y - 34.0) if absf(b_pos.y - 34.0) > 0.3 else (1.0 if rnd() < 0.5 else -1.0)
				b_vel = Vector2(b_vel.x * rng.randf_range(0.15, 0.35), lado * rng.randf_range(5, 9))
			else:
				b_vel = Vector2(-b_vel.x * 0.35, b_vel.y * 0.4 + rng.randfn(0, 6))
			b_vz = absf(b_vz) * 0.4 + rng.randf_range(1.5, 4.5)
			b_last = p.side
			b_shot = false
			p.touch = 0.5
			flash("¡Manotazo de " + p.d["corto"] + "!")
		ev("atajada")
	else:
		p.touch = 0.6
		if rnd() < 0.3:
			b_vel *= 0.8
			b_vel.y += rng.randfn(0, 3)


func _header(p: Jug, S: Lado, O: Lado) -> void:
	var gx = att_x(S)
	var goal = Vector2(gx, 34)
	var dg = p.pos.distance_to(goal)
	var hum = p == human and not auto
	var cab: float = p.d["cab"]
	p.act = "cabezazo"
	p.act_t = 0.5
	p.touch = 0.35
	var err = (100.0 - cab) / 100.0 * 0.16
	var want_shot = (hum and inp["shoot"]) or (not hum and dg < 17.0)
	var want_clear = not hum and prog(S, p.pos.x) < 0.3
	if hum and inp["shoot"]:
		power = 0.0
	if want_shot:
		var aim = clampf(inp["mv"].y, -1, 1) * 0.9 if hum and absf(inp["mv"].y) > 0.2 else rng.randf_range(-0.9, 0.9)
		var tgt = Vector2(gx, 34 + aim * 3.2)
		b_owner = null
		var spd = 11.0 + cab / 100.0 * 9.0
		var a = (tgt - b_pos).angle() + rng.randfn(0, err)
		b_vel = Vector2.from_angle(a) * spd
		b_vz = rng.randf_range(-3.5, 0.5) + (1.0 - cab / 100.0) * rng.randf_range(0, 3)
		b_spin = 0.0
		b_top = 0.0
		b_kicker = p
		b_last = p.side
		b_shot = true
		b_shot_side = p.side
		stats["tiros"][p.side] += 1
		_mark_react(O)
		ev("cabezazo")
		return
	var dir = Vector2(S.dir, 0)
	if hum and inp["mv"].length() > 0.2:
		dir = inp["mv"].normalized()
	var q = best_pass(p, S, O, dir if hum else Vector2(), false)
	var tgt2 = p.pos + dir * 18.0
	if want_clear or q == null:
		tgt2 = Vector2(p.pos.x + S.dir * 25.0, clampf(p.pos.y + (p.pos.y - 34) * 0.6, 4, W - 4))
	else:
		tgt2 = q.pos
		q.recv = 1.5
		q.recv_pt = tgt2
	var dist = tgt2.distance_to(p.pos)
	b_owner = null
	var a2 = (tgt2 - b_pos).angle() + rng.randfn(0, err)
	var tf = clampf(dist / 14.0, 0.6, 1.6)
	b_vel = Vector2.from_angle(a2) * (dist / tf)
	b_vz = GRAV * tf / 2.0 - b_z / tf
	b_spin = 0.0
	b_kicker = p
	b_last = p.side
	b_shot = false
	ev("cabezazo")


func _first_touch(p: Jug, S: Lado, O: Lado, spd: float, kind: String) -> void:
	var hum = p == human and not auto
	var gx = att_x(S)
	var dg = p.pos.distance_to(Vector2(gx, 34))
	# volea o remate de primera
	var volley = false
	if b_z > 0.35 and dg < 22.0 and kind == "pie":
		volley = (hum and inp["shoot"]) or (not hum and p.d["tir"] > 74 and rnd() < 0.55)
	elif dg < 16.0 and spd > 4.0 and not hum and b_last == p.side and rnd() < 0.3 + p.d["tir"] / 400.0:
		volley = true
	if volley:
		b_owner = null
		var aim = clampf(inp["mv"].y, -1, 1) * 0.9 if hum and absf(inp["mv"].y) > 0.2 else rng.randf_range(-0.85, 0.85)
		var pw = maxf(power, 0.65) if hum else rng.randf_range(0.5, 0.9)
		power = 0.0
		shoot(p, pw, aim, false, false)
		if b_z > 0.35:
			b_vz += 0.6 + b_z * 0.5
			p.act = "volea"
			p.act_t = 0.5
		return
	var reg: float = p.d["reg"]
	var ok_p = 1.35 - spd / 26.0 + reg / 260.0 - (0.15 if kind == "pecho" else 0.0) - b_z * 0.1
	if b_shot and b_shot_side != p.side:
		ok_p -= 0.25
		if rnd() < 0.5:
			ev("bloqueo")
	if rnd() < ok_p:
		give_ball(p)
		if kind == "pecho":
			p.act = "pecho"
			p.act_t = 0.35
	else:
		p.touch = 0.28
		b_vel = b_vel * 0.55 + Vector2(rng.randfn(0, 2.5), rng.randfn(0, 2.5))
		b_vz = absf(b_vz) * 0.3 + (0.8 if kind == "pecho" else 0.2)
		b_last = p.side
		b_kicker = p
		b_shot = false


# =========================================================
# Límites de la cancha y goles
# =========================================================
func goal(gx: float) -> void:
	var sc: Lado = T[0] if att_x(T[0]) == gx else T[1]
	score[sc.side] += 1
	goal_against = 1 - sc.side
	state = "gol"
	st_t = 3.2
	var k = b_kicker
	var name = ""
	var own_goal = false
	if k:
		own_goal = k.side != sc.side
		name = k.d["n"] + (" (en contra)" if own_goal else "")
	goals.append({"side": sc.side, "name": name, "min": cur_min()})
	last_goal = {"side": sc.side, "name": name, "scorer": k if (k and not own_goal) else null}
	if k and not own_goal:
		k.act = "festejo"
		k.act_t = 3.0
	stats["al_arco"][sc.side] += 1
	ev("gol", {"side": sc.side})


func bounds() -> void:
	if b_owner:
		if b_pos.x > -0.3 and b_pos.x < L + 0.3 and b_pos.y > -0.3 and b_pos.y < W + 0.3:
			return
		b_last = b_owner.side
		b_owner = null
	if b_pos.x < -BR or b_pos.x > L + BR:
		var gx = L if b_pos.x > L else 0.0
		if b_pos.y > GY0 and b_pos.y < GY1 and b_z < CROSS:
			goal(gx)
			return
		var def: Lado = T[0] if own_x(T[0]) == gx else T[1]
		var att: Lado = T[1 - def.side]
		if b_last == att.side:
			restart(def, gx + def.dir * 5.5, 34 + (-4.0 if b_pos.y < 34 else 4.0), "arco", "Saque de arco")
		else:
			restart(att, L - 0.5 if gx == L else 0.5, 0.5 if b_pos.y < 34 else W - 0.5, "corner", "Córner")
		return
	if b_pos.y < -BR or b_pos.y > W + BR:
		restart(T[1 - b_last], clampf(b_pos.x, 1, L - 1), 0.0 if b_pos.y < 0 else W, "lateral", "Lateral")


func second_half() -> void:
	half = 2
	time = 0.0
	for S in T:
		S.dir *= -1
		for p in S.ps:
			p.sta = minf(1.0, p.sta + 0.35)
	set_kickoff(1)


func _set_piece_step(dt: float) -> void:
	## Mientras dura una pelota parada el ejecutor no se mueve y los rivales
	## respetan la distancia hasta que la pelota se juega.
	if sp.is_empty():
		return
	var tk: Jug = sp["taker"]
	if b_owner != tk:
		sp = {}
		return
	sp["t"] += dt
	tk.dv = Vector2()
	tk.vel = Vector2()
	var kind: String = sp["tipo"]
	var dmin = 9.15 if kind in ["corner", "libre", "arco", "saque"] else 3.0
	for q in T[1 - tk.side].ps:
		if q.gk and kind != "saque":
			continue
		var dd = q.pos.distance_to(b_pos)
		if dd < dmin:
			q.pos = b_pos + (q.pos - b_pos).normalized() * dmin
	# la máquina ejecuta sola
	var hum = tk.side == 0 and not auto and not tk.gk
	if hum and sp["t"] < 8.0:
		return
	if tk.gk:
		return
	if sp["t"] < 0.5 + rnd() * 0.4:
		return
	var S: Lado = T[tk.side]
	var O: Lado = T[1 - tk.side]
	match kind:
		"corner":
			do_cross(tk)
		"libre":
			var dg = b_pos.distance_to(Vector2(att_x(S), 34))
			if dg < 30.0 and (tk.esp("tl") or tk.d["tir"] > 82 or rnd() < 0.35):
				var gk = gk_of(O)
				var aim = -1.0 if gk and gk.pos.y > 34 else 1.0
				free_kick_shot(tk, aim * 0.78, 0.5, -aim)
			else:
				var m = best_pass(tk, S, O, Vector2(), false)
				if m:
					do_pass(tk, m, m.pos.distance_to(tk.pos) > 26)
		_:
			var m2 = best_pass(tk, S, O, Vector2(), false)
			if m2:
				do_pass(tk, m2, m2.pos.distance_to(tk.pos) > 26)
	sp = {}


## Tiro libre del humano: dirección vertical = a qué palo, horizontal = comba.
func human_free_kick() -> bool:
	if sp.is_empty() or sp["tipo"] != "libre":
		return false
	var tk: Jug = sp["taker"]
	if tk != human or b_owner != tk:
		return false
	var S: Lado = T[0]
	var dg = b_pos.distance_to(Vector2(att_x(S), 34))
	if dg > 34.0:
		return false
	if inp["shoot"]:
		power = minf(1.0, power + 1.0 / 60.0 * 1.2)
		return true
	if power > 0.0:
		var mv: Vector2 = inp["mv"]
		var aim = clampf(mv.y, -1, 1) * 0.85
		var curl = clampf(mv.x * S.dir, -1, 1)
		if absf(curl) < 0.2:
			curl = -signf(aim) if absf(aim) > 0.2 else 0.6
		free_kick_shot(tk, aim, power, curl)
		power = 0.0
		sp = {}
		return true
	return false


# =========================================================
# Paso principal
# =========================================================
func step(dt: float) -> void:
	if msg_t > 0.0:
		msg_t -= dt
	for S in T:
		for p in S.ps:
			if p.anim > 1e6:
				p.anim = 0.0
	match state:
		"saque":
			st_t -= dt
			dribble(dt)
			for S in T:
				for p in S.ps:
					p.dv = Vector2()
					integrate(p, dt)
			if st_t <= 0.0:
				state = "juego"
			return
		"gol":
			st_t -= dt
			ball_phys(dt)
			net_clamp()
			_celebrate(dt)
			if st_t <= 0.0 and not hold_after_goal:
				set_kickoff(goal_against)
			return
		"penal":
			_penalty_step(dt)
			for S in T:
				for p in S.ps:
					p.dv = Vector2()
					integrate(p, dt)
			return
		"juego":
			pass
		_:
			return
	time += dt
	if time >= half_len and b_owner != null or time >= half_len + 6.0:
		state = "entretiempo" if half == 1 else "final"
		ev(state)
		return
	if b_owner:
		stats["posesion"][b_owner.side] += dt
	compute_chasers()
	var hfk = human_free_kick()
	if not hfk:
		human_ctl(dt)
	for S in T:
		var O: Lado = T[1 - S.side]
		for p in S.ps:
			if p != human or auto:
				ai(p, S, O, dt)
	_set_piece_step(dt)
	for S in T:
		for p in S.ps:
			integrate(p, dt)
	separate()
	dribble(dt)
	ball_phys(dt)
	contact(dt)
	bounds()
	if state == "juego":
		auto_switch(dt)
	for k in ["pass_p", "long_p", "thru_p", "switch_p", "feint_p", "shoot_p"]:
		inp[k] = false


func _celebrate(dt: float) -> void:
	var lg: Dictionary = last_goal
	var sc: Jug = lg.get("scorer")
	for S in T:
		for p in S.ps:
			if sc and S.side == sc.side and p != sc and not p.gk and p.pos.distance_to(sc.pos) < 30:
				move_to(p, sc.pos, 1.0)
			elif p == sc:
				var corner = Vector2(L if sc.pos.x > L / 2 else 0.0, W if sc.pos.y > W / 2 else 0.0)
				move_to(p, sc.pos + (corner - sc.pos).normalized() * 3.0, 0.9)
			else:
				p.dv = Vector2()
			integrate(p, dt)
	separate()

class_name Sonido
extends Node
## Efectos sintetizados al arrancar (no hay archivos de audio).

const RATE := 22050

var muted := false
var _sfx := {}
var _pool: Array = []
var _amb: AudioStreamPlayer
var _amb_target := -20.0


func _ready() -> void:
	_sfx["patada"] = _thump(150.0, 0.08, 0.55, 0.25)
	_sfx["remate"] = _thump(105.0, 0.14, 0.9, 0.35)
	_sfx["cabezazo"] = _thump(220.0, 0.06, 0.45, 0.4)
	_sfx["quite"] = _thump(80.0, 0.09, 0.5, 0.6)
	_sfx["palo"] = _ping()
	_sfx["silbato"] = _whistle(0.32)
	_sfx["silbato_largo"] = _whistle(0.9)
	_sfx["gol"] = _crowd(3.2, 0.9, 0.25, 900.0)
	_sfx["uh"] = _crowd(1.2, 0.5, 0.15, 650.0)
	_sfx["red"] = _noise_burst(0.35, 0.35)
	_sfx["pique"] = _thump(190.0, 0.05, 0.3, 0.2)
	for i in 8:
		var p = AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_amb = AudioStreamPlayer.new()
	var amb: AudioStreamWAV = _crowd(4.0, 0.22, 0.0, 600.0, true)
	amb.loop_mode = AudioStreamWAV.LOOP_FORWARD
	amb.loop_end = int(4.0 * RATE)
	_amb.stream = amb
	_amb.volume_db = -20.0
	add_child(_amb)


func iniciar_ambiente() -> void:
	if not _amb.playing:
		_amb.play()


func detener() -> void:
	_amb.stop()
	for p in _pool:
		p.stop()


## Sube la hinchada cuando hay peligro de gol.
func tension(v: float) -> void:
	_amb_target = lerpf(-20.0, -9.0, clampf(v, 0.0, 1.0))


func _process(delta: float) -> void:
	_amb.volume_db = lerpf(_amb.volume_db, -80.0 if muted else _amb_target, minf(1.0, delta * 2.0))


func play(nombre: String, vol := 0.0, pitch := 1.0) -> void:
	if muted or not _sfx.has(nombre):
		return
	for p in _pool:
		if not p.playing:
			p.stream = _sfx[nombre]
			p.volume_db = vol
			p.pitch_scale = pitch
			p.play()
			return


func _wav(data: PackedFloat32Array) -> AudioStreamWAV:
	var bytes = PackedByteArray()
	bytes.resize(data.size() * 2)
	for i in data.size():
		bytes.encode_s16(i * 2, int(clampf(data[i], -1.0, 1.0) * 32000.0))
	var s = AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = bytes
	return s


func _thump(f: float, dur: float, vol: float, noise: float) -> AudioStreamWAV:
	var n = int(dur * RATE)
	var d = PackedFloat32Array()
	d.resize(n)
	var ph = 0.0
	for i in n:
		var t = float(i) / RATE
		var env = exp(-t / dur * 4.0)
		ph += TAU * (f * (1.0 - 0.45 * t / dur)) / RATE
		d[i] = (sin(ph) * (1.0 - noise) + (randf() * 2.0 - 1.0) * noise * exp(-t * 60.0)) * env * vol
	return _wav(d)


func _ping() -> AudioStreamWAV:
	var n = int(0.6 * RATE)
	var d = PackedFloat32Array()
	d.resize(n)
	for i in n:
		var t = float(i) / RATE
		var env = exp(-t * 7.0)
		d[i] = (sin(TAU * 880.0 * t) * 0.5 + sin(TAU * 1320.0 * t) * 0.3 + sin(TAU * 2310.0 * t) * 0.2) * env * 0.5
	return _wav(d)


func _whistle(dur: float) -> AudioStreamWAV:
	var n = int(dur * RATE)
	var d = PackedFloat32Array()
	d.resize(n)
	var ph = 0.0
	for i in n:
		var t = float(i) / RATE
		var f = 2650.0 + sin(TAU * 32.0 * t) * 90.0
		ph += TAU * f / RATE
		var env = minf(1.0, t * 40.0) * minf(1.0, (dur - t) * 25.0)
		var sq = 1.0 if sin(ph) > 0.0 else -1.0
		d[i] = (sq * 0.35 + sin(ph) * 0.4) * env * 0.22
	return _wav(d)


func _crowd(dur: float, vol: float, attack: float, center: float, loop := false) -> AudioStreamWAV:
	var n = int(dur * RATE)
	var d = PackedFloat32Array()
	d.resize(n)
	var lp1 = 0.0
	var lp2 = 0.0
	var a1 = clampf(TAU * center / RATE, 0.0, 1.0)
	var a2 = clampf(TAU * center * 0.25 / RATE, 0.0, 1.0)
	for i in n:
		var t = float(i) / RATE
		var x = randf() * 2.0 - 1.0
		lp1 += (x - lp1) * a1
		lp2 += (lp1 - lp2) * a2
		var band = (lp1 - lp2) * 3.0
		var env = 1.0
		if not loop:
			env = minf(1.0, t / maxf(attack, 0.01)) * exp(-maxf(0.0, t - attack) / dur * 2.2)
		else:
			env = 0.8 + 0.2 * sin(TAU * t / dur)
		d[i] = band * env * vol
	return _wav(d)


func _noise_burst(dur: float, vol: float) -> AudioStreamWAV:
	var n = int(dur * RATE)
	var d = PackedFloat32Array()
	d.resize(n)
	var lp = 0.0
	for i in n:
		var t = float(i) / RATE
		lp += (randf() * 2.0 - 1.0 - lp) * 0.3
		d[i] = lp * exp(-t * 9.0) * vol
	return _wav(d)

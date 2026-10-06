extends Node
## Planteles, camisetas y atributos de los jugadores.
## Los datos salen de data/equipos.json, que se genera desde clasico.html
## con `node leyendas/exportar_planteles.js`.

const ESPECIALIDADES := {
	"tl": "Tiro libre", "gam": "Gambeta", "cab": "Cabezazo", "pot": "Remate potente",
	"vis": "Visión", "vel": "Velocidad", "muro": "Marca", "arq": "Atajador",
}
const ATRIBUTOS := [
	["vel", "Velocidad"], ["res", "Resistencia"], ["reg", "Gambeta"], ["pas", "Pase"],
	["tir", "Tiro"], ["cab", "Cabezazo"], ["def", "Marca"], ["fis", "Físico"],
]
const PUESTOS := {
	"ARQ": "Arquero", "LD": "Lateral derecho", "LI": "Lateral izquierdo", "DFC": "Defensor central",
	"MCD": "Volante central", "MC": "Volante", "MP": "Enganche", "ED": "Puntero derecho",
	"EI": "Puntero izquierdo", "DC": "Centrodelantero",
}

var equipos: Array = []
var formaciones: Dictionary = {}
var kits_arquero: Array = []

## Opciones que se eligen en el menú.
var sel := {
	"local": "boc", "visita": "riv", "kit_l": 0, "kit_v": 0,
	"linea_l": [], "linea_v": [], "minutos": 5, "dificultad": 1, "camara": 0,
}


func _ready() -> void:
	cargar()


func cargar() -> void:
	if not equipos.is_empty():
		return
	var f = FileAccess.open("res://data/equipos.json", FileAccess.READ)
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	formaciones = data["formaciones"]
	kits_arquero = data["kits_arquero"]
	equipos = data["equipos"]
	for e in equipos:
		for j in e["jugadores"]:
			completar(j)
	sel["linea_l"] = _linea_vacia()
	sel["linea_v"] = _linea_vacia()


func _linea_vacia() -> Array:
	var a = []
	a.resize(11)
	a.fill(0)
	return a


func equipo(id: String) -> Dictionary:
	for e in equipos:
		if e["id"] == id:
			return e
	return equipos[0]


## Calcula los atributos que no vienen en los datos (resistencia, cabezazo,
## físico) y aplica las especialidades.
func completar(j: Dictionary) -> void:
	var o: float = j["o"]
	var pos: String = j["pos"]
	var c = func(v: float) -> float: return clampf(roundf(v), 25, 99)
	var res = o
	var cab = o
	var fis = o
	match pos:
		"ARQ":
			res = 75; cab = o - 40; fis = o - 12
		"LD", "LI":
			res = o + 3; cab = o - 12; fis = o - 6
		"DFC":
			res = o - 6; cab = o + 1; fis = o + 1
		"MCD":
			res = o + 3; cab = o - 10; fis = o - 1
		"MC":
			res = o + 2; cab = o - 16; fis = o - 10
		"MP":
			res = o - 6; cab = o - 25; fis = o - 20
		"ED", "EI":
			res = o - 2; cab = o - 25; fis = o - 18
		_:
			res = o - 8; cab = o - 6; fis = o - 5
	j["res"] = c.call(res)
	j["cab"] = c.call(cab)
	j["fis"] = c.call(fis)
	if pos == "ARQ":
		j["arq"] = j["ata"]
	else:
		j["arq"] = 20
	var tr: Array = []
	if j["tr"] is String and j["tr"] != "":
		tr = Array((j["tr"] as String).split(","))
	j["esp"] = tr
	for t in tr:
		match t:
			"cab": j["cab"] = maxf(j["cab"], minf(99, o + 3))
			"vel": j["vel"] = minf(99, j["vel"] + 4)
			"gam": j["reg"] = minf(99, j["reg"] + 3)
			"pot": j["tir"] = minf(99, j["tir"] + 2)
			"muro": j["def"] = minf(99, j["def"] + 3)
			"vis": j["pas"] = minf(99, j["pas"] + 3)
			"arq": j["arq"] = minf(99, j["arq"] + 2)
	j["ace"] = clampf(j["vel"] + (j["reg"] - 70) * 0.25, 30, 99)
	var partes: PackedStringArray = (j["n"] as String).split(" ")
	j["corto"] = partes[partes.size() - 1]
	if partes.size() > 2 and partes[partes.size() - 2] in ["de", "la", "Barros", "Aguirre", "Rodríguez", "Moreno", "Gómez", "García", "Di", "Mac", "Castagno", "Alfaro"]:
		j["corto"] = partes[partes.size() - 2] + " " + partes[partes.size() - 1]


func tiene(j: Dictionary, esp: String) -> bool:
	return esp in j["esp"]


## Once titular según los cambios (0 = titular original, 1 = suplente).
func once(e: Dictionary, linea: Array) -> Array:
	var r = []
	var js: Array = e["jugadores"]
	for i in 11:
		var sup: bool = linea.size() > i and linea[i] == 1
		r.append(js[i + 11] if sup else js[i])
	return r


func color(hex: String) -> Color:
	return Color.html(hex)

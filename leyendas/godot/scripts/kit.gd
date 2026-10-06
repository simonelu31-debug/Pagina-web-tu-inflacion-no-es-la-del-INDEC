class_name KitArt
extends RefCounted
## Dibuja camisetas: la textura que envuelve el torso de los jugadores 3D y
## los íconos de camiseta de los menús.

static var _cache := {}


static func col(hex: String) -> Color:
	return Color.html(hex)


## Color del diseño en un punto (u, v) del frente de la camiseta, ambos 0..1.
static func pattern_at(k: Dictionary, u: float, v: float) -> Color:
	var base = col(k["base"])
	var alt = col(k["alt"])
	var w: float = k["w"]
	match k["pat"]:
		"band":
			if absf(v - 0.46) < w / 2.0:
				return alt
		"sash":
			var dd = absf((u - 0.08) - (v * 0.95))
			if dd < w * 0.62:
				return alt
		"stripes":
			var n = maxf(3.0, w)
			if int(floor(u * n)) % 2 == 1:
				return alt
		"halves":
			if u < 0.5:
				return alt
		"vee":
			var dx = absf(u - 0.5)
			var vy = dx * 1.1
			if v < 0.62 and absf(v - vy) < 0.075 and dx < 0.5:
				return alt
		"tri":
			var n2 = maxf(3.0, w) * 3.0
			var i = int(floor(u * n2)) % 3
			if i == 1:
				return alt
			if i == 2:
				return col(k.get("alt2", k["alt"]))
	return base


## Textura para el torso (cilindro): el frente ocupa la mitad central de u.
static func torso_texture(k: Dictionary) -> ImageTexture:
	var key = "t" + JSON.stringify(k)
	if _cache.has(key):
		return _cache[key]
	var W = 256
	var H = 96
	var img = Image.create(W, H, false, Image.FORMAT_RGB8)
	var collar = col(k["collar"])
	for y in H:
		var v = float(y) / H
		for x in W:
			var uu = float(x) / W
			# 0.25..0.75 = frente; el resto = espalda (se repite el diseño)
			var fu = (uu - 0.25) * 2.0
			var espalda = fu < 0.0 or fu > 1.0
			if espalda:
				fu = fposmod(fu, 1.0)
			var c = pattern_at(k, fu, v)
			if k["pat"] == "sash" and (uu < 0.25 or uu > 0.75):
				c = col(k["base"])
			if k["pat"] == "vee" and (uu < 0.25 or uu > 0.75):
				c = col(k["base"])
			if v < 0.07:
				c = collar
			if v > 0.95:
				c = c.darkened(0.12)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	var t = ImageTexture.create_from_image(img)
	_cache[key] = t
	return t


const SHIRT := [
	Vector2(0.34, 0.08), Vector2(0.66, 0.08), Vector2(0.96, 0.26), Vector2(0.86, 0.44), Vector2(0.77, 0.38),
	Vector2(0.77, 0.94), Vector2(0.23, 0.94), Vector2(0.23, 0.38), Vector2(0.14, 0.44), Vector2(0.04, 0.26),
]


## Ícono de camiseta para los menús.
static func shirt_icon(k: Dictionary, size := 64) -> ImageTexture:
	var key = "i%d" % size + JSON.stringify(k)
	if _cache.has(key):
		return _cache[key]
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var poly = PackedVector2Array()
	for p in SHIRT:
		poly.append(p * size)
	var collar = col(k["collar"])
	var outline = Color(0, 0, 0, 0.55)
	for y in size:
		for x in size:
			var pt = Vector2(x + 0.5, y + 0.5)
			if Geometry2D.is_point_in_polygon(pt, poly):
				var c = pattern_at(k, (pt.x / size - 0.04) / 0.92, pt.y / size)
				var cx = pt.x / size - 0.5
				var cy = pt.y / size - 0.08
				if (cx * cx) / (0.17 * 0.17) + (cy * cy) / (0.09 * 0.09) < 1.0 and cy > 0:
					c = collar
				img.set_pixel(x, y, c)
	# contorno
	var out = img.duplicate()
	for y in size:
		for x in size:
			if img.get_pixel(x, y).a > 0.5:
				continue
			for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var xx: int = x + o.x
				var yy: int = y + o.y
				if xx >= 0 and yy >= 0 and xx < size and yy < size and img.get_pixel(xx, yy).a > 0.5:
					out.set_pixel(x, y, outline)
					break
	var t = ImageTexture.create_from_image(out)
	_cache[key] = t
	return t


## Textura de la pelota de cuero, con costuras.
static func ball_texture() -> ImageTexture:
	if _cache.has("ball"):
		return _cache["ball"]
	var W = 256
	var H = 128
	var img = Image.create(W, H, false, Image.FORMAT_RGB8)
	var base = Color("#e9dcbc")
	var seam = Color("#6d5434")
	for y in H:
		for x in W:
			var u = float(x) / W
			var v = float(y) / H
			var c = base
			# gajos
			var g = fposmod(u * 6.0, 1.0)
			if g < 0.03 and v > 0.08 and v < 0.92:
				c = seam
			if absf(v - 0.5) < 0.012 or absf(v - 0.25) < 0.01 or absf(v - 0.75) < 0.01:
				if int(floor(u * 6.0)) % 2 == 0:
					c = seam
			if fposmod(u * 12.0 + v * 2.0, 1.0) < 0.02 and absf(v - 0.5) < 0.24:
				c = seam.lightened(0.25)
			c = c.darkened(0.06 * sin(u * 31.0 + v * 17.0) * 0.5)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	var t = ImageTexture.create_from_image(img)
	_cache["ball"] = t
	return t


## Sombra suave redonda para jugadores y pelota.
static func blob_texture() -> ImageTexture:
	if _cache.has("blob"):
		return _cache["blob"]
	var S = 64
	var img = Image.create(S, S, false, Image.FORMAT_RGBA8)
	for y in S:
		for x in S:
			var d = Vector2(x - S / 2.0 + 0.5, y - S / 2.0 + 0.5).length() / (S / 2.0)
			var a = clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(0, 0, 0, a * a * 0.55))
	var t = ImageTexture.create_from_image(img)
	_cache["blob"] = t
	return t

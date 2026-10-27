class_name AssetGenerator
extends RefCounted

static var _cache: Dictionary = {}

static func get_floor_concrete() -> ImageTexture:
	if _cache.has("floor_concrete"):
		return _cache["floor_concrete"]
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var col_base := Color(0.22, 0.23, 0.25)
	var col_dark := Color(0.18, 0.19, 0.20)
	var col_seam := Color(0.14, 0.14, 0.15)
	for y in range(32):
		for x in range(32):
			if x == 0 or y == 0 or x == 31 or y == 31:
				img.set_pixel(x, y, col_seam)
			elif (x + y) % 7 == 0:
				img.set_pixel(x, y, col_dark)
			else:
				img.set_pixel(x, y, col_base)
	var tex := ImageTexture.create_from_image(img)
	_cache["floor_concrete"] = tex
	return tex

static func get_floor_metal() -> ImageTexture:
	if _cache.has("floor_metal"):
		return _cache["floor_metal"]
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var c1 := Color(0.17, 0.20, 0.24)
	var c2 := Color(0.12, 0.14, 0.17)
	var c_seam := Color(0.09, 0.10, 0.12)
	for y in range(32):
		for x in range(32):
			if x % 8 == 0 or y % 8 == 0:
				img.set_pixel(x, y, c_seam)
			elif ((x / 4) + (y / 4)) % 2 == 0:
				img.set_pixel(x, y, c1)
			else:
				img.set_pixel(x, y, c2)
	var tex := ImageTexture.create_from_image(img)
	_cache["floor_metal"] = tex
	return tex

static func get_floor_dirt() -> ImageTexture:
	if _cache.has("floor_dirt"):
		return _cache["floor_dirt"]
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var c_dirt := Color(0.28, 0.22, 0.17)
	var c_dark := Color(0.22, 0.17, 0.13)
	for y in range(32):
		for x in range(32):
			var n: float = sin(x * 0.4) * cos(y * 0.5)
			if n > 0.2:
				img.set_pixel(x, y, c_dark)
			else:
				img.set_pixel(x, y, c_dirt)
	var tex := ImageTexture.create_from_image(img)
	_cache["floor_dirt"] = tex
	return tex

static func get_wall_bunker() -> ImageTexture:
	if _cache.has("wall_bunker"):
		return _cache["wall_bunker"]
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var c_face := Color(0.40, 0.42, 0.46)
	var c_dark := Color(0.26, 0.28, 0.31)
	var c_rivet := Color(0.60, 0.62, 0.65)
	for y in range(32):
		for x in range(32):
			if x < 2 or y < 2 or x > 29 or y > 29:
				img.set_pixel(x, y, c_dark)
			elif (x in [5, 26]) and (y in [5, 26]):
				img.set_pixel(x, y, c_rivet)
			else:
				img.set_pixel(x, y, c_face)
	var tex := ImageTexture.create_from_image(img)
	_cache["wall_bunker"] = tex
	return tex

static func get_wall_sandbag() -> ImageTexture:
	if _cache.has("wall_sandbag"):
		return _cache["wall_sandbag"]
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var c_bag := Color(0.50, 0.44, 0.32)
	var c_shade := Color(0.35, 0.30, 0.22)
	for y in range(32):
		for x in range(32):
			if y % 10 == 0 or x % 16 == 0:
				img.set_pixel(x, y, c_shade)
			else:
				img.set_pixel(x, y, c_bag)
	var tex := ImageTexture.create_from_image(img)
	_cache["wall_sandbag"] = tex
	return tex

static func get_unit_texture(team: Globals.Team, weight_class: Globals.WeightClass) -> ImageTexture:
	var key: String = "unit_%d_%d" % [team, weight_class]
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0)) # transparent
	
	var team_color: Color = Color(0.85, 0.25, 0.25) if team == Globals.Team.BAAL_RED else Color(0.25, 0.45, 0.85)
	var armor_color: Color = Color(0.18, 0.20, 0.22) if weight_class == Globals.WeightClass.LIGHT else Color(0.28, 0.30, 0.32)
	var skin_color: Color = Color(0.85, 0.70, 0.55)
	var outline_color: Color = Color(0.08, 0.08, 0.10)
	
	var center := Vector2(16, 16)
	var radius: float = 8.0 if weight_class == Globals.WeightClass.LIGHT else 10.0
	
	# Draw body circle
	for y in range(32):
		for x in range(32):
			var dist: float = center.distance_to(Vector2(x, y))
			if dist <= radius:
				img.set_pixel(x, y, team_color)
			elif dist <= radius + 1.2:
				img.set_pixel(x, y, outline_color)
				
	# Draw Head/helmet facing right (+X is 0 degrees in Godot)
	var head_center := Vector2(18, 16)
	for y in range(11, 22):
		for x in range(14, 25):
			if head_center.distance_to(Vector2(x, y)) <= 4.5:
				img.set_pixel(x, y, armor_color)
	# Helmet visor
	img.set_pixel(22, 15, Color(0.1, 0.9, 0.9))
	img.set_pixel(22, 16, Color(0.1, 0.9, 0.9))
	img.set_pixel(22, 17, Color(0.1, 0.9, 0.9))
	
	# Hands / arms holding gun
	img.set_pixel(20, 9, skin_color)
	img.set_pixel(21, 9, skin_color)
	img.set_pixel(20, 23, skin_color)
	img.set_pixel(21, 23, skin_color)
	
	# Gun barrel extending forward
	for gx in range(21, 30):
		img.set_pixel(gx, 18, Color(0.15, 0.15, 0.18))
		img.set_pixel(gx, 19, Color(0.25, 0.25, 0.28))
		
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex

static func get_body_doll_texture(torso_col: Color, arms_col: Color, legs_col: Color) -> ImageTexture:
	var img := Image.create(32, 40, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	
	# Head (at top)
	for y in range(2, 9):
		for x in range(12, 20):
			if Vector2(16, 5).distance_to(Vector2(x, y)) <= 3.5:
				img.set_pixel(x, y, torso_col)
				
	# Torso
	for y in range(10, 24):
		for x in range(11, 21):
			img.set_pixel(x, y, torso_col)
			
	# Arms (Left & Right)
	for y in range(11, 23):
		for x in range(6, 10):
			img.set_pixel(x, y, arms_col)
		for x in range(22, 26):
			img.set_pixel(x, y, arms_col)
			
	# Legs
	for y in range(25, 38):
		for x in range(11, 15):
			img.set_pixel(x, y, legs_col)
		for x in range(17, 21):
			img.set_pixel(x, y, legs_col)
			
	return ImageTexture.create_from_image(img)

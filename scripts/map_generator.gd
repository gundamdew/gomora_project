class_name MapGenerator
extends Node2D

static var instance: MapGenerator

var wall_colliders: Node2D
var floor_node: Node2D

var zone_a: CaptureZone
var zone_b: CaptureZone
var zone_c: CaptureZone

# Map grid: 0 = floor, 1 = bunker wall, 2 = sandbag
var grid: Array = []
var floor_variants: Array = []
var turf_textures: Array[Texture2D] = []

func _init() -> void:
	instance = self
	_load_turfs()

func _load_turfs() -> void:
	for i in range(1, 7):
		var p: String = "res://assets/turfs/tile%d.png" % i
		if ResourceLoader.exists(p):
			var tex := load(p) as Texture2D
			if tex:
				turf_textures.append(tex)

func is_tile_solid(t: Vector2i) -> bool:
	if t.x < 0 or t.x >= Globals.MAP_TILES or t.y < 0 or t.y >= Globals.MAP_TILES:
		return true
	if grid.is_empty() or grid.size() <= t.y or grid[t.y].size() <= t.x:
		return false
	return grid[t.y][t.x] != 0

func _ready() -> void:
	wall_colliders = Node2D.new()
	wall_colliders.name = "WallColliders"
	add_child(wall_colliders)
	
	_generate_map_grid()
	_create_colliders()
	_spawn_capture_zones()
	queue_redraw()

func _generate_map_grid() -> void:
	grid.resize(Globals.MAP_TILES)
	floor_variants.resize(Globals.MAP_TILES)
	for y in range(Globals.MAP_TILES):
		var row: Array = []
		row.resize(Globals.MAP_TILES)
		row.fill(0)
		grid[y] = row

		var f_row: Array = []
		f_row.resize(Globals.MAP_TILES)
		for x in range(Globals.MAP_TILES):
			# Deterministic pseudo-random distribution so all clients see the identical randomized floor
			var seed_val: int = ((x * 7919 + y * 65537) ^ (x * 383 + y * 541))
			if seed_val < 0:
				seed_val = -seed_val
			f_row[x] = seed_val % 6
		floor_variants[y] = f_row

	# 1. Outer perimeter walls
	for x in range(Globals.MAP_TILES):
		grid[0][x] = 1
		grid[Globals.MAP_TILES - 1][x] = 1
	for y in range(Globals.MAP_TILES):
		grid[y][0] = 1
		grid[y][Globals.MAP_TILES - 1] = 1

	# 2. Defensive bunker lines and checkpoints
	# Line 1 (between Zone A and B): around X = 35..38
	_create_barrier_line(36, 12, 88, [45, 46, 47, 48, 49, 50, 51, 52, 53, 54])
	# Line 2 (between Zone B and C): around X = 65..68
	_create_barrier_line(66, 12, 88, [45, 46, 47, 48, 49, 50, 51, 52, 53, 54])

	# 3. Pillboxes and cover clusters around Zone A (X=25, Y=50)
	_add_pillbox(20, 42, 6, 4)
	_add_pillbox(20, 54, 6, 4)
	_add_sandbags(28, 46, 4, 1)
	_add_sandbags(28, 53, 4, 1)

	# 4. Pillboxes around Zone B (X=50, Y=50)
	_add_pillbox(46, 38, 8, 4)
	_add_pillbox(46, 58, 8, 4)
	_add_sandbags(52, 45, 1, 10)

	# 5. Fortress defenses around Zone C (X=78, Y=50)
	_add_pillbox(74, 40, 6, 6)
	_add_pillbox(74, 54, 6, 6)
	_add_sandbags(80, 44, 4, 1)
	_add_sandbags(80, 55, 4, 1)

	# Scattered sandbag barricades
	for i in range(30):
		var rx: int = randi_range(5, 92)
		var ry: int = randi_range(5, 92)
		if grid[ry][rx] == 0:
			grid[ry][rx] = 2

func _create_barrier_line(x_pos: int, y_start: int, y_end: int, openings: Array) -> void:
	for y in range(y_start, y_end):
		if not openings.has(y):
			grid[y][x_pos] = 1
			grid[y][x_pos + 1] = 1

func _add_pillbox(start_x: int, start_y: int, w: int, h: int) -> void:
	for y in range(start_y, start_y + h):
		for x in range(start_x, start_x + w):
			if x < Globals.MAP_TILES and y < Globals.MAP_TILES:
				if x == start_x or x == start_x + w - 1 or y == start_y or y == start_y + h - 1:
					# Leave 2-tile opening on one side
					if not (y == start_y + int(h/2) and x == start_x + w - 1):
						grid[y][x] = 1

func _add_sandbags(start_x: int, start_y: int, w: int, h: int) -> void:
	for y in range(start_y, start_y + h):
		for x in range(start_x, start_x + w):
			if x < Globals.MAP_TILES and y < Globals.MAP_TILES:
				grid[y][x] = 2

func _create_colliders() -> void:
	# Add physics collision rects for walls
	for y in range(Globals.MAP_TILES):
		for x in range(Globals.MAP_TILES):
			var tile_type: int = grid[y][x]
			if tile_type != 0:
				var body := StaticBody2D.new()
				body.position = Vector2(x * Globals.TILE_SIZE + 16.0, y * Globals.TILE_SIZE + 16.0)
				var shape := CollisionShape2D.new()
				var rect := RectangleShape2D.new()
				rect.size = Vector2(Globals.TILE_SIZE, Globals.TILE_SIZE)
				shape.shape = rect
				body.add_child(shape)
				wall_colliders.add_child(body)

func _spawn_capture_zones() -> void:
	# Zone A (Attack sector 1)
	zone_a = CaptureZone.new()
	zone_a.zone_name = "A"
	zone_a.is_active = true # Active from round start
	zone_a.position = Vector2(25 * Globals.TILE_SIZE, 50 * Globals.TILE_SIZE)
	add_child(zone_a)

	# Zone B (Mid sector 2)
	zone_b = CaptureZone.new()
	zone_b.zone_name = "B"
	zone_b.is_active = false # Unlocked when A captured
	zone_b.position = Vector2(50 * Globals.TILE_SIZE, 50 * Globals.TILE_SIZE)
	add_child(zone_b)

	# Zone C (Final defender base 3)
	zone_c = CaptureZone.new()
	zone_c.zone_name = "C"
	zone_c.is_active = false # Unlocked when B captured
	zone_c.position = Vector2(78 * Globals.TILE_SIZE, 50 * Globals.TILE_SIZE)
	add_child(zone_c)

func get_active_objective_position() -> Vector2:
	if not zone_a.is_captured:
		return zone_a.global_position
	elif not zone_b.is_captured:
		return zone_b.global_position
	elif not zone_c.is_captured:
		return zone_c.global_position
	return zone_c.global_position

func _draw() -> void:
	var tex_concrete := AssetGenerator.get_floor_concrete()
	var tex_wall := AssetGenerator.get_wall_bunker()
	var tex_sandbag := AssetGenerator.get_wall_sandbag()
	var has_turfs: bool = not turf_textures.is_empty()

	# Draw floor and walls
	for y in range(Globals.MAP_TILES):
		for x in range(Globals.MAP_TILES):
			var pos := Vector2(x * Globals.TILE_SIZE, y * Globals.TILE_SIZE)
			var tile_type: int = grid[y][x]
			
			if tile_type == 1:
				draw_texture(tex_wall, pos)
			elif tile_type == 2:
				draw_texture(tex_sandbag, pos)
			else:
				if has_turfs:
					var v_idx: int = floor_variants[y][x] % turf_textures.size()
					draw_texture(turf_textures[v_idx], pos)
				else:
					draw_texture(tex_concrete, pos)

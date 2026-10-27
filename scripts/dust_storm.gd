class_name DustStorm
extends Node2D

var player_ref: Node2D = null

# Circle visibility settings:
# Central view screen is 1080x1080 (at 2x zoom = 540x540 world area).
# Diameter = 540 world units (radius = 270.0 world units).
var inner_radius: float = 160.0
var outer_radius: float = 270.0

# Gray atmospheric storm palette
var storm_color := Color(0.13, 0.14, 0.15, 1.0)
var storm_haze_color := Color(0.70, 0.74, 0.78, 0.02)

var storm_time: float = 0.0
var wind_angle: float = -0.45 # Blowing northeast
var wind_speed: float = 520.0
var wind_dir: Vector2 = Vector2.from_angle(-0.45)

var _sand_particles: Array[Dictionary] = []

func setup(p: Node2D) -> void:
	player_ref = p

func _ready() -> void:
	z_index = 8
	top_level = true
	position = Vector2.ZERO

	_init_sand_particles()

	if AudioManager.instance:
		AudioManager.instance.start_ambient_wind(-10.0)

func _exit_tree() -> void:
	if AudioManager.instance:
		AudioManager.instance.stop_ambient_wind()

func _init_sand_particles() -> void:
	_sand_particles.clear()
	# Semi-transparent subtle wind streaks
	for _i in range(70):
		var p := {
			"offset": Vector2(randf_range(-450.0, 450.0), randf_range(-450.0, 450.0)),
			"speed_mult": randf_range(0.8, 1.25),
			"len": randf_range(16.0, 32.0),
			"width": randf_range(1.0, 1.8),
			"alpha": randf_range(0.08, 0.22) # Subtle semi-transparency
		}
		_sand_particles.append(p)

func _process(delta: float) -> void:
	storm_time += delta

	# Ensure local player tracking
	if player_ref == null or not is_instance_valid(player_ref):
		if GameManager.instance and is_instance_valid(GameManager.instance.local_player):
			player_ref = GameManager.instance.local_player

	# Update flying sand particles
	var w_step := wind_dir * wind_speed * delta
	for p in _sand_particles:
		p["offset"] += w_step * p["speed_mult"]
		if p["offset"].x > 450.0:
			p["offset"].x -= 900.0
			p["offset"].y = randf_range(-450.0, 450.0)
		elif p["offset"].x < -450.0:
			p["offset"].x += 900.0
			p["offset"].y = randf_range(-450.0, 450.0)
		if p["offset"].y > 450.0:
			p["offset"].y -= 900.0
			p["offset"].x = randf_range(-450.0, 450.0)
		elif p["offset"].y < -450.0:
			p["offset"].y += 900.0
			p["offset"].x = randf_range(-450.0, 450.0)

	queue_redraw()

func _draw() -> void:
	var player_pos: Vector2 = player_ref.global_position if (player_ref and is_instance_valid(player_ref)) else Vector2(1600.0, 1600.0)
	var cam_pos: Vector2 = player_pos
	var cam := get_viewport().get_camera_2d() if get_viewport() else null
	if cam and is_instance_valid(cam):
		cam_pos = cam.global_position

	var has_dv: bool = false
	if player_ref and is_instance_valid(player_ref) and player_ref.get("class_data"):
		var p_cdata: ClassData = player_ref.get("class_data")
		if p_cdata and p_cdata.has_deathvision:
			has_dv = true

	# Storm visibility circle is ALWAYS anchored to the character (player_pos), NEVER to the camera!
	var center: Vector2 = player_pos

	# 1. Subtle neutral ambient air tint inside clear circle
	draw_circle(center, inner_radius, storm_haze_color)

	# 2. Smooth feathered transparency gradient transition into gray storm overlay
	var steps: int = 28
	var dr: float = (outer_radius - inner_radius) / float(steps)
	for i in range(steps):
		var r_start: float = inner_radius + float(i) * dr
		var r_mid: float = r_start + dr * 0.5
		var t: float = float(i) / float(steps - 1)
		# Smoothstep S-curve (cubic Hermite) for seamless zero-derivative blending
		var band_alpha: float = t * t * (3.0 - 2.0 * t)
		var band_col := Color(storm_color.r, storm_color.g, storm_color.b, band_alpha)
		draw_arc(center, r_mid, 0.0, TAU, 64, band_col, dr + 1.2)

	# 3. Solid impenetrable gray storm shroud outside outer_radius
	var shroud_radii: Array[float] = [325.0, 445.0, 665.0, 1050.0, 1750.0, 2800.0]
	var shroud_widths: Array[float] = [112.0, 145.0, 305.0, 500.0, 920.0, 1250.0]
	for k in range(shroud_radii.size()):
		draw_arc(center, shroud_radii[k], 0.0, TAU, 64, storm_color, shroud_widths[k])

	# 4. Semi-transparent fast-flying wind/dust streaks
	var w_dir: Vector2 = wind_dir
	for p in _sand_particles:
		var p_start: Vector2 = cam_pos + p["offset"]
		var p_end: Vector2 = p_start + w_dir * p["len"]
		var s_col := Color(0.80, 0.82, 0.86, p["alpha"])
		draw_line(p_start, p_end, s_col, p["width"])

	# 5. Смертовизор (Deathvision / Thermal Vision)
	# Allows seeing thermal signatures colored by team through the storm shroud (not through walls)
	# Cloaked units (Augur) are hidden from deathvision
	if has_dv:
		_draw_deathvision(player_pos)

func _draw_deathvision(player_pos: Vector2) -> void:
	var tree := get_tree()
	if not tree:
		return
	var space := get_world_2d().direct_space_state
	var units := tree.get_nodes_in_group("units")
	var p_unit: Unit = player_ref as Unit

	# Collect all unit RIDs to exclude from obstacle raycast, so raycast only checks static walls
	var unit_rids: Array[RID] = []
	for u_node in units:
		if u_node is Unit and is_instance_valid(u_node):
			unit_rids.append((u_node as Unit).get_rid())

	for u_node in units:
		var u: Unit = u_node as Unit
		if not is_instance_valid(u) or u.is_dead or u == player_ref:
			continue
		
		# Check if cloaked (Покров)
		if u.class_data and u.class_data.has_cloak:
			continue # Cloaked from thermal vision!

		var u_pos: Vector2 = u.global_position
		var d_player: float = player_pos.distance_to(u_pos)

		# If unit is already in the close clear view circle around the player, normal sprite is visible;
		# but if they are in the storm shroud, draw their thermal signature!
		if d_player < inner_radius:
			continue

		# Check line of sight from player to enemy (not through walls / obstacles)
		if space and p_unit:
			var q := PhysicsRayQueryParameters2D.create(player_pos, u_pos)
			q.collide_with_areas = false
			q.collide_with_bodies = true
			q.exclude = unit_rids
			var hit := space.intersect_ray(q)
			if not hit.is_empty():
				# Blocked by wall / obstacle
				continue

		# Thermal signature color: Red team = infrared red, Blue team = cyan blue
		var t_col := Color(1.0, 0.28, 0.25, 0.95) if u.team == Globals.Team.BAAL_RED else Color(0.25, 0.85, 1.0, 0.95)
		var halo_col := Color(t_col.r, t_col.g, t_col.b, 0.35 + sin(storm_time * 6.0) * 0.15)

		# Size based on weight class (Light: small, Medium: medium, Heavy: large)
		var rad: float = 8.0
		if u.weight_class == Globals.WeightClass.MEDIUM:
			rad = 12.0
		elif u.weight_class == Globals.WeightClass.HEAVY:
			rad = 16.0

		draw_circle(u_pos, rad + 5.0, halo_col)
		draw_circle(u_pos, rad, t_col)
		draw_circle(u_pos, rad * 0.45, Color(1.0, 1.0, 1.0, 0.9)) # Hotspot
		draw_arc(u_pos, rad + 1.5, 0.0, TAU, 16, Color(1.0, 1.0, 1.0, 0.8), 1.5)

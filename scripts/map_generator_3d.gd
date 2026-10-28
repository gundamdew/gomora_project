class_name MapGenerator3D
extends Node3D

# Capture Sectors (A, B, C)
class CaptureSector3D extends Node3D:
	signal sector_captured(sector: CaptureSector3D)

	var sector_id: String = "A"
	var display_name: String = "СЕКТОР A"
	var capture_radius: float = 6.0
	var capture_progress: float = 0.0 # -1.0 (Full Blue) to +1.0 (Full Red)
	var current_owner: Globals.Team = Globals.Team.MOLOCH_BLUE
	var is_captured: bool = false
	var is_active: bool = true

	var beam_mesh: MeshInstance3D
	var ring_mesh: MeshInstance3D
	var light: OmniLight3D
	var label_3d: Label3D
	var _ring_rotation: float = 0.0

	func _init(id: String, d_name: String, pos: Vector3) -> void:
		sector_id = id
		display_name = d_name
		position = pos

	func _ready() -> void:
		_create_visuals()

	func _create_visuals() -> void:
		# 1. Vertical holographic light beam
		beam_mesh = MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 1.2
		cyl.bottom_radius = 1.6
		cyl.height = 30.0
		beam_mesh.mesh = cyl
		beam_mesh.position = Vector3(0, 15.0, 0)

		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1.0, 0.8, 0.2, 0.35)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		beam_mesh.material_override = mat
		add_child(beam_mesh)

		# 2. Concentric ring on floor
		ring_mesh = MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = capture_radius * 0.85
		torus.outer_radius = capture_radius
		ring_mesh.mesh = torus
		ring_mesh.position = Vector3(0, 0.1, 0)

		var r_mat := StandardMaterial3D.new()
		r_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		r_mat.albedo_color = Color(1.0, 0.8, 0.2, 0.8)
		r_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		r_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		ring_mesh.material_override = r_mat
		add_child(ring_mesh)

		# 3. OmniLight
		light = OmniLight3D.new()
		light.light_color = Color(1.0, 0.8, 0.2)
		light.light_energy = 3.5
		light.omni_range = capture_radius * 2.0
		light.position = Vector3(0, 2.0, 0)
		add_child(light)

		# 4. Floating 3D Label
		label_3d = Label3D.new()
		label_3d.text = "[ %s ]" % display_name
		label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label_3d.position = Vector3(0, 4.0, 0)
		label_3d.font_size = 36
		label_3d.modulate = Color(1.0, 0.85, 0.2)
		add_child(label_3d)

	func _process(delta: float) -> void:
		_ring_rotation += delta * 1.5
		if ring_mesh:
			ring_mesh.rotation.y = _ring_rotation

		# Update visual colors based on capture progress
		var col: Color = Color(1.0, 0.8, 0.2) # Neutral
		if capture_progress > 0.1:
			col = Color(1.0, 0.2, 0.2).lerp(Color(1.0, 0.8, 0.2), 1.0 - capture_progress) # Red
		elif capture_progress < -0.1:
			col = Color(0.2, 0.5, 1.0).lerp(Color(1.0, 0.8, 0.2), 1.0 - absf(capture_progress)) # Blue

		if beam_mesh and beam_mesh.material_override:
			var bm := beam_mesh.material_override as StandardMaterial3D
			bm.albedo_color = Color(col.r, col.g, col.b, 0.35)

		if ring_mesh and ring_mesh.material_override:
			var rm := ring_mesh.material_override as StandardMaterial3D
			rm.albedo_color = Color(col.r, col.g, col.b, 0.8)

		if light:
			light.light_color = col

		if label_3d:
			var pct: int = int(absf(capture_progress) * 100.0)
			var status_str := "НЕЙТРАЛЕН"
			if capture_progress > 0.05:
				status_str = "БААЛ (КРАСНЫЕ): %d%%" % pct
			elif capture_progress < -0.05:
				status_str = "МОЛОХ (СИНИЕ): %d%%" % pct
			label_3d.text = "[ %s ]\n%s" % [display_name, status_str]
			label_3d.modulate = col

	func update_capture_logic(delta: float) -> void:
		if not is_active:
			return

		var red_count: int = 0
		var blue_count: int = 0

		var units := get_tree().get_nodes_in_group("units")
		for u in units:
			if not is_instance_valid(u) or u.is_queued_for_deletion():
				continue
			if u.get("is_dead") == true:
				continue
			if not (u is CharacterBody3D):
				continue

			var dist: float = global_position.distance_to(u.global_position)
			if dist <= capture_radius:
				if u.get("team") == Globals.Team.BAAL_RED:
					red_count += 1
				elif u.get("team") == Globals.Team.MOLOCH_BLUE:
					blue_count += 1

		# Capture rate
		var speed: float = 0.25 # 4 seconds to full cap with 1 unit
		if red_count > 0 and blue_count == 0:
			capture_progress = clampf(capture_progress + speed * float(red_count) * delta, -1.0, 1.0)
			if capture_progress >= 1.0 and not is_captured:
				is_captured = true
				current_owner = Globals.Team.BAAL_RED
				emit_signal("sector_captured", self)
				if AudioManager.instance:
					AudioManager.instance.play_sfx(AudioManager.instance.sfx_capture, 2.0)
		elif blue_count > 0 and red_count == 0:
			capture_progress = clampf(capture_progress - speed * float(blue_count) * delta, -1.0, 1.0)
			if capture_progress <= -1.0 and not is_captured:
				is_captured = true
				current_owner = Globals.Team.MOLOCH_BLUE
				emit_signal("sector_captured", self)
				if AudioManager.instance:
					AudioManager.instance.play_sfx(AudioManager.instance.sfx_capture, 2.0)

var zone_a: CaptureSector3D
var zone_b: CaptureSector3D
var zone_c: CaptureSector3D

var world_env: WorldEnvironment
var sun_light: DirectionalLight3D

func _ready() -> void:
	_setup_lighting_and_environment()
	_build_arena_geometry()
	_setup_capture_zones()
	_setup_jump_pads()

func _setup_lighting_and_environment() -> void:
	# 1. Environment: Gothic twilight with Quake glow
	world_env = WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY

	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.1, 0.12, 0.18)
	sky_mat.sky_horizon_color = Color(0.4, 0.2, 0.15)
	sky_mat.ground_bottom_color = Color(0.08, 0.08, 0.1)
	sky_mat.ground_horizon_color = Color(0.3, 0.15, 0.12)
	sky.sky_material = sky_mat
	env.sky = sky

	# Tone mapping & Quake style Glow/Bloom
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 1.1
	env.glow_bloom = 0.25
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE

	# Atmospheric Distance Fog (supported across all renderers)
	env.fog_enabled = true
	env.fog_light_color = Color(0.35, 0.2, 0.15)
	env.fog_density = 0.006

	world_env.environment = env
	add_child(world_env)

	# 2. Directional Sun
	sun_light = DirectionalLight3D.new()
	sun_light.rotation_degrees = Vector3(-48.0, 35.0, 0.0)
	sun_light.light_color = Color(1.0, 0.85, 0.7)
	sun_light.light_energy = 1.5
	sun_light.shadow_enabled = true
	add_child(sun_light)

func _build_arena_geometry() -> void:
	# Materials
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.2, 0.22, 0.25)
	floor_mat.roughness = 0.85

	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.16, 0.17, 0.2)
	wall_mat.roughness = 0.9

	var trim_mat := StandardMaterial3D.new()
	trim_mat.albedo_color = Color(0.7, 0.35, 0.1)
	trim_mat.roughness = 0.4
	trim_mat.metallic = 0.6

	# 1. Main Floor (80m x 80m)
	_create_box_collider_mesh(Vector3(0, -0.5, 0), Vector3(80, 1.0, 80), floor_mat)

	# 2. Outer Perimeter Walls (height 12m)
	_create_box_collider_mesh(Vector3(0, 6.0, -40), Vector3(80, 12.0, 2.0), wall_mat) # North
	_create_box_collider_mesh(Vector3(0, 6.0, 40), Vector3(80, 12.0, 2.0), wall_mat)  # South
	_create_box_collider_mesh(Vector3(-40, 6.0, 0), Vector3(2.0, 12.0, 80), wall_mat) # West
	_create_box_collider_mesh(Vector3(40, 6.0, 0), Vector3(2.0, 12.0, 80), wall_mat)  # East

	# 3. Central Gothic Cathedral / Tower (x = 0, z = 0)
	# Base platform (16m x 16m, height 3.5m)
	_create_box_collider_mesh(Vector3(0, 1.75, 0), Vector3(16, 3.5, 16), wall_mat)
	# Upper platform (10m x 10m at height 7.0m)
	_create_box_collider_mesh(Vector3(0, 5.25, 0), Vector3(10, 3.5, 10), trim_mat)

	# 4 Gothic Pillars around center
	for px in [-7.0, 7.0]:
		for pz in [-7.0, 7.0]:
			_create_box_collider_mesh(Vector3(px, 7.0, pz), Vector3(1.8, 14.0, 1.8), wall_mat)

	# 4. Elevated Perimeter Catwalks & Balconies
	# West Balcony (+4.5m)
	_create_box_collider_mesh(Vector3(-28.0, 2.25, 0.0), Vector3(14.0, 4.5, 28.0), floor_mat)
	# East Balcony (+4.5m)
	_create_box_collider_mesh(Vector3(28.0, 2.25, 0.0), Vector3(14.0, 4.5, 28.0), floor_mat)
	# North High Walkway (+6.0m)
	_create_box_collider_mesh(Vector3(0.0, 3.0, -28.0), Vector3(32.0, 6.0, 8.0), floor_mat)
	# South High Walkway (+6.0m)
	_create_box_collider_mesh(Vector3(0.0, 3.0, 28.0), Vector3(32.0, 6.0, 8.0), floor_mat)

	# 5. Access Ramps & Stairs
	_create_ramp(Vector3(-18.0, 2.25, -12.0), Vector3(8.0, 4.5, 6.0), Vector3(0, 0, -22.0), floor_mat)
	_create_ramp(Vector3(18.0, 2.25, 12.0), Vector3(8.0, 4.5, 6.0), Vector3(0, 0, 22.0), floor_mat)

	# 6. Cover Blocks & Pillars scattered across Courtyard
	var cover_positions: Array[Vector3] = [
		Vector3(-14, 1.5, -18), Vector3(-14, 1.5, 18),
		Vector3(14, 1.5, -18), Vector3(14, 1.5, 18),
		Vector3(-22, 1.2, -10), Vector3(22, 1.2, 10),
		Vector3(0, 1.5, -18), Vector3(0, 1.5, 18)
	]
	for c_pos in cover_positions:
		_create_box_collider_mesh(c_pos, Vector3(2.5, 3.0, 2.5), wall_mat)

	# 7. Decorative Torches / Gothic Glow Lights
	var light_spots: Array[Vector3] = [
		Vector3(-7, 7.5, -7), Vector3(7, 7.5, -7),
		Vector3(-7, 7.5, 7), Vector3(7, 7.5, 7),
		Vector3(-28, 5.5, -10), Vector3(-28, 5.5, 10),
		Vector3(28, 5.5, -10), Vector3(28, 5.5, 10)
	]
	for l_pos in light_spots:
		var o := OmniLight3D.new()
		o.position = l_pos
		o.light_color = Color(1.0, 0.5, 0.15)
		o.light_energy = 2.0
		o.omni_range = 14.0
		add_child(o)

func _create_box_collider_mesh(pos: Vector3, size: Vector3, mat: Material) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.position = pos

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	sb.add_child(col)

	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	sb.add_child(mi)

	add_child(sb)
	return sb

func _create_ramp(pos: Vector3, size: Vector3, rot_deg: Vector3, mat: Material) -> StaticBody3D:
	var sb := _create_box_collider_mesh(pos, size, mat)
	sb.rotation_degrees = rot_deg
	return sb

func _setup_capture_zones() -> void:
	# Sector A: Lower West Courtyard
	zone_a = CaptureSector3D.new("A", "СЕКТОР А (ДВОР)", Vector3(-25.0, 0.0, 0.0))
	add_child(zone_a)

	# Sector B: Central High Cathedral Tower (+7m)
	zone_b = CaptureSector3D.new("B", "СЕКТОР B (БАШНЯ)", Vector3(0.0, 7.0, 0.0))
	zone_b.is_active = false
	add_child(zone_b)

	# Sector C: Upper East Redoubt (+4.5m)
	zone_c = CaptureSector3D.new("C", "СЕКТОР C (БАСТИОН)", Vector3(25.0, 4.5, 0.0))
	zone_c.is_active = false
	add_child(zone_c)

func _setup_jump_pads() -> void:
	# 4 Quake Jump Pads launching players into the air toward upper platforms!
	var pad_data: Array[Dictionary] = [
		{"pos": Vector3(-14, 0.1, -14), "dir": Vector3(12.0, 18.0, 12.0)},
		{"pos": Vector3(14, 0.1, -14), "dir": Vector3(-12.0, 18.0, 12.0)},
		{"pos": Vector3(-14, 0.1, 14), "dir": Vector3(12.0, 18.0, -12.0)},
		{"pos": Vector3(14, 0.1, 14), "dir": Vector3(-12.0, 18.0, -12.0)}
	]

	for pd in pad_data:
		_create_jump_pad(pd["pos"], pd["dir"])

func _create_jump_pad(pos: Vector3, launch_vel: Vector3) -> void:
	var area := Area3D.new()
	area.position = pos

	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 1.6
	cyl.height = 0.5
	col.shape = cyl
	area.add_child(col)

	# Glowing bounce pad mesh
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.5
	cm.bottom_radius = 1.6
	cm.height = 0.2
	mi.mesh = cm

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.8, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.1, 0.8, 1.0)
	mat.emission_energy_multiplier = 4.0
	mi.material_override = mat
	area.add_child(mi)

	var light := OmniLight3D.new()
	light.light_color = Color(0.1, 0.8, 1.0)
	light.light_energy = 2.5
	light.omni_range = 5.0
	light.position = Vector3(0, 0.6, 0)
	area.add_child(light)

	area.body_entered.connect(func(body: Node3D):
		if body is CharacterBody3D and body.has_method("apply_impulse"):
			body.apply_impulse(launch_vel)
			if AudioManager.instance:
				AudioManager.instance.play_sfx_3d(AudioManager.instance.sfx_jump_pad, area.global_position, 2.0)
	)

	add_child(area)

func _physics_process(delta: float) -> void:
	if zone_a: zone_a.update_capture_logic(delta)
	if zone_b: zone_b.update_capture_logic(delta)
	if zone_c: zone_c.update_capture_logic(delta)

func get_active_objective_position() -> Vector3:
	if zone_a and not zone_a.is_captured:
		return zone_a.global_position
	if zone_b and not zone_b.is_captured:
		return zone_b.global_position
	if zone_c and not zone_c.is_captured:
		return zone_c.global_position
	return Vector3.ZERO

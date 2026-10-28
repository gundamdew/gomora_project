class_name Player3D
extends Unit3D

var camera: Camera3D
var camera_pivot: Node3D
var viewmodel_root: Node3D
var muzzle_flash_light: OmniLight3D
var muzzle_flash_mesh: MeshInstance3D

var mouse_sensitivity: float = 0.0022
var pitch: float = 0.0
var yaw: float = 0.0

var camera_shake: float = 0.0
var base_fov: float = 95.0
var target_fov: float = 95.0

# Weapon Viewmodels
var viewmodels: Dictionary = {}
var weapon_bob_timer: float = 0.0
var weapon_recoil_pos: Vector3 = Vector3.ZERO
var weapon_recoil_rot: Vector3 = Vector3.ZERO

# Weapon Ammo & Stats
var ammo: Dictionary = {
	1: 999, # Melee
	2: 24,  # Shotgun
	3: 150, # Machinegun
	4: 15,  # Rocket Launcher
	5: 10,  # Railgun
	6: 60   # Plasma
}

var fire_cooldown: float = 0.0
var prev_weapon_idx: int = 2

# Network transform sync
var _net_sync_timer: float = 0.0
var target_net_pos: Vector3
var target_net_yaw: float = 0.0
var target_net_pitch: float = 0.0

func _ready() -> void:
	super._ready()
	add_to_group("players")
	name = "Player_%d" % peer_id
	unit_name = "Игрок %d" % peer_id

	target_net_pos = global_position

	if is_multiplayer_authority():
		name = "Player_Local"
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_setup_first_person_camera()
		_setup_viewmodels()
		# Hide third-person body for local player
		if visual_root:
			visual_root.visible = false
		if nameplate_label:
			nameplate_label.visible = false

func _setup_first_person_camera() -> void:
	camera_pivot = Node3D.new()
	camera_pivot.position = Vector3(0, 1.65, 0)
	add_child(camera_pivot)

	camera = Camera3D.new()
	camera.fov = base_fov
	camera.current = true
	camera_pivot.add_child(camera)

func _setup_viewmodels() -> void:
	viewmodel_root = Node3D.new()
	viewmodel_root.position = Vector3(0.28, -0.22, -0.55)
	camera.add_child(viewmodel_root)

	var dark_metal := StandardMaterial3D.new()
	dark_metal.albedo_color = Color(0.2, 0.22, 0.25)
	dark_metal.roughness = 0.4
	dark_metal.metallic = 0.8

	var neon_cyan := StandardMaterial3D.new()
	neon_cyan.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	neon_cyan.albedo_color = Color(0.1, 0.9, 1.0)

	var neon_orange := StandardMaterial3D.new()
	neon_orange.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	neon_orange.albedo_color = Color(1.0, 0.4, 0.05)

	# 1. Melee Gauntlet Blade
	var vm_1 := Node3D.new()
	var blade_mesh := MeshInstance3D.new()
	var b_box := BoxMesh.new()
	b_box.size = Vector3(0.04, 0.12, 0.4)
	blade_mesh.mesh = b_box
	blade_mesh.material_override = neon_cyan
	vm_1.add_child(blade_mesh)
	viewmodel_root.add_child(vm_1)
	viewmodels[1] = vm_1

	# 2. Super Shotgun (Double Barrel)
	var vm_2 := Node3D.new()
	var b1 := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.035
	cyl.bottom_radius = 0.035
	cyl.height = 0.55
	b1.mesh = cyl
	b1.rotation_degrees.x = 90.0
	b1.position = Vector3(-0.04, 0, 0)
	b1.material_override = dark_metal
	vm_2.add_child(b1)

	var b2 := MeshInstance3D.new()
	b2.mesh = cyl
	b2.rotation_degrees.x = 90.0
	b2.position = Vector3(0.04, 0, 0)
	b2.material_override = dark_metal
	vm_2.add_child(b2)
	viewmodel_root.add_child(vm_2)
	viewmodels[2] = vm_2

	# 3. Machinegun
	var vm_3 := Node3D.new()
	var mg_body := MeshInstance3D.new()
	var mg_box := BoxMesh.new()
	mg_box.size = Vector3(0.08, 0.12, 0.45)
	mg_body.mesh = mg_box
	mg_body.material_override = dark_metal
	vm_3.add_child(mg_body)
	viewmodel_root.add_child(vm_3)
	viewmodels[3] = vm_3

	# 4. Rocket Launcher (Wide cylindrical cannon)
	var vm_4 := Node3D.new()
	var rl_body := MeshInstance3D.new()
	var rl_cyl := CylinderMesh.new()
	rl_cyl.top_radius = 0.09
	rl_cyl.bottom_radius = 0.09
	rl_cyl.height = 0.65
	rl_body.mesh = rl_cyl
	rl_body.rotation_degrees.x = 90.0
	rl_body.material_override = dark_metal
	vm_4.add_child(rl_body)

	var rl_ring := MeshInstance3D.new()
	var r_torus := TorusMesh.new()
	r_torus.inner_radius = 0.09
	r_torus.outer_radius = 0.12
	rl_ring.mesh = r_torus
	rl_ring.rotation_degrees.x = 90.0
	rl_ring.position = Vector3(0, 0, -0.28)
	rl_ring.material_override = neon_orange
	vm_4.add_child(rl_ring)
	viewmodel_root.add_child(vm_4)
	viewmodels[4] = vm_4

	# 5. Railgun (Sleek tech cannon with glowing coils)
	var vm_5 := Node3D.new()
	var rg_body := MeshInstance3D.new()
	var rg_box := BoxMesh.new()
	rg_box.size = Vector3(0.07, 0.08, 0.7)
	rg_body.mesh = rg_box
	rg_body.material_override = dark_metal
	vm_5.add_child(rg_body)

	for c_idx in range(4):
		var coil := MeshInstance3D.new()
		var coil_box := BoxMesh.new()
		coil_box.size = Vector3(0.09, 0.1, 0.04)
		coil.mesh = coil_box
		coil.position = Vector3(0, 0, -0.1 - float(c_idx) * 0.12)
		coil.material_override = neon_cyan
		vm_5.add_child(coil)

	viewmodel_root.add_child(vm_5)
	viewmodels[5] = vm_5

	# 6. Plasma Gun
	var vm_6 := Node3D.new()
	var pg_body := MeshInstance3D.new()
	var pg_box := BoxMesh.new()
	pg_box.size = Vector3(0.1, 0.12, 0.5)
	pg_body.mesh = pg_box
	pg_body.material_override = dark_metal
	vm_6.add_child(pg_body)
	viewmodel_root.add_child(vm_6)
	viewmodels[6] = vm_6

	# Muzzle Flash
	muzzle_flash_light = OmniLight3D.new()
	muzzle_flash_light.light_color = Color(1.0, 0.7, 0.2)
	muzzle_flash_light.light_energy = 0.0
	muzzle_flash_light.omni_range = 8.0
	muzzle_flash_light.position = Vector3(0.28, -0.22, -1.1)
	camera.add_child(muzzle_flash_light)

	_update_viewmodel_visibility()

func _update_viewmodel_visibility() -> void:
	for idx in viewmodels:
		viewmodels[idx].visible = (idx == active_weapon_idx)

func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

		# Weapon switching with mouse wheel
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_cycle_weapon(1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_cycle_weapon(-1)

	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * mouse_sensitivity
		pitch = clampf(pitch - event.relative.y * mouse_sensitivity, -deg_to_rad(88.0), deg_to_rad(88.0))
		rotation.y = yaw
		if camera_pivot:
			camera_pivot.rotation.x = pitch

func _cycle_weapon(step: int) -> void:
	var next_idx: int = active_weapon_idx + step
	if next_idx > 6: next_idx = 1
	if next_idx < 1: next_idx = 6
	_select_weapon(next_idx)

func _select_weapon(idx: int) -> void:
	if idx != active_weapon_idx:
		prev_weapon_idx = active_weapon_idx
		active_weapon_idx = idx
		_update_viewmodel_visibility()
		emit_signal("weapon_state_changed")

func add_camera_shake(amount: float) -> void:
	camera_shake = clampf(camera_shake + amount, 0.0, 0.8)

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if is_multiplayer_authority():
		_handle_player_input(delta)
		_update_viewmodel_animation(delta)
		_network_broadcast(delta)
	else:
		# Remote player interpolation
		global_position = global_position.lerp(target_net_pos, 18.0 * delta)
		rotation.y = lerp_angle(rotation.y, target_net_yaw, 18.0 * delta)
		if visual_root:
			visual_root.rotation.x = target_net_pitch

	super._physics_process(delta)

func _handle_player_input(delta: float) -> void:
	# ESC: toggle mouse capture / pause menu
	if Input.is_key_pressed(KEY_ESCAPE) or Input.is_action_just_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Numeric weapon hotkeys (1..6)
	for k in range(1, 7):
		if Input.is_physical_key_pressed(KEY_0 + k):
			_select_weapon(k)
	if Input.is_action_just_pressed("switch_slot"):
		_select_weapon(prev_weapon_idx)

	# Movement direction (WASD)
	var input_dir := Vector3.ZERO
	if Input.is_action_pressed("move_up") or Input.is_key_pressed(KEY_W):
		input_dir.z -= 1.0
	if Input.is_action_pressed("move_down") or Input.is_key_pressed(KEY_S):
		input_dir.z += 1.0
	if Input.is_action_pressed("move_left") or Input.is_key_pressed(KEY_A):
		input_dir.x -= 1.0
	if Input.is_action_pressed("move_right") or Input.is_key_pressed(KEY_D):
		input_dir.x += 1.0

	var wish_dir: Vector3 = (transform.basis * input_dir).normalized()

	# Quake Ground vs Air Physics
	var is_grounded: bool = is_on_floor()
	if is_grounded:
		# Ground snappy acceleration
		var target_vel: Vector3 = wish_dir * move_speed
		velocity.x = lerpf(velocity.x, target_vel.x, 15.0 * delta)
		velocity.z = lerpf(velocity.z, target_vel.z, 15.0 * delta)

		# Jump
		if Input.is_key_pressed(KEY_SPACE) or Input.is_action_just_pressed("dodge_roll"):
			velocity.y = jump_velocity
			if AudioManager.instance:
				AudioManager.instance.play_sfx(AudioManager.instance.sfx_jump, -2.0)
	else:
		# Quake Air Strafe Acceleration!
		if wish_dir != Vector3.ZERO:
			var current_speed: float = velocity.dot(wish_dir)
			var add_speed: float = clampf(move_speed - current_speed, 0.0, 32.0 * delta)
			velocity += wish_dir * add_speed

	# Weapons Fire Controls
	if fire_cooldown > 0.0:
		fire_cooldown -= delta

	var is_firing: bool = (
		(Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_action_pressed("fire_primary"))
		and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	)

	if is_firing and fire_cooldown <= 0.0:
		_try_fire_active_weapon()

	# Secondary fire: Railgun / Weapon Zoom
	var is_zoom: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or Input.is_action_pressed("fire_secondary")
	target_fov = 48.0 if is_zoom else base_fov
	if camera:
		camera.fov = lerpf(camera.fov, target_fov, 14.0 * delta)

	# Camera Shake decay
	if camera_shake > 0.0:
		camera_shake = maxf(0.0, camera_shake - delta * 1.5)
		if camera:
			camera.h_offset = randf_range(-camera_shake, camera_shake) * 0.15
			camera.v_offset = randf_range(-camera_shake, camera_shake) * 0.15

func _try_fire_active_weapon() -> void:
	if ammo[active_weapon_idx] <= 0:
		if AudioManager.instance:
			AudioManager.instance.play_sfx(AudioManager.instance.sfx_reload, 1.0)
		fire_cooldown = 0.3
		return

	match active_weapon_idx:
		1: # Melee Gauntlet
			fire_cooldown = 0.35
			_fire_melee()
		2: # Super Shotgun
			fire_cooldown = 0.65
			ammo[2] -= 2
			_fire_shotgun()
		3: # Machinegun
			fire_cooldown = 0.09
			ammo[3] -= 1
			_fire_machinegun()
		4: # Rocket Launcher
			fire_cooldown = 0.75
			ammo[4] -= 1
			_fire_rocket()
		5: # Railgun
			fire_cooldown = 1.15
			ammo[5] -= 1
			_fire_railgun()
		6: # Plasma Gun
			fire_cooldown = 0.12
			ammo[6] -= 1
			_fire_plasma()

	emit_signal("weapon_state_changed")
	_trigger_recoil()

func _fire_melee() -> void:
	if AudioManager.instance:
		AudioManager.instance.play_sfx(AudioManager.instance.sfx_knife, 2.0)

	var from_pos: Vector3 = camera.global_position
	var forward: Vector3 = -camera.global_transform.basis.z
	var to_pos: Vector3 = from_pos + forward * 2.8

	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from_pos, to_pos)
	query.exclude = [get_rid()]
	var res := space.intersect_ray(query)
	if not res.is_empty():
		var col: Object = res.collider
		if col and col.has_method("apply_damage"):
			col.apply_damage(50.0, false, self)

func _fire_shotgun() -> void:
	if AudioManager.instance:
		AudioManager.instance.play_sfx(AudioManager.instance.sfx_shotgun, 3.0)
	add_camera_shake(0.2)

	var from_pos: Vector3 = camera.global_position + (-camera.global_transform.basis.z * 0.4)
	var forward: Vector3 = -camera.global_transform.basis.z
	var right: Vector3 = camera.global_transform.basis.x
	var up: Vector3 = camera.global_transform.basis.y

	# Fire 10 pellets in spread cone
	for i in range(10):
		var spread_x: float = randf_range(-0.07, 0.07)
		var spread_y: float = randf_range(-0.06, 0.06)
		var dir: Vector3 = (forward + right * spread_x + up * spread_y).normalized()
		_perform_hitscan_shot(from_pos, dir, 12.0, Tracer3D.TracerType.SHOTGUN)

func _fire_machinegun() -> void:
	if AudioManager.instance:
		AudioManager.instance.play_sfx(AudioManager.instance.sfx_machinegun, 1.5)
	add_camera_shake(0.04)

	var from_pos: Vector3 = camera.global_position + (-camera.global_transform.basis.z * 0.4)
	var forward: Vector3 = -camera.global_transform.basis.z
	var right: Vector3 = camera.global_transform.basis.x
	var up: Vector3 = camera.global_transform.basis.y

	var spread_x: float = randf_range(-0.02, 0.02)
	var spread_y: float = randf_range(-0.02, 0.02)
	var dir: Vector3 = (forward + right * spread_x + up * spread_y).normalized()
	_perform_hitscan_shot(from_pos, dir, 14.0, Tracer3D.TracerType.BULLET)

func _fire_railgun() -> void:
	if AudioManager.instance:
		AudioManager.instance.play_sfx(AudioManager.instance.sfx_railgun, 4.0)
	add_camera_shake(0.35)

	var from_pos: Vector3 = camera.global_position + (-camera.global_transform.basis.z * 0.4)
	var forward: Vector3 = -camera.global_transform.basis.z
	_perform_hitscan_shot(from_pos, forward, 100.0, Tracer3D.TracerType.RAILGUN)

func _perform_hitscan_shot(from_pos: Vector3, dir: Vector3, dmg: float, tracer_type: Tracer3D.TracerType) -> void:
	var to_pos: Vector3 = from_pos + dir * 180.0
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from_pos, to_pos)
	query.exclude = [get_rid()]

	var hit_end: Vector3 = to_pos
	var res := space.intersect_ray(query)
	if not res.is_empty():
		hit_end = res.position
		var col: Object = res.collider
		if col and col.has_method("apply_damage"):
			var is_headshot: bool = (hit_end.y - (col as Node3D).global_position.y) > 1.4
			col.apply_damage(dmg, is_headshot, self)

	# Local Tracer
	_spawn_tracer(from_pos, hit_end, tracer_type)

	# Broadcast to multiplayer peers
	if multiplayer.has_multiplayer_peer():
		rpc("rpc_hitscan_effect", from_pos, hit_end, int(tracer_type))

func _fire_rocket() -> void:
	if AudioManager.instance:
		AudioManager.instance.play_sfx(AudioManager.instance.sfx_rocket_launch, 3.0)
	add_camera_shake(0.25)

	var from_pos: Vector3 = camera.global_position + (-camera.global_transform.basis.z * 0.8)
	var dir: Vector3 = -camera.global_transform.basis.z

	if multiplayer.has_multiplayer_peer():
		rpc("rpc_spawn_rocket", from_pos, dir)
	else:
		_spawn_rocket_local(from_pos, dir)

func _fire_plasma() -> void:
	if AudioManager.instance:
		AudioManager.instance.play_sfx(AudioManager.instance.sfx_plasma, 2.0)

	var from_pos: Vector3 = camera.global_position + (-camera.global_transform.basis.z * 0.6)
	var dir: Vector3 = -camera.global_transform.basis.z

	if multiplayer.has_multiplayer_peer():
		rpc("rpc_spawn_plasma", from_pos, dir)
	else:
		_spawn_plasma_local(from_pos, dir)

func _spawn_rocket_local(from_pos: Vector3, dir: Vector3) -> void:
	var p_script = load("res://scripts/projectile_3d.gd")
	if p_script:
		var p: Projectile3D = p_script.new()
		p.setup(from_pos, dir, Projectile3D.ProjectileType.ROCKET, 100.0, team, peer_id, self)
		get_parent().add_child(p)

func _spawn_plasma_local(from_pos: Vector3, dir: Vector3) -> void:
	var p_script = load("res://scripts/projectile_3d.gd")
	if p_script:
		var p: Projectile3D = p_script.new()
		p.setup(from_pos, dir, Projectile3D.ProjectileType.PLASMA, 24.0, team, peer_id, self)
		get_parent().add_child(p)

func _spawn_tracer(from_pos: Vector3, end_pos: Vector3, type: Tracer3D.TracerType) -> void:
	var t_script = load("res://scripts/tracer_3d.gd")
	if t_script:
		var t: Tracer3D = t_script.new()
		t.setup(from_pos, end_pos, type)
		get_parent().add_child(t)

func _trigger_recoil() -> void:
	weapon_recoil_pos = Vector3(0, 0.04, 0.12)
	weapon_recoil_rot = Vector3(0.08, 0, 0)
	if muzzle_flash_light:
		muzzle_flash_light.light_energy = 4.0

func _update_viewmodel_animation(delta: float) -> void:
	if not viewmodel_root:
		return

	# Recoil lerp back
	weapon_recoil_pos = weapon_recoil_pos.lerp(Vector3.ZERO, 15.0 * delta)
	weapon_recoil_rot = weapon_recoil_rot.lerp(Vector3.ZERO, 15.0 * delta)

	# Muzzle flash light fade
	if muzzle_flash_light:
		muzzle_flash_light.light_energy = lerpf(muzzle_flash_light.light_energy, 0.0, 25.0 * delta)

	# Walking weapon bobbing
	var horiz_vel := Vector2(velocity.x, velocity.z).length()
	var bob_offset := Vector3.ZERO
	if is_on_floor() and horiz_vel > 0.5:
		weapon_bob_timer += delta * (horiz_vel * 1.2)
		bob_offset.x = cos(weapon_bob_timer * 0.5) * 0.02
		bob_offset.y = sin(weapon_bob_timer) * 0.015
	else:
		weapon_bob_timer = 0.0

	var default_pos := Vector3(0.28, -0.22, -0.55)
	viewmodel_root.position = default_pos + bob_offset + weapon_recoil_pos
	viewmodel_root.rotation = weapon_recoil_rot

func _network_broadcast(delta: float) -> void:
	if not multiplayer.has_multiplayer_peer():
		return

	_net_sync_timer -= delta
	if _net_sync_timer <= 0.0:
		_net_sync_timer = 0.033 # 30 Hz position sync
		rpc("rpc_sync_transform", global_position, yaw, pitch, active_weapon_idx)

# ---------------- MULTIPLAYER RPCs ----------------

@rpc("any_peer", "unreliable")
func rpc_sync_transform(pos: Vector3, p_yaw: float, p_pitch: float, w_idx: int) -> void:
	if is_multiplayer_authority():
		return
	target_net_pos = pos
	target_net_yaw = p_yaw
	target_net_pitch = p_pitch
	active_weapon_idx = w_idx

@rpc("any_peer", "call_local", "reliable")
func rpc_spawn_rocket(from_pos: Vector3, dir: Vector3) -> void:
	_spawn_rocket_local(from_pos, dir)

@rpc("any_peer", "call_local", "reliable")
func rpc_spawn_plasma(from_pos: Vector3, dir: Vector3) -> void:
	_spawn_plasma_local(from_pos, dir)

@rpc("any_peer", "call_local", "unreliable")
func rpc_hitscan_effect(from_pos: Vector3, to_pos: Vector3, tracer_type_int: int) -> void:
	if is_multiplayer_authority():
		return
	_spawn_tracer(from_pos, to_pos, tracer_type_int as Tracer3D.TracerType)

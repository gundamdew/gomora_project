class_name Bot3D
extends Unit3D

var current_target: Unit3D = null
var current_objective_pos: Vector3 = Vector3.ZERO

var ai_tick_timer: float = 0.0
var strafe_timer: float = 0.0
var strafe_dir: float = 1.0

var fire_timer: float = 0.0
var preferred_weapon: int = 4 # Default Rocket Launcher

var target_net_pos: Vector3
var target_net_yaw: float = 0.0

func _ready() -> void:
	super._ready()
	add_to_group("bots")
	target_net_pos = global_position
	fire_timer = randf_range(0.5, 1.5)
	strafe_dir = 1.0 if randf() > 0.5 else -1.0

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# Only server / solo simulates Bot AI logic
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		_process_bot_ai(delta)
	else:
		# Remote clients interpolate bot transform
		global_position = global_position.lerp(target_net_pos, 16.0 * delta)
		rotation.y = lerp_angle(rotation.y, target_net_yaw, 16.0 * delta)

	super._physics_process(delta)

func _process_bot_ai(delta: float) -> void:
	ai_tick_timer -= delta
	if ai_tick_timer <= 0.0:
		ai_tick_timer = 0.3
		_find_best_target()

	strafe_timer -= delta
	if strafe_timer <= 0.0:
		strafe_timer = randf_range(0.8, 2.0)
		strafe_dir = -strafe_dir
		# Occasional jump over obstacle / strafe jump
		if is_on_floor() and randf() < 0.35:
			velocity.y = jump_velocity

	var target_pos: Vector3 = current_objective_pos
	var has_enemy: bool = (is_instance_valid(current_target) and not current_target.is_dead)

	if has_enemy:
		target_pos = current_target.global_position

	var to_target: Vector3 = target_pos - global_position
	to_target.y = 0.0
	var dist: float = to_target.length()

	# Aim / Rotation
	if dist > 0.1:
		var desired_yaw: float = atan2(-to_target.x, -to_target.z)
		rotation.y = lerp_angle(rotation.y, desired_yaw, 10.0 * delta)

	# Movement calculation
	var move_dir := Vector3.ZERO
	if dist > 3.5:
		move_dir = to_target.normalized()
	elif dist < 2.0 and has_enemy:
		move_dir = -to_target.normalized() # Back up if too close

	# Add combat strafe
	if has_enemy:
		var right_vec := transform.basis.x
		move_dir += right_vec * (strafe_dir * 0.7)
		move_dir = move_dir.normalized()

	var is_grounded: bool = is_on_floor()
	if is_grounded:
		var target_vel: Vector3 = move_dir * (move_speed * 0.85)
		velocity.x = lerpf(velocity.x, target_vel.x, 12.0 * delta)
		velocity.z = lerpf(velocity.z, target_vel.z, 12.0 * delta)
	else:
		if move_dir != Vector3.ZERO:
			velocity += move_dir * (20.0 * delta)

	# Combat shooting
	if has_enemy and dist < 45.0:
		_process_bot_combat(dist, delta)

func _find_best_target() -> void:
	current_target = null
	var min_dist: float = 999.0

	var units := get_tree().get_nodes_in_group("units")
	for u in units:
		if not is_instance_valid(u) or u == self:
			continue
		if not (u is Unit3D) or u.is_dead:
			continue
		if u.team == team:
			continue # Friendly

		var d: float = global_position.distance_to(u.global_position)
		if d < min_dist:
			min_dist = d
			current_target = u

func _process_bot_combat(dist: float, delta: float) -> void:
	fire_timer -= delta
	if fire_timer > 0.0:
		return

	# Select best weapon according to distance
	if dist > 25.0:
		preferred_weapon = 5 # Railgun
		fire_timer = randf_range(1.2, 1.8)
	elif dist > 8.0:
		preferred_weapon = 4 if randf() < 0.6 else 3 # Rocket or Machinegun
		fire_timer = 0.85 if preferred_weapon == 4 else 0.12
	else:
		preferred_weapon = 2 # Shotgun
		fire_timer = randf_range(0.7, 1.1)

	_bot_fire_weapon(preferred_weapon)

func _bot_fire_weapon(w_idx: int) -> void:
	if not is_instance_valid(current_target):
		return

	var from_pos: Vector3 = global_position + Vector3(0, 1.4, 0)
	var target_chest: Vector3 = current_target.global_position + Vector3(0, 1.1, 0)
	var to_dir: Vector3 = (target_chest - from_pos).normalized()

	# Add minor bot aim inaccuracy
	to_dir.x += randf_range(-0.04, 0.04)
	to_dir.y += randf_range(-0.03, 0.03)
	to_dir.z += randf_range(-0.04, 0.04)
	to_dir = to_dir.normalized()

	match w_idx:
		2: # Shotgun
			if AudioManager.instance:
				AudioManager.instance.play_sfx_3d(AudioManager.instance.sfx_shotgun, from_pos, 2.0)
			for i in range(8):
				var spread := to_dir + Vector3(randf_range(-0.06, 0.06), randf_range(-0.05, 0.05), randf_range(-0.06, 0.06))
				_bot_hitscan(from_pos, spread.normalized(), 10.0, Tracer3D.TracerType.SHOTGUN)
		3: # Machinegun
			if AudioManager.instance:
				AudioManager.instance.play_sfx_3d(AudioManager.instance.sfx_machinegun, from_pos, 1.0)
			_bot_hitscan(from_pos, to_dir, 12.0, Tracer3D.TracerType.BULLET)
		4: # Rocket Launcher
			if AudioManager.instance:
				AudioManager.instance.play_sfx_3d(AudioManager.instance.sfx_rocket_launch, from_pos, 2.0)
			if multiplayer.has_multiplayer_peer():
				GameManager3D.instance.rpc("rpc_spawn_bot_rocket", from_pos, to_dir, int(team))
			else:
				_spawn_bot_rocket(from_pos, to_dir)
		5: # Railgun
			if AudioManager.instance:
				AudioManager.instance.play_sfx_3d(AudioManager.instance.sfx_railgun, from_pos, 3.0)
			_bot_hitscan(from_pos, to_dir, 90.0, Tracer3D.TracerType.RAILGUN)

func _bot_hitscan(from_pos: Vector3, dir: Vector3, dmg: float, tracer_type: Tracer3D.TracerType) -> void:
	var to_pos: Vector3 = from_pos + dir * 140.0
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

	_spawn_tracer(from_pos, hit_end, tracer_type)

	if multiplayer.has_multiplayer_peer():
		GameManager3D.instance.rpc("rpc_bot_tracer", from_pos, hit_end, int(tracer_type))

func _spawn_bot_rocket(from_pos: Vector3, dir: Vector3) -> void:
	var p_script = load("res://scripts/projectile_3d.gd")
	if p_script:
		var p: Projectile3D = p_script.new()
		p.setup(from_pos, dir, Projectile3D.ProjectileType.ROCKET, 95.0, team, 999, self)
		get_parent().add_child(p)

func _spawn_tracer(from_pos: Vector3, end_pos: Vector3, type: Tracer3D.TracerType) -> void:
	var t_script = load("res://scripts/tracer_3d.gd")
	if t_script:
		var t: Tracer3D = t_script.new()
		t.setup(from_pos, end_pos, type)
		get_parent().add_child(t)

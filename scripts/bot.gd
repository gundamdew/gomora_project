class_name Bot
extends Unit

var target_enemy: Unit = null
var current_objective_pos: Vector2 = Vector2.ZERO
var _decision_timer: float = 0.0

func _ready() -> void:
	super._ready()
	add_to_group("bots")
	_decision_timer = randf_range(0.1, 0.4)

func _physics_process(delta: float) -> void:
	if is_dead:
		return
		
	# Only server / host simulates bot decision AI
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		_decision_timer -= delta
		if _decision_timer <= 0.0:
			_decision_timer = randf_range(0.2, 0.4)
			_update_ai_decisions()
			
		_execute_ai_behavior(delta)
		
	super._physics_process(delta)

func _update_ai_decisions() -> void:
	# Find nearest living enemy
	var units := get_tree().get_nodes_in_group("units")
	var nearest_dist: float = 99999.0
	target_enemy = null
	
	for u in units:
		if is_instance_valid(u) and u is Unit and u != self and u.team != team and not u.is_dead:
			var d: float = global_position.distance_to(u.global_position)
			if d < nearest_dist:
				nearest_dist = d
				target_enemy = u

	# AI Body Part Targeting strategy
	if target_enemy:
		var r: float = randf()
		if r < 0.35:
			current_body_target = Globals.BodyTarget.HEAD
		elif r < 0.65:
			current_body_target = Globals.BodyTarget.ARMS
		else:
			current_body_target = Globals.BodyTarget.LEGS

func _execute_ai_behavior(_delta: float) -> void:
	# Kamikaze charge
	if kamikaze_active:
		if target_enemy and is_instance_valid(target_enemy):
			var to_enemy: Vector2 = (target_enemy.global_position - global_position).normalized()
			aim_angle = to_enemy.angle()
			_step_toward(target_enemy.global_position)
		return

	if target_enemy and is_instance_valid(target_enemy):
		var dist: float = global_position.distance_to(target_enemy.global_position)
		var to_enemy: Vector2 = (target_enemy.global_position - global_position).normalized()
		aim_angle = to_enemy.angle()
		aim_pos = target_enemy.global_position

		# Tile-based Combat positioning
		var desired_range: float = 140.0
		if dist > desired_range + 35.0:
			_step_toward(target_enemy.global_position)
		elif dist < desired_range - 35.0:
			_step_toward(global_position - to_enemy * 64.0)
		else:
			# Occasional tactical strafe
			if randf() < 0.15:
				var strafe: Vector2 = to_enemy.orthogonal() * (32.0 if randf() < 0.5 else -32.0)
				_step_toward(global_position + strafe)

		# Firing logic
		var w: WeaponData = get_active_primary_weapon()
		if w:
			if w.current_ammo > 0:
				if randf() < 0.35:
					try_fire_primary(target_enemy, target_enemy.global_position)
			else:
				start_reload()

		# Melee attack if close and has knife
		if dist < 48.0 and weapon_slot_2_right and weapon_slot_2_right.weapon_type == WeaponData.WeaponType.MELEE:
			if active_slot != 2:
				switch_weapon_slot()
			try_fire_secondary(target_enemy, target_enemy.global_position)

		# Dual pistols: fire right-hand pistol if Leech in Slot 2
		if active_slot == 2 and weapon_slot_2_right and weapon_slot_2_right.weapon_type != WeaponData.WeaponType.MELEE:
			if weapon_slot_2_right.current_ammo > 0 and randf() < 0.35:
				try_fire_secondary(target_enemy, target_enemy.global_position)

		# Roll away if low hp and light class
		if torso_hp < 40.0 and class_data.has_dodge_roll and randf() < 0.08:
			var roll_dir_vec := Vector2i(int(round(-to_enemy.x)), int(round(-to_enemy.y)))
			try_dodge_roll(roll_dir_vec)
	else:
		# Objective movement towards active capture zone
		if current_objective_pos != Vector2.ZERO:
			var to_obj: Vector2 = (current_objective_pos - global_position).normalized()
			aim_angle = to_obj.angle()
			_step_toward(current_objective_pos)

func _step_toward(dest_pos: Vector2) -> void:
	if is_stepping or is_rolling:
		return
	var diff: Vector2 = dest_pos - global_position
	var dx: int = 0
	var dy: int = 0
	if absf(diff.x) > 12.0:
		dx = 1 if diff.x > 0 else -1
	if absf(diff.y) > 12.0:
		dy = 1 if diff.y > 0 else -1
		
	var dir := Vector2i(dx, dy)
	if not try_step(dir):
		if dx != 0 and not try_step(Vector2i(dx, 0)):
			if dy != 0:
				try_step(Vector2i(0, dy))
		elif dy != 0:
			try_step(Vector2i(0, dy))

class_name Player
extends Unit

var camera: Camera2D
var auto_firing: bool = false
var hovered_enemy: Unit = null
var is_looking_ahead: bool = false

func _ready() -> void:
	super._ready()
	add_to_group("players")
	_setup_camera()

func _setup_camera() -> void:
	camera = Camera2D.new()
	camera.enabled = is_multiplayer_authority()
	camera.zoom = Vector2(2.0, 2.0) # 2x pixel scale in 1080p centered play area (1080x1080)
	camera.position_smoothing_enabled = false
	add_child(camera)

func _physics_process(delta: float) -> void:
	if is_dead:
		return
		
	if is_multiplayer_authority():
		_handle_input()
		_update_camera_look(delta)
		
	super._physics_process(delta)

func _update_camera_look(delta: float) -> void:
	if not camera:
		return

	# Look-ahead input: Shift key or Middle mouse button
	is_looking_ahead = (
		Input.is_key_pressed(KEY_SHIFT) or
		Input.is_physical_key_pressed(KEY_SHIFT) or
		Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE)
	)

	var mouse_world: Vector2 = get_global_mouse_position()
	var to_mouse: Vector2 = mouse_world - global_position
	var mouse_dist: float = to_mouse.length()
	var mouse_dir: Vector2 = to_mouse.normalized() if mouse_dist > 0.0 else Vector2.ZERO

	var target_offset: Vector2 = Vector2.ZERO
	if is_looking_ahead:
		# Extended look-ahead: shifts camera up to 240 world pixels towards cursor (~7.5 tiles)
		var max_peek: float = 240.0
		var peek_amount: float = clampf(mouse_dist * 0.75, 0.0, max_peek)
		target_offset = mouse_dir * peek_amount
	else:
		# Subtle natural aim bias: shifts camera up to 45 world pixels towards cursor
		var max_subtle: float = 45.0
		var subtle_amount: float = clampf(mouse_dist * 0.18, 0.0, max_subtle)
		target_offset = mouse_dir * subtle_amount

	camera.position = camera.position.lerp(target_offset, 9.0 * delta)

func _handle_input() -> void:
	# Ignore in-game inputs if pause menu is open
	var hud_node: Node = get_tree().root.find_child("HUD", true, false)
	if hud_node and hud_node.get("is_pause_open") == true:
		return

	# 1. Aim towards mouse position in world
	aim_pos = get_global_mouse_position()
	aim_angle = (aim_pos - global_position).angle()
	
	# Check for enemy under cursor for direct targeting
	_detect_hovered_enemy()
	
	# 2. Tile-based Movement
	if not is_rolling:
		var dir := Vector2i.ZERO
		if Input.is_action_pressed("move_left"):
			dir.x -= 1
		if Input.is_action_pressed("move_right"):
			dir.x += 1
		if Input.is_action_pressed("move_up"):
			dir.y -= 1
		if Input.is_action_pressed("move_down"):
			dir.y += 1
			
		if Input.is_action_just_pressed("dodge_roll"):
			try_dodge_roll(dir)
		elif not is_stepping and dir != Vector2i.ZERO:
			if not try_step(dir):
				if dir.x != 0 and dir.y != 0:
					if not try_step(Vector2i(dir.x, 0)):
						try_step(Vector2i(0, dir.y))

	# 3. Weapons controls (only fire when cursor is inside the central gameplay view X: 420..1500)
	var screen_mpos := get_viewport().get_mouse_position()
	var in_play_area := (screen_mpos.x >= 420.0 and screen_mpos.x <= 1500.0)
	var w: WeaponData = get_active_primary_weapon()
	if Input.is_action_just_pressed("fire_primary") and in_play_area:
		auto_firing = true
		try_fire_primary(hovered_enemy, aim_pos)
	elif Input.is_action_pressed("fire_primary") and auto_firing and in_play_area:
		if w and w.is_automatic:
			try_fire_primary(hovered_enemy, aim_pos)
	else:
		auto_firing = false
		
	# Secondary action: Special mode toggle on Slot 1, Melee Knife or Right Hand Pistol on Slot 2
	var w2: WeaponData = get_active_secondary_weapon()
	if active_slot == 1:
		if Input.is_action_just_pressed("fire_secondary") and in_play_area:
			try_fire_secondary(hovered_enemy, aim_pos)
	else:
		if Input.is_action_just_pressed("fire_secondary") and in_play_area:
			try_fire_secondary(hovered_enemy, aim_pos)
		elif Input.is_action_pressed("fire_secondary") and in_play_area:
			if w2 and (w2.weapon_type == WeaponData.WeaponType.MELEE or w2.is_automatic):
				try_fire_secondary(hovered_enemy, aim_pos)
		
	if Input.is_action_just_pressed("reload"):
		start_reload()
		
	if Input.is_action_just_pressed("switch_slot"):
		switch_weapon_slot()
		
	# 4. Target Body Part selection hotkeys
	if Input.is_action_just_pressed("target_head"):
		current_body_target = Globals.BodyTarget.HEAD
		emit_signal("weapon_state_changed")
	elif Input.is_action_just_pressed("target_arms"):
		current_body_target = Globals.BodyTarget.ARMS
		emit_signal("weapon_state_changed")
	elif Input.is_action_just_pressed("target_legs"):
		current_body_target = Globals.BodyTarget.LEGS
		emit_signal("weapon_state_changed")

	# 5. Extra hotkeys
	if Input.is_action_just_pressed("toggle_range_ring"):
		show_range_ring = !show_range_ring
	if Input.is_action_just_pressed("kamikaze_manual"):
		manual_kamikaze()

func _detect_hovered_enemy() -> void:
	var space := get_world_2d().direct_space_state
	var query := PhysicsPointQueryParameters2D.new()
	query.position = aim_pos
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var hits := space.intersect_point(query, 8)
	hovered_enemy = null
	for hit in hits:
		var col: Object = hit.get("collider")
		if col is Unit and col != self and col.team != team and not col.is_dead:
			hovered_enemy = col
			break

class_name Unit
extends CharacterBody2D

signal integrity_changed
signal unit_died(unit: Unit, by_headshot: bool)
signal weapon_state_changed
signal kamikaze_started

@export var peer_id: int = 1
@export var team: Globals.Team = Globals.Team.BAAL_RED
@export var class_data: ClassData

var weight_class: Globals.WeightClass = Globals.WeightClass.LIGHT

# Integrity stats
var torso_hp: float = 100.0
var max_torso_hp: float = 100.0
var arms_hp: float = 60.0
var max_arms_hp: float = 60.0
var legs_hp: float = 60.0
var max_legs_hp: float = 60.0

# Evasion (Raptor extra: max 15, regens after 5s without taking attacks)
var evasion: float = 0.0
var max_evasion: float = 0.0
var evasion_regen_timer: float = 0.0

var is_dead: bool = false
var kamikaze_active: bool = false
var kamikaze_timer: float = 5.0
var kamikaze_beep_timer: float = 1.0

# Stun / Slow
var stun_timer: float = 0.0

# Tile-based movement
var current_tile: Vector2i = Vector2i.ZERO
var start_tile: Vector2i = Vector2i.ZERO
var target_tile: Vector2i = Vector2i.ZERO
var is_stepping: bool = false
var step_progress: float = 0.0
var step_duration: float = 0.2

# Dodge roll (tile-based)
var is_rolling: bool = false
var roll_dir: Vector2i = Vector2i.ZERO
var roll_remaining_steps: int = 0
var roll_cooldown_timer: float = 0.0

# Weapons
var weapon_slot_1: WeaponData # Two-handed
var weapon_slot_2_left: WeaponData # One-handed primary / left
var weapon_slot_2_right: WeaponData # One-handed secondary / right (e.g. knife)
var active_slot: int = 1 # 1 or 2

# Targeting selection for attacks
var current_body_target: Globals.BodyTarget = Globals.BodyTarget.TORSO
var show_range_ring: bool = true

# Aiming & Sprite
var aim_angle: float = 0.0
var aim_pos: Vector2 = Vector2.ZERO
var sprite_node: Sprite2D
var overlay_sprite_node: Sprite2D
var overlay_left_arm_node: Sprite2D
var overlay_right_arm_node: Sprite2D
var collision_shape: CollisionShape2D

# DMI Layering & Animation State
var base_state_name: String = ""
var overlay_two_handed_name: String = ""
var overlay_left_arm_name: String = ""
var overlay_right_arm_name: String = ""
var anim_frame: int = 0
var anim_timer: float = 0.0
var anim_frame_delay: float = 0.16
var current_dmi_dir: int = 0

# Melee visual slash effect
var melee_slash_timer: float = 0.0
var melee_slash_dir: Vector2 = Vector2.RIGHT

var _sync_timer: float = 0.0

func _ready() -> void:
	add_to_group("units")
	_init_components()
	if class_data == null:
		class_data = ClassData.create_leech() if team == Globals.Team.BAAL_RED else ClassData.create_trooper()
	setup_class(class_data)

func _init_components() -> void:
	collision_shape = CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 12.0
	collision_shape.shape = circle
	add_child(collision_shape)
	
	# Base torso/legs (класс_цифра)
	sprite_node = Sprite2D.new()
	sprite_node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite_node.z_index = 0
	add_child(sprite_node)
	
	# Slot 1: Two-handed rifle + arms overlay
	overlay_sprite_node = Sprite2D.new()
	overlay_sprite_node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	overlay_sprite_node.z_index = 1 # Renders on top of base sprite
	add_child(overlay_sprite_node)

	# Slot 2: Left arm / weapon overlay
	overlay_left_arm_node = Sprite2D.new()
	overlay_left_arm_node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	overlay_left_arm_node.z_index = 1
	add_child(overlay_left_arm_node)

	# Slot 2: Right arm / weapon overlay
	overlay_right_arm_node = Sprite2D.new()
	overlay_right_arm_node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	overlay_right_arm_node.z_index = 1
	add_child(overlay_right_arm_node)

func setup_class(data: ClassData) -> void:
	class_data = data
	weight_class = data.weight_class
	max_torso_hp = data.max_torso_hp
	torso_hp = max_torso_hp
	max_arms_hp = data.max_arms_hp
	arms_hp = max_arms_hp
	max_legs_hp = data.max_legs_hp
	legs_hp = max_legs_hp
	
	# Evasion
	max_evasion = data.max_evasion
	evasion = max_evasion
	evasion_regen_timer = 0.0

	# Align to tile center
	current_tile = Globals.world_to_tile(global_position)
	start_tile = current_tile
	target_tile = current_tile
	global_position = Globals.tile_to_world_center(current_tile)

	# Loadouts based on class
	if data.class_id == "leech":
		weapon_slot_1 = WeaponData.create_mk_ultra()
		weapon_slot_2_left = WeaponData.create_tribunal()
		weapon_slot_2_right = WeaponData.create_tribunal() # Dual pistols (Tribunal in left and right hands!)
		active_slot = 1
	elif data.class_id == "trooper":
		weapon_slot_1 = WeaponData.create_wagner()
		weapon_slot_2_left = WeaponData.create_sudan()
		weapon_slot_2_right = WeaponData.create_fatwa() # Melee combat knife for Trooper
		active_slot = 1
	elif data.class_id == "raptor":
		weapon_slot_1 = null
		weapon_slot_2_left = WeaponData.create_ghetta() # ПП Ghetta in left hand
		weapon_slot_2_right = WeaponData.create_cossack() # Клинок Cossack in right hand
		active_slot = 2
	elif data.class_id == "augur":
		weapon_slot_1 = null
		weapon_slot_2_left = WeaponData.create_blaster() # Обрез Blaster in left hand
		weapon_slot_2_right = WeaponData.create_templum() # Пушка Templum in right hand
		active_slot = 2
	else:
		weapon_slot_1 = WeaponData.create_mk_ultra()
		weapon_slot_2_left = WeaponData.create_tribunal()
		weapon_slot_2_right = WeaponData.create_tribunal()
		active_slot = 1
		
	_update_dmi_states()
	if sprite_node and sprite_node.texture == null:
		sprite_node.texture = AssetGenerator.get_unit_texture(team, weight_class)
	emit_signal("integrity_changed")
	emit_signal("weapon_state_changed")

func has_network() -> bool:
	return is_inside_tree() and multiplayer != null and multiplayer.has_multiplayer_peer()

func _physics_process(delta: float) -> void:
	if is_dead:
		return
		
	_process_kamikaze(delta)
	_process_stun(delta)
	_process_tile_movement(delta)
	_process_weapons(delta)
	
	# Evasion regeneration (after 5s without taking attacks, regens 20% max per sec)
	if max_evasion > 0.0:
		if evasion_regen_timer > 0.0:
			evasion_regen_timer -= delta
		elif evasion < max_evasion:
			var prev_e: float = evasion
			evasion = minf(max_evasion, evasion + (max_evasion * 0.2) * delta)
			if int(prev_e) != int(evasion):
				emit_signal("integrity_changed")

	if melee_slash_timer > 0.0:
		melee_slash_timer -= delta

	if roll_cooldown_timer > 0.0:
		roll_cooldown_timer -= delta

	# Periodic aim angle sync for multiplayer peers
	if is_multiplayer_authority() and has_network():
		_sync_timer -= delta
		if _sync_timer <= 0.0:
			_sync_timer = 0.05 # 20 Hz
			rpc("rpc_sync_aim", aim_angle)

	# Animate DMI base (класс_цифра) and overlay (класс_оружие_рука)
	_process_animations(delta)

	queue_redraw()

func _process_kamikaze(delta: float) -> void:
	if not kamikaze_active:
		return
	kamikaze_timer -= delta
	kamikaze_beep_timer -= delta
	if kamikaze_beep_timer <= 0.0:
		kamikaze_beep_timer = clampf(kamikaze_timer * 0.2, 0.15, 0.8)
		if AudioManager.instance:
			AudioManager.instance.play_sfx(AudioManager.instance.sfx_kamikaze_beep)
			
	if kamikaze_timer <= 0.0:
		_explode_kamikaze()

func _process_stun(delta: float) -> void:
	if stun_timer > 0.0:
		stun_timer -= delta

func _process_weapons(delta: float) -> void:
	_tick_weapon(weapon_slot_1, delta)
	_tick_weapon(weapon_slot_2_left, delta)
	_tick_weapon(weapon_slot_2_right, delta)

func _tick_weapon(w: WeaponData, delta: float) -> void:
	if w == null:
		return
	if w.fire_cooldown > 0.0:
		w.fire_cooldown -= delta
	if w.is_reloading:
		w.reload_timer -= delta
		if w.reload_timer <= 0.0:
			w.is_reloading = false
			w.current_ammo = w.magazine_size
			emit_signal("weapon_state_changed")
	elif w.reload_time <= 0.0 and w.current_ammo < w.magazine_size:
		w.current_ammo = w.magazine_size

# Tile Movement Calculations
func get_current_move_delay() -> float:
	var delay: float = class_data.base_move_delay
	# Stun delay penalty: +3 for Light, +2 for Medium
	if stun_timer > 0.0:
		delay += Globals.get_stun_delay_penalty(weight_class)
	# Leg damage penalties
	var leg_ratio: float = legs_hp / max_legs_hp
	if leg_ratio <= 0.0:
		delay += 8.0 # Crawling penalty
	elif leg_ratio <= 0.5:
		delay += 3.0 # Limping penalty
	return delay

func try_step(dir: Vector2i) -> bool:
	if is_dead or is_rolling or is_stepping:
		return false
	if dir == Vector2i.ZERO:
		return false
		
	var next_t: Vector2i = current_tile + dir
	if MapGenerator.instance and MapGenerator.instance.is_tile_solid(next_t):
		return false
		
	var dur: float = Globals.delay_to_step_time(get_current_move_delay())
	if has_network():
		rpc("rpc_step", current_tile, next_t, dur)
	else:
		_execute_step(current_tile, next_t, dur)
	return true

func _execute_step(start_t: Vector2i, target_t: Vector2i, dur: float) -> void:
	start_tile = start_t
	target_tile = target_t
	is_stepping = true
	step_progress = 0.0
	step_duration = dur

func _process_tile_movement(delta: float) -> void:
	if is_rolling:
		_process_roll_step(delta)
		return
		
	if not is_stepping:
		return
		
	step_progress += delta / step_duration
	if step_progress >= 1.0:
		step_progress = 1.0
		is_stepping = false
		current_tile = target_tile
		global_position = Globals.tile_to_world_center(current_tile)
	else:
		var p0: Vector2 = Globals.tile_to_world_center(start_tile)
		var p1: Vector2 = Globals.tile_to_world_center(target_tile)
		global_position = p0.lerp(p1, step_progress)

# Tile-based Dodge Roll
func try_dodge_roll(dir: Vector2i) -> bool:
	if is_dead or is_rolling or not class_data.has_dodge_roll:
		return false
	if roll_cooldown_timer > 0.0:
		return false
	if dir == Vector2i.ZERO:
		dir = Vector2i(int(round(cos(aim_angle))), int(round(sin(aim_angle))))
		if dir == Vector2i.ZERO:
			dir = Vector2i.RIGHT
			
	if has_network():
		rpc("rpc_start_roll", dir)
	else:
		_execute_roll(dir)
	return true

func _execute_roll(dir: Vector2i) -> void:
	is_rolling = true
	roll_dir = dir
	roll_remaining_steps = class_data.roll_tiles
	roll_cooldown_timer = class_data.roll_cooldown
	_start_next_roll_step()
	if AudioManager.instance:
		AudioManager.instance.play_sfx(AudioManager.instance.sfx_roll)

func _reset_doll_rotations() -> void:
	if sprite_node: sprite_node.rotation = 0.0
	if overlay_sprite_node: overlay_sprite_node.rotation = 0.0
	if overlay_left_arm_node: overlay_left_arm_node.rotation = 0.0
	if overlay_right_arm_node: overlay_right_arm_node.rotation = 0.0

func _start_next_roll_step() -> void:
	if roll_remaining_steps <= 0:
		is_rolling = false
		_reset_doll_rotations()
		return
	var next_t: Vector2i = current_tile + roll_dir
	if MapGenerator.instance and MapGenerator.instance.is_tile_solid(next_t):
		is_rolling = false
		_reset_doll_rotations()
		return
	start_tile = current_tile
	target_tile = next_t
	roll_remaining_steps -= 1
	step_progress = 0.0
	step_duration = 0.08 # fast roll step
	is_stepping = true

func _process_roll_step(delta: float) -> void:
	if not is_stepping:
		_start_next_roll_step()
		return
	step_progress += delta / step_duration
	if step_progress >= 1.0:
		step_progress = 1.0
		is_stepping = false
		current_tile = target_tile
		global_position = Globals.tile_to_world_center(current_tile)
		if roll_remaining_steps > 0:
			_start_next_roll_step()
		else:
			is_rolling = false
			_reset_doll_rotations()
	else:
		var p0: Vector2 = Globals.tile_to_world_center(start_tile)
		var p1: Vector2 = Globals.tile_to_world_center(target_tile)
		global_position = p0.lerp(p1, step_progress)

func switch_weapon_slot() -> void:
	if is_rolling:
		return
	if has_network():
		rpc("rpc_switch_weapon_slot")
	else:
		_execute_switch_weapon_slot()

func _execute_switch_weapon_slot() -> void:
	# If class has no two-handed rifle (e.g. Raptor or Augur), keep one-handed combo in Slot 2
	if weapon_slot_1 == null:
		active_slot = 2
		_update_dmi_states()
		emit_signal("weapon_state_changed")
		return

	# If arms <= 50%, cannot use Slot 1
	if arms_hp <= (max_arms_hp * 0.5) and not (class_data and class_data.instant_explode_on_arms_loss):
		active_slot = 2
		_update_dmi_states()
		emit_signal("weapon_state_changed")
		return
		
	active_slot = 2 if active_slot == 1 else 1
	_update_dmi_states()
	emit_signal("weapon_state_changed")

@rpc("any_peer", "call_local", "reliable")
func rpc_switch_weapon_slot() -> void:
	_execute_switch_weapon_slot()

func _get_dmi_manager() -> Node:
	var dmi := get_node_or_null("/root/DmiManager")
	if dmi:
		return dmi
	if get_tree() and get_tree().root:
		dmi = get_tree().root.get_node_or_null("DmiManager")
		if dmi:
			return dmi
		var script = load("res://scripts/dmi_manager.gd")
		if script and script.can_instantiate():
			dmi = script.new()
			dmi.name = "DmiManager"
			get_tree().root.add_child(dmi)
			return dmi
	return null

func _update_dmi_states() -> void:
	var dmi := _get_dmi_manager()
	if not dmi or not dmi.get("is_loaded"):
		return
	var c_id: String = class_data.class_id if class_data else "leech"
	var t_val: int = int(team)
	base_state_name = dmi.call("get_base_state", c_id, team)
	
	# Slot 1: two-handed rifle + arms overlay
	var w1_id: String = weapon_slot_1.weapon_id if weapon_slot_1 else ""
	overlay_two_handed_name = dmi.call("get_two_handed_overlay", c_id, w1_id, t_val)
	
	# Slot 2: one-handed left/right hand overlays
	var w2_l_id: String = weapon_slot_2_left.weapon_id if weapon_slot_2_left else ""
	var w2_r_id: String = weapon_slot_2_right.weapon_id if weapon_slot_2_right else ""
	overlay_left_arm_name = dmi.call("get_one_handed_overlay", c_id, w2_l_id, "l", t_val)
	overlay_right_arm_name = dmi.call("get_one_handed_overlay", c_id, w2_r_id, "r", t_val)

func _process_animations(delta: float) -> void:
	var dmi := _get_dmi_manager()
	if not dmi or not dmi.get("is_loaded"):
		if sprite_node:
			sprite_node.rotation = aim_angle
		return

	if base_state_name.is_empty():
		_update_dmi_states()
		if base_state_name.is_empty():
			if sprite_node:
				sprite_node.rotation = aim_angle
			return

	var is_moving: bool = (is_stepping or is_rolling)

	# 1. Determine active base state (moving vs standing)
	var active_base := base_state_name
	if is_moving and not is_rolling and dmi.call("has_state", base_state_name + "_move"):
		active_base = base_state_name + "_move"

	# 2. Update Direction & Rotation (Aim vs Dodge Roll tumble)
	var base_info: Dictionary = dmi.call("get_state_info", active_base)
	var num_dirs: int = base_info.get("dirs", 1)
	var total_frames: int = base_info.get("frames", 1)

	if is_rolling:
		# Dodge Roll: Doll rotated 90 degrees (lying flat) and tumbling through directions
		var roll_rot: float = -PI * 0.5 if (roll_dir.x < 0 or (roll_dir.x == 0 and roll_dir.y < 0)) else PI * 0.5
		if sprite_node:
			sprite_node.rotation = roll_rot
		if overlay_sprite_node:
			overlay_sprite_node.rotation = roll_rot
		if overlay_left_arm_node:
			overlay_left_arm_node.rotation = roll_rot
		if overlay_right_arm_node:
			overlay_right_arm_node.rotation = roll_rot

		var tumble_seq: Array = [0, 2, 1, 3] if roll_rot > 0.0 else [0, 3, 1, 2]
		var phase: int = clampi(int(step_progress * 4.0), 0, 3)
		current_dmi_dir = tumble_seq[phase]
		anim_frame = 0
		anim_timer = 0.0
	elif num_dirs > 1:
		current_dmi_dir = dmi.call("angle_to_dmi_dir", aim_angle, num_dirs)
		if sprite_node:
			sprite_node.rotation = 0.0
		if overlay_sprite_node:
			overlay_sprite_node.rotation = 0.0
		if overlay_left_arm_node:
			overlay_left_arm_node.rotation = 0.0
		if overlay_right_arm_node:
			overlay_right_arm_node.rotation = 0.0
	else:
		current_dmi_dir = 0
		if sprite_node:
			sprite_node.rotation = aim_angle
		if overlay_sprite_node:
			overlay_sprite_node.rotation = aim_angle
		if overlay_left_arm_node:
			overlay_left_arm_node.rotation = aim_angle
		if overlay_right_arm_node:
			overlay_right_arm_node.rotation = aim_angle

	# 3. Calculate animation frame:
	# Continuous 4-frame cycle per tile step:
	if not is_rolling:
		if is_moving:
			if total_frames > 1:
				anim_frame = clampi(int(step_progress * float(total_frames)), 0, total_frames - 1)
			else:
				anim_frame = 0
			anim_timer = 0.0
		else:
			# Stationary: standing frame 0 (or idle cycle if state has multiple frames)
			if total_frames > 1:
				anim_timer += delta
				if anim_timer >= anim_frame_delay:
					anim_timer = 0.0
					anim_frame = (anim_frame + 1) % total_frames
			else:
				anim_frame = 0
				anim_timer = 0.0

	# 4. Apply Base Layer Texture (класс_цифра)
	var base_tex: Texture2D = dmi.call("get_texture", active_base, current_dmi_dir, anim_frame)
	if base_tex and sprite_node:
		sprite_node.texture = base_tex

	# 5. Handle Overlays & Arm Destruction:
	# "Руки не пропадают с персонажей после их уничтожения"
	# "класс_цифра(база) + класс_оружие_рука(оверлей). Это необходимо для того чтобы удалять его в случае уничтожение сегмента рук."
	if arms_hp <= 0.0 or is_dead:
		# Arms destroyed: remove/hide all weapon and arm overlays!
		if overlay_sprite_node:
			overlay_sprite_node.visible = false
		if overlay_left_arm_node:
			overlay_left_arm_node.visible = false
		if overlay_right_arm_node:
			overlay_right_arm_node.visible = false
		return

	# Arms alive: display overlays according to active_slot
	if active_slot == 1:
		# Slot 1: Two-handed rifle + arms overlay
		if overlay_left_arm_node:
			overlay_left_arm_node.visible = false
		if overlay_right_arm_node:
			overlay_right_arm_node.visible = false

		if overlay_sprite_node:
			if not overlay_two_handed_name.is_empty():
				overlay_sprite_node.visible = true
				var active_ov := overlay_two_handed_name
				if is_moving and not is_rolling and dmi.call("has_state", overlay_two_handed_name + "_move"):
					active_ov = overlay_two_handed_name + "_move"

				var ov_info: Dictionary = dmi.call("get_state_info", active_ov)
				var ov_dirs: int = ov_info.get("dirs", 1)
				var ov_frames: int = ov_info.get("frames", 1)
				var ov_dir: int = current_dmi_dir if ov_dirs > 1 else 0
				var ov_frame: int = anim_frame if ov_frames > 1 else 0
				var ov_tex: Texture2D = dmi.call("get_texture", active_ov, ov_dir, ov_frame)
				if ov_tex:
					overlay_sprite_node.texture = ov_tex
			else:
				overlay_sprite_node.visible = false
	else:
		# Slot 2: One-handed weapons / arms (left and right)
		if overlay_sprite_node:
			overlay_sprite_node.visible = false

		# Left hand overlay
		if overlay_left_arm_node:
			if not overlay_left_arm_name.is_empty():
				overlay_left_arm_node.visible = true
				var active_l := overlay_left_arm_name
				if is_moving and not is_rolling and dmi.call("has_state", overlay_left_arm_name + "_move"):
					active_l = overlay_left_arm_name + "_move"

				var l_info: Dictionary = dmi.call("get_state_info", active_l)
				var l_dirs: int = l_info.get("dirs", 1)
				var l_frames: int = l_info.get("frames", 1)
				var l_dir: int = current_dmi_dir if l_dirs > 1 else 0
				var l_frame: int = anim_frame if l_frames > 1 else 0
				var l_tex: Texture2D = dmi.call("get_texture", active_l, l_dir, l_frame)
				if l_tex:
					overlay_left_arm_node.texture = l_tex
			else:
				overlay_left_arm_node.visible = false

		# Right hand overlay
		if overlay_right_arm_node:
			if not overlay_right_arm_name.is_empty():
				overlay_right_arm_node.visible = true
				var active_r := overlay_right_arm_name
				if is_moving and not is_rolling and dmi.call("has_state", overlay_right_arm_name + "_move"):
					active_r = overlay_right_arm_name + "_move"

				var r_info: Dictionary = dmi.call("get_state_info", active_r)
				var r_dirs: int = r_info.get("dirs", 1)
				var r_frames: int = r_info.get("frames", 1)
				var r_dir: int = current_dmi_dir if r_dirs > 1 else 0
				var r_frame: int = anim_frame if r_frames > 1 else 0
				var r_tex: Texture2D = dmi.call("get_texture", active_r, r_dir, r_frame)
				if r_tex:
					overlay_right_arm_node.texture = r_tex
			else:
				overlay_right_arm_node.visible = false

func get_active_primary_weapon() -> WeaponData:
	if active_slot == 1:
		return weapon_slot_1
	return weapon_slot_2_left

func get_active_secondary_weapon() -> WeaponData:
	if active_slot == 1:
		return weapon_slot_1 # alt action for slot 1
	return weapon_slot_2_right

func try_fire_primary(target_unit: Node2D = null, target_pos: Vector2 = Vector2.ZERO) -> bool:
	if is_dead and not kamikaze_active:
		return false
	if is_rolling:
		return false
	if arms_hp <= 0.0:
		return false # no arms left
		
	var w: WeaponData = get_active_primary_weapon()
	if arms_hp <= (max_arms_hp * 0.5) and not (class_data and class_data.instant_explode_on_arms_loss):
		# If one arm lost on standard class: fire whatever arm remains
		if w == null or active_slot == 1:
			w = weapon_slot_2_left if weapon_slot_2_left != null else weapon_slot_2_right
	if w == null:
		return false
	return _execute_weapon_attack(w, target_unit, target_pos, false)

func try_fire_secondary(target_unit: Node2D = null, target_pos: Vector2 = Vector2.ZERO) -> bool:
	if is_dead and not kamikaze_active:
		return false
	if is_rolling:
		return false
	if arms_hp <= 0.0:
		return false
		
	if active_slot == 1 and weapon_slot_1 != null:
		# Special mode toggle on Slot 1 two-handed weapon
		weapon_slot_1.alt_mode_active = !weapon_slot_1.alt_mode_active
		emit_signal("weapon_state_changed")
		return true
	else:
		# Slot 2 (or one-handed combo):
		# If one arm is lost on standard units, fire remaining arm's weapon
		var w: WeaponData = weapon_slot_2_right
		if arms_hp <= (max_arms_hp * 0.5) and not (class_data and class_data.instant_explode_on_arms_loss):
			w = weapon_slot_2_left if weapon_slot_2_left != null else weapon_slot_2_right
		if w == null:
			w = weapon_slot_2_left
		if w:
			return _execute_weapon_attack(w, target_unit, target_pos, true)
		return false

func _execute_weapon_attack(w: WeaponData, target_unit: Node2D, target_pos: Vector2, is_secondary: bool) -> bool:
	if w.is_reloading or w.fire_cooldown > 0.0:
		return false
		
	if w.weapon_type == WeaponData.WeaponType.MELEE:
		w.fire_cooldown = w.fire_delay
		emit_signal("weapon_state_changed")
		var dir := Vector2.from_angle(aim_angle)
		var spawn_pos: Vector2 = global_position + dir * 14.0
		_execute_melee_attack(w, spawn_pos, dir)
		return true

	# Firearm attack
	if w.current_ammo <= 0 and w.reload_time > 0.0:
		start_reload()
		return false
		
	if w.reload_time > 0.0:
		w.current_ammo -= 1
	else:
		w.current_ammo = w.magazine_size
	w.fire_cooldown = w.fire_delay
	emit_signal("weapon_state_changed")
	
	var dir := Vector2.from_angle(aim_angle)
	var side_offset: Vector2 = Vector2.ZERO
	if active_slot == 2:
		var side_norm := Vector2(-dir.y, dir.x) # lateral perpendicular vector
		side_offset = (side_norm * 5.0) if is_secondary else (-side_norm * 5.0)
	var spawn_pos: Vector2 = global_position + dir * 14.0 + side_offset
	
	if target_pos != Vector2.ZERO and spawn_pos.distance_to(target_pos) > 8.0:
		dir = (target_pos - spawn_pos).normalized()

	_perform_hitscan(w, spawn_pos, dir, target_unit, target_pos)
	return true

func _perform_hitscan(w: WeaponData, spawn_pos: Vector2, dir: Vector2, target_unit: Node2D, target_pos: Vector2) -> void:
	# 1. Play weapon sound
	_play_fire_sound(w)

	var max_dist: float = w.max_range_tiles * Globals.TILE_SIZE
	var max_pos: Vector2 = spawn_pos + dir * max_dist
	var is_wagner_aoe: bool = (w.alt_mode_active and w.weapon_id == "wagner")

	var space_state := get_world_2d().direct_space_state
	if space_state == null:
		return

	# Handle Piercing weapons (Templum extra: passes through units except heavy)
	if w.is_piercing:
		var curr_from: Vector2 = spawn_pos
		var exclude_rids: Array[RID] = [self.get_rid()]
		var final_reach: Vector2 = max_pos
		var final_norm: Vector2 = -dir
		var final_hit_type: int = 0
		
		for _step in range(12):
			if spawn_pos.distance_to(curr_from) >= max_dist:
				break
			var q := PhysicsRayQueryParameters2D.create(curr_from, max_pos)
			q.collide_with_areas = false
			q.collide_with_bodies = true
			q.exclude = exclude_rids
			var res := space_state.intersect_ray(q)
			if res.is_empty():
				final_reach = max_pos
				final_hit_type = 0
				break
				
			var col: Object = res.get("collider")
			var p: Vector2 = res.get("position", max_pos)
			var n: Vector2 = res.get("normal", -dir)
			var r: RID = res.get("rid", RID())
			
			if col is Unit:
				var u: Unit = col as Unit
				if u == self or u.team == team or u.is_dead:
					exclude_rids.append(r)
					curr_from = p + dir * 2.0
					continue
				else:
					# Hit an enemy!
					var dist_px: float = spawn_pos.distance_to(p)
					var eff_dist_px: float = Globals.get_effective_range_distance(w.eff_range_category)
					var within_eff: bool = (dist_px <= eff_dist_px)
					var eff_falloff: float = Globals.calculate_effective_falloff(dist_px, w.eff_range_category)
					var base_dmg: float = w.calculate_damage_against(u.weight_class)
					var final_dmg: float = base_dmg * eff_falloff
					var safe_att: Node2D = self if is_instance_valid(self) else null
					u.apply_damage(final_dmg, current_body_target, team, safe_att, false, false, false, false, within_eff)
					_spawn_tracer_effect(curr_from, p, n, 2, w.weapon_id, false)
					
					if u.weight_class == Globals.WeightClass.HEAVY:
						final_reach = p
						final_norm = n
						final_hit_type = 2
						break
					else:
						exclude_rids.append(r)
						curr_from = p + dir * 2.0
						final_reach = p
						final_norm = n
						final_hit_type = 2
			else:
				# Wall / obstacle
				final_reach = p
				final_norm = n
				final_hit_type = 1
				break
				
		_spawn_tracer_effect(curr_from, final_reach, final_norm, final_hit_type, w.weapon_id, false)
		if has_network():
			rpc("rpc_show_hitscan_tracer", spawn_pos, final_reach, final_norm, final_hit_type, w.weapon_id, false)
		return

	# Standard Hitscan Raycast
	var from: Vector2 = spawn_pos
	var to: Vector2 = max_pos
	var exclude: Array[RID] = [self.get_rid()]
	var hit_pos: Vector2 = max_pos
	var hit_normal: Vector2 = -dir
	var hit_unit: Unit = null
	var hit_type_int: int = 0 # 0: AIR, 1: WALL, 2: UNIT, 3: AOE

	for _i in range(8):
		if spawn_pos.distance_to(from) >= max_dist:
			hit_pos = to
			hit_type_int = 0
			break

		var query := PhysicsRayQueryParameters2D.create(from, to)
		query.collide_with_areas = false
		query.collide_with_bodies = true
		query.exclude = exclude

		var result := space_state.intersect_ray(query)
		if result.is_empty():
			hit_pos = to
			hit_type_int = 0
			break

		var collider: Object = result.get("collider")
		var pos: Vector2 = result.get("position", to)
		var norm: Vector2 = result.get("normal", -dir)
		var rid: RID = result.get("rid", RID())

		if collider is Unit:
			var u: Unit = collider as Unit
			if u == self or u.team == team or u.is_dead:
				# Friendly unit or dead corpse: penetrate through
				exclude.append(rid)
				from = pos + dir * 2.0
				continue
			else:
				# Living enemy unit hit!
				hit_pos = pos
				hit_normal = norm
				hit_unit = u
				hit_type_int = 2
				break
		else:
			# Wall / sandbag / static obstacle
			hit_pos = pos
			hit_normal = norm
			hit_type_int = 1
			break

	# 3. Handle AoE detonation vs direct unit damage
	if is_wagner_aoe:
		hit_type_int = 3 # AOE
		if target_pos != Vector2.ZERO:
			var target_dist: float = spawn_pos.distance_to(target_pos)
			if target_dist <= max_dist and hit_pos.distance_to(spawn_pos) > target_dist:
				hit_pos = target_pos
				hit_normal = -dir

		var exp_scene := preload("res://scripts/explosion.gd")
		var explosion := Explosion.new()
		explosion.global_position = hit_pos
		var safe_att: Node2D = self if is_instance_valid(self) else null
		explosion.setup(20.0, 1.0, team, safe_att)
		get_parent().add_child(explosion)
	elif hit_unit:
		var hit_part: Globals.BodyTarget = Globals.BodyTarget.TORSO
		if is_instance_valid(target_unit) and target_unit == hit_unit:
			hit_part = current_body_target

		var dist_px: float = spawn_pos.distance_to(hit_pos)
		var eff_dist_px: float = Globals.get_effective_range_distance(w.eff_range_category)
		var within_eff: bool = (dist_px <= eff_dist_px)
		var eff_falloff: float = Globals.calculate_effective_falloff(dist_px, w.eff_range_category)
		
		# Blaster Spread extra: damage falloff beyond point blank
		if w.has_spread:
			var dist_tiles: float = dist_px / float(Globals.TILE_SIZE)
			if dist_tiles > 2.0:
				eff_falloff = clampf(1.0 - 0.05 * (dist_tiles - 2.0), 0.35, 1.0)

		var base_dmg: float = w.calculate_damage_against(hit_unit.weight_class)
		var final_dmg: float = base_dmg * eff_falloff

		var safe_att: Node2D = self if is_instance_valid(self) else null
		hit_unit.apply_damage(final_dmg, hit_part, team, safe_att, false, false, w.has_spread, w.is_automatic, within_eff)

	# 4. Spawn local visual tracer effect
	_spawn_tracer_effect(spawn_pos, hit_pos, hit_normal, hit_type_int, w.weapon_id, is_wagner_aoe)

	# 5. Broadcast tracer to other peers in multiplayer
	if has_network():
		rpc("rpc_show_hitscan_tracer", spawn_pos, hit_pos, hit_normal, hit_type_int, w.weapon_id, is_wagner_aoe)

func _play_fire_sound(w: WeaponData) -> void:
	if not AudioManager.instance:
		return
	if w.weapon_id == "templum":
		AudioManager.instance.play_sfx(AudioManager.instance.sfx_headshot, 4.0)
	elif w.weapon_id == "blaster" or (w.alt_mode_active and w.weapon_id == "wagner"):
		AudioManager.instance.play_sfx(AudioManager.instance.sfx_aoe_shot)
	elif w.weapon_type == WeaponData.WeaponType.TWO_HANDED:
		AudioManager.instance.play_sfx(AudioManager.instance.sfx_rifle)
	else:
		AudioManager.instance.play_sfx(AudioManager.instance.sfx_pistol)

func _spawn_tracer_effect(spawn_pos: Vector2, hit_pos: Vector2, hit_normal: Vector2, hit_type_int: int, weapon_id: String, is_aoe: bool) -> void:
	var tracer_script = load("res://scripts/tracer_effect.gd")
	if tracer_script:
		var tracer: Node2D = tracer_script.new()
		tracer.call("setup", spawn_pos, hit_pos, hit_normal, hit_type_int, weapon_id, is_aoe)
		get_parent().add_child(tracer)

func _execute_melee_attack(w: WeaponData, spawn_pos: Vector2, dir: Vector2) -> void:
	if AudioManager.instance:
		AudioManager.instance.play_sfx(AudioManager.instance.sfx_knife)
		
	# Trigger local slash visual
	melee_slash_timer = 0.16
	melee_slash_dir = dir
	queue_redraw()
	
	# Broadcast slash visual to peers
	if has_network():
		rpc("rpc_show_melee_slash", dir)
		
	var melee_reach: float = w.max_range_tiles * Globals.TILE_SIZE # ~51.2 px
	var hit_enemy: Unit = null
	var min_dist: float = melee_reach + 20.0
	
	if is_inside_tree():
		var units := get_tree().get_nodes_in_group("units")
		for u in units:
			if not (u is Unit) or u == self or u.team == team or u.is_dead:
				continue
			var d: float = global_position.distance_to(u.global_position)
			if d <= melee_reach + 14.0:
				var to_u: Vector2 = (u.global_position - global_position).normalized()
				var dot: float = dir.dot(to_u)
				if dot >= 0.1: # in front (~168 degree cone)
					if d < min_dist:
						min_dist = d
						hit_enemy = u
						
		if hit_enemy:
			hit_enemy.apply_damage(w.base_damage, current_body_target, team, self, true)

func _spawn_projectile(w: WeaponData, spawn_pos: Vector2, dir: Vector2, target_unit: Node2D, target_pos: Vector2) -> void:
	_perform_hitscan(w, spawn_pos, dir, target_unit, target_pos)

func start_reload() -> void:
	if is_rolling:
		return
	var did_reload: bool = false
	if active_slot == 1:
		var w: WeaponData = weapon_slot_1
		if w and not w.is_reloading and w.current_ammo < w.magazine_size and w.reload_time > 0.0:
			w.is_reloading = true
			w.reload_timer = w.reload_time
			w.current_ammo = 0 # Magazine ammo dropped upon reload
			did_reload = true
	else:
		var wl: WeaponData = weapon_slot_2_left
		if wl and wl.weapon_type != WeaponData.WeaponType.MELEE and not wl.is_reloading and wl.current_ammo < wl.magazine_size:
			if wl.reload_time > 0.0:
				wl.is_reloading = true
				wl.reload_timer = wl.reload_time
				wl.current_ammo = 0
				did_reload = true
			else:
				wl.current_ammo = wl.magazine_size
		var wr: WeaponData = weapon_slot_2_right
		if wr and wr.weapon_type != WeaponData.WeaponType.MELEE and not wr.is_reloading and wr.current_ammo < wr.magazine_size:
			if wr.reload_time > 0.0:
				wr.is_reloading = true
				wr.reload_timer = wr.reload_time
				wr.current_ammo = 0
				did_reload = true
			else:
				wr.current_ammo = wr.magazine_size

	if did_reload:
		if AudioManager.instance:
			AudioManager.instance.play_sfx(AudioManager.instance.sfx_reload)
		emit_signal("weapon_state_changed")

func manual_kamikaze() -> void:
	if not kamikaze_active and not is_dead:
		if has_network():
			rpc("rpc_trigger_kamikaze")
		else:
			_start_kamikaze()

func check_and_apply_evasion(incoming_damage: float, is_aoe: bool, is_melee: bool, has_spread: bool, is_automatic: bool, within_eff_dist: bool) -> Dictionary:
	if evasion <= 0.0 or is_rolling:
		return { "dodged": false, "damage_mult": 1.0, "no_slow": false }
	
	evasion_regen_timer = 5.0 # Timer resets upon taking damage/attack
	
	if not has_spread and not is_melee and not is_aoe:
		# Standard tracer attack: COMPLETE DODGE!
		var cost: float = 0.0
		if within_eff_dist:
			cost = 1.0 if is_automatic else 2.0
		else:
			cost = 0.0 if is_automatic else 1.0
		evasion = maxf(0.0, evasion - cost)
		emit_signal("integrity_changed")
		return { "dodged": true, "damage_mult": 0.0, "no_slow": true }
	else:
		# Spread, Melee or AoE: half damage, no slow, costs 1 evasion
		evasion = maxf(0.0, evasion - 1.0)
		emit_signal("integrity_changed")
		return { "dodged": false, "damage_mult": 0.5, "no_slow": true }

func _show_dodge_float_text() -> void:
	var lbl := Label.new()
	lbl.text = "УКЛОНЕНИЕ!"
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.7))
	lbl.position = global_position + Vector2(-24.0, -28.0)
	lbl.z_index = 10
	if get_parent():
		get_parent().add_child(lbl)
		var tw := lbl.create_tween()
		tw.tween_property(lbl, "position:y", lbl.position.y - 18.0, 0.6)
		tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.6)
		tw.tween_callback(lbl.queue_free)

func apply_damage(amount: float, body_part: Globals.BodyTarget, attacker_team: Globals.Team, attacker: Node2D = null, is_melee: bool = false, is_aoe: bool = false, has_spread: bool = false, is_automatic: bool = false, within_eff_dist: bool = true) -> void:
	if is_dead or is_rolling:
		return
	if has_network():
		rpc("rpc_apply_damage", amount, int(body_part), int(attacker_team), is_melee, is_aoe, has_spread, is_automatic, within_eff_dist)
	else:
		_execute_apply_damage(amount, body_part, attacker_team, is_melee, is_aoe, has_spread, is_automatic, within_eff_dist)

@rpc("any_peer", "call_local", "reliable")
func rpc_apply_damage(amount: float, body_part_int: int, attacker_team_int: int, is_melee: bool = false, is_aoe: bool = false, has_spread: bool = false, is_automatic: bool = false, within_eff_dist: bool = true) -> void:
	_execute_apply_damage(amount, body_part_int as Globals.BodyTarget, attacker_team_int as Globals.Team, is_melee, is_aoe, has_spread, is_automatic, within_eff_dist)

func _execute_apply_damage(amount: float, body_part: Globals.BodyTarget, attacker_team: Globals.Team, is_melee: bool, is_aoe: bool = false, has_spread: bool = false, is_automatic: bool = false, within_eff_dist: bool = true) -> void:
	if is_dead or is_rolling:
		return
		
	# Check Evasion first
	var ev_res: Dictionary = check_and_apply_evasion(amount, is_aoe, is_melee, has_spread, is_automatic, within_eff_dist)
	if ev_res.get("dodged", false):
		if AudioManager.instance:
			AudioManager.instance.play_sfx(AudioManager.instance.sfx_roll)
		_show_dodge_float_text()
		return

	var final_amount: float = amount * ev_res.get("damage_mult", 1.0)
	var allow_slow: bool = not ev_res.get("no_slow", false)

	if AudioManager.instance:
		AudioManager.instance.play_sfx(AudioManager.instance.sfx_hit)
		
	if (is_melee or is_aoe) and allow_slow:
		_apply_hit_stun(final_amount)

	match body_part:
		Globals.BodyTarget.HEAD:
			var mult: float = Globals.get_headshot_multiplier(weight_class)
			var total_dmg: float = final_amount * mult
			if AudioManager.instance:
				AudioManager.instance.play_sfx(AudioManager.instance.sfx_headshot)
				
			if kamikaze_active:
				_die_by_headshot()
				return
				
			torso_hp -= total_dmg
			if torso_hp <= 0.0:
				_die_by_headshot()
				return

		Globals.BodyTarget.ARMS:
			if class_data and class_data.instant_explode_on_arms_loss:
				# Augur unique arms rule: No 50% threshold. Instantly explodes upon reaching 0% arms!
				arms_hp = maxf(0.0, arms_hp - final_amount)
				if arms_hp <= 0.0:
					_explode_kamikaze()
					return
			else:
				var half_hp: float = max_arms_hp * 0.5
				if arms_hp > half_hp:
					if (arms_hp - final_amount) < half_hp:
						arms_hp = half_hp # clipped to 50%!
					else:
						arms_hp -= final_amount
				else:
					arms_hp = maxf(0.0, arms_hp - final_amount)
					
				if arms_hp <= half_hp and active_slot == 1:
					active_slot = 2
					_update_dmi_states()
					emit_signal("weapon_state_changed")
				elif arms_hp <= 0.0:
					_update_dmi_states()
					emit_signal("weapon_state_changed")

		Globals.BodyTarget.LEGS:
			legs_hp = maxf(0.0, legs_hp - final_amount)

		Globals.BodyTarget.TORSO:
			torso_hp -= final_amount
			if torso_hp <= 0.0:
				if not kamikaze_active:
					_start_kamikaze()
					
	emit_signal("integrity_changed")

func apply_aoe_damage(amount: float, attacker_team: Globals.Team, attacker: Node2D = null) -> void:
	if is_dead or is_rolling:
		return
	if has_network():
		rpc("rpc_apply_aoe_damage", amount, int(attacker_team))
	else:
		_execute_apply_aoe_damage(amount, attacker_team)

func _execute_apply_aoe_damage(amount: float, attacker_team: Globals.Team) -> void:
	if is_dead or is_rolling:
		return
		
	# Evasion reduces AoE damage by 50% and prevents stun
	var ev_res: Dictionary = check_and_apply_evasion(amount, true, false, false, false, true)
	var final_amount: float = amount * ev_res.get("damage_mult", 1.0)
	var allow_slow: bool = not ev_res.get("no_slow", false)

	if allow_slow:
		_apply_hit_stun(final_amount)
	
	torso_hp -= final_amount
	var arm_dmg: float = final_amount * 0.3
	var leg_dmg: float = final_amount * 0.3

	if class_data and class_data.instant_explode_on_arms_loss:
		arms_hp = maxf(0.0, arms_hp - arm_dmg)
		if arms_hp <= 0.0:
			_explode_kamikaze()
			return
	else:
		arms_hp = maxf(0.0, arms_hp - arm_dmg)
		if arms_hp <= (max_arms_hp * 0.5) and active_slot == 1:
			active_slot = 2
			_update_dmi_states()
			emit_signal("weapon_state_changed")
		elif arms_hp <= 0.0:
			_update_dmi_states()
			emit_signal("weapon_state_changed")

	legs_hp = maxf(0.0, legs_hp - leg_dmg)

	if torso_hp <= 0.0 and not kamikaze_active:
		_start_kamikaze()
		
	emit_signal("integrity_changed")

func _apply_hit_stun(dmg: float) -> void:
	var dur: float = Globals.get_stun_duration(dmg, max_torso_hp)
	stun_timer = maxf(stun_timer, dur)

func _start_kamikaze() -> void:
	kamikaze_active = true
	kamikaze_timer = 5.0
	kamikaze_beep_timer = 0.5
	emit_signal("kamikaze_started")

func _explode_kamikaze() -> void:
	if is_dead:
		return
	is_dead = true
	var specs: Dictionary = Globals.get_kamikaze_specs(weight_class)
	var exp_node := Explosion.new()
	exp_node.global_position = global_position
	exp_node.setup(specs["damage"], specs["radius_tiles"], team, self)
	get_parent().add_child(exp_node)
	emit_signal("unit_died", self, false)
	_handle_death_cleanup()

func _die_by_headshot() -> void:
	is_dead = true
	kamikaze_active = false
	emit_signal("unit_died", self, true)
	_handle_death_cleanup()

func _handle_death_cleanup() -> void:
	if self is Bot:
		queue_free()
	else:
		visible = false
		if overlay_sprite_node:
			overlay_sprite_node.visible = false
		if overlay_left_arm_node:
			overlay_left_arm_node.visible = false
		if overlay_right_arm_node:
			overlay_right_arm_node.visible = false
		if collision_shape:
			collision_shape.set_deferred("disabled", true)

func respawn(spawn_tile: Vector2i) -> void:
	is_dead = false
	kamikaze_active = false
	visible = true
	if collision_shape:
		collision_shape.set_deferred("disabled", false)
	setup_class(class_data)
	current_tile = spawn_tile
	start_tile = spawn_tile
	target_tile = spawn_tile
	global_position = Globals.tile_to_world_center(spawn_tile)
	queue_redraw()

@rpc("any_peer", "call_local", "reliable")
func rpc_respawn(spawn_tile: Vector2i) -> void:
	respawn(spawn_tile)

# ----------------- MULTIPLAYER RPCs -----------------

@rpc("any_peer", "call_local", "reliable")
func rpc_step(start_t: Vector2i, target_t: Vector2i, dur: float) -> void:
	_execute_step(start_t, target_t, dur)

@rpc("any_peer", "call_local", "reliable")
func rpc_start_roll(dir: Vector2i) -> void:
	_execute_roll(dir)

@rpc("any_peer", "call_local", "unreliable")
func rpc_sync_aim(new_aim_angle: float) -> void:
	aim_angle = new_aim_angle

@rpc("any_peer", "call_local", "reliable")
func rpc_spawn_projectile(spawn_pos: Vector2, dir: Vector2, body_target_int: int, target_path: String, target_pos: Vector2, is_secondary: bool = false) -> void:
	var w: WeaponData = get_active_secondary_weapon() if is_secondary else get_active_primary_weapon()
	if not w:
		return
	var target_node: Node2D = get_node_or_null(target_path) as Node2D if not target_path.is_empty() else null
	_perform_hitscan(w, spawn_pos, dir, target_node, target_pos)

@rpc("any_peer", "call_remote", "unreliable")
func rpc_show_hitscan_tracer(spawn_pos: Vector2, hit_pos: Vector2, hit_normal: Vector2, hit_type_int: int, weapon_id: String, is_aoe: bool) -> void:
	if AudioManager.instance:
		if is_aoe or weapon_id == "blaster":
			AudioManager.instance.play_sfx(AudioManager.instance.sfx_aoe_shot)
		elif weapon_id == "templum":
			AudioManager.instance.play_sfx(AudioManager.instance.sfx_headshot, 4.0)
		elif weapon_id == "wagner" or weapon_id == "mk_ultra":
			AudioManager.instance.play_sfx(AudioManager.instance.sfx_rifle)
		else:
			AudioManager.instance.play_sfx(AudioManager.instance.sfx_pistol)

	_spawn_tracer_effect(spawn_pos, hit_pos, hit_normal, hit_type_int, weapon_id, is_aoe)

	if is_aoe:
		var exp_scene := preload("res://scripts/explosion.gd")
		var exp_node := Explosion.new()
		exp_node.global_position = hit_pos
		exp_node.setup(0.0, 1.0, team, null) # visual-only on remote peer
		get_parent().add_child(exp_node)

@rpc("any_peer", "call_local", "reliable")
func rpc_apply_aoe_damage(amount: float, attacker_team_int: int) -> void:
	_execute_apply_aoe_damage(amount, attacker_team_int as Globals.Team)

@rpc("any_peer", "call_local", "reliable")
func rpc_trigger_kamikaze() -> void:
	_start_kamikaze()

@rpc("any_peer", "call_remote", "unreliable")
func rpc_show_melee_slash(slash_dir: Vector2) -> void:
	melee_slash_timer = 0.16
	melee_slash_dir = slash_dir
	if AudioManager.instance:
		AudioManager.instance.play_sfx(AudioManager.instance.sfx_knife)
	queue_redraw()

# ----------------- DRAWING -----------------

func _draw() -> void:
	if is_dead:
		return
		
	# Draw melee slash visual arc if active
	if melee_slash_timer > 0.0:
		var alpha: float = clampf(melee_slash_timer / 0.16, 0.0, 1.0)
		var angle: float = melee_slash_dir.angle()
		var arc_radius: float = 34.0
		var half_arc: float = 0.75 # ~86 degrees swing
		
		# White-cyan/yellow blade slash arc
		var col_outer := Color(1.0, 1.0, 0.5, 0.95 * alpha)
		var col_inner := Color(1.0, 0.4, 0.1, 0.7 * alpha)
		draw_arc(Vector2.ZERO, arc_radius, angle - half_arc, angle + half_arc, 16, col_outer, 3.0)
		draw_arc(Vector2.ZERO, arc_radius - 6.0, angle - half_arc * 0.8, angle + half_arc * 0.8, 12, col_inner, 2.0)
		
		# Blade slash spark line
		var slash_tip := Vector2.from_angle(angle) * (arc_radius + 4.0)
		draw_line(Vector2.from_angle(angle) * 8.0, slash_tip, Color(1.0, 1.0, 1.0, alpha), 2.0)

	# Draw range ring if enabled
	if show_range_ring:
		var w: WeaponData = get_active_primary_weapon()
		if w:
			var eff_r: float = float(w.eff_range_category) * Globals.TILE_SIZE
			draw_arc(Vector2.ZERO, eff_r, 0, TAU, 32, Color(0.2, 0.9, 0.3, 0.25), 1.5)
			draw_arc(Vector2.ZERO, eff_r * 2.0, 0, TAU, 32, Color(0.2, 0.9, 0.3, 0.1), 1.0)
			
	# Kamikaze visual alarm badge
	if kamikaze_active:
		var pulse: float = sin(kamikaze_timer * 20.0) * 0.5 + 0.5
		draw_circle(Vector2(0, -22), 6.0, Color(1.0, 0.1, 0.1, 0.5 + 0.5 * pulse))
		draw_arc(Vector2(0, -22), 8.0, 0, TAU, 16, Color(1.0, 1.0, 0.2), 1.5)

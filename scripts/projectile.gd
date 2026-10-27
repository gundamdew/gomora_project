class_name Projectile
extends Node2D

var direction: Vector2 = Vector2.RIGHT
var speed: float = 1200.0
var max_range_px: float = 384.0
var weapon_ref: WeaponData
var attacker_team: Globals.Team = Globals.Team.BAAL_RED
var attacker_unit: Node2D = null
var targeted_body_part: Globals.BodyTarget = Globals.BodyTarget.TORSO
var direct_target_unit: Node2D = null # Unit clicked on, if any

var origin_pos: Vector2
var traveled_dist: float = 0.0
var target_dest: Vector2 # for AoE target position
var is_aoe: bool = false
var aoe_radius_tiles: float = 1.0

var _prev_pos: Vector2

func setup(
	start_pos: Vector2,
	dir: Vector2,
	w: WeaponData,
	team: Globals.Team,
	attacker: Node2D,
	body_target: Globals.BodyTarget,
	direct_target: Node2D = null,
	dest_pos: Vector2 = Vector2.ZERO
) -> void:
	global_position = start_pos
	origin_pos = start_pos
	_prev_pos = start_pos
	direction = dir.normalized()
	weapon_ref = w
	attacker_team = team
	attacker_unit = attacker
	targeted_body_part = body_target
	direct_target_unit = direct_target
	speed = w.projectile_speed
	max_range_px = w.max_range_tiles * Globals.TILE_SIZE
	
	if w.alt_mode_active and w.weapon_id == "wagner":
		is_aoe = true
		aoe_radius_tiles = 1.0
		target_dest = dest_pos
	else:
		is_aoe = w.is_aoe
		aoe_radius_tiles = w.aoe_radius_tiles
		target_dest = dest_pos

func _ready() -> void:
	queue_redraw()

func _physics_process(delta: float) -> void:
	_prev_pos = global_position
	var step: float = speed * delta
	
	# If AoE and target destination set, check if reached
	if is_aoe and target_dest != Vector2.ZERO:
		var dist_to_dest: float = global_position.distance_to(target_dest)
		if dist_to_dest <= step:
			global_position = target_dest
			_detonate()
			return

	global_position += direction * step
	traveled_dist += step
	
	# Raycast check between _prev_pos and global_position
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(_prev_pos, global_position)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	if attacker_unit:
		query.exclude = [attacker_unit]
		
	var result := space_state.intersect_ray(query)
	if not result.is_empty():
		_handle_collision(result)
		return

	if traveled_dist >= max_range_px:
		if is_aoe:
			_detonate()
		else:
			queue_free()
		return
		
	queue_redraw()

func _handle_collision(collision: Dictionary) -> void:
	var collider: Object = collision.get("collider")
	var hit_pos: Vector2 = collision.get("position", global_position)
	global_position = hit_pos
	
	if is_aoe:
		_detonate()
		return

	if collider and collider.has_method("apply_damage"):
		var unit: Node2D = collider as Node2D
		# Determine target body part:
		# If direct click was on this unit -> hits targeted_body_part.
		# Else -> stray bullet hits TORSO.
		var hit_part: Globals.BodyTarget = Globals.BodyTarget.TORSO
		if unit == direct_target_unit:
			hit_part = targeted_body_part
			
		var dist_px: float = origin_pos.distance_to(hit_pos)
		var eff_falloff: float = Globals.calculate_effective_falloff(dist_px, weapon_ref.eff_range_category)
		var base_dmg: float = weapon_ref.calculate_damage_against(unit.weight_class)
		var final_dmg: float = base_dmg * eff_falloff
		
		var safe_attacker: Node2D = attacker_unit if is_instance_valid(attacker_unit) else null
		unit.apply_damage(final_dmg, hit_part, attacker_team, safe_attacker, false)
		
	queue_free()

func _detonate() -> void:
	var exp_scene := preload("res://scripts/explosion.gd")
	var explosion := Explosion.new()
	explosion.global_position = global_position
	var dmg: float = weapon_ref.base_damage if weapon_ref else 50.0
	if weapon_ref and weapon_ref.alt_mode_active and weapon_ref.weapon_id == "wagner":
		dmg = 20.0
	var safe_attacker: Node2D = attacker_unit if is_instance_valid(attacker_unit) else null
	explosion.setup(dmg, aoe_radius_tiles, attacker_team, safe_attacker)
	get_parent().add_child(explosion)
	queue_free()

func _draw() -> void:
	var tail_len: float = clampf(speed * 0.03, 12.0, 30.0)
	var start_pt := -direction * tail_len
	var end_pt := Vector2.ZERO
	
	if is_aoe:
		draw_circle(Vector2.ZERO, 3.5, Color(1.0, 0.4, 0.2))
		draw_line(start_pt * 0.5, end_pt, Color(1.0, 0.7, 0.2, 0.6), 2.0)
	else:
		# Bright tracer line
		draw_line(start_pt, end_pt, Color(1.0, 0.9, 0.3, 0.9), 1.8)
		draw_circle(Vector2.ZERO, 1.8, Color(1.0, 1.0, 0.8))

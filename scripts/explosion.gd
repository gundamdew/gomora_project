class_name Explosion
extends Node2D

var damage: float = 50.0
var radius_tiles: float = 1.0
var attacker_team: Globals.Team = Globals.Team.BAAL_RED
var attacker_unit: Node2D = null

var _life_timer: float = 0.4
var _max_life: float = 0.4
var _has_damaged: bool = false
var _radius_px: float = 32.0

func setup(dmg: float, r_tiles: float, team: Globals.Team, attacker: Node2D) -> void:
	damage = dmg
	radius_tiles = r_tiles
	attacker_team = team
	attacker_unit = attacker
	_radius_px = radius_tiles * Globals.TILE_SIZE

func _ready() -> void:
	if AudioManager.instance:
		AudioManager.instance.play_sfx(AudioManager.instance.sfx_explosion, 2.0)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if not _has_damaged:
		_has_damaged = true
		_apply_aoe_damage()
		
	_life_timer -= delta
	queue_redraw()
	if _life_timer <= 0.0:
		queue_free()

func _apply_aoe_damage() -> void:
	var tree := get_tree()
	if not tree:
		return
	var units := tree.get_nodes_in_group("units")
	for u in units:
		if not is_instance_valid(u) or u.is_queued_for_deletion():
			continue
		if not u.has_method("apply_damage"):
			continue
			
		var dist_px: float = global_position.distance_to(u.global_position)
		if dist_px <= _radius_px:
			var falloff: float = Globals.calculate_aoe_falloff(dist_px, radius_tiles)
			var final_dmg: float = damage * falloff
			# AoE hits Torso 100%, and Arms & Legs 30% each
			var safe_att: Node2D = attacker_unit if is_instance_valid(attacker_unit) else null
			u.apply_aoe_damage(final_dmg, attacker_team, safe_att)

func _draw() -> void:
	var t: float = 1.0 - (_life_timer / _max_life) # 0 to 1
	var current_r: float = _radius_px * (0.3 + 0.7 * t)
	var alpha: float = 1.0 - t
	
	# Outer shockwave ring
	draw_arc(Vector2.ZERO, current_r, 0, TAU, 32, Color(1.0, 0.6, 0.2, alpha), 2.5)
	# Inner fireball
	var inner_r: float = current_r * 0.7
	draw_circle(Vector2.ZERO, inner_r, Color(1.0, 0.3, 0.1, alpha * 0.6))
	# Core flash
	if t < 0.3:
		draw_circle(Vector2.ZERO, inner_r * 0.5, Color(1.0, 1.0, 0.8, (0.3 - t) / 0.3))

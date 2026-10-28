class_name Explosion3D
extends Node3D

var damage: float = 100.0
var radius: float = 6.0
var knockback_force: float = 24.0
var attacker_team: Globals.Team = Globals.Team.BAAL_RED
var attacker_peer_id: int = 1
var attacker_node: Node3D = null

var _life_timer: float = 0.5
var _max_life: float = 0.5
var _has_damaged: bool = false

var sphere_mesh_instance: MeshInstance3D
var flash_light: OmniLight3D
var particles: CPUParticles3D

func setup(dmg: float, r: float, kb: float, team: Globals.Team, att_id: int, attacker: Node3D = null) -> void:
	damage = dmg
	radius = r
	knockback_force = kb
	attacker_team = team
	attacker_peer_id = att_id
	attacker_node = attacker

func _ready() -> void:
	_create_visuals()
	if AudioManager.instance:
		AudioManager.instance.play_sfx_3d(AudioManager.instance.sfx_rocket_explode, global_position, 3.0)

func _create_visuals() -> void:
	# 1. OmniLight3D flash
	flash_light = OmniLight3D.new()
	flash_light.light_color = Color(1.0, 0.6, 0.15)
	flash_light.light_energy = 8.0
	flash_light.omni_range = radius * 2.5
	add_child(flash_light)

	# 2. Expanding glowing shockwave sphere
	sphere_mesh_instance = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sphere_mesh_instance.mesh = sm

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.45, 0.1, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	sphere_mesh_instance.material_override = mat
	add_child(sphere_mesh_instance)

	# 3. Flying spark debris
	particles = CPUParticles3D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = 32
	particles.lifetime = 0.45
	particles.spread = 180.0
	particles.initial_velocity_min = 12.0
	particles.initial_velocity_max = 28.0
	particles.scale_amount_min = 0.12
	particles.scale_amount_max = 0.35

	var p_mat := StandardMaterial3D.new()
	p_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	p_mat.albedo_color = Color(1.0, 0.8, 0.2)
	p_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var p_box := BoxMesh.new()
	p_box.size = Vector3(0.12, 0.12, 0.25)
	p_box.material = p_mat
	particles.mesh = p_box
	add_child(particles)

func _physics_process(delta: float) -> void:
	if not _has_damaged:
		_has_damaged = true
		_apply_aoe()

	_life_timer -= delta
	var progress: float = 1.0 - (_life_timer / _max_life) # 0 -> 1

	if flash_light:
		flash_light.light_energy = lerpf(8.0, 0.0, progress)

	if sphere_mesh_instance:
		var s: float = lerpf(0.5, radius * 1.8, progress)
		sphere_mesh_instance.scale = Vector3(s, s, s)
		var mat := sphere_mesh_instance.material_override as StandardMaterial3D
		if mat:
			mat.albedo_color.a = lerpf(0.85, 0.0, progress)

	if _life_timer <= 0.0:
		queue_free()

func _apply_aoe() -> void:
	var units := get_tree().get_nodes_in_group("units")
	for u in units:
		if not is_instance_valid(u) or u.is_queued_for_deletion():
			continue
		if not (u is CharacterBody3D):
			continue
		if u.get("is_dead") == true:
			continue

		var dist: float = global_position.distance_to(u.global_position)
		if dist <= radius:
			var falloff: float = clampf(1.0 - (dist / radius), 0.15, 1.0)
			var final_dmg: float = damage * falloff

			# Direction for knockback / rocket jump!
			var to_unit: Vector3 = (u.global_position - global_position)
			var blast_dir: Vector3
			if to_unit.length_squared() < 0.001:
				blast_dir = Vector3.UP
			else:
				blast_dir = to_unit.normalized()

			# Upward boost bias for classic Quake rocket jumping!
			blast_dir.y = maxf(blast_dir.y, 0.45)
			blast_dir = blast_dir.normalized()

			var impulse: Vector3 = blast_dir * (knockback_force * (0.6 + 0.4 * falloff))

			# Self-rocket jump deals reduced self-damage in Quake style!
			var is_self: bool = (u == attacker_node or (u.get("peer_id") != null and u.peer_id == attacker_peer_id))
			if is_self:
				final_dmg *= 0.35 # Rocket jump self-damage reduction

			if u.has_method("apply_impulse"):
				u.apply_impulse(impulse)

			if u.has_method("apply_damage"):
				u.apply_damage(final_dmg, false, attacker_node)

	# Local camera shake
	var local_p: Node3D = get_tree().root.find_child("Player_Local", true, false)
	if local_p and is_instance_valid(local_p):
		var p_dist: float = global_position.distance_to(local_p.global_position)
		if p_dist < radius * 3.5:
			var shake_amt: float = (1.0 - (p_dist / (radius * 3.5))) * 0.4
			if local_p.has_method("add_camera_shake"):
				local_p.add_camera_shake(shake_amt)

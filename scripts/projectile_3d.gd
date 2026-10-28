class_name Projectile3D
extends Node3D

enum ProjectileType {
	ROCKET,
	PLASMA
}

var projectile_type: ProjectileType = ProjectileType.ROCKET
var direction: Vector3 = Vector3.FORWARD
var speed: float = 34.0
var damage: float = 100.0
var splash_radius: float = 5.5
var knockback: float = 22.0

var attacker_team: Globals.Team = Globals.Team.BAAL_RED
var attacker_peer_id: int = 1
var attacker_node: Node3D = null

var _life_timer: float = 6.0
var _prev_pos: Vector3

var mesh_inst: MeshInstance3D
var light_inst: OmniLight3D
var trail_particles: CPUParticles3D

func setup(
	start_pos: Vector3,
	dir: Vector3,
	type: ProjectileType,
	dmg: float,
	team: Globals.Team,
	att_id: int,
	attacker: Node3D = null
) -> void:
	global_position = start_pos
	_prev_pos = start_pos
	direction = dir.normalized()
	projectile_type = type
	damage = dmg
	attacker_team = team
	attacker_peer_id = att_id
	attacker_node = attacker

	if type == ProjectileType.ROCKET:
		speed = 36.0
		splash_radius = 6.0
		knockback = 24.0
	else:
		speed = 52.0
		splash_radius = 2.5
		knockback = 8.0

func _ready() -> void:
	_create_visuals()
	look_at(global_position + direction, Vector3.UP)

func _create_visuals() -> void:
	mesh_inst = MeshInstance3D.new()
	add_child(mesh_inst)

	light_inst = OmniLight3D.new()
	light_inst.light_energy = 2.5
	light_inst.omni_range = 6.0
	add_child(light_inst)

	trail_particles = CPUParticles3D.new()
	trail_particles.emitting = true
	trail_particles.lifetime = 0.35
	trail_particles.amount = 24
	trail_particles.spread = 15.0
	trail_particles.gravity = Vector3(0, 0.5, 0)
	trail_particles.initial_velocity_min = 1.0
	trail_particles.initial_velocity_max = 3.0
	trail_particles.scale_amount_min = 0.1
	trail_particles.scale_amount_max = 0.25

	if projectile_type == ProjectileType.ROCKET:
		# Chunky Quake rocket mesh: cylinder body + cone tip + 4 fins
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.12
		cyl.bottom_radius = 0.12
		cyl.height = 0.65
		mesh_inst.mesh = cyl
		mesh_inst.rotation_degrees.x = 90.0

		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.85, 0.25, 0.1)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.4, 0.05)
		mat.emission_energy_multiplier = 3.0
		mesh_inst.material_override = mat

		light_inst.light_color = Color(1.0, 0.5, 0.1)

		# Smoke & fire trail particles
		var p_mat := StandardMaterial3D.new()
		p_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		p_mat.albedo_color = Color(0.9, 0.4, 0.1, 0.7)
		p_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var p_sph := SphereMesh.new()
		p_sph.radius = 0.15
		p_sph.height = 0.3
		p_sph.material = p_mat
		trail_particles.mesh = p_sph
	else:
		# Plasma energy orb
		var sph := SphereMesh.new()
		sph.radius = 0.22
		sph.height = 0.44
		mesh_inst.mesh = sph

		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(0.2, 0.9, 1.0)
		mesh_inst.material_override = mat

		light_inst.light_color = Color(0.2, 0.8, 1.0)

		var p_mat := StandardMaterial3D.new()
		p_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		p_mat.albedo_color = Color(0.2, 0.9, 1.0, 0.6)
		p_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var p_box := BoxMesh.new()
		p_box.size = Vector3(0.1, 0.1, 0.1)
		p_box.material = p_mat
		trail_particles.mesh = p_box

	add_child(trail_particles)

func _physics_process(delta: float) -> void:
	_prev_pos = global_position
	var next_pos: Vector3 = global_position + direction * (speed * delta)

	# Continuous collision detection raycast sweep
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(_prev_pos, next_pos)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	
	# Exclude attacker to prevent immediate collision on launch
	var exclude_list: Array[RID] = []
	if is_instance_valid(attacker_node) and attacker_node is CollisionObject3D:
		exclude_list.append((attacker_node as CollisionObject3D).get_rid())
	query.exclude = exclude_list

	var result := space.intersect_ray(query)
	if not result.is_empty():
		var hit_pos: Vector3 = result.position
		var hit_collider: Object = result.collider
		_detonate(hit_pos, hit_collider)
		return

	global_position = next_pos

	_life_timer -= delta
	if _life_timer <= 0.0:
		_detonate(global_position, null)

func _detonate(hit_pos: Vector3, direct_hit: Object) -> void:
	# Direct hit extra damage
	if direct_hit and is_instance_valid(direct_hit):
		if direct_hit.has_method("apply_damage"):
			var is_headshot: bool = false
			direct_hit.apply_damage(damage * 0.4, is_headshot, attacker_node)

	# Spawn 3D Explosion
	var exp_script = load("res://scripts/explosion_3d.gd")
	if exp_script:
		var exp_node: Explosion3D = exp_script.new()
		exp_node.setup(damage, splash_radius, knockback, attacker_team, attacker_peer_id, attacker_node)
		get_parent().add_child(exp_node)
		exp_node.global_position = hit_pos

	queue_free()

class_name Tracer3D
extends Node3D

enum TracerType {
	BULLET,
	SHOTGUN,
	RAILGUN,
	PLASMA
}

var _life_timer: float = 0.2
var _max_life: float = 0.2
var tracer_type: TracerType = TracerType.BULLET

var mesh_inst: MeshInstance3D
var spiral_inst: MeshInstance3D
var spark_particles: CPUParticles3D

func setup(start_pos: Vector3, end_pos: Vector3, type: TracerType = TracerType.BULLET) -> void:
	tracer_type = type
	global_position = Vector3.ZERO

	match type:
		TracerType.RAILGUN:
			_max_life = 0.65
			_life_timer = 0.65
			_create_railgun_beam(start_pos, end_pos)
		TracerType.SHOTGUN:
			_max_life = 0.18
			_life_timer = 0.18
			_create_bullet_line(start_pos, end_pos, Color(1.0, 0.7, 0.3), 0.04)
		TracerType.PLASMA:
			_max_life = 0.22
			_life_timer = 0.22
			_create_bullet_line(start_pos, end_pos, Color(0.2, 0.8, 1.0), 0.08)
		_:
			_max_life = 0.14
			_life_timer = 0.14
			_create_bullet_line(start_pos, end_pos, Color(1.0, 0.9, 0.5), 0.03)

	_create_impact_sparks(end_pos)

func _create_bullet_line(start_pos: Vector3, end_pos: Vector3, color: Color, thickness: float) -> void:
	mesh_inst = MeshInstance3D.new()
	var im := ImmediateMesh.new()
	mesh_inst.mesh = im

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mesh_inst.material_override = mat

	im.surface_begin(Mesh.PRIMITIVE_LINES)
	im.surface_set_color(color)
	im.surface_add_vertex(start_pos)
	im.surface_set_color(color)
	im.surface_add_vertex(end_pos)
	im.surface_end()

	add_child(mesh_inst)

func _create_railgun_beam(start_pos: Vector3, end_pos: Vector3, is_red: bool = false) -> void:
	# 1. Core laser beam
	mesh_inst = MeshInstance3D.new()
	var im := ImmediateMesh.new()
	mesh_inst.mesh = im

	var beam_color := Color(0.1, 0.9, 1.0) if not is_red else Color(1.0, 0.2, 0.3)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = beam_color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mesh_inst.material_override = mat

	im.surface_begin(Mesh.PRIMITIVE_LINES)
	im.surface_set_color(Color.WHITE)
	im.surface_add_vertex(start_pos)
	im.surface_set_color(beam_color)
	im.surface_add_vertex(end_pos)
	im.surface_end()
	add_child(mesh_inst)

	# 2. Classic Quake spiral corkscrew trail around the beam!
	spiral_inst = MeshInstance3D.new()
	var sp_im := ImmediateMesh.new()
	spiral_inst.mesh = sp_im

	var sp_mat := StandardMaterial3D.new()
	sp_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sp_mat.albedo_color = Color(beam_color.r, beam_color.g, beam_color.b, 0.8)
	sp_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sp_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	spiral_inst.material_override = sp_mat

	var diff: Vector3 = end_pos - start_pos
	var dist: float = diff.length()
	if dist > 1.0:
		var dir: Vector3 = diff.normalized()
		var up := Vector3.UP if absf(dir.y) < 0.9 else Vector3.RIGHT
		var right: Vector3 = dir.cross(up).normalized()
		up = right.cross(dir).normalized()

		var turns: int = int(dist * 0.8) # Spiral frequency
		var steps: int = turns * 8
		var radius: float = 0.25

		sp_im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		for s in range(steps + 1):
			var frac: float = float(s) / float(steps)
			var angle: float = frac * float(turns) * TAU
			var center: Vector3 = start_pos + dir * (frac * dist)
			var offset: Vector3 = (right * cos(angle) + up * sin(angle)) * radius
			sp_im.surface_add_vertex(center + offset)
		sp_im.surface_end()

	add_child(spiral_inst)

func _create_impact_sparks(pos: Vector3) -> void:
	spark_particles = CPUParticles3D.new()
	spark_particles.global_position = pos
	spark_particles.emitting = true
	spark_particles.one_shot = true
	spark_particles.explosiveness = 0.95
	spark_particles.amount = 16
	spark_particles.lifetime = 0.25
	spark_particles.spread = 180.0
	spark_particles.initial_velocity_min = 4.0
	spark_particles.initial_velocity_max = 12.0
	spark_particles.scale_amount_min = 0.08
	spark_particles.scale_amount_max = 0.2

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.8, 0.3)
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var box := BoxMesh.new()
	box.size = Vector3(0.08, 0.08, 0.15)
	box.material = mat
	spark_particles.mesh = box
	add_child(spark_particles)

func _process(delta: float) -> void:
	_life_timer -= delta
	var alpha: float = clampf(_life_timer / _max_life, 0.0, 1.0)

	if mesh_inst and mesh_inst.material_override:
		(mesh_inst.material_override as StandardMaterial3D).albedo_color.a = alpha
	if spiral_inst and spiral_inst.material_override:
		(spiral_inst.material_override as StandardMaterial3D).albedo_color.a = alpha * 0.8

	if _life_timer <= 0.0:
		queue_free()

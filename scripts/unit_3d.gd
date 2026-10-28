class_name Unit3D
extends CharacterBody3D

signal integrity_changed
signal unit_died(unit: Unit3D, by_headshot: bool)
signal weapon_state_changed

@export var peer_id: int = 1
@export var team: Globals.Team = Globals.Team.BAAL_RED
@export var class_data: ClassData

var health: float = 100.0
var max_health: float = 100.0
var armor: float = 100.0
var max_armor: float = 100.0

var is_dead: bool = false
var unit_name: String = "Боец"

# Movement attributes
var move_speed: float = 11.0
var jump_velocity: float = 8.5
var gravity: float = 24.0

# Active weapon index (1: Melee, 2: Shotgun, 3: Machinegun, 4: Rocket, 5: Railgun, 6: Plasma)
var active_weapon_idx: int = 4

# Visual nodes
var visual_root: Node3D
var torso_mesh: MeshInstance3D
var head_mesh: MeshInstance3D
var visor_mesh: MeshInstance3D
var left_arm_mesh: MeshInstance3D
var right_arm_mesh: MeshInstance3D
var weapon_mesh: MeshInstance3D
var left_leg_mesh: MeshInstance3D
var right_leg_mesh: MeshInstance3D

var nameplate_label: Label3D
var collision_body: CollisionShape3D

var _flash_timer: float = 0.0
var _base_torso_mat: StandardMaterial3D
var _flash_mat: StandardMaterial3D

func _ready() -> void:
	add_to_group("units")
	_init_components()
	if class_data == null:
		class_data = ClassData.create_leech() if team == Globals.Team.BAAL_RED else ClassData.create_trooper()
	setup_class(class_data)

func setup_class(c: ClassData) -> void:
	class_data = c
	if c.weight_class == Globals.WeightClass.LIGHT:
		max_health = 100.0
		max_armor = 50.0
		move_speed = 12.5
		jump_velocity = 9.2
	elif c.weight_class == Globals.WeightClass.MEDIUM:
		max_health = 150.0
		max_armor = 100.0
		move_speed = 10.5
		jump_velocity = 8.2
	else:
		max_health = 200.0
		max_armor = 150.0
		move_speed = 9.0
		jump_velocity = 7.5

	health = max_health
	armor = max_armor
	emit_signal("integrity_changed")
	_update_nameplate()

func _init_components() -> void:
	# 1. Physics Collision Capsule
	collision_body = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.45
	cap.height = 1.8
	collision_body.shape = cap
	collision_body.position = Vector3(0, 0.9, 0)
	add_child(collision_body)

	# 2. Visual Model Root
	visual_root = Node3D.new()
	add_child(visual_root)

	_create_character_mesh()
	_create_nameplate()

func _create_character_mesh() -> void:
	var team_color: Color = Color(0.85, 0.15, 0.15) if team == Globals.Team.BAAL_RED else Color(0.15, 0.35, 0.9)
	var glow_color: Color = Color(1.0, 0.6, 0.1) if team == Globals.Team.BAAL_RED else Color(0.2, 0.8, 1.0)

	_base_torso_mat = StandardMaterial3D.new()
	_base_torso_mat.albedo_color = team_color
	_base_torso_mat.roughness = 0.4
	_base_torso_mat.metallic = 0.6

	_flash_mat = StandardMaterial3D.new()
	_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash_mat.albedo_color = Color(1.0, 1.0, 1.0)

	var dark_metal := StandardMaterial3D.new()
	dark_metal.albedo_color = Color(0.15, 0.16, 0.18)
	dark_metal.roughness = 0.5
	dark_metal.metallic = 0.8

	var visor_mat := StandardMaterial3D.new()
	visor_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	visor_mat.albedo_color = glow_color

	# Torso
	torso_mesh = MeshInstance3D.new()
	var t_box := BoxMesh.new()
	t_box.size = Vector3(0.65, 0.75, 0.4)
	torso_mesh.mesh = t_box
	torso_mesh.position = Vector3(0, 1.05, 0)
	torso_mesh.material_override = _base_torso_mat
	visual_root.add_child(torso_mesh)

	# Head
	head_mesh = MeshInstance3D.new()
	var h_box := BoxMesh.new()
	h_box.size = Vector3(0.38, 0.38, 0.38)
	head_mesh.mesh = h_box
	head_mesh.position = Vector3(0, 1.62, 0)
	head_mesh.material_override = dark_metal
	visual_root.add_child(head_mesh)

	# Glowing Visor
	visor_mesh = MeshInstance3D.new()
	var v_box := BoxMesh.new()
	v_box.size = Vector3(0.3, 0.1, 0.08)
	visor_mesh.mesh = v_box
	visor_mesh.position = Vector3(0, 1.63, -0.2)
	visor_mesh.material_override = visor_mat
	visual_root.add_child(visor_mesh)

	# Arms
	left_arm_mesh = MeshInstance3D.new()
	var a_box := BoxMesh.new()
	a_box.size = Vector3(0.2, 0.65, 0.2)
	left_arm_mesh.mesh = a_box
	left_arm_mesh.position = Vector3(-0.45, 1.05, 0)
	left_arm_mesh.material_override = dark_metal
	visual_root.add_child(left_arm_mesh)

	right_arm_mesh = MeshInstance3D.new()
	right_arm_mesh.mesh = a_box
	right_arm_mesh.position = Vector3(0.45, 1.05, -0.2)
	right_arm_mesh.material_override = dark_metal
	visual_root.add_child(right_arm_mesh)

	# Weapon in hands
	weapon_mesh = MeshInstance3D.new()
	var w_cyl := CylinderMesh.new()
	w_cyl.top_radius = 0.08
	w_cyl.bottom_radius = 0.08
	w_cyl.height = 0.7
	weapon_mesh.mesh = w_cyl
	weapon_mesh.rotation_degrees.x = 90.0
	weapon_mesh.position = Vector3(0.35, 0.95, -0.45)
	weapon_mesh.material_override = dark_metal
	visual_root.add_child(weapon_mesh)

	# Legs
	var l_box := BoxMesh.new()
	l_box.size = Vector3(0.24, 0.7, 0.24)

	left_leg_mesh = MeshInstance3D.new()
	left_leg_mesh.mesh = l_box
	left_leg_mesh.position = Vector3(-0.2, 0.35, 0)
	left_leg_mesh.material_override = dark_metal
	visual_root.add_child(left_leg_mesh)

	right_leg_mesh = MeshInstance3D.new()
	right_leg_mesh.mesh = l_box
	right_leg_mesh.position = Vector3(0.2, 0.35, 0)
	right_leg_mesh.material_override = dark_metal
	visual_root.add_child(right_leg_mesh)

func _create_nameplate() -> void:
	nameplate_label = Label3D.new()
	nameplate_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	nameplate_label.position = Vector3(0, 2.15, 0)
	nameplate_label.font_size = 28
	nameplate_label.outline_size = 8
	nameplate_label.modulate = Color(1.0, 0.4, 0.4) if team == Globals.Team.BAAL_RED else Color(0.4, 0.7, 1.0)
	add_child(nameplate_label)
	_update_nameplate()

func _update_nameplate() -> void:
	if not nameplate_label:
		return
	var team_tag := "[БААЛ]" if team == Globals.Team.BAAL_RED else "[МОЛОХ]"
	nameplate_label.text = "%s %s\nHP: %d | AP: %d" % [team_tag, unit_name, int(health), int(armor)]

func apply_impulse(impulse: Vector3) -> void:
	velocity += impulse

func apply_damage(amount: float, is_headshot: bool = false, attacker: Node3D = null) -> void:
	if is_dead:
		return

	var final_amount: float = amount
	if is_headshot:
		final_amount *= 2.0
		if AudioManager.instance:
			AudioManager.instance.play_sfx(AudioManager.instance.sfx_headshot, 1.5)

	# Quake Armor absorption formula: 66% absorbed by armor, 34% by health
	if armor > 0.0:
		var absorbed: float = minf(final_amount * 0.66, armor)
		armor -= absorbed
		var health_dmg: float = final_amount - absorbed
		health -= health_dmg
	else:
		health -= final_amount

	# Trigger visual hit flash
	_flash_timer = 0.1
	if torso_mesh:
		torso_mesh.material_override = _flash_mat

	# Play hit confirmation for local player if attacker is local
	var my_id: int = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	if attacker and attacker.get("peer_id") == my_id:
		if AudioManager.instance:
			AudioManager.instance.play_sfx(AudioManager.instance.sfx_hitsound, 1.5)

	_update_nameplate()
	emit_signal("integrity_changed")

	if health <= 0.0:
		health = 0.0
		die(is_headshot, attacker)

func die(by_headshot: bool, attacker: Node3D = null) -> void:
	if is_dead:
		return
	is_dead = true

	# Play frag sound if attacker was local player
	var my_id: int = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	if attacker and attacker.get("peer_id") == my_id:
		if AudioManager.instance:
			AudioManager.instance.play_sfx(AudioManager.instance.sfx_frag, 2.0)

	emit_signal("unit_died", self, by_headshot)
	_spawn_death_gibs()
	queue_free()

func _spawn_death_gibs() -> void:
	# Quake-style 3D flying mechanical gibs
	var gibs_parent := get_parent()
	if not gibs_parent:
		return

	var colors: Array[Color] = [
		Color(0.8, 0.2, 0.1), Color(0.2, 0.2, 0.2), Color(0.9, 0.5, 0.1)
	]

	for i in range(8):
		var gib := RigidBody3D.new()
		gib.position = global_position + Vector3(randf_range(-0.3, 0.3), randf_range(0.3, 1.5), randf_range(-0.3, 0.3))

		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.25, 0.25, 0.25)
		col.shape = box
		gib.add_child(col)

		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.25, 0.25, 0.25)
		mi.mesh = bm

		var mat := StandardMaterial3D.new()
		mat.albedo_color = colors[i % colors.size()]
		mi.material_override = mat
		gib.add_child(mi)

		gibs_parent.add_child(gib)
		var rand_impulse := Vector3(randf_range(-8, 8), randf_range(6, 16), randf_range(-8, 8))
		gib.apply_central_impulse(rand_impulse)
		gib.apply_torque_impulse(Vector3(randf_range(-10, 10), randf_range(-10, 10), randf_range(-10, 10)))

		# Auto-cleanup gibs after 3.5s
		var tree := get_tree()
		if tree:
			tree.create_timer(3.5).timeout.connect(gib.queue_free)

func _physics_process(delta: float) -> void:
	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0 and torso_mesh:
			torso_mesh.material_override = _base_torso_mat

	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	move_and_slide()

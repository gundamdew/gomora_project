class_name TracerEffect
extends Node2D

enum HitType {
	AIR,
	WALL,
	UNIT,
	AOE
}

var start_pos: Vector2 = Vector2.ZERO
var end_pos: Vector2 = Vector2.ZERO
var hit_normal: Vector2 = Vector2.UP
var hit_type: HitType = HitType.AIR

var color_glow: Color = Color(1.0, 0.85, 0.35, 0.85)
var color_core: Color = Color(1.0, 1.0, 0.95, 1.0)
var line_width: float = 3.0

var duration: float = 0.09
var timer: float = 0.09

var _sparks: Array[Vector2] = []

func setup(
	p_start: Vector2,
	p_end: Vector2,
	p_normal: Vector2 = Vector2.ZERO,
	p_type: int = 0,
	weapon_id: String = "",
	is_aoe: bool = false
) -> void:
	start_pos = p_start
	end_pos = p_end
	hit_normal = p_normal.normalized() if p_normal != Vector2.ZERO else (p_start - p_end).normalized()
	hit_type = p_type as HitType
	duration = 0.09
	timer = 0.09
	z_index = 10
	top_level = true
	position = Vector2.ZERO

	# Palette & line thickness according to weapon archetype
	if is_aoe:
		color_glow = Color(1.0, 0.42, 0.12, 0.95)
		color_core = Color(1.0, 0.92, 0.65, 1.0)
		line_width = 4.2
	elif weapon_id == "wagner":
		color_glow = Color(1.0, 0.78, 0.22, 0.9)
		color_core = Color(1.0, 1.0, 0.92, 1.0)
		line_width = 3.2
	elif weapon_id == "sudan":
		color_glow = Color(1.0, 0.68, 0.18, 0.9)
		color_core = Color(1.0, 0.98, 0.88, 1.0)
		line_width = 3.0
	elif weapon_id == "templum":
		# Heavy sniper laser / railgun beam
		color_glow = Color(0.25, 0.85, 1.0, 0.95) # Cyan high-energy plasma
		color_core = Color(0.92, 1.0, 1.0, 1.0)
		line_width = 4.8
		duration = 0.16
		timer = 0.16
	elif weapon_id == "blaster":
		# Heavy sawed-off shotgun blast
		color_glow = Color(1.0, 0.38, 0.12, 0.95) # Fiery orange-red
		color_core = Color(1.0, 0.92, 0.55, 1.0)
		line_width = 4.2
	elif weapon_id == "ghetta":
		# Fast SMG tracer
		color_glow = Color(1.0, 0.78, 0.22, 0.85)
		color_core = Color(1.0, 1.0, 0.92, 1.0)
		line_width = 2.4
	elif weapon_id == "mk_ultra":
		color_glow = Color(0.95, 0.88, 0.35, 0.85)
		color_core = Color(1.0, 1.0, 0.95, 1.0)
		line_width = 2.6
	else: # tribunal, etc.
		color_glow = Color(1.0, 0.85, 0.35, 0.85)
		color_core = Color(1.0, 1.0, 0.95, 1.0)
		line_width = 2.4

	# Generate random impact spark velocities
	_sparks.clear()
	if hit_type == HitType.WALL or hit_type == HitType.UNIT or hit_type == HitType.AOE:
		var spark_count := 6 if hit_type != HitType.AOE else 8
		for _i in range(spark_count):
			var spread := randf_range(-PI * 0.42, PI * 0.42)
			var s_dir := hit_normal.rotated(spread)
			var s_len := randf_range(8.0, 18.0)
			_sparks.append(s_dir * s_len)

func _ready() -> void:
	queue_redraw()

func _process(delta: float) -> void:
	timer -= delta
	if timer <= 0.0:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var prog: float = clampf(1.0 - (timer / duration), 0.0, 1.0)
	var alpha: float = clampf(1.0 - prog * prog, 0.0, 1.0)

	# Dynamic tracer motion: tail accelerates from muzzle towards impact point
	var cur_start: Vector2 = start_pos.lerp(end_pos, pow(prog, 1.5))
	var cur_end: Vector2 = end_pos

	var cur_glow := Color(color_glow.r, color_glow.g, color_glow.b, color_glow.a * alpha)
	var cur_core := Color(color_core.r, color_core.g, color_core.b, color_core.a * alpha)
	var cur_w: float = maxf(1.0, line_width * (1.0 - prog * 0.45))

	# 1. Outer beam glow
	draw_line(cur_start, cur_end, cur_glow, cur_w)
	# 2. Inner bright beam core
	draw_line(cur_start, cur_end, cur_core, maxf(1.0, cur_w * 0.45))

	# 3. Muzzle flash (at muzzle, fast fade out)
	if prog < 0.45:
		var m_f: float = 1.0 - (prog / 0.45)
		draw_circle(start_pos, 4.8 * m_f, Color(1.0, 1.0, 0.8, m_f * 0.9))
		draw_circle(start_pos, 2.2 * m_f, Color(1.0, 1.0, 1.0, m_f))

	# 4. Impact effects
	match hit_type:
		HitType.UNIT:
			# Blood / flesh impact burst
			var blood_col := Color(0.92, 0.15, 0.15, alpha)
			draw_circle(end_pos, 3.2 * (1.0 - prog), blood_col)
			for sp in _sparks:
				var sp_tip: Vector2 = end_pos + sp * pow(prog, 0.65)
				draw_line(end_pos, sp_tip, blood_col, 1.6)
		HitType.WALL:
			# Concrete / metal ricochet spark burst
			var spark_col := Color(1.0, 0.88, 0.35, alpha)
			draw_circle(end_pos, 2.8 * (1.0 - prog), Color(1.0, 1.0, 0.95, alpha))
			for sp in _sparks:
				var sp_tip: Vector2 = end_pos + sp * pow(prog, 0.65)
				draw_line(end_pos, sp_tip, spark_col, 1.6)
		HitType.AOE:
			# Fiery expansion ring & flash
			draw_circle(end_pos, 7.0 * (1.0 - prog), Color(1.0, 0.55, 0.15, alpha * 0.85))
			for sp in _sparks:
				var sp_tip: Vector2 = end_pos + sp * pow(prog, 0.65)
				draw_line(end_pos, sp_tip, Color(1.0, 0.45, 0.1, alpha), 2.0)
		HitType.AIR:
			# Dissipating tip
			draw_circle(end_pos, 1.8 * (1.0 - prog), cur_core)

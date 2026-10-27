class_name CaptureZone
extends Area2D

signal zone_captured(zone: CaptureZone)

@export var zone_name: String = "A"
@export var is_active: bool = false
@export var capture_radius_px: float = 80.0

var capture_progress: float = 0.0 # 0.0 to 100.0
var is_captured: bool = false
var collision_shape: CollisionShape2D

func _ready() -> void:
	collision_shape = CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = capture_radius_px
	collision_shape.shape = circle
	add_child(collision_shape)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if not is_active or is_captured:
		queue_redraw()
		return
		
	# In multiplayer, only server calculates zone capture
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		queue_redraw()
		return

	var bodies := get_overlapping_bodies()
	var red_count: int = 0
	var blue_count: int = 0
	
	for b in bodies:
		if b is Unit and not b.is_dead:
			if b.team == Globals.Team.BAAL_RED:
				red_count += 1
			elif b.team == Globals.Team.MOLOCH_BLUE:
				blue_count += 1
				
	var net_attackers: int = red_count - blue_count
	if net_attackers > 0:
		capture_progress += net_attackers * 12.0 * delta # captures in ~8 sec with 1 net attacker
		if capture_progress >= 100.0:
			capture_progress = 100.0
			is_captured = true
			if AudioManager.instance:
				AudioManager.instance.play_sfx(AudioManager.instance.sfx_capture)
			emit_signal("zone_captured", self)
	elif net_attackers < 0:
		capture_progress = maxf(0.0, capture_progress - 15.0 * delta)
		
	queue_redraw()

@rpc("authority", "call_remote", "unreliable")
func rpc_sync_zone(prog: float, captured: bool, active: bool) -> void:
	capture_progress = prog
	is_captured = captured
	is_active = active
	queue_redraw()

func _draw() -> void:
	var col_ring: Color = Color(0.4, 0.4, 0.4, 0.3)
	if is_captured:
		col_ring = Color(0.9, 0.2, 0.2, 0.7) # Red captured
	elif is_active:
		col_ring = Color(0.9, 0.7, 0.2, 0.6) # Active / contested
		
	# Outer border
	draw_arc(Vector2.ZERO, capture_radius_px, 0, TAU, 48, col_ring, 2.5)
	
	# Fill progress
	if is_active and not is_captured and capture_progress > 0.0:
		var sweep_angle: float = (capture_progress / 100.0) * TAU
		draw_arc(Vector2.ZERO, capture_radius_px - 4.0, -PI/2.0, -PI/2.0 + sweep_angle, 32, Color(0.9, 0.2, 0.2, 0.9), 4.0)
		draw_circle(Vector2.ZERO, capture_radius_px * 0.9, Color(0.9, 0.2, 0.2, 0.15 * (capture_progress / 100.0)))
	elif is_captured:
		draw_circle(Vector2.ZERO, capture_radius_px * 0.9, Color(0.9, 0.2, 0.2, 0.2))

	# Draw Letter A, B, or C
	var font := ThemeDB.fallback_font
	if font:
		var txt := "SECTOR " + zone_name
		draw_string(font, Vector2(-28, 4), txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color.WHITE)

class_name Globals
extends RefCounted

enum Team {
	BAAL_RED,      ## Army of Baal (Attackers)
	MOLOCH_BLUE    ## Army of Moloch (Defenders)
}

enum WeightClass {
	LIGHT,
	MEDIUM,
	HEAVY
}

enum BodyTarget {
	HEAD,
	ARMS,
	LEGS,
	TORSO
}

enum RangeCategory {
	POINT_BLANK = 2,  ## 2 tiles (64 px)
	CLOSE = 4,        ## 4 tiles (128 px)
	MEDIUM = 6,       ## 6 tiles (192 px)
	FAR = 8,          ## 8 tiles (256 px)
	SNIPER = 10       ## 10 tiles (320 px)
}

const TILE_SIZE: float = 32.0
const MAP_TILES: int = 100
const MAP_PX: float = 3200.0
const VIEW_TILES: int = 15
const VIEW_PX: float = 480.0

static func world_to_tile(pos: Vector2) -> Vector2i:
	return Vector2i(int(floor(pos.x / TILE_SIZE)), int(floor(pos.y / TILE_SIZE)))

static func tile_to_world_center(t: Vector2i) -> Vector2:
	return Vector2(float(t.x) * TILE_SIZE + 16.0, float(t.y) * TILE_SIZE + 16.0)

static func delay_to_step_time(delay: float) -> float:
	return clampf(delay * 0.033, 0.1, 1.2)

static func get_stun_delay_penalty(weight_class: WeightClass) -> float:
	match weight_class:
		WeightClass.LIGHT:
			return 3.0 # +3 delay for light classes
		WeightClass.MEDIUM:
			return 2.0 # +2 delay for medium classes
		WeightClass.HEAVY:
			return 1.5
	return 2.0

static func get_effective_range_distance(eff_range_tiles: int) -> float:
	return float(eff_range_tiles) * TILE_SIZE

static func calculate_effective_falloff(dist_px: float, eff_range_tiles: int) -> float:
	var eff_px: float = float(eff_range_tiles) * TILE_SIZE
	if dist_px <= eff_px:
		return 1.0
	var double_eff_px: float = eff_px * 2.0
	if dist_px >= double_eff_px:
		return 0.7
	var ratio: float = (dist_px - eff_px) / eff_px
	return 1.0 - (0.3 * ratio)

static func calculate_aoe_falloff(dist_px: float, radius_tiles: float) -> float:
	var dist_tiles: float = dist_px / TILE_SIZE
	if radius_tiles <= 1.0 or dist_tiles <= 1.0:
		return 1.0
	if dist_tiles >= radius_tiles:
		return 0.3
	var factor: float = 1.0 - 0.7 * ((dist_tiles - 1.0) / (radius_tiles - 1.0))
	return clampf(factor, 0.3, 1.0)

static func get_headshot_multiplier(weight_class: WeightClass) -> float:
	match weight_class:
		WeightClass.LIGHT:
			return 1.5
		WeightClass.MEDIUM:
			return 1.35
		WeightClass.HEAVY:
			return 1.2
	return 1.3

static func get_kamikaze_specs(weight_class: WeightClass) -> Dictionary:
	match weight_class:
		WeightClass.LIGHT:
			return {"damage": 50.0, "radius_tiles": 1.0}
		WeightClass.MEDIUM:
			return {"damage": 100.0, "radius_tiles": 2.0}
		WeightClass.HEAVY:
			return {"damage": 250.0, "radius_tiles": 3.0}
	return {"damage": 100.0, "radius_tiles": 2.0}

static func get_stun_duration(damage: float, max_torso_hp: float) -> float:
	if max_torso_hp <= 0.0:
		return 0.5
	return clampf((damage / max_torso_hp) * 5.0, 0.1, 5.0)

static func get_stun_slow_factor(weight_class: WeightClass) -> float:
	# Light delay increased by +3, medium by +2
	match weight_class:
		WeightClass.LIGHT:
			return 0.55  # ~45% slow
		WeightClass.MEDIUM:
			return 0.70  # ~30% slow
		WeightClass.HEAVY:
			return 0.85
	return 0.7

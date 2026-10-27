class_name WeaponData
extends Resource

enum WeaponType {
	TWO_HANDED,
	ONE_HANDED,
	MELEE
}

@export var weapon_id: String = ""
@export var display_name: String = ""
@export var weapon_type: WeaponType = WeaponType.TWO_HANDED
@export var base_damage: float = 20.0
@export var light_mult_or_override: float = 0.0 # if > 0, specific damage to light
@export var medium_mult_or_override: float = 0.0 # if > 0, specific damage to medium
@export var heavy_mult_or_override: float = 0.0 # if > 0, specific damage to heavy
@export var fire_delay: float = 0.3
@export var magazine_size: int = 10
@export var reload_time: float = 2.5
@export var is_automatic: bool = false
@export var is_aoe: bool = false
@export var aoe_radius_tiles: float = 1.0
@export var is_piercing: bool = false # Templum extra: penetrates through units except heavy
@export var has_spread: bool = false # Blaster extra: damages evasion targets for 0.5x
@export var eff_range_category: Globals.RangeCategory = Globals.RangeCategory.CLOSE
@export var max_range_tiles: float = 12.0
@export var projectile_speed: float = 1200.0 # high speed for tracer, slow for rockets

# Dynamic state when equipped
var current_ammo: int = 10
var reload_timer: float = 0.0
var is_reloading: bool = false
var fire_cooldown: float = 0.0
var alt_mode_active: bool = false # used for Wagner AoE mode or Mk.Ultra mode

func clone() -> WeaponData:
	var w: WeaponData = WeaponData.new()
	w.weapon_id = weapon_id
	w.display_name = display_name
	w.weapon_type = weapon_type
	w.base_damage = base_damage
	w.light_mult_or_override = light_mult_or_override
	w.medium_mult_or_override = medium_mult_or_override
	w.heavy_mult_or_override = heavy_mult_or_override
	w.fire_delay = fire_delay
	w.magazine_size = magazine_size
	w.reload_time = reload_time
	w.is_automatic = is_automatic
	w.is_aoe = is_aoe
	w.aoe_radius_tiles = aoe_radius_tiles
	w.is_piercing = is_piercing
	w.has_spread = has_spread
	w.eff_range_category = eff_range_category
	w.max_range_tiles = max_range_tiles
	w.projectile_speed = projectile_speed
	w.current_ammo = magazine_size
	return w

func calculate_damage_against(target_class: Globals.WeightClass) -> float:
	var dmg: float = base_damage
	if alt_mode_active and weapon_id == "wagner":
		return 20.0 # Wagner AoE flat 20
	if target_class == Globals.WeightClass.LIGHT and light_mult_or_override > 0.0:
		dmg = light_mult_or_override
	elif target_class == Globals.WeightClass.MEDIUM and medium_mult_or_override > 0.0:
		dmg = medium_mult_or_override
	elif target_class == Globals.WeightClass.HEAVY and heavy_mult_or_override > 0.0:
		dmg = heavy_mult_or_override
	return dmg

static func create_mk_ultra() -> WeaponData:
	var w := WeaponData.new()
	w.weapon_id = "mk_ultra"
	w.display_name = "Винтовка Mk.Ultra"
	w.weapon_type = WeaponType.TWO_HANDED
	w.base_damage = 15.0
	w.heavy_mult_or_override = 6.0
	w.fire_delay = 0.2
	w.magazine_size = 30
	w.reload_time = 3.0
	w.is_automatic = true
	w.eff_range_category = Globals.RangeCategory.MEDIUM
	w.max_range_tiles = 12.0
	w.current_ammo = 30
	return w

static func create_tribunal() -> WeaponData:
	var w := WeaponData.new()
	w.weapon_id = "tribunal"
	w.display_name = "Пистолет Tribunal"
	w.weapon_type = WeaponType.ONE_HANDED
	w.base_damage = 10.0
	w.heavy_mult_or_override = 3.0
	w.fire_delay = 0.3
	w.magazine_size = 8
	w.reload_time = 2.0
	w.is_automatic = false
	w.eff_range_category = Globals.RangeCategory.CLOSE
	w.max_range_tiles = 8.0
	w.current_ammo = 8
	return w

static func create_wagner() -> WeaponData:
	var w := WeaponData.new()
	w.weapon_id = "wagner"
	w.display_name = "Карабин Wagner"
	w.weapon_type = WeaponType.TWO_HANDED
	w.base_damage = 30.0
	w.light_mult_or_override = 40.0
	w.fire_delay = 0.5
	w.magazine_size = 12
	w.reload_time = 3.0
	w.is_automatic = false
	w.eff_range_category = Globals.RangeCategory.MEDIUM
	w.max_range_tiles = 12.0
	w.current_ammo = 12
	return w

static func create_sudan() -> WeaponData:
	var w := WeaponData.new()
	w.weapon_id = "sudan"
	w.display_name = "Пистолет Sudan"
	w.weapon_type = WeaponType.ONE_HANDED
	w.base_damage = 20.0
	w.fire_delay = 0.5
	w.magazine_size = 6
	w.reload_time = 2.0
	w.is_automatic = false
	w.eff_range_category = Globals.RangeCategory.CLOSE
	w.max_range_tiles = 8.0
	w.current_ammo = 6
	return w

static func create_fatwa() -> WeaponData:
	var w := WeaponData.new()
	w.weapon_id = "fatwa"
	w.display_name = "Боевой нож Fatwa"
	w.weapon_type = WeaponType.MELEE
	w.base_damage = 40.0
	w.fire_delay = 0.35
	w.magazine_size = 999
	w.reload_time = 0.0
	w.is_automatic = false
	w.eff_range_category = Globals.RangeCategory.POINT_BLANK
	w.max_range_tiles = 1.6 # ~51.2 px melee reach
	w.current_ammo = 999
	return w

# -------------------------------------------------------------
# СПЕЦИАЛИСТ: РАПТОР (RAPTOR) ОРУЖИЕ
# -------------------------------------------------------------
static func create_ghetta() -> WeaponData:
	var w := WeaponData.new()
	w.weapon_id = "ghetta"
	w.display_name = "ПП Ghetta"
	w.weapon_type = WeaponType.ONE_HANDED
	w.base_damage = 10.0
	w.heavy_mult_or_override = 3.0 # УРОН 10 (3 Тяж)
	w.fire_delay = 0.15 # 0.15с
	w.magazine_size = 20 # МАГ 20
	w.reload_time = 2.5 # РЕЛОАД 2.5с
	w.is_automatic = true # Автомат
	w.eff_range_category = Globals.RangeCategory.CLOSE # Ближняя (4 тайла)
	w.max_range_tiles = 8.0
	w.current_ammo = 20
	return w

static func create_cossack() -> WeaponData:
	var w := WeaponData.new()
	w.weapon_id = "cossack"
	w.display_name = "Клинок Cossack"
	w.weapon_type = WeaponType.MELEE
	w.base_damage = 40.0
	w.heavy_mult_or_override = 20.0 # УРОН 40 (20 Тяж)
	w.fire_delay = 0.7 # ДЕЛЕЙ 0.7с
	w.magazine_size = 999
	w.reload_time = 0.0
	w.is_automatic = false
	w.eff_range_category = Globals.RangeCategory.POINT_BLANK
	w.max_range_tiles = 1.6 # Соседние тайлы
	w.current_ammo = 999
	return w

# -------------------------------------------------------------
# СПЕЦИАЛИСТ: АВГУР (AUGUR) ОРУЖИЕ
# -------------------------------------------------------------
static func create_templum() -> WeaponData:
	var w := WeaponData.new()
	w.weapon_id = "templum"
	w.display_name = "Пушка Templum"
	w.weapon_type = WeaponType.ONE_HANDED
	w.base_damage = 100.0 # УРОН 100
	w.fire_delay = 3.0 # ДЕЛЕЙ 3с
	w.magazine_size = 1 # МАГ - (одиночный мощный выстрел с перезарядкой/кулдауном 3с)
	w.reload_time = 0.0
	w.is_automatic = false
	w.is_piercing = true # ЭКСТРА: Сквозное (пробивает сквозь юнитов кроме тяжелых)
	w.eff_range_category = Globals.RangeCategory.SNIPER # Снайперская (10 тайлов)
	w.max_range_tiles = 16.0
	w.current_ammo = 1
	return w

static func create_blaster() -> WeaponData:
	var w := WeaponData.new()
	w.weapon_id = "blaster"
	w.display_name = "Обрез Blaster"
	w.weapon_type = WeaponType.ONE_HANDED
	w.base_damage = 40.0 # УРОН 40
	w.medium_mult_or_override = 20.0 # (20 Сред)
	w.heavy_mult_or_override = 10.0 # (10 Тяж)
	w.fire_delay = 0.1 # ДЕЛЕЙ 0.1с
	w.magazine_size = 2 # МАГ 2
	w.reload_time = 1.5 # РЕЛОАД 1.5с
	w.is_automatic = false
	w.has_spread = true # ЭКСТРА: Разброс (0.5х урон по уклонению)
	w.eff_range_category = Globals.RangeCategory.POINT_BLANK # В упор (2 тайла)
	w.max_range_tiles = 6.0
	w.current_ammo = 2
	return w

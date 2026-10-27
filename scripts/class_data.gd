class_name ClassData
extends Resource

@export var class_id: String = ""
@export var display_name: String = ""
@export var weight_class: Globals.WeightClass = Globals.WeightClass.LIGHT

@export var max_torso_hp: float = 100.0
@export var max_arms_hp: float = 60.0
@export var max_legs_hp: float = 60.0

@export var base_move_delay: float = 6.0 # 6 for Leech (sprint), 8 for Trooper (walk)
@export var has_dodge_roll: bool = false
@export var roll_tiles: int = 3 # tiles covered in roll
@export var roll_cooldown: float = 1.0

# Specialist traits
@export var max_evasion: float = 0.0 # Raptor: 15
@export var has_deathvision: bool = false # Raptor & Augur: thermal view through storm
@export var has_cloak: bool = false # Augur: hidden from deathvision
@export var instant_explode_on_arms_loss: bool = false # Augur: arms 0% -> instant explosion

static func create_leech() -> ClassData:
	var c := ClassData.new()
	c.class_id = "leech"
	c.display_name = "Пиявка (Leech)"
	c.weight_class = Globals.WeightClass.LIGHT
	c.max_torso_hp = 100.0
	c.max_arms_hp = 60.0
	c.max_legs_hp = 60.0
	c.base_move_delay = 6.0 # Задержка движения 6 (эквивалент спринта на Ашане)
	c.has_dodge_roll = true
	c.roll_tiles = 3
	c.roll_cooldown = 1.0
	return c

static func create_trooper() -> ClassData:
	var c := ClassData.new()
	c.class_id = "trooper"
	c.display_name = "Десантник (Trooper)"
	c.weight_class = Globals.WeightClass.MEDIUM
	c.max_torso_hp = 200.0
	c.max_arms_hp = 150.0
	c.max_legs_hp = 100.0
	c.base_move_delay = 8.0 # Задержка движения 8 (эквивалент ходьбы на Ашане)
	c.has_dodge_roll = false
	return c

# -------------------------------------------------------------
# СПЕЦИАЛИСТ-КОММАНДОС: РАПТОР (RAPTOR)
# ПРОЧНОСТЬ: Туловище 80 / Конечности 50
# ЗАДЕРЖКА ДВИЖЕНИЯ: 5
# ЭКСТРА: Уклонение 15, Смертовизор, Перекат
# СЛОТ 1: Комбо одноручных (ПП Ghetta / Клинок Cossack)
# -------------------------------------------------------------
static func create_raptor() -> ClassData:
	var c := ClassData.new()
	c.class_id = "raptor"
	c.display_name = "Раптор (Raptor)"
	c.weight_class = Globals.WeightClass.LIGHT
	c.max_torso_hp = 80.0
	c.max_arms_hp = 50.0
	c.max_legs_hp = 50.0
	c.base_move_delay = 5.0 # Задержка 5 (высокая маневренность)
	c.has_dodge_roll = true
	c.roll_tiles = 3
	c.roll_cooldown = 1.0
	c.max_evasion = 15.0 # Показатель Уклонения 15
	c.has_deathvision = true # Смертовизор (видит тепловые сигнатуры сквозь бурю)
	c.has_cloak = false
	c.instant_explode_on_arms_loss = false
	return c

# -------------------------------------------------------------
# СПЕЦИАЛИСТ-СНАЙПЕР: АВГУР (AUGUR)
# ПРОЧНОСТЬ: Туловище 100 / Руки 40 / Ноги 60
# ЗАДЕРЖКА ДВИЖЕНИЯ: 7
# ЭКСТРА: Смертовизор, Покров
# СЛОТ 1: Пушка Templum в правой руке / Обрез Blaster в левой руке
# ОСОБОЕ: Снижение Прочности рук не имеет ни 50%-го порога,
# ни каких-либо последствий вплоть до полного обнуления, при котором
# юнит мгновенно детонирует как камикадзе, но без задержки.
# -------------------------------------------------------------
static func create_augur() -> ClassData:
	var c := ClassData.new()
	c.class_id = "augur"
	c.display_name = "Авгур (Augur)"
	c.weight_class = Globals.WeightClass.LIGHT
	c.max_torso_hp = 100.0
	c.max_arms_hp = 40.0
	c.max_legs_hp = 60.0
	c.base_move_delay = 7.0
	c.has_dodge_roll = false
	c.max_evasion = 0.0
	c.has_deathvision = true # Смертовизор
	c.has_cloak = true # Покров (скрыт от чужих Смертовизоров)
	c.instant_explode_on_arms_loss = true # Взрыв при потере рук!
	return c

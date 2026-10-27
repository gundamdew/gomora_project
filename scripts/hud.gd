class_name HUD
extends CanvasLayer

var player_ref: Player

# UI Elements
var root: Control

# Left Panel Elements
var left_panel: PanelContainer
var lbl_title_hud: Label
var lbl_timer: Label
var lbl_team: Label
var lbl_sectors: Label
var lbl_class_title: Label

var evasion_box: HBoxContainer
var evasion_bar: ProgressBar
var lbl_evasion_val: Label

var torso_bar: ProgressBar
var lbl_torso_val: Label
var arms_bar: ProgressBar
var lbl_arms_val: Label
var legs_bar: ProgressBar
var lbl_legs_val: Label
var lbl_delay: Label

var lbl_target: Label
var btn_target_head: Button
var btn_target_arms: Button
var btn_target_legs: Button
var btn_target_torso: Button

var lbl_weapon: Label
var lbl_ammo: Label
var btn_switch_slot: Button
var btn_reload: Button

var lbl_controls: Label
var btn_kamikaze: Button
var btn_exit_lobby: Button

# Right Panel Elements
var right_panel: PanelContainer
var lbl_minimap_title: Label
var lbl_minimap_coords: Label
var minimap_control: Control
var _minimap_terrain_texture: ImageTexture = null

var lbl_zone_a: Label
var bar_zone_a: ProgressBar
var lbl_zone_b: Label
var bar_zone_b: ProgressBar
var lbl_zone_c: Label
var bar_zone_c: ProgressBar

var lbl_casualties_red: Label
var lbl_casualties_blue: Label
var lbl_wave: Label

# Central Alert Banners
var lbl_kamikaze: Label
var lbl_respawn: Label

# Pause Menu Overlay
var pause_modal: Control
var pause_panel: PanelContainer
var is_pause_open: bool = false
var respawn_countdown: float = 0.0

func setup(player: Player) -> void:
	player_ref = player
	respawn_countdown = 0.0
	if lbl_respawn:
		lbl_respawn.visible = false
	if player_ref:
		if not player_ref.integrity_changed.is_connected(_on_player_update):
			player_ref.integrity_changed.connect(_on_player_update)
		if not player_ref.weapon_state_changed.is_connected(_on_player_update):
			player_ref.weapon_state_changed.connect(_on_player_update)
		if not player_ref.kamikaze_started.is_connected(_on_kamikaze_started):
			player_ref.kamikaze_started.connect(_on_kamikaze_started)
		_on_player_update()

func _ready() -> void:
	_create_ui_layout()
	_on_player_update()

func _unhandled_input(event: InputEvent) -> void:
	if _is_escape_event(event):
		toggle_pause_menu()
		get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	if _is_escape_event(event):
		toggle_pause_menu()
		get_viewport().set_input_as_handled()

func _is_escape_event(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE:
			return true
	if event.is_action_pressed("menu_pause", false) or event.is_action_pressed("ui_cancel", false):
		return true
	return false

func toggle_pause_menu() -> void:
	is_pause_open = !is_pause_open
	if pause_modal:
		pause_modal.visible = is_pause_open

func _create_ui_layout() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# -------------------------------------------------------------
	# 1. LEFT PANEL: Full Interface (Width 420 px, Height 1080 px)
	# -------------------------------------------------------------
	left_panel = PanelContainer.new()
	left_panel.position = Vector2(0, 0)
	left_panel.size = Vector2(420, 1080)
	left_panel.custom_minimum_size = Vector2(420, 1080)
	left_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var left_style := StyleBoxFlat.new()
	left_style.bg_color = Color(0.07, 0.08, 0.11, 0.98)
	left_style.border_width_right = 2
	left_style.border_color = Color(0.22, 0.28, 0.35)
	left_panel.add_theme_stylebox_override("panel", left_style)
	root.add_child(left_panel)

	var left_margin := MarginContainer.new()
	left_margin.add_theme_constant_override("margin_left", 14)
	left_margin.add_theme_constant_override("margin_right", 14)
	left_margin.add_theme_constant_override("margin_top", 14)
	left_margin.add_theme_constant_override("margin_bottom", 14)
	left_panel.add_child(left_margin)

	var left_vbox := VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 8)
	left_margin.add_child(left_vbox)

	# Title / Header
	lbl_title_hud = Label.new()
	lbl_title_hud.text = "ОПЕРАТИВНЫЙ ИНТЕРФЕЙС"
	lbl_title_hud.add_theme_font_size_override("font_size", 14)
	lbl_title_hud.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
	left_vbox.add_child(lbl_title_hud)

	# Match Timer & Team
	var match_box := HBoxContainer.new()
	match_box.add_theme_constant_override("separation", 10)
	left_vbox.add_child(match_box)

	lbl_timer = Label.new()
	lbl_timer.text = "ВРЕМЯ: 03:00"
	lbl_timer.add_theme_font_size_override("font_size", 13)
	lbl_timer.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	match_box.add_child(lbl_timer)

	lbl_team = Label.new()
	lbl_team.text = "[БААЛ (КРАСНЫЕ)]"
	lbl_team.add_theme_font_size_override("font_size", 12)
	lbl_team.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
	match_box.add_child(lbl_team)

	lbl_sectors = Label.new()
	lbl_sectors.text = "СЕКТОРЫ: [A] АКТИВЕН  [B] БЛОК  [C] БЛОК"
	lbl_sectors.add_theme_font_size_override("font_size", 11)
	lbl_sectors.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	left_vbox.add_child(lbl_sectors)

	lbl_class_title = Label.new()
	lbl_class_title.text = "КЛАСС: ОПЕРАТИВНИК"
	lbl_class_title.add_theme_font_size_override("font_size", 12)
	lbl_class_title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	left_vbox.add_child(lbl_class_title)

	left_vbox.add_child(HSeparator.new())

	# Integrity / Body Health Section
	var lbl_integ_title := Label.new()
	lbl_integ_title.text = "ПРОЧНОСТЬ ТЕЛА ОПЕРАТИВНИКА"
	lbl_integ_title.add_theme_font_size_override("font_size", 12)
	lbl_integ_title.add_theme_color_override("font_color", Color(0.6, 0.9, 0.7))
	left_vbox.add_child(lbl_integ_title)

	var ev_res := _create_stat_bar("Уклон", Color(0.2, 0.9, 0.8), left_vbox)
	evasion_box = ev_res["box"]
	evasion_bar = ev_res["bar"]
	lbl_evasion_val = ev_res["val"]

	var t_res := _create_stat_bar("Торс", Color(0.2, 0.85, 0.35), left_vbox)
	torso_bar = t_res["bar"]
	lbl_torso_val = t_res["val"]

	var a_res := _create_stat_bar("Руки", Color(0.2, 0.75, 1.0), left_vbox)
	arms_bar = a_res["bar"]
	lbl_arms_val = a_res["val"]

	var l_res := _create_stat_bar("Ноги", Color(1.0, 0.75, 0.2), left_vbox)
	legs_bar = l_res["bar"]
	lbl_legs_val = l_res["val"]

	lbl_delay = Label.new()
	lbl_delay.text = "ЗАДЕРЖКА ШАГА: 10 [СПРИНТ]"
	lbl_delay.add_theme_font_size_override("font_size", 11)
	lbl_delay.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	left_vbox.add_child(lbl_delay)

	left_vbox.add_child(HSeparator.new())

	# Target Selection Section
	var lbl_target_sec := Label.new()
	lbl_target_sec.text = "ПРИЦЕЛИВАНИЕ ПО ЧАСТЯМ ТЕЛА"
	lbl_target_sec.add_theme_font_size_override("font_size", 12)
	lbl_target_sec.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
	left_vbox.add_child(lbl_target_sec)

	lbl_target = Label.new()
	lbl_target.text = "АКТИВНАЯ ЦЕЛЬ: ТУЛОВИЩЕ"
	lbl_target.add_theme_font_size_override("font_size", 11)
	lbl_target.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	left_vbox.add_child(lbl_target)

	var target_grid := GridContainer.new()
	target_grid.columns = 2
	target_grid.add_theme_constant_override("h_separation", 6)
	target_grid.add_theme_constant_override("v_separation", 6)
	left_vbox.add_child(target_grid)

	btn_target_head = Button.new()
	btn_target_head.text = "ГОЛОВА [1] (х1.5)"
	btn_target_head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_target_head.add_theme_font_size_override("font_size", 10)
	btn_target_head.pressed.connect(func(): _set_target(Globals.BodyTarget.HEAD))
	target_grid.add_child(btn_target_head)

	btn_target_arms = Button.new()
	btn_target_arms.text = "РУКИ [2] (Оружие)"
	btn_target_arms.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_target_arms.add_theme_font_size_override("font_size", 10)
	btn_target_arms.pressed.connect(func(): _set_target(Globals.BodyTarget.ARMS))
	target_grid.add_child(btn_target_arms)

	btn_target_legs = Button.new()
	btn_target_legs.text = "НОГИ [3] (Замедлить)"
	btn_target_legs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_target_legs.add_theme_font_size_override("font_size", 10)
	btn_target_legs.pressed.connect(func(): _set_target(Globals.BodyTarget.LEGS))
	target_grid.add_child(btn_target_legs)

	btn_target_torso = Button.new()
	btn_target_torso.text = "ТУЛОВИЩЕ [4]"
	btn_target_torso.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_target_torso.add_theme_font_size_override("font_size", 10)
	btn_target_torso.pressed.connect(func(): _set_target(Globals.BodyTarget.TORSO))
	target_grid.add_child(btn_target_torso)

	left_vbox.add_child(HSeparator.new())

	# Weapon & Slot Section
	var lbl_weapon_sec := Label.new()
	lbl_weapon_sec.text = "ВООРУЖЕНИЕ И АМУНИЦИЯ"
	lbl_weapon_sec.add_theme_font_size_override("font_size", 12)
	lbl_weapon_sec.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
	left_vbox.add_child(lbl_weapon_sec)

	lbl_weapon = Label.new()
	lbl_weapon.text = "Mk.Ultra [СЛОТ 1]"
	lbl_weapon.add_theme_font_size_override("font_size", 12)
	lbl_weapon.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	left_vbox.add_child(lbl_weapon)

	lbl_ammo = Label.new()
	lbl_ammo.text = "ПАТРОНЫ: 30 / 30"
	lbl_ammo.add_theme_font_size_override("font_size", 14)
	lbl_ammo.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
	left_vbox.add_child(lbl_ammo)

	var weapon_btn_row := HBoxContainer.new()
	weapon_btn_row.add_theme_constant_override("separation", 6)
	left_vbox.add_child(weapon_btn_row)

	btn_switch_slot = Button.new()
	btn_switch_slot.text = "СМЕНИТЬ СЛОТ [Q]"
	btn_switch_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_switch_slot.add_theme_font_size_override("font_size", 10)
	btn_switch_slot.pressed.connect(func(): if player_ref: player_ref.switch_weapon_slot())
	weapon_btn_row.add_child(btn_switch_slot)

	btn_reload = Button.new()
	btn_reload.text = "ПЕРЕЗАРЯДКА [R]"
	btn_reload.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_reload.add_theme_font_size_override("font_size", 10)
	btn_reload.pressed.connect(func(): if player_ref: player_ref.start_reload())
	weapon_btn_row.add_child(btn_reload)

	left_vbox.add_child(HSeparator.new())

	# Controls Guide
	var lbl_ctrl_title := Label.new()
	lbl_ctrl_title.text = "СПРАВКА УПРАВЛЕНИЯ"
	lbl_ctrl_title.add_theme_font_size_override("font_size", 11)
	lbl_ctrl_title.add_theme_color_override("font_color", Color(0.65, 0.75, 0.85))
	left_vbox.add_child(lbl_ctrl_title)

	lbl_controls = Label.new()
	lbl_controls.text = "• [WASD] — Шаг по клеткам сетки\n• [Shift / СКМ] — Взгляд вдаль (буря)\n• [ЛКМ] — Огонь из оружия / левой руки\n• [ПКМ] — Альт-режим / Второй пистолет / Нож\n• [Q] — Переключение слота оружия\n• [R] — Перезарядка магазина\n• [Пробел] — Тактический перекат\n• [1, 2, 3, 4] — Выбор сегмента прицела\n• [T] — Кольцо эффективной дальности\n• [E] — Активация камикадзе\n• [ESC] — Меню паузы"
	lbl_controls.add_theme_font_size_override("font_size", 9)
	lbl_controls.add_theme_color_override("font_color", Color(0.75, 0.78, 0.82))
	left_vbox.add_child(lbl_controls)

	# Spacer
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_vbox.add_child(spacer)

	# Emergency buttons
	btn_kamikaze = Button.new()
	btn_kamikaze.text = "💥 ПОЯС ШАХИДА (КАМИКАДЗЕ) [E]"
	btn_kamikaze.custom_minimum_size = Vector2(0, 30)
	btn_kamikaze.add_theme_font_size_override("font_size", 10)
	btn_kamikaze.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	btn_kamikaze.pressed.connect(func(): if player_ref: player_ref.manual_kamikaze())
	left_vbox.add_child(btn_kamikaze)

	btn_exit_lobby = Button.new()
	btn_exit_lobby.text = "⚙️ МЕНЮ ПАУЗЫ / ВЫХОД [ESC]"
	btn_exit_lobby.custom_minimum_size = Vector2(0, 28)
	btn_exit_lobby.add_theme_font_size_override("font_size", 10)
	btn_exit_lobby.pressed.connect(toggle_pause_menu)
	left_vbox.add_child(btn_exit_lobby)

	# -------------------------------------------------------------
	# 2. RIGHT PANEL: Tactical Minimap & Intel (Width 420 px, Height 1080 px)
	# -------------------------------------------------------------
	right_panel = PanelContainer.new()
	right_panel.position = Vector2(1500, 0)
	right_panel.size = Vector2(420, 1080)
	right_panel.custom_minimum_size = Vector2(420, 1080)
	right_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var right_style := StyleBoxFlat.new()
	right_style.bg_color = Color(0.07, 0.08, 0.11, 0.98)
	right_style.border_width_left = 2
	right_style.border_color = Color(0.22, 0.28, 0.35)
	right_panel.add_theme_stylebox_override("panel", right_style)
	root.add_child(right_panel)

	var right_margin := MarginContainer.new()
	right_margin.add_theme_constant_override("margin_left", 16)
	right_margin.add_theme_constant_override("margin_right", 16)
	right_margin.add_theme_constant_override("margin_top", 14)
	right_margin.add_theme_constant_override("margin_bottom", 14)
	right_panel.add_child(right_margin)

	var right_vbox := VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 8)
	right_margin.add_child(right_vbox)

	# Minimap Title
	lbl_minimap_title = Label.new()
	lbl_minimap_title.text = "ТАКТИЧЕСКИЙ РАДАР (100x100)"
	lbl_minimap_title.add_theme_font_size_override("font_size", 14)
	lbl_minimap_title.add_theme_color_override("font_color", Color(0.3, 1.0, 0.6))
	right_vbox.add_child(lbl_minimap_title)

	lbl_minimap_coords = Label.new()
	lbl_minimap_coords.text = "КООРДИНАТЫ ОПЕРАТИВНИКА: X: 50, Y: 50"
	lbl_minimap_coords.add_theme_font_size_override("font_size", 10)
	lbl_minimap_coords.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	right_vbox.add_child(lbl_minimap_coords)

	# Minimap Control Canvas (388 x 388)
	minimap_control = Control.new()
	minimap_control.custom_minimum_size = Vector2(388, 388)
	minimap_control.size = Vector2(388, 388)
	minimap_control.mouse_filter = Control.MOUSE_FILTER_STOP
	minimap_control.draw.connect(_on_minimap_draw)
	right_vbox.add_child(minimap_control)

	right_vbox.add_child(HSeparator.new())

	# Sector Progress Bars
	var lbl_sec_title := Label.new()
	lbl_sec_title.text = "КОНТРОЛЬ КЛЮЧЕВЫХ СЕКТОРОВ"
	lbl_sec_title.add_theme_font_size_override("font_size", 12)
	lbl_sec_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	right_vbox.add_child(lbl_sec_title)

	var za_res := _create_sector_item("[СЕКТОР A] Аванпост (Клетка 25, 50)", right_vbox)
	lbl_zone_a = za_res["lbl"]
	bar_zone_a = za_res["bar"]

	var zb_res := _create_sector_item("[СЕКТОР B] Бункерный узел (Клетка 50, 50)", right_vbox)
	lbl_zone_b = zb_res["lbl"]
	bar_zone_b = zb_res["bar"]

	var zc_res := _create_sector_item("[СЕКТОР C] Цитадель (Клетка 78, 50)", right_vbox)
	lbl_zone_c = zc_res["lbl"]
	bar_zone_c = zc_res["bar"]

	right_vbox.add_child(HSeparator.new())

	# Match Intel / Casualties
	var lbl_intel_title := Label.new()
	lbl_intel_title.text = "СВОДКА БОЕВЫХ ДЕЙСТВИЙ"
	lbl_intel_title.add_theme_font_size_override("font_size", 12)
	lbl_intel_title.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	right_vbox.add_child(lbl_intel_title)

	lbl_casualties_red = Label.new()
	lbl_casualties_red.text = "Потери Баала (Красные): 0"
	lbl_casualties_red.add_theme_font_size_override("font_size", 10)
	lbl_casualties_red.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
	right_vbox.add_child(lbl_casualties_red)

	lbl_casualties_blue = Label.new()
	lbl_casualties_blue.text = "Потери Молоха (Синие): 0"
	lbl_casualties_blue.add_theme_font_size_override("font_size", 10)
	lbl_casualties_blue.add_theme_color_override("font_color", Color(0.45, 0.75, 1.0))
	right_vbox.add_child(lbl_casualties_blue)

	lbl_wave = Label.new()
	lbl_wave.text = "Текущая волна: 1 | Подкрепления: Автоматические"
	lbl_wave.add_theme_font_size_override("font_size", 10)
	lbl_wave.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	right_vbox.add_child(lbl_wave)

	# -------------------------------------------------------------
	# 3. CENTRAL GAME VIEWPORT (Width 1080 px, Height 1080 px: X 420..1500)
	# -------------------------------------------------------------
	# Alert Banners (centered horizontally between 420 and 1500)
	lbl_kamikaze = Label.new()
	lbl_kamikaze.text = "КАМИКАДЗЕ! ВЗРЫВ ЧЕРЕЗ: 5.0с"
	lbl_kamikaze.add_theme_font_size_override("font_size", 16)
	lbl_kamikaze.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
	lbl_kamikaze.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_kamikaze.position = Vector2(440, 24)
	lbl_kamikaze.size = Vector2(1040, 30)
	lbl_kamikaze.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_kamikaze.visible = false
	root.add_child(lbl_kamikaze)

	lbl_respawn = Label.new()
	lbl_respawn.text = "ВЫ ПОГИБЛИ. АВТОРЕСПАВН ЧЕРЕЗ: 3.0с"
	lbl_respawn.add_theme_font_size_override("font_size", 15)
	lbl_respawn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	lbl_respawn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_respawn.position = Vector2(440, 60)
	lbl_respawn.size = Vector2(1040, 30)
	lbl_respawn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_respawn.visible = false
	root.add_child(lbl_respawn)

	# -------------------------------------------------------------
	# 4. PAUSE / EXIT MODAL OVERLAY
	# -------------------------------------------------------------
	pause_modal = Control.new()
	pause_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_modal.visible = false
	pause_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(pause_modal)

	var dimmer := ColorRect.new()
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0, 0, 0, 0.65)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_modal.add_child(dimmer)

	var p_center := CenterContainer.new()
	p_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_modal.add_child(p_center)

	pause_panel = PanelContainer.new()
	pause_panel.custom_minimum_size = Vector2(360, 220)
	p_center.add_child(pause_panel)

	var p_vbox := VBoxContainer.new()
	p_vbox.add_theme_constant_override("separation", 14)
	pause_panel.add_child(p_vbox)

	var p_title := Label.new()
	p_title.text = "МЕНЮ ПАУЗЫ"
	p_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p_title.add_theme_font_size_override("font_size", 16)
	p_title.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
	p_vbox.add_child(p_title)

	var btn_resume := Button.new()
	btn_resume.text = "ПРОДОЛЖИТЬ БОЙ [ESC]"
	btn_resume.custom_minimum_size = Vector2(0, 34)
	btn_resume.add_theme_font_size_override("font_size", 12)
	btn_resume.pressed.connect(toggle_pause_menu)
	p_vbox.add_child(btn_resume)

	var btn_quit_lobby := Button.new()
	btn_quit_lobby.text = "ВЫЙТИ В ЛОББИ"
	btn_quit_lobby.custom_minimum_size = Vector2(0, 34)
	btn_quit_lobby.add_theme_font_size_override("font_size", 12)
	btn_quit_lobby.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	btn_quit_lobby.pressed.connect(_on_exit_to_lobby_pressed)
	p_vbox.add_child(btn_quit_lobby)

# ----------------- MINIMAP RENDERING -----------------

func _get_minimap_terrain_texture() -> ImageTexture:
	if _minimap_terrain_texture != null:
		return _minimap_terrain_texture
	if not MapGenerator.instance or MapGenerator.instance.grid.is_empty():
		return null

	var img := Image.create(Globals.MAP_TILES, Globals.MAP_TILES, false, Image.FORMAT_RGBA8)
	for y in range(Globals.MAP_TILES):
		for x in range(Globals.MAP_TILES):
			var t_type: int = MapGenerator.instance.grid[y][x]
			var col := Color(0.10, 0.12, 0.15) # Walkable ground
			if t_type == 1:
				col = Color(0.55, 0.62, 0.70) # Bunker walls
			elif t_type == 2:
				col = Color(0.80, 0.55, 0.25) # Sandbag barricades
			img.set_pixel(x, y, col)

	_minimap_terrain_texture = ImageTexture.create_from_image(img)
	return _minimap_terrain_texture

func _on_minimap_draw() -> void:
	if not minimap_control:
		return

	var m_size: float = 388.0
	var scale_f: float = m_size / Globals.MAP_PX # 388.0 / 3200.0

	# 1. Base dark background
	minimap_control.draw_rect(Rect2(0, 0, m_size, m_size), Color(0.06, 0.07, 0.09), true)

	# 2. Map terrain texture
	var tex: ImageTexture = _get_minimap_terrain_texture()
	if tex:
		minimap_control.draw_texture_rect(tex, Rect2(0, 0, m_size, m_size), false)

	# 3. Defensive barrier lines (Line 1 at X=36, Line 2 at X=66)
	var x1: float = 36.0 * Globals.TILE_SIZE * scale_f
	var x2: float = 66.0 * Globals.TILE_SIZE * scale_f
	minimap_control.draw_line(Vector2(x1, 0), Vector2(x1, m_size), Color(0.4, 0.6, 0.8, 0.35), 1.0)
	minimap_control.draw_line(Vector2(x2, 0), Vector2(x2, m_size), Color(0.4, 0.6, 0.8, 0.35), 1.0)

	# 4. Spawns / Bases
	var red_base: Vector2 = Vector2(10 * 32 + 16, 50 * 32 + 16) * scale_f
	var blue_base: Vector2 = Vector2(90 * 32 + 16, 50 * 32 + 16) * scale_f
	minimap_control.draw_circle(red_base, 6.0, Color(1.0, 0.25, 0.25, 0.9))
	minimap_control.draw_circle(blue_base, 6.0, Color(0.25, 0.65, 1.0, 0.9))

	# 5. Capture Zones A, B, C
	if MapGenerator.instance:
		_draw_minimap_zone(minimap_control, MapGenerator.instance.zone_a, scale_f)
		_draw_minimap_zone(minimap_control, MapGenerator.instance.zone_b, scale_f)
		_draw_minimap_zone(minimap_control, MapGenerator.instance.zone_c, scale_f)

	# 6. Camera Viewport Wireframe & Dust Storm Range on Minimap
	if player_ref and is_instance_valid(player_ref):
		var p_pos: Vector2 = player_ref.global_position
		# Draw dust storm vision circle around player on radar (gray storm boundary)
		var storm_r_mini: float = 270.0 * scale_f
		minimap_control.draw_arc(p_pos * scale_f, storm_r_mini, 0.0, TAU, 32, Color(0.68, 0.72, 0.78, 0.45), 1.2)

		var cam_node = player_ref.get_node_or_null("Camera2D")
		var cam_pos: Vector2 = cam_node.global_position if (cam_node and is_instance_valid(cam_node)) else p_pos
		var cam_half := Vector2(270.0, 270.0) # 540x540 world area at 2x zoom
		var cam_rect_world := Rect2(cam_pos - cam_half, Vector2(540.0, 540.0))
		var cam_mini := Rect2(cam_rect_world.position * scale_f, cam_rect_world.size * scale_f)
		minimap_control.draw_rect(cam_mini, Color(1.0, 1.0, 1.0, 0.6), false, 1.5)

	# 7. Units (bots & players)
	var units: Array = get_tree().get_nodes_in_group("units")
	for u_node in units:
		var u: Unit = u_node as Unit
		if not is_instance_valid(u) or u == null or u.is_dead:
			continue
		if u == player_ref:
			continue # Local player drawn on top
		var is_friend: bool = (player_ref != null and u.team == player_ref.team)
		# In dust storm: distant enemies outside visibility radius are hidden from radar
		if not is_friend and player_ref != null and is_instance_valid(player_ref):
			var has_dv: bool = (player_ref.class_data != null and player_ref.class_data.has_deathvision)
			var is_cloaked: bool = (u.class_data != null and u.class_data.has_cloak)
			if has_dv and not is_cloaked:
				# Deathvision detects uncloaked enemies on radar even through the storm
				pass
			else:
				var cam_node = player_ref.get_node_or_null("Camera2D")
				var cam_center: Vector2 = cam_node.global_position if (cam_node and is_instance_valid(cam_node)) else player_ref.global_position
				var dist_p: float = player_ref.global_position.distance_to(u.global_position)
				var dist_c: float = cam_center.distance_to(u.global_position)
				if dist_p > 270.0 and dist_c > 270.0:
					continue
		var u_pos: Vector2 = u.global_position * scale_f
		var u_col: Color
		if is_friend:
			u_col = Color(0.3, 0.75, 1.0, 0.95) if u.team == Globals.Team.MOLOCH_BLUE else Color(1.0, 0.45, 0.45, 0.95)
		else:
			u_col = Color(1.0, 0.2, 0.2, 0.95) if u.team == Globals.Team.BAAL_RED else Color(0.2, 0.55, 1.0, 0.95)
		minimap_control.draw_circle(u_pos, 3.5, u_col)

	# Local Player (Bright green with heading line)
	if player_ref and is_instance_valid(player_ref) and not player_ref.is_dead:
		var p_mini: Vector2 = player_ref.global_position * scale_f
		minimap_control.draw_circle(p_mini, 5.5, Color(0.2, 1.0, 0.4, 0.95))
		minimap_control.draw_arc(p_mini, 7.5, 0, TAU, 16, Color(1.0, 1.0, 0.2, 0.95), 1.5)
		var ray: Vector2 = Vector2.from_angle(player_ref.aim_angle) * 12.0
		minimap_control.draw_line(p_mini, p_mini + ray, Color(1.0, 1.0, 0.2, 0.95), 2.0)

	# 8. Frame border & corner crosshairs
	minimap_control.draw_rect(Rect2(0, 0, m_size, m_size), Color(0.35, 0.45, 0.55), false, 2.0)
	var t_len: float = 12.0
	minimap_control.draw_line(Vector2(0, 0), Vector2(t_len, 0), Color(0.4, 0.9, 1.0), 2.0)
	minimap_control.draw_line(Vector2(0, 0), Vector2(0, t_len), Color(0.4, 0.9, 1.0), 2.0)
	minimap_control.draw_line(Vector2(m_size, 0), Vector2(m_size - t_len, 0), Color(0.4, 0.9, 1.0), 2.0)
	minimap_control.draw_line(Vector2(m_size, 0), Vector2(m_size, t_len), Color(0.4, 0.9, 1.0), 2.0)
	minimap_control.draw_line(Vector2(0, m_size), Vector2(t_len, m_size), Color(0.4, 0.9, 1.0), 2.0)
	minimap_control.draw_line(Vector2(0, m_size), Vector2(0, m_size - t_len), Color(0.4, 0.9, 1.0), 2.0)
	minimap_control.draw_line(Vector2(m_size, m_size), Vector2(m_size - t_len, m_size), Color(0.4, 0.9, 1.0), 2.0)
	minimap_control.draw_line(Vector2(m_size, m_size), Vector2(m_size, m_size - t_len), Color(0.4, 0.9, 1.0), 2.0)

func _draw_minimap_zone(c: Control, zone: CaptureZone, scale_f: float) -> void:
	if not zone:
		return
	var z_pos: Vector2 = zone.global_position * scale_f
	var z_rad: float = zone.capture_radius_px * scale_f
	var col: Color = Color(0.5, 0.5, 0.5, 0.5)
	if zone.is_captured:
		col = Color(1.0, 0.25, 0.25, 0.85)
	elif zone.is_active:
		col = Color(1.0, 0.85, 0.25, 0.85)

	c.draw_circle(z_pos, z_rad, Color(col.r, col.g, col.b, 0.25))
	c.draw_arc(z_pos, z_rad, 0, TAU, 24, col, 1.5)

	if zone.is_active and not zone.is_captured and zone.capture_progress > 0.0:
		var sweep: float = (zone.capture_progress / 100.0) * TAU
		c.draw_arc(z_pos, z_rad + 2.0, -PI/2.0, -PI/2.0 + sweep, 24, Color(1.0, 0.2, 0.2, 0.95), 2.5)

	var f: Font = ThemeDB.fallback_font
	c.draw_string(f, z_pos + Vector2(-5, 4), zone.zone_name, HORIZONTAL_ALIGNMENT_CENTER, -1, 11, Color(1, 1, 1, 0.95))

# ----------------- UI CREATION HELPERS -----------------

func _create_stat_bar(part_name: String, col: Color, parent: VBoxContainer) -> Dictionary:
	var box := HBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(box)

	var lbl := Label.new()
	lbl.text = part_name
	lbl.custom_minimum_size = Vector2(50, 0)
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(lbl)

	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(230, 16)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.max_value = 100.0
	bar.value = 100.0
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(bar)

	var val_lbl := Label.new()
	val_lbl.text = "100/100"
	val_lbl.custom_minimum_size = Vector2(70, 0)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_lbl.add_theme_font_size_override("font_size", 10)
	val_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(val_lbl)

	return {"bar": bar, "val": val_lbl, "box": box}

func _create_sector_item(sector_name: String, parent: VBoxContainer) -> Dictionary:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	parent.add_child(box)

	var lbl := Label.new()
	lbl.text = sector_name
	lbl.add_theme_font_size_override("font_size", 11)
	box.add_child(lbl)

	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(380, 12)
	bar.max_value = 100.0
	bar.value = 0.0
	bar.show_percentage = false
	box.add_child(bar)

	return {"lbl": lbl, "bar": bar}

func _set_target(target: Globals.BodyTarget) -> void:
	if player_ref:
		player_ref.current_body_target = target
		_on_player_update()

func show_respawn_countdown(dur: float = 3.0) -> void:
	respawn_countdown = dur
	if lbl_respawn:
		lbl_respawn.visible = true
		lbl_respawn.text = "ВЫ ПОГИБЛИ. АВТОРЕСПАВН ЧЕРЕЗ: %.1fс" % respawn_countdown

func _on_player_update() -> void:
	if not player_ref:
		return

	# Team display
	if lbl_team:
		if player_ref.team == Globals.Team.BAAL_RED:
			lbl_team.text = "[АРМИЯ БААЛА (ШТУРМ)]"
			lbl_team.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
		else:
			lbl_team.text = "[АРМИЯ МОЛОХА (ОБОРОНА)]"
			lbl_team.add_theme_color_override("font_color", Color(0.45, 0.75, 1.0))

	# Class title and Specialist traits
	if lbl_class_title:
		var c_name: String = "ОПЕРАТИВНИК"
		var badges: String = ""
		var is_specialist: bool = false
		if player_ref.class_data:
			c_name = player_ref.class_data.display_name.to_upper()
			if player_ref.class_data.class_id == "raptor" or player_ref.class_data.class_id == "augur":
				is_specialist = true
			if player_ref.class_data.has_deathvision:
				badges += " [СМЕРТОВИЗОР]"
			if player_ref.class_data.has_cloak:
				badges += " [ПОКРОВ]"
		lbl_class_title.text = "КЛАСС: %s%s" % [c_name, badges]
		if is_specialist:
			lbl_class_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
		else:
			lbl_class_title.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))

	# Evasion Bar (Raptor)
	if evasion_box and evasion_bar and lbl_evasion_val:
		if player_ref.max_evasion > 0.0:
			evasion_box.visible = true
			evasion_bar.max_value = player_ref.max_evasion
			evasion_bar.value = player_ref.evasion
			lbl_evasion_val.text = "%d / %d" % [int(player_ref.evasion), int(player_ref.max_evasion)]
		else:
			evasion_box.visible = false

	# Update Integrity Bars & numeric values
	torso_bar.max_value = player_ref.max_torso_hp
	torso_bar.value = maxf(0.0, player_ref.torso_hp)
	if lbl_torso_val:
		lbl_torso_val.text = "%d / %d" % [int(player_ref.torso_hp), int(player_ref.max_torso_hp)]

	arms_bar.max_value = player_ref.max_arms_hp
	arms_bar.value = maxf(0.0, player_ref.arms_hp)
	if lbl_arms_val:
		if player_ref.arms_hp <= 0.0:
			lbl_arms_val.text = "ОТОРВАНЫ!"
			lbl_arms_val.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
		else:
			if player_ref.class_data and player_ref.class_data.instant_explode_on_arms_loss:
				lbl_arms_val.text = "%d / %d [ВЗРЫВ ПРИ 0%%]" % [int(player_ref.arms_hp), int(player_ref.max_arms_hp)]
				lbl_arms_val.add_theme_color_override("font_color", Color(1.0, 0.5, 0.2))
			else:
				lbl_arms_val.text = "%d / %d" % [int(player_ref.arms_hp), int(player_ref.max_arms_hp)]
				lbl_arms_val.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))

	legs_bar.max_value = player_ref.max_legs_hp
	legs_bar.value = maxf(0.0, player_ref.legs_hp)
	if lbl_legs_val:
		lbl_legs_val.text = "%d / %d" % [int(player_ref.legs_hp), int(player_ref.max_legs_hp)]

	# Movement Delay info
	var cur_delay: float = player_ref.get_current_move_delay()
	lbl_delay.text = "ЗАДЕРЖКА ШАГА: %.0f" % cur_delay
	if player_ref.stun_timer > 0.0:
		lbl_delay.text += " (ОГЛУШЕН)"
	elif player_ref.legs_hp <= 0.0:
		lbl_delay.text += " (ПОЛЗАНИЕ)"
	elif player_ref.legs_hp <= player_ref.max_legs_hp * 0.5:
		lbl_delay.text += " (ХРОМОТА)"

	# Target part label & button highlighting
	var act_col := Color(0.2, 1.0, 0.4)
	var inact_col := Color(0.7, 0.7, 0.7)

	if btn_target_head: btn_target_head.add_theme_color_override("font_color", inact_col)
	if btn_target_arms: btn_target_arms.add_theme_color_override("font_color", inact_col)
	if btn_target_legs: btn_target_legs.add_theme_color_override("font_color", inact_col)
	if btn_target_torso: btn_target_torso.add_theme_color_override("font_color", inact_col)

	match player_ref.current_body_target:
		Globals.BodyTarget.HEAD:
			lbl_target.text = "АКТИВНАЯ ЦЕЛЬ: ГОЛОВА (х1.5 Урон)"
			if btn_target_head: btn_target_head.add_theme_color_override("font_color", act_col)
		Globals.BodyTarget.ARMS:
			lbl_target.text = "АКТИВНАЯ ЦЕЛЬ: РУКИ (Обезоружить)"
			if btn_target_arms: btn_target_arms.add_theme_color_override("font_color", act_col)
		Globals.BodyTarget.LEGS:
			lbl_target.text = "АКТИВНАЯ ЦЕЛЬ: НОГИ (Замедление)"
			if btn_target_legs: btn_target_legs.add_theme_color_override("font_color", act_col)
		Globals.BodyTarget.TORSO:
			lbl_target.text = "АКТИВНАЯ ЦЕЛЬ: ТУЛОВИЩЕ"
			if btn_target_torso: btn_target_torso.add_theme_color_override("font_color", act_col)

	# Slot button state
	if btn_switch_slot:
		if player_ref.weapon_slot_1 == null:
			btn_switch_slot.text = "СЛОТ: ФИКСИРОВАННЫЙ"
			btn_switch_slot.disabled = true
		else:
			btn_switch_slot.text = "СМЕНИТЬ СЛОТ [Q]"
			btn_switch_slot.disabled = false

	# Active weapon display
	if player_ref.arms_hp <= 0.0:
		lbl_weapon.text = "РУКИ УНИЧТОЖЕНЫ! ОРУЖИЕ НЕДОСТУПНО"
		lbl_weapon.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
		lbl_ammo.text = "ЖМИ [E] ДЛЯ КАМИКАДЗЕ"
		lbl_ammo.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	else:
		var c_id: String = player_ref.class_data.class_id if player_ref.class_data else ""
		if c_id == "raptor":
			# Raptor: Ghetta SMG (L) + Cossack Blade (R)
			var wl: WeaponData = player_ref.weapon_slot_2_left
			var wr: WeaponData = player_ref.weapon_slot_2_right
			lbl_weapon.text = "РАПТОР: ПП GHETTA + КЛИНОК COSSACK"
			lbl_weapon.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
			var l_str: String = ("ЗАРЯДКА (%.1fс)" % wl.reload_timer) if (wl and wl.is_reloading) else ("%d/%d" % [wl.current_ammo, wl.magazine_size] if wl else "НЕТ")
			lbl_ammo.text = "[ЛКМ] ПП: %s | [ПКМ] КЛИНОК: БЕЗЛИМИТ" % l_str
			var is_reloading: bool = (wl != null and wl.is_reloading)
			lbl_ammo.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2) if is_reloading else Color(0.3, 1.0, 0.5))
		elif c_id == "augur":
			# Augur: Blaster Shotgun (L) + Templum Heavy Cannon (R)
			var wl: WeaponData = player_ref.weapon_slot_2_left
			var wr: WeaponData = player_ref.weapon_slot_2_right
			lbl_weapon.text = "АВГУР: ОБРЕЗ BLASTER + ПУШКА TEMPLUM"
			lbl_weapon.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
			var l_str: String = ("ЗАРЯДКА (%.1fс)" % wl.reload_timer) if (wl and wl.is_reloading) else ("%d/%d" % [wl.current_ammo, wl.magazine_size] if wl else "НЕТ")
			var r_str: String = "КД (%.1fс)" % wr.fire_cooldown if (wr and wr.fire_cooldown > 0.0) else "ГОТОВА (1/1)"
			lbl_ammo.text = "[ЛКМ] ОБРЕЗ: %s | [ПКМ] ПУШКА: %s" % [l_str, r_str]
			var is_reloading_any: bool = (wl != null and wl.is_reloading) or (wr != null and wr.fire_cooldown > 0.0)
			lbl_ammo.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2) if is_reloading_any else Color(0.3, 1.0, 0.5))
		else:
			# Standard Leech / Trooper
			var w: WeaponData = player_ref.get_active_primary_weapon()
			if w:
				var slot_str := "СЛОТ 1" if player_ref.active_slot == 1 else "СЛОТ 2"
				var alt_str := " [АоЕ РЕЖИМ]" if w.alt_mode_active else ""
				if player_ref.active_slot == 2:
					var wr: WeaponData = player_ref.weapon_slot_2_right
					if wr and wr.weapon_type != WeaponData.WeaponType.MELEE:
						# Dual pistols loadout (Leech)
						lbl_weapon.text = "ДВА ПИСТОЛЕТА (%s) [СЛОТ 2]" % [w.display_name]
						lbl_weapon.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
						
						var l_ammo_str: String = "ЗАРЯДКА (%.1fс)" % w.reload_timer if w.is_reloading else ("%d/%d" % [w.current_ammo, w.magazine_size])
						var r_ammo_str: String = "ЗАРЯДКА (%.1fс)" % wr.reload_timer if wr.is_reloading else ("%d/%d" % [wr.current_ammo, wr.magazine_size])
						lbl_ammo.text = "ЛЕВЫЙ [ЛКМ]: %s | ПРАВЫЙ [ПКМ]: %s" % [l_ammo_str, r_ammo_str]
						var is_reloading_any: bool = (w.is_reloading or wr.is_reloading)
						lbl_ammo.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2) if is_reloading_any else Color(0.3, 1.0, 0.5))
					else:
						# Pistol + Knife loadout (Trooper)
						lbl_weapon.text = "%s [СЛОТ 2: ЛКМ Огонь | ПКМ Нож]" % [w.display_name]
						lbl_weapon.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
						if w.is_reloading:
							lbl_ammo.text = "ЗАРЯДКА... (%.1fс) | НОЖ: [ПКМ] БЕЗЛИМИТ" % w.reload_timer
							lbl_ammo.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
						else:
							lbl_ammo.text = "ПАТРОНЫ: %d / %d | НОЖ: [ПКМ] БЕЗЛИМИТ" % [w.current_ammo, w.magazine_size]
							lbl_ammo.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
				else:
					lbl_weapon.text = "%s [%s]%s" % [w.display_name, slot_str, alt_str]
					lbl_weapon.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
					if w.is_reloading:
						lbl_ammo.text = "ЗАРЯДКА... (%.1fс)" % w.reload_timer
						lbl_ammo.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
					else:
						lbl_ammo.text = "ПАТРОНЫ: %d / %d" % [w.current_ammo, w.magazine_size]
						lbl_ammo.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
			else:
				lbl_weapon.text = "НЕТ ОРУЖИЯ"
				lbl_ammo.text = ""

	# Kamikaze banner
	if player_ref.kamikaze_active:
		lbl_kamikaze.visible = true
		lbl_kamikaze.text = "КАМИКАДЗЕ! ВЗРЫВ ЧЕРЕЗ: %.1fс" % player_ref.kamikaze_timer
	else:
		lbl_kamikaze.visible = false

func _on_kamikaze_started() -> void:
	_on_player_update()

func update_match_status(time_left: float, zone_a_prog: float, a_cap: bool, zone_b_prog: float, b_cap: bool, zone_c_prog: float, c_cap: bool) -> void:
	var mins: int = int(time_left) / 60
	var secs: int = int(time_left) % 60
	lbl_timer.text = "ВРЕМЯ: %02d:%02d" % [mins, secs]

	var a_str: String = "A: ВЗЯТ" if a_cap else ("A: %d%%" % int(zone_a_prog))
	var b_str: String = "B: ВЗЯТ" if b_cap else (("B: %d%%" % int(zone_b_prog)) if a_cap else "B: БЛОК")
	var c_str: String = "C: ВЗЯТ" if c_cap else (("C: %d%%" % int(zone_c_prog)) if b_cap else "C: БЛОК")
	lbl_sectors.text = "СЕКТОРЫ: [%s]  [%s]  [%s]" % [a_str, b_str, c_str]

	# Update Sector Progress Bars on Right Panel
	if bar_zone_a and lbl_zone_a:
		bar_zone_a.value = 100.0 if a_cap else zone_a_prog
		lbl_zone_a.text = "[СЕКТОР A] Аванпост: %s" % ("ЗАХВАЧЕН" if a_cap else ("ШТУРМ %d%%" % int(zone_a_prog)))

	if bar_zone_b and lbl_zone_b:
		bar_zone_b.value = 100.0 if b_cap else zone_b_prog
		var b_status: String = "ЗАХВАЧЕН" if b_cap else (("ШТУРМ %d%%" % int(zone_b_prog)) if a_cap else "ЗАБЛОКИРОВАН")
		lbl_zone_b.text = "[СЕКТОР B] Бункерный узел: %s" % b_status

	if bar_zone_c and lbl_zone_c:
		bar_zone_c.value = 100.0 if c_cap else zone_c_prog
		var c_status: String = "ЗАХВАЧЕН" if c_cap else (("ШТУРМ %d%%" % int(zone_c_prog)) if b_cap else "ЗАБЛОКИРОВАН")
		lbl_zone_c.text = "[СЕКТОР C] Цитадель: %s" % c_status

func _process(delta: float) -> void:
	if player_ref and is_instance_valid(player_ref):
		_on_player_update()

	# Update minimap coords
	if player_ref and is_instance_valid(player_ref) and lbl_minimap_coords:
		var t := player_ref.current_tile
		lbl_minimap_coords.text = "КООРДИНАТЫ: Клетка [%d, %d]  (Мир: %d, %d)" % [t.x, t.y, int(player_ref.global_position.x), int(player_ref.global_position.y)]

	# Redraw minimap radar
	if minimap_control:
		minimap_control.queue_redraw()

	# Update casualties & wave info from GameManager
	if GameManager.instance:
		if lbl_casualties_red:
			lbl_casualties_red.text = "Потери Баала (Красные): %d" % GameManager.instance.red_casualties
		if lbl_casualties_blue:
			lbl_casualties_blue.text = "Потери Молоха (Синие): %d" % GameManager.instance.blue_casualties
		if lbl_wave:
			lbl_wave.text = "Текущая волна: %d | Подкрепления: Автоматические" % GameManager.instance.wave_number

	# Kamikaze countdown
	if player_ref and player_ref.kamikaze_active:
		lbl_kamikaze.text = "КАМИКАДЗЕ! ВЗРЫВ ЧЕРЕЗ: %.1fс" % player_ref.kamikaze_timer

	# Respawn countdown
	if respawn_countdown > 0.0:
		respawn_countdown -= delta
		if lbl_respawn:
			lbl_respawn.text = "ВЫ ПОГИБЛИ. АВТОРЕСПАВН ЧЕРЕЗ: %.1fс" % maxf(0.0, respawn_countdown)
			if respawn_countdown <= 0.0:
				lbl_respawn.visible = false

func _on_exit_to_lobby_pressed() -> void:
	var net_node: Node = get_node_or_null("/root/NetworkManager")
	if net_node and net_node.has_method("stop_multiplayer"):
		net_node.call("stop_multiplayer")
	get_tree().change_scene_to_file("res://scenes/lobby.tscn")

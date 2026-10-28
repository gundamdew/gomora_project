class_name HUD3D
extends CanvasLayer

var player_ref: Player3D = null

# Central Crosshair & Hitmarker
var crosshair_center: Control
var hitmarker_rect: Control
var hitmarker_timer: float = 0.0

# Bottom HUD stats
var lbl_health: Label
var lbl_armor: Label
var lbl_ammo: Label
var lbl_weapon_name: Label
var weapon_slots_container: HBoxContainer
var weapon_slot_labels: Dictionary = {}

# Top Match Status
var lbl_timer: Label
var lbl_sectors: Label

# Top Right Killfeed
var killfeed_vbox: VBoxContainer

# Center Announcement
var lbl_announcement: Label
var announcement_timer: float = 0.0

# TAB Scoreboard
var scoreboard_panel: PanelContainer
var scoreboard_red_vbox: VBoxContainer
var scoreboard_blue_vbox: VBoxContainer

# ESC Pause Menu
var pause_menu_panel: PanelContainer
var is_pause_open: bool = false

func _ready() -> void:
	_create_ui()

func setup(player: Player3D) -> void:
	player_ref = player
	if is_instance_valid(player_ref):
		player_ref.integrity_changed.connect(_update_stats)
		player_ref.weapon_state_changed.connect(_update_weapon_display)
		_update_stats()
		_update_weapon_display()

func _create_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# 1. Quake Central Crosshair
	_create_crosshair(root)

	# 2. Bottom Stats Panel (Health, Armor, Ammo, Weapon bar)
	_create_bottom_hud(root)

	# 3. Top Match Status & Sectors
	_create_top_status(root)

	# 4. Top Right Killfeed
	_create_killfeed(root)

	# 5. Central Frag Announcement
	_create_announcement(root)

	# 6. TAB Scoreboard
	_create_scoreboard(root)

	# 7. ESC Pause Menu
	_create_pause_menu(root)

func _create_crosshair(parent: Control) -> void:
	crosshair_center = Control.new()
	crosshair_center.set_anchors_preset(Control.PRESET_CENTER)
	crosshair_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(crosshair_center)

	var cross_col := Color(0.1, 1.0, 0.4, 0.85)
	# 4 Crosshair lines
	var left := ColorRect.new()
	left.position = Vector2(-14, -1)
	left.size = Vector2(8, 2)
	left.color = cross_col
	crosshair_center.add_child(left)

	var right := ColorRect.new()
	right.position = Vector2(6, -1)
	right.size = Vector2(8, 2)
	right.color = cross_col
	crosshair_center.add_child(right)

	var top := ColorRect.new()
	top.position = Vector2(-1, -14)
	top.size = Vector2(2, 8)
	top.color = cross_col
	crosshair_center.add_child(top)

	var bottom := ColorRect.new()
	bottom.position = Vector2(-1, 6)
	bottom.size = Vector2(2, 8)
	bottom.color = cross_col
	crosshair_center.add_child(bottom)

	# Red Hitmarker 'X' ticks
	hitmarker_rect = Control.new()
	hitmarker_rect.visible = false
	hitmarker_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair_center.add_child(hitmarker_rect)

	for rot in [-45.0, 45.0]:
		var h_line := ColorRect.new()
		h_line.size = Vector2(16, 2)
		h_line.position = Vector2(-8, -1)
		h_line.color = Color(1.0, 0.2, 0.2, 0.95)
		h_line.rotation_degrees = rot
		hitmarker_rect.add_child(h_line)

func _create_bottom_hud(parent: Control) -> void:
	var bottom_bar := HBoxContainer.new()
	bottom_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_bar.position.y -= 20.0
	bottom_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_bar.add_theme_constant_override("separation", 35)
	bottom_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bottom_bar)

	# Health Container
	var hp_panel := PanelContainer.new()
	var hp_box := HBoxContainer.new()
	hp_box.add_theme_constant_override("separation", 8)
	var hp_icon := Label.new()
	hp_icon.text = "❤️ HP"
	hp_icon.add_theme_font_size_override("font_size", 18)
	hp_icon.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	hp_box.add_child(hp_icon)

	lbl_health = Label.new()
	lbl_health.text = "100"
	lbl_health.add_theme_font_size_override("font_size", 28)
	lbl_health.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
	hp_box.add_child(lbl_health)
	hp_panel.add_child(hp_box)
	bottom_bar.add_child(hp_panel)

	# Armor Container
	var ap_panel := PanelContainer.new()
	var ap_box := HBoxContainer.new()
	ap_box.add_theme_constant_override("separation", 8)
	var ap_icon := Label.new()
	ap_icon.text = "🛡️ AP"
	ap_icon.add_theme_font_size_override("font_size", 18)
	ap_icon.add_theme_color_override("font_color", Color(0.3, 0.7, 1.0))
	ap_box.add_child(ap_icon)

	lbl_armor = Label.new()
	lbl_armor.text = "100"
	lbl_armor.add_theme_font_size_override("font_size", 28)
	lbl_armor.add_theme_color_override("font_color", Color(0.3, 0.7, 1.0))
	ap_box.add_child(lbl_armor)
	ap_panel.add_child(ap_box)
	bottom_bar.add_child(ap_panel)

	# Weapon Slots (1..6)
	weapon_slots_container = HBoxContainer.new()
	weapon_slots_container.add_theme_constant_override("separation", 6)
	var slot_names: Dictionary = {
		1: "[1] КЛИНОК",
		2: "[2] ДРОБОВИК",
		3: "[3] ПУЛЕМЕТ",
		4: "[4] РОКЕТА",
		5: "[5] РЕЛЬСА",
		6: "[6] ПЛАЗМА"
	}
	for idx in range(1, 7):
		var p := PanelContainer.new()
		var l := Label.new()
		l.text = slot_names[idx]
		l.add_theme_font_size_override("font_size", 11)
		l.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
		p.add_child(l)
		weapon_slots_container.add_child(p)
		weapon_slot_labels[idx] = l
	bottom_bar.add_child(weapon_slots_container)

	# Ammo Container
	var ammo_panel := PanelContainer.new()
	var ammo_box := HBoxContainer.new()
	ammo_box.add_theme_constant_override("separation", 8)
	lbl_weapon_name = Label.new()
	lbl_weapon_name.text = "РОКЕТНИЦА"
	lbl_weapon_name.add_theme_font_size_override("font_size", 14)
	lbl_weapon_name.add_theme_color_override("font_color", Color(1.0, 0.7, 0.2))
	ammo_box.add_child(lbl_weapon_name)

	lbl_ammo = Label.new()
	lbl_ammo.text = "15"
	lbl_ammo.add_theme_font_size_override("font_size", 28)
	lbl_ammo.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	ammo_box.add_child(lbl_ammo)
	ammo_panel.add_child(ammo_box)
	bottom_bar.add_child(ammo_panel)

func _create_top_status(parent: Control) -> void:
	var top_vbox := VBoxContainer.new()
	top_vbox.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_vbox.position.y += 12.0
	top_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	top_vbox.add_theme_constant_override("separation", 4)
	top_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(top_vbox)

	lbl_timer = Label.new()
	lbl_timer.text = "ВРЕМЯ МАТЧА: 03:00"
	lbl_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_timer.add_theme_font_size_override("font_size", 22)
	lbl_timer.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	top_vbox.add_child(lbl_timer)

	lbl_sectors = Label.new()
	lbl_sectors.text = "[ СЕКТОР А: 0% ]   [ СЕКТОР B: ЗАБЛОКИРОВАН ]   [ СЕКТОР C: ЗАБЛОКИРОВАН ]"
	lbl_sectors.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_sectors.add_theme_font_size_override("font_size", 14)
	lbl_sectors.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	top_vbox.add_child(lbl_sectors)

func _create_killfeed(parent: Control) -> void:
	killfeed_vbox = VBoxContainer.new()
	killfeed_vbox.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	killfeed_vbox.position = Vector2(-380, 20)
	killfeed_vbox.custom_minimum_size = Vector2(360, 200)
	killfeed_vbox.add_theme_constant_override("separation", 3)
	killfeed_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(killfeed_vbox)

func _create_announcement(parent: Control) -> void:
	lbl_announcement = Label.new()
	lbl_announcement.set_anchors_preset(Control.PRESET_CENTER)
	lbl_announcement.position.y -= 100.0
	lbl_announcement.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_announcement.add_theme_font_size_override("font_size", 34)
	lbl_announcement.add_theme_color_override("font_color", Color(1.0, 0.3, 0.2))
	lbl_announcement.visible = false
	lbl_announcement.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(lbl_announcement)

func _create_scoreboard(parent: Control) -> void:
	scoreboard_panel = PanelContainer.new()
	scoreboard_panel.set_anchors_preset(Control.PRESET_CENTER)
	scoreboard_panel.custom_minimum_size = Vector2(650, 380)
	scoreboard_panel.visible = false
	parent.add_child(scoreboard_panel)

	var svbox := VBoxContainer.new()
	svbox.add_theme_constant_override("separation", 12)
	scoreboard_panel.add_child(svbox)

	var title := Label.new()
	title.text = "ТАБЛИЦА ФРАГОВ (TAB)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	svbox.add_child(title)

	var hbox := HBoxContainer.new()
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 20)
	svbox.add_child(hbox)

	# Red team column
	var red_panel := PanelContainer.new()
	red_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scoreboard_red_vbox = VBoxContainer.new()
	var red_header := Label.new()
	red_header.text = "АРМИЯ БААЛА (КРАСНЫЕ)"
	red_header.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	scoreboard_red_vbox.add_child(red_header)
	red_panel.add_child(scoreboard_red_vbox)
	hbox.add_child(red_panel)

	# Blue team column
	var blue_panel := PanelContainer.new()
	blue_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scoreboard_blue_vbox = VBoxContainer.new()
	var blue_header := Label.new()
	blue_header.text = "АРМИЯ МОЛОХА (СИНИЕ)"
	blue_header.add_theme_color_override("font_color", Color(0.3, 0.6, 1.0))
	scoreboard_blue_vbox.add_child(blue_header)
	blue_panel.add_child(scoreboard_blue_vbox)
	hbox.add_child(blue_panel)

func _create_pause_menu(parent: Control) -> void:
	pause_menu_panel = PanelContainer.new()
	pause_menu_panel.set_anchors_preset(Control.PRESET_CENTER)
	pause_menu_panel.custom_minimum_size = Vector2(320, 240)
	pause_menu_panel.visible = false
	parent.add_child(pause_menu_panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	pause_menu_panel.add_child(vbox)

	var title := Label.new()
	title.text = "ПАУЗА / МЕНЮ ИГРЫ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title)

	var btn_resume := Button.new()
	btn_resume.text = "ПРОДОЛЖИТЬ [ESC]"
	btn_resume.pressed.connect(toggle_pause_menu)
	vbox.add_child(btn_resume)

	var btn_lobby := Button.new()
	btn_lobby.text = "ВЫЙТИ В ЛОББИ"
	btn_lobby.pressed.connect(_on_return_to_lobby)
	vbox.add_child(btn_lobby)

func toggle_pause_menu() -> void:
	is_pause_open = !is_pause_open
	pause_menu_panel.visible = is_pause_open
	if is_pause_open:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_return_to_lobby() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if GameManager3D.instance:
		GameManager3D.instance.return_to_lobby()

func trigger_hitmarker() -> void:
	hitmarker_timer = 0.14
	if hitmarker_rect:
		hitmarker_rect.visible = true

func show_announcement(msg: String) -> void:
	if lbl_announcement:
		lbl_announcement.text = msg
		lbl_announcement.visible = true
		announcement_timer = 1.8

func add_killfeed_entry(killer: String, victim: String, weapon_str: String) -> void:
	if not killfeed_vbox:
		return
	var row := Label.new()
	row.text = "%s [%s] %s" % [killer, weapon_str, victim]
	row.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_theme_font_size_override("font_size", 11)
	row.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	killfeed_vbox.add_child(row)

	# Keep at most 6 entries
	while killfeed_vbox.get_child_count() > 6:
		var c := killfeed_vbox.get_child(0)
		killfeed_vbox.remove_child(c)
		c.queue_free()

	get_tree().create_timer(4.5).timeout.connect(func():
		if is_instance_valid(row):
			row.queue_free()
	)

func _update_stats() -> void:
	if not is_instance_valid(player_ref):
		return
	if lbl_health:
		lbl_health.text = str(int(player_ref.health))
		if player_ref.health < 30.0:
			lbl_health.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
		else:
			lbl_health.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))

	if lbl_armor:
		lbl_armor.text = str(int(player_ref.armor))

func _update_weapon_display() -> void:
	if not is_instance_valid(player_ref):
		return

	var idx: int = player_ref.active_weapon_idx
	var names: Dictionary = {
		1: "КЛИНОК", 2: "ДРОБОВИК", 3: "ПУЛЕМЕТ",
		4: "РОКЕТНИЦА", 5: "РЕЛЬСА", 6: "ПЛАЗМА"
	}
	if lbl_weapon_name:
		lbl_weapon_name.text = names.get(idx, "ОРУЖИЕ")

	if lbl_ammo:
		lbl_ammo.text = "INF" if idx == 1 else str(player_ref.ammo.get(idx, 0))

	# Highlight active weapon slot in bottom bar
	for k in weapon_slot_labels:
		var lbl: Label = weapon_slot_labels[k]
		if k == idx:
			lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		else:
			lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))

func update_match_status(time_left: float, a_p: float, a_c: bool, b_p: float, b_c: bool, c_p: float, c_c: bool) -> void:
	if lbl_timer:
		var mins: int = int(time_left) / 60
		var secs: int = int(time_left) % 60
		lbl_timer.text = "ВРЕМЯ МАТЧА: %02d:%02d" % [mins, secs]

	if lbl_sectors:
		var a_str := "ВЗЯТ" if a_c else ("%d%%" % int(absf(a_p) * 100.0))
		var b_str := "ВЗЯТ" if b_c else ("%d%%" % int(absf(b_p) * 100.0))
		var c_str := "ВЗЯТ" if c_c else ("%d%%" % int(absf(c_p) * 100.0))
		lbl_sectors.text = "[ А: %s ]   [ B: %s ]   [ C: %s ]" % [a_str, b_str, c_str]

func _process(delta: float) -> void:
	if hitmarker_timer > 0.0:
		hitmarker_timer -= delta
		if hitmarker_timer <= 0.0 and hitmarker_rect:
			hitmarker_rect.visible = false

	if announcement_timer > 0.0:
		announcement_timer -= delta
		if announcement_timer <= 0.0 and lbl_announcement:
			lbl_announcement.visible = false

	# TAB Scoreboard visibility
	if scoreboard_panel:
		scoreboard_panel.visible = Input.is_key_pressed(KEY_TAB)

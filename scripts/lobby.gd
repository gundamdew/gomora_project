class_name Lobby
extends Control

var txt_name: LineEdit
var txt_ip: LineEdit
var txt_port: LineEdit
var opt_team: OptionButton
var opt_class: OptionButton
var chk_bots: CheckBox

var btn_host: Button
var btn_join: Button
var btn_solo: Button
var btn_start: Button
var btn_copy_ip: Button
var btn_loopback_ip: Button
var btn_class_leech: Button
var btn_class_trooper: Button
var btn_class_raptor: Button
var btn_class_augur: Button

var lbl_status: Label
var lbl_local_ip: Label
var player_list_container: VBoxContainer
var lan_servers_container: VBoxContainer
var lobby_panel: PanelContainer

func _ready() -> void:
	_ensure_dmi_manager()
	_create_ui()
	_connect_network_signals()
	_update_local_ip()
	_on_team_changed(Globals.Team.BAAL_RED)
	_select_class("leech")
	if NetworkManager.instance:
		NetworkManager.instance.start_lan_listener()
	_check_command_line_args()

func _ensure_dmi_manager() -> Node:
	var dmi: Node = get_node_or_null("/root/DmiManager")
	if dmi == null and get_tree() and get_tree().root:
		dmi = get_tree().root.get_node_or_null("DmiManager")
		
	if dmi == null:
		var script = load("res://scripts/dmi_manager.gd")
		if script and script.can_instantiate():
			dmi = script.new()
			dmi.name = "DmiManager"
			if get_tree() and get_tree().root:
				get_tree().root.add_child(dmi)
			if not dmi.get("is_loaded"):
				dmi.call("load_dmi")
				
	return dmi

func _check_command_line_args() -> void:
	var all_args: Array[String] = []
	for a in OS.get_cmdline_args():
		all_args.append(a)
	for a in OS.get_cmdline_user_args():
		all_args.append(a)
		
	for i in range(all_args.size()):
		var arg := all_args[i]
		if arg == "--host":
			call_deferred("_on_host_pressed")
			break
		elif arg == "--join" and i + 1 < all_args.size():
			txt_ip.text = all_args[i + 1]
			call_deferred("_on_join_pressed")
			break

func _exit_tree() -> void:
	if NetworkManager.instance:
		NetworkManager.instance.stop_lan_listener()

func _connect_network_signals() -> void:
	if NetworkManager.instance:
		NetworkManager.instance.player_list_changed.connect(_on_player_list_updated)
		NetworkManager.instance.server_started.connect(_on_server_started)
		NetworkManager.instance.connected_to_server.connect(_on_connected_to_server)
		NetworkManager.instance.connection_failed.connect(_on_connection_failed)
		NetworkManager.instance.server_disconnected.connect(_on_server_disconnected)
		NetworkManager.instance.lan_servers_updated.connect(_on_lan_servers_updated)

func _update_local_ip() -> void:
	if not NetworkManager.instance:
		return
	var ips: Array[Dictionary] = NetworkManager.instance.get_all_usable_ips()
	var text_lines := ""
	for item in ips:
		text_lines += "%s: %s  " % [item["desc"], item["ip"]]
	lbl_local_ip.text = text_lines.strip_edges()

func _create_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# Dark tactical background
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.08, 0.09, 0.11)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	lobby_panel = PanelContainer.new()
	lobby_panel.custom_minimum_size = Vector2(680, 780)
	center.add_child(lobby_panel)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.custom_minimum_size = Vector2(660, 760)
	lobby_panel.add_child(scroll)

	var main_vbox := VBoxContainer.new()
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(main_vbox)

	# Title
	var lbl_title := Label.new()
	lbl_title.text = "QUAKE 3D: PROJECT GOMORA"
	lbl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_title.add_theme_font_size_override("font_size", 22)
	lbl_title.add_theme_color_override("font_color", Color(1.0, 0.45, 0.2))
	main_vbox.add_child(lbl_title)

	var lbl_sub := Label.new()
	lbl_sub.text = "Классический 3D Арена-Шутер в стиле Quake | Мультиплеер & LAN"
	lbl_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_sub.add_theme_font_size_override("font_size", 12)
	lbl_sub.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	main_vbox.add_child(lbl_sub)

	# Local IP + Copy Button row
	var ip_row := HBoxContainer.new()
	ip_row.alignment = BoxContainer.ALIGNMENT_CENTER
	ip_row.add_theme_constant_override("separation", 8)
	main_vbox.add_child(ip_row)

	lbl_local_ip = Label.new()
	lbl_local_ip.text = "Локальный IP..."
	lbl_local_ip.add_theme_font_size_override("font_size", 8)
	lbl_local_ip.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	ip_row.add_child(lbl_local_ip)

	btn_copy_ip = Button.new()
	btn_copy_ip.text = "СКОПИРОВАТЬ IP"
	btn_copy_ip.add_theme_font_size_override("font_size", 7)
	btn_copy_ip.pressed.connect(func():
		var my_ip: String = NetworkManager.instance.get_local_ip() if NetworkManager.instance else "127.0.0.1"
		DisplayServer.clipboard_set(my_ip)
		lbl_status.text = "IP %s скопирован в буфер обмена!" % my_ip
	)
	ip_row.add_child(btn_copy_ip)

	main_vbox.add_child(HSeparator.new())

	# Settings Form
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 4)
	main_vbox.add_child(grid)

	# Name
	var l_name := Label.new()
	l_name.text = "Позывной:"
	l_name.add_theme_font_size_override("font_size", 8)
	grid.add_child(l_name)
	txt_name = LineEdit.new()
	txt_name.text = "Боец_%d" % randi_range(10, 99)
	txt_name.add_theme_font_size_override("font_size", 8)
	txt_name.text_changed.connect(func(new_text: String):
		if NetworkManager.instance:
			NetworkManager.instance.set_local_name(new_text.strip_edges())
	)
	grid.add_child(txt_name)

	# Team
	var l_team := Label.new()
	l_team.text = "Сторона:"
	l_team.add_theme_font_size_override("font_size", 8)
	grid.add_child(l_team)
	opt_team = OptionButton.new()
	opt_team.add_item("Армия Баала (Красные, Штурм)", 0)
	opt_team.add_item("Армия Молоха (Синие, Оборона)", 1)
	opt_team.add_theme_font_size_override("font_size", 8)
	opt_team.item_selected.connect(func(idx: int):
		var t: Globals.Team = Globals.Team.BAAL_RED if idx == 0 else Globals.Team.MOLOCH_BLUE
		if NetworkManager.instance:
			NetworkManager.instance.set_local_team(t)
		_on_team_changed(t)
	)
	grid.add_child(opt_team)

	# Class
	var l_class := Label.new()
	l_class.text = "Класс:"
	l_class.add_theme_font_size_override("font_size", 8)
	grid.add_child(l_class)
	opt_class = OptionButton.new()
	opt_class.add_theme_font_size_override("font_size", 8)
	opt_class.item_selected.connect(func(idx: int):
		var cur_team: Globals.Team = Globals.Team.BAAL_RED if opt_team.selected == 0 else Globals.Team.MOLOCH_BLUE
		var sel_id: String = "leech"
		if cur_team == Globals.Team.BAAL_RED:
			match idx:
				0: sel_id = "leech"
				1: sel_id = "trooper"
				2: sel_id = "raptor"
		else:
			match idx:
				0: sel_id = "leech"
				1: sel_id = "trooper"
				2: sel_id = "augur"
		_select_class(sel_id)
	)
	grid.add_child(opt_class)

	# IP
	var l_ip := Label.new()
	l_ip.text = "IP Сервера (LAN):"
	l_ip.add_theme_font_size_override("font_size", 8)
	grid.add_child(l_ip)
	
	var ip_box := HBoxContainer.new()
	grid.add_child(ip_box)
	txt_ip = LineEdit.new()
	txt_ip.text = "127.0.0.1"
	txt_ip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	txt_ip.add_theme_font_size_override("font_size", 8)
	ip_box.add_child(txt_ip)

	btn_loopback_ip = Button.new()
	btn_loopback_ip.text = "127.0.0.1"
	btn_loopback_ip.add_theme_font_size_override("font_size", 7)
	btn_loopback_ip.pressed.connect(func(): txt_ip.text = "127.0.0.1")
	ip_box.add_child(btn_loopback_ip)

	# Port
	var l_port := Label.new()
	l_port.text = "Порт:"
	l_port.add_theme_font_size_override("font_size", 8)
	grid.add_child(l_port)
	txt_port = LineEdit.new()
	txt_port.text = "7777"
	txt_port.add_theme_font_size_override("font_size", 8)
	grid.add_child(txt_port)

	# Bots checkbox
	chk_bots = CheckBox.new()
	chk_bots.text = "Заполнить пустые места ботами"
	chk_bots.button_pressed = true
	chk_bots.add_theme_font_size_override("font_size", 8)
	main_vbox.add_child(chk_bots)

	# Buttons Row
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 6)
	main_vbox.add_child(btn_row)

	btn_host = Button.new()
	btn_host.text = "СОЗДАТЬ СЕРВЕР"
	btn_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_host.add_theme_font_size_override("font_size", 9)
	btn_host.pressed.connect(_on_host_pressed)
	btn_row.add_child(btn_host)

	btn_join = Button.new()
	btn_join.text = "ПОДКЛЮЧИТЬСЯ"
	btn_join.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_join.add_theme_font_size_override("font_size", 9)
	btn_join.pressed.connect(_on_join_pressed)
	btn_row.add_child(btn_join)

	btn_solo = Button.new()
	btn_solo.text = "ОДИНОЧНЫЙ"
	btn_solo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_solo.add_theme_font_size_override("font_size", 9)
	btn_solo.pressed.connect(_on_solo_pressed)
	btn_row.add_child(btn_solo)

	# Status Label
	lbl_status = Label.new()
	lbl_status.text = "Готов к подключению"
	lbl_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_status.add_theme_font_size_override("font_size", 8)
	main_vbox.add_child(lbl_status)

	# DMI Skins Status
	var lbl_dmi_info := Label.new()
	var dmi_mgr := _ensure_dmi_manager()

	if dmi_mgr:
		if dmi_mgr.has_method("get_loaded_status_text"):
			lbl_dmi_info.text = str(dmi_mgr.call("get_loaded_status_text"))
			if dmi_mgr.get("is_loaded") == true:
				lbl_dmi_info.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
			else:
				lbl_dmi_info.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
		else:
			lbl_dmi_info.text = "DMI: модуль загружен"
			lbl_dmi_info.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
	else:
		lbl_dmi_info.text = "Спрайты DMI: не удалось загрузить res://scripts/dmi_manager.gd"
		lbl_dmi_info.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	lbl_dmi_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_dmi_info.add_theme_font_size_override("font_size", 7)
	main_vbox.add_child(lbl_dmi_info)

	main_vbox.add_child(HSeparator.new())

	# Discovered LAN Servers Section
	var lbl_lan := Label.new()
	lbl_lan.text = "Серверы в локальной сети (Автопоиск LAN):"
	lbl_lan.add_theme_font_size_override("font_size", 8)
	lbl_lan.add_theme_color_override("font_color", Color(0.4, 0.9, 0.6))
	main_vbox.add_child(lbl_lan)

	lan_servers_container = VBoxContainer.new()
	lan_servers_container.add_theme_constant_override("separation", 2)
	main_vbox.add_child(lan_servers_container)
	_on_lan_servers_updated()

	main_vbox.add_child(HSeparator.new())

	# Quick class toggle bar in lobby
	var lbl_class_bar := Label.new()
	lbl_class_bar.text = "СМЕНА ВАШЕГО КЛАССА В ЛОББИ:"
	lbl_class_bar.add_theme_font_size_override("font_size", 8)
	lbl_class_bar.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	main_vbox.add_child(lbl_class_bar)

	var class_row := HBoxContainer.new()
	class_row.add_theme_constant_override("separation", 6)
	main_vbox.add_child(class_row)

	btn_class_leech = Button.new()
	btn_class_leech.text = "🩸 Пиявка"
	btn_class_leech.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_class_leech.add_theme_font_size_override("font_size", 8)
	btn_class_leech.pressed.connect(func(): _select_class("leech"))
	class_row.add_child(btn_class_leech)

	btn_class_trooper = Button.new()
	btn_class_trooper.text = "🛡️ Десантник"
	btn_class_trooper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_class_trooper.add_theme_font_size_override("font_size", 8)
	btn_class_trooper.pressed.connect(func(): _select_class("trooper"))
	class_row.add_child(btn_class_trooper)

	btn_class_raptor = Button.new()
	btn_class_raptor.text = "⚡ Раптор [СПЕЦ]"
	btn_class_raptor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_class_raptor.add_theme_font_size_override("font_size", 8)
	btn_class_raptor.pressed.connect(func(): _select_class("raptor"))
	class_row.add_child(btn_class_raptor)

	btn_class_augur = Button.new()
	btn_class_augur.text = "👁️ Авгур [СПЕЦ]"
	btn_class_augur.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_class_augur.add_theme_font_size_override("font_size", 8)
	btn_class_augur.pressed.connect(func(): _select_class("augur"))
	class_row.add_child(btn_class_augur)

	# Connected Players List
	var lbl_pl := Label.new()
	lbl_pl.text = "Игроки в лобби:"
	lbl_pl.add_theme_font_size_override("font_size", 8)
	main_vbox.add_child(lbl_pl)

	player_list_container = VBoxContainer.new()
	player_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(player_list_container)

	# Start Match Button
	btn_start = Button.new()
	btn_start.text = "НАЧАТЬ МАТЧ"
	btn_start.custom_minimum_size = Vector2(0, 26)
	btn_start.add_theme_font_size_override("font_size", 10)
	btn_start.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
	btn_start.disabled = true
	btn_start.pressed.connect(_on_start_pressed)
	main_vbox.add_child(btn_start)

func _sync_inputs_to_manager() -> void:
	if not NetworkManager.instance:
		return
	NetworkManager.instance.local_player_name = txt_name.text.strip_edges()
	var t: Globals.Team = Globals.Team.BAAL_RED if opt_team.selected == 0 else Globals.Team.MOLOCH_BLUE
	NetworkManager.instance.local_team = t
	var sel_c: String = "leech"
	if t == Globals.Team.BAAL_RED:
		match opt_class.selected:
			0: sel_c = "leech"
			1: sel_c = "trooper"
			2: sel_c = "raptor"
			_: sel_c = "leech"
	else:
		match opt_class.selected:
			0: sel_c = "leech"
			1: sel_c = "trooper"
			2: sel_c = "augur"
			_: sel_c = "leech"
	NetworkManager.instance.local_class_id = sel_c
	NetworkManager.instance.fill_with_bots = chk_bots.button_pressed

func _on_host_pressed() -> void:
	_sync_inputs_to_manager()
	var port: int = int(txt_port.text)
	if port <= 0:
		port = NetworkManager.DEFAULT_PORT
	lbl_status.text = "Запуск локального сервера на порту %d..." % port
	var err: Error = NetworkManager.instance.start_host(port)
	if err == OK:
		lbl_status.text = "Сервер успешно создан! Вещание в LAN активно..."
		btn_host.disabled = true
		btn_join.disabled = true
		btn_solo.disabled = true
		btn_start.disabled = false
	else:
		lbl_status.text = "Ошибка создания сервера: %s" % err

func _on_join_pressed() -> void:
	_sync_inputs_to_manager()
	var ip: String = txt_ip.text.strip_edges()
	var port: int = int(txt_port.text)
	if ip.is_empty():
		ip = "127.0.0.1"
	if port <= 0:
		port = NetworkManager.DEFAULT_PORT
	lbl_status.text = "Подключение к %s:%d..." % [ip, port]
	btn_join.disabled = true
	var err: Error = NetworkManager.instance.start_client(ip, port)
	if err != OK:
		lbl_status.text = "Не удалось инициировать подключение: %s" % err
		btn_join.disabled = false

func _on_solo_pressed() -> void:
	_sync_inputs_to_manager()
	lbl_status.text = "Запуск одиночной игры с ботами..."
	NetworkManager.instance.start_solo()
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_start_pressed() -> void:
	if NetworkManager.instance and NetworkManager.instance.is_host:
		NetworkManager.instance.rpc("rpc_start_game")

# Signal Listeners
func _on_server_started() -> void:
	_update_player_list_ui()

func _on_connected_to_server() -> void:
	lbl_status.text = "Подключено к серверу! Ожидание старта хостом..."
	btn_host.disabled = true
	btn_join.disabled = true
	btn_solo.disabled = true
	btn_start.disabled = true

func _on_connection_failed() -> void:
	lbl_status.text = "Не удалось подключиться к серверу!"
	btn_join.disabled = false

func _on_server_disconnected() -> void:
	lbl_status.text = "Сервер разорвал соединение."
	btn_host.disabled = false
	btn_join.disabled = false
	btn_solo.disabled = false
	btn_start.disabled = true
	_update_player_list_ui()

func _on_player_list_updated() -> void:
	_update_player_list_ui()

func _on_lan_servers_updated() -> void:
	for child in lan_servers_container.get_children():
		child.queue_free()

	if not NetworkManager.instance or NetworkManager.instance.discovered_servers.is_empty():
		var lbl_empty := Label.new()
		lbl_empty.text = "  (Серверы в локальной сети пока не обнаружены)"
		lbl_empty.add_theme_font_size_override("font_size", 7)
		lbl_empty.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		lan_servers_container.add_child(lbl_empty)
		return

	for key in NetworkManager.instance.discovered_servers:
		var s: Dictionary = NetworkManager.instance.discovered_servers[key]
		var h_box := HBoxContainer.new()
		h_box.add_theme_constant_override("separation", 6)
		lan_servers_container.add_child(h_box)

		var s_lbl := Label.new()
		s_lbl.text = "• %s (%s:%d) [Игроков: %d]" % [s.get("name", "Сервер"), s.get("ip", "127.0.0.1"), s.get("port", 7777), s.get("players", 1)]
		s_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s_lbl.add_theme_font_size_override("font_size", 8)
		s_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.3))
		h_box.add_child(s_lbl)

		var s_btn := Button.new()
		s_btn.text = "ПОДКЛЮЧИТЬСЯ"
		s_btn.add_theme_font_size_override("font_size", 7)
		s_btn.pressed.connect(func():
			txt_ip.text = s.get("ip", "127.0.0.1")
			txt_port.text = str(s.get("port", 7777))
			_on_join_pressed()
		)
		h_box.add_child(s_btn)

func _on_team_changed(t: Globals.Team) -> void:
	if not opt_class:
		return
	var cur_class := "leech"
	if NetworkManager.instance:
		cur_class = NetworkManager.instance.local_class_id

	opt_class.clear()
	opt_class.add_item("Пиявка (Рядовой: Mk.Ultra, 2 пистолета, Перекат)", 0)
	opt_class.add_item("Десантник (Рядовой: Wagner, Нож Fatwa)", 1)
	if t == Globals.Team.BAAL_RED:
		opt_class.add_item("⚡ Раптор [СПЕЦИАЛИСТ БААЛА] (Ghetta, Cossack, Уклонение 15, Смертовизор)", 2)
		if cur_class == "augur":
			cur_class = "raptor"
	else:
		opt_class.add_item("👁️ Авгур [СПЕЦИАЛИСТ МОЛОХА] (Templum, Blaster, Смертовизор, Покров)", 2)
		if cur_class == "raptor":
			cur_class = "augur"

	_select_class(cur_class)

func _select_class(class_id: String) -> void:
	var cur_team: Globals.Team = Globals.Team.BAAL_RED
	if opt_team:
		cur_team = Globals.Team.BAAL_RED if opt_team.selected == 0 else Globals.Team.MOLOCH_BLUE
	elif NetworkManager.instance:
		cur_team = NetworkManager.instance.local_team

	# Augur is only available for Moloch (Blue); Raptor is only available for Baal (Red)
	if class_id == "raptor" and cur_team != Globals.Team.BAAL_RED:
		if lbl_status: lbl_status.text = "Раптор доступен ТОЛЬКО для Армии Баала (Красные)!"
		return
	if class_id == "augur" and cur_team != Globals.Team.MOLOCH_BLUE:
		if lbl_status: lbl_status.text = "Авгур доступен ТОЛЬКО для Армии Молоха (Синие)!"
		return

	if opt_class:
		if cur_team == Globals.Team.BAAL_RED:
			match class_id:
				"leech": opt_class.selected = 0
				"trooper": opt_class.selected = 1
				"raptor": opt_class.selected = 2
				_: opt_class.selected = 0
		else:
			match class_id:
				"leech": opt_class.selected = 0
				"trooper": opt_class.selected = 1
				"augur": opt_class.selected = 2
				_: opt_class.selected = 0
		
	_update_class_buttons_visual(class_id)
	
	if NetworkManager.instance:
		NetworkManager.instance.set_local_class(class_id)
		
	var c_name := "Пиявка"
	match class_id:
		"leech": c_name = "Пиявка (Рядовой легкий)"
		"trooper": c_name = "Десантник (Рядовой средний)"
		"raptor": c_name = "Раптор [СПЕЦИАЛИСТ БААЛА]"
		"augur": c_name = "Авгур [СПЕЦИАЛИСТ МОЛОХА]"
	if lbl_status:
		lbl_status.text = "Выбран класс: %s" % c_name

func _update_class_buttons_visual(class_id: String) -> void:
	if not btn_class_leech or not btn_class_trooper:
		return
	var act_col := Color(0.2, 1.0, 0.4)
	var inact_col := Color(0.7, 0.7, 0.7)
	var disabled_col := Color(0.42, 0.45, 0.50)

	var cur_team: Globals.Team = Globals.Team.BAAL_RED
	if opt_team:
		cur_team = Globals.Team.BAAL_RED if opt_team.selected == 0 else Globals.Team.MOLOCH_BLUE
	elif NetworkManager.instance:
		cur_team = NetworkManager.instance.local_team

	btn_class_leech.add_theme_color_override("font_color", act_col if class_id == "leech" else inact_col)
	btn_class_leech.text = "🩸 [ПИЯВКА]" if class_id == "leech" else "🩸 Пиявка"
	btn_class_leech.disabled = false

	btn_class_trooper.add_theme_color_override("font_color", act_col if class_id == "trooper" else inact_col)
	btn_class_trooper.text = "🛡️ [ДЕСАНТНИК]" if class_id == "trooper" else "🛡️ Десантник"
	btn_class_trooper.disabled = false

	# Raptor only available for Baal (Red)
	if btn_class_raptor:
		if cur_team == Globals.Team.BAAL_RED:
			btn_class_raptor.disabled = false
			btn_class_raptor.add_theme_color_override("font_color", act_col if class_id == "raptor" else inact_col)
			btn_class_raptor.text = "⚡ [РАПТОР]" if class_id == "raptor" else "⚡ Раптор [СПЕЦ]"
		else:
			btn_class_raptor.disabled = true
			btn_class_raptor.add_theme_color_override("font_color", disabled_col)
			btn_class_raptor.text = "🔒 Раптор (Только Баал)"

	# Augur only available for Moloch (Blue)
	if btn_class_augur:
		if cur_team == Globals.Team.MOLOCH_BLUE:
			btn_class_augur.disabled = false
			btn_class_augur.add_theme_color_override("font_color", act_col if class_id == "augur" else inact_col)
			btn_class_augur.text = "👁️ [АВГУР]" if class_id == "augur" else "👁️ Авгур [СПЕЦ]"
		else:
			btn_class_augur.disabled = true
			btn_class_augur.add_theme_color_override("font_color", disabled_col)
			btn_class_augur.text = "🔒 Авгур (Только Молох)"

func _update_player_list_ui() -> void:
	for child in player_list_container.get_children():
		child.queue_free()

	if not NetworkManager.instance:
		return

	var my_id: int = multiplayer.get_unique_id() if (multiplayer and multiplayer.has_multiplayer_peer()) else 1

	for peer_id in NetworkManager.instance.players:
		var p_info: Dictionary = NetworkManager.instance.players[peer_id]
		var h_box := HBoxContainer.new()
		h_box.add_theme_constant_override("separation", 6)
		player_list_container.add_child(h_box)

		var is_me: bool = (peer_id == my_id)
		var host_str: String = " (Хост)" if peer_id == 1 else ""
		var me_str: String = " [ВЫ]" if is_me else ""
		var team_str: String = "[БААЛ (КРАСНЫЕ)]" if p_info["team"] == Globals.Team.BAAL_RED else "[МОЛОХ (СИНИЕ)]"
		var class_str: String = "Пиявка"
		match p_info["class_id"]:
			"leech": class_str = "Пиявка"
			"trooper": class_str = "Десантник"
			"raptor": class_str = "Раптор [СПЕЦ БААЛА]"
			"augur": class_str = "Авгур [СПЕЦ МОЛОХА]"
			_: class_str = p_info["class_id"]

		var lbl := Label.new()
		lbl.text = "• %s%s%s - %s - Класс: [%s]" % [p_info["name"], host_str, me_str, team_str, class_str]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_font_size_override("font_size", 8)
		if p_info["team"] == Globals.Team.BAAL_RED:
			lbl.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
		else:
			lbl.add_theme_color_override("font_color", Color(0.45, 0.75, 1.0))
		h_box.add_child(lbl)

		if is_me:
			var btn_cycle := Button.new()
			btn_cycle.text = "Сменить класс"
			btn_cycle.add_theme_font_size_override("font_size", 7)
			btn_cycle.pressed.connect(func():
				var classes := ["leech", "trooper", "raptor"] if p_info["team"] == Globals.Team.BAAL_RED else ["leech", "trooper", "augur"]
				var cur_idx := classes.find(p_info["class_id"])
				if cur_idx == -1: cur_idx = 0
				var next_c: String = classes[(cur_idx + 1) % classes.size()]
				_select_class(next_c)
			)
			h_box.add_child(btn_cycle)
			
			_update_class_buttons_visual(p_info["class_id"])

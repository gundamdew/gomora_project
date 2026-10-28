class_name GameManager3D
extends Node3D

static var instance: GameManager3D

var map_gen: MapGenerator3D
var hud: HUD3D
var local_player: Player3D

var players_container: Node3D
var bots_container: Node3D

# Match settings
var round_timer: float = 180.0
var is_game_over: bool = false
var winner_team: Globals.Team = Globals.Team.BAAL_RED

# 3D Spawn Bases
var red_spawn_base := Vector3(-28.0, 5.0, 0.0)
var blue_spawn_base := Vector3(28.0, 5.0, 0.0)

var bot_counter: int = 0
var respawn_timer: float = 4.0
var _sync_timer: float = 0.0
var _bot_sync_timer: float = 0.0

func _init() -> void:
	instance = self

func _ready() -> void:
	map_gen = MapGenerator3D.new()
	add_child(map_gen)

	players_container = Node3D.new()
	players_container.name = "Players"
	add_child(players_container)

	bots_container = Node3D.new()
	bots_container.name = "Bots"
	add_child(bots_container)

	# Connect 3D capture zones
	map_gen.zone_a.sector_captured.connect(_on_zone_a_captured)
	map_gen.zone_b.sector_captured.connect(_on_zone_b_captured)
	map_gen.zone_c.sector_captured.connect(_on_zone_c_captured)

	_spawn_all_players()

	# If host or solo, spawn initial bots
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		_spawn_initial_bots()

	hud = HUD3D.new()
	add_child(hud)
	if local_player:
		hud.setup(local_player)

func _spawn_all_players() -> void:
	var my_id: int = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	var players_dict: Dictionary = {}
	if NetworkManager.instance and not NetworkManager.instance.players.is_empty():
		players_dict = NetworkManager.instance.players
	else:
		players_dict[1] = {
			"name": "Боец",
			"team": Globals.Team.BAAL_RED,
			"class_id": "leech"
		}

	var player_script = load("res://scripts/player_3d.gd")
	for p_id in players_dict:
		var p_info: Dictionary = players_dict[p_id]
		var p: Player3D = player_script.new()
		p.name = "Player_%d" % p_id
		p.peer_id = p_id
		p.set_multiplayer_authority(p_id)
		p.team = p_info.get("team", Globals.Team.BAAL_RED) as Globals.Team
		p.unit_name = p_info.get("name", "Игрок %d" % p_id)

		var c_id: String = p_info.get("class_id", "leech")
		match c_id:
			"trooper": p.class_data = ClassData.create_trooper()
			"raptor": p.class_data = ClassData.create_raptor()
			"augur": p.class_data = ClassData.create_augur()
			_: p.class_data = ClassData.create_leech()

		var base_pos: Vector3 = red_spawn_base if p.team == Globals.Team.BAAL_RED else blue_spawn_base
		var spawn_pos: Vector3 = base_pos + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3))
		p.position = spawn_pos
		p.unit_died.connect(_on_player_died)

		players_container.add_child(p)

		if p_id == my_id:
			local_player = p

func _spawn_initial_bots() -> void:
	var fill_bots: bool = NetworkManager.instance.fill_with_bots if NetworkManager.instance else true
	if not fill_bots:
		return

	var red_humans: int = 0
	var blue_humans: int = 0
	if NetworkManager.instance:
		for p_id in NetworkManager.instance.players:
			if NetworkManager.instance.players[p_id]["team"] == Globals.Team.BAAL_RED:
				red_humans += 1
			else:
				blue_humans += 1

	var red_needed: int = maxi(1, 4 - red_humans)
	var blue_needed: int = maxi(1, 4 - blue_humans)

	for i in range(red_needed):
		_spawn_bot(Globals.Team.BAAL_RED, red_spawn_base)
	for i in range(blue_needed):
		_spawn_bot(Globals.Team.MOLOCH_BLUE, blue_spawn_base)

func _spawn_bot(team: Globals.Team, base_pos: Vector3) -> void:
	bot_counter += 1
	var b_name := "Bot_%d" % bot_counter
	var spawn_pos := base_pos + Vector3(randf_range(-4, 4), 0, randf_range(-4, 4))

	var bot_script = load("res://scripts/bot_3d.gd")
	if bot_script:
		var bot: Bot3D = bot_script.new()
		bot.name = b_name
		bot.unit_name = b_name
		bot.team = team
		bot.class_data = ClassData.create_leech() if team == Globals.Team.BAAL_RED else ClassData.create_trooper()
		bot.position = spawn_pos
		if map_gen:
			bot.current_objective_pos = map_gen.get_active_objective_position()
		bot.unit_died.connect(_on_bot_died)
		bots_container.add_child(bot)

func _physics_process(delta: float) -> void:
	if is_game_over:
		if Input.is_physical_key_pressed(KEY_R):
			return_to_lobby()
		return

	# Host / Solo simulates match timer & objectives
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		round_timer -= delta
		if round_timer <= 0.0:
			round_timer = 0.0
			_end_game(Globals.Team.MOLOCH_BLUE)

		var active_obj: Vector3 = map_gen.get_active_objective_position()
		var bots := get_tree().get_nodes_in_group("bots")
		for b in bots:
			if is_instance_valid(b) and b is Bot3D and not b.is_dead:
				b.current_objective_pos = active_obj

		respawn_timer -= delta
		if respawn_timer <= 0.0:
			respawn_timer = 5.0
			_maintain_bot_counts()

		# Broadcast match state to peers
		if multiplayer.has_multiplayer_peer():
			_sync_timer -= delta
			if _sync_timer <= 0.0:
				_sync_timer = 0.25
				rpc("rpc_sync_match_state",
					round_timer,
					map_gen.zone_a.capture_progress, map_gen.zone_a.is_captured,
					map_gen.zone_b.capture_progress, map_gen.zone_b.is_captured,
					map_gen.zone_c.capture_progress, map_gen.zone_c.is_captured
				)

			# Sync bot positions to clients (20 Hz)
			_bot_sync_timer -= delta
			if _bot_sync_timer <= 0.0:
				_bot_sync_timer = 0.05
				_sync_bots_to_clients()

	# Local HUD update
	if hud and map_gen:
		hud.update_match_status(
			round_timer,
			map_gen.zone_a.capture_progress, map_gen.zone_a.is_captured,
			map_gen.zone_b.capture_progress, map_gen.zone_b.is_captured,
			map_gen.zone_c.capture_progress, map_gen.zone_c.is_captured
		)

func _sync_bots_to_clients() -> void:
	var bot_list: Array = []
	var bots := get_tree().get_nodes_in_group("bots")
	for b in bots:
		if is_instance_valid(b) and b is Bot3D and not b.is_dead:
			bot_list.append({
				"name": b.name,
				"team": int(b.team),
				"pos": b.global_position,
				"yaw": b.rotation.y,
				"hp": b.health,
				"ap": b.armor
			})
	if not bot_list.is_empty():
		rpc("rpc_sync_bots", bot_list)

func _maintain_bot_counts() -> void:
	var fill_bots: bool = NetworkManager.instance.fill_with_bots if NetworkManager.instance else true
	if not fill_bots:
		return

	var red_count: int = 0
	var blue_count: int = 0
	var units := get_tree().get_nodes_in_group("units")
	for u in units:
		if is_instance_valid(u) and not u.is_dead and (u is Unit3D):
			if u.team == Globals.Team.BAAL_RED:
				red_count += 1
			elif u.team == Globals.Team.MOLOCH_BLUE:
				blue_count += 1

	if red_count < 4:
		_spawn_bot(Globals.Team.BAAL_RED, red_spawn_base)
	if blue_count < 4:
		_spawn_bot(Globals.Team.MOLOCH_BLUE, blue_spawn_base)

func _on_zone_a_captured(zone: Node) -> void:
	round_timer += 60.0
	map_gen.zone_b.is_active = true
	if hud:
		hud.show_announcement("СЕКТОР А ВЗЯТ! АКТИВИРОВАН СЕКТОР B!")

func _on_zone_b_captured(zone: Node) -> void:
	round_timer += 60.0
	map_gen.zone_c.is_active = true
	if hud:
		hud.show_announcement("СЕКТОР B ВЗЯТ! АКТИВИРОВАН СЕКТОР C!")

func _on_zone_c_captured(zone: Node) -> void:
	_end_game(Globals.Team.BAAL_RED)

func _on_bot_died(b: Unit3D, by_headshot: bool) -> void:
	if hud:
		var w_str := "ХЕДШОТ!" if by_headshot else "ОРУЖИЕ"
		hud.add_killfeed_entry("Игрок", b.unit_name, w_str)

func _on_player_died(p: Unit3D, by_headshot: bool) -> void:
	if hud:
		var w_str := "ХЕДШОТ!" if by_headshot else "ФРАГ"
		hud.add_killfeed_entry("Враг", p.unit_name, w_str)

	if p == local_player:
		if hud:
			hud.show_announcement("ВЫ ПОГИБЛИ! ВОЗРОЖДЕНИЕ ЧЕРЕЗ 3 СЕКУНДЫ...")
		await get_tree().create_timer(3.0).timeout
		if not is_game_over:
			_respawn_local_player()

func _respawn_local_player() -> void:
	var base_pos: Vector3 = red_spawn_base if local_player.team == Globals.Team.BAAL_RED else blue_spawn_base
	var spawn_pos := base_pos + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3))

	# Re-create player node
	var player_script = load("res://scripts/player_3d.gd")
	var p: Player3D = player_script.new()
	var my_id: int = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	p.name = "Player_Local"
	p.peer_id = my_id
	p.set_multiplayer_authority(my_id)
	p.team = local_player.team
	p.class_data = local_player.class_data
	p.position = spawn_pos
	p.unit_died.connect(_on_player_died)
	players_container.add_child(p)

	local_player = p
	if hud:
		hud.setup(local_player)
	if AudioManager.instance:
		AudioManager.instance.play_sfx(AudioManager.instance.sfx_teleport, 2.0)

func _end_game(winner: Globals.Team) -> void:
	is_game_over = true
	winner_team = winner
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		rpc("rpc_game_over", int(winner))
	_show_game_over_screen(winner)

func _show_game_over_screen(winner: Globals.Team) -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)

	var center_box := CenterContainer.new()
	center_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(center_box)

	var panel := PanelContainer.new()
	center_box.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	var lbl_title := Label.new()
	if winner == Globals.Team.BAAL_RED:
		lbl_title.text = "ПОБЕДА: АРМИЯ БААЛА (КРАСНЫЕ) ЗАХВАТИЛА ВСЕ СЕКТОРЫ!"
		lbl_title.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	else:
		lbl_title.text = "ПОБЕДА: АРМИЯ МОЛОХА (СИНИЕ) УСПЕШНО ОТБИЛА ШТУРМ!"
		lbl_title.add_theme_color_override("font_color", Color(0.3, 0.6, 1.0))
	lbl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(lbl_title)

	var btn_lobby := Button.new()
	btn_lobby.text = "ВЕРНУТЬСЯ В ЛОББИ [R]"
	btn_lobby.add_theme_font_size_override("font_size", 14)
	btn_lobby.pressed.connect(return_to_lobby)
	vbox.add_child(btn_lobby)

func return_to_lobby() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if NetworkManager.instance:
		NetworkManager.instance.stop_multiplayer()
	get_tree().change_scene_to_file("res://scenes/lobby.tscn")

# ----------------- MULTIPLAYER 3D RPCs -----------------

@rpc("authority", "call_remote", "unreliable")
func rpc_sync_match_state(time_left: float, a_p: float, a_c: bool, b_p: float, b_c: bool, c_p: float, c_c: bool) -> void:
	round_timer = time_left
	if map_gen:
		map_gen.zone_a.capture_progress = a_p
		map_gen.zone_a.is_captured = a_c
		map_gen.zone_b.capture_progress = b_p
		map_gen.zone_b.is_captured = b_c
		map_gen.zone_c.capture_progress = c_p
		map_gen.zone_c.is_captured = c_c

@rpc("authority", "call_remote", "reliable")
func rpc_game_over(winner_int: int) -> void:
	is_game_over = true
	winner_team = winner_int as Globals.Team
	_show_game_over_screen(winner_team)

@rpc("authority", "call_local", "reliable")
func rpc_spawn_bot_rocket(from_pos: Vector3, dir: Vector3, team_int: int) -> void:
	var p_script = load("res://scripts/projectile_3d.gd")
	if p_script:
		var p: Projectile3D = p_script.new()
		p.setup(from_pos, dir, Projectile3D.ProjectileType.ROCKET, 95.0, team_int as Globals.Team, 999)
		add_child(p)

@rpc("authority", "call_local", "unreliable")
func rpc_bot_tracer(from_pos: Vector3, to_pos: Vector3, type_int: int) -> void:
	var t_script = load("res://scripts/tracer_3d.gd")
	if t_script:
		var t: Tracer3D = t_script.new()
		t.setup(from_pos, to_pos, type_int as Tracer3D.TracerType)
		add_child(t)

@rpc("authority", "unreliable")
func rpc_sync_bots(bot_list: Array) -> void:
	if multiplayer.is_server():
		return
	var bot_script = load("res://scripts/bot_3d.gd")
	for b_data in bot_list:
		var b_name: String = b_data["name"]
		var bot_node: Bot3D = bots_container.get_node_or_null(b_name) as Bot3D
		if bot_node == null and bot_script:
			bot_node = bot_script.new()
			bot_node.name = b_name
			bot_node.unit_name = b_name
			bot_node.team = b_data["team"] as Globals.Team
			bot_node.position = b_data["pos"]
			bots_container.add_child(bot_node)

		if bot_node:
			bot_node.target_net_pos = b_data["pos"]
			bot_node.target_net_yaw = b_data["yaw"]
			bot_node.health = b_data["hp"]
			bot_node.armor = b_data["ap"]

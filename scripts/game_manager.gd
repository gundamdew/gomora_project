class_name GameManager
extends Node2D

static var instance: GameManager

var map_gen: MapGenerator
var hud: Node
var audio_mgr: AudioManager
var local_player: Player

var players_container: Node2D
var bots_container: Node2D

# Match settings
var round_timer: float = 180.0
var is_game_over: bool = false
var winner_team: Globals.Team = Globals.Team.BAAL_RED

# Wave / Reinforcements
var wave_number: int = 1
var red_casualties: int = 0
var blue_casualties: int = 0
var respawn_timer: float = 5.0
var bot_counter: int = 0

# Spawn positions (tile coordinates)
var red_spawn_base_tile := Vector2i(10, 50)
var blue_spawn_base_tile := Vector2i(90, 50)

var _sync_timer: float = 0.0

func _init() -> void:
	instance = self

func _ready() -> void:
	audio_mgr = AudioManager.new()
	add_child(audio_mgr)

	map_gen = MapGenerator.new()
	add_child(map_gen)

	players_container = Node2D.new()
	players_container.name = "Players"
	add_child(players_container)

	bots_container = Node2D.new()
	bots_container.name = "Bots"
	add_child(bots_container)

	# Connect capture zones
	map_gen.zone_a.zone_captured.connect(_on_zone_a_captured)
	map_gen.zone_b.zone_captured.connect(_on_zone_b_captured)
	map_gen.zone_c.zone_captured.connect(_on_zone_c_captured)

	_spawn_all_players()

	# If server or solo, spawn initial bots
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		_spawn_initial_bots()

	var hud_script = load("res://scripts/hud.gd")
	if hud_script and hud_script.can_instantiate():
		hud = hud_script.new()
		add_child(hud)
		if local_player and hud.has_method("setup"):
			hud.setup(local_player)
	else:
		print("ERROR: Could not instantiate res://scripts/hud.gd")

	# Initialize atmospheric dust storm (visual circle vision limit & blowing sand)
	var storm_script = load("res://scripts/dust_storm.gd")
	if storm_script and storm_script.can_instantiate():
		var dust_storm: Node2D = storm_script.new()
		add_child(dust_storm)
		if local_player and dust_storm.has_method("setup"):
			dust_storm.call("setup", local_player)

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

	var player_script = load("res://scripts/player.gd")
	for p_id in players_dict:
		var p_info: Dictionary = players_dict[p_id]
		var p: Player = (player_script.new() if (player_script and player_script.can_instantiate()) else Player.new())
		p.name = "Player_%d" % p_id
		p.peer_id = p_id
		p.set_multiplayer_authority(p_id)
		p.team = p_info["team"] as Globals.Team
		
		var c_id: String = p_info.get("class_id", "leech")
		if p.team == Globals.Team.BAAL_RED and c_id == "augur":
			c_id = "raptor"
		elif p.team == Globals.Team.MOLOCH_BLUE and c_id == "raptor":
			c_id = "augur"

		match c_id:
			"trooper": p.class_data = ClassData.create_trooper()
			"raptor": p.class_data = ClassData.create_raptor()
			"augur": p.class_data = ClassData.create_augur()
			_: p.class_data = ClassData.create_leech()

		var base_t: Vector2i = red_spawn_base_tile if p.team == Globals.Team.BAAL_RED else blue_spawn_base_tile
		var spawn_t := Vector2i(base_t.x + randi_range(-1, 1), base_t.y + randi_range(-1, 1))
		p.global_position = Globals.tile_to_world_center(spawn_t)
		p.unit_died.connect(_on_player_died)
		
		players_container.add_child(p)
		
		if p_id == my_id:
			local_player = p

func _spawn_initial_bots() -> void:
	var fill_bots: bool = NetworkManager.instance.fill_with_bots if NetworkManager.instance else true
	if not fill_bots:
		return

	# Count human players per team
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
		_spawn_bot(Globals.Team.BAAL_RED, red_spawn_base_tile)
	for i in range(blue_needed):
		_spawn_bot(Globals.Team.MOLOCH_BLUE, blue_spawn_base_tile)

func _spawn_bot(team: Globals.Team, base_tile: Vector2i) -> void:
	bot_counter += 1
	var b_name := "Bot_%d" % bot_counter
	var class_id := "leech"
	var r := randf()
	if team == Globals.Team.BAAL_RED:
		if wave_number == 1:
			class_id = "raptor" if r < 0.25 else "leech"
		else:
			if r < 0.35: class_id = "raptor"
			elif r < 0.70: class_id = "trooper"
			else: class_id = "leech"
	else:
		if wave_number == 1:
			class_id = "augur" if r < 0.25 else "leech"
		else:
			if r < 0.35: class_id = "augur"
			elif r < 0.70: class_id = "trooper"
			else: class_id = "leech"

	var spawn_t := Vector2i(base_tile.x + randi_range(-2, 2), base_tile.y + randi_range(-2, 2))
	
	if multiplayer.has_multiplayer_peer():
		rpc("rpc_spawn_bot", b_name, int(team), class_id, spawn_t)
	else:
		_create_bot_node(b_name, team, class_id, spawn_t)

@rpc("authority", "call_local", "reliable")
func rpc_spawn_bot(b_name: String, team_int: int, class_id: String, spawn_t: Vector2i) -> void:
	_create_bot_node(b_name, team_int as Globals.Team, class_id, spawn_t)

func _create_bot_node(b_name: String, team: Globals.Team, class_id: String, spawn_t: Vector2i) -> Bot:
	var bot_script = load("res://scripts/bot.gd")
	var bot: Bot = (bot_script.new() if (bot_script and bot_script.can_instantiate()) else Bot.new())
	bot.name = b_name
	bot.team = team
	if team == Globals.Team.BAAL_RED and class_id == "augur":
		class_id = "raptor"
	elif team == Globals.Team.MOLOCH_BLUE and class_id == "raptor":
		class_id = "augur"

	match class_id:
		"trooper": bot.class_data = ClassData.create_trooper()
		"raptor": bot.class_data = ClassData.create_raptor()
		"augur": bot.class_data = ClassData.create_augur()
		_: bot.class_data = ClassData.create_leech()
		
	bot.global_position = Globals.tile_to_world_center(spawn_t)
	if map_gen:
		bot.current_objective_pos = map_gen.get_active_objective_position()
	bot.unit_died.connect(_on_bot_died)
	bots_container.add_child(bot)
	return bot

func _physics_process(delta: float) -> void:
	if is_game_over:
		if Input.is_action_just_pressed("reload"):
			_return_to_lobby()
		return

	# Only server simulates match timer, objectives & bot spawns
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		round_timer -= delta
		if round_timer <= 0.0:
			round_timer = 0.0
			_end_game(Globals.Team.MOLOCH_BLUE)

		var active_obj: Vector2 = map_gen.get_active_objective_position()
		var bots := get_tree().get_nodes_in_group("bots")
		for b in bots:
			if is_instance_valid(b) and b is Bot and not b.is_dead:
				b.current_objective_pos = active_obj

		respawn_timer -= delta
		if respawn_timer <= 0.0:
			respawn_timer = 6.0
			_maintain_bot_counts()

		# Broadcast match status to peers
		if multiplayer.has_multiplayer_peer():
			_sync_timer -= delta
			if _sync_timer <= 0.0:
				_sync_timer = 0.25 # 4 Hz match status sync
				rpc("rpc_sync_match_state",
					round_timer,
					map_gen.zone_a.capture_progress, map_gen.zone_a.is_captured,
					map_gen.zone_b.capture_progress, map_gen.zone_b.is_captured,
					map_gen.zone_c.capture_progress, map_gen.zone_c.is_captured
				)

	# Local HUD update
	if hud and map_gen:
		hud.update_match_status(
			round_timer,
			map_gen.zone_a.capture_progress, map_gen.zone_a.is_captured,
			map_gen.zone_b.capture_progress, map_gen.zone_b.is_captured,
			map_gen.zone_c.capture_progress, map_gen.zone_c.is_captured
		)

func _maintain_bot_counts() -> void:
	var fill_bots: bool = NetworkManager.instance.fill_with_bots if NetworkManager.instance else true
	if not fill_bots:
		return

	var red_count: int = 0
	var blue_count: int = 0
	var units := get_tree().get_nodes_in_group("units")
	for u in units:
		if is_instance_valid(u) and u is Unit and not u.is_dead:
			if u.team == Globals.Team.BAAL_RED:
				red_count += 1
			elif u.team == Globals.Team.MOLOCH_BLUE:
				blue_count += 1

	if red_count < 4:
		_spawn_bot(Globals.Team.BAAL_RED, red_spawn_base_tile)
	if blue_count < 4:
		_spawn_bot(Globals.Team.MOLOCH_BLUE, blue_spawn_base_tile)

func _on_zone_a_captured(zone: CaptureZone) -> void:
	round_timer += 60.0
	map_gen.zone_b.is_active = true
	wave_number = maxi(wave_number, 2)

func _on_zone_b_captured(zone: CaptureZone) -> void:
	round_timer += 60.0
	map_gen.zone_c.is_active = true
	wave_number = maxi(wave_number, 3)

func _on_zone_c_captured(zone: CaptureZone) -> void:
	_end_game(Globals.Team.BAAL_RED)

func _on_bot_died(b: Unit, by_headshot: bool) -> void:
	if b.team == Globals.Team.BAAL_RED:
		red_casualties += 1
	else:
		blue_casualties += 1
		
	if (red_casualties + blue_casualties) >= 4 and wave_number == 1:
		wave_number = 2
	elif (red_casualties + blue_casualties) >= 10 and wave_number == 2:
		wave_number = 3

func _on_player_died(p: Unit, by_headshot: bool) -> void:
	if p == local_player:
		if hud:
			hud.show_respawn_countdown(3.0)
		await get_tree().create_timer(3.0).timeout
		if not is_game_over and is_instance_valid(local_player):
			var base_t: Vector2i = red_spawn_base_tile if local_player.team == Globals.Team.BAAL_RED else blue_spawn_base_tile
			var spawn_t := Vector2i(base_t.x + randi_range(-1, 1), base_t.y + randi_range(-1, 1))
			if multiplayer.has_multiplayer_peer():
				local_player.rpc("rpc_respawn", spawn_t)
			else:
				local_player.respawn(spawn_t)
			if hud:
				hud.setup(local_player)

func _end_game(winner: Globals.Team) -> void:
	is_game_over = true
	winner_team = winner
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
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)
	
	var lbl_title := Label.new()
	if winner == Globals.Team.BAAL_RED:
		lbl_title.text = "ПОБЕДА: АРМИЯ БААЛА (КРАСНЫЕ) ЗАХВАТИЛА ВСЕ СЕКТОРЫ!"
		lbl_title.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	else:
		lbl_title.text = "ПОБЕДА: АРМИЯ МОЛОХА (СИНИЕ) УСПЕШНО ОТБИЛА ШТУРМ!"
		lbl_title.add_theme_color_override("font_color", Color(0.3, 0.6, 1.0))
	lbl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_title.add_theme_font_size_override("font_size", 10)
	vbox.add_child(lbl_title)
	
	var btn_lobby := Button.new()
	btn_lobby.text = "ВЕРНУТЬСЯ В ЛОББИ [R]"
	btn_lobby.add_theme_font_size_override("font_size", 9)
	btn_lobby.pressed.connect(_return_to_lobby)
	vbox.add_child(btn_lobby)

func _return_to_lobby() -> void:
	if NetworkManager.instance:
		NetworkManager.instance.stop_multiplayer()
	get_tree().change_scene_to_file("res://scenes/lobby.tscn")

# ----------------- MULTIPLAYER MATCH RPCs -----------------

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

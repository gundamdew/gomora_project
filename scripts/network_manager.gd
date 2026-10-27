extends Node

signal player_list_changed
signal server_started
signal connected_to_server
signal connection_failed
signal server_disconnected
signal lan_servers_updated

const DEFAULT_PORT: int = 7777
const BROADCAST_PORT: int = 7778
const MAX_PLAYERS: int = 8

static var instance: NetworkManager

var enet_peer: ENetMultiplayerPeer
var is_host: bool = false
var is_solo: bool = false
var fill_with_bots: bool = true

# Connected players dictionary: { peer_id: { "name": String, "team": int, "class_id": String } }
var players: Dictionary = {}

# Local player settings chosen in lobby
var local_player_name: String = "Боец"
var local_team: Globals.Team = Globals.Team.BAAL_RED
var local_class_id: String = "leech"

# LAN Discovery
var udp_broadcaster: PacketPeerUDP
var udp_listener: PacketPeerUDP
var broadcast_timer: float = 0.0
var discovered_servers: Dictionary = {}

func _init() -> void:
	instance = self

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func _process(delta: float) -> void:
	_process_lan_broadcast(delta)
	_process_lan_listen()

func get_local_ip() -> String:
	var ips: PackedStringArray = IP.get_local_addresses()
	# First priority: Standard private Wi-Fi/Ethernet LAN subnets
	for ip in ips:
		if ip.contains(":"):
			continue
		if ip.begins_with("192.168.") or ip.begins_with("10."):
			return ip
		if ip.begins_with("172."):
			var parts := ip.split(".")
			if parts.size() >= 2:
				var sec := int(parts[1])
				if sec >= 16 and sec <= 31:
					return ip

	# Second priority: Other non-loopback IPv4 (e.g. Radmin VPN 26.x.x.x)
	for ip in ips:
		if not ip.contains(":") and ip != "127.0.0.1" and not ip.begins_with("169.254"):
			return ip
			
	return "127.0.0.1"

func get_all_usable_ips() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var ips: PackedStringArray = IP.get_local_addresses()
	for ip in ips:
		if ip.contains(":") or ip == "127.0.0.1" or ip.begins_with("169.254"):
			continue
		var desc: String = "Локальная сеть (Wi-Fi/LAN)"
		if ip.begins_with("26."):
			desc = "Radmin VPN"
		elif not (ip.begins_with("192.168.") or ip.begins_with("10.") or ip.begins_with("172.")):
			desc = "Сетевой адаптер"
		result.append({"ip": ip, "desc": desc})
	if result.is_empty():
		result.append({"ip": "127.0.0.1", "desc": "Локальный ПК"})
	return result

# --- LAN Discovery Broadcaster & Listener ---

func _process_lan_broadcast(delta: float) -> void:
	if is_host and not is_solo and udp_broadcaster:
		broadcast_timer -= delta
		if broadcast_timer <= 0.0:
			broadcast_timer = 1.0
			var local_ip := get_local_ip()
			var data := {
				"name": local_player_name + " (Сервер)",
				"ip": local_ip,
				"port": DEFAULT_PORT,
				"players": players.size()
			}
			var json_bytes := JSON.stringify(data).to_utf8_buffer()
			
			# Broadcast to standard general broadcast
			udp_broadcaster.set_dest_address("255.255.255.255", BROADCAST_PORT)
			udp_broadcaster.put_packet(json_bytes)
			
			# Also send directed subnet broadcast if on 192.168.x.x
			if local_ip.begins_with("192.168."):
				var parts := local_ip.split(".")
				if parts.size() == 4:
					var subnet_bcast := "%s.%s.%s.255" % [parts[0], parts[1], parts[2]]
					udp_broadcaster.set_dest_address(subnet_bcast, BROADCAST_PORT)
					udp_broadcaster.put_packet(json_bytes)
			elif local_ip.begins_with("26."):
				udp_broadcaster.set_dest_address("26.255.255.255", BROADCAST_PORT)
				udp_broadcaster.put_packet(json_bytes)

func start_lan_listener() -> void:
	if udp_listener:
		udp_listener.close()
	udp_listener = PacketPeerUDP.new()
	var err := udp_listener.bind(BROADCAST_PORT)
	if err != OK:
		print("LAN Listener bind status: ", err)

func stop_lan_listener() -> void:
	if udp_listener:
		udp_listener.close()
		udp_listener = null
	discovered_servers.clear()

func _process_lan_listen() -> void:
	if not udp_listener:
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	var changed: bool = false
	while udp_listener.get_available_packet_count() > 0:
		var pkt := udp_listener.get_packet()
		var sender_ip := udp_listener.get_packet_ip()
		var json_str := pkt.get_string_from_utf8()
		var parser := JSON.new()
		if parser.parse(json_str) == OK and typeof(parser.data) == TYPE_DICTIONARY:
			var data: Dictionary = parser.data
			var s_ip: String = data.get("ip", sender_ip)
			if s_ip == "127.0.0.1" and sender_ip != "127.0.0.1":
				s_ip = sender_ip
			var s_port: int = int(data.get("port", DEFAULT_PORT))
			var key := "%s:%d" % [s_ip, s_port]
			data["ip"] = s_ip
			data["port"] = s_port
			data["last_seen"] = now
			discovered_servers[key] = data
			changed = true

	# Cleanup dead beacons (> 3.5s)
	for k in discovered_servers.keys():
		if now - discovered_servers[k]["last_seen"] > 3.5:
			discovered_servers.erase(k)
			changed = true

	if changed:
		emit_signal("lan_servers_updated")

# --- Hosting & Connecting ---

func start_host(port: int = DEFAULT_PORT) -> Error:
	is_host = true
	is_solo = false
	enet_peer = ENetMultiplayerPeer.new()
	var err: Error = enet_peer.create_server(port, MAX_PLAYERS)
	if err != OK:
		print("Failed to create server on port %d: %s" % [port, err])
		return err
		
	multiplayer.multiplayer_peer = enet_peer
	players.clear()
	# Register host as peer 1
	players[1] = {
		"name": local_player_name,
		"team": local_team,
		"class_id": local_class_id
	}

	# Start UDP broadcaster for LAN discovery
	udp_broadcaster = PacketPeerUDP.new()
	udp_broadcaster.set_broadcast_enabled(true)
	udp_broadcaster.set_dest_address("255.255.255.255", BROADCAST_PORT)
	broadcast_timer = 0.0

	emit_signal("server_started")
	emit_signal("player_list_changed")
	return OK

func start_client(ip: String, port: int = DEFAULT_PORT) -> Error:
	is_host = false
	is_solo = false
	enet_peer = ENetMultiplayerPeer.new()
	var err: Error = enet_peer.create_client(ip, port)
	if err != OK:
		print("Failed to connect to %s:%d: %s" % [ip, port, err])
		return err
		
	multiplayer.multiplayer_peer = enet_peer
	return OK

func set_local_class(new_class_id: String) -> void:
	local_class_id = new_class_id
	_sync_local_player_update()

func set_local_team(new_team: Globals.Team) -> void:
	local_team = new_team
	_sync_local_player_update()

func set_local_name(new_name: String) -> void:
	if not new_name.is_empty():
		local_player_name = new_name
		_sync_local_player_update()

func _sync_local_player_update() -> void:
	var my_id: int = multiplayer.get_unique_id() if (multiplayer and multiplayer.has_multiplayer_peer()) else 1
	if players.has(my_id):
		players[my_id]["name"] = local_player_name
		players[my_id]["team"] = local_team
		players[my_id]["class_id"] = local_class_id
		emit_signal("player_list_changed")
		
	if multiplayer and multiplayer.has_multiplayer_peer():
		if multiplayer.is_server():
			rpc("sync_player_list", players)
		else:
			rpc_id(1, "register_player", local_player_name, local_team, local_class_id)

func start_solo() -> void:
	is_host = true
	is_solo = true
	enet_peer = null
	multiplayer.multiplayer_peer = null
	players.clear()
	players[1] = {
		"name": local_player_name,
		"team": local_team,
		"class_id": local_class_id
	}

func stop_multiplayer() -> void:
	if udp_broadcaster:
		udp_broadcaster.close()
		udp_broadcaster = null
	if udp_listener:
		udp_listener.close()
		udp_listener = null
	if enet_peer:
		enet_peer.close()
		enet_peer = null
	multiplayer.multiplayer_peer = null
	players.clear()
	discovered_servers.clear()
	is_host = false
	is_solo = false

# Signal Callbacks
func _on_peer_connected(id: int) -> void:
	print("Peer connected: ", id)
	if multiplayer.is_server():
		rpc_id(id, "sync_player_list", players)

func _on_peer_disconnected(id: int) -> void:
	print("Peer disconnected: ", id)
	if players.has(id):
		players.erase(id)
		emit_signal("player_list_changed")
		if multiplayer.is_server():
			rpc("sync_player_list", players)

func _on_connected_to_server() -> void:
	print("Successfully connected to host!")
	emit_signal("connected_to_server")
	rpc_id(1, "register_player", local_player_name, local_team, local_class_id)

func _on_connection_failed() -> void:
	print("Connection failed!")
	stop_multiplayer()
	emit_signal("connection_failed")

func _on_server_disconnected() -> void:
	print("Server disconnected!")
	stop_multiplayer()
	emit_signal("server_disconnected")

# RPCs for Lobby
@rpc("any_peer", "call_local", "reliable")
func register_player(p_name: String, p_team: int, p_class: String) -> void:
	if not multiplayer.is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = 1
		
	players[sender_id] = {
		"name": p_name,
		"team": p_team,
		"class_id": p_class
	}
	emit_signal("player_list_changed")
	rpc("sync_player_list", players)

@rpc("authority", "call_remote", "reliable")
func sync_player_list(server_players: Dictionary) -> void:
	players = server_players.duplicate(true)
	emit_signal("player_list_changed")

@rpc("authority", "call_local", "reliable")
func rpc_start_game() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")

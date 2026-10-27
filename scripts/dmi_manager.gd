extends Node

static var instance: Node

class DMIState:
	var name: String = ""
	var dirs: int = 1
	var frames: int = 1
	var delays: Array[float] = []
	var movement: bool = false
	var textures: Array = [] # [dir_idx][frame_idx] -> Texture2D

var is_loaded: bool = false
var states: Dictionary = {} # state_name -> DMIState
var dmi_source_path: String = ""
var last_error: String = ""
var dmi_raw_text: String = ""
var tile_width: int = 32
var tile_height: int = 32

var _base_state_cache: Dictionary = {}
var _overlay_cache: Dictionary = {}
var _log_buffer: String = ""

func _init() -> void:
	instance = self

func _ready() -> void:
	_log("--- DmiManager _ready() initialized ---")
	_log("OS: " + OS.get_name() + ", UserProfile: " + str(OS.get_environment("USERPROFILE")))
	load_dmi()

func _log(msg: String) -> void:
	print("[DmiManager] ", msg)
	_log_buffer += msg + "\n"
	var f := FileAccess.open("d:/gavno11/dmi_debug.log", FileAccess.WRITE)
	if f != null:
		f.store_string(_log_buffer)
		f.close()

func _find_dmi_file() -> String:
	var user_profile := OS.get_environment("USERPROFILE").replace("\\", "/")
	
	# Priority 1: Check known file paths
	var candidates: Array[String] = [
		"res://assets/classes.dmi",
		"res://assets/classes.png",
		"res://assets/classes (3).dmi",
		"d:/gavno11/assets/classes.dmi",
		"d:/gavno11/assets/classes.png",
		"d:/gavno11/assets/classes (3).dmi",
		"d:/gavno11/classes.dmi",
		"d:/gavno11/classes (3).dmi",
		"res://classes.dmi",
		"res://classes (3).dmi"
	]
	
	if not user_profile.is_empty():
		candidates.append(user_profile + "/Downloads/classes (3).dmi")
		candidates.append(user_profile + "/Downloads/classes.dmi")
	candidates.append("C:/Users/Alienware/Downloads/classes (3).dmi")
	candidates.append("C:/Users/Alienware/Downloads/classes.dmi")

	for p in candidates:
		if FileAccess.file_exists(p):
			var test_f := FileAccess.open(p, FileAccess.READ)
			if test_f != null:
				var sz: int = test_f.get_length()
				test_f.close()
				if sz > 64:
					_log("Found candidate file at: " + p + " (size: " + str(sz) + " bytes)")
					return p

	# Priority 2: Scan Downloads folders using DirAccess
	var scan_dirs: Array[String] = []
	if not user_profile.is_empty():
		scan_dirs.append(user_profile + "/Downloads")
	scan_dirs.append("C:/Users/Alienware/Downloads")

	for sd in scan_dirs:
		var da := DirAccess.open(sd)
		if da != null:
			da.list_dir_begin()
			var fn: String = da.get_next()
			while fn != "":
				if not da.current_is_dir() and fn.to_lower().ends_with(".dmi"):
					var full_p: String = sd + "/" + fn
					_log("Discovered .dmi file via DirAccess scan: " + full_p)
					return full_p
				fn = da.get_next()

	return ""

func load_dmi() -> bool:
	states.clear()
	_base_state_cache.clear()
	_overlay_cache.clear()
	is_loaded = false
	last_error = ""

	var src_file := _find_dmi_file()
	if src_file.is_empty():
		last_error = "Файл classes.dmi не найден"
		_log("ERROR: " + last_error)
		return false

	dmi_source_path = src_file
	_log("Opening DMI file: " + src_file)
	
	var f := FileAccess.open(src_file, FileAccess.READ)
	if f == null:
		last_error = "Не удалось открыть: " + src_file + " (код ошибки " + str(FileAccess.get_open_error()) + ")"
		_log("ERROR: " + last_error)
		return false

	var buf := f.get_buffer(f.get_length())
	f.close()

	if buf.size() < 64:
		last_error = "Файл поврежден (размер " + str(buf.size()) + " байт)"
		_log("ERROR: " + last_error)
		return false

	_log("Read " + str(buf.size()) + " bytes")

	# Save copy to assets
	_save_copy_to_assets(buf)

	# Parse buffer
	var ok := _parse_png_buffer(buf)
	if ok and not states.is_empty():
		is_loaded = true
		_log("SUCCESS: Loaded " + str(states.size()) + " states!")
		_dump_states()
	else:
		last_error = "Не удалось распознать текстуры в файле"
		_log("ERROR: " + last_error)

	return is_loaded

func _save_copy_to_assets(buf: PackedByteArray) -> void:
	var global_assets := ProjectSettings.globalize_path("res://assets").replace("\\", "/")
	DirAccess.make_dir_recursive_absolute(global_assets)
	
	var paths: Array[String] = [
		global_assets + "/classes.dmi",
		global_assets + "/classes.png",
		"d:/gavno11/assets/classes.dmi",
		"d:/gavno11/assets/classes.png"
	]
	for p in paths:
		var dst := FileAccess.open(p, FileAccess.WRITE)
		if dst != null:
			dst.store_buffer(buf)
			dst.close()
			_log("Saved copy to: " + p)

func _parse_png_buffer(buf: PackedByteArray) -> bool:
	if buf.size() < 8:
		return false
	if buf[0] != 0x89 or buf[1] != 0x50 or buf[2] != 0x4E or buf[3] != 0x47:
		_log("Not a valid PNG header")
		return false

	var img := Image.new()
	var err := img.load_png_from_buffer(buf)
	if err != OK or img.is_empty():
		_log("Image.load_png_from_buffer failed: error " + str(err))
		return false

	_log("Image loaded: " + str(img.get_width()) + "x" + str(img.get_height()) + " pixels")

	# Extract DMI description
	dmi_raw_text = _extract_dmi_text(buf)
	var state_list: Array = []
	if not dmi_raw_text.is_empty():
		_log("DMI metadata text found (" + str(dmi_raw_text.length()) + " chars)")
		state_list = _parse_dmi_text(dmi_raw_text)
		_log("Parsed " + str(state_list.size()) + " states from text")
	else:
		_log("No DMI text metadata found in zTXt/tEXt chunks")

	if not state_list.is_empty():
		_slice_sprites(img, state_list)
	else:
		_slice_grid_fallback(img)

	return states.size() > 0

func _extract_dmi_text(buf: PackedByteArray) -> String:
	var offset := 8
	var total_len := buf.size()
	
	while offset + 8 <= total_len:
		var chunk_len: int = ((buf[offset] & 0xFF) << 24) | ((buf[offset + 1] & 0xFF) << 16) | ((buf[offset + 2] & 0xFF) << 8) | (buf[offset + 3] & 0xFF)
		chunk_len = chunk_len & 0x7FFFFFFF
		var chunk_type := buf.slice(offset + 4, offset + 8).get_string_from_ascii()
		var data_offset := offset + 8
		
		if data_offset + chunk_len > total_len:
			break
			
		if chunk_type == "zTXt":
			var null_pos := data_offset
			while null_pos < data_offset + chunk_len and buf[null_pos] != 0:
				null_pos += 1
				
			var keyword := buf.slice(data_offset, null_pos).get_string_from_ascii()
			if keyword.nocasecmp_to("Description") == 0 and null_pos + 2 <= data_offset + chunk_len:
				var comp_data := buf.slice(null_pos + 2, data_offset + chunk_len)
				var decomp := _try_decompress(comp_data)
				if not decomp.is_empty():
					var text := decomp.get_string_from_utf8()
					if text.is_empty():
						text = decomp.get_string_from_ascii()
					if not text.is_empty():
						return text
					
		elif chunk_type == "tEXt":
			var null_pos := data_offset
			while null_pos < data_offset + chunk_len and buf[null_pos] != 0:
				null_pos += 1
				
			var keyword := buf.slice(data_offset, null_pos).get_string_from_ascii()
			if keyword.nocasecmp_to("Description") == 0:
				var text := buf.slice(null_pos + 1, data_offset + chunk_len).get_string_from_utf8()
				if text.is_empty():
					text = buf.slice(null_pos + 1, data_offset + chunk_len).get_string_from_ascii()
				if not text.is_empty():
					return text
				
		elif chunk_type == "IEND":
			break
			
		offset = data_offset + chunk_len + 4 # skip CRC
		
	return ""

func _try_decompress(data: PackedByteArray) -> PackedByteArray:
	if data.is_empty():
		return PackedByteArray()

	var max_size := 8 * 1024 * 1024
	
	# Attempt 1: Direct COMPRESSION_DEFLATE (standard zlib/deflate)
	var res := data.decompress(max_size, FileAccess.COMPRESSION_DEFLATE)
	if not res.is_empty():
		return res

	# Attempt 2: COMPRESSION_GZIP
	res = data.decompress(max_size, FileAccess.COMPRESSION_GZIP)
	if not res.is_empty():
		return res

	# Attempt 3: Raw deflate (RFC 1951) - strip 2-byte header and 4-byte Adler32
	if data.size() > 6 and data[0] == 0x78:
		var raw_deflate := data.slice(2, data.size() - 4)
		res = raw_deflate.decompress(max_size, FileAccess.COMPRESSION_DEFLATE)
		if not res.is_empty():
			return res

	# Attempt 4: Strip only 2-byte header
	if data.size() > 2 and data[0] == 0x78:
		var raw_deflate2 := data.slice(2)
		res = raw_deflate2.decompress(max_size, FileAccess.COMPRESSION_DEFLATE)
		if not res.is_empty():
			return res

	return PackedByteArray()

func _parse_dmi_text(text: String) -> Array:
	var result: Array = []
	var lines := text.split("\n")
	var current_state: DMIState = null
	
	for raw_line in lines:
		var s: String = raw_line.strip_edges()
		if s.is_empty() or s.begins_with("#"):
			continue
			
		var eq_idx: int = s.find("=")
		if eq_idx == -1:
			continue
			
		var key: String = s.substr(0, eq_idx).strip_edges().to_lower()
		var val: String = s.substr(eq_idx + 1).strip_edges()
		
		match key:
			"width":
				tile_width = maxi(1, int(val))
			"height":
				tile_height = maxi(1, int(val))
			"state":
				var name: String = val.trim_prefix("\"").trim_suffix("\"")
				current_state = DMIState.new()
				current_state.name = name
				result.append(current_state)
			"dirs":
				if current_state:
					current_state.dirs = maxi(1, int(val))
			"frames":
				if current_state:
					current_state.frames = maxi(1, int(val))
			"movement":
				if current_state:
					current_state.movement = (int(val) == 1)
			"delay":
				if current_state:
					current_state.delays.clear()
					for p in val.split(","):
						var p_str: String = p.strip_edges()
						if not p_str.is_empty():
							current_state.delays.append(float(p_str) * 0.1)
					
	return result

func _slice_sprites(img: Image, state_list: Array) -> void:
	if tile_width <= 0 or tile_height <= 0:
		tile_width = 32
		tile_height = 32
		
	var img_w: int = img.get_width()
	var img_h: int = img.get_height()
	var grid_cols: int = img_w / tile_width
	var max_tiles: int = grid_cols * (img_h / tile_height)
	var tile_idx: int = 0
	
	for st_obj in state_list:
		var st: DMIState = st_obj
		st.textures = []
		for d in range(st.dirs):
			st.textures.append([])
			
		for f in range(st.frames):
			for d in range(st.dirs):
				if tile_idx >= max_tiles:
					if not st.textures[d].is_empty():
						st.textures[d].append(st.textures[d][0])
					continue
					
				var col: int = tile_idx % grid_cols
				var row: int = tile_idx / grid_cols
				var x: int = col * tile_width
				var y: int = row * tile_height
				
				if x + tile_width <= img_w and y + tile_height <= img_h:
					var sub_rect := Rect2i(x, y, tile_width, tile_height)
					var frame_img := img.get_region(sub_rect)
					if frame_img and not frame_img.is_empty():
						var tex := ImageTexture.create_from_image(frame_img)
						st.textures[d].append(tex)
						
				tile_idx += 1
				
		# Differentiate movement (4 frames) from standing (1 frame)
		if st.movement:
			states[st.name + "_move"] = st
			if not states.has(st.name):
				states[st.name] = st
		else:
			states[st.name] = st

	# Guarantee every state has at least 1 valid texture
	var fallback_tex: Texture2D = null
	for s_key in states:
		var st_chk: DMIState = states[s_key]
		for d in range(st_chk.textures.size()):
			if not st_chk.textures[d].is_empty() and st_chk.textures[d][0] != null:
				fallback_tex = st_chk.textures[d][0]
				break
		if fallback_tex != null:
			break

	if fallback_tex != null:
		for s_key in states:
			var st_fill: DMIState = states[s_key]
			for d in range(st_fill.dirs):
				if st_fill.textures[d].is_empty():
					st_fill.textures[d].append(fallback_tex)

	_log("All DMI states: " + ", ".join(states.keys()))

func _slice_grid_fallback(img: Image) -> void:
	tile_width = 32
	tile_height = 32
	var img_w: int = img.get_width()
	var img_h: int = img.get_height()
	var grid_cols: int = img_w / tile_width
	var grid_rows: int = img_h / tile_height
	
	var tile_idx: int = 0
	for r in range(grid_rows):
		for c in range(grid_cols):
			var sub_rect := Rect2i(c * 32, r * 32, 32, 32)
			var frame_img := img.get_region(sub_rect)
			if frame_img and not frame_img.is_empty():
				var tex := ImageTexture.create_from_image(frame_img)
				var st := DMIState.new()
				st.name = "tile_%d" % tile_idx
				st.dirs = 1
				st.frames = 1
				st.textures = [[tex]]
				states[st.name] = st
				states["row_%d_col_%d" % [r, c]] = st
				tile_idx += 1
			
	if states.has("tile_0"):
		states["leech1"] = states["tile_0"]
		states["trooper1"] = states["tile_2"] if states.has("tile_2") else states["tile_0"]

func _dump_states() -> void:
	var lines: Array[String] = []
	lines.append("=== PARSED DMI STATES LIST (%d states) ===" % states.size())
	for s_name in states:
		var st: DMIState = states[s_name]
		lines.append("• '%s' -> '%s' (dirs: %d, frames: %d, movement: %s)" % [s_name, st.name, st.dirs, st.frames, str(st.movement)])
		
	var dump_text := "\n".join(lines)
	var f := FileAccess.open("d:/gavno11/assets/dmi_states.txt", FileAccess.WRITE)
	if f:
		f.store_string(dump_text)
		f.close()

	if not dmi_raw_text.is_empty():
		var meta_f := FileAccess.open("d:/gavno11/assets/dmi_metadata.txt", FileAccess.WRITE)
		if meta_f:
			meta_f.store_string(dmi_raw_text)
			meta_f.close()

func has_state(state_name: String) -> bool:
	return is_loaded and states.has(state_name)

func get_loaded_status_text() -> String:
	if is_loaded:
		return "✓ Спрайты DMI загружены (%d состояний из %s)" % [states.size(), dmi_source_path.get_file()]
	elif not last_error.is_empty():
		return "✗ Спрайты DMI: %s" % last_error
	else:
		return "✗ Спрайты DMI не найдены"

# ----------------- LOOKUP METHODS -----------------

## Returns the base character state name (pure body without arms)
func get_base_state(class_id: String, team: Globals.Team) -> String:
	var team_idx := 0 if team == Globals.Team.BAAL_RED else 1
	var cache_key := "%s:%d" % [class_id, team_idx]
	if _base_state_cache.has(cache_key):
		return _base_state_cache[cache_key]

	var state_name := _resolve_base_state(class_id, team_idx)
	_base_state_cache[cache_key] = state_name
	_log("Resolved base state for class='%s', team=%d -> '%s'" % [class_id, team_idx, state_name])
	return state_name

func _resolve_base_state(class_id: String, team_idx: int) -> String:
	if not is_loaded or states.is_empty():
		return ""

	var c: String = class_id.to_lower()
	if c == "leech" or c == "пиявка":
		# Team Red: leech1, Team Blue: crow1 or leech1
		if team_idx == 0 and states.has("leech1"):
			return "leech1"
		elif team_idx == 1 and states.has("crow1"):
			return "crow1"
		if states.has("leech1"):
			return "leech1"
	elif c == "trooper" or c == "десантник":
		# Team Red: trooper1, Team Blue: grunt1 or trooper2 or trooper1
		if team_idx == 0 and states.has("trooper1"):
			return "trooper1"
		elif team_idx == 1 and states.has("grunt1"):
			return "grunt1"
		elif team_idx == 1 and states.has("trooper2"):
			return "trooper2"
		if states.has("trooper1"):
			return "trooper1"
	elif c == "raptor" or c == "раптор":
		if states.has("raptor1"):
			return "raptor1"
	elif c == "augur" or c == "авгур":
		if states.has("augur1"):
			return "augur1"

	# General fallback: check exact matching class name ending with '1'
	if states.has(c + "1"):
		return c + "1"
	if states.has(c):
		return c

	return states.keys()[0]

## Returns two-handed weapon & arms overlay state for Slot 1
func get_two_handed_overlay(class_id: String, weapon_id: String, team: int = 0) -> String:
	var cache_key := "%s:%s:%d:two_handed" % [class_id, weapon_id, team]
	if _overlay_cache.has(cache_key):
		return _overlay_cache[cache_key]

	var c: String = class_id.to_lower()
	var w: String = weapon_id.to_lower()
	var result: String = ""

	if c == "trooper" or c == "десантник":
		if team == 1: # Blue Team (Grunt)
			if states.has("grunt_wagner"): result = "grunt_wagner"
			elif states.has("gruntwagner"): result = "gruntwagner"
			elif states.has("trooper_wagner"): result = "trooper_wagner"
		else: # Red Team (Trooper)
			if states.has("trooper_wagner"): result = "trooper_wagner"
			elif states.has("trooperwagner"): result = "trooperwagner"
			elif states.has("grunt_wagner"): result = "grunt_wagner"
	elif c == "leech" or c == "пиявка":
		if team == 1: # Blue Team (Crow)
			if states.has("crow_mkultra"): result = "crow_mkultra"
			elif states.has("leech_mkultra"): result = "leech_mkultra"
		else: # Red Team (Leech)
			if states.has("leech_mkultra"): result = "leech_mkultra"
			elif states.has("crow_mkultra"): result = "crow_mkultra"

	# Fallback search among 4-directional overlays
	if result.is_empty():
		for s_name in states:
			var sl: String = str(s_name).to_lower()
			var st: DMIState = states[s_name]
			if st.dirs == 4 and not sl.ends_with("_l") and not sl.ends_with("_r") and not sl.ends_with("_move"):
				if (c in sl) and ("wagner" in sl or "mk" in sl or "ultra" in sl):
					result = str(s_name)
					break

	_overlay_cache[cache_key] = result
	_log("Resolved two-handed overlay: class='%s', weapon='%s', team=%d -> '%s'" % [class_id, weapon_id, team, result])
	return result

## Returns one-handed weapon & arm overlay for Slot 2 ('l' = left hand, 'r' = right hand)
func get_one_handed_overlay(class_id: String, weapon_id: String, hand: String, team: int = 0) -> String:
	var h: String = hand.to_lower()
	var cache_key := "%s:%s:%s:%d" % [class_id, weapon_id, h, team]
	if _overlay_cache.has(cache_key):
		return _overlay_cache[cache_key]

	var c: String = class_id.to_lower()
	var w: String = weapon_id.to_lower()
	var result: String = ""

	if c == "trooper" or c == "десантник":
		if "sudan" in w:
			if team == 1:
				if states.has("grunt_sudan_" + h): result = "grunt_sudan_" + h
				elif states.has("trooper_sudan_" + h): result = "trooper_sudan_" + h
			else:
				if states.has("trooper_sudan_" + h): result = "trooper_sudan_" + h
				elif states.has("grunt_sudan_" + h): result = "grunt_sudan_" + h
		elif "fatwa" in w or "knife" in w or "blade" in w or "нож" in w:
			if team == 1:
				if states.has("grunt_fatwa_" + h): result = "grunt_fatwa_" + h
				elif states.has("trooper_fatwa_" + h): result = "trooper_fatwa_" + h
			else:
				if states.has("trooper_fatwa_" + h): result = "trooper_fatwa_" + h
				elif states.has("grunt_fatwa_" + h): result = "grunt_fatwa_" + h
	elif c == "leech" or c == "пиявка":
		if "tribunal" in w or "pistol" in w:
			if team == 1:
				if states.has("crow_tribunal_" + h): result = "crow_tribunal_" + h
				elif states.has("leech_tribunal_" + h): result = "leech_tribunal_" + h
			else:
				if states.has("leech_tribunal_" + h): result = "leech_tribunal_" + h
				elif states.has("crow_tribunal_" + h): result = "crow_tribunal_" + h
		elif "fatwa" in w or "knife" in w or "нож" in w:
			if team == 1:
				if states.has("grunt_fatwa_" + h): result = "grunt_fatwa_" + h
				elif states.has("trooper_fatwa_" + h): result = "trooper_fatwa_" + h
				elif states.has("crow_tribunal_" + h): result = "crow_tribunal_" + h
			else:
				if states.has("trooper_fatwa_" + h): result = "trooper_fatwa_" + h
				elif states.has("grunt_fatwa_" + h): result = "grunt_fatwa_" + h
				elif states.has("leech_tribunal_" + h): result = "leech_tribunal_" + h
	elif c == "raptor" or c == "раптор":
		if "ghetta" in w or "smg" in w or "пп" in w:
			if states.has("raptor_ghetta_" + h): result = "raptor_ghetta_" + h
		elif "cossack" in w or "blade" in w or "knife" in w or "клинок" in w:
			if states.has("raptor_cossack_" + h): result = "raptor_cossack_" + h
	elif c == "augur" or c == "авгур":
		if "blaster" in w or "shotgun" in w or "обрез" in w:
			if h == "l" and states.has("augur_blaster_l"): result = "augur_blaster_l"
			elif states.has("augur_blaster_" + h): result = "augur_blaster_" + h
		elif "templum" in w or "cannon" in w or "пушка" in w:
			return "" # Handled by augur1 base sprite (Templum cannon in right hand)

	# Fallback to empty arm overlay
	if result.is_empty():
		result = get_empty_arm_overlay(class_id, hand, team)

	_overlay_cache[cache_key] = result
	_log("Resolved one-handed overlay: class='%s', weapon='%s', hand='%s', team=%d -> '%s'" % [class_id, weapon_id, h, team, result])
	return result

## Returns empty arm overlay ('l' = left, 'r' = right)
func get_empty_arm_overlay(class_id: String, hand: String, team: int = 0) -> String:
	var c: String = class_id.to_lower()
	var h: String = hand.to_lower()
	
	if c == "augur" or c == "авгур":
		return "" # augur has integrated arms in base sprite

	if c == "trooper" or c == "десантник":
		if team == 1 and states.has("grunt_arm_" + h):
			return "grunt_arm_" + h
		elif states.has("trooper_arm_" + h):
			return "trooper_arm_" + h
	elif c == "leech" or c == "пиявка":
		if states.has("leech_arm_" + h):
			return "leech_arm_" + h
	elif states.has(c + "_arm_" + h):
		return c + "_arm_" + h

	if states.has("trooper_arm_" + h):
		return "trooper_arm_" + h
	if states.has("leech_arm_" + h):
		return "leech_arm_" + h
	return ""

## Legacy lookup for backwards compatibility
func get_overlay_state(class_id: String, weapon_id: String) -> String:
	return get_two_handed_overlay(class_id, weapon_id)

## Returns texture for given state, direction index, and frame index
func get_texture(state_name: String, dir_idx: int = 0, frame_idx: int = 0) -> Texture2D:
	if not is_loaded or state_name.is_empty():
		return null
		
	var actual_state: String = state_name
	if not states.has(actual_state):
		if actual_state.ends_with("_move") and states.has(actual_state.trim_suffix("_move")):
			actual_state = actual_state.trim_suffix("_move")
		else:
			return null
		
	var st: DMIState = states[actual_state]
	if st.textures.is_empty():
		return null
		
	var safe_dir := clampi(dir_idx, 0, st.dirs - 1)
	var dir_frames: Array = st.textures[safe_dir]
	if dir_frames.is_empty():
		return null
		
	var safe_frame := clampi(frame_idx, 0, dir_frames.size() - 1)
	return dir_frames[safe_frame]

## Returns DMI state metadata: {"dirs": int, "frames": int, "delays": Array}
func get_state_info(state_name: String) -> Dictionary:
	if not is_loaded or state_name.is_empty():
		return {"dirs": 1, "frames": 1, "delays": []}
		
	var actual_state: String = state_name
	if not states.has(actual_state):
		if actual_state.ends_with("_move") and states.has(actual_state.trim_suffix("_move")):
			actual_state = actual_state.trim_suffix("_move")
		else:
			return {"dirs": 1, "frames": 1, "delays": []}
		
	var st: DMIState = states[actual_state]
	return {
		"dirs": st.dirs,
		"frames": st.frames,
		"delays": st.delays
	}

## Converts aim angle (in radians) into BYOND 4-dir index
## 0: South (Down), 1: North (Up), 2: East (Right), 3: West (Left)
func angle_to_dmi_dir(angle: float, num_dirs: int = 4) -> int:
	if num_dirs <= 1:
		return 0
		
	var norm_a := wrapf(angle, -PI, PI)
	if num_dirs == 4:
		if norm_a >= PI * 0.25 and norm_a <= PI * 0.75:
			return 0 # SOUTH
		elif norm_a >= -PI * 0.75 and norm_a <= -PI * 0.25:
			return 1 # NORTH
		elif norm_a > -PI * 0.25 and norm_a < PI * 0.25:
			return 2 # EAST
		else:
			return 3 # WEST
	return 0

extends Node
## Central registry of all Nusantara Farm items, crops, recipes, NPCs, quests, and zones.

const WORLD_LEVEL_THRESHOLDS: Array[int] = [50, 150, 500, 850, 1300, 1900, 2500, 3100, 3700]

var items: Dictionary = {}
var crops: Dictionary = {}
var crops_by_seed: Dictionary = {}
var recipes: Dictionary = {}
var npcs: Dictionary = {}
var quests: Dictionary = {}
var zones: Dictionary = {}

var _items_atlas: Texture2D
var _crops_atlas: Texture2D
var _hud_icons_atlas: Texture2D
var _item_icon_cache: Dictionary = {}
var _crop_tex_cache: Dictionary = {}
var _hud_icon_cache: Dictionary = {}


func _ready() -> void:
	_load_atlases()
	_register_items()
	_register_crops()
	_register_recipes()
	_register_npcs()
	_register_quests()
	_register_zones()


func _load_atlases() -> void:
	_items_atlas = _safe_load_tex("res://assets/items/items_atlas.png")
	_crops_atlas = _safe_load_tex("res://assets/objects/crops_atlas.png")
	_hud_icons_atlas = _safe_load_tex("res://assets/ui/hud_icons.png")


func _safe_load_tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


func _register_items() -> void:
	var defs := [
		# Tools
		["gembor", "Gembor Siram", "Alat penyiram tanaman kebun.", ItemData.Category.TOOL, 0, 0, 0, false, 0, 0.0, false, 1],
		["cangkul", "Cangkul Besi", "Mencangkul tanah kebun agar siap ditanami.", ItemData.Category.TOOL, 1, 0, 0, false, 0, 0.0, false, 1],
		["kapak", "Kapak Kayu", "Menebang pohon dewasa di hutan (ingat reboisasi!).", ItemData.Category.TOOL, 2, 0, 0, false, 0, 0.0, false, 1],
		["sabit", "Sabit Rumput", "Membersihkan gulma dan memanen tanaman.", ItemData.Category.TOOL, 3, 0, 0, false, 0, 0.0, false, 1],
		# Seeds & Saplings
		["benih_padi", "Benih Padi Lokal", "Tumbuh 4 hari di Musim Penghujan (5 hari di Kemarau).", ItemData.Category.SEED, 4, 20, 10, false, 0, 0.0, false, 1],
		["benih_pisang", "Tunas Pisang Raja", "Berbuah perdana 6 hari, lalu panen ulang tiap 3 hari.", ItemData.Category.SEED, 5, 60, 30, false, 0, 0.0, false, 1],
		["benih_kopi", "Bibit Kopi Nusantara", "Berbuah 7 hari, panen ulang tiap 4 hari.", ItemData.Category.SEED, 6, 80, 40, false, 0, 0.0, false, 2],
		["benih_kelapa", "Tunas Kelapa Hijau", "Berbuah 8 hari, panen ulang tiap 4 hari.", ItemData.Category.SEED, 7, 100, 50, false, 0, 0.0, false, 2],
		["benih_sawit", "Bibit Kelapa Sawit", "Berbuah 9 hari, panen ulang tiap 4 hari.", ItemData.Category.SEED, 8, 150, 75, false, 0, 0.0, false, 3],
		["benih_cabai", "Benih Cabai Merah", "Optimal di Musim Kemarau (4 hari, panen ulang tiap 2 hari).", ItemData.Category.SEED, 9, 30, 15, false, 0, 0.0, false, 1],
		["bibit_pohon", "Bibit Pohon Hutan", "Tanam ulang di Hutan Tropis untuk menjaga Eco-Meter!", ItemData.Category.SEED, 10, 10, 5, false, 0, 0.0, false, 1],
		# Crops & Raw Materials
		["padi", "Ikat Padi Lokal", "Hasil panen padi sawah Nusantara.", ItemData.Category.CROP, 11, 0, 45, false, 0, 0.0, true, 1],
		["pisang", "Sisir Pisang Raja", "Pisang manis bahan baku Keripik Pisang.", ItemData.Category.CROP, 12, 0, 35, true, 12, 0.0, true, 1],
		["biji_kopi", "Biji Kopi Nusantara", "Aroma kuat siap disangrai di Joglo.", ItemData.Category.CROP, 13, 0, 45, false, 0, 0.0, true, 2],
		["kelapa", "Kelapa Hijau", "Segar diminum atau diolah menjadi santan.", ItemData.Category.CROP, 14, 0, 70, true, 18, 0.0, true, 2],
		["tandan_sawit", "Tandan Kelapa Sawit", "Bahan utama Minyak Sawit di Stasiun Peras.", ItemData.Category.CROP, 15, 0, 95, false, 0, 0.0, true, 3],
		["cabai", "Cabai & Rempah", "Bumbu pedas pelengkap masakan desa.", ItemData.Category.CROP, 16, 0, 30, false, 0, 0.0, true, 1],
		["kayu", "Kayu Tropis", "Bahan perbaikan jembatan, gerbang, dan bangunan.", ItemData.Category.MATERIAL, 17, 40, 15, false, 0, 0.0, false, 1],
		["garam_laut", "Garam Laut", "Garam alami hasil pesisir pantai.", ItemData.Category.FORAGE, 18, 35, 18, false, 0, 0.0, false, 4],
		["minyak_dasar", "Minyak Goreng Dasar", "Minyak dapur untuk mengolah keripik pisang.", ItemData.Category.MATERIAL, 19, 45, 20, false, 0, 0.0, false, 1],
		["gula_jawa", "Gula Jawa Asli", "Pemanis alami tebu dan nira kelapa.", ItemData.Category.MATERIAL, 20, 30, 15, false, 0, 0.0, true, 1],
		# Crafted / Processed Products
		["keripik_pisang", "Keripik Pisang", "Camilan renyah khas Joglo. Pulihkan +35 Stamina.", ItemData.Category.PROCESSED, 21, 0, 480, true, 35, 0.0, true, 1],
		["beras_pulen", "Beras Pulen Desa", "Beras putih pulen hasil lesung Joglo.", ItemData.Category.PROCESSED, 22, 0, 280, false, 0, 0.0, true, 2],
		["kopi_sangrai", "Kopi Sangrai", "Biji kopi matang siap seduh.", ItemData.Category.PROCESSED, 23, 0, 300, false, 0, 0.0, true, 2],
		["kopi_seduh", "Kopi Seduh Nusantara", "+45 Stamina & menunda Debuff Mengantuk 4 jam!", ItemData.Category.PROCESSED, 24, 0, 120, true, 45, 4.0, true, 2],
		["minyak_sawit", "Minyak Sawit Murni", "Minyak olahan berkualitas tinggi.", ItemData.Category.PROCESSED, 25, 0, 460, false, 0, 0.0, true, 3],
		["santan_kelapa", "Santan Kelapa", "Santan kental untuk masakan & Tumpeng.", ItemData.Category.PROCESSED, 26, 0, 260, false, 0, 0.0, true, 2],
		["nasi_tumpeng", "Nasi Tumpeng Desa", "Hidangan adat terbaik untuk Festival & Kepala Desa.", ItemData.Category.PROCESSED, 27, 0, 950, true, 80, 0.0, true, 3],
	]
	for d in defs:
		var item := ItemData.new()
		item.id = StringName(d[0])
		item.display_name = d[1]
		item.description = d[2]
		item.category = d[3]
		item.atlas_index = d[4]
		item.base_buy_price = d[5]
		item.base_sell_price = d[6]
		item.is_consumable = d[7]
		item.energy_restore = d[8]
		item.anti_drowsy_hours = d[9]
		item.is_giftable = d[10]
		item.required_world_level = d[11]
		item.icon = get_item_icon(item.atlas_index)
		items[item.id] = item


func _register_crops() -> void:
	var defs := [
		["padi_lokal", "benih_padi", "padi", "Padi Lokal", 0, [&"penghujan"], 5, 4, false, 0, 2, 3, 10, "Padi lokal tumbuh lebih cepat saat Musim Penghujan."],
		["pisang_raja", "benih_pisang", "pisang", "Pisang Raja", 1, [&"kemarau", &"penghujan"], 6, 5, true, 3, 3, 4, 12, "Pisang adalah bahan baku utama Keripik Pisang khas Joglo."],
		["kopi_nusantara", "benih_kopi", "biji_kopi", "Kopi Nusantara", 2, [&"kemarau", &"penghujan"], 7, 6, true, 4, 3, 3, 14, "Kopi Nusantara dapat diseduh untuk menahan rasa kantuk."],
		["kelapa_hijau", "benih_kelapa", "kelapa", "Kelapa Hijau", 3, [&"kemarau"], 8, 7, true, 4, 2, 2, 15, "Pohon kelapa serba guna untuk santan dan hidangan desa."],
		["kelapa_sawit", "benih_sawit", "tandan_sawit", "Kelapa Sawit", 4, [&"kemarau", &"penghujan"], 9, 8, true, 4, 2, 2, 18, "Tandan sawit diolah menjadi minyak goreng serba guna."],
		["cabai_rempah", "benih_cabai", "cabai", "Cabai Merah", 5, [&"kemarau"], 4, 3, true, 2, 2, 3, 10, "Cabai tumbuh subur pada terik Musim Kemarau."],
	]
	for d in defs:
		var c := CropData.new()
		c.crop_id = StringName(d[0])
		c.seed_item_id = StringName(d[1])
		c.harvest_item_id = StringName(d[2])
		c.display_name = d[3]
		c.atlas_row = d[4]
		c.optimal_seasons.assign(d[5])
		c.grow_days_normal = d[6]
		c.grow_days_optimal = d[7]
		c.is_regrowable = d[8]
		c.regrow_days = d[9]
		c.min_yield = d[10]
		c.max_yield = d[11]
		c.harvest_xp = d[12]
		c.education_fact = d[13]
		crops[c.crop_id] = c
		crops_by_seed[c.seed_item_id] = c


func _register_recipes() -> void:
	var defs := [
		["keripik_pisang", "Keripik Pisang", &"wajan_joglo", 1, {&"pisang": 10, &"minyak_dasar": 1}, &"keripik_pisang", 1, 2.0, 15],
		["beras_pulen", "Beras Pulen Desa", &"lesung", 2, {&"padi": 5}, &"beras_pulen", 1, 1.5, 15],
		["kopi_sangrai", "Kopi Sangrai", &"sangrai", 2, {&"biji_kopi": 5}, &"kopi_sangrai", 1, 2.0, 15],
		["kopi_seduh", "Kopi Seduh Nusantara", &"dapur_joglo", 2, {&"kopi_sangrai": 1, &"gula_jawa": 1}, &"kopi_seduh", 1, 0.5, 12],
		["minyak_sawit", "Minyak Sawit Murni", &"peras", 3, {&"tandan_sawit": 4}, &"minyak_sawit", 1, 3.0, 20],
		["santan_kelapa", "Santan Kelapa", &"dapur_joglo", 2, {&"kelapa": 3}, &"santan_kelapa", 1, 1.0, 15],
		["nasi_tumpeng", "Nasi Tumpeng Desa", &"dapur_joglo", 3, {&"beras_pulen": 2, &"santan_kelapa": 1, &"cabai": 2}, &"nasi_tumpeng", 1, 4.0, 40],
	]
	for d in defs:
		var r := RecipeData.new()
		r.recipe_id = StringName(d[0])
		r.display_name = d[1]
		r.station_type = d[2]
		r.required_world_level = d[3]
		r.ingredients = d[4]
		r.output_item_id = d[5]
		r.output_amount = d[6]
		r.process_hours = d[7]
		r.craft_xp = d[8]
		recipes[r.recipe_id] = r


func _register_npcs() -> void:
	var defs := [
		[
			"pak_tani", "Pak Tani", "Mentor Pertanian", 0, "res://assets/portraits/pak_tani.png",
			[&"padi", &"kopi_seduh", &"beras_pulen"], [&"tandan_sawit"], &"desa_pasar", Vector2(180, 175),
			["Selamat pagi, Nak! Padi lokal butuh pengairan cukup setiap hari.", "Jangan lupa cangkul tanah sebelum menabur benih ya."],
			["Musim hujan ini berkah bagi sawah! Tanaman luar ruangan tersiram otomatis."],
			"Panen raya tiba! Mari syukuri hasil bumi desa kita."
		],
		[
			"nisrina", "Nisrina", "Pemilik Kios Bumbu & Bibit", 1, "res://assets/portraits/nisrina.png",
			[&"pisang", &"keripik_pisang", &"cabai"], [&"kayu"], &"desa_pasar", Vector2(360, 165),
			["Halo! Kios saya menyediakan benih lokal dan bahan dapur Joglo.", "Pisang desa kita paling cocok diolah menjadi Keripik Pisang!"],
			["Hujan begini enak minum Kopi Seduh hangat di teras Joglo."],
			"Semua warga membantu menyiapkan bumbu untuk Tumpeng Festival!"
		],
		[
			"kades", "Kepala Desa", "Penjaga Adat & K3LH Desa", 2, "res://assets/portraits/kades.png",
			[&"nasi_tumpeng", &"beras_pulen", &"kelapa"], [&"kayu"], &"balai_desa", Vector2(240, 170),
			["Ingat selalu kelestarian alam desa: tebang satu pohon, tanam kembali bibitnya!", "Gotong royong membangun World Level membuat desa makin makmur."],
			["Air hujan membantu kesuburan tanah, tetap jaga hutan agar tidak longsor."],
			"Selamat merayakan Festival Panen Desa! Semoga hasil bumi kita selalu melimpah!"
		],
		[
			"leon", "Mas Leon", "Pedagang Konsinyasi Pasar", 3, "res://assets/portraits/leon.png",
			[&"keripik_pisang", &"minyak_sawit", &"kopi_sangrai"], [&"bibit_pohon"], &"desa_pasar", Vector2(430, 185),
			["Titip jual hasil panen atau olahanmu di sini! Harganya lebih tinggi dan cair beberapa jam lagi.", "Kalau Eco-Meter desa sehat, pembeli kota berani bayar lebih mahal!"],
			["Meski hujan, pembeli tetap mencari keripik pisang dan kopi sangrai."],
			"Festival hari ini bikin dagangan warga laris manis!"
		],
		[
			"bahri", "Pak Bahri", "Nelayan Pesisir", 4, "res://assets/portraits/bahri.png",
			[&"kelapa", &"kopi_seduh", &"gula_jawa"], [&"cabai"], &"desa_pasar", Vector2(475, 240),
			["Jembatan menuju Pantai Selatan menunggu perbaikan kayu dan koin warga.", "Nanti di Pantai kita bisa mencari garam laut dan kelapa pesisir."],
			["Ombak pantai agak tinggi saat hujan, tapi udara tetap segar."],
			"Nelayan dan petani sama-sama bersyukur di Festival Panen!"
		],
	]
	for d in defs:
		var n := NPCData.new()
		n.npc_id = StringName(d[0])
		n.display_name = d[1]
		n.role_title = d[2]
		n.sprite_index = d[3]
		n.portrait = _safe_load_tex(d[4])
		n.liked_items.assign(d[5])
		n.disliked_items.assign(d[6])
		n.default_zone = StringName(d[7])
		n.default_position = d[8]
		n.greetings_day.assign(d[9])
		n.greetings_rain.assign(d[10])
		n.greetings_festival = d[11]
		npcs[n.npc_id] = n


func _register_quests() -> void:
	var defs := [
		["q_panen_padi", "Panen Padi Pertama", "Tanam dan panen 5 Ikat Padi Lokal lalu serahkan ke Pak Tani.", &"pak_tani", 1, &"", {&"padi": 5}, 120, 60, 5, 100, &""],
		["q_keripik_nisrina", "Oleh-Oleh Keripik Pisang", "Olah 1 bungkus Keripik Pisang di dapur Joglo dan berikan kepada Nisrina.", &"nisrina", 1, &"", {&"keripik_pisang": 1}, 250, 80, 5, 120, &""],
		["q_buka_hutan", "Akses Hutan Tropis", "Capai World Level 2 dan serahkan 50 Koin/persiapan ke Pak Tani untuk membuka Hutan.", &"pak_tani", 2, &"q_panen_padi", {&"padi": 3}, 100, 90, 10, 100, &"hutan"],
		["q_reboisasi", "Gotong Royong Reboisasi", "Bantu Kepala Desa menjaga kelestarian alam dengan menyerahkan 2 Kayu Tropis & 2 Cabai untuk kerja bakti.", &"kades", 2, &"", {&"kayu": 2, &"cabai": 2}, 150, 75, 20, 120, &""],
		["q_buka_sawit", "Gerbang Kebun Sawit", "Capai World Level 3 dan kumpulkan 10 Kayu untuk memperbaiki gerbang Perkebunan Sawit.", &"kades", 3, &"q_buka_hutan", {&"kayu": 10}, 200, 120, 5, 120, &"sawit"],
		["q_buka_pantai", "Perbaikan Jembatan Pantai", "Capai World Level 4 dan bantu Pak Bahri dengan 15 Kayu untuk membuka jalur Pantai & Laut.", &"bahri", 4, &"q_buka_sawit", {&"kayu": 15}, 300, 150, 10, 150, &"pantai"],
		["q_buka_tambang", "Jalur Pegunungan & Tambang", "Capai World Level 5 dan siapkan 2 Kopi Seduh serta 2 Beras Pulen untuk tim buka jalur tambang.", &"kades", 5, &"q_buka_pantai", {&"kopi_seduh": 2, &"beras_pulen": 2}, 450, 200, 10, 150, &"tambang"],
	]
	for d in defs:
		var q := QuestData.new()
		q.quest_id = StringName(d[0])
		q.title = d[1]
		q.description = d[2]
		q.giver_npc_id = d[3]
		q.required_world_level = d[4]
		q.prerequisite_quest_id = d[5]
		q.required_items = d[6]
		q.reward_coins = d[7]
		q.reward_world_xp = d[8]
		q.reward_eco = d[9]
		q.reward_hearts = d[10]
		q.unlocks_zone_id = d[11]
		quests[q.quest_id] = q


func _register_zones() -> void:
	var defs := [
		["kebun", "Rumah & Kebun", "res://scenes/zones/ZonaKebun.tscn", Vector2i(36, 24), false, true, 1, &"", 0, 0, Vector2(64, 52)],
		["joglo_interior", "Dalam Rumah Joglo", "res://scenes/interiors/JogloInterior.tscn", Vector2i(20, 14), true, true, 1, &"", 0, 0, Vector2(64, 52)],
		["desa_pasar", "Desa Utama & Pasar", "res://scenes/zones/ZonaDesaPasar.tscn", Vector2i(38, 24), false, true, 1, &"", 0, 0, Vector2(170, 102)],
		["balai_desa", "Balai Desa Nusantara", "res://scenes/interiors/BalaiDesaInterior.tscn", Vector2i(20, 14), true, true, 1, &"", 0, 0, Vector2(170, 102)],
		["hutan", "Hutan Tropis", "res://scenes/zones/ZonaHutan.tscn", Vector2i(36, 24), false, false, 2, &"q_buka_hutan", 50, 0, Vector2(205, 58)],
		["sawit", "Perkebunan Sawit", "res://scenes/zones/ZonaSawit.tscn", Vector2i(36, 24), false, false, 3, &"q_buka_sawit", 200, 10, Vector2(82, 160)],
		["pantai", "Pantai & Laut", "res://scenes/zones/ZonaPantai.tscn", Vector2i(36, 24), false, false, 4, &"q_buka_pantai", 400, 15, Vector2(315, 162)],
		["tambang", "Pegunungan & Tambang", "res://scenes/zones/ZonaTambang.tscn", Vector2i(36, 24), false, false, 5, &"q_buka_tambang", 500, 0, Vector2(326, 52)],
	]
	for d in defs:
		var z := ZoneData.new()
		z.zone_id = StringName(d[0])
		z.display_name = d[1]
		z.scene_path = d[2]
		z.grid_size = d[3]
		z.is_indoor = d[4]
		z.unlocked_by_default = d[5]
		z.required_world_level = d[6]
		z.required_quest_id = d[7]
		z.unlock_cost_coins = d[8]
		z.unlock_cost_wood = d[9]
		z.map_pin_pos = d[10]
		zones[z.zone_id] = z


func get_item(id: StringName) -> ItemData:
	return items.get(id, null)


func get_crop(id: StringName) -> CropData:
	return crops.get(id, null)


func get_crop_by_seed(seed_id: StringName) -> CropData:
	return crops_by_seed.get(seed_id, null)


func get_recipe(id: StringName) -> RecipeData:
	return recipes.get(id, null)


func get_npc(id: StringName) -> NPCData:
	return npcs.get(id, null)


func get_quest(id: StringName) -> QuestData:
	return quests.get(id, null)


func get_zone(id: StringName) -> ZoneData:
	return zones.get(id, null)


func get_shop_items(world_level: int) -> Array[ItemData]:
	var res: Array[ItemData] = []
	for item in items.values():
		var it := item as ItemData
		if it.base_buy_price > 0 and it.required_world_level <= world_level:
			res.append(it)
	return res


func get_xp_for_next_world_level(current_level: int) -> int:
	var idx := current_level - 1
	if idx >= 0 and idx < WORLD_LEVEL_THRESHOLDS.size():
		return WORLD_LEVEL_THRESHOLDS[idx]
	return 3700 + (current_level - WORLD_LEVEL_THRESHOLDS.size()) * 600


func get_item_icon(atlas_index: int) -> Texture2D:
	if _item_icon_cache.has(atlas_index):
		return _item_icon_cache[atlas_index]
	if _items_atlas == null:
		return null
	var tex := AtlasTexture.new()
	tex.atlas = _items_atlas
	tex.region = Rect2((atlas_index % 8) * 16, (atlas_index / 8) * 16, 16, 16)
	_item_icon_cache[atlas_index] = tex
	return tex


func get_crop_stage_texture(atlas_row: int, stage: int) -> Texture2D:
	var key := "%d_%d" % [atlas_row, stage]
	if _crop_tex_cache.has(key):
		return _crop_tex_cache[key]
	if _crops_atlas == null:
		return null
	var tex := AtlasTexture.new()
	tex.atlas = _crops_atlas
	tex.region = Rect2(clampi(stage, 0, 4) * 16, clampi(atlas_row, 0, 6) * 24, 16, 24)
	_crop_tex_cache[key] = tex
	return tex


func get_hud_icon(icon_index: int) -> Texture2D:
	if _hud_icon_cache.has(icon_index):
		return _hud_icon_cache[icon_index]
	if _hud_icons_atlas == null:
		return null
	var tex := AtlasTexture.new()
	tex.atlas = _hud_icons_atlas
	tex.region = Rect2(icon_index * 16, 0, 16, 16)
	_hud_icon_cache[icon_index] = tex
	return tex

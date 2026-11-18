class_name GraLibrary
extends RefCounted
## キャラグラ (BMP) の探索・読み込みを od/ed エディタで共有する。
## 探索先: 設定フォルダ直下 + その chara* サブフォルダ + マップのチップ
## フォルダ + その親の chara* サブフォルダ。色鍵は NeoPHI と同じ
## (0,128,128) を透明化する。シート配置も NeoPHI と同じ
## (96幅: 小16x2 + 大32x2、行は B/R/F/L の 32px)。

var root := ""
var names: Array[String] = []
var paths := {}
var _cache := {}

const DIR_ROWS := {"B": 0, "R": 1, "F": 2, "L": 3}


func setup_from_cfg() -> void:
	var cfg := ConfigFile.new()
	cfg.load("user://creators.cfg")
	root = String(cfg.get_value("od", "gra_root", ""))
	scan()


func set_root(dir: String) -> void:
	root = dir
	var cfg := ConfigFile.new()
	cfg.load("user://creators.cfg")
	cfg.set_value("od", "gra_root", dir)
	cfg.save("user://creators.cfg")
	scan()


func scan() -> void:
	paths.clear()
	names.clear()
	var roots: Array[String] = []
	if root != "":
		roots.append(root)
		_append_chara_subdirs(roots, root)
	var cfg := ConfigFile.new()
	cfg.load("user://creators.cfg")
	var chip := String(cfg.get_value("chip", "dir", ""))
	if chip != "":
		roots.append(chip)
		_append_chara_subdirs(roots, chip.get_base_dir())
	for dir in roots:
		_scan_dir(dir)
	names.sort()


func _append_chara_subdirs(roots: Array[String], base: String) -> void:
	var d := DirAccess.open(base)
	if d == null:
		return
	for name in d.get_directories():
		if name.to_lower().begins_with("chara"):
			roots.append(base.path_join(name))


func _scan_dir(dir: String) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for file in d.get_files():
		if file.to_lower().ends_with(".bmp"):
			var stem := file.get_basename()
			var key := stem.to_lower()
			if not paths.has(key):
				paths[key] = dir.path_join(file)
				names.append(stem)


func find_path(gname: String) -> String:
	return String(paths.get(gname.to_lower(), ""))


## {img, tex} を返す。読めなければ空辞書
func data_for(path: String) -> Dictionary:
	if _cache.has(path):
		return _cache[path]
	var img := Image.load_from_file(path)
	if img == null:
		return {}
	img.convert(Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.r8 == 0 and c.g8 == 128 and c.b8 == 128:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	var data := {"img": img, "tex": ImageTexture.create_from_image(img)}
	_cache[path] = data
	return data


## 向き行 (0=B,1=R,2=F,3=L) のフレーム。large なら 32x32、否なら 16x32
func frame_texture(img: Image, row: int, large: bool) -> Texture2D:
	var rect := Rect2i(32, row * 32, 32, 32) if large \
			else Rect2i(0, row * 32, 16, 32)
	rect = rect.intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	if rect.size.x <= 0 or rect.size.y <= 0:
		return null
	return ImageTexture.create_from_image(img.get_region(rect))

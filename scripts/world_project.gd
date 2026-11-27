class_name WorldProject
extends RefCounted
## world フォルダ1つ分の読み込みと保存。
## phi.td は必須。phi.swt / phi.bb / phi.inf は任意 (無ければ作れる)。

var dir := ""
var td: PhiTd
var swt: PhiSwt
var dd: PhiDd
var fd: PhiFd
var map_size := Vector2i.ZERO ## phi_dm.cnf の MAX_X/MAX_Y (無ければ dd から推定)
var ed: PhiEd
var od: PhiOd
var crt: PhiCrt
var ex: PhiEx
var ad: PhiAd
var has_ed := false
var has_od := false
var has_crt := false
var has_ex := false
var has_ad := false
var jb: PhiJb
var pt: PhiPt
var has_jb := false
var has_pt := false
var has_ddx := false
var bb_text := ""
var inf_text := ""
var cls_text := ""
var has_swt := false
var has_bb := false
var has_inf := false
var has_cls := false
var _bb_bytes := PackedByteArray()
var _inf_bytes := PackedByteArray()
var _cls_bytes := PackedByteArray()


func open(p_dir: String) -> bool:
	dir = p_dir
	td = PhiTd.load_file(dir.path_join("phi.td"))
	if td == null:
		return false
	has_swt = FileAccess.file_exists(dir.path_join("phi.swt"))
	if has_swt:
		swt = PhiSwt.load_file(dir.path_join("phi.swt"))
	has_bb = FileAccess.file_exists(dir.path_join("phi.bb"))
	if has_bb:
		bb_text = _read_text(dir.path_join("phi.bb"))
		_bb_bytes = _read_bytes(dir.path_join("phi.bb"))
	has_inf = FileAccess.file_exists(dir.path_join("phi.inf"))
	if has_inf:
		inf_text = _read_text(dir.path_join("phi.inf"))
		_inf_bytes = _read_bytes(dir.path_join("phi.inf"))
	has_ed = FileAccess.file_exists(dir.path_join("phi.ed"))
	if has_ed:
		ed = PhiEd.load_file(dir.path_join("phi.ed"))
	has_od = FileAccess.file_exists(dir.path_join("phi.od"))
	if has_od:
		od = PhiOd.load_file(dir.path_join("phi.od"))
	has_crt = FileAccess.file_exists(dir.path_join("phi.crt"))
	if has_crt:
		crt = PhiCrt.load_file(dir.path_join("phi.crt"))
	has_ex = FileAccess.file_exists(dir.path_join("phi.ex"))
	if has_ex:
		ex = PhiEx.load_file(dir.path_join("phi.ex"))
	has_ad = FileAccess.file_exists(dir.path_join("phi.ad"))
	if has_ad:
		ad = PhiAd.load_file(dir.path_join("phi.ad"))
	has_jb = FileAccess.file_exists(dir.path_join("phi.jb"))
	if has_jb:
		jb = PhiJb.load_file(dir.path_join("phi.jb"))
	has_pt = FileAccess.file_exists(dir.path_join("phi.pt"))
	if has_pt:
		pt = PhiPt.load_file(dir.path_join("phi.pt"))
	has_cls = FileAccess.file_exists(dir.path_join("phi.cls"))
	if has_cls:
		cls_text = _read_text(dir.path_join("phi.cls"))
		_cls_bytes = _read_bytes(dir.path_join("phi.cls"))
	has_ddx = FileAccess.file_exists(dir.path_join("phi.ddx"))
	map_size = _read_map_size()
	if map_size.x > 0:
		if FileAccess.file_exists(dir.path_join("phi.dd")):
			dd = PhiDd.load_file(dir.path_join("phi.dd"), map_size.x, map_size.y)
		if FileAccess.file_exists(dir.path_join("phi.fd")):
			fd = PhiFd.load_file(dir.path_join("phi.fd"), map_size.x, map_size.y)
	return true


## 無いファイルを空で新規作成する。その場でディスクにも書き出す。
## kind は "swt" / "ed" / "od" / "crt" / "ex" / "ad" / "jb" / "pt"。
## phi.jb は空でも存在するだけでジョブ／性別が有効になる。
func create_file(kind: String) -> bool:
	var path := dir.path_join("phi." + kind)
	if FileAccess.file_exists(path):
		return false
	var data := PackedByteArray()
	match kind:
		"swt":
			swt = PhiSwt.parse(PhiRawLines.from_bytes(PackedByteArray()))
			has_swt = true
			data = swt.serialize()
		"ed":
			ed = PhiEd.parse(PhiRawLines.from_bytes(PackedByteArray()))
			has_ed = true
			data = ed.serialize()
		"od":
			od = PhiOd.parse(PhiRawLines.from_bytes(PackedByteArray()))
			has_od = true
			data = od.serialize()
		"crt":
			crt = PhiCrt.parse(PhiRawLines.from_bytes(PackedByteArray()))
			has_crt = true
			data = crt.serialize()
		"ex":
			ex = PhiEx.parse(PhiRawLines.from_bytes(PackedByteArray()))
			has_ex = true
			data = ex.serialize()
		"ad":
			ad = PhiAd.parse(PhiRawLines.from_bytes(PackedByteArray()))
			has_ad = true
			data = ad.serialize()
		"jb":
			jb = PhiJb.parse(PhiRawLines.from_bytes(PackedByteArray()))
			has_jb = true
			data = jb.serialize()
		"pt":
			pt = PhiPt.parse(PhiRawLines.from_bytes(PackedByteArray()))
			has_pt = true
			data = pt.serialize()
		_:
			return false
	_write(path, data)
	return FileAccess.file_exists(path)


## マップを新規作成する (正方形のみ)。dd/fd をメモリ上に作り、
## 保存時に書き出される。サーバは同じ寸法でコンパイルする必要がある。
func create_map(size: int) -> void:
	map_size = Vector2i(size, size)
	dd = PhiDd.create_new(size, size)
	dd.force_dirty = true
	fd = PhiFd.create_new(size, size)
	fd.force_dirty = true


## マップ寸法: phi_dm.cnf の MAX_X/MAX_Y を読み、無ければ phi.dd から推定
func _read_map_size() -> Vector2i:
	var cnf_path := dir.path_join("phi_dm.cnf")
	if FileAccess.file_exists(cnf_path):
		var text := _read_text(cnf_path)
		var mx := 0
		var my := 0
		for line in text.split("\n"):
			var t := line.strip_edges()
			if t.begins_with("#define"):
				# 実サーバの phi_dm.cnf はタブ区切り (#define\tMAX_X\t\t8)
				var parts := t.replace("\t", " ").split(" ", false)
				if parts.size() >= 3:
					if parts[1] == "MAX_X":
						mx = parts[2].to_int()
					elif parts[1] == "MAX_Y":
						my = parts[2].to_int()
		if mx > 0 and my > 0:
			return Vector2i(mx, my)
	var dd_path := dir.path_join("phi.dd")
	if FileAccess.file_exists(dd_path):
		var all := PhiRawLines.from_bytes(_read_bytes(dd_path))
		if all.line_count() > 0 and all.lines[0].size() >= 2:
			var sx := all.lines[0].size() / 2
			var sy := 0
			for i in all.line_count():
				if all.line_text(i).begins_with(":T "):
					break
				sy += 1
			if sx > 0 and sy > 0:
				return Vector2i(sx, sy)
	return Vector2i.ZERO


static func _read_bytes(path: String) -> PackedByteArray:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return PackedByteArray()
	return f.get_buffer(f.get_length())


static func _read_text(path: String) -> String:
	return Cp932.decode(_read_bytes(path))


static func _model_dirty(model: RefCounted) -> bool:
	if model == null:
		return false
	var records: Array = model.get("records")
	for rec in records:
		if bool(rec.get("modified", false)):
			return true
	return false


static func _clear_modified(model: RefCounted) -> void:
	var records: Array = model.get("records")
	for rec in records:
		rec["modified"] = false
	var raw: PhiRawLines = model.get("raw_lines")
	if raw != null:
		for i in raw.dirty.size():
			raw.dirty[i] = false


func td_dirty() -> bool:
	return _model_dirty(td)


func swt_dirty() -> bool:
	return _model_dirty(swt)


func ed_dirty() -> bool:
	return _model_dirty(ed)


func od_dirty() -> bool:
	return _model_dirty(od)


func crt_dirty() -> bool:
	return _model_dirty(crt)


func ex_dirty() -> bool:
	return _model_dirty(ex)


func ad_dirty() -> bool:
	return _model_dirty(ad)


func jb_dirty() -> bool:
	return _model_dirty(jb)


func pt_dirty() -> bool:
	return _model_dirty(pt)


func bb_dirty() -> bool:
	return Cp932.encode(bb_text) != _bb_bytes


func inf_dirty() -> bool:
	return Cp932.encode(inf_text) != _inf_bytes


func cls_dirty() -> bool:
	return Cp932.encode(cls_text) != _cls_bytes


## 変更のあるファイルを保存する (.bak を残す)。保存した名前を返す
func save_all() -> Array[String]:
	var saved: Array[String] = []
	if td_dirty():
		_write(dir.path_join("phi.td"), td.serialize())
		_clear_modified(td)
		saved.append("phi.td")
	if swt != null and swt_dirty():
		_write(dir.path_join("phi.swt"), swt.serialize())
		_clear_modified(swt)
		saved.append("phi.swt")
	if ed != null and ed_dirty():
		_write(dir.path_join("phi.ed"), ed.serialize())
		_clear_modified(ed)
		saved.append("phi.ed")
	if od != null and od_dirty():
		_write(dir.path_join("phi.od"), od.serialize())
		_clear_modified(od)
		saved.append("phi.od")
	if crt != null and crt_dirty():
		_write(dir.path_join("phi.crt"), crt.serialize())
		_clear_modified(crt)
		saved.append("phi.crt")
	if ex != null and ex_dirty():
		_write(dir.path_join("phi.ex"), ex.serialize())
		_clear_modified(ex)
		saved.append("phi.ex")
	if ad != null and ad_dirty():
		_write(dir.path_join("phi.ad"), ad.serialize())
		_clear_modified(ad)
		saved.append("phi.ad")
	if jb != null and jb_dirty():
		_write(dir.path_join("phi.jb"), jb.serialize())
		_clear_modified(jb)
		saved.append("phi.jb")
	if pt != null and pt_dirty():
		_write(dir.path_join("phi.pt"), pt.serialize())
		_clear_modified(pt)
		saved.append("phi.pt")
	if cls_dirty():
		_write(dir.path_join("phi.cls"), Cp932.encode(cls_text))
		_cls_bytes = Cp932.encode(cls_text)
		has_cls = true
		saved.append("phi.cls")
	if dd != null and dd.is_dirty():
		_write(dir.path_join("phi.dd"), dd.serialize())
		dd._edited.clear()
		dd.force_dirty = false
		for i in dd.tail.dirty.size():
			dd.tail.dirty[i] = false
		saved.append("phi.dd")
	if fd != null and fd.is_dirty():
		_write(dir.path_join("phi.fd"), fd.serialize())
		fd._edited.clear()
		fd.force_dirty = false
		_clear_modified(fd)
		saved.append("phi.fd")
	if bb_dirty():
		_write(dir.path_join("phi.bb"), Cp932.encode(bb_text))
		_bb_bytes = Cp932.encode(bb_text)
		saved.append("phi.bb")
	if inf_dirty():
		_write(dir.path_join("phi.inf"), Cp932.encode(inf_text))
		_inf_bytes = Cp932.encode(inf_text)
		saved.append("phi.inf")
	return saved


static func _write(path: String, data: PackedByteArray) -> void:
	if FileAccess.file_exists(path):
		var bak := FileAccess.open(path + ".bak", FileAccess.WRITE)
		if bak != null:
			bak.store_buffer(_read_bytes(path))
			bak.close()
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_buffer(data)
		f.close()

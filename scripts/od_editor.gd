extends HSplitContainer
## オブジェクトエディタ (phi.od)。FORMAT_SPEC §8。
## 配置は第3段のマップエディタでも扱う。ここでは表形式で編集する。

var _od: PhiOd
var _list: ItemList
var _detail: VBoxContainer
var _current := -1
var _gra := GraLibrary.new()
var _gra_root := ""
var _gra_names: Array[String] = []
var _gra_paths := {}
var _gra_cache := {}
var _gra_left_note: Label
var _gra_dialog: FileDialog
var _sheet_rect: TextureRect
var _frame_rect: TextureRect
var _frame_label: Label
var _gra_note: Label

const DIR_LABELS: Array[String] = [
	"北", "東", "南", "西", "固定 北面", "固定 東面", "固定 南面", "固定 西面",
]


func setup(project: WorldProject) -> void:
	_od = project.od
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(380, 0)
	add_child(left)
	if _od == null:
		var l := Label.new()
		l.text = "phi.od は無い world です"
		left.add_child(l)
		var cb := Button.new()
		cb.text = "phi.od を新規作成"
		cb.pressed.connect(func() -> void:
			if project.create_file("od"):
				for child in get_children():
					remove_child(child)
					child.queue_free()
				setup(project))
		left.add_child(cb)
		return
	var btns := HBoxContainer.new()
	var add_btn := Button.new()
	add_btn.text = "追加"
	add_btn.pressed.connect(_add)
	var del_btn := Button.new()
	del_btn.text = "削除"
	del_btn.pressed.connect(_delete)
	btns.add_child(add_btn)
	btns.add_child(del_btn)
	left.add_child(btns)
	var gra_btn := Button.new()
	gra_btn.text = "キャラグラフォルダを選ぶ"
	gra_btn.pressed.connect(_on_gra_dir_pressed)
	left.add_child(gra_btn)
	_gra_left_note = Label.new()
	_gra_left_note.add_theme_font_size_override("font_size", 20)
	left.add_child(_gra_left_note)
	_gra.setup_from_cfg()
	_gra_root = _gra.root
	_scan_gra()
	_update_gra_left_note()
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_selected.connect(func(idx: int) -> void: _show(idx))
	left.add_child(_list)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	split_offset = int(left.custom_minimum_size.x)
	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_detail)
	_refresh()


func _refresh() -> void:
	_list.clear()
	for rec in _od.records:
		if String(rec["kind"]) == "O":
			var f: Dictionary = rec["fields"]
			var pos := "隠し"
			if int(f["x"]) >= 0:
				pos = "(%d,%d)" % [int(f["x"]), int(f["y"])]
			_list.add_item("%s %s %s" % [String(f["gname"]), pos,
					String(f["id"])])
		else:
			_list.add_item("(保持行)")


func _record_index(item_idx: int) -> int:
	return item_idx


func _add() -> void:
	var rec := {"kind": "O", "fields": {"x": 1, "y": 1, "gname": "NewObj",
			"dir": 2, "trace": false, "debu": false, "board": false,
			"push": false, "name": "", "id": ""}, "modified": true}
	_od.add_record(rec)
	_refresh()


func _delete() -> void:
	var sel := _list.get_selected_items()
	if sel.is_empty() or String(_od.records[sel[0]]["kind"]) != "O":
		return
	_od.remove_record(sel[0])
	_refresh()


func _show(idx: int) -> void:
	_current = idx
	for child in _detail.get_children():
		_detail.remove_child(child)
		child.queue_free()
	var rec := _od.records[idx]
	if String(rec["kind"]) != "O":
		var l := Label.new()
		l.text = "この行は原文のまま保持されます"
		_detail.add_child(l)
		return
	var f: Dictionary = rec["fields"]
	_build_preview(f)
	var rebuild := func() -> void:
		_od.touch(rec)
		_refresh()
		_list.select(idx)
	var hide := CheckBox.new()
	hide.text = "隠しオブジェクト (マップ上に無い。スイッチ/魔法エフェクト用)"
	hide.button_pressed = int(f["x"]) < 0
	hide.toggled.connect(func(on: bool) -> void:
		if on:
			f["x"] = -1
			f["y"] = -1
		else:
			f["x"] = 1
			f["y"] = 1
		rebuild.call())
	_detail.add_child(hide)
	_num("配置 X", int(f["x"]), func(v: int) -> void:
		f["x"] = v
		rebuild.call())
	_num("配置 Y", int(f["y"]), func(v: int) -> void:
		f["y"] = v
		rebuild.call())
	var gh := HBoxContainer.new()
	var gl := Label.new()
	gl.text = "グラフィック名"
	gl.custom_minimum_size = Vector2(170, 0)
	gh.add_child(gl)
	var ge := LineEdit.new()
	ge.text = String(f["gname"])
	ge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ge.text_changed.connect(func(t: String) -> void:
		f["gname"] = t
		rebuild.call()
		_update_preview(f))
	gh.add_child(ge)
	var gob := OptionButton.new()
	gob.tooltip_text = "フォルダ内のグラから選ぶ"
	if _gra_names.is_empty():
		gob.add_item("(グラなし)")
		gob.disabled = true
	else:
		for gn in _gra_names:
			gob.add_item(gn)
		var cur := _gra_names.find(String(f["gname"]))
		if cur >= 0:
			gob.select(cur)
	gob.item_selected.connect(func(i: int) -> void:
		var gn := gob.get_item_text(i)
		ge.text = gn
		f["gname"] = gn
		rebuild.call()
		_update_preview(f))
	gh.add_child(gob)
	_detail.add_child(gh)
	var dir_ob := OptionButton.new()
	for n in DIR_LABELS:
		dir_ob.add_item(n)
	dir_ob.select(int(f["dir"]))
	dir_ob.item_selected.connect(func(i: int) -> void:
		f["dir"] = i
		rebuild.call()
		_update_preview(f))
	var dh := HBoxContainer.new()
	var dl := Label.new()
	dl.text = "向き"
	dl.custom_minimum_size = Vector2(170, 0)
	dh.add_child(dl)
	dh.add_child(dir_ob)
	_detail.add_child(dh)
	_check("視線追っかけ (近くの人の方を向く)", bool(f["trace"]),
			func(on: bool) -> void:
		f["trace"] = on
		rebuild.call())
	_check("32x32 グラフィック (デブ)", bool(f["debu"]), func(on: bool) -> void:
		f["debu"] = on
		rebuild.call()
		_update_preview(f))
	_check("看板型", bool(f["board"]), func(on: bool) -> void:
		f["board"] = on
		if on:
			f["push"] = false
		rebuild.call())
	_check("押せるオブジェクト", bool(f["push"]), func(on: bool) -> void:
		f["push"] = on
		if on:
			f["board"] = false
		rebuild.call())
	_line("表示名 (空でよい)", String(f["name"]), func(t: String) -> void:
		f["name"] = t
		rebuild.call())
	_line("オブジェクト ID (スイッチから操作する識別子)",
			String(f["id"]), func(t: String) -> void:
		f["id"] = t
		rebuild.call())


func _num(label: String, value: int, on_change: Callable) -> void:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(170, 0)
	h.add_child(l)
	var s := SpinBox.new()
	s.min_value = -1
	s.max_value = 999
	s.value = value
	s.value_changed.connect(func(v: float) -> void: on_change.call(int(v)))
	h.add_child(s)
	_detail.add_child(h)


func _line(label: String, value: String, on_change: Callable) -> void:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(170, 0)
	h.add_child(l)
	var e := LineEdit.new()
	e.text = value
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	e.text_changed.connect(func(t: String) -> void: on_change.call(t))
	h.add_child(e)
	_detail.add_child(h)


func _check(label: String, value: bool, on_change: Callable) -> void:
	var c := CheckBox.new()
	c.text = label
	c.button_pressed = value
	c.toggled.connect(func(on: bool) -> void: on_change.call(on))
	_detail.add_child(c)


# ------------------------------------------------------------ グラ表示

func _on_gra_dir_pressed() -> void:
	if _gra_dialog == null:
		_gra_dialog = FileDialog.new()
		_gra_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
		_gra_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_gra_dialog.transparent = true
		_gra_dialog.title = "キャラグラフォルダを選ぶ"
		_gra_dialog.dir_selected.connect(_on_gra_dir_selected)
		add_child(_gra_dialog)
	if _gra_root != "" and DirAccess.dir_exists_absolute(_gra_root):
		_gra_dialog.current_dir = _gra_root
	_gra_dialog.popup_centered(Vector2i(900, 600))


func _on_gra_dir_selected(dir: String) -> void:
	_gra_root = dir
	_gra.set_root(dir)
	_scan_gra()
	_update_gra_left_note()
	if _current >= 0:
		_show(_current)


func _update_gra_left_note() -> void:
	if _gra_left_note == null:
		return
	if _gra_names.is_empty():
		_gra_left_note.text = "グラが見つかりません"
	else:
		_gra_left_note.text = "グラ %d 件" % _gra_names.size()


func _scan_gra() -> void:
	_gra.scan()
	_gra_names = _gra.names
	_gra_paths = _gra.paths


func _gra_data(path: String) -> Dictionary:
	return _gra.data_for(path)


func _build_preview(f: Dictionary) -> void:
	var head := Label.new()
	head.text = "■ グラフィック"
	head.add_theme_color_override("font_color", AppTheme.GOLD)
	_detail.add_child(head)
	var h := HBoxContainer.new()
	var sv := VBoxContainer.new()
	_sheet_rect = TextureRect.new()
	_sheet_rect.custom_minimum_size = Vector2(144, 192)
	_sheet_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sheet_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_sheet_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sv.add_child(_sheet_rect)
	var sl := Label.new()
	sl.text = "全体"
	sv.add_child(sl)
	h.add_child(sv)
	var fv := VBoxContainer.new()
	_frame_rect = TextureRect.new()
	_frame_rect.custom_minimum_size = Vector2(128, 128)
	_frame_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_frame_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_frame_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fv.add_child(_frame_rect)
	_frame_label = Label.new()
	_frame_label.text = "向き"
	fv.add_child(_frame_label)
	h.add_child(fv)
	_detail.add_child(h)
	_gra_note = Label.new()
	_gra_note.add_theme_font_size_override("font_size", 20)
	_detail.add_child(_gra_note)
	_update_preview(f)


func _update_preview(f: Dictionary) -> void:
	if _sheet_rect == null:
		return
	var gname := String(f["gname"])
	var path := String(_gra_paths.get(gname.to_lower(), ""))
	if path == "":
		_sheet_rect.texture = null
		_frame_rect.texture = null
		_frame_label.text = "向き"
		_gra_note.text = "グラ '%s' が見つかりません (フォルダを確認)" % gname
		return
	var data := _gra_data(path)
	if data.is_empty():
		_gra_note.text = "グラ '%s' を読み込めません" % gname
		return
	var img: Image = data["img"]
	_sheet_rect.texture = data["tex"]
	_frame_rect.texture = _gra.frame_texture(img, int(f["dir"]) % 4,
			bool(f["debu"]))
	_frame_label.text = "向き: %s" % DIR_LABELS[int(f["dir"])]
	_gra_note.text = path.get_file()

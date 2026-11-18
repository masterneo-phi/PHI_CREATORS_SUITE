extends HSplitContainer
## マップエディタ (phi.dd + phi.fd + phi.od 統合)。FORMAT_SPEC §2/§3/§8。
## サイズは phi_dm.cnf 由来 (WorldProject.map_size)。無い場合は
## 最初にサイズを指定して新規作成する (正方形のみ)。

signal coord_picked(x: int, y: int)
signal pick_cancelled

var _project: WorldProject
var _canvas: MapCanvas
var _hsb: HScrollBar
var _vsb: VScrollBar
var _syncing_bars := false
var _status: Label
var _palette_grid: GridContainer
var _area_list: ItemList
var _roof_check: CheckBox
var _e_detail: VBoxContainer
var _e_flag_boxes: Array[CheckBox] = []
var _obj_detail: VBoxContainer
var _cell_label: Label
var _sheet_ob: OptionButton
var _chip_dir := ""
var _tool_buttons := {}
var _zoom_ob: OptionButton
var _zoom2x_check: CheckBox
var _zoom_base := 24
var _zoom_2x := false

const ZOOM_SIZES: Array[int] = [8, 12, 16, 24, 32, 48]
const TOOLS: Array = [
	["terrain", "地形ペン"], ["fill", "塗りつぶし"], ["surface", "見た目(:T)"],
	["area", "エリアペン"], ["object", "オブジェクト"],
]


func setup(project: WorldProject) -> void:
	_project = project
	if project.dd == null:
		_build_create_ui()
		return
	_build_editor_ui()


func _build_create_ui() -> void:
	var v := VBoxContainer.new()
	add_child(v)
	var l := Label.new()
	l.text = "この world にはマップ (phi.dd) がありません。\n" \
			+ "マップサイズはサーバのコンパイル設定 (phi_dm.cnf の MAX_X/MAX_Y) で決まります。\n" \
			+ "作るサイズを指定してください (正方形のみ、最大1000)。"
	v.add_child(l)
	var spin := SpinBox.new()
	spin.min_value = 8
	spin.max_value = 1000
	spin.value = 64
	v.add_child(spin)
	var b := Button.new()
	b.text = "このサイズでマップを新規作成"
	b.pressed.connect(func() -> void:
		_project.create_map(int(spin.value))
		for child in get_children():
			remove_child(child)
			child.queue_free()
		_build_editor_ui())
	v.add_child(b)
	if _project.map_size.x > 0:
		var l2 := Label.new()
		l2.text = "phi_dm.cnf の寸法は %d x %d です" % [_project.map_size.x,
				_project.map_size.y]
		v.add_child(l2)


func _build_editor_ui() -> void:
	# 左: 道具とパレット (縦に長くなるのでスクロール可能にする)
	var left_scroll := ScrollContainer.new()
	left_scroll.custom_minimum_size = Vector2(350, 0)
	add_child(left_scroll)
	split_offset = 350
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.add_child(left)
	var chip_btn := Button.new()
	chip_btn.text = "チップフォルダを選ぶ"
	chip_btn.pressed.connect(_on_chip_dir_pressed)
	left.add_child(chip_btn)
	_sheet_ob = OptionButton.new()
	_sheet_ob.item_selected.connect(func(_i: int) -> void: _load_sheet())
	left.add_child(_sheet_ob)
	var tool_group := ButtonGroup.new()
	for t in TOOLS:
		var b := Button.new()
		b.text = String(t[1])
		b.toggle_mode = true
		b.button_group = tool_group
		b.pressed.connect(func() -> void: _set_tool(String(t[0])))
		left.add_child(b)
		_tool_buttons[String(t[0])] = b
	(_tool_buttons["terrain"] as Button).button_pressed = true
	_roof_check = CheckBox.new()
	_roof_check.text = "屋根を付ける"
	_roof_check.toggled.connect(func(on: bool) -> void:
		_canvas.pen_roof = on)
	left.add_child(_roof_check)
	_zoom_ob = OptionButton.new()
	for z in ZOOM_SIZES:
		_zoom_ob.add_item("%d px" % z)
	_zoom_ob.select(3)
	_zoom_ob.item_selected.connect(func(i: int) -> void:
		_zoom_base = ZOOM_SIZES[i]
		_apply_zoom()
		_save_zoom_cfg())
	left.add_child(_zoom_ob)
	_zoom2x_check = CheckBox.new()
	_zoom2x_check.text = "拡大 ×2"
	_zoom2x_check.toggled.connect(func(on: bool) -> void:
		_zoom_2x = on
		_apply_zoom()
		_save_zoom_cfg())
	left.add_child(_zoom2x_check)
	_load_zoom_cfg()
	var area_check := CheckBox.new()
	area_check.text = "エリアを表示"
	area_check.toggled.connect(func(on: bool) -> void:
		_canvas.show_area = on
		_canvas.queue_redraw())
	left.add_child(area_check)
	var obj_check := CheckBox.new()
	obj_check.text = "オブジェクトを表示"
	obj_check.button_pressed = true
	obj_check.toggled.connect(func(on: bool) -> void:
		_canvas.show_objects = on
		_canvas.queue_redraw())
	left.add_child(obj_check)
	var spawn_check := CheckBox.new()
	spawn_check.text = "敵の出現位置を表示"
	spawn_check.button_pressed = true
	spawn_check.toggled.connect(func(on: bool) -> void:
		_canvas.show_spawns = on
		_canvas.queue_redraw())
	left.add_child(spawn_check)
	var swt_check := CheckBox.new()
	swt_check.text = "スイッチ位置を表示"
	swt_check.button_pressed = true
	swt_check.toggled.connect(func(on: bool) -> void:
		_canvas.show_switches = on
		_canvas.queue_redraw())
	left.add_child(swt_check)
	var pl := Label.new()
	pl.text = "■ 地形パレット (右クリックで吸い取り)"
	pl.clip_text = true
	pl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	left.add_child(pl)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 190)
	left.add_child(scroll)
	_palette_grid = GridContainer.new()
	_palette_grid.columns = 3
	scroll.add_child(_palette_grid)
	_build_palette()
	var al := Label.new()
	al.text = "■ エリア"
	left.add_child(al)
	_area_list = ItemList.new()
	_area_list.custom_minimum_size = Vector2(0, 300)
	_area_list.item_selected.connect(_on_area_selected)
	left.add_child(_area_list)
	var add_area := Button.new()
	add_area.text = "エリア定義 (:E) を追加"
	add_area.pressed.connect(_add_area)
	left.add_child(add_area)
	var el := Label.new()
	el.text = "■ エリア定義 (:E)"
	el.add_theme_color_override("font_color", AppTheme.GOLD)
	left.add_child(el)
	_e_detail = VBoxContainer.new()
	left.add_child(_e_detail)
	_refresh_areas()
	# 中央: キャンバス + スクロールバー (周囲に余白枠を付ける)
	var frame := PanelContainer.new()
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fs := AppTheme.style(Color(0.10, 0.10, 0.12),
			Color(0.55, 0.58, 0.65))
	fs.content_margin_left = 10
	fs.content_margin_right = 10
	fs.content_margin_top = 10
	fs.content_margin_bottom = 10
	frame.add_theme_stylebox_override("panel", fs)
	var inner := HSplitContainer.new()
	add_child(inner)
	inner.add_child(frame)
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.add_child(mid)
	var row1 := HBoxContainer.new()
	row1.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_child(row1)
	_canvas = MapCanvas.new()
	_canvas.dd = _project.dd
	_canvas.fd = _project.fd
	_canvas.od = _project.od
	_canvas.cell_px = _zoom_base * (2 if _zoom_2x else 1)
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas.hover_changed.connect(_on_hover)
	_canvas.object_picked.connect(_on_object_picked)
	_canvas.painted.connect(_refresh_status)
	_canvas.coord_picked.connect(_on_coord_picked)
	_canvas.pick_cancelled.connect(_on_pick_cancelled)
	_canvas.offset_changed.connect(_sync_scrollbars)
	_canvas.resized.connect(_update_scrollbars)
	row1.add_child(_canvas)
	_vsb = VScrollBar.new()
	_vsb.custom_minimum_size = Vector2(16, 0)
	_vsb.value_changed.connect(_on_vsb)
	row1.add_child(_vsb)
	var row2 := HBoxContainer.new()
	mid.add_child(row2)
	_hsb = HScrollBar.new()
	_hsb.custom_minimum_size = Vector2(0, 16)
	_hsb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hsb.value_changed.connect(_on_hsb)
	row2.add_child(_hsb)
	var corner := Control.new()
	corner.custom_minimum_size = Vector2(16, 16)
	row2.add_child(corner)
	# 右: 情報とオブジェクト詳細
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(370, 0)
	inner.add_child(right)
	inner.split_offset = 1000000 # 右は最小幅で開始
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_status)
	_cell_label = Label.new()
	_cell_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_cell_label)
	var ol := Label.new()
	ol.text = "■ オブジェクト"
	ol.add_theme_color_override("font_color", AppTheme.GOLD)
	right.add_child(ol)
	_obj_detail = VBoxContainer.new()
	right.add_child(_obj_detail)
	_init_chip_dir()
	refresh_marks()
	_refresh_status()


## 座標指定モードに入る (他エディタからの依頼)。
func begin_coord_pick() -> void:
	if _canvas == null:
		return
	_canvas.pick_mode = true
	_status.text = "座標指定中: マップをクリックすると座標が入ります。" \
			+ "右クリックで中止"
	_canvas.queue_redraw()


func _on_coord_picked(x: int, y: int) -> void:
	_canvas.pick_mode = false
	_canvas.queue_redraw()
	coord_picked.emit(x, y)


func _on_pick_cancelled() -> void:
	_canvas.pick_mode = false
	_canvas.queue_redraw()
	pick_cancelled.emit()


## 信号を出さずに座標指定モードを抜ける (手動のエディタ切替時)。
func end_coord_pick() -> void:
	if _canvas != null:
		_canvas.pick_mode = false
		_canvas.queue_redraw()


## 敵の出現位置とスイッチ位置のマーカーを作り直す。
func refresh_marks() -> void:
	if _canvas == null:
		return
	var spawns: Array = []
	if _project.ed != null:
		for b in _project.ed.blocks():
			var f: Dictionary = _project.ed.records[int(b["header"])]["fields"]
			spawns.append({"x": int(String(f["ix"])), "y": int(String(f["iy"])),
					"label": String(f["name"]).substr(0, 4)})
	var switches: Array = []
	var targets: Array = []
	if _project.swt != null:
		for rec in _project.swt.records:
			if String(rec["kind"]) != "S":
				continue
			var f: Dictionary = rec["fields"]
			switches.append({"x": int(f.get("sx", 0)), "y": int(f.get("sy", 0)),
					"label": "SW"})
			targets.append({"x": int(f.get("ax", 0)), "y": int(f.get("ay", 0))})
	_canvas.spawn_points = spawns
	_canvas.switch_points = switches
	_canvas.switch_targets = targets
	_canvas.queue_redraw()


func _set_tool(tool: String) -> void:
	_canvas.mode = tool


func _build_palette() -> void:
	for child in _palette_grid.get_children():
		_palette_grid.remove_child(child)
		child.queue_free()
	for code in PhiDd.PALETTE:
		var b := Button.new()
		b.text = String(PhiDd.CODE_TO_PAIR.get(code, "  "))
		b.tooltip_text = String(PhiDd.CODE_TO_NAME.get(code, ""))
		b.toggle_mode = true
		# 地形そのものの色をボタンの地にする (第6段: 色が潰れないように)
		var base: Color = MapCanvas.FALLBACK_COLORS.get(code,
				Color(0.35, 0.35, 0.35))
		b.add_theme_stylebox_override("normal",
				AppTheme.style(base.darkened(0.10)))
		b.add_theme_stylebox_override("hover",
				AppTheme.style(base.lightened(0.15)))
		b.add_theme_stylebox_override("pressed",
				AppTheme.style(base.lightened(0.30), AppTheme.GOLD))
		b.add_theme_color_override("font_color", Color.WHITE)
		b.add_theme_color_override("font_hover_color", Color.WHITE)
		b.add_theme_color_override("font_pressed_color", Color.WHITE)
		b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		b.add_theme_constant_override("outline_size", 6)
		var c := code
		b.pressed.connect(func() -> void:
			_canvas.pen_code = c
			_set_tool("terrain")
			(_tool_buttons["terrain"] as Button).button_pressed = true)
		_palette_grid.add_child(b)


func _refresh_areas() -> void:
	_area_list.clear()
	if _project.fd == null:
		return
	for code in _project.fd.used_codes():
		var ei := _project.fd.find_e(code)
		var name := "(未定義)"
		if ei >= 0:
			name = String(_project.fd.records[ei]["fields"]["name"])
		_area_list.add_item("%02x %s" % [code, name])
		_area_list.set_item_metadata(_area_list.item_count - 1, code)


func _on_area_selected(idx: int) -> void:
	var code := int(_area_list.get_item_metadata(idx))
	_canvas.pen_area = code
	_canvas.highlight_area = code
	_canvas.queue_redraw()
	_show_e(code)


func _add_area() -> void:
	var fd := _project.fd
	var used := fd.used_codes()
	var next := 0
	while next in used:
		next += 1
	if next > 0xFF:
		return
	var rec := {"kind": "E", "fields": {"code": "%02x" % next,
			"floor": "00", "name": "New Area", "flags": "",
			"name_width": 0}, "modified": true}
	fd.records.append(rec)
	fd.raw_lines.lines.append(PackedByteArray())
	fd.raw_lines.eols.append("\n".to_utf8_buffer())
	fd.raw_lines.dirty.append(false)
	_refresh_areas()


func _show_e(code: int) -> void:
	for child in _e_detail.get_children():
		_e_detail.remove_child(child)
		child.queue_free()
	var fd := _project.fd
	var ei := fd.find_e(code)
	if ei < 0:
		var l := Label.new()
		l.text = "エリア %02x の :E 定義がありません" % code
		_e_detail.add_child(l)
		return
	var rec := fd.records[ei]
	var f: Dictionary = rec["fields"]
	_e_field("名前", String(f["name"]), func(t: String) -> void:
		f["name"] = t
		fd.touch(rec)
		_refresh_areas())
	_e_field("階コード (16進2桁)", String(f["floor"]), func(t: String) -> void:
		f["floor"] = t
		fd.touch(rec))
	var flags := String(f["flags"])
	_e_flag_boxes.clear()
	var flag_grid := GridContainer.new()
	flag_grid.columns = 2
	_e_detail.add_child(flag_grid)
	for ch in PhiFd.FLAG_NAMES.keys():
		var c := CheckBox.new()
		c.text = "%s: %s" % [ch, String(PhiFd.FLAG_NAMES[ch])]
		c.add_theme_font_size_override("font_size", 23)
		c.set_meta("flag_char", ch)
		c.button_pressed = flags.contains(ch)
		c.toggled.connect(func(_on: bool) -> void:
			var s := ""
			for b in _e_flag_boxes:
				if b.button_pressed:
					s += String(b.get_meta("flag_char"))
			# Call 先 (小文字) は保持する
			for ch2 in String(f["flags"]):
				if ch2 >= "a" and ch2 <= "z":
					s += ch2
			f["flags"] = s
			fd.touch(rec))
		_e_flag_boxes.append(c)
		flag_grid.add_child(c)
	var mapset := ""
	for r in fd.records:
		if String(r["kind"]) == "S" and String(r["fields"]["rest"]).lstrip(" ") \
				.begins_with("%02x" % code):
			mapset = String(r["fields"]["rest"]).lstrip(" ").substr(3)
	var ml := Label.new()
	ml.text = "チップセット (:S): %s" % (mapset if mapset != "" else "(なし)")
	_e_detail.add_child(ml)


func _e_field(label: String, value: String, on_change: Callable) -> void:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(140, 0)
	h.add_child(l)
	var e := LineEdit.new()
	e.text = value
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	e.text_changed.connect(func(t: String) -> void: on_change.call(t))
	h.add_child(e)
	_e_detail.add_child(h)


func _on_hover(x: int, y: int) -> void:
	_refresh_status(x, y)


## --- スクロールバー ---

func _apply_zoom() -> void:
	if _canvas == null:
		return
	_canvas.cell_px = _zoom_base * (2 if _zoom_2x else 1)
	_canvas.queue_redraw()
	_update_scrollbars()


func _save_zoom_cfg() -> void:
	var cfg := ConfigFile.new()
	cfg.load("user://creators.cfg")
	cfg.set_value("map", "zoom", _zoom_base)
	cfg.set_value("map", "zoom_2x", _zoom_2x)
	cfg.save("user://creators.cfg")


func _load_zoom_cfg() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://creators.cfg") != OK:
		return
	_zoom_base = int(cfg.get_value("map", "zoom", 24))
	_zoom_2x = bool(cfg.get_value("map", "zoom_2x", false))
	var idx := ZOOM_SIZES.find(_zoom_base)
	if idx >= 0:
		_zoom_ob.select(idx)
	_zoom2x_check.button_pressed = _zoom_2x


func _update_scrollbars() -> void:
	if _canvas == null or _project == null or _project.dd == null:
		return
	_canvas.clamp_offset()
	_syncing_bars = true
	var cols := int(_canvas.size.x) / maxi(1, _canvas.cell_px)
	var rows := int(_canvas.size.y) / maxi(1, _canvas.cell_px)
	_hsb.max_value = _project.dd.size_x
	_hsb.page = maxi(1, cols)
	_hsb.value = _canvas.offset.x
	_vsb.max_value = _project.dd.size_y
	_vsb.page = maxi(1, rows)
	_vsb.value = _canvas.offset.y
	_syncing_bars = false


func _sync_scrollbars() -> void:
	if _syncing_bars or _canvas == null:
		return
	_syncing_bars = true
	_hsb.value = _canvas.offset.x
	_vsb.value = _canvas.offset.y
	_syncing_bars = false


func _on_hsb(v: float) -> void:
	if _syncing_bars or _canvas == null:
		return
	_canvas.offset.x = v
	_canvas.queue_redraw()


func _on_vsb(v: float) -> void:
	if _syncing_bars or _canvas == null:
		return
	_canvas.offset.y = v
	_canvas.queue_redraw()


func _refresh_status(x: int = -1, y: int = -1) -> void:
	if _canvas == null or _project.dd == null:
		return
	if x < 0:
		return
	var dd := _project.dd
	var code := dd.code_at(x, y)
	var s := "(%d, %d) %s %s" % [x, y,
			String(PhiDd.CODE_TO_PAIR.get(code, "  ")),
			String(PhiDd.CODE_TO_NAME.get(code, ""))]
	if dd.roof_at(x, y):
		s += " 屋根"
	if _project.fd != null:
		var ac := _project.fd.code_at(x, y)
		s += "\nエリア %02x" % ac
		var ei := _project.fd.find_e(ac)
		if ei >= 0:
			s += " " + String(_project.fd.records[ei]["fields"]["name"])
	_status.text = s


func _on_object_picked(rec_idx: int) -> void:
	for child in _obj_detail.get_children():
		_obj_detail.remove_child(child)
		child.queue_free()
	if rec_idx < 0 or _project.od == null:
		return
	var rec := _project.od.records[rec_idx]
	var f: Dictionary = rec["fields"]
	var l := Label.new()
	l.text = "%s (ID: %s)\n位置 (%d, %d) — ドラッグで移動できます" % [
			String(f["gname"]), String(f["id"]), int(f["x"]), int(f["y"])]
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_obj_detail.add_child(l)
	var hide := Button.new()
	hide.text = "マップから隠す"
	hide.pressed.connect(func() -> void:
		f["x"] = -1
		f["y"] = -1
		_project.od.touch(rec)
		_canvas.queue_redraw())
	_obj_detail.add_child(hide)


## --- チップシート ---

func _init_chip_dir() -> void:
	var cfg := ConfigFile.new()
	cfg.load("user://creators.cfg")
	_chip_dir = String(cfg.get_value("chip", "dir", ""))
	if _chip_dir == "" or not DirAccess.dir_exists_absolute(_chip_dir):
		var exe := OS.get_executable_path().get_base_dir()
		for cand in [exe.path_join("chip_tofup"), exe.path_join("chip_pcgl"),
				"/home/hatch/workspace/.zipstage/mac/chip_tofup"]:
			if DirAccess.dir_exists_absolute(cand):
				_chip_dir = cand
				break
	_refresh_sheet_list()


func _refresh_sheet_list() -> void:
	_sheet_ob.clear()
	if _chip_dir == "":
		return
	var files: Array[String] = []
	for fn in DirAccess.get_files_at(_chip_dir):
		if fn.to_lower().ends_with(".bmp"):
			files.append(fn)
	files.sort()
	for fn in files:
		_sheet_ob.add_item(fn)
	# fd の :S (エリア00) が指すシートを優先
	var want := "Base.bmp"
	if _project.fd != null:
		for r in _project.fd.records:
			if String(r["kind"]) == "S":
				var rest := String(r["fields"]["rest"]).lstrip(" ")
				if rest.begins_with("00"):
					want = rest.substr(3).strip_edges() + ".bmp"
					break
	for i in _sheet_ob.item_count:
		if _sheet_ob.get_item_text(i) == want:
			_sheet_ob.select(i)
			break
	_load_sheet()


func _load_sheet() -> void:
	if _canvas == null or _sheet_ob.item_count == 0:
		return
	var path := _chip_dir.path_join(_sheet_ob.get_item_text(_sheet_ob.selected))
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var img := BmpLoader.decode_bmp(f.get_buffer(f.get_length()))
	f.close()
	if img == null:
		return
	_canvas.chip_tex = ImageTexture.create_from_image(BmpLoader.mask_h(img))
	_canvas.queue_redraw()


func _on_chip_dir_pressed() -> void:
	var dlg := FileDialog.new()
	dlg.transparent = true # Mac で黒く潰れないように (NeoPHI の教訓)
	dlg.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	dlg.access = FileDialog.ACCESS_FILESYSTEM
	dlg.dir_selected.connect(func(d: String) -> void:
		_chip_dir = d
		var cfg := ConfigFile.new()
		cfg.load("user://creators.cfg")
		cfg.set_value("chip", "dir", d)
		cfg.save("user://creators.cfg")
		_refresh_sheet_list())
	add_child(dlg)
	dlg.popup_centered(Vector2i(900, 600))

extends HSplitContainer
## スイッチエディタ (phi.swt)。FORMAT_SPEC §7。
## 左の一覧で選び、右でプルダウン (条件・動作の種別) と
## 欄入力で編集する。原文の行も常に表示し、手書き編集もできる。
## コメント・空行などの行は保持専用として表示する。

var _project: WorldProject
var _swt: PhiSwt
var _list: ItemList
var _detail: VBoxContainer
var _indices: Array[int] = []
var _current := -1 ## records の番号


func setup(project: WorldProject) -> void:
	_project = project
	_swt = project.swt
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(520, 0)
	add_child(left)
	if _swt == null:
		var l := Label.new()
		l.text = "phi.swt は無い world です"
		left.add_child(l)
		var cb := Button.new()
		cb.text = "phi.swt を新規作成"
		cb.pressed.connect(func() -> void:
			if project.create_file("swt"):
				for child in get_children():
					remove_child(child)
					child.queue_free()
				setup(project))
		left.add_child(cb)
		return
	var btns := GridContainer.new()
	btns.columns = 3
	var add_s := Button.new()
	add_s.text = "新規 :S"
	add_s.pressed.connect(func() -> void:
		_swt.add_record({"kind": "S", "fields": {"sx": 0, "sy": 0,
				"cc": 1, "cond": ["00", "0000"], "ax": 0, "ay": 0,
				"dd": 16, "act": ["0", '"テキスト"']}, "modified": true})
		_refresh_list())
	var del := Button.new()
	del.text = "削除"
	del.pressed.connect(func() -> void:
		if _current >= 0:
			_swt.remove_record(_current)
			_current = -1
			_refresh_list())
	btns.add_child(add_s)
	btns.add_child(del)
	var ai_ask := Button.new()
	ai_ask.text = "AIに頼む"
	ai_ask.pressed.connect(_show_ai_ask)
	btns.add_child(ai_ask)
	var ai_imp := Button.new()
	ai_imp.text = "AIから取り込む"
	ai_imp.pressed.connect(_show_ai_import)
	btns.add_child(ai_imp)
	var lib_btn := Button.new()
	lib_btn.text = "作例ライブラリ"
	lib_btn.pressed.connect(_show_library)
	btns.add_child(lib_btn)
	# AI ボタンは水色にして目立たせる
	for b in [ai_ask, ai_imp]:
		b.add_theme_stylebox_override("normal",
				AppTheme.style(Color(0.62, 0.85, 0.98)))
		b.add_theme_stylebox_override("hover",
				AppTheme.style(Color(0.76, 0.92, 1.0)))
		b.add_theme_stylebox_override("pressed",
				AppTheme.style(Color(0.48, 0.76, 0.96)))
	left.add_child(btns)
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_selected.connect(_on_selected)
	left.add_child(_list)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	split_offset = int(left.custom_minimum_size.x)
	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_detail)
	_refresh_list()


func _refresh_list() -> void:
	_indices.clear()
	_list.clear()
	for i in _swt.records.size():
		var rec := _swt.records[i]
		_indices.append(i)
		_list.add_item(_summary(i, rec))
	if _current >= 0 and _current < _swt.records.size():
		_list.select(_indices.find(_current))
		_show_detail(_current)


func _summary(i: int, rec: Dictionary) -> String:
	var f: Dictionary = rec.get("fields", {})
	match String(rec["kind"]):
		"S":
			return "(%03d,%03d) %s → (%03d,%03d) %s" % [
				int(f.get("sx", 0)), int(f.get("sy", 0)),
				HelpTexts.cc_name(int(f.get("cc", 0))),
				int(f.get("ax", 0)), int(f.get("ay", 0)),
				HelpTexts.dd_name(int(f.get("dd", 0)))]
		"A":
			return "メッセージ %04d → %04d" % [int(f.get("no", 0)),
					int(f.get("next", 0))]
		"M":
			return "メニュー %04d" % int(f.get("no", 0))
	var line := _swt.raw_lines.line_text(i)
	return line.substr(0, 60) if line != "" else "(空行)"


func _on_selected(idx: int) -> void:
	_current = _indices[idx]
	_show_detail(_current)


# ---------------------------------------------------------------- AI 支援

func _ai_window(title: String) -> Array:
	var win := Window.new()
	win.title = title
	win.transparent = true # Mac で黒く潰れないように
	win.size = Vector2i(940, 720)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	win.add_child(v)
	add_child(win)
	win.popup_centered()
	return [win, v]


func _show_ai_ask() -> void:
	var parts := _ai_window("AIに頼む")
	var v: VBoxContainer = parts[1]
	var help := Label.new()
	help.text = "この文を自分の Muse (AI) に貼り、末尾の「作りたい仕掛け」を書き換えて送ってください。\n返ってきた :S 行は「AIから取り込む」で検証してから追加できます。"
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(help)
	var te := TextEdit.new()
	te.text = SwtAi.build_context(_project)
	te.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(te)
	var row := HBoxContainer.new()
	v.add_child(row)
	var copy_btn := Button.new()
	copy_btn.text = "全部コピー"
	copy_btn.pressed.connect(func() -> void:
		DisplayServer.clipboard_set(te.text)
		copy_btn.text = "コピーしました")
	row.add_child(copy_btn)
	var close_btn := Button.new()
	close_btn.text = "閉じる"
	var win: Window = parts[0]
	close_btn.pressed.connect(func() -> void: win.hide())
	row.add_child(close_btn)


func _show_ai_import() -> void:
	var parts := _ai_window("AIから取り込む")
	var v: VBoxContainer = parts[1]
	var win: Window = parts[0]
	var help := Label.new()
	help.text = "AI が返した :S 行を貼ってください。書式の往復チェック・条件/動作の定義・座標の範囲を検証し、通った行だけを追加します。"
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(help)
	var te := TextEdit.new()
	te.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(te)
	var result := Label.new()
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(result)
	var row := HBoxContainer.new()
	v.add_child(row)
	var imp := Button.new()
	imp.text = "検証して取り込む"
	imp.pressed.connect(func() -> void:
		var r := SwtAi.validate_lines(te.text, _project.map_size)
		var n := 0
		for rec in r["ok"]:
			_swt.add_record(rec)
			n += 1
		if n > 0:
			_refresh_list()
		var msg := "%d 件を取り込みました。" % n
		var errs: Array = r["errors"]
		if not errs.is_empty():
			msg += "\n取り込めなかった行:\n" + "\n".join(errs)
		result.text = msg)
	row.add_child(imp)
	var close_btn := Button.new()
	close_btn.text = "閉じる"
	close_btn.pressed.connect(func() -> void: win.hide())
	row.add_child(close_btn)


# ------------------------------------------------------------ 作例ライブラリ

var _lib_entries: Array = []
var _lib_list: ItemList
var _lib_preview: Label
var _lib_status: Label


func _show_library() -> void:
	var parts := _ai_window("スイッチ作例ライブラリ")
	var v: VBoxContainer = parts[1]
	var win: Window = parts[0]
	var help := Label.new()
	help.text = "座標と文章を伏せた作例集です。選んで「この作例を追加」すると下書きとして入るので、座標と文章を直して使ってください。\n「この世界から作例を生成」は、今開いている世界のスイッチを同じ規則で伏せて自分のライブラリに足します。"
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(help)
	_lib_status = Label.new()
	v.add_child(_lib_status)
	_lib_list = ItemList.new()
	_lib_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lib_list.item_selected.connect(func(idx: int) -> void:
		_lib_preview.text = String(_lib_entries[idx]["line"]))
	v.add_child(_lib_list)
	_lib_preview = Label.new()
	_lib_preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_lib_preview)
	var row := HBoxContainer.new()
	v.add_child(row)
	var add_btn := Button.new()
	add_btn.text = "この作例を追加"
	add_btn.pressed.connect(func() -> void:
		var sel := _lib_list.get_selected_items()
		if sel.is_empty():
			return
		var line := String(_lib_entries[sel[0]]["line"])
		if line.begins_with(":S"):
			var r := SwtAi.validate_lines(line, _project.map_size)
			if (r["ok"] as Array).is_empty():
				_lib_status.text = "この作例は現在の世界には追加できません"
				return
			_swt.add_record(r["ok"][0])
		else:
			var p2 := PhiSwt.parse(PhiRawLines.from_bytes(Cp932.encode(line)))
			if p2.records.is_empty():
				return
			_swt.add_record(p2.records[0])
		_refresh_list()
		_lib_status.text = "作例を追加しました (座標と文章を直してください)")
	row.add_child(add_btn)
	var gen_btn := Button.new()
	gen_btn.text = "この世界から作例を生成"
	gen_btn.pressed.connect(func() -> void:
		var made := SwtLibrary.build_entries(_swt)
		var added := SwtLibrary.append_user_entries(made)
		_refresh_library()
		_lib_status.text = "この世界から %d 件の作例を新しく足しました" % added)
	row.add_child(gen_btn)
	var exp_btn := Button.new()
	exp_btn.text = "書き出し"
	exp_btn.pressed.connect(func() -> void:
		var fd := FileDialog.new()
		fd.transparent = true # Mac で黒く潰れないように
		fd.file_mode = FileDialog.FILE_MODE_SAVE_FILE
		fd.access = FileDialog.ACCESS_FILESYSTEM
		fd.current_file = "switch_library.txt"
		fd.file_selected.connect(func(path: String) -> void:
			var f := FileAccess.open(path, FileAccess.WRITE)
			if f != null:
				f.store_string(SwtLibrary.entries_to_text(_lib_entries))
			fd.queue_free())
		add_child(fd)
		fd.popup_centered_ratio(0.7))
	row.add_child(exp_btn)
	var imp_btn := Button.new()
	imp_btn.text = "読み込み"
	imp_btn.pressed.connect(func() -> void:
		var fd := FileDialog.new()
		fd.transparent = true
		fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		fd.access = FileDialog.ACCESS_FILESYSTEM
		fd.file_selected.connect(func(path: String) -> void:
			var f := FileAccess.open(path, FileAccess.READ)
			if f != null:
				var es := SwtLibrary.parse_library_text(f.get_as_text())
				var added := SwtLibrary.append_user_entries(es)
				_refresh_library()
				_lib_status.text = "%d 件の作例を読み込みました" % added
			fd.queue_free())
		add_child(fd)
		fd.popup_centered_ratio(0.7))
	row.add_child(imp_btn)
	var close_btn := Button.new()
	close_btn.text = "閉じる"
	close_btn.pressed.connect(func() -> void: win.hide())
	row.add_child(close_btn)
	_refresh_library()


func _refresh_library() -> void:
	_lib_entries = SwtLibrary.load_all()
	_lib_list.clear()
	for e in _lib_entries:
		var line := String(e["line"])
		_lib_list.add_item("%s ｜ %s" % [String(e["label"]),
				line.substr(0, 72)])
	_lib_status.text = "作例 %d 件" % _lib_entries.size()


func _clear_detail() -> void:
	for child in _detail.get_children():
		_detail.remove_child(child)
		child.queue_free()


func _spin_row(label: String, value: int, maxv: int,
		on_change: Callable) -> SpinBox:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(150, 0)
	h.add_child(l)
	var s := SpinBox.new()
	s.min_value = 0
	s.max_value = maxv
	s.value = value
	s.value_changed.connect(func(v: float) -> void: on_change.call(int(v)))
	h.add_child(s)
	_detail.add_child(h)
	return s


func _line_row(label: String, value: String, on_change: Callable) -> LineEdit:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(150, 0)
	h.add_child(l)
	var e := LineEdit.new()
	e.text = value
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	e.text_changed.connect(func(t: String) -> void: on_change.call(t))
	h.add_child(e)
	_detail.add_child(h)
	return e


func _atoms_box(title: String, atoms: Array) -> VBoxContainer:
	var l := Label.new()
	l.text = title
	_detail.add_child(l)
	var box := VBoxContainer.new()
	_detail.add_child(box)
	for a in atoms:
		var e := LineEdit.new()
		e.text = String(a)
		box.add_child(e)
	return box


func _read_atoms(box: VBoxContainer) -> Array:
	var out: Array = []
	for child in box.get_children():
		out.append((child as LineEdit).text)
	return out


func _show_detail(rec_idx: int) -> void:
	_clear_detail()
	var rec := _swt.records[rec_idx]
	var f: Dictionary = rec["fields"]
	var kind := String(rec["kind"])
	if kind == "S":
		_show_s(rec, f)
	elif kind == "A":
		_show_a(rec, f)
	elif kind == "M":
		_show_m(rec, f)
	else:
		var l := Label.new()
		l.text = "この行は保持専用です (コメント・空行など):\n"
		l.text += _swt.raw_lines.line_text(rec_idx)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_detail.add_child(l)
		return
	# 原文の行 (手書き編集)
	var original_line := PhiSwt.build_line(rec)
	if not bool(rec.get("modified", false)):
		original_line = _swt.raw_lines.line_text(rec_idx)
	_line_row("原文の行", original_line, func(t: String) -> void:
		var parsed := PhiSwt._parse_line(t)
		if String(parsed["kind"]) != "raw":
			rec["fields"] = parsed["fields"]
			rec["kind"] = parsed["kind"]
			_swt.touch(rec)
			_list.set_item_text(_indices.find(rec_idx),
					_summary(rec_idx, rec)))


func _request_pick(handler: Callable) -> void:
	var m := get_tree().get_first_node_in_group("creators_main")
	if m != null:
		m.call("request_coord_pick", handler)


func _pick_button(label: String, handler: Callable) -> void:
	var b := Button.new()
	b.text = label
	b.pressed.connect(func() -> void: _request_pick(handler))
	_detail.add_child(b)


func _show_s(rec: Dictionary, f: Dictionary) -> void:
	var sx_spin := _spin_row("設置 X", int(f["sx"]), 999, func(v: int) -> void:
		f["sx"] = v
		_commit(rec))
	var sy_spin := _spin_row("設置 Y", int(f["sy"]), 999, func(v: int) -> void:
		f["sy"] = v
		_commit(rec))
	_pick_button("設置位置をマップで指定", func(x: int, y: int) -> void:
		sx_spin.value = x
		sy_spin.value = y
		f["sx"] = x
		f["sy"] = y
		_commit(rec))
	var cc_box := _kind_option("条件", HelpTexts.CC_NAMES, int(f["cc"]),
			func(v: int) -> void:
		f["cc"] = v
		_commit(rec))
	_detail.add_child(cc_box)
	var cond_box := _atoms_box("条件パラメータ", f.get("cond", []))
	cond_box.child_exiting_tree.connect(func() -> void: pass)
	var apply_cond := Button.new()
	apply_cond.text = "条件パラメータを反映"
	apply_cond.pressed.connect(func() -> void:
		f["cond"] = _read_atoms(cond_box)
		_commit(rec))
	_detail.add_child(apply_cond)
	var ax_spin := _spin_row("動作 X", int(f["ax"]), 999, func(v: int) -> void:
		f["ax"] = v
		_commit(rec))
	var ay_spin := _spin_row("動作 Y", int(f["ay"]), 999, func(v: int) -> void:
		f["ay"] = v
		_commit(rec))
	_pick_button("動作位置をマップで指定", func(x: int, y: int) -> void:
		ax_spin.value = x
		ay_spin.value = y
		f["ax"] = x
		f["ay"] = y
		_commit(rec))
	var dd_box := _kind_option("動作", HelpTexts.DD_NAMES, int(f["dd"]),
			func(v: int) -> void:
		f["dd"] = v
		_commit(rec))
	_detail.add_child(dd_box)
	var act_box := _atoms_box("動作パラメータ", f.get("act", []))
	var apply_act := Button.new()
	apply_act.text = "動作パラメータを反映"
	apply_act.pressed.connect(func() -> void:
		f["act"] = _read_atoms(act_box)
		_commit(rec))
	_detail.add_child(apply_act)
	if f.has("tail_raw"):
		_line_row("末尾 (原文の残り)", String(f["tail_raw"]),
				func(t: String) -> void:
			f["tail_raw"] = t
			_commit(rec))


func _show_a(rec: Dictionary, f: Dictionary) -> void:
	_spin_row("メッセージ番号", int(f["no"]), 9999, func(v: int) -> void:
		f["no"] = v
		_commit(rec))
	_spin_row("次の番号 (0=終わり)", int(f["next"]), 9999,
			func(v: int) -> void:
		f["next"] = v
		_commit(rec))
	_spin_row("待ち", int(f["wait"]), 9999, func(v: int) -> void:
		f["wait"] = v
		_commit(rec))
	var tail_kind := int(f.get("tail_kind", -1))
	if tail_kind == 1:
		var hl := Label.new()
		hl.text = "末尾はテレポート (x) です"
		hl.modulate = Color(0.75, 0.75, 0.75)
		_detail.add_child(hl)
		var parts := String(f.get("text", "")).split(" ", false)
		var st := {"x": 0, "y": 0}
		if parts.size() >= 3:
			st["x"] = String(parts[1]).to_int()
			st["y"] = String(parts[2]).to_int()
		var x_spin := _spin_row("転送先 X", int(st["x"]), 999,
				func(v: int) -> void:
			st["x"] = v
			f["text"] = "x %03d %03d" % [v, int(st["y"])]
			_commit(rec))
		var y_spin := _spin_row("転送先 Y", int(st["y"]), 999,
				func(v: int) -> void:
			st["y"] = v
			f["text"] = "x %03d %03d" % [int(st["x"]), v]
			_commit(rec))
		_pick_button("転送先をマップで指定", func(x: int, y: int) -> void:
			st["x"] = x
			st["y"] = y
			x_spin.value = x
			y_spin.value = y
			f["text"] = "x %03d %03d" % [x, y]
			_commit(rec))
	elif tail_kind == 2:
		var hl2 := Label.new()
		hl2.text = "末尾はフラグ操作 (f) です"
		hl2.modulate = Color(0.75, 0.75, 0.75)
		_detail.add_child(hl2)
		_line_row("フラグ (flagno)", String(f.get("text", "")).substr(2),
				func(t: String) -> void:
			f["text"] = "f " + t
			_commit(rec))
	else:
		_line_row("末尾 (テキスト等)", String(f.get("text", "")),
				func(t: String) -> void:
			f["text"] = t
			_commit(rec))


func _show_m(rec: Dictionary, f: Dictionary) -> void:
	_spin_row("メニュー番号", int(f["no"]), 9999, func(v: int) -> void:
		f["no"] = v
		_commit(rec))
	_line_row("パターン", String(f.get("pattern", "")),
			func(t: String) -> void:
		f["pattern"] = t
		_commit(rec))
	_line_row("キャプション", String(f.get("caption", "")),
			func(t: String) -> void:
		f["caption"] = t
		_commit(rec))
	_line_row("動作", String(f.get("action", "")),
			func(t: String) -> void:
		f["action"] = t
		_commit(rec))


func _kind_option(label: String, names: Dictionary, current: int,
		on_change: Callable) -> HBoxContainer:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(150, 0)
	h.add_child(l)
	var ob := OptionButton.new()
	var keys := names.keys()
	keys.sort()
	if not keys.has(current):
		keys.append(current)
		keys.sort()
	for k in keys:
		ob.add_item("%02d %s" % [int(k), String(names.get(k, "不明"))])
		ob.set_item_metadata(ob.item_count - 1, int(k))
	ob.select(keys.find(current))
	ob.item_selected.connect(func(idx: int) -> void:
		on_change.call(int(ob.get_item_metadata(idx))))
	h.add_child(ob)
	return h


func _commit(rec: Dictionary) -> void:
	_swt.touch(rec)
	var idx := _swt.records.find(rec)
	if idx >= 0:
		var li := _indices.find(idx)
		if li >= 0:
			_list.set_item_text(li, _summary(idx, rec))

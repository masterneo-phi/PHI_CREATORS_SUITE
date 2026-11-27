extends HSplitContainer
## ジョブ／性別エディタ (phi.jb)。PHIDM_NEO 拡張。
## phi.jb が存在するだけでジョブ／性別システムが有効になる。
## 書かなかった項目はサーバ標準 (PhiJb の BASE_*) が使われるため、
## ここでは「上書き」だけをレコードとして持つ。

var _jb: PhiJb
var _list: ItemList
var _detail: VBoxContainer
var _items: Array[Dictionary] = []
var _sel := -1


func setup(project: WorldProject) -> void:
	_jb = project.jb
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(330, 0)
	add_child(left)
	if _jb == null:
		var l := Label.new()
		l.text = "phi.jb は無い world です (ジョブ／性別は無効)"
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		left.add_child(l)
		var cb := Button.new()
		cb.text = "phi.jb を新規作成 (有効化)"
		cb.pressed.connect(func() -> void:
			if project.create_file("jb"):
				for child in get_children():
					remove_child(child)
					child.queue_free()
				setup(project))
		left.add_child(cb)
		return
	_items.clear()
	for no in [1, 2]:
		_items.append({"kind": "S", "no": no})
	for no in range(1, PhiJb.MAX_JOB + 1):
		_items.append({"kind": "N", "no": no})
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_selected.connect(func(idx: int) -> void: _show(idx))
	left.add_child(_list)
	var note := Label.new()
	note.text = "率の上限は標準値の150%です (サーバが丸めます)。"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(note)
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
	for it in _items:
		var kind := String(it["kind"])
		var no := int(it["no"])
		if kind == "S":
			_list.add_item("性別 %d: %s" % [no, _jb.sex_name(no)])
		else:
			_list.add_item("職業 %d: %s" % [no, _jb.job_name(no)])
	if _sel >= 0 and _sel < _items.size():
		_list.select(_sel)
		_show(_sel)


func _show(idx: int) -> void:
	_sel = idx
	for child in _detail.get_children():
		_detail.remove_child(child)
		child.queue_free()
	var it := _items[idx]
	var kind := String(it["kind"])
	var no := int(it["no"])
	var base_name := PhiJb.BASE_SEXNAMES[no] if kind == "S" \
			else PhiJb.BASE_NAMES[no]
	var ri := _jb.find_record(kind, no)
	var cur := ""
	if ri >= 0:
		cur = String(_jb.records[ri]["fields"].get("name", ""))
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = "名前 (標準: %s)" % base_name
	l.custom_minimum_size = Vector2(190, 0)
	h.add_child(l)
	var e := LineEdit.new()
	e.text = cur
	e.placeholder_text = base_name
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	e.text_changed.connect(func(t: String) -> void:
		_set_name(kind, no, t))
	h.add_child(e)
	_detail.add_child(h)
	if kind == "N":
		for slot in PhiJb.SLOTS[no]:
			_rate_row(no, slot)
	var del := Button.new()
	del.text = "この項目の上書きを消す (標準に戻す)"
	del.pressed.connect(func() -> void:
		_clear_item(kind, no)
		_show(idx))
	_detail.add_child(del)


func _set_name(kind: String, no: int, t: String) -> void:
	var ri := _jb.find_record(kind, no)
	if t == "":
		if ri >= 0:
			_jb.remove_record(ri)
		return
	if ri >= 0:
		_jb.records[ri]["fields"]["name"] = t
		_jb.touch(_jb.records[ri])
	else:
		_jb.add_record({"kind": kind, "fields": {"no": no, "name": t},
				"modified": true})
	_refresh_names_only()


func _refresh_names_only() -> void:
	for i in _items.size():
		var kind := String(_items[i]["kind"])
		var no := int(_items[i]["no"])
		if kind == "S":
			_list.set_item_text(i, "性別 %d: %s" % [no, _jb.sex_name(no)])
		else:
			_list.set_item_text(i, "職業 %d: %s" % [no, _jb.job_name(no)])


func _rate_row(no: int, slot: int) -> void:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = String(PhiJb.RATE_LABELS[no][slot])
	l.custom_minimum_size = Vector2(190, 0)
	h.add_child(l)
	var s := SpinBox.new()
	s.min_value = 0
	s.max_value = PhiJb.rate_cap(no, slot)
	s.value = _jb.job_rate(no, slot)
	s.tooltip_text = "標準 %d / 上限 %d" % [int(PhiJb.BASE_RATES[no][slot]),
			PhiJb.rate_cap(no, slot)]
	s.value_changed.connect(func(v: float) -> void:
		_set_rate(no, slot, int(v)))
	h.add_child(s)
	var base := Label.new()
	base.text = "標準 %d / 上限 %d" % [int(PhiJb.BASE_RATES[no][slot]),
			PhiJb.rate_cap(no, slot)]
	base.modulate = Color(0.75, 0.75, 0.75)
	h.add_child(base)
	_detail.add_child(h)


func _set_rate(no: int, slot: int, v: int) -> void:
	var ri := _jb.find_record("R", no)
	if ri < 0:
		var rates: Array = []
		for s2 in PhiJb.SLOTS[no]:
			rates.append(str(_jb.job_rate(no, s2)))
		rates[slot] = str(v)
		_jb.add_record({"kind": "R", "fields": {"no": no, "rates": rates},
				"modified": true})
		return
	var rec := _jb.records[ri]
	var rates: Array = rec["fields"].get("rates", []).duplicate()
	while rates.size() < PhiJb.SLOTS[no]:
		rates.append(str(_jb.job_rate(no, rates.size())))
	rates[slot] = str(v)
	rec["fields"]["rates"] = rates
	_jb.touch(rec)


func _clear_item(kind: String, no: int) -> void:
	var ri := _jb.find_record(kind, no)
	if ri >= 0:
		_jb.remove_record(ri)
	if kind == "N":
		ri = _jb.find_record("R", no)
		if ri >= 0:
			_jb.remove_record(ri)
	_refresh_names_only()

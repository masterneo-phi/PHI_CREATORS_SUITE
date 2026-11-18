extends HBoxContainer
## オブジェクトエディタ (phi.od)。FORMAT_SPEC §8。
## 配置は第3段のマップエディタでも扱う。ここでは表形式で編集する。

var _od: PhiOd
var _list: ItemList
var _detail: VBoxContainer
var _current := -1

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
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_selected.connect(func(idx: int) -> void: _show(idx))
	left.add_child(_list)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(scroll)
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
	_line("グラフィック名 (最大15文字)", String(f["gname"]), func(t: String) -> void:
		f["gname"] = t
		rebuild.call())
	var dir_ob := OptionButton.new()
	for n in DIR_LABELS:
		dir_ob.add_item(n)
	dir_ob.select(int(f["dir"]))
	dir_ob.item_selected.connect(func(i: int) -> void:
		f["dir"] = i
		rebuild.call())
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
		rebuild.call())
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

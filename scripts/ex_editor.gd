extends HSplitContainer
## ゲート制限エディタ (phi.ex)。FORMAT_SPEC §10。
## グループ = :G/:g + :I/:i/:M/:m + '.' 。許可 (:i/:m) は
## 禁止より前に置く必要がある。

var _ex: PhiEx
var _list: ItemList
var _detail: VBoxContainer

const KIND_LABELS := {
	"G": "輸出ゲート (この世界から出る)", "g": "輸入ゲート (この世界へ来る)",
	"I": "禁止アイテム", "i": "許可アイテム (例外)",
	"M": "禁止魔法", "m": "許可魔法 (例外)",
}


func setup(project: WorldProject) -> void:
	_ex = project.ex
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(450, 0)
	add_child(left)
	if _ex == null:
		var l := Label.new()
		l.text = "phi.ex は無い world です (制限なし)"
		left.add_child(l)
		var cb := Button.new()
		cb.text = "phi.ex を新規作成"
		cb.pressed.connect(func() -> void:
			if project.create_file("ex"):
				for child in get_children():
					remove_child(child)
					child.queue_free()
				setup(project))
		left.add_child(cb)
		return
	var btns := HBoxContainer.new()
	for letter in ["G", "g", "I", "i", "M", "m"]:
		var b := Button.new()
		b.text = ":" + letter
		b.pressed.connect(func() -> void: _add(letter))
		btns.add_child(b)
	var del_btn := Button.new()
	del_btn.text = "削除"
	del_btn.pressed.connect(_delete)
	btns.add_child(del_btn)
	left.add_child(btns)
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
	for i in _ex.records.size():
		var rec := _ex.records[i]
		var kind := String(rec["kind"])
		if kind in KIND_LABELS:
			_list.add_item(PhiEx.build_line(rec).substr(0, 52))
		elif kind == "term":
			_list.add_item(".")
		else:
			_list.add_item(_ex.raw_lines.line_text(i))


func _add(letter: String) -> void:
	var rec: Dictionary
	if letter in ["G", "g"]:
		rec = {"kind": letter, "fields": {"x": "---", "y": "---",
				"name": "*", "ip": "*.*", "rest": "", "name_width": 0},
				"modified": true}
	else:
		rec = {"kind": letter, "fields": {
				"rest": " *                               ---- -- - -- -- -- --"},
				"modified": true}
	_ex.add_record(rec)
	_refresh()


func _delete() -> void:
	var sel := _list.get_selected_items()
	if sel.is_empty():
		return
	_ex.remove_record(sel[0])
	_refresh()


func _show(idx: int) -> void:
	for child in _detail.get_children():
		_detail.remove_child(child)
		child.queue_free()
	var rec := _ex.records[idx]
	var kind := String(rec["kind"])
	if not (kind in KIND_LABELS):
		var l := Label.new()
		l.text = "この行は原文のまま保持されます"
		_detail.add_child(l)
		return
	var title := Label.new()
	title.text = String(KIND_LABELS[kind])
	_detail.add_child(title)
	var f: Dictionary = rec["fields"]
	if kind in ["G", "g"]:
		_field("ゲート X (--- は全て)", String(f["x"]), func(t: String) -> void:
			f["x"] = t
			_touch(rec, idx))
		_field("ゲート Y", String(f["y"]), func(t: String) -> void:
			f["y"] = t
			_touch(rec, idx))
		_field("ゲート名 (ワイルドカード可)", String(f["name"]),
				func(t: String) -> void:
			f["name"] = t
			_touch(rec, idx))
		_field("行き先 IP ('-' はサーバ内、ワイルドカード可)",
				String(f["ip"]), func(t: String) -> void:
			f["ip"] = t
			_touch(rec, idx))
	else:
		var data := String(f["rest"]).lstrip(" ")
		var applied := func(new_data: String) -> void:
			f["rest"] = " " + new_data
			_touch(rec, idx)
		var ok := false
		if kind in ["I", "i"]:
			ok = ItemForm.build_item_form(_detail, data, applied)
		else:
			ok = ItemForm.build_spell_form(_detail, data, applied)
		if not ok:
			_field("データ (ワイルドカード可)", data,
					func(t: String) -> void:
				f["rest"] = " " + t
				_touch(rec, idx))
		var help := Label.new()
		help.text = "パターン: ワイルドカード (* ? - など) が使えます" \
				if kind in ["I", "i"] else \
				"魔法パターン: 効果番号 -- はワイルドカード"
		help.modulate = Color(0.75, 0.75, 0.75)
		_detail.add_child(help)


func _touch(rec: Dictionary, idx: int) -> void:
	_ex.touch(rec)
	_list.set_item_text(idx, PhiEx.build_line(rec).substr(0, 52))


func _field(label: String, value: String, on_change: Callable) -> void:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(200, 0)
	h.add_child(l)
	var e := LineEdit.new()
	e.text = value
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	e.text_changed.connect(func(t: String) -> void: on_change.call(t))
	h.add_child(e)
	_detail.add_child(h)

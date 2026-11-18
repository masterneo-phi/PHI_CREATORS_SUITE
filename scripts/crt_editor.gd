extends HBoxContainer
## クリエイトエディタ (phi.crt)。FORMAT_SPEC §9。
## レシピ = [:L] :P/:F :S :S の厳密な並びを崩さないよう、
## 行リスト + 原文データ編集で扱う。

var _crt: PhiCrt
var _list: ItemList
var _detail: VBoxContainer

const KIND_LABELS := {
	"L": "必要レベル", "P": "成功時の生成物", "F": "失敗時の生成物",
	"S": "素材",
}


func setup(project: WorldProject) -> void:
	_crt = project.crt
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(360, 0)
	add_child(left)
	if _crt == null:
		var l := Label.new()
		l.text = "phi.crt は無い world です (汎用 Create のみ)"
		left.add_child(l)
		return
	var add_btn := Button.new()
	add_btn.text = "レシピを追加 (末尾)"
	add_btn.pressed.connect(_add_recipe)
	left.add_child(add_btn)
	var note := Label.new()
	note.text = "並びは :L? → :P/:F → :S → :S が必須です"
	note.modulate = Color(0.75, 0.75, 0.75)
	left.add_child(note)
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
	for i in _crt.records.size():
		var rec := _crt.records[i]
		var kind := String(rec["kind"])
		if kind in KIND_LABELS:
			_list.add_item(":%s %s" % [kind,
					String(rec["fields"]["rest"]).substr(0, 48)])
		elif kind == "term":
			_list.add_item(".")
		else:
			_list.add_item(_crt.raw_lines.line_text(i))


func _add_recipe() -> void:
	for proto in [":P New item                      0001 01 n 00 00 00 00",
			":S Material1                     0001 01 n 00 00 00 00",
			":S Material2                     0001 01 n 00 00 00 00", "."]:
		var rec: Dictionary
		if proto == ".":
			rec = {"kind": "term", "fields": {}, "modified": true}
		else:
			rec = {"kind": proto[1], "fields": {"rest": proto.substr(2)},
					"modified": true}
		_crt.add_record(rec)
	_refresh()


func _show(idx: int) -> void:
	for child in _detail.get_children():
		_detail.remove_child(child)
		child.queue_free()
	var rec := _crt.records[idx]
	var kind := String(rec["kind"])
	if not (kind in KIND_LABELS):
		var l := Label.new()
		l.text = "この行は原文のまま保持されます"
		_detail.add_child(l)
		return
	var title := Label.new()
	title.text = String(KIND_LABELS[kind])
	_detail.add_child(title)
	var e := LineEdit.new()
	e.text = String(rec["fields"]["rest"])
	e.text_changed.connect(func(t: String) -> void:
		rec["fields"]["rest"] = t
		_crt.touch(rec)
		_list.set_item_text(idx, ":%s %s" % [kind, t.substr(0, 48)]))
	_detail.add_child(e)
	var help := Label.new()
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	match kind:
		"L":
			help.text = "このレベル以下の PC は作れません。2倍のレベルで成功率100%。"
		"P", "F":
			help.text = "アイテムデータ (名前 type wp fn op×4)。ワイルドカードは使えません。"
		"S":
			help.text = "素材のアイテムデータ。ワイルドカード (* や -- や 60^ など) が使えます。"
	_detail.add_child(help)

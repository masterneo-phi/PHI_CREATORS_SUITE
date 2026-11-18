extends HBoxContainer
## クリエイトエディタ (phi.crt)。FORMAT_SPEC §9。
## 第5段: エネミーエディタと同じく「1ブロック = 1クリエイト設定」で扱う。
## レシピ = [:L] :P/:F :S :S の厳密な並びを崩さないよう、
## ブロック内の各行は原文データ (rest) を編集する。

var _crt: PhiCrt
var _list: ItemList
var _detail: VBoxContainer
var _blocks: Array[Dictionary] = []

const KIND_LABELS := {
	"L": "必要レベル", "P": "成功時の生成物", "F": "失敗時の生成物",
	"S": "素材",
}

const KIND_HELP := {
	"L": "このレベル以下の PC は作れません。2倍のレベルで成功率100%。",
	"P": "アイテムデータ (名前 type wp fn op×4)。ワイルドカードは使えません。",
	"F": "アイテムデータ (名前 type wp fn op×4)。ワイルドカードは使えません。",
	"S": "素材のアイテムデータ。ワイルドカード (* や -- や 60^ など) が使えます。",
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
	_blocks = _crt.blocks()
	_list.clear()
	for b in _blocks:
		_list.add_item(_crt.block_summary(b))


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
	_show(_blocks.size() - 1)


func _delete_block(bi: int) -> void:
	if bi < 0 or bi >= _blocks.size():
		return
	var b := _blocks[bi]
	for i in range(int(b["end"]), int(b["start"]) - 1, -1):
		_crt.remove_record(i)
	for child in _detail.get_children():
		_detail.remove_child(child)
		child.queue_free()
	_refresh()


func _show(bi: int) -> void:
	for child in _detail.get_children():
		_detail.remove_child(child)
		child.queue_free()
	if bi < 0 or bi >= _blocks.size():
		return
	var b := _blocks[bi]
	var title := Label.new()
	title.text = "レシピ: " + _crt.block_summary(b)
	title.add_theme_color_override("font_color", AppTheme.GOLD)
	_detail.add_child(title)
	for i in range(int(b["start"]), int(b["end"]) + 1):
		var rec := _crt.records[i]
		var kind := String(rec["kind"])
		if kind == "term":
			var tl := Label.new()
			tl.text = ". (レシピの終わり)"
			tl.modulate = Color(0.7, 0.7, 0.7)
			_detail.add_child(tl)
			continue
		if not (kind in KIND_LABELS):
			var rl := Label.new()
			rl.text = _crt.raw_lines.line_text(i) + " (原文のまま保持)"
			_detail.add_child(rl)
			continue
		var head := Label.new()
		head.text = ":%s %s" % [kind, String(KIND_LABELS[kind])]
		_detail.add_child(head)
		var e := LineEdit.new()
		e.text = String(rec["fields"]["rest"])
		var rec_ref := rec
		e.text_changed.connect(func(t: String) -> void:
			rec_ref["fields"]["rest"] = t
			_crt.touch(rec_ref)
			_blocks = _crt.blocks()
			_list.set_item_text(bi, _crt.block_summary(_blocks[bi])))
		_detail.add_child(e)
		var help := Label.new()
		help.text = String(KIND_HELP[kind])
		help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		help.modulate = Color(0.75, 0.75, 0.75)
		_detail.add_child(help)
	var del := Button.new()
	del.text = "このレシピを削除"
	del.pressed.connect(func() -> void: _delete_block(bi))
	_detail.add_child(del)

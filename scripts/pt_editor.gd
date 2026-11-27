extends HSplitContainer
## ペット調整エディタ (phi.pt)。PHIDM_NEO 拡張。
## phi.pt が無くてもペットは標準値で動く。このファイルには
## 「上書き」だけをレコードとして持つ。範囲はサーバのエンジン
## 上限 (pet_cfg_caps) で、超えた値はサーバ側でも丸められる。

var _pt: PhiPt
var _list: ItemList
var _detail: VBoxContainer
var _sel := ""

const PAGES: Array[String] = ["all", "fairy", "cat", "dog", "bird"]


func setup(project: WorldProject) -> void:
	_pt = project.pt
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(330, 0)
	add_child(left)
	if _pt == null:
		var l := Label.new()
		l.text = "phi.pt は無い world です (ペットは標準値で動きます)"
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		left.add_child(l)
		var cb := Button.new()
		cb.text = "phi.pt を新規作成 (調整を始める)"
		cb.pressed.connect(func() -> void:
			if project.create_file("pt"):
				for child in get_children():
					remove_child(child)
					child.queue_free()
				setup(project))
		left.add_child(cb)
		return
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_selected.connect(func(idx: int) -> void:
		_show(PAGES[idx]))
	left.add_child(_list)
	for p in PAGES:
		if p == "all":
			_list.add_item("共通 (all)")
		else:
			_list.add_item(String(PhiPt.TYPE_NAMES[p]))
	var note := Label.new()
	note.text = "物理追撃は 確率×威力 が 2500 を超えるとサーバが威力を" \
			+ "丸めます (期待値25%まで)。支援の間隔は支援確率が 0 でない時に 1〜3600 秒です。"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(note)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	split_offset = int(left.custom_minimum_size.x)
	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_detail)
	_show("all")
	_list.select(0)


func _show(page: String) -> void:
	_sel = page
	for child in _detail.get_children():
		_detail.remove_child(child)
		child.queue_free()
	if page == "all":
		for g in PhiPt.GLOBALS:
			_row("all", String(g[0]), String(g[1]), int(g[3]), int(g[4]),
					_pt.global_value(String(g[0])), int(g[2]))
	else:
		for k in PhiPt.KEYS:
			var key := String(k[0])
			_row(page, key, String(k[1]), int(k[2]), int(k[3]),
					_pt.value(page, key),
					int((PhiPt.DEFAULTS.get(page, {}) as Dictionary).get(key, 0)))
	var del := Button.new()
	del.text = "この種類の上書きを全部消す (標準に戻す)"
	del.pressed.connect(func() -> void:
		var i := 0
		while i < _pt.records.size():
			var rec := _pt.records[i]
			if String(rec["kind"]) == "P" and PhiPt.norm_type(
					String(rec["fields"]["type"])) == page:
				_pt.remove_record(i)
			else:
				i += 1
		_show(page))
	_detail.add_child(del)


func _row(page: String, key: String, label: String, minv: int, maxv: int,
		value: int, base: int) -> void:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = "%s (%s)" % [label, key]
	l.custom_minimum_size = Vector2(250, 0)
	h.add_child(l)
	var s := SpinBox.new()
	s.min_value = minv
	s.max_value = maxv
	s.value = value
	s.tooltip_text = "標準 %d / 範囲 %d〜%d" % [base, minv, maxv]
	s.value_changed.connect(func(v: float) -> void:
		_set_value(page, key, int(v)))
	h.add_child(s)
	var bl := Label.new()
	bl.text = "標準 %d" % base
	bl.modulate = Color(0.75, 0.75, 0.75)
	h.add_child(bl)
	_detail.add_child(h)


func _set_value(page: String, key: String, v: int) -> void:
	var ri := _pt.find_record(page, key)
	if ri >= 0:
		_pt.records[ri]["fields"]["value"] = v
		_pt.touch(_pt.records[ri])
	else:
		_pt.add_record({"kind": "P", "fields": {"type": page, "key": key,
				"value": v}, "modified": true})

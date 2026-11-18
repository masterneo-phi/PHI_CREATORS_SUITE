extends HBoxContainer
## マスター権限エディタ (phi.ad)。FORMAT_SPEC §13。
## ブロック = :<uid> <ip> <権限文字列> [:A 領土] '.'

var _ad: PhiAd
var _list: ItemList
var _detail: VBoxContainer
var _block := {}

const AUTH_ORDER: Array[String] = [
	"A", "B", "K", "U", "D", "R", "I", "L", "S", "T", "Q", "u", "d", "r",
]


func setup(project: WorldProject) -> void:
	_ad = project.ad
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(260, 0)
	add_child(left)
	if _ad == null:
		var l := Label.new()
		l.text = "phi.ad は無い world です"
		left.add_child(l)
		return
	var btns := HBoxContainer.new()
	var add_btn := Button.new()
	add_btn.text = "権限を追加"
	add_btn.pressed.connect(_add_block)
	var del_btn := Button.new()
	del_btn.text = "削除"
	del_btn.pressed.connect(_delete_block)
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


func _blocks() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var start := -1
	for i in _ad.records.size():
		var kind := String(_ad.records[i]["kind"])
		if kind == "head":
			start = i
		elif kind == "term" and start >= 0:
			out.append({"head": start, "end": i})
			start = -1
	return out


func _refresh() -> void:
	_list.clear()
	for b in _blocks():
		var f: Dictionary = _ad.records[int(b["head"])]["fields"]
		_list.add_item("%s (%s)" % [String(f["uid"]), String(f["auth"])])


func _add_block() -> void:
	var head := {"kind": "head", "fields": {"uid": "NEWID",
			"ip": "127.0.0.1", "auth": ""}, "modified": true}
	var term := {"kind": "term", "fields": {}, "modified": true}
	_ad.add_record(head)
	_ad.add_record(term)
	_refresh()


func _delete_block() -> void:
	if _block.is_empty():
		return
	var start := int(_block["head"])
	var count := int(_block["end"]) - start + 1
	for k in count:
		_ad.remove_record(start)
	_block = {}
	_refresh()


func _show(idx: int) -> void:
	_block = _blocks()[idx]
	for child in _detail.get_children():
		_detail.remove_child(child)
		child.queue_free()
	var rec := _ad.records[int(_block["head"])]
	var f: Dictionary = rec["fields"]
	_field("キャラ ID", String(f["uid"]), func(t: String) -> void:
		f["uid"] = t
		_ad.touch(rec)
		_refresh())
	_field("IP パターン (ワイルドカード可)", String(f["ip"]),
			func(t: String) -> void:
		f["ip"] = t
		_ad.touch(rec))
	var auth := String(f["auth"])
	var checks := {}
	var gl := Label.new()
	gl.text = "権限 (A は全権限。その他は必要なものだけ)"
	_detail.add_child(gl)
	for ch in AUTH_ORDER:
		var c := CheckBox.new()
		c.text = "%s: %s" % [ch, String(PhiAd.AUTH_NAMES[ch])]
		c.button_pressed = auth.contains(ch)
		checks[ch] = c
		c.toggled.connect(func(_on: bool) -> void:
			var s := ""
			for k in AUTH_ORDER:
				if (checks[k] as CheckBox).button_pressed:
					s += k
			f["auth"] = s
			_ad.touch(rec)
			_refresh())
		_detail.add_child(c)
	# 領土 (:A) があれば編集欄を出す
	for i in range(int(_block["head"]) + 1, int(_block["end"])):
		var r := _ad.records[i]
		if String(r["kind"]) == "A":
			_field("領土 (16進エリア、範囲は 00-05 の形)",
					String(r["fields"]["rest"]).lstrip(" "),
					func(t: String) -> void:
				r["fields"]["rest"] = " " + t
				_ad.touch(r))


func _field(label: String, value: String, on_change: Callable) -> void:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(190, 0)
	h.add_child(l)
	var e := LineEdit.new()
	e.text = value
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	e.text_changed.connect(func(t: String) -> void: on_change.call(t))
	h.add_child(e)
	_detail.add_child(h)

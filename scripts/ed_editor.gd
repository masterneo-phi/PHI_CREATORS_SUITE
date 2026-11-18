extends HBoxContainer
## エネミーエディタ (phi.ed)。FORMAT_SPEC §5。
## 左で敵を選び、右でヘッダ (能力値) とサブレコードを編集する。

var _project: WorldProject
var _ed: PhiEd
var _list: ItemList
var _detail: VBoxContainer
var _block := {} ## 現在の {header, end}
var _sub_list: ItemList
var _sub_detail: VBoxContainer
var _sub_indices: Array[int] = []
var _ix_edit: LineEdit
var _iy_edit: LineEdit

const TYPE_NAMES: Array[String] = [
	"知的生物", "獣", "狂戦士", "魔法生物", "不死", "精神体", "消去者",
]
const TALK_NAMES: Array[String] = [
	"発話しない", "攻撃時", "逃走/危機時", "勝利時", "死亡時", "挨拶",
	"キーワード応答",
]
const HEADER_LABELS: Array = [
	["nm", "同時出現数", "同時に存在できる最大数"],
	["type", "種別", ""],
	["align", "カルマ", "小さいほど善/秩序。50 が境界"],
	["moral", "モラル", "逃走しやすさ"],
	["sp", "移動速度", "小さいほど速い (50=とても遅い、20=かなり速い)"],
	["flv", "戦士レベル", "出現時に +0〜99 される"],
	["wlv", "魔法レベル", "出現時に +0〜99 される"],
	["mhp", "最大 HP", "出現時に ±25%。5000 以上で巨大化 (知的生物を除く)"],
	["mmp", "最大 MP", "出現時に ±25%"],
	["gp", "所持金", "出現時に 50〜150%"],
	["ix", "出現中心 X", ""],
	["iy", "出現中心 Y", ""],
	["d", "出現半径", "中心から ±d の範囲に出る"],
	["st", "出現開始時", "00〜24"],
	["et", "出現終了時", "24 は常時"],
]


func setup(project: WorldProject) -> void:
	_project = project
	_ed = project.ed
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(220, 0)
	add_child(left)
	if _ed == null:
		var l := Label.new()
		l.text = "phi.ed は無い world です"
		left.add_child(l)
		return
	var btns := HBoxContainer.new()
	var add_btn := Button.new()
	add_btn.text = "敵を追加"
	add_btn.pressed.connect(_add_enemy)
	var del_btn := Button.new()
	del_btn.text = "敵を削除"
	del_btn.pressed.connect(_delete_enemy)
	btns.add_child(add_btn)
	btns.add_child(del_btn)
	left.add_child(btns)
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_selected.connect(_on_enemy_selected)
	left.add_child(_list)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_detail)
	_refresh_list()


func _refresh_list() -> void:
	_list.clear()
	for b in _ed.blocks():
		var rec := _ed.records[int(b["header"])]
		_list.add_item(String(rec["fields"]["name"]))


func _on_enemy_selected(idx: int) -> void:
	_block = _ed.blocks()[idx]
	_show_enemy()


func _add_enemy() -> void:
	var header := {"kind": "header", "fields": {
			"name": "NewEnemy", "name_width": 31, "nm": "01",
			"type": "01", "align": "50", "moral": "50", "sp": "30",
			"flv": "0100", "wlv": "0100", "mhp": "0100", "mmp": "0100",
			"gp": "0000", "ix": "001", "iy": "001", "d": "02",
			"st": "00", "et": "24"}, "modified": true}
	var term := {"kind": "term", "fields": {}, "modified": true}
	# 末尾の単独 '.' より前に挿入する (ローダの数えパスが止まるため)
	var insert_at := _ed.records.size()
	if insert_at > 0 and String(_ed.records[insert_at - 1]["kind"]) == "raw" \
			and _ed.raw_lines.line_text(insert_at - 1) == ".":
		insert_at -= 1
	_insert_record(insert_at, header)
	_insert_record(insert_at + 1, term)
	_refresh_list()


func _insert_record(at: int, rec: Dictionary) -> void:
	_ed.raw_lines.lines.insert(at, PackedByteArray())
	_ed.raw_lines.eols.insert(at, "\n".to_utf8_buffer())
	_ed.raw_lines.dirty.insert(at, false)
	rec["modified"] = true
	_ed.records.insert(at, rec)


func _delete_enemy() -> void:
	if _block.is_empty():
		return
	var start := int(_block["header"])
	var count := int(_block["end"]) - start + 1
	for k in count:
		_ed.remove_record(start)
	_block = {}
	_refresh_list()
	for child in _detail.get_children():
		_detail.remove_child(child)
		child.queue_free()


func _show_enemy() -> void:
	for child in _detail.get_children():
		_detail.remove_child(child)
		child.queue_free()
	var rec := _ed.records[int(_block["header"])]
	var f: Dictionary = rec["fields"]
	var name_edit := LineEdit.new()
	name_edit.text = String(f["name"])
	name_edit.text_changed.connect(func(t: String) -> void:
		f["name"] = t
		_ed.touch(rec)
		_list.set_item_text(_ed.blocks().find(_block), t))
	var nh := HBoxContainer.new()
	var nl := Label.new()
	nl.text = "名前"
	nl.custom_minimum_size = Vector2(110, 0)
	nh.add_child(nl)
	nh.add_child(name_edit)
	_detail.add_child(nh)
	for item in HEADER_LABELS:
		var key := String(item[0])
		var h := HBoxContainer.new()
		var l := Label.new()
		l.text = String(item[1])
		l.custom_minimum_size = Vector2(110, 0)
		h.add_child(l)
		if key == "type":
			var ob := OptionButton.new()
			for n in TYPE_NAMES:
				ob.add_item(n)
			ob.select(clampi(String(f["type"]).to_int(), 0, 6))
			ob.item_selected.connect(func(idx: int) -> void:
				f["type"] = "%02d" % idx
				_ed.touch(rec))
			h.add_child(ob)
		else:
			var e := LineEdit.new()
			e.text = String(f[key])
			e.custom_minimum_size = Vector2(90, 0)
			e.text_changed.connect(func(t: String) -> void:
				f[key] = t
				_ed.touch(rec))
			h.add_child(e)
			if key == "ix":
				_ix_edit = e
			elif key == "iy":
				_iy_edit = e
		if String(item[2]) != "":
			var hl := Label.new()
			hl.text = String(item[2])
			hl.modulate = Color(0.75, 0.75, 0.75)
			h.add_child(hl)
		_detail.add_child(h)
	var pick_btn := Button.new()
	pick_btn.text = "出現位置をマップで指定"
	pick_btn.pressed.connect(func() -> void:
		_request_pick(func(x: int, y: int) -> void:
			f["ix"] = "%03d" % x
			f["iy"] = "%03d" % y
			if _ix_edit != null:
				_ix_edit.text = f["ix"]
			if _iy_edit != null:
				_iy_edit.text = f["iy"]
			_ed.touch(rec)))
	_detail.add_child(pick_btn)
	var sl := Label.new()
	sl.text = "■ サブレコード"
	_detail.add_child(sl)
	_sub_list = ItemList.new()
	_sub_list.custom_minimum_size = Vector2(0, 160)
	_sub_list.item_selected.connect(_on_sub_selected)
	_detail.add_child(_sub_list)
	var sbtns := HBoxContainer.new()
	for letter in ["T", "M", "I", "O", "R"]:
		var b := Button.new()
		b.text = ":" + letter + " 追加"
		b.pressed.connect(func() -> void: _add_sub(letter))
		sbtns.add_child(b)
	var del_sub := Button.new()
	del_sub.text = "サブ削除"
	del_sub.pressed.connect(_delete_sub)
	sbtns.add_child(del_sub)
	_detail.add_child(sbtns)
	_sub_detail = VBoxContainer.new()
	_detail.add_child(_sub_detail)
	_refresh_subs()


func _request_pick(handler: Callable) -> void:
	var m := get_tree().get_first_node_in_group("creators_main")
	if m != null:
		m.call("request_coord_pick", handler)


func _refresh_subs() -> void:
	_sub_indices.clear()
	_sub_list.clear()
	for i in range(int(_block["header"]) + 1, int(_block["end"])):
		_sub_indices.append(i)
		_sub_list.add_item(_ed.raw_lines.line_text(i).substr(0, 55))


func _on_sub_selected(idx: int) -> void:
	_show_sub(_sub_indices[idx])


func _add_sub(letter: String) -> void:
	var proto := PhiEd._parse_sub(":" + letter + " 99 ")
	var at := int(_block["end"])
	_insert_record(at, proto)
	_block["end"] = at + 1
	_refresh_subs()


func _delete_sub() -> void:
	var sel := _sub_list.get_selected_items()
	if sel.is_empty():
		return
	_ed.remove_record(_sub_indices[sel[0]])
	_block["end"] = int(_block["end"]) - 1
	_refresh_subs()


func _show_sub(rec_idx: int) -> void:
	for child in _sub_detail.get_children():
		_sub_detail.remove_child(child)
		child.queue_free()
	var rec := _ed.records[rec_idx]
	if String(rec["kind"]) == "select":
		var l := Label.new()
		l.text = "<select> グループの行です:\n" + String(rec["fields"]["text"])
		_sub_detail.add_child(l)
		return
	if String(rec["kind"]) != "sub":
		return
	var f: Dictionary = rec["fields"]
	var letter := String(f["letter"])
	var rebuild := func() -> void:
		_ed.touch(rec)
		_sub_list.set_item_text(_sub_indices.find(rec_idx),
				PhiEd.build_line(rec).substr(0, 55))
	match letter:
		"T", "S":
			_sub_spin("確率", String(f.get("prob", "99")), func(t: String) -> void:
				f["prob"] = t
				f["rest"] = " %s %s %s" % [t, String(f["type"]), String(f["text"])]
				rebuild.call())
			var ob := OptionButton.new()
			for n in TALK_NAMES:
				ob.add_item(n)
			ob.select(clampi(String(f.get("type", "0")).to_int(), 0, 6))
			ob.item_selected.connect(func(idx: int) -> void:
				f["type"] = "%02d" % idx
				f["rest"] = " %s %s %s" % [String(f["prob"]), f["type"],
						String(f["text"])]
				rebuild.call())
			_sub_detail.add_child(ob)
			_sub_line("テキスト", String(f.get("text", "")), func(t: String) -> void:
				f["text"] = t
				f["rest"] = " %s %s %s" % [String(f["prob"]), String(f["type"]), t]
				rebuild.call())
		"M", "I":
			_sub_spin("確率", String(f.get("prob", "99")), func(t: String) -> void:
				f["prob"] = t
				f["rest"] = " %s %s" % [t, String(f["data"])]
				rebuild.call())
			_sub_line("データ (名前+パラメータ)", String(f.get("data", "")),
					func(t: String) -> void:
				f["data"] = t
				f["rest"] = " %s %s" % [String(f["prob"]), t]
				rebuild.call())
		"O":
			_sub_line("オプション (H/M の倍率、B=2x2)", String(f.get("options", "")),
					func(t: String) -> void:
				f["options"] = t
				f["rest"] = " " + t
				rebuild.call())
		"R":
			_sub_line("出現条件 (apc apt 追加)", String(f.get("rest", "")).lstrip(" "),
					func(t: String) -> void:
				f["rest"] = " " + t
				rebuild.call())
		_:
			_sub_line("原文", String(f.get("rest", "")), func(t: String) -> void:
				f["rest"] = t
				rebuild.call())


func _sub_spin(label: String, value: String, on_change: Callable) -> void:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	h.add_child(l)
	var e := LineEdit.new()
	e.text = value
	e.custom_minimum_size = Vector2(70, 0)
	e.text_changed.connect(func(t: String) -> void: on_change.call(t))
	h.add_child(e)
	_sub_detail.add_child(h)


func _sub_line(label: String, value: String, on_change: Callable) -> void:
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
	_sub_detail.add_child(h)

extends ScrollContainer
## 世界設定エディタ (phi.td)。FORMAT_SPEC §1。
## 基本・通貨・:O・:U はフォーム+スイッチ+解説、
## ゲート類は一覧+フォーム、:M/:F は一覧+欄、で編集する。
## どの編集も PhiTd のレコードを書き換えるだけで、保存は
## WorldProject.save_all() が正規形で書き戻す。

var _project: WorldProject
var _td: PhiTd
var _box: VBoxContainer
var _u_raw: LineEdit
var _u_controls := {} ## key -> Control (現在の :U を再読する用)


func setup(project: WorldProject) -> void:
	_project = project
	_td = project.td
	_box = VBoxContainer.new()
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_box)
	_build_basic()
	_build_currency()
	_build_o_flags()
	_build_u_options()
	_build_gates()
	_build_lists()


func _section(title: String) -> void:
	var l := Label.new()
	l.text = "■ " + title
	l.add_theme_font_size_override("font_size", 30)
	l.add_theme_color_override("font_color", AppTheme.GOLD)
	_box.add_child(l)


func _row(label: String, control: Control, help: String) -> void:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(265, 0)
	h.add_child(l)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(control)
	if help != "":
		var hl := Label.new()
		hl.text = help
		hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hl.custom_minimum_size = Vector2(305, 0)
		hl.modulate = Color(0.75, 0.75, 0.75)
		h.add_child(hl)
	_box.add_child(h)


func _spin(minv: int, maxv: int, value: int) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = minv
	s.max_value = maxv
	s.value = value
	return s


# ---------------------------------------------------------------- 基本
func _build_basic() -> void:
	_section("基本")
	var nrec := _td.find_record("N")
	var name_edit := LineEdit.new()
	name_edit.text = String(nrec.get("fields", {}).get("name", ""))
	name_edit.text_changed.connect(func(t: String) -> void:
		var r := _ensure("N", {"name": ""})
		r["fields"]["name"] = t
		_td.touch(r))
	_row("世界名", name_edit, "自世界の名前。ゲートの照合にも使われる")
	var trec := _td.find_record("T")
	var tslide := _spin(0, 23, int(trec.get("fields", {}).get("tslide", 0)))
	tslide.value_changed.connect(func(v: float) -> void:
		var r := _ensure("T", {"tslide": 0})
		r["fields"]["tslide"] = int(v)
		_td.touch(r))
	_row("時差 (時間)", tslide, "PHI 世界の時計 = 現地時刻 + 時差")
	var yrec := _td.find_record("t")
	var ybox := HBoxContainer.new()
	var yslide := LineEdit.new()
	yslide.text = str(int(yrec.get("fields", {}).get("yslide", 0)))
	yslide.custom_minimum_size = Vector2(90, 0)
	var yname := LineEdit.new()
	yname.text = String(yrec.get("fields", {}).get("yname", ""))
	yslide.text_changed.connect(func(t: String) -> void:
		var r := _ensure("t", {"yslide": 0, "yname": ""})
		r["fields"]["yslide"] = t.to_int()
		_td.touch(r))
	yname.text_changed.connect(func(t: String) -> void:
		var r := _ensure("t", {"yslide": 0, "yname": ""})
		r["fields"]["yname"] = t
		_td.touch(r))
	ybox.add_child(yslide)
	ybox.add_child(yname)
	_row("暦 (年オフセットと暦号)", ybox, "表示年 = 西暦 + オフセット。例: +3000 星暦")
	var orec := _td.find_record("O")
	var port := _spin(1, 65535, int(orec.get("fields", {}).get("port", 20017)))
	port.value_changed.connect(func(v: float) -> void:
		_set_port(int(v)))
	_row("サーバポート", port, "この世界が待ち受けるポート番号")


func _ensure(kind: String, defaults: Dictionary) -> Dictionary:
	var r := _td.find_record(kind)
	if r.is_empty():
		r = {"kind": kind, "fields": defaults.duplicate(), "modified": true}
		_td.add_record(r)
	return r


func _set_port(port: int) -> void:
	var r := _ensure("O", {"tokens": PackedStringArray(["O", "20017"]),
			"port": 20017})
	var tokens: PackedStringArray = r["fields"]["tokens"]
	for i in tokens.size():
		if tokens[i] == "O" and i + 1 < tokens.size():
			tokens[i + 1] = str(port)
			r["fields"]["tokens"] = tokens
			r["fields"]["port"] = port
			_td.touch(r)
			return
	tokens.append("O")
	tokens.append(str(port))
	r["fields"]["tokens"] = tokens
	r["fields"]["port"] = port
	_td.touch(r)


# ---------------------------------------------------------------- 通貨
func _build_currency() -> void:
	_section("通貨")
	var rrec := _td.find_record("R")
	var f: Dictionary = rrec.get("fields", {})
	var xbox := CheckBox.new()
	xbox.text = "現金を持って世界間を移動できない (宝石に換算)"
	xbox.button_pressed = bool(f.get("x", false))
	xbox.toggled.connect(func(on: bool) -> void:
		var r := _ensure("R", {"x": false, "rate": 100, "unit": "gp"})
		r["fields"]["x"] = on
		_td.touch(r))
	_row("現金の持出", xbox, "")
	var rate := _spin(0, 9999, int(f.get("rate", 100)))
	rate.value_changed.connect(func(v: float) -> void:
		var r := _ensure("R", {"x": false, "rate": 100, "unit": "gp"})
		r["fields"]["rate"] = int(v)
		_td.touch(r))
	_row("レート (1GP = 値/100 単位)", rate, "0100 で 1.00。0 は 100 として扱われる")
	var unit := LineEdit.new()
	unit.text = String(f.get("unit", "gp"))
	unit.text_changed.connect(func(t: String) -> void:
		var r := _ensure("R", {"x": false, "rate": 100, "unit": "gp"})
		r["fields"]["unit"] = t
		_td.touch(r))
	_row("単位名", unit, "")


# ---------------------------------------------------------------- :O
func _o_tokens() -> PackedStringArray:
	var r := _td.find_record("O")
	if r.is_empty():
		return PackedStringArray()
	return r["fields"]["tokens"]


func _set_o_tokens(tokens: PackedStringArray) -> void:
	var r := _ensure("O", {"tokens": PackedStringArray(), "port": 20017})
	r["fields"]["tokens"] = tokens
	_td.touch(r)


func _build_o_flags() -> void:
	_section("サーバ動作 (:O)")
	var tokens := _o_tokens()
	# A: 自動登録 (A xxx yyy idnt の4トークン)
	var a_idx := tokens.find("A")
	var abox := HBoxContainer.new()
	var acheck := CheckBox.new()
	acheck.text = "新規ユーザ自動登録"
	acheck.button_pressed = a_idx >= 0
	var ax := _spin(0, 999, 0)
	var ay := _spin(0, 999, 0)
	ax.custom_minimum_size.x = 110
	ay.custom_minimum_size.x = 110
	var aid := LineEdit.new()
	aid.custom_minimum_size.x = 100
	aid.placeholder_text = "ID接頭辞"
	if a_idx >= 0 and a_idx + 3 < tokens.size():
		ax.value = tokens[a_idx + 1].to_int()
		ay.value = tokens[a_idx + 2].to_int()
		aid.text = tokens[a_idx + 3]
	var apply_a := func() -> void:
		var t := _o_tokens()
		var i := t.find("A")
		if i >= 0:
			for k in 4:
				t.remove_at(i)
		if acheck.button_pressed:
			t.append("A")
			t.append("%03d" % int(ax.value))
			t.append("%03d" % int(ay.value))
			t.append(aid.text)
		_set_o_tokens(t)
	acheck.toggled.connect(func(_on: bool) -> void: apply_a.call())
	ax.value_changed.connect(func(_v: float) -> void: apply_a.call())
	ay.value_changed.connect(func(_v: float) -> void: apply_a.call())
	aid.text_changed.connect(func(_t: String) -> void: apply_a.call())
	abox.add_child(acheck)
	abox.add_child(ax)
	abox.add_child(ay)
	abox.add_child(aid)
	_row("自動登録", abox, "出現位置と生成 ID の接頭辞 (ID = 接頭辞+5桁+パスワード)")
	_o_flag_row("G", "巨大化の境界を厳密に", "MHP 5000 以上でも巨大化しなくなる")
	_o_flag_row("N", "税金は現地通貨基準", "税金を GP でなく現地通貨で計算する")
	_o_flag_row("T", "互換オプション", "壁への衝突で条件01スイッチが起動する等。ドキュメントは「使用すべきでない」としている")


func _o_flag_row(code: String, label: String, help: String) -> void:
	var cb := CheckBox.new()
	cb.text = label
	cb.button_pressed = _o_tokens().has(code)
	cb.toggled.connect(func(on: bool) -> void:
		var t := _o_tokens()
		if on and not t.has(code):
			t.append(code)
		elif not on:
			while t.has(code):
				t.remove_at(t.find(code))
		_set_o_tokens(t))
	_row(":O " + code, cb, help)


# ---------------------------------------------------------------- :U
var _u_help_label: Label


func _u_codes() -> String:
	var r := _td.find_record("U")
	if r.is_empty():
		return ""
	return String(r["fields"]["codes"])


func _set_u_codes(codes: String) -> void:
	var r := _ensure("U", {"codes": ""})
	r["fields"]["codes"] = codes
	_td.touch(r)
	if _u_raw != null:
		_u_raw.text = codes


func _build_u_options() -> void:
	_section("雑多オプション (:U)")
	# フラグ類は横に並べる (第5段: 縦長にしない)。解説は下の1行に出す
	var grid := GridContainer.new()
	grid.columns = 3
	_box.add_child(grid)
	_u_help_label = Label.new()
	_u_help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_u_help_label.modulate = Color(0.75, 0.75, 0.75)
	for def in HelpTexts.U_DEFS:
		var key := String(def["key"])
		var cb := CheckBox.new()
		cb.add_theme_font_size_override("font_size", 23)
		cb.text = String(def["label"])
		cb.tooltip_text = String(def["help"])
		cb.button_pressed = _u_flag_state(def)
		cb.toggled.connect(func(on: bool) -> void:
			var tokens := UOptions.tokenize(_u_codes())
			tokens = UOptions.set_flag(tokens, String(def["on"]),
					String(def.get("off", "")), on)
			_set_u_codes(UOptions.join(tokens)))
		var help_text := String(def["help"])
		cb.mouse_entered.connect(func() -> void:
			_u_help_label.text = "%s — %s" % [String(def["label"]), help_text])
		_u_controls[key] = cb
		grid.add_child(cb)
	_box.add_child(_u_help_label)
	for def in HelpTexts.U_INT_DEFS:
		var prefix := String(def["prefix"])
		var cur := UOptions.get_int(UOptions.tokenize(_u_codes()), prefix)
		var sp := _spin(int(def["min"]), int(def["max"]),
				cur if cur >= 0 else int(def["default"]))
		sp.value_changed.connect(func(v: float) -> void:
			var tokens := UOptions.tokenize(_u_codes())
			tokens = UOptions.set_int(tokens, prefix, int(v),
					int(def["default"]))
			_set_u_codes(UOptions.join(tokens)))
		_u_controls[String(def["key"])] = sp
		_row(String(def["label"]), sp, String(def["help"]))
	for def in HelpTexts.U_CHOICE_DEFS:
		var ob := OptionButton.new()
		var options: Dictionary = def["options"]
		var keys := options.keys()
		keys.sort()
		for k in keys:
			ob.add_item(String(k) if String(k) != "" else "(なし)")
		var cur := UOptions.get_choice(UOptions.tokenize(_u_codes()),
				options, String(def["default"]))
		ob.select(keys.find(cur))
		ob.item_selected.connect(func(idx: int) -> void:
			var tokens := UOptions.tokenize(_u_codes())
			tokens = UOptions.set_choice(tokens, options,
					String(options[keys[idx]]))
			_set_u_codes(UOptions.join(tokens)))
		_u_controls[String(def["key"])] = ob
		_row(String(def["label"]), ob, String(def["help"]))
	# R "…" 屋根を隠す地形文字
	var roof := LineEdit.new()
	roof.text = _u_roof_string()
	roof.text_changed.connect(func(t: String) -> void:
		var tokens := UOptions.tokenize(_u_codes())
		var out: Array = []
		var i := 0
		while i < tokens.size():
			if String(tokens[i]) == "R":
				i += 2
				continue
			out.append(tokens[i])
			i += 1
		if t != "":
			out.append("R")
			out.append('"' + t + '"')
		_set_u_codes(UOptions.join(out)))
	_row("Eagle Eye で屋根を隠す地形", roof,
			"屋根として隠す地形文字の並び (例: > .!*o:+_/x[I|=HZ#$@T?)")
	_u_raw = LineEdit.new()
	_u_raw.text = _u_codes()
	_row(":U 行 (手書き)", _u_raw, "直接編集もできる。右のボタンで下のスイッチ類に反映")
	var apply_btn := Button.new()
	apply_btn.text = "手書きを反映"
	apply_btn.pressed.connect(func() -> void:
		_set_u_codes(_u_raw.text)
		_refresh_u_controls())
	_box.add_child(apply_btn)


func _u_flag_state(def: Dictionary) -> bool:
	var tokens := UOptions.tokenize(_u_codes())
	if tokens.has(String(def["on"])):
		return true
	if String(def["kind"]) == "pair" and tokens.has(String(def.get("off", ""))):
		return false
	return String(def["default"]) == "on"


func _u_roof_string() -> String:
	var tokens := UOptions.tokenize(_u_codes())
	var i := tokens.find("R")
	if i >= 0 and i + 1 < tokens.size():
		var q := String(tokens[i + 1])
		if q.length() >= 2 and q.begins_with('"'):
			return q.substr(1, q.length() - 2)
	return ""


func _refresh_u_controls() -> void:
	for def in HelpTexts.U_DEFS:
		var cb: CheckBox = _u_controls[String(def["key"])]
		cb.set_pressed_no_signal(_u_flag_state(def))
	for def in HelpTexts.U_INT_DEFS:
		var sp: SpinBox = _u_controls[String(def["key"])]
		var cur := UOptions.get_int(UOptions.tokenize(_u_codes()),
				String(def["prefix"]))
		sp.set_value_no_signal(cur if cur >= 0 else int(def["default"]))
	for def in HelpTexts.U_CHOICE_DEFS:
		var ob: OptionButton = _u_controls[String(def["key"])]
		var options: Dictionary = def["options"]
		var keys := options.keys()
		keys.sort()
		ob.select(keys.find(UOptions.get_choice(
				UOptions.tokenize(_u_codes()), options,
				String(def["default"]))))


# ---------------------------------------------------------------- ゲート
var _gate_list: ItemList
var _gate_fields := {}
var _gate_indices: Array[int] = []

func _build_gates() -> void:
	_section("ゲート (:G / :g / :H)")
	_gate_list = ItemList.new()
	_gate_list.custom_minimum_size = Vector2(0, 150)
	_box.add_child(_gate_list)
	var names := ["種別 (G=可視 / g=隠し / H=着信規則)", "自 X", "自 Y",
			"先 X / 着信X", "先 Y / 着信Y", "ラベル / 世界名", "行き先 / IP 等"]
	# 汎用の7欄フォームで G/g/H を共用する
	var edits: Array[LineEdit] = []
	for n in names:
		var le := LineEdit.new()
		edits.append(le)
		_row(n, le, "")
	_gate_fields["edits"] = edits
	var btns := HBoxContainer.new()
	var add_btn := Button.new()
	add_btn.text = "ゲート追加 (:G)"
	add_btn.pressed.connect(func() -> void:
		_td.add_record({"kind": "G", "fields": {"x": 1, "y": 1, "dx": 1,
				"dy": 1, "label": "", "dest": "-"}, "modified": true})
		_refresh_gates())
	var del_btn := Button.new()
	del_btn.text = "選択を削除"
	del_btn.pressed.connect(func() -> void:
		var sel := _gate_list.get_selected_items()
		if sel.size() > 0:
			_td.remove_record(_gate_indices[sel[0]])
			_refresh_gates())
	btns.add_child(add_btn)
	btns.add_child(del_btn)
	_box.add_child(btns)
	_gate_list.item_selected.connect(_on_gate_selected)
	for i in edits.size():
		edits[i].text_changed.connect(func(_t: String) -> void:
			_apply_gate_form(edits))
	_refresh_gates()


func _refresh_gates() -> void:
	_gate_indices.clear()
	_gate_list.clear()
	for kind in ["G", "g", "H"]:
		for i in _td.record_indices(kind):
			_gate_indices.append(i)
			var rec := _td.records[i]
			_gate_list.add_item(PhiTd.build_line(rec).substr(0, 60))


func _on_gate_selected(idx: int) -> void:
	var rec := _td.records[_gate_indices[idx]]
	var f: Dictionary = rec["fields"]
	var edits: Array = _gate_fields["edits"]
	edits[0].text = String(rec["kind"])
	if String(rec["kind"]) in ["G", "g"]:
		edits[1].text = str(int(f["x"]))
		edits[2].text = str(int(f["y"]))
		edits[3].text = str(int(f["dx"]))
		edits[4].text = str(int(f["dy"]))
		edits[5].text = String(f["label"])
		edits[6].text = String(f["dest"])
	else:
		edits[1].text = String(f["x"])
		edits[2].text = String(f["y"])
		edits[3].text = String(f["flag"])
		edits[4].text = ""
		edits[5].text = String(f["name"])
		var tail := String(f["ip"])
		if String(f["rest"]) != "":
			tail += " " + String(f["rest"])
		edits[6].text = tail


func _apply_gate_form(edits: Array) -> void:
	var sel := _gate_list.get_selected_items()
	if sel.is_empty():
		return
	var rec := _td.records[_gate_indices[sel[0]]]
	var f: Dictionary = rec["fields"]
	if String(rec["kind"]) in ["G", "g"]:
		f["x"] = edits[1].text.to_int()
		f["y"] = edits[2].text.to_int()
		f["dx"] = edits[3].text.to_int()
		f["dy"] = edits[4].text.to_int()
		f["label"] = edits[5].text
		f["dest"] = edits[6].text
	else:
		f["x"] = edits[1].text
		f["y"] = edits[2].text
		f["flag"] = edits[3].text
		f["name"] = edits[5].text
		var tail := String(edits[6].text)
		var sp := tail.find(" ")
		if sp >= 0:
			f["ip"] = tail.substr(0, sp)
			f["rest"] = tail.substr(sp + 1)
		else:
			f["ip"] = tail
			f["rest"] = ""
	_td.touch(rec)
	_gate_list.set_item_text(sel[0], PhiTd.build_line(rec).substr(0, 60))


# ---------------------------------------------------------------- :P :B :b :M :F
func _build_lists() -> void:
	_section("パスワード・禁止・その他")
	_simple_list("P", "ゲートパスワード (:P)",
			"着信ゲートの認証パスワード。番号つきは :P1 の形")
	_simple_list("B", "接続禁止 IP (:B)", "ワイルドカード可。上限16件")
	_simple_list("b", "接続禁止 ID (:b)", "上限16件 (超えると古い順に押し出される)")
	_simple_list("F", "初期キャラグラフィック (:F)", "最大32件。順序に意味がある")
	_simple_list("M", "パワースペル (:M)", "倍率 + 魔法パターン。最大16件")


func _simple_list(kind: String, title: String, help: String) -> void:
	var l := Label.new()
	l.text = title + " — " + help
	_box.add_child(l)
	var list := ItemList.new()
	list.custom_minimum_size = Vector2(0, 80)
	_box.add_child(list)
	var edit := LineEdit.new()
	_box.add_child(edit)
	var refresh := func() -> void:
		list.clear()
		for i in _td.record_indices(kind):
			list.add_item(PhiTd.build_line(_td.records[i]))
	refresh.call()
	list.item_selected.connect(func(idx: int) -> void:
		var rec_idx := _td.record_indices(kind)[idx]
		edit.text = PhiTd.build_line(_td.records[rec_idx])
		edit.set_meta("rec_idx", rec_idx))
	edit.text_changed.connect(func(t: String) -> void:
		if not edit.has_meta("rec_idx"):
			return
		var rec_idx := int(edit.get_meta("rec_idx"))
		var parsed := PhiTd._parse_line(t)
		if String(parsed["kind"]) == kind:
			_td.records[rec_idx]["fields"] = parsed["fields"]
			_td.touch(_td.records[rec_idx])
			list.set_item_text(list.get_selected_items()[0], t))
	var btns := HBoxContainer.new()
	var add_btn := Button.new()
	add_btn.text = "追加"
	add_btn.pressed.connect(func() -> void:
		var proto := PhiTd._parse_line(":" + kind + " ")
		_td.add_record(proto)
		refresh.call())
	var del_btn := Button.new()
	del_btn.text = "削除"
	del_btn.pressed.connect(func() -> void:
		var sel := list.get_selected_items()
		if sel.size() > 0:
			_td.remove_record(_td.record_indices(kind)[sel[0]])
			refresh.call())
	btns.add_child(add_btn)
	btns.add_child(del_btn)
	_box.add_child(btns)

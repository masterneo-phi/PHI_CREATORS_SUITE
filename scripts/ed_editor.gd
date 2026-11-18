extends HSplitContainer
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
var _gra := GraLibrary.new()
var _gra_left_note: Label
var _gra_dialog: FileDialog
var _sheet_rect: TextureRect
var _frame_rect: TextureRect
var _frame_label: Label
var _gra_note: Label
var _preview_dir := 2

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
	left.custom_minimum_size = Vector2(280, 0)
	add_child(left)
	if _ed == null:
		var l := Label.new()
		l.text = "phi.ed は無い world です"
		left.add_child(l)
		var cb := Button.new()
		cb.text = "phi.ed を新規作成"
		cb.pressed.connect(func() -> void:
			if project.create_file("ed"):
				for child in get_children():
					remove_child(child)
					child.queue_free()
				setup(project))
		left.add_child(cb)
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
	var gra_btn := Button.new()
	gra_btn.text = "キャラグラフォルダを選ぶ"
	gra_btn.pressed.connect(_on_gra_dir_pressed)
	left.add_child(gra_btn)
	_gra_left_note = Label.new()
	_gra_left_note.add_theme_font_size_override("font_size", AppTheme.rel(_gra_left_note, 20))
	left.add_child(_gra_left_note)
	_gra.setup_from_cfg()
	_update_gra_left_note()
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_selected.connect(_on_enemy_selected)
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
	_build_enemy_gra(rec)
	var sl := Label.new()
	sl.text = "■ サブレコード"
	sl.add_theme_color_override("font_color", AppTheme.GOLD)
	_detail.add_child(sl)
	_sub_list = ItemList.new()
	_sub_list.custom_minimum_size = Vector2(0, 160)
	_sub_list.item_selected.connect(_on_sub_selected)
	_detail.add_child(_sub_list)
	var sbtns := GridContainer.new()
	sbtns.columns = 6
	for letter in ["T", "M", "I", "O", "R", "G", "A", "C", "D", "F", "Z", "S"]:
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
		var rec: Dictionary = _ed.records[i]
		var txt := _ed.raw_lines.line_text(i)
		if txt.strip_edges() == "" or bool(rec.get("modified", false)):
			txt = PhiEd.build_line(rec)
		_sub_list.add_item(txt.substr(0, 55))


func _on_sub_selected(idx: int) -> void:
	_show_sub(_sub_indices[idx])


const SUB_PROTOS := {
	"T": ":T 99 01 テキスト",
	"M": ":M 99 Cure                           09 s",
	"I": ":I 99 New item                       0001 00 n 00 00 00 00",
	"O": ":O H00002",
	"R": ":R 01 00120 99",
	"G": ":G NewGra",
	"A": ":A 0000",
	"C": ":C 50",
	"D": ":D *",
	"F": ":F A 05 00",
	"Z": ":Z 99",
	"S": ":S 99 00 ",
}


func _add_sub(letter: String) -> void:
	var proto := PhiEd._parse_sub(String(SUB_PROTOS.get(letter,
			":" + letter + " 99 ")))
	proto["modified"] = true
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
		_sub_title("<select> グループ")
		_sub_help("グループ内から最大1件だけが付与される (先頭から順に抽選し、成功したら残りを飛ばす)")
		var l := Label.new()
		l.text = String(rec["fields"]["text"])
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
		"T":
			_sub_title(":T トーク (セリフ)")
			_sub_help("出現時に確率で付与されるセリフ (最大16件)。同種別が複数ある場合は最初の1つが使われる。種別06 のテキストは 「キーワード:応答」 の形で、相手の文にキーワードと ? が含まれると応答する")
			_prob_edit(f, rebuild)
			var ob := OptionButton.new()
			for n in TALK_NAMES:
				ob.add_item(n)
			ob.select(clampi(String(f.get("type", "0")).to_int(), 0, 6))
			ob.item_selected.connect(func(idx: int) -> void:
				f["type"] = "%02d" % idx
				_sync_rest(f)
				rebuild.call())
			_sub_detail.add_child(ob)
			_sub_edit("テキスト", String(f.get("text", "")), 0,
					func(t: String) -> void:
				f["text"] = t
				_sync_rest(f)
				rebuild.call())
		"S":
			_sub_title(":S アプリデータ")
			_sub_help("⚠ 仕様調査の結果: ローダは格納しますが出現時に NPC へコピーされないため、このサーバでは効果を持たない痕跡的レコードです")
			_prob_edit(f, rebuild)
			_sub_edit("種別 (2桁)", String(f.get("type", "00")), 70,
					func(t: String) -> void:
				f["type"] = t
				_sync_rest(f)
				rebuild.call())
			_sub_edit("テキスト", String(f.get("text", "")), 0,
					func(t: String) -> void:
				f["text"] = t
				_sync_rest(f)
				rebuild.call())
		"M":
			_sub_title(":M 魔法")
			_sub_help("出現時に確率で習得する魔法 (最大8つ)")
			_prob_edit(f, rebuild)
			_spell_editor(f, rebuild)
		"I":
			_sub_title(":I アイテム")
			_sub_help("出現時に確率で所持するアイテム (最大8つ)")
			_prob_edit(f, rebuild)
			_item_editor(f, rec_idx, rebuild)
		"O":
			_sub_title(":O オプション")
			_sub_help("出現時の補正。H/M は 5桁の倍率そのもの (H00002 = HP 2倍)。B は C++ 移植版で追加された 2x2 巨大ボス指定")
			var d := parse_options(String(f.get("options", "")))
			var apply_o := func() -> void:
				f["options"] = build_options(d)
				_sync_rest(f)
				rebuild.call()
			_opt_mult("HP 倍率 H", "h", d, apply_o)
			_opt_mult("MP 倍率 M", "m", d, apply_o)
			var bc := CheckBox.new()
			bc.text = "2x2 巨大ボス (B)"
			bc.button_pressed = bool(d["b"])
			bc.toggled.connect(func(on: bool) -> void:
				d["b"] = on
				apply_o.call())
			_sub_detail.add_child(bc)
			if String(d["unknown"]) != "":
				_sub_help("未対応の文字 「%s」 はそのまま保持されます"
						% String(d["unknown"]))
		"R":
			_sub_title(":R 出現条件")
			_sub_help("省略した場合は :R 01 00120 99 (定常・120秒間隔・絶滅で再出現)")
			_r_editor(f, rec_idx, rebuild)
		"G":
			_sub_title(":G グラフィック")
			_sub_help("表示グラフィック名 (最大15バイト)。プレビューとプルダウン選択は上のグラフィック欄にあります")
			_sub_edit("グラフィック名", String(f.get("graphic", "")), 0,
					func(t: String) -> void:
				f["graphic"] = t
				_sync_rest(f)
				rebuild.call()
				_update_enemy_preview())
		"A":
			_sub_title(":A 先天属性")
			_sub_help("悪魔・ドラゴン・神・精霊は通常武器/魔法ダメージ半減、守護種族は半減、サーガ種族は通常ダメージ無効。狼人間は銀/ミスリル/魔法/サーガ武器でのみ傷つく")
			_a_editor(f, rebuild)
		"C":
			_sub_title(":C クールダウン")
			_sub_edit("値 (2桁)", String(f.get("prob", "50")), 70,
					func(t: String) -> void:
				f["prob"] = t
				_sync_rest(f)
				rebuild.call())
			_sub_help("怒った NPC が 10 秒ごとに落ち着く確率 (%)。デフォルト 50")
		"D":
			_sub_title(":D Identify 隠蔽")
			_sub_help("Identify したときに隠れる情報。大文字小文字は区別される")
			_d_editor(f, rebuild)
		"F":
			_sub_title(":F 個体数フラグ")
			_sub_help("生存数に応じてフラグを ON にする。フラグ番号は flagno 表記 (素の16進数や s0 など)")
			_f_editor(f, rebuild)
		"Z":
			_sub_title(":Z ダミー")
			_prob_edit(f, rebuild)
			_sub_help("何も付与しないプレースホルダ。<select> グループ内で確率の配分を調整するために使う")
		_:
			_sub_help("未対応のレコードは原文のまま編集します")
			_sub_line("原文", String(f.get("rest", "")), func(t: String) -> void:
				f["rest"] = t
				rebuild.call())


func _sync_rest(f: Dictionary) -> void:
	var letter := String(f["letter"])
	match letter:
		"T", "S":
			f["rest"] = " %s %s %s" % [String(f["prob"]),
					String(f["type"]), String(f["text"])]
		"M", "I":
			f["rest"] = " %s %s" % [String(f["prob"]), String(f["data"])]
		"C", "Z":
			f["rest"] = " " + String(f["prob"])
		"G":
			f["rest"] = " " + String(f["graphic"])
		"A":
			f["rest"] = " " + String(f["hex"])
		"O":
			f["rest"] = " " + String(f["options"])
		"R":
			var tail := String(f.get("tail", ""))
			f["rest"] = " %s %s%s" % [String(f["apc"]), String(f["apt"]),
					(" " + tail) if tail != "" else ""]


func _sub_title(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", AppTheme.GOLD)
	_sub_detail.add_child(l)


func _sub_help(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.modulate = Color(0.75, 0.75, 0.75)
	l.add_theme_font_size_override("font_size", AppTheme.rel(l, 20))
	_sub_detail.add_child(l)


func _sub_edit(label: String, value: String, width: int,
		on_change: Callable) -> LineEdit:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(150, 0)
	h.add_child(l)
	var e := LineEdit.new()
	e.text = value
	if width > 0:
		e.custom_minimum_size = Vector2(width, 0)
	else:
		e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	e.text_changed.connect(func(t: String) -> void: on_change.call(t))
	h.add_child(e)
	_sub_detail.add_child(h)
	return e


func _prob_edit(f: Dictionary, rebuild: Callable) -> void:
	_sub_edit("所持確率 (2桁)", String(f.get("prob", "99")), 70,
			func(t: String) -> void:
		f["prob"] = t
		_sync_rest(f)
		rebuild.call())
	_sub_help("出現時に抽選される。実際は表示+1% (99 = 必ず付与)")


# ------------------------------------------------------------ :M 魔法

static func parse_spell_data(data: String) -> Dictionary:
	return ItemForm.parse_spell_data(data)


static func build_spell_data(d: Dictionary) -> String:
	return ItemForm.build_spell_data(d)


func _spell_editor(f: Dictionary, rebuild: Callable) -> void:
	var ok := ItemForm.build_spell_form(_sub_detail, String(f["data"]),
			func(new_data: String) -> void:
		f["data"] = new_data
		_sync_rest(f)
		rebuild.call())
	if not ok:
		_sub_help("分解できない形式のため、データ文字列をそのまま編集します")
		_sub_edit("SPELL DATA", String(f["data"]), 0,
				func(t: String) -> void:
			f["data"] = t
			_sync_rest(f)
			rebuild.call())


# ------------------------------------------------------------ :I アイテム

static func parse_item_data(data: String) -> Dictionary:
	return ItemForm.parse_item_data(data)


static func build_item_data(d: Dictionary) -> String:
	return ItemForm.build_item_data(d)


func _item_editor(f: Dictionary, rec_idx: int, rebuild: Callable) -> void:
	var ok := ItemForm.build_item_form(_sub_detail, String(f["data"]),
			func(new_data: String) -> void:
		f["data"] = new_data
		_sync_rest(f)
		rebuild.call())
	if not ok:
		_sub_help("分解できない形式のため、データ文字列をそのまま編集します")
		_sub_edit("ITEM DATA", String(f["data"]), 0,
				func(t: String) -> void:
			f["data"] = t
			_sync_rest(f)
			rebuild.call())


# ------------------------------------------------------------ :O オプション

static func parse_options(s: String) -> Dictionary:
	var d := {"h": -1, "m": -1, "b": false, "unknown": ""}
	var i := 0
	while i < s.length():
		var c := s[i]
		if c == "H" or c == "M":
			var j := i + 1
			while j < s.length() and s[j] == " ":
				j += 1
			var digits := ""
			while j < s.length() and s[j] >= "0" and s[j] <= "9" \
					and digits.length() < 5:
				digits += s[j]
				j += 1
			if digits != "":
				if c == "H":
					d["h"] = digits.to_int()
				else:
					d["m"] = digits.to_int()
			i = j
		elif c == "B":
			d["b"] = true
			i += 1
		elif c == " ":
			i += 1
		else:
			d["unknown"] = String(d["unknown"]) + c
			i += 1
	return d


static func build_options(d: Dictionary) -> String:
	var parts: Array[String] = []
	if int(d["h"]) >= 0:
		parts.append("H%05d" % int(d["h"]))
	if int(d["m"]) >= 0:
		parts.append("M%05d" % int(d["m"]))
	if bool(d["b"]):
		parts.append("B")
	var out := " ".join(parts)
	if String(d["unknown"]) != "":
		out = (out + " " + String(d["unknown"])).strip_edges()
	return out


func _opt_mult(label: String, key: String, d: Dictionary,
		apply: Callable) -> void:
	var h := HBoxContainer.new()
	var cb := CheckBox.new()
	cb.text = label
	cb.button_pressed = int(d[key]) >= 0
	cb.custom_minimum_size = Vector2(150, 0)
	h.add_child(cb)
	var e := LineEdit.new()
	e.text = "%05d" % int(d[key]) if int(d[key]) >= 0 else "00002"
	e.custom_minimum_size = Vector2(90, 0)
	h.add_child(e)
	cb.toggled.connect(func(on: bool) -> void:
		d[key] = e.text.to_int() if on else -1
		apply.call())
	e.text_changed.connect(func(t: String) -> void:
		if cb.button_pressed:
			d[key] = t.to_int()
			apply.call())
	_sub_detail.add_child(h)


# ------------------------------------------------------------ :R 出現条件

const APC_NAMES: Array[String] = [
	"00 定常", "01 定常", "02 初期出現なし (スイッチで出現)",
	"03 召喚", "04 絶滅危惧種", "05+ 未定義 (出現しない)",
]


static func quote_tokens(s: String) -> Array:
	var out: Array = []
	var i := 0
	while i < s.length():
		while i < s.length() and s[i] == " ":
			i += 1
		if i >= s.length():
			break
		if s[i] == "\"":
			var j := s.find("\"", i + 1)
			if j < 0:
				j = s.length() - 1
			out.append(s.substr(i, j - i + 1))
			i = j + 1
		else:
			var j := s.find(" ", i)
			if j < 0:
				j = s.length()
			out.append(s.substr(i, j - i))
			i = j
	return out


func _r_editor(f: Dictionary, rec_idx: int, rebuild: Callable) -> void:
	var apc := clampi(String(f.get("apc", "01")).to_int(), 0, 5)
	var ob := OptionButton.new()
	for n in APC_NAMES:
		ob.add_item(n)
	ob.select(apc)
	ob.item_selected.connect(func(idx: int) -> void:
		f["apc"] = "%02d" % idx
		match idx:
			0, 1:
				f["tail"] = "99"
			2:
				f["tail"] = ""
			3:
				f["tail"] = "00 0000"
			4:
				f["tail"] = "00000"
			_:
				f["tail"] = ""
		_sync_rest(f)
		rebuild.call()
		_show_sub(rec_idx))
	_sub_detail.add_child(ob)
	_sub_edit("再出現間隔 apt (5桁・秒)", String(f.get("apt", "00120")), 90,
			func(t: String) -> void:
		f["apt"] = t
		_sync_rest(f)
		rebuild.call())
	_sub_help("出現時に 60〜140% で変動する")
	var tail := String(f.get("tail", ""))
	match apc:
		0, 1:
			_sub_edit("再出現する生存数 anm", tail, 70,
					func(t: String) -> void:
				f["tail"] = t
				_sync_rest(f)
				rebuild.call())
			_sub_help("生存数がこれ以下になったら再出現する (定常モードのみ)")
		3:
			_r_summon(f, tail, rebuild)
		4:
			_sub_edit("必要最小生存秒数 (5桁)", tail, 90,
					func(t: String) -> void:
				f["tail"] = t
				_sync_rest(f)
				rebuild.call())
			_sub_help("早く倒されると再出現時間が比例して伸びる")
		_:
			if tail != "":
				_sub_edit("追加データ", tail, 0, func(t: String) -> void:
					f["tail"] = t
					_sync_rest(f)
					rebuild.call())


func _r_summon(f: Dictionary, tail: String, rebuild: Callable) -> void:
	var toks := quote_tokens(tail)
	var st := {"apcode": "00", "aplvl": "0000", "item1": "", "item2": ""}
	if toks.size() > 0:
		st["apcode"] = String(toks[0])
	if toks.size() > 1:
		st["aplvl"] = String(toks[1])
	if toks.size() > 2:
		st["item1"] = String(toks[2]).trim_prefix("\"").trim_suffix("\"")
	if toks.size() > 3:
		st["item2"] = String(toks[3]).trim_prefix("\"").trim_suffix("\"")
	var apply := func() -> void:
		var parts: Array[String] = [String(st["apcode"]),
				String(st["aplvl"])]
		if String(st["item1"]) != "":
			parts.append("\"%s\"" % String(st["item1"]))
		if String(st["item2"]) != "":
			parts.append("\"%s\"" % String(st["item2"]))
		f["tail"] = " ".join(parts)
		_sync_rest(f)
		rebuild.call()
	var ob := OptionButton.new()
	ob.add_item("00 アイテム不要")
	ob.add_item("99 召喚アイテム必須")
	ob.add_item("その他 (コードは無検証で格納)")
	ob.select(0 if String(st["apcode"]) == "00" else
			(1 if String(st["apcode"]) == "99" else 2))
	ob.item_selected.connect(func(i: int) -> void:
		if i == 0:
			st["apcode"] = "00"
		elif i == 1:
			st["apcode"] = "99"
		apply.call())
	_sub_detail.add_child(ob)
	_sub_help("99 のとき Item1 は特殊効果99のアイテムか効果99 (Appear) のチャージ、Item2 は効果98 (Disappear) のチャージ (省略可)")
	_sub_edit("召喚レベル aplvl (4桁)", String(st["aplvl"]), 80,
			func(t: String) -> void:
		st["aplvl"] = t
		apply.call())
	_sub_edit("Item1", String(st["item1"]), 0, func(t: String) -> void:
		st["item1"] = t
		apply.call())
	_sub_edit("Item2", String(st["item2"]), 0, func(t: String) -> void:
		st["item2"] = t
		apply.call())


# ------------------------------------------------------------ :A / :D / :F

const A_BITS: Array = [
	[0x0001, "石頭"], [0x0002, "傘"], [0x0004, "飛行"], [0x0008, "狼人間"],
	[0x0010, "ドラゴン"], [0x0020, "神"], [0x0040, "精霊"], [0x0080, "悪魔"],
	[0x0100, "守護種族1"], [0x0200, "守護種族2"], [0x0400, "守護種族3"],
	[0x0800, "守護種族4"], [0x1000, "サーガ種族1"], [0x2000, "サーガ種族2"],
	[0x4000, "サーガ種族3"], [0x8000, "サーガ種族4"],
]


func _a_editor(f: Dictionary, rebuild: Callable) -> void:
	var grid := GridContainer.new()
	grid.columns = 4
	var state := {"value": String(f.get("hex", "0000")).hex_to_int()}
	for def in A_BITS:
		var bit := int(def[0])
		var cb := CheckBox.new()
		cb.text = String(def[1])
		cb.add_theme_font_size_override("font_size", AppTheme.rel(cb, 23))
		cb.button_pressed = (int(state["value"]) & bit) != 0
		cb.toggled.connect(func(on: bool) -> void:
			var v := int(state["value"])
			v = (v | bit) if on else (v & ~bit)
			state["value"] = v
			f["hex"] = "%04X" % v
			_sync_rest(f)
			rebuild.call())
		grid.add_child(cb)
	_sub_detail.add_child(grid)


const D_DEFS: Array = [
	["k", "カルマ"], ["a", "攻撃属性"], ["d", "防御属性"], ["H", "HP/MaxHP"],
	["M", "MP/MaxMP"], ["n", "n = k,a,d,S,s の合併"], ["S", "現在の状態"],
	["s", "速度"], ["D", "DFP/MRP"], ["A", "ATP"], ["L", "戦士/商人レベル"],
	["*", "* 全部 (Stealth)"],
]


func _d_editor(f: Dictionary, rebuild: Callable) -> void:
	var cur := String(f.get("rest", "")).replace(" ", "")
	var grid := GridContainer.new()
	grid.columns = 3
	for def in D_DEFS:
		var ch := String(def[0])
		var cb := CheckBox.new()
		cb.text = "%s %s" % [ch, String(def[1])]
		cb.add_theme_font_size_override("font_size", AppTheme.rel(cb, 23))
		cb.button_pressed = cur.contains(ch)
		cb.toggled.connect(func(on: bool) -> void:
			var set := {}
			for d2 in D_DEFS:
				set[String(d2[0])] = false
			for c2 in String(f.get("rest", "")).replace(" ", ""):
				set[c2] = true
			set[ch] = on
			if bool(set["*"]):
				f["rest"] = " *"
			else:
				var out := ""
				for d2 in D_DEFS:
					var c3 := String(d2[0])
					if c3 != "*" and bool(set.get(c3, false)):
						out += c3
				f["rest"] = " " + out
			rebuild.call())
		grid.add_child(cb)
	_sub_detail.add_child(grid)


func _f_editor(f: Dictionary, rebuild: Callable) -> void:
	var toks := String(f.get("rest", "")).split(" ", false)
	var fa := {"on": false, "nn": "05", "ff": "00"}
	var fd := {"on": false, "nn": "05", "ff": "00"}
	for i in toks.size():
		if String(toks[i]) == "A" and i + 2 < toks.size():
			fa = {"on": true, "nn": String(toks[i + 1]),
					"ff": String(toks[i + 2])}
		if String(toks[i]) == "D" and i + 2 < toks.size():
			fd = {"on": true, "nn": String(toks[i + 1]),
					"ff": String(toks[i + 2])}
	var apply := func() -> void:
		var parts: Array[String] = []
		if bool(fa["on"]):
			parts.append_array(["A", String(fa["nn"]), String(fa["ff"])])
		if bool(fd["on"]):
			parts.append_array(["D", String(fd["nn"]), String(fd["ff"])])
		f["rest"] = (" " + " ".join(parts)) if not parts.is_empty() else ""
		rebuild.call()
	_f_side("A: 生存数が nn 以上になったら", fa, apply)
	_f_side("D: 生存数が nn 以下になったら", fd, apply)


func _f_side(label: String, st: Dictionary, apply: Callable) -> void:
	var cb := CheckBox.new()
	cb.text = label
	cb.button_pressed = bool(st["on"])
	cb.toggled.connect(func(on: bool) -> void:
		st["on"] = on
		apply.call())
	_sub_detail.add_child(cb)
	var h := HBoxContainer.new()
	var nl := Label.new()
	nl.text = "  個数 nn"
	h.add_child(nl)
	var ne := LineEdit.new()
	ne.text = String(st["nn"])
	ne.custom_minimum_size = Vector2(70, 0)
	ne.text_changed.connect(func(t: String) -> void:
		st["nn"] = t
		apply.call())
	h.add_child(ne)
	var fl := Label.new()
	fl.text = "フラグ ff"
	h.add_child(fl)
	var fe := LineEdit.new()
	fe.text = String(st["ff"])
	fe.custom_minimum_size = Vector2(90, 0)
	fe.text_changed.connect(func(t: String) -> void:
		st["ff"] = t
		apply.call())
	h.add_child(fe)
	_sub_detail.add_child(h)


# ------------------------------------------------------------ グラ表示

func _on_gra_dir_pressed() -> void:
	if _gra_dialog == null:
		_gra_dialog = FileDialog.new()
		_gra_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
		_gra_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_gra_dialog.transparent = true
		_gra_dialog.title = "キャラグラフォルダを選ぶ"
		_gra_dialog.dir_selected.connect(_on_gra_dir_selected)
		add_child(_gra_dialog)
	if _gra.root != "" and DirAccess.dir_exists_absolute(_gra.root):
		_gra_dialog.current_dir = _gra.root
	_gra_dialog.popup_centered(Vector2i(900, 600))


func _on_gra_dir_selected(dir: String) -> void:
	_gra.set_root(dir)
	_update_gra_left_note()
	if not _block.is_empty():
		_show_enemy()


func _update_gra_left_note() -> void:
	if _gra_left_note == null:
		return
	_gra_left_note.text = "グラ %d 件" % _gra.names.size() \
			if not _gra.names.is_empty() else "グラが見つかりません"


func _find_g_sub() -> int:
	if _block.is_empty():
		return -1
	for i in range(int(_block["header"]) + 1, int(_block["end"])):
		var r: Dictionary = _ed.records[i]
		if String(r["kind"]) == "sub" \
				and String(r["fields"].get("letter", "")) == "G":
			return i
	return -1


func _enemy_graphic() -> String:
	var gi := _find_g_sub()
	if gi < 0:
		return ""
	return String(_ed.records[gi]["fields"].get("graphic", ""))


func _set_enemy_graphic(gname: String) -> void:
	var gi := _find_g_sub()
	if gi >= 0:
		var r: Dictionary = _ed.records[gi]
		r["fields"]["graphic"] = gname
		r["fields"]["rest"] = " " + gname
		_ed.touch(r)
	else:
		if gname == "":
			return
		var proto := PhiEd._parse_sub(":G " + gname)
		proto["modified"] = true
		_insert_record(int(_block["header"]) + 1, proto)
		_block["end"] = int(_block["end"]) + 1
	_refresh_subs()
	var pos := _sub_indices.find(_find_g_sub())
	if pos >= 0:
		_sub_list.set_item_text(pos, PhiEd.build_line(
				_ed.records[_find_g_sub()]).substr(0, 55))
	_update_enemy_preview()


func _enemy_is_large() -> bool:
	var f: Dictionary = _ed.records[int(_block["header"])]["fields"]
	if String(f["type"]) != "00" and String(f["mhp"]).to_int() >= 5000:
		return true
	for i in range(int(_block["header"]) + 1, int(_block["end"])):
		var r: Dictionary = _ed.records[i]
		if String(r["kind"]) == "sub" \
				and String(r["fields"].get("letter", "")) == "O":
			if bool(parse_options(String(r["fields"].get("options", "")))["b"]):
				return true
	return false


func _build_enemy_gra(rec: Dictionary) -> void:
	var head := Label.new()
	head.text = "■ グラフィック (:G)"
	head.add_theme_color_override("font_color", AppTheme.GOLD)
	_detail.add_child(head)
	var h := HBoxContainer.new()
	var sv := VBoxContainer.new()
	_sheet_rect = TextureRect.new()
	_sheet_rect.custom_minimum_size = Vector2(144, 192)
	_sheet_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sheet_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_sheet_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sv.add_child(_sheet_rect)
	var sl := Label.new()
	sl.text = "全体"
	sv.add_child(sl)
	h.add_child(sv)
	var fv := VBoxContainer.new()
	_frame_rect = TextureRect.new()
	_frame_rect.custom_minimum_size = Vector2(128, 128)
	_frame_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_frame_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_frame_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fv.add_child(_frame_rect)
	_frame_label = Label.new()
	_frame_label.text = "向き"
	fv.add_child(_frame_label)
	h.add_child(fv)
	_detail.add_child(h)
	var dh := HBoxContainer.new()
	var dl := Label.new()
	dl.text = "プレビュー向き"
	dl.custom_minimum_size = Vector2(150, 0)
	dh.add_child(dl)
	var dob := OptionButton.new()
	for n in ["北", "東", "南", "西"]:
		dob.add_item(n)
	dob.select(_preview_dir)
	dob.item_selected.connect(func(i: int) -> void:
		_preview_dir = i
		_update_enemy_preview())
	dh.add_child(dob)
	_detail.add_child(dh)
	var gh := HBoxContainer.new()
	var gl := Label.new()
	gl.text = "グラフィック名"
	gl.custom_minimum_size = Vector2(150, 0)
	gh.add_child(gl)
	var ge := LineEdit.new()
	ge.text = _enemy_graphic()
	ge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ge.text_changed.connect(func(t: String) -> void:
		_set_enemy_graphic(t))
	gh.add_child(ge)
	var gob := OptionButton.new()
	gob.tooltip_text = "フォルダ内のグラから選ぶ"
	if _gra.names.is_empty():
		gob.add_item("(グラなし)")
		gob.disabled = true
	else:
		for gn in _gra.names:
			gob.add_item(gn)
		var cur := _gra.names.find(_enemy_graphic())
		if cur >= 0:
			gob.select(cur)
	gob.item_selected.connect(func(i: int) -> void:
		var gn := gob.get_item_text(i)
		ge.text = gn
		_set_enemy_graphic(gn))
	gh.add_child(gob)
	_detail.add_child(gh)
	_gra_note = Label.new()
	_gra_note.add_theme_font_size_override("font_size", AppTheme.rel(_gra_note, 20))
	_detail.add_child(_gra_note)
	_update_enemy_preview()


func _update_enemy_preview() -> void:
	if _sheet_rect == null or _block.is_empty():
		return
	var gname := _enemy_graphic()
	if gname == "":
		_sheet_rect.texture = null
		_frame_rect.texture = null
		_frame_label.text = "向き"
		_gra_note.text = ":G が無い敵は既定グラで表示されます"
		return
	var path := _gra.find_path(gname)
	if path == "":
		_sheet_rect.texture = null
		_frame_rect.texture = null
		_frame_label.text = "向き"
		_gra_note.text = "グラ '%s' が見つかりません (フォルダを確認)" % gname
		return
	var data := _gra.data_for(path)
	if data.is_empty():
		_gra_note.text = "グラ '%s' を読み込めません" % gname
		return
	var img: Image = data["img"]
	_sheet_rect.texture = data["tex"]
	var large := _enemy_is_large()
	_frame_rect.texture = _gra.frame_texture(img, _preview_dir, large)
	_frame_label.text = "向き: %s (%s)" % [
			["北", "東", "南", "西"][_preview_dir],
			"大 32x32" if large else "小 16x32"]
	_gra_note.text = path.get_file()


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

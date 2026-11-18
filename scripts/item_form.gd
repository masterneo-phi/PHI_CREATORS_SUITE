class_name ItemForm
extends RefCounted
## ITEM DATA / SPELL DATA (FORMAT_SPEC §0.6/§0.7) の分解とフォーム生成を
## ed / crt / ex エディタで共有する。分解できない文字列は false を返し、
## 呼び出し側が原文編集にフォールバックする。

const HEXD := "0123456789abcdef"
const FN_DEFS: Array = [
	["n", "n 無"], ["e", "e 地"], ["l", "l 光"], ["a", "a 空"],
	["s", "s 精霊"], ["w", "w 水"], ["f", "f 火"], ["m", "m 鏡"],
	["p", "p 虹分光"], ["r", "r 虹"], ["v", "v 可変 (再抽選)"],
	["-", "- ワイルドカード"],
]
const WD_NAMES: Array[String] = [
	"F", "FR", "FL", "FLR", "FB", "FBR", "FBL", "FBLR", "なし",
	"R", "L", "LR", "B", "BR", "BL", "BLR",
]
const MT_NAMES: Array[String] = [
	"皮/肉", "木", "石", "鋼", "銀", "ミスリル", "オリハルコン",
	"アダマンタイト", "魔法", "9 未定義", "a 未定義", "b 未定義",
	"c 未定義", "d 未定義", "e 未定義", "NO-BREAK 壊れない",
]
const WT_NAMES: Array[String] = [
	"拳", "剣", "刃", "刺", "槍", "斧", "打", "鞭", "牙", "広域",
	"周囲", "b 未定義", "c 未定義", "d 未定義", "e 未定義", "f 未定義",
]
const IT_NAMES: Array[String] = [
	"NOUSE", "Armor 防具", "Weapon 武器", "Food 食料", "Resource 資源",
	"Jewel 宝石", "Charge チャージ", "Accessory 装飾", "SpellJewel 魔石",
	"9 未定義", "a 未定義", "b 未定義", "Evently イベント", "Scroll 巻物",
	"Foreign 外国", "All 全",
]
const OP_MEANINGS := {
	"1": ["ATP 攻撃力", "DFP 物理防御%", "MRP 魔法防御%", "SE 特殊効果"],
	"2": ["ATP 攻撃力", "ER 強化率", "AE 追加効果", "SE 特殊効果"],
	"3": ["ATP 攻撃力", "VALUE2", "VALUE MP回復", "ENTROP 保存性"],
	"4": ["ATP 攻撃力", "(未使用)", "リソース種別", "SE 特殊効果"],
	"5": ["ATP 攻撃力", "価値 下位", "価値 上位 (x100)", "SE 特殊効果"],
	"6": ["ATP 攻撃力", "CHARGE 使用回数", "UE 魔法効果番号", "SE 特殊効果"],
	"7": ["ATP 攻撃力", "(未使用)", "AT 付加能力", "SE 特殊効果"],
	"8": ["ATP 攻撃力", "(未使用)", "UE 習得する効果", "SE 特殊効果"],
	"c": ["ATP 攻撃力", "フラグ番号", "残り使用回数", "SE 特殊効果"],
	"d": ["ATP 攻撃力", "メッセージ番号 上位", "メッセージ番号 下位", "SE 特殊効果"],
}
const SE_HELP := "op3 (SE 特殊効果): 0 なし / 1 ATP↑ / 2 ATP↓ / 3 DEF↑ / 4 DEF↓ / 5 MRP↑ / 6 MRP↓ / 7 ヘイスト / 8 スロウ / 9 イリュージョン / 10 リジェネ / 11 意志 / 12 毒 / 13 麻痺 / 14 パニック / 15 混乱 / 16 狂戦士 / 17 沈黙 / 18 カルマ↑ / 19 カルマ↓ / 20 千里眼 / 21 盲目 / 24 ギガント / 32 リトル / 33 移動不可 / 99 出現"
const AE_HELP := "op2 (AE 追加効果): 0 なし / 1 毒 / 2 麻痺 / 3 パニック / 4 混乱 / 5 狂戦士 / 6 沈黙 / 7 ドレイン / 8 盗み / 9 精神 / 10 エネルギー / 11 秩序 / 12 混沌 / 13 盲目 / 14 ノックバック / 15 ランダム / 16 全て / 17 リック / 18-19 ガード3/4 / 20-23 サーガ1-4 / 24 ドラゴン / 25 神 / 26 精霊 / 27 悪魔 / 28-29 ガード1/2"


# ------------------------------------------------------------ 分解と再構築

static func parse_item_data(data: String) -> Dictionary:
	var dd := data.find("  ")
	if dd < 0:
		return {}
	var tail := data.substr(dd).lstrip(" ")
	var toks := tail.split(" ", false)
	if toks.size() < 7:
		return {}
	var d := {"name": data.substr(0, dd).rstrip(" "),
			"type": String(toks[0]), "wp": String(toks[1]),
			"fn": String(toks[2]),
			"ops": [String(toks[3]), String(toks[4]), String(toks[5]),
					String(toks[6])],
			"drop": false, "ext": ""}
	var ops: Array = d["ops"]
	if String(ops[3]).length() == 3 and String(ops[3]).ends_with("-"):
		ops[3] = String(ops[3]).substr(0, 2)
		d["drop"] = true
	var rest := ""
	if toks.size() > 7:
		rest = " ".join(toks.slice(7))
	if rest.begins_with("-"):
		d["drop"] = true
		rest = rest.substr(1).lstrip(" ")
	d["ext"] = rest
	return d


static func build_item_data(d: Dictionary) -> String:
	var nm := String(d["name"])
	var nb := Cp932.encode(nm).size()
	while nb < 31:
		nm += " "
		nb += 1
	var ops: Array = d["ops"]
	var out := nm + " " + String(d["type"]) + " " + String(d["wp"]) \
			+ " " + String(d["fn"]) + " " + " ".join(ops)
	if bool(d["drop"]):
		out += " -"
	if String(d["ext"]) != "":
		out += " " + String(d["ext"])
	return out


static func parse_spell_data(data: String) -> Dictionary:
	var dd := data.find("  ")
	if dd < 0:
		return {}
	var tail := data.substr(dd).lstrip(" ")
	var toks := tail.split(" ", false)
	if toks.size() < 2:
		return {}
	var d := {"name": data.substr(0, dd).rstrip(" "),
			"effect": String(toks[0]), "fn": String(toks[1]),
			"star": false, "ext": ""}
	var i := 2
	if i < toks.size() and String(toks[i]) == "*":
		d["star"] = true
		i += 1
	if i < toks.size():
		d["ext"] = " ".join(toks.slice(i))
	return d


static func build_spell_data(d: Dictionary) -> String:
	var nm := String(d["name"])
	var nb := Cp932.encode(nm).size()
	while nb < 31:
		nm += " "
		nb += 1
	var out := nm + " " + String(d["effect"]) + " " + String(d["fn"])
	if bool(d["star"]):
		out += " *"
	if String(d["ext"]) != "":
		out += " " + String(d["ext"])
	return out


# ------------------------------------------------------------ フォーム部品

static func _help(parent: Control, text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.modulate = Color(0.75, 0.75, 0.75)
	l.add_theme_font_size_override("font_size", AppTheme.rel(l, 20))
	parent.add_child(l)
	return l


static func _edit(parent: Control, label: String, value: String,
		width: int, on_change: Callable) -> LineEdit:
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
	parent.add_child(h)
	return e


static func _fn_ob(current: String, on_pick: Callable) -> OptionButton:
	var ob := OptionButton.new()
	var sel := 0
	for i in FN_DEFS.size():
		ob.add_item(String(FN_DEFS[i][1]))
		if String(FN_DEFS[i][0]) == current:
			sel = i
	ob.select(sel)
	ob.item_selected.connect(func(i: int) -> void:
		on_pick.call(String(FN_DEFS[i][0])))
	return ob


static func _fn_row(parent: Control, current: String,
		on_pick: Callable) -> void:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = "属性 fn"
	l.custom_minimum_size = Vector2(150, 0)
	h.add_child(l)
	h.add_child(_fn_ob(current, on_pick))
	parent.add_child(h)


static func _nibble_ob(names: Array, cur: String,
		on_pick: Callable) -> OptionButton:
	var ob := OptionButton.new()
	ob.add_item("- ワイルドカード")
	for n in names:
		ob.add_item(String(n))
	var sel := 0
	if cur != "-":
		var p := HEXD.find(cur.to_lower())
		if p >= 0:
			sel = p + 1
	ob.select(sel)
	ob.item_selected.connect(func(i: int) -> void:
		on_pick.call("-" if i == 0 else HEXD[i - 1]))
	return ob


static func _nibble_row(parent: Control, label: String, names: Array,
		cur: String, on_pick: Callable) -> void:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(150, 0)
	h.add_child(l)
	h.add_child(_nibble_ob(names, cur, on_pick))
	parent.add_child(h)


# ------------------------------------------------------------ フォーム生成

static func build_item_form(parent: Control, data: String,
		on_apply: Callable) -> bool:
	var d := parse_item_data(data)
	if d.is_empty():
		return false
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(box)
	var apply := func() -> void:
		on_apply.call(build_item_data(d))
	_edit(box, "アイテム名", String(d["name"]), 0, func(t: String) -> void:
		d["name"] = t
		apply.call())
	var type_str := String(d["type"])
	while type_str.length() < 4:
		type_str += "0"
	var op_labels: Array[Label] = []
	var ae_help: Label = null
	var set_nib := func(pos: int, c: String) -> void:
		var t := String(d["type"])
		while t.length() < 4:
			t += "0"
		t = t.substr(0, pos) + c + t.substr(pos + 1)
		d["type"] = t
		apply.call()
		if pos == 3:
			var meanings: Array = OP_MEANINGS.get(c,
					["ATP 攻撃力", "op1", "op2", "SE 特殊効果"])
			for k in 4:
				op_labels[k].text = "op%d %s" % [k, String(meanings[k])]
			ae_help.visible = c == "2"
	_nibble_row(box, "タイプ1桁目 (攻撃方向)", WD_NAMES, type_str[0],
			func(c: String) -> void: set_nib.call(0, c))
	_nibble_row(box, "タイプ2桁目 (材質)", MT_NAMES, type_str[1],
			func(c: String) -> void: set_nib.call(1, c))
	_nibble_row(box, "タイプ3桁目 (攻撃タイプ)", WT_NAMES, type_str[2],
			func(c: String) -> void: set_nib.call(2, c))
	_nibble_row(box, "タイプ4桁目 (使用効果)", IT_NAMES, type_str[3],
			func(c: String) -> void: set_nib.call(3, c))
	_help(box, "攻撃方向は F=前 R=右 L=左 B=後 の組合せ (8=なし)")
	_edit(box, "重さ wp (2桁)", String(d["wp"]), 70,
			func(t: String) -> void:
		d["wp"] = t
		apply.call())
	_help(box, "重さ。-- = ワイルドカード、NN^ = NN以上、NNv = NN以下。重いほど武器の命中・回避が下がる")
	_fn_row(box, String(d["fn"]), func(c: String) -> void:
		d["fn"] = c
		apply.call())
	var meanings0: Array = OP_MEANINGS.get(type_str[3],
			["ATP 攻撃力", "op1", "op2", "SE 特殊効果"])
	var oph := HBoxContainer.new()
	var ops: Array = d["ops"]
	for k in 4:
		var vb := VBoxContainer.new()
		var ml := Label.new()
		ml.text = "op%d %s" % [k, String(meanings0[k])]
		ml.add_theme_font_size_override("font_size", AppTheme.rel(ml, 20))
		vb.add_child(ml)
		op_labels.append(ml)
		var e := LineEdit.new()
		e.text = String(ops[k])
		e.custom_minimum_size = Vector2(70, 0)
		var kk := k
		e.text_changed.connect(func(t: String) -> void:
			ops[kk] = t
			apply.call())
		vb.add_child(e)
		oph.add_child(vb)
	box.add_child(oph)
	_help(box, SE_HELP)
	ae_help = _help(box, AE_HELP)
	ae_help.visible = type_str[3] == "2"
	var drop := CheckBox.new()
	drop.text = "落すだけ (NPC は装備・使用しない)"
	drop.button_pressed = bool(d["drop"])
	drop.toggled.connect(func(on: bool) -> void:
		d["drop"] = on
		apply.call())
	box.add_child(drop)
	_edit(box, "拡張文字列", String(d["ext"]), 0, func(t: String) -> void:
		d["ext"] = t
		apply.call())
	return true


static func build_spell_form(parent: Control, data: String,
		on_apply: Callable) -> bool:
	var d := parse_spell_data(data)
	if d.is_empty():
		return false
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(box)
	var apply := func() -> void:
		on_apply.call(build_spell_data(d))
	_edit(box, "魔法名", String(d["name"]), 0, func(t: String) -> void:
		d["name"] = t
		apply.call())
	_edit(box, "効果番号 (2桁)", String(d["effect"]), 70,
			func(t: String) -> void:
		d["effect"] = t
		apply.call())
	_help(box, "効果番号はファイル番号 (魔法一覧は man/phi_effect.man)。威力と消費 MP は魔法名の長さで決まる")
	_fn_row(box, String(d["fn"]), func(c: String) -> void:
		d["fn"] = c
		apply.call())
	var star := CheckBox.new()
	star.text = "習得できない魔法 (*)"
	star.button_pressed = bool(d["star"])
	star.toggled.connect(func(on: bool) -> void:
		d["star"] = on
		apply.call())
	box.add_child(star)
	_edit(box, "拡張文字列", String(d["ext"]), 0, func(t: String) -> void:
		d["ext"] = t
		apply.call())
	return true

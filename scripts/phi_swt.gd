class_name PhiSwt
extends RefCounted
## phi.swt (スイッチ) のモデル。FORMAT_SPEC §7。
##
## :S 行は「固定ヘッダ + 条件パラメータ + 動作ヘッダ + 動作パラメータ」
## の可変長文法。パラメータは CC/DD ごとの形表 (PARAM_SPECS) で
## アトム (引用符つき文字列 or 空白区切りトークン) に分解して保持し、
## 未知・解釈不能な部分は tail_raw に原文のまま残す。未編集行は
## PhiRawLines がバイトを保証するので、ここでの分解は編集 UI の
## ためのもので、往復の安全は土台が担う。

var raw_lines: PhiRawLines
var records: Array[Dictionary] = []

## アトム種別: "tok" 空白区切り / "q" 引用 (両種) / "qD" " のみ /
## "rest" 行末まで / "opt_tok" あってもなくてもよい tok
const CC_PARAMS := {
	0: [], 1: ["tok", "tok"], 2: [], 3: ["qD"], 4: ["q"], 5: ["tok"],
	6: ["tok", "tok"], 7: ["qD"], 8: ["q"], 9: ["tok"], 10: ["qD"],
	11: ["tok", "tok"], 12: ["qD"], 13: ["qD"], 14: ["q"], 15: ["tok"],
	16: ["tok", "tok"], 17: [], 18: ["q"],
	20: ["tok", "tok", "tok"], 21: ["qtok"], 22: [], 23: [], 24: [],
	25: ["tok", "tok", "tok", "tok", "tok", "tok"],
	30: ["tok"], 31: ["tok"],
	# PHIDM_NEO 独自拡張: 80=職業・性別 / 91=実時間 (月・日・時・分、
	# 各 99=任意) / 92=ペット (タイプ・状態)。条件25 の変動量形式は
	# 専用リーダ (_read_cc25) で読むため、ここの 25 は従来形の宣言。
	80: ["tok", "tok"], 91: ["tok", "tok", "tok", "tok"],
	92: ["tok", "tok"],
}
const DD_PARAMS := {
	1: ["tok"], 2: [], 3: ["qD"], 4: ["qitem"], 5: ["tok"],
	6: ["opt_tok"], 7: ["qtok"], 8: ["tok", "tok"], 9: ["tok", "tok"],
	10: ["tok", "qD"], 11: ["qD", "opt_tok"], 12: [], 13: ["tok"],
	14: ["qitem"], 15: ["qtok"], 17: ["tok"],
	18: ["tok", "tok", "tok", "opt_expr_tail"], 19: ["tok", "tok"],
	20: ["tok", "tok", "qD"], 21: ["tok", "opt_tok"], 22: ["rest"],
	23: ["tok"], 24: [], 25: ["rest"], 26: ["tok", "tok", "opt_tok"],
	29: ["tok"], 30: [], 31: [], 33: ["q"], 34: ["tok", "tok"],
	44: ["qitem"],
	45: ["tok"], 50: ["rest"], 90: ["qD"],
	# PHIDM_NEO 独自拡張: 51/52=式・代入 (JET 由来、50 と同じ rest 形)、
	# 80=職業・性別を設定、81/82=フラグを変更 (JET 由来、10 と同じ形)、
	# 92=ペット (操作・タイプ)。
	51: ["rest"], 52: ["rest"], 80: ["tok", "tok"],
	81: ["tok", "qD"], 82: ["tok", "qD"], 92: ["tok", "tok"],
	# PHIDM_NEO 独自拡張: 60=刻印記録 / 61=刻印表示 / 62=プログラム
	# 実行、63〜68=演出 (FX)。いずれも引用符つき文字列 1 つ。
	# 69 は演出系の予約番号 (サーバ未実装のため登録しない)。
	60: ["q"], 61: ["q"], 62: ["q"],
	63: ["q"], 64: ["q"], 65: ["q"], 66: ["q"], 67: ["q"], 68: ["q"],
}
## DD16 は x の値で中間アトム数が変わるため専用処理する


static func parse(raw: PhiRawLines) -> PhiSwt:
	var sw := PhiSwt.new()
	sw.raw_lines = raw
	for i in raw.line_count():
		sw.records.append(_parse_line(raw.line_text(i)))
	return sw


static func load_file(path: String) -> PhiSwt:
	var raw := PhiRawLines.load_file(path)
	if raw == null:
		return null
	return parse(raw)


func serialize() -> PackedByteArray:
	for i in records.size():
		if bool(records[i].get("modified", false)):
			raw_lines.set_line_text(i, build_line(records[i]))
	return raw_lines.to_bytes()


func touch(rec: Dictionary) -> void:
	rec["modified"] = true


## 行と対応させてレコードを追加し、その番号を返す
func add_record(rec: Dictionary) -> int:
	raw_lines.lines.append(PackedByteArray())
	raw_lines.eols.append("\n".to_utf8_buffer())
	raw_lines.dirty.append(false)
	rec["modified"] = true
	records.append(rec)
	return records.size() - 1


## 行ごとレコードを削除する
func remove_record(idx: int) -> void:
	raw_lines.lines.remove_at(idx)
	raw_lines.eols.remove_at(idx)
	raw_lines.dirty.remove_at(idx)
	records.remove_at(idx)


static func _rec(kind: String, fields: Dictionary) -> Dictionary:
	return {"kind": kind, "fields": fields, "modified": false}


## 引用を尊重してアトム列へ分解する。pos 以降を [atoms, rest] で返す
static func _read_atom(s: String, pos: int) -> Array:
	var i := pos
	while i < s.length() and s[i] == " ":
		i += 1
	if i >= s.length():
		return ["", i]
	if s[i] == '"' or s[i] == "'":
		var q := s[i]
		var j := i + 1
		while j < s.length() and s[j] != q:
			j += 1
		if j < s.length():
			j += 1
		return [s.substr(i, j - i), j]
	var j := i
	while j < s.length() and s[j] != " ":
		j += 1
	return [s.substr(i, j - i), j]


static func _read_atoms(s: String, pos: int, specs: Array) -> Array:
	var atoms: Array = []
	var p := pos
	for spec in specs:
		var rest := s.substr(p).lstrip(" ")
		if rest == "":
			break
		match String(spec):
			"rest":
				atoms.append(rest)
				p = s.length()
			"opt_tok":
				var a := _read_atom(s, p)
				if String(a[0]) != "":
					atoms.append(a[0])
					p = int(a[1])
			"opt_expr_tail":
				atoms.append(rest)
				p = s.length()
			_:
				var a := _read_atom(s, p)
				atoms.append(a[0])
				p = int(a[1])
	return [atoms, s.substr(p), p]


## 条件20 は `変数 OP 右辺` で、OP と右辺が連結した形 (<=03) もある
static func _read_cc20(s: String, pos: int) -> Array:
	var atoms: Array = []
	var a := _read_atom(s, pos)
	atoms.append(String(a[0]))
	var p := int(a[1])
	a = _read_atom(s, p)
	var op := String(a[0])
	atoms.append(op)
	p = int(a[1])
	const OPS := ["=", "!", "<", "<=", ">", ">=", "&", "^", "_", "l", "g"]
	if op in OPS:
		a = _read_atom(s, p)
		atoms.append(String(a[0]))
		p = int(a[1])
	return [atoms, s.substr(p).lstrip(" "), p]


## 条件25 は 6 アトム (レベル種類・式・値・状態種別・式・境界値) が
## 基本形で、状態種別 (4 つ目) が 2/3 の時だけ 7 つ目に変動量下限
## (4桁) が続く (PHIDM_NEO v2.2)。サーバのローダと同じ分岐で読む。
static func _read_cc25(s: String, pos: int) -> Array:
	var got := _read_atoms(s, pos,
			["tok", "tok", "tok", "tok", "tok", "tok"])
	var atoms: Array = got[0]
	var p := int(got[2])
	if atoms.size() >= 4 and String(atoms[3]).to_int() >= 2:
		var a := _read_atom(s, p)
		if String(a[0]) != "":
			atoms.append(String(a[0]))
			p = int(a[1])
	return [atoms, s.substr(p), p]


static func _parse_line(line: String) -> Dictionary:
	if line.begins_with(":S "):
		return _parse_s(line)
	if line.begins_with(":A "):
		return _parse_a(line)
	if line.begins_with(":M "):
		return _parse_m(line)
	return _rec("raw", {})


static func _parse_s(line: String) -> Dictionary:
	var p := 3
	var head: Array = []
	for k in 3:
		var a := _read_atom(line, p)
		head.append(String(a[0]))
		p = int(a[1])
	if head.size() < 3 or String(head[2]) == "":
		return _rec("raw", {})
	var cc := String(head[2]).to_int()
	var f := {"sx": String(head[0]).to_int(), "sy": String(head[1]).to_int(),
			"cc": cc}
	var got: Array
	if cc == 20:
		got = _read_cc20(line, p)
	elif cc == 25:
		got = _read_cc25(line, p)
	else:
		var specs: Array = CC_PARAMS.get(cc, [])
		got = _read_atoms(line, p, specs)
	f["cond"] = got[0]
	p = int(got[2])
	# 動作ヘッダ (ax ay dd)
	var ah: Array = []
	for k in 3:
		var a := _read_atom(line, p)
		ah.append(String(a[0]))
		p = int(a[1])
	if ah.size() < 3 or String(ah[2]) == "":
		f["tail_raw"] = line.substr(3)
		return _rec("S_partial", f)
	f["ax"] = String(ah[0]).to_int()
	f["ay"] = String(ah[1]).to_int()
	var dd := String(ah[2]).to_int()
	f["dd"] = dd
	if dd == 16:
		var x := _read_atom(line, p)
		var xa: Array = [String(x[0])]
		p = int(x[1])
		var xv := String(x[0]).to_int()
		if xv == 2 or xv == 3:
			var extra := _read_atom(line, p)
			xa.append(String(extra[0]))
			p = int(extra[1])
		var txt := _read_atom(line, p)
		xa.append(String(txt[0]))
		p = int(txt[1])
		f["act"] = xa
	else:
		var dspecs: Array = DD_PARAMS.get(dd, [])
		var agot := _read_atoms(line, p, dspecs)
		f["act"] = agot[0]
		p = int(agot[2])
	var tail_full := line.substr(p)
	var tail := tail_full.lstrip(" ")
	if tail != "" and not _is_only_padding(tail):
		f["tail_raw"] = tail_full
	return _rec("S", f)


## 末尾の空白埋め (半角/全角スペース) だけかどうか
static func _is_only_padding(s: String) -> bool:
	for i in s.length():
		var c := s[i]
		if c != " " and c != "　" and c != "\t":
			return false
	return true


static func _parse_a(line: String) -> Dictionary:
	var p := 3
	var nums: Array = []
	for k in 3:
		var a := _read_atom(line, p)
		nums.append(String(a[0]))
		p = int(a[1])
	if nums.size() < 3:
		return _rec("raw", {})
	var f := {"no": String(nums[0]).to_int(), "next": String(nums[1]).to_int(),
			"wait": String(nums[2]).to_int()}
	var rest := line.substr(p).lstrip(" ")
	if rest.begins_with('"') or rest.begins_with("'"):
		var a := _read_atom(line, p)
		f["tail_kind"] = 0
		f["text"] = String(a[0])
	elif rest.begins_with("x "):
		f["tail_kind"] = 1
		f["text"] = rest
	elif rest.begins_with("f "):
		f["tail_kind"] = 2
		f["text"] = rest
	elif rest.begins_with("z "):
		# 演出 (FX) ペイロード (PHIDM_NEO 拡張、設計書 §10)
		f["tail_kind"] = 3
		f["text"] = rest
	elif rest == "y" or rest.begins_with("y "):
		# Yes/No 選択 (PHIDM_NEO 拡張、MRDM 由来)。分岐先はパラメータ
		# ではなく next=はい / wait=いいえ の欄が担う
		f["tail_kind"] = 4
		f["text"] = rest
	elif rest == "s" or rest.begins_with("s "):
		# 選択肢 (PHIDM_NEO 拡張、MRDM 由来)。next=次の選択肢行、
		# wait=選択時の分岐先
		f["tail_kind"] = 5
		f["text"] = rest
	else:
		f["tail_kind"] = -1
		f["text"] = rest
	return _rec("A", f)


static func _parse_m(line: String) -> Dictionary:
	var p := 3
	var a := _read_atom(line, p)
	var f := {"no": String(a[0]).to_int()}
	p = int(a[1])
	a = _read_atom(line, p)
	f["pattern"] = String(a[0])
	p = int(a[1])
	a = _read_atom(line, p)
	f["caption"] = String(a[0])
	p = int(a[1])
	f["action"] = line.substr(p).lstrip(" ")
	return _rec("M", f)


static func build_line(rec: Dictionary) -> String:
	var f: Dictionary = rec["fields"]
	match String(rec["kind"]):
		"S":
			var parts: Array = [":S", "%03d" % int(f["sx"]),
					"%03d" % int(f["sy"]), "%02d" % int(f["cc"])]
			parts.append_array(f["cond"])
			parts.append("%03d" % int(f["ax"]))
			parts.append("%03d" % int(f["ay"]))
			parts.append("%02d" % int(f["dd"]))
			parts.append_array(f["act"])
			var out := " ".join(parts)
			if f.has("tail_raw"):
				out += String(f["tail_raw"])
			return out
		"A":
			var out := ":A %04d %04d %04d" % [int(f["no"]), int(f["next"]),
					int(f["wait"])]
			if String(f.get("text", "")) != "":
				out += " " + String(f["text"])
			return out
		"M":
			var out := ":M %04d %s %s" % [int(f["no"]), String(f["pattern"]),
					String(f["caption"])]
			if String(f.get("action", "")) != "":
				out += " " + String(f["action"])
			return out
	return ""

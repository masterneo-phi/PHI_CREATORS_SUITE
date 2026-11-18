class_name SwtLibrary
extends RefCounted
## スイッチ作例ライブラリ (第8段)。
## 既存の phi.swt から、座標・文章・キーワードを伏せた作例を作る。
## 残すのは条件/動作の組み合わせとパラメータの形 (仕掛けのパターン)。
## 銀行のような一般的な施設名はそのまま使う (ユーザーの方針)。

const BUNDLED_PATH := "res://data/switch_library.txt"
const USER_PATH := "user://switch_library.txt"

const KEEP_WORDS: Array[String] = ["銀行", "宿屋", "教会", "神社",
	"ギルド", "酒場", "商店", "港", "市場", "闘技場", "図書館", "学校",
	"病院", "武器屋", "防具屋", "道具屋", "交易所", "受付", "看板",
	"掲示板", "ゲート", "神殿", "温泉", "訓練場", "鍛冶屋", "薬屋",
	"牧場", "灯台", "宿", "店", "村", "町"]
const LABEL_WORDS: Array[String] = ["スイッチ", "復活", "死亡",
	"ゲート", "接続", "テレポート", "銀行", "宿屋", "教会", "ギルド",
	"チュートリアル", "看板", "掲示板", "宝箱", "罠", "回復", "移動",
	"転送", "出現", "支払", "会話", "選択", "フラグ", "開始", "終了",
	"開閉", "施錠", "セーブ", "PK", "TEST", "テスト"]


static func _has_non_ascii(s: String) -> bool:
	for i in s.length():
		if s.unicode_at(i) > 127:
			return true
	return false


static func _is_generic_short(s: String) -> bool:
	var t := s.strip_edges()
	if t.length() > 12:
		return false
	for w in KEEP_WORDS:
		if t.contains(w):
			return true
	return false


## 数字の並び (run 桁) から後ろを返す。無ければ ""
static func _tail_from_digits(s: String, run: int) -> String:
	var i := 0
	while i + run <= s.length():
		var ok := true
		for j in run:
			var c := s.unicode_at(i + j)
			if c < 48 or c > 57:
				ok = false
				break
		if ok and (i == 0 or s[i - 1] == " "):
			return s.substr(i)
		i += 1
	return ""


static func _sanitize_inner(s: String, role: String) -> String:
	match role:
		"keyword":
			return "キーワード"
		"pattern":
			return "パターン"
		"message":
			return s if _is_generic_short(s) else "メッセージ本文"
		"item":
			var tail := _tail_from_digits(s, 4)
			return "アイテム名 " + tail if tail != "" else "アイテム名"
		"spell":
			var tail2 := _tail_from_digits(s, 2)
			return "魔法名 " + tail2 if tail2 != "" else "魔法名"
		"command":
			return "コマンド" if _has_non_ascii(s) else s
		"expr":
			return "式" if _has_non_ascii(s) else s
	if s.length() <= 4:
		return s
	if not _has_non_ascii(s) and s.length() <= 16:
		return s
	if _is_generic_short(s):
		return s
	return "テキスト"


static func _sanitize_atom(atom: String, role: String) -> String:
	if atom.begins_with("\"") and atom.ends_with("\"") and atom.length() >= 2:
		return "\"" + _sanitize_inner(atom.substr(1, atom.length() - 2),
				role) + "\""
	if _has_non_ascii(atom) and atom.length() > 4:
		var inner := _sanitize_inner(atom, role)
		# 文章・キーワード系は引用符付きの形にそろえる
		if role in ["message", "keyword", "pattern"]:
			return "\"" + inner + "\""
		return inner
	return atom


static func _cond_role(cc: int) -> String:
	match cc:
		3, 7:
			return "keyword"
		13:
			return "pattern"
		4, 8, 18:
			return "item"
		14:
			return "spell"
	return "any"


static func _act_role(dd: int) -> String:
	match dd:
		3, 16, 25, 90:
			return "message"
		4, 14, 44:
			return "item"
		33:
			return "command"
		50:
			return "expr"
	return "any"


## レコードを伏せた形に作り替える。対象外は空辞書を返す
static func sanitize_record(rec: Dictionary) -> Dictionary:
	var kind := String(rec["kind"])
	var f: Dictionary = (rec["fields"] as Dictionary).duplicate(true)
	match kind:
		"S":
			var same := int(f["sx"]) == int(f["ax"]) \
					and int(f["sy"]) == int(f["ay"])
			f["sx"] = 0
			f["sy"] = 0
			f["ax"] = 0 if same else 1
			f["ay"] = 0 if same else 1
			var cc := int(f["cc"])
			var dd := int(f["dd"])
			var cond: Array = []
			for a in f["cond"]:
				cond.append(_sanitize_atom(String(a), _cond_role(cc)))
			f["cond"] = cond
			var act: Array = []
			for a in f["act"]:
				act.append(_sanitize_atom(String(a), _act_role(dd)))
			f["act"] = act
			if f.has("tail_raw") and _has_non_ascii(String(f["tail_raw"])):
				f.erase("tail_raw")
		"A":
			match int(f.get("tail_kind", -1)):
				0:
					f["text"] = _sanitize_atom(String(f["text"]), "message")
				1:
					f["text"] = "x 000 000"
				-1:
					if _has_non_ascii(String(f["text"])):
						f["text"] = ""
		"M":
			f["pattern"] = _sanitize_atom(String(f["pattern"]), "pattern")
			var cap := String(f["caption"])
			if _has_non_ascii(cap) and not _is_generic_short(
					cap.trim_prefix("\"").trim_suffix("\"")):
				f["caption"] = "\"見出し\"" if cap.begins_with("\"") \
						else "見出し"
			if _has_non_ascii(String(f["action"])):
				f["action"] = "テキスト"
		_:
			return {}
	return {"kind": kind, "fields": f, "modified": true}


static func _label_for(rec: Dictionary, comment: String) -> String:
	var c := comment.lstrip("#").strip_edges()
	c = c.rstrip("0123456789 ").strip_edges()
	if c != "" and c.length() <= 14:
		for w in LABEL_WORDS:
			if c.contains(w):
				return c
	var f: Dictionary = rec["fields"]
	match String(rec["kind"]):
		"S":
			return "%s → %s" % [HelpTexts.cc_name(int(f["cc"])),
					HelpTexts.dd_name(int(f["dd"]))]
		"A":
			return "メッセージ連鎖 (:A)"
		"M":
			return "メニュー (:M)"
	return "スイッチ"


## アトム内の数字の並びを # に潰す (署名用)
static func _sig_atom(a: String) -> String:
	var out := ""
	var in_digits := false
	for i in a.length():
		var c := a.unicode_at(i)
		if c >= 48 and c <= 57:
			if not in_digits:
				out += "#"
				in_digits = true
		else:
			out += a[i]
			in_digits = false
	return out


## 作例の「形」の署名。数字は # に潰して判定する
static func _signature(rec: Dictionary) -> String:
	var f: Dictionary = rec["fields"]
	var parts: Array[String] = [String(rec["kind"])]
	match String(rec["kind"]):
		"S":
			parts.append(str(int(f["cc"])))
			for a in f["cond"]:
				parts.append(_sig_atom(String(a)))
			parts.append("@" + str(int(f["ax"])))
			parts.append(str(int(f["dd"])))
			for a in f["act"]:
				parts.append(_sig_atom(String(a)))
		"A":
			parts.append(str(int(f.get("tail_kind", -1))))
			parts.append(_sig_atom(String(f.get("text", ""))))
		"M":
			parts.append(_sig_atom(String(f["pattern"])))
			parts.append(_sig_atom(String(f["caption"])))
	return "|".join(parts)


## 世界の phi.swt から作例の一覧 [{label, line}] を作る (重複除去済み)
static func build_entries(swt: PhiSwt) -> Array:
	var entries: Array = []
	var seen := {}
	var seen_sig := {}
	var comment := ""
	for i in swt.records.size():
		var raw_line := swt.raw_lines.line_text(i)
		if raw_line.begins_with("#") and not raw_line.begins_with("#:"):
			comment = raw_line
			continue
		var rec := swt.records[i]
		if not ["S", "A", "M"].has(String(rec["kind"])):
			continue
		var srec := sanitize_record(rec)
		if srec.is_empty():
			continue
		var line := PhiSwt.build_line(srec)
		if line == "" or seen.has(line):
			continue
		var sig := _signature(srec)
		if seen_sig.has(sig):
			continue
		if String(rec["kind"]) == "S":
			var v := SwtAi.validate_lines(line, Vector2i(1000, 1000))
			if (v["ok"] as Array).is_empty():
				continue
		else:
			var p2 := PhiSwt.parse(PhiRawLines.from_bytes(Cp932.encode(line)))
			if p2.records.is_empty() \
					or PhiSwt.build_line(p2.records[0]) != line:
				continue
		seen[line] = true
		seen_sig[sig] = true
		entries.append({"label": _label_for(rec, comment), "line": line})
	return entries


static func entries_to_text(entries: Array) -> String:
	var parts: Array[String] = [
		"# PHI CREATORS SUITE スイッチ作例ライブラリ",
		"# 座標と文章は伏せてあります。使うときは座標と文章を直してください。"]
	for e in entries:
		parts.append("## " + String(e["label"]))
		parts.append(String(e["line"]))
	return "\n".join(parts) + "\n"


static func parse_library_text(text: String) -> Array:
	var entries: Array = []
	var label := "スイッチ"
	for ln in text.split("\n"):
		var s := ln.strip_edges()
		if s.begins_with("## "):
			label = s.substr(3).strip_edges()
		elif s.begins_with(":S") or s.begins_with(":A") \
				or s.begins_with(":M"):
			entries.append({"label": label, "line": s})
	return entries


static func _read_entries(path: String) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return []
	return parse_library_text(f.get_as_text())


## 同梱 + ユーザーのライブラリを統合 (行で重複除去)
static func load_all() -> Array:
	var out: Array = []
	var seen := {}
	for e in _read_entries(USER_PATH) + _read_entries(BUNDLED_PATH):
		if not seen.has(String(e["line"])):
			seen[String(e["line"])] = true
			out.append(e)
	return out


## ユーザーライブラリへ作例を足して保存し、追加できた件数を返す
static func append_user_entries(new_entries: Array) -> int:
	var cur := _read_entries(USER_PATH)
	var seen := {}
	for e in cur:
		seen[String(e["line"])] = true
	var added := 0
	for e in new_entries:
		if not seen.has(String(e["line"])):
			seen[String(e["line"])] = true
			cur.append(e)
			added += 1
	if added > 0:
		var f := FileAccess.open(USER_PATH, FileAccess.WRITE)
		if f != null:
			f.store_string(entries_to_text(cur))
	return added

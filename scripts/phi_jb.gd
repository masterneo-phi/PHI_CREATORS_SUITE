class_name PhiJb
extends RefCounted
## phi.jb (ジョブ／性別定義) のモデル。PHIDM_NEO 拡張 (phi_class.cpp
## jb_load)。ファイルが存在するだけでシステムが有効になり、書かれて
## いない項目はサーバの標準値が使われる。
##   :N <職業 1-9> <名前>        職業名の上書き
##   :R <職業 1-9> <率> [<率2>]  効果率の上書き (標準の150%まで)
##   :S <性別 1-2> <名前>        性別名の上書き
## 未編集行は PhiRawLines がバイトを保証する。

var raw_lines: PhiRawLines
var records: Array[Dictionary] = []

const MAX_JOB := 9
## サーバ標準の職業名 (添字 = 職業番号、0 は未使用)
const BASE_NAMES: Array[String] = ["", "戦士", "僧侶", "武闘家", "魔法使い",
		"商人", "盗賊", "賢者", "獣人", "魔族"]
## サーバ標準の効果率 [職業][スロット]
const BASE_RATES: Array = [[0, 0], [10, 0], [20, 0], [5, 0], [10, 0],
		[20, 0], [10, 0], [10, 5], [5, 0], [5, 0]]
## 職業ごとの効果スロット数 (賢者だけ 2 つ)
const SLOTS: Array[int] = [0, 1, 1, 1, 1, 1, 1, 2, 1, 1]
## 効果スロットの表示名 [職業][スロット]
const RATE_LABELS: Array = [["", ""], ["物理ダメージ +%"], ["回復 +%"],
		["クリティカル率 +ポイント"], ["魔法ダメージ +%"], ["GP 収入 +%"],
		["攻撃の重さ -%"], ["回復 +%", "魔法ダメージ +%"],
		["防御率 +ポイント"], ["魔法防御率 +ポイント"]]
## サーバ標準の性別名 (添字 = 性別番号)
const BASE_SEXNAMES: Array[String] = ["", "男", "女"]


static func parse(raw: PhiRawLines) -> PhiJb:
	var jb := PhiJb.new()
	jb.raw_lines = raw
	for i in raw.line_count():
		jb.records.append(_parse_line(raw.line_text(i)))
	return jb


static func load_file(path: String) -> PhiJb:
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


func add_record(rec: Dictionary) -> int:
	raw_lines.lines.append(PackedByteArray())
	raw_lines.eols.append("\n".to_utf8_buffer())
	raw_lines.dirty.append(false)
	rec["modified"] = true
	records.append(rec)
	return records.size() - 1


func remove_record(idx: int) -> void:
	raw_lines.lines.remove_at(idx)
	raw_lines.eols.remove_at(idx)
	raw_lines.dirty.remove_at(idx)
	records.remove_at(idx)


static func _parse_line(line: String) -> Dictionary:
	if line.length() >= 2 and line[0] == ":" and line[1] in ["N", "R", "S"]:
		var kind := line[1]
		var rest := line.substr(2).lstrip(" ")
		var sp := rest.find(" ")
		var no_s := rest if sp < 0 else rest.substr(0, sp)
		var tail := "" if sp < 0 else rest.substr(sp + 1).lstrip(" ")
		if no_s.is_valid_int():
			var no := no_s.to_int()
			if kind == "R":
				var rates: Array = []
				for t in tail.split(" ", false):
					rates.append(t)
				return {"kind": "R", "fields": {"no": no, "rates": rates},
						"modified": false}
			return {"kind": kind, "fields": {"no": no, "name": tail},
					"modified": false}
	return {"kind": "raw", "fields": {}, "modified": false}


static func build_line(rec: Dictionary) -> String:
	var f: Dictionary = rec.get("fields", {})
	match String(rec["kind"]):
		"N", "S":
			var name := String(f.get("name", ""))
			if name == "":
				return ":%s %d" % [String(rec["kind"]), int(f["no"])]
			return ":%s %d %s" % [String(rec["kind"]), int(f["no"]), name]
		"R":
			var parts: Array = [":R", str(int(f["no"]))]
			for r in f.get("rates", []):
				parts.append(String(r))
			return " ".join(parts)
	return ""


## 率の上限 (サーバは標準値の 3/2 を超えると丸める。整数演算)
static func rate_cap(no: int, slot: int) -> int:
	return int(BASE_RATES[no][slot]) * 3 / 2


## 上書きを適用した実効の職業名
func job_name(no: int) -> String:
	var v := BASE_NAMES[no]
	for rec in records:
		if String(rec["kind"]) == "N" and int(rec["fields"]["no"]) == no:
			var nm := String(rec["fields"].get("name", ""))
			if nm != "":
				v = nm
	return v


## 上書きを適用した実効の性別名
func sex_name(no: int) -> String:
	var v := BASE_SEXNAMES[no]
	for rec in records:
		if String(rec["kind"]) == "S" and int(rec["fields"]["no"]) == no:
			var nm := String(rec["fields"].get("name", ""))
			if nm != "":
				v = nm
	return v


## 上書きを適用した実効の効果率 (サーバと同じくスロット順に適用し、
## 上限と 0 下限で丸める)
func job_rate(no: int, slot: int) -> int:
	var v := int(BASE_RATES[no][slot])
	for rec in records:
		if String(rec["kind"]) == "R" and int(rec["fields"]["no"]) == no:
			var rates: Array = rec["fields"].get("rates", [])
			if slot < rates.size() and String(rates[slot]).is_valid_int():
				v = clampi(String(rates[slot]).to_int(), 0, rate_cap(no, slot))
	return v


## 指定の種類・番号のレコード番号 (無ければ -1)
func find_record(kind: String, no: int) -> int:
	for i in records.size():
		if String(records[i]["kind"]) == kind \
				and int(records[i]["fields"].get("no", -1)) == no:
			return i
	return -1

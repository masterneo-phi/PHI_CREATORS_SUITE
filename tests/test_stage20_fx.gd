extends SceneTree
## 第20段: DM 演出拡張 (FX) の PCS 対応。
## - 動作 60〜68 (NEO 拡張 + 演出) が DD_PARAMS / DD_NAMES に登録
##   され、引用符つき引数が動作パラメータとして分解・再構築できる
## - :A チェーン本文タイプ z (tail_kind 3) の認識と往復
## - FX 行を含む phi.swt の無編集保存がバイト同一、編集保存では
##   意図した行だけが変わる
## - 69 は予約番号として未登録 (AI 取り込み検証で弾かれる)
## - 作例ライブラリの伏せで FX の表示文字列が残らない

var _checks := 0
var _failures := 0


func _check(cond: bool, label: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		print("FAIL: ", label)


func _parse_one(line: String) -> Dictionary:
	var sw := PhiSwt.parse(PhiRawLines.from_bytes(Cp932.encode(line)))
	return sw.records[0] if sw.records.size() > 0 else {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	Cp932.ensure_loaded()
	# --- 動作 60〜68: 引数がアトムとして分解され、往復する ---
	var fx_args := {
		60: "\"カテゴリ名\"", 61: "\"カテゴリ名\"", 62: "\"program_name\"",
		63: "\"C 200 4000 第四章\"", 64: "\"80 3000 1\"", 65: "\"C on\"",
		66: "\"M crest 5000\"", 67: "\"6 800\"", 68: "\"1500\"",
	}
	for dd in fx_args:
		var line := ":S 010 010 06 00 0000 010 010 %02d %s" % [dd, fx_args[dd]]
		var rec := _parse_one(line)
		_check(String(rec.get("kind", "")) == "S", "dd %d parses as S" % dd)
		var f: Dictionary = rec.get("fields", {})
		_check((f.get("act", []) as Array).size() == 1
				and String(f["act"][0]) == String(fx_args[dd]),
				"dd %d arg is one atom" % dd)
		_check(not f.has("tail_raw"), "dd %d leaves no tail_raw" % dd)
		_check(PhiSwt.build_line(rec) == line, "dd %d round trip" % dd)
		_check(HelpTexts.DD_NAMES.has(dd), "dd %d has a name" % dd)
		var v := SwtAi.validate_lines(line, Vector2i(1000, 1000))
		_check((v["ok"] as Array).size() == 1, "dd %d validates" % dd)
	# --- 69 は予約: 名前が無く、検証で弾かれる ---
	_check(not HelpTexts.DD_NAMES.has(69), "dd 69 stays reserved")
	var v69 := SwtAi.validate_lines(
			":S 010 010 06 00 0000 010 010 69 \"1500\"", Vector2i(1000, 1000))
	_check((v69["ok"] as Array).is_empty(), "dd 69 rejected by validate")
	# --- 未知の動作 (99) は従来どおり tail_raw で往復する ---
	var unk := _parse_one(":S 010 010 06 00 0000 010 010 99 \"何か\"")
	_check(String(unk.get("kind", "")) == "S"
			and (unk["fields"] as Dictionary).has("tail_raw"),
			"unknown dd keeps tail_raw")
	_check(PhiSwt.build_line(unk)
			== ":S 010 010 06 00 0000 010 010 99 \"何か\"",
			"unknown dd round trip")
	# --- :A 本文タイプ: 既存 0/1/2 と新規 3 (z) ---
	var a_cases := {
		":A 4000 4001 0010 \"メッセージ本文\"": 0,
		":A 4000 4001 0010 x 213 146": 1,
		":A 4000 4001 0010 f p5": 2,
		":A 4000 4001 0010 z text C 200 4000 第四章": 3,
		":A 4001 4002 0010 z wipe C on": 3,
		":A 4002 0000 0001 z wipe C off": 3,
	}
	for line in a_cases:
		var rec := _parse_one(line)
		_check(String(rec.get("kind", "")) == "A", "A parses: " + line)
		_check(int(rec["fields"].get("tail_kind", -9)) == int(a_cases[line]),
				"A tail_kind %d: %s" % [int(a_cases[line]), line])
		_check(PhiSwt.build_line(rec) == line, "A round trip: " + line)
	# --- 無編集保存はバイト同一 (CRLF の実データ形式) ---
	var lines: Array[String] = [
		"# コメント行",
		":S 213 145 06 00 0000 213 145 63 \"C 200 4000 第四章\"",
		":S 213 145 06 00 0000 213 145 64 \"80 3000 1\"",
		":S 213 145 06 00 0000 213 145 66 \"M crest 5000\"",
		":A 4000 4001 0010 z text C 200 4000 第四章",
		":A 4001 4002 0010 x 213 146",
		":A 4002 0000 0001 z wipe C off",
		":S 010 010 06 00 0000 010 010 99 \"何か\"",
		":S 003 013 03 \"GO\" 003 013 06",
	]
	var original := Cp932.encode("\r\n".join(lines) + "\r\n")
	var sw := PhiSwt.parse(PhiRawLines.from_bytes(original))
	_check(sw.serialize() == original, "untouched FX swt is byte-identical")
	# --- 編集保存では触った行だけが変わる ---
	var zrec: Dictionary = sw.records[4]
	zrec["fields"]["wait"] = 20
	sw.touch(zrec)
	var srec: Dictionary = sw.records[1]
	srec["fields"]["sx"] = 214
	sw.touch(srec)
	var after := PhiRawLines.from_bytes(sw.serialize())
	_check(after.line_count() == lines.size(), "line count kept")
	for i in lines.size():
		var want := lines[i]
		if i == 1:
			want = ":S 214 145 06 00 0000 213 145 63 \"C 200 4000 第四章\""
		elif i == 4:
			want = ":A 4000 4001 0020 z text C 200 4000 第四章"
		_check(after.line_text(i) == want, "line %d after edit" % i)
	# --- 作例の伏せ: FX の表示文字列が残らず、形は残る ---
	var s63 := SwtLibrary.sanitize_record(_parse_one(
			":S 213 145 06 00 0000 213 145 63 \"C 200 4000 第四章\""))
	var s63line := PhiSwt.build_line(s63)
	_check(not s63line.contains("第四章"), "fx :S title masked")
	_check(s63line.contains("C 200 4000 テキスト"), "fx :S shape kept")
	var az := SwtLibrary.sanitize_record(_parse_one(
			":A 4000 4001 0010 z text C 200 4000 第四章"))
	_check(String(az["fields"]["text"]) == "z text C 200 4000 テキスト",
			"fx :A payload masked")
	var aw := SwtLibrary.sanitize_record(_parse_one(
			":A 4000 4001 0010 z wipe C on"))
	_check(String(aw["fields"]["text"]) == "z wipe C on",
			"fx :A ascii payload kept")
	# --- 同梱ライブラリに FX 作例が入っている ---
	var has63 := false
	var hasz := false
	for e in SwtLibrary.load_all():
		var line := String(e["line"])
		if line.contains(" 63 \""):
			has63 = true
		if line.begins_with(":A") and line.contains(" z "):
			hasz = true
	_check(has63, "bundled library has a dd 63 example")
	_check(hasz, "bundled library has a z chain example")
	print("stage20 checks: ", _checks, " failures: ", _failures)
	quit(1 if _failures > 0 else 0)

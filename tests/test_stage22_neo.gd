extends SceneTree
## PHIDM_NEO 対応 (v0.7.0) のテスト: 追加した条件・動作の仕様表の
## 往復 (parse → build_line / 編集 → serialize のバイト一致)、
## 条件25 変動量形式、:A y/s の種別化、PhiJb / PhiPt の実効値。

var _checks := 0
var _failures := 0


func _check(cond: bool, label: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		print("FAIL: ", label)


func _roundtrip(line: String, label: String) -> Dictionary:
	var bytes := Cp932.encode(line + "\n")
	var sw := PhiSwt.parse(PhiRawLines.from_bytes(bytes))
	_check(sw.records.size() == 1, label + ": 1 record")
	var rec: Dictionary = sw.records[0]
	_check(PhiSwt.build_line(rec) == line, label + ": build_line 一致")
	sw.touch(rec)
	_check(sw.serialize() == bytes, label + ": 編集後 serialize 一致")
	return rec


func _initialize() -> void:
	Cp932.ensure_loaded()
	# --- 条件 80 / 91 / 92 (監査の化け分解の実例を含む) ---
	var r := _roundtrip(":S 002 005 80 01 01 000 000 03 \"COND80_WARRIOR\"",
			"cond80")
	_check(int(r["fields"]["cc"]) == 80 and r["fields"]["cond"].size() == 2,
			"cond80: 条件パラメータ 2 個")
	r = _roundtrip(":S 000 000 91 99 99 20 10 000 000 50 za = 1", "cond91")
	_check(r["fields"]["cond"].size() == 4, "cond91: 条件パラメータ 4 個")
	_check(int(r["fields"]["dd"]) == 50, "cond91: 動作ヘッダが化けていない")
	r = _roundtrip(":S 010 010 92 02 01 010 010 03 \"pet\"", "cond92")
	_check(r["fields"]["cond"].size() == 2, "cond92: 条件パラメータ 2 個")
	_check(int(r["fields"]["ax"]) == 10 and int(r["fields"]["dd"]) == 3,
			"cond92: 動作ヘッダが化けていない")
	# --- 動作 34 / 51 / 52 / 80 / 81 / 82 / 92 ---
	_roundtrip(":S 032 030 03 \"job1\" 000 000 80 01 01", "act80")
	_roundtrip(":S 032 030 03 \"petfairy\" 000 000 92 00 01", "act92")
	_roundtrip(":S 002 002 25 01 < 9999 0 < 9999 002 002 34 40 0030", "act34")
	_roundtrip(":S 001 001 06 00 0000 001 001 51 za += 01", "act51")
	_roundtrip(":S 001 001 06 00 0000 001 001 52 za += 01", "act52")
	_roundtrip(":S 001 001 03 \"go\" 001 001 81 1 \"01 02\"", "act81")
	_roundtrip(":S 001 001 03 \"go\" 001 001 82 1 \"01 02\"", "act82")
	# --- 条件25: 従来形 (6 アトム) と変動量形 (7 アトム) ---
	r = _roundtrip(":S 002 002 25 01 < 9999 0 < 1000 002 002 03 \"LT1000\"",
			"cond25 base")
	_check(r["fields"]["cond"].size() == 6, "cond25 base: 6 アトム")
	r = _roundtrip(
			":S 002 002 25 01 < 9999 2 < 1000 0500 002 002 03 \"DELTA\"",
			"cond25 delta")
	_check(r["fields"]["cond"].size() == 7, "cond25 delta: 7 アトム")
	_check(String(r["fields"]["cond"][6]) == "0500",
			"cond25 delta: 変動量下限が条件側にある")
	_check(int(r["fields"]["dd"]) == 3, "cond25 delta: 動作ヘッダ無事")
	r = _roundtrip(
			":S 002 003 25 01 < 9999 3 > 0500 0100 002 003 03 \"DELTA3\"",
			"cond25 delta mp")
	_check(r["fields"]["cond"].size() == 7, "cond25 delta mp: 7 アトム")
	# --- :A y / s の種別化 ---
	r = _roundtrip(":A 0001 0002 0003 y \"質問ですか\"", "A y")
	_check(int(r["fields"]["tail_kind"]) == 4, "A y: tail_kind=4")
	r = _roundtrip(":A 0005 0006 0007 s \"選択肢その1\"", "A s")
	_check(int(r["fields"]["tail_kind"]) == 5, "A s: tail_kind=5")
	# --- AI 取り込みが NEO 番号を受け付ける ---
	var v := SwtAi.validate_lines(
			":S 002 005 80 01 01 000 000 03 \"X\"\n"
			+ ":S 032 030 03 \"petfairy\" 000 000 92 00 01",
			Vector2i.ZERO)
	_check((v["ok"] as Array).size() == 2, "AI validate: NEO 番号を受付")
	# --- PhiJb ---
	var jb := PhiJb.parse(PhiRawLines.from_bytes(Cp932.encode(
			":N 1 騎士\n:R 1 99\n:R 7 12 9\n:S 2 女性\n.\n")))
	_check(jb.job_name(1) == "騎士", "jb: 職業名の上書き")
	_check(jb.job_name(2) == "僧侶", "jb: 標準名")
	_check(jb.job_rate(1, 0) == 15, "jb: 率は上限 15 に丸め")
	_check(jb.job_rate(7, 0) == 12 and jb.job_rate(7, 1) == 7,
			"jb: 賢者は2スロット (2つ目は上限 7)")
	_check(jb.sex_name(2) == "女性", "jb: 性別名の上書き")
	_check(jb.sex_name(1) == "男", "jb: 性別標準名")
	var jbytes := Cp932.encode(":N 01 戦士\n:R 02 20\n.\n")
	var jb2 := PhiJb.parse(PhiRawLines.from_bytes(jbytes))
	_check(jb2.serialize() == jbytes, "jb: 無編集往復")
	# --- PhiPt ---
	var pt := PhiPt.parse(PhiRawLines.from_bytes(Cp932.encode(
			":P fairy heal_pct 20\n:P 2 heal_cost 7\n:P all mp_max 300\n")))
	_check(pt.value("fairy", "heal_pct") == 20, "pt: 上書き")
	_check(pt.value("fairy", "mag_pct") == 70, "pt: 標準値 (妖精 mag_pct)")
	_check(pt.value("cat", "heal_cost") == 7, "pt: 番号トークンの種類")
	_check(pt.value("bird", "sup_int") == 5, "pt: 標準値 (鳥 sup_int)")
	_check(pt.global_value("mp_max") == 300, "pt: 共通の上書き")
	_check(pt.global_value("regen_in") == 1, "pt: 共通の標準値")
	var pbytes := Cp932.encode(":P dog phys_rate 35\n")
	var pt2 := PhiPt.parse(PhiRawLines.from_bytes(pbytes))
	_check(pt2.serialize() == pbytes, "pt: 無編集往復")
	pt2.touch(pt2.records[0])
	_check(pt2.serialize() == pbytes, "pt: 編集往復")
	print("test_stage22_neo: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)

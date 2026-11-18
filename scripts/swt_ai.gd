class_name SwtAi
extends RefCounted
## スイッチの AI サポート (第7段)。
## 「AIに頼む」: 世界の文脈 + :S 書式 + 実例をまとめた依頼文を作る。
## 「AIから取り込む」: 返ってきた :S 行を検証 (パース往復・範囲) して
## からだけ phi.swt に追加する。

const GRAMMAR := """
■ :S 行の書式
:S XXX YYY CC <条件パラメータ> AAA BBB DD <動作パラメータ>
- XXX YYY = スイッチの設置位置 (3桁ずつ)。AAA BBB = 動作位置 (3桁ずつ)
- CC = 条件の種類 (2桁)、DD = 動作の種類 (2桁)
- パラメータは条件・動作の種類ごとに決まった個数の「アトム」を
  空白区切りで並べる。文字列は " で囲む。アイテムデータは
  "名前(31バイトに空白詰め) type2桁 wp fn op op op op" の形の1アトム
- 1行に1スイッチ。行頭は必ず :S、行末に余分な空白を付けない

■ 実例 (実在の世界データから)
:S 003 013 03 "GO" 003 013 06
  … (003,013) で「GO」と言ったら (003,013) へテレポート
:S 246 126 06 00 0000 246 126 13 1
  … (246,126) で能力00が0000以上 (無音) ならゲート転送 1
:S 103 012 05 0010 103 012 04 "Turotial sword       0212 10 n 12 00 00 00"
  … (103,012) で 0010 GP 支払ったらアイテムを生成
"""


static func _table(names: Dictionary, title: String) -> String:
	var keys := names.keys()
	keys.sort()
	var parts: Array[String] = [title]
	for k in keys:
		parts.append("%02d %s" % [int(k), String(names[k])])
	return "\n".join(parts)


static func build_context(project: WorldProject) -> String:
	var out: Array[String] = []
	out.append("あなたは PHIDM (オンライン RPG) の世界データ phi.swt の"
			+ "スイッチを書く助手です。以下の文脈と書式に従い、"
			+ "依頼された仕掛けを :S 行だけで返してください。"
			+ "説明文は最小限にし、:S 行はコードブロックに1行ずつ書いてください。")
	var wname := ""
	if project.td != null:
		wname = String(project.td.find_record("N").get("fields", {})
				.get("name", ""))
	out.append("\n■ 世界: %s (マップ %d x %d)" % [wname,
			project.map_size.x, project.map_size.y])
	if project.fd != null:
		var areas: Array[String] = []
		for code in project.fd.used_codes():
			var ei := project.fd.find_e(code)
			if ei >= 0:
				areas.append("%02x %s" % [code, String(
						project.fd.records[ei]["fields"]["name"])])
			if areas.size() >= 40:
				break
		if not areas.is_empty():
			out.append("■ エリア: " + " / ".join(areas))
	if project.od != null:
		var objs: Array[String] = []
		for rec in project.od.records:
			var f: Dictionary = rec["fields"]
			if int(f.get("x", -1)) >= 0:
				objs.append("%s (%d,%d)" % [String(f.get("gname", "")),
						int(f["x"]), int(f["y"])])
			if objs.size() >= 60:
				break
		if not objs.is_empty():
			out.append("■ オブジェクト: " + " / ".join(objs))
	if project.ed != null:
		var enes: Array[String] = []
		for b in project.ed.blocks():
			var f: Dictionary = project.ed.records[int(b["header"])]["fields"]
			enes.append("%s (出現 %s,%s)" % [String(f.get("name", "")),
					String(f.get("ix", "")), String(f.get("iy", ""))])
			if enes.size() >= 40:
				break
		if not enes.is_empty():
			out.append("■ エネミー: " + " / ".join(enes))
	out.append(GRAMMAR)
	out.append(_table(HelpTexts.CC_NAMES, "■ 条件 (CC) の種類"))
	out.append(_table(HelpTexts.DD_NAMES, "■ 動作 (DD) の種類"))
	if project.swt != null:
		var ex: Array[String] = []
		for i in project.swt.records.size():
			var rec := project.swt.records[i]
			if String(rec["kind"]) == "S":
				ex.append(project.swt.raw_lines.line_text(i))
			if ex.size() >= 30:
				break
		if not ex.is_empty():
			out.append("■ 既存のスイッチ (重複を避け、書き方の参考に):\n"
					+ "\n".join(ex))
	out.append("\n■ 作りたい仕掛け:\n(ここに作りたい仕掛けを書いてください)")
	return "\n".join(out)


## 取り込み検証。戻り値: {"ok": Array[Dictionary], "errors": Array[String]}
static func validate_lines(text: String, map_size: Vector2i) -> Dictionary:
	var ok: Array = []
	var errors: Array[String] = []
	# 貼り付け文は Unicode。CP932 に直してから行として解釈する
	# (CP932 で表せない文字は往復で崩れるため自動的に弾かれる)
	var stripped: Array[String] = []
	for ln in text.split("\n"):
		stripped.append(ln.strip_edges())
	var raw := PhiRawLines.from_bytes(Cp932.encode("\n".join(stripped)))
	var parsed := PhiSwt.parse(raw)
	for i in parsed.records.size():
		var line := raw.line_text(i)
		if line == "" or line.begins_with("#") or line.begins_with("```"):
			continue
		var rec := parsed.records[i]
		if not line.begins_with(":S"):
			errors.append("「%s」: :S 行だけ取り込めます" % line.substr(0, 40))
			continue
		if String(rec["kind"]) != "S":
			errors.append("「%s」: 書式を解釈できません" % line.substr(0, 40))
			continue
		if PhiSwt.build_line(rec) != line:
			errors.append("「%s」: 正規形に直すと変わってしまうため取り込めません"
					% line.substr(0, 40))
			continue
		var f: Dictionary = rec["fields"]
		var cc := int(f.get("cc", -1))
		var dd := int(f.get("dd", -1))
		if not HelpTexts.CC_NAMES.has(cc):
			errors.append("「%s」: 条件 %02d は未定義です"
					% [line.substr(0, 40), cc])
			continue
		if not HelpTexts.DD_NAMES.has(dd):
			errors.append("「%s」: 動作 %02d は未定義です"
					% [line.substr(0, 40), dd])
			continue
		if map_size.x > 0:
			var bad := false
			for key in ["sx", "sy", "ax", "ay"]:
				var lim := map_size.x if key in ["sx", "ax"] else map_size.y
				if int(f.get(key, 0)) < 0 or int(f.get(key, 0)) >= lim:
					errors.append("「%s」: 座標 %s=%d がマップ範囲外です"
							% [line.substr(0, 40), key, int(f.get(key, 0))])
					bad = true
					break
			if bad:
				continue
		ok.append(rec)
	return {"ok": ok, "errors": errors}

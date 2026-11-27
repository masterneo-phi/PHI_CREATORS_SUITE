class_name PhiPt
extends RefCounted
## phi.pt (ペット調整) のモデル。PHIDM_NEO 拡張 (phi_class.cpp
## pet_pt_load)。ファイルが無くてもペットは標準値で動くため、この
## ファイルは調整のためだけに置く。
##   :P <種類> <項目> <値>
##   種類は fairy / cat / dog / bird (番号 1〜4 でも可)。共通項目
##   (mp_max / st_max / regen_out / regen_in) は種類 all。
## 未編集行は PhiRawLines がバイトを保証する。

var raw_lines: PhiRawLines
var records: Array[Dictionary] = []

const TYPES: Array[String] = ["fairy", "cat", "dog", "bird"]
const TYPE_NAMES := {"fairy": "妖精 (万能型)", "cat": "猫 (回復メイン)",
		"dog": "犬 (物理攻撃メイン)", "bird": "鳥 (魔法攻撃メイン)"}
## 共通項目 [key, 表示名, 標準, 下限, 上限]
const GLOBALS: Array = [
	["mp_max", "MP 最大", 100, 1, 100000],
	["st_max", "体力最大", 100, 1, 100000],
	["regen_out", "回復量/秒 (戦闘外)", 3, 0, 1000],
	["regen_in", "回復量/秒 (戦闘中)", 1, 0, 1000],
]
## 種類別項目 [key, 表示名, 下限, 上限] (標準値は DEFAULTS)
const KEYS: Array = [
	["heal_pct", "回復量 (主人最大HPの%)", 0, 25],
	["heal_thr", "回復する主人HP (%) 以下", 0, 99],
	["heal_cost", "回復1回の MP 消費", 0, 1000],
	["emg_thr", "緊急回復の発動HP (%)", 0, 99],
	["emg_cost", "緊急回復の MP 消費", 0, 1000],
	["emg_cd", "緊急回復の再使用間隔 (秒)", 0, 3600],
	["phys_rate", "物理追撃の確率 (%)", 0, 50],
	["phys_pct", "物理追撃の威力 (%)", 0, 100],
	["phys_cost", "追撃1回の体力消費", 0, 1000],
	["mag_rate", "魔法追撃の確率 (%)", 0, 50],
	["mag_pct", "魔法追撃の威力 (%)", 0, 100],
	["mag_cost", "追撃1回の MP 消費", 0, 1000],
	["sup_rate", "支援詠唱の確率 (%/間隔)", 0, 50],
	["sup_pct", "支援の量 (%)", 0, 100],
	["sup_cost", "支援1回の MP 消費", 0, 1000],
	["sup_int", "支援の間隔 (秒)", 0, 3600],
]
## サーバ標準値 (pet_cfg_defaults)。書かれていない項目は 0
const DEFAULTS := {
	"fairy": {"heal_pct": 5, "heal_thr": 60, "heal_cost": 15,
			"phys_rate": 20, "phys_pct": 35, "phys_cost": 10,
			"mag_rate": 20, "mag_pct": 70, "mag_cost": 12},
	"cat": {"heal_pct": 10, "heal_thr": 50, "heal_cost": 20,
			"emg_thr": 25, "emg_cost": 30, "emg_cd": 10,
			"mag_rate": 15, "mag_pct": 50, "mag_cost": 12},
	"dog": {"phys_rate": 35, "phys_pct": 50, "phys_cost": 10},
	"bird": {"mag_rate": 35, "mag_pct": 100, "mag_cost": 12,
			"sup_rate": 50, "sup_pct": 50, "sup_cost": 15, "sup_int": 5},
}


static func parse(raw: PhiRawLines) -> PhiPt:
	var pt := PhiPt.new()
	pt.raw_lines = raw
	for i in raw.line_count():
		pt.records.append(_parse_line(raw.line_text(i)))
	return pt


static func load_file(path: String) -> PhiPt:
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
	if line.begins_with(":P "):
		var parts := line.substr(3).split(" ", false)
		if parts.size() >= 3 and String(parts[2]).is_valid_int():
			return {"kind": "P", "fields": {"type": String(parts[0]),
					"key": String(parts[1]),
					"value": String(parts[2]).to_int()}, "modified": false}
	return {"kind": "raw", "fields": {}, "modified": false}


static func build_line(rec: Dictionary) -> String:
	var f: Dictionary = rec.get("fields", {})
	if String(rec["kind"]) == "P":
		return ":P %s %s %d" % [String(f["type"]), String(f["key"]),
				int(f["value"])]
	return ""


## 種類トークンを正規形 (fairy/cat/dog/bird/all) に直す。無効なら ""
static func norm_type(tok: String) -> String:
	if tok == "all" or tok == "0":
		return "all"
	if tok in TYPES:
		return tok
	if tok.is_valid_int():
		var n := tok.to_int()
		if n >= 1 and n <= 4:
			return TYPES[n - 1]
	return ""


## 上書きを適用した実効値 (種類別項目)
func value(type_id: String, key: String) -> int:
	var v := int((DEFAULTS.get(type_id, {}) as Dictionary).get(key, 0))
	for rec in records:
		if String(rec["kind"]) == "P":
			var f: Dictionary = rec["fields"]
			if norm_type(String(f["type"])) == type_id \
					and String(f["key"]) == key:
				v = int(f["value"])
	return v


## 上書きを適用した実効値 (共通項目)
func global_value(key: String) -> int:
	var v := 0
	for g in GLOBALS:
		if String(g[0]) == key:
			v = int(g[2])
	for rec in records:
		if String(rec["kind"]) == "P":
			var f: Dictionary = rec["fields"]
			if norm_type(String(f["type"])) == "all" \
					and String(f["key"]) == key:
				v = int(f["value"])
	return v


## 指定の種類・項目のレコード番号 (無ければ -1)
func find_record(type_id: String, key: String) -> int:
	for i in records.size():
		if String(records[i]["kind"]) == "P":
			var f: Dictionary = records[i]["fields"]
			if norm_type(String(f["type"])) == type_id \
					and String(f["key"]) == key:
				return i
	return -1

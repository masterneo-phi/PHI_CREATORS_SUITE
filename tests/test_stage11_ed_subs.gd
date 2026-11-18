extends SceneTree
## 第11段: エネミーのグラ欄とサブレコード分解 (ITEM/SPELL/OPTIONS 等)

var _failures := 0
var _checks := 0


func check(cond: bool, label: String) -> void:
	_checks += 1
	if cond:
		print("ok: ", label)
	else:
		_failures += 1
		printerr("FAIL: ", label)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	Cp932.ensure_loaded()
	var Ed := load("res://scripts/ed_editor.gd")
	# --- ITEM DATA 分解と再構築 (実データ形式) ---
	var item: Dictionary = Ed.parse_item_data(
			"Fang                            0f82 20 n 04 00 00 00")
	check(not item.is_empty(), "アイテムを分解できる")
	check(String(item["name"]) == "Fang", "アイテム名")
	check(String(item["type"]) == "0f82", "タイプ 0f82")
	check(Ed.build_item_data(item) ==
			"Fang                            0f82 20 n 04 00 00 00",
			"アイテム再構築が正規形と一致")
	var item2: Dictionary = Ed.parse_item_data(
			"Blade of Burn                   0322 07 f 10 00 00 00 -")
	check(bool(item2["drop"]), "落すだけマーカーを分解できる")
	check(Ed.build_item_data(item2).ends_with("00 -"),
			"落すだけマーカーを再構築できる")
	# --- SPELL DATA ---
	var spell: Dictionary = Ed.parse_spell_data(
			"Shine                           01 s")
	check(not spell.is_empty(), "魔法を分解できる")
	check(String(spell["name"]) == "Shine" and String(spell["fn"]) == "s",
			"魔法名と属性")
	check(Ed.build_spell_data(spell) ==
			"Shine                           01 s", "魔法再構築が一致")
	# --- :O オプション (未知文字の保持) ---
	var opt: Dictionary = Ed.parse_options("H00002 X B")
	check(int(opt["h"]) == 2 and bool(opt["b"]), "オプション分解")
	check(Ed.build_options(opt) == "H00002 B X", "未知文字を保持して再構築")
	# --- エディタ: グラ欄と :G 追加 ---
	var gra_dir := ProjectSettings.globalize_path("res://tests/fixtures/gra")
	var cfg := ConfigFile.new()
	cfg.load("user://creators.cfg")
	cfg.set_value("od", "gra_root", gra_dir)
	cfg.save("user://creators.cfg")
	var project := WorldProject.new()
	check(project.open("res://tests/fixtures/realworld"), "world を開ける")
	var editor = Ed.new()
	root.add_child(editor)
	editor.setup(project)
	await process_frame
	editor.call("_on_enemy_selected", 0)
	await process_frame
	check(String(editor.call("_enemy_graphic")) == "bm_gnome",
			"既存の :G を読める")
	# 実世界の敵は全員 :G 持ちなので、敵を追加してグラを設定する
	editor.call("_add_enemy")
	var no_g: int = project.ed.blocks().size() - 1
	editor.call("_on_enemy_selected", no_g)
	check(String(editor.call("_enemy_graphic")) == "",
			"追加した敵は :G 無し")
	if no_g >= 0:
		editor.call("_set_enemy_graphic", "elb_p02")
		check(String(editor.call("_enemy_graphic")) == "elb_p02",
				":G を新規追加できる")
		var sheet: TextureRect = editor.get("_sheet_rect")
		check(sheet != null and sheet.texture != null,
				"敵グラの全体が表示される")
		var frame: TextureRect = editor.get("_frame_rect")
		check(frame != null and frame.texture != null,
				"敵グラの向きフレームが表示される")
	# --- サブレコード分解 UI が開ける (:I を持つ敵) ---
	var found_i := false
	for bi in project.ed.blocks().size():
		editor.call("_on_enemy_selected", bi)
		var subs: Array = editor.get("_sub_indices")
		for si in subs.size():
			var rec: Dictionary = project.ed.records[int(subs[si])]
			if String(rec["kind"]) == "sub" and \
					String(rec["fields"].get("letter", "")) == "I":
				editor.call("_show_sub", int(subs[si]))
				found_i = true
				break
		if found_i:
			break
	await process_frame
	check(found_i, ":I サブの分解エディタを開ける")
	print("checks: %d, failures: %d" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)

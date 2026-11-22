class_name HelpTexts
extends RefCounted
## エディタの表示名・解説データ。根拠は FORMAT_SPEC (コードと
## DM ドキュメント phitd.man / phiswt.man 等の突き合わせ)。

const CC_NAMES := {
	0: "条件なし", 1: "能力が以上", 2: "離れた", 3: "言った",
	4: "アイテムを置いた", 5: "支払った", 6: "能力が以上 (無音)",
	7: "NPC が言った", 8: "アイテムを所持", 9: "置かれた物の重量",
	10: "フラグが ON", 11: "能力が未満", 12: "フラグが ON (位置つき)",
	13: "発言がパターン一致", 14: "魔法を唱えた", 15: "向いた",
	16: "能力が未満 (無音)", 17: "攻撃した", 18: "アイテムを拾った",
	20: "変数の比較", 21: "敵を倒した", 22: "PK した", 23: "復活した",
	24: "死んだ", 25: "能力と HP/MP", 30: "オブジェクトが置かれた",
	31: "オブジェクトが除かれた",
}

const DD_NAMES := {
	1: "地形を変更", 2: "何もしない", 3: "喋る", 4: "アイテムを生成",
	5: "GP を生成", 6: "テレポート", 7: "クリーチャーを出現",
	8: "キャラを変更", 9: "メッセージ連鎖 (凍結)", 10: "フラグを変更",
	11: "地形を一括変更", 12: "グラフィックを初期化", 13: "ゲート転送",
	14: "アイテムを生成 (無音)", 15: "グラフィックを設定",
	16: "範囲メッセージ", 17: "巨大化 / 縮小", 18: "状態を設定",
	19: "メッセージ連鎖", 20: "フラグを確率で変更",
	21: "オブジェクトを移動", 22: "オブジェクトを除去",
	23: "見た目を変更", 24: "見た目を除去", 25: "show を実行",
	26: "相対テレポート", 29: "メニューを開く", 30: "コールビーコン",
	31: "殺す (罠)", 33: "コマンドを実行", 44: "アイテムを生成 (自分の位置)",
	45: "GP を生成 (自分の位置)", 50: "式・代入", 90: "ログに記録",
	# PHIDM_NEO 独自拡張 (60〜62) と演出 (FX、63〜68)。
	# 69 は演出系の予約番号 (サーバ未実装のため登録しない)。
	60: "刻印を記録", 61: "刻印を表示", 62: "プログラムを実行",
	63: "マップ文字を表示", 64: "暗転", 65: "ワイプ", 66: "画像を表示",
	67: "画面振動", 68: "放射発光",
}

## :U の2文字コード定義。
## kind: "pair" = on/off の2コード / "flag" = あれば ON /
##       "int" = コード+数字1桁 / "choice" = 値ごとのコード列
## on/off: そのコード文字列。default: サーバ既定の状態キー。
const U_DEFS: Array[Dictionary] = [
	{"key": "auto_equip", "kind": "pair", "on": "AO", "off": "AX", "default": "on",
		"label": "アクセス時 自動装備", "help": "ログイン時に装備を自動で整える"},
	{"key": "access_dm_main", "kind": "flag", "on": "AD", "default": "off",
		"label": "アクセス DM をメインエリア限定", "help": "アクセス時の DM メッセージをメインエリア放送に限定する"},
	{"key": "axe_blade", "kind": "pair", "on": "ABO", "off": "ABX", "default": "off",
		"label": "斧・刃のダメージ補正", "help": "斧と刃のダメージ計算に補正を入れる"},
	{"key": "burst_to_caster", "kind": "flag", "on": "BX", "default": "off",
		"label": "バースト被害は術者のみ表示", "help": "魔法暴走の被害メッセージを術者にだけ見せる"},
	{"key": "charge_time", "kind": "flag", "on": "CT", "default": "off",
		"label": "チャージ再使用の待ち時間", "help": "チャージアイテムに再使用までの待ち時間をつける"},
	{"key": "charge_degrade", "kind": "flag", "on": "CD", "default": "off",
		"label": "チャージ使用で劣化", "help": "チャージアイテムの使用で劣化が進む"},
	{"key": "destroy_notice", "kind": "flag", "on": "DC", "default": "off",
		"label": "destroy を周囲に通知", "help": "破壊コマンドの対象を周囲のキャラにも知らせる"},
	{"key": "beginner", "kind": "pair", "on": "DSO", "off": "DSX", "default": "off",
		"label": "初心者保護", "help": "初心者への死亡ペナルティを軽くする"},
	{"key": "limitter", "kind": "pair", "on": "DTO", "off": "DTX", "default": "off",
		"label": "死亡ペナルティ・リミッタ", "help": "死亡ペナルティに上限を設ける"},
	{"key": "magic_degrade", "kind": "flag", "on": "DM", "default": "off",
		"label": "魔法ダメージでも装備劣化", "help": "魔法によるダメージでも装備が劣化する"},
	{"key": "beast_wall", "kind": "pair", "on": "EB", "off": "EX", "default": "on",
		"label": "知的生物バリアは獣にも壁", "help": "ON で獣もバリアを通れない。OFF で獣は通れる"},
	{"key": "mhp_up", "kind": "flag", "on": "HU", "default": "off",
		"label": "物理攻撃で最大 HP 上昇", "help": "物理攻撃を当てると最大 HP が乱数で上がることがある"},
	{"key": "slow_degrade", "kind": "flag", "on": "IS", "default": "off",
		"label": "劣化が緩やか", "help": "劣化の頻度が 4 倍・効果が 1/4 になる"},
	{"key": "kill_master", "kind": "flag", "on": "KM", "default": "off",
		"label": "マスター戦闘も通常扱い", "help": "マスターとの戦闘でも LV・カルマ変動と落下がある"},
	{"key": "limit_mrp", "kind": "flag", "on": "LM", "default": "off",
		"label": "MRP 上昇を確率化", "help": "防具+Resource Create の MRP 上昇が確率で決まる"},
	{"key": "cast_time_name", "kind": "flag", "on": "MT", "default": "off",
		"label": "魔法名詠唱も時間が必要", "help": "名前で唱えても番号詠唱と同じ詠唱時間がかかる"},
	{"key": "see_magic", "kind": "pair", "on": "MS", "off": "MX", "default": "off",
		"label": "魔法の可視化", "help": "魔法の効果を目に見える形で表示する"},
	{"key": "magic_anti_degrade", "kind": "flag", "on": "MD", "default": "off",
		"label": "強化魔法で劣化を軽減", "help": "強化魔法で装備の劣化を軽くできる"},
	{"key": "mmp_up", "kind": "flag", "on": "MU", "default": "off",
		"label": "魔法攻撃で最大 MP 上昇", "help": "魔法攻撃を当てると最大 MP が乱数で上がることがある"},
	{"key": "power_add", "kind": "flag", "on": "PA", "default": "off",
		"label": "パワースペルを加算方式に", "help": "パワースペルの効果変化が乗算でなく加算になる"},
	{"key": "deny_pk", "kind": "flag", "on": "PKX", "default": "off",
		"label": "PK 禁止", "help": "プレイヤーキルを禁止する"},
	{"key": "single_use", "kind": "flag", "on": "SU", "default": "off",
		"label": "use は1つずつ", "help": "use で複数アイテムを同時に指定できない"},
	{"key": "spellup_time", "kind": "flag", "on": "ST", "default": "off",
		"label": "SpellUp は持続時間のみ2倍", "help": "SpellUp の効果を時間だけに限定する"},
	{"key": "save_condition", "kind": "flag", "on": "SC", "default": "off",
		"label": "キャラの状態を保存", "help": "状態異常などをセーブデータに残す"},
	{"key": "save_flags", "kind": "flag", "on": "SV", "default": "off",
		"label": "フラグ・変数を保存", "help": "sn フラグと zn 変数を phi.sav に保存する"},
	{"key": "sys_no_degrade", "kind": "flag", "on": "SD", "default": "off",
		"label": "システム魔法で劣化なし", "help": "システム魔法では武器が劣化しない"},
	{"key": "npc_charge", "kind": "flag", "on": "UO", "default": "off",
		"label": "NPC がチャージ品を使用可", "help": "NPC もチャージアイテムを使える"},
	{"key": "gift_tax", "kind": "flag", "on": "TG", "default": "off",
		"label": "pay の税を贈与税に", "help": "受取人は全額を受け取り、支払人が税込みで払う"},
	{"key": "offline_exp", "kind": "flag", "on": "OE", "default": "off",
		"label": "オフライン時間も経験値", "help": "接続していない時間も経験値に数える"},
	{"key": "psp_center", "kind": "flag", "on": "7C", "default": "off",
		"label": "7x7 回転マップを画面中央に", "help": "回転マップでのキャラ位置を PSP 互換 (中央) にする"},
	{"key": "only_55", "kind": "flag", "on": "7X", "default": "off",
		"label": "マップサイズを 5x5 に制限", "help": "クライアントの表示を 5x5 のみに制限する"},
]

## 数字つきコード (コード+1桁)。min/max/default はサーバ既定
const U_INT_DEFS: Array[Dictionary] = [
	{"key": "attack_effect", "prefix": "AE", "min": 0, "max": 2, "default": 0,
		"label": "攻撃効果の計算式", "help": "攻撃効果の新計算式の種類 (0=従来)"},
	{"key": "counter_effect", "prefix": "CE", "min": 0, "max": 9, "default": 1,
		"label": "カウンター効果 1/n", "help": "カウンターの効果を 1/n にする。0 で無効"},
	{"key": "death_penalty", "prefix": "DP", "min": 0, "max": 3, "default": 0,
		"label": "死亡ペナルティ段階", "help": "0=全部あり、1=LVダウンなし、2=+アイテム落下なし、3=+死亡税なし"},
	{"key": "multi_access", "prefix": "MA", "min": 0, "max": 9, "default": 0,
		"label": "同一 IP の最大同時接続", "help": "0 は制限なし"},
]

## 選択式コード (値→コード文字列。"" はコード自体を書かない)
const U_CHOICE_DEFS: Array[Dictionary] = [
	{"key": "penalty_rate", "default": "10",
		"options": {"10": "", "1": "DR1", "2": "DR2", "3": "DR3", "5": "DR5"},
		"label": "死亡ペナルティ率 (%)", "help": "ペナルティの割合。既定は 10%"},
	{"key": "rebirth_life", "default": "0",
		"options": {"0": "", "1": "DL1", "2": "DL2"},
		"label": "死亡後の再接続時 HP/MP", "help": "0=最大まで回復、1=1、2=最大の半分"},
	{"key": "wiz_eye", "default": "WL",
		"options": {"WL": "WL", "WE": "WE"},
		"label": "アクセス時の視界魔法", "help": "WL=Wizard Light、WE=Wizard Eye"},
	{"key": "fighter_wizard", "default": "0",
		"options": {"0": "", "-1": "FWX", "1": "FW0"},
		"label": "戦士と魔法使いの併用", "help": "0=併用可。Coat と SpellUp の相互作用を切り替える"},
	{"key": "spell_learning", "default": "0",
		"options": {"0": "", "1": "SLD", "2": "SLN"},
		"label": "魔法の学習制限", "help": "0=無制限、1=全面禁止、2=NPC からのみ可"},
	{"key": "turn_permission", "default": "",
		"options": {"": "", "7T": "7T", "7S": "7S", "7W": "7W"},
		"label": "回転マップの許可 (7T/7S/7W)", "help": "値の詳細な意味はドキュメントになく不明"},
]

## マップの高さ (起伏) の注意書き。phi.dd の見た目文字 (2バイト目) に
## 印として書く: '1' = +1段 / '2' = +2段 / '3' = +3段 / '9' = −1段 (窪地)。
const HEIGHT_NOTE := "高さは phi.dd の見た目文字 (2バイト目) に印として書かれます。" \
		+ "屋根 ('~') とは同じ1文字の場所を取り合うため、屋根のあるマスに高さを塗ると印が優先され、屋根は外れます。" \
		+ "高さを消すと、その地形の正規の見た目文字に戻ります。" \
		+ "高さが表示されるのは PHIDM_NEO と NeoPHI の組み合わせで、旧クライアントでは印の文字が代替表示に落ちます" \
		+ " (地形の性質や通行の判定は変わりません)。"

static func cc_name(cc: int) -> String:
	return String(CC_NAMES.get(cc, "不明な条件"))


static func dd_name(dd: int) -> String:
	return String(DD_NAMES.get(dd, "不明な動作"))

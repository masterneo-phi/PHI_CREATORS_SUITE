class_name CreatorsVersion
extends RefCounted
## バージョン情報 (About 表示用)。

const VERSION := "0.6.0"
const AUTHOR := "Master NEO"
const APP_NAME := "PHI CREATORS SUITE"


static func about_text() -> String:
	return "%s\nバージョン %s\n作者 %s\nGodot %s" % [
		APP_NAME, VERSION, AUTHOR,
		str(Engine.get_version_info()["string"])]

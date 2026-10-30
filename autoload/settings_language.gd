class_name SettingsLanguage
extends RefCounted
## Which of the game's languages is in use (PlayerSettings): the player's choice, else the
## system's.


## The language in use: the player's, else the system's when the game has it, else English.
static func code() -> String:
	if codes().has(PlayerSettings.language):
		return PlayerSettings.language
	var system := OS.get_locale()
	for each: String in codes():
		# Any Chinese system gets Simplified Chinese, the only Chinese the game has.
		var base := each.get_slice("_", 0)
		if system == each or system.get_slice("_", 0) == base:
			return each
	return "en"


## The name of the language in use, as its own speakers write it.
static func shown_name() -> String:
	return str(PlayerSettings.LANGUAGES[codes().find(code())][1])


static func codes() -> Array[String]:
	var out: Array[String] = []
	for row: Array in PlayerSettings.LANGUAGES:
		out.append(str(row[0]))
	return out

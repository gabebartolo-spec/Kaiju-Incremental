class_name CjkFont
## Our faces draw Latin and Cyrillic; Chinese falls back to the Noto Sans SC subset (D-392,
## tools/fonts/subset_cjk.py). Loaded fonts are shared, so one fallback reaches every label. It is
## attached only under Chinese: a font's height is the tallest of its fallbacks, so it would grow
## every line in the other languages.

const FONTS: Array[String] = [
	"res://assets/fonts/kaiju_block.ttf",
	"res://assets/fonts/kaiju_claw.ttf",
	"res://assets/fonts/kaiju_rubble.ttf",
	"res://assets/fonts/kaiju_fault.ttf",
]
const PATH := "res://assets/fonts/kaiju_cjk.ttf"
const LOCALE := "zh_CN"


## Adds the fallback to every face under Chinese and removes it otherwise.
static func attach(locale: String) -> void:
	var cjk: Font = load(PATH)
	for path in FONTS:
		var font: Font = load(path)
		var list := font.fallbacks
		list.erase(cjk)
		if locale == LOCALE:
			list.append(cjk)
		font.fallbacks = list

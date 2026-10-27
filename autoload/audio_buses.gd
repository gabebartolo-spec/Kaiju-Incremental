class_name AudioBuses
extends RefCounted
## The mixer (R 8.1, docs/research/2026-10-21/08-soundscape.md), built at boot from tuning
## "audio" and "sfx" "dynamics" so no dB or ms lives in a hand-tuned .tres. Presentation only.
## Layout (a bus sends only to one on its left):
##   Master (hard limiter) > SFX (the player's volume, gentle compressor) > Hero (roar, toppling
##   tower, barrel blasts) | Bed (ducked by Hero) > Debris, Crowd, Military, Ambience | UI;
##   Music beside SFX, ducked a little by Hero. Hero is the loudest thing in the mix, so the
##   chaos under it dips while it sounds and swells back over the duck's release. Stomps and
##   footsteps play on SFX itself: they duck nothing (director 2026-10-27).


## Builds every bus in order, its send and its sidechain duck, and the limiter and compressor.
## Safe to call again: a bus or an effect that exists is left as it is.
static func apply() -> void:
	var cfg: Dictionary = Content.section("audio")
	var ducks: Dictionary = cfg["ducks"]
	for def: Dictionary in cfg["buses"]:
		var at := PlayerSettings.bus(str(def["name"]))
		AudioServer.set_bus_send(at, str(def["send"]))
		if def.has("duck") and not _has_effect(at, AudioEffectCompressor):
			var duck: Dictionary = ducks[def["duck"]]
			AudioServer.add_bus_effect(at, _duck(duck))
	_dynamics()


## The bus a sound plays on (tuning "audio" "sounds"); SFX for one the table does not list.
static func of(sound: String) -> StringName:
	var sounds: Dictionary = Content.section("audio")["sounds"]
	return StringName(str(sounds.get(sound, "SFX")))


static func _duck(cfg: Dictionary) -> AudioEffectCompressor:
	var duck := AudioEffectCompressor.new()
	duck.sidechain = StringName(str(cfg["sidechain"]))
	duck.threshold = Num.f(cfg["threshold_db"])
	duck.ratio = Num.f(cfg["ratio"])
	duck.attack_us = Num.f(cfg["attack_us"])
	duck.release_ms = Num.f(cfg["release_ms"])
	duck.mix = Num.f(cfg["mix"])
	return duck


## Keeps the loudest moments clean (tuning "sfx" "dynamics"): a gentle compressor on SFX
## evens out a stack of big sounds, and a hard limiter on Master holds the peak under the
## ceiling, so breath + collapses + tanks never clip. Added once, at the end of each chain.
static func _dynamics() -> void:
	var cfg: Dictionary = Content.section("sfx")["dynamics"]
	var sfx_bus := PlayerSettings.bus("SFX")
	if not _has_effect(sfx_bus, AudioEffectCompressor):
		var comp := AudioEffectCompressor.new()
		comp.threshold = Num.f(cfg["threshold_db"])
		comp.ratio = Num.f(cfg["ratio"])
		comp.attack_us = Num.f(cfg["attack_us"])
		comp.release_ms = Num.f(cfg["release_ms"])
		AudioServer.add_bus_effect(sfx_bus, comp)
	if not _has_effect(0, AudioEffectHardLimiter):
		var limiter := AudioEffectHardLimiter.new()
		limiter.ceiling_db = Num.f(cfg["ceiling_db"])
		limiter.release = Num.f(cfg["limiter_release"])
		AudioServer.add_bus_effect(0, limiter)


static func _has_effect(at: int, kind: Variant) -> bool:
	for i: int in AudioServer.get_bus_effect_count(at):
		if is_instance_of(AudioServer.get_bus_effect(at, i), kind):
			return true
	return false

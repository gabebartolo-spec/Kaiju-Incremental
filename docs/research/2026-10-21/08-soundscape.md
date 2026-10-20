# Soundscape for a city-destruction rampage, and how to build it in Godot 4.7

Researched 2026-10-21. Scope: layering, voice limits, ducking/HDR, distance and scale, crowd beds, debris, adaptive music, mix clarity, and the Godot 4 audio features that implement each. "Inference" marks my own reasoning where no source states it.

## Key findings

1. **The AAA answer to "mush" is HDR audio: only the loudest sounds of the moment get the output range.** DICE (Anders Clerwall, GDC 2009, Battlefield: Bad Company) mapped real-world loudness to a "sliding window" on the output. Clerwall's summary was "every sound is important, but not at the same time". Loud sounds pin the window's position while they play, and quieter sounds fall below it and drop out until the loud ones end. Numerically this works like a limiter that keeps the relative levels between sounds ([Designing Sound, HDR in Wwise](https://designingsound.org/2013/06/21/finding-your-way-with-high-dynamic-range-audio-in-wwise/); [Frostbite talk page](https://www.ea.com/frostbite/news/how-hdr-audio-makes-battlefield-bad-company-go-boom)). DICE described it as a run-time system that picks and balances the loudest sounds for each player ([MCV, DICE interview](https://mcvuk.com/?p=146207)). Some caveats:
   - Practitioners say the dB SPL tags end up far from real-world values.
   - Window movement that is too fast or too slow causes pumping.
   - The source advises starting from a normal mix and pushing only a few sounds above the threshold ([Designing Sound](https://designingsound.org/2013/06/21/finding-your-way-with-high-dynamic-range-audio-in-wwise/)).
   - One Battlefield 6 player complains that HDR sinks non-threat gunfire under the loudest gun. That is player opinion, not evidence ([EA forum](https://forums.ea.com/discussions/battlefield-6-general-discussion-en/mid-range-gunfire-collapse--occlusion-mismatch-50%E2%80%9380m/13631537)).
   - For us, the cheap version of HDR is a sidechain duck. The "hero" bus (roar, stomp, big collapse) pushes the bed bus down.

2. **Godot's compressor has a sidechain input, so it gives you ducking with no code.** `AudioEffectCompressor.sidechain` is "Audio bus to use for the volume threshold detection". Its parameters and ranges are:
   - threshold: -60 to 0 dB
   - ratio: 1 to 48
   - attack_us: 20 to 2000 µs
   - release_ms: 20 to 2000 ms
   - mix: 0 to 1

   The docs name ducking as the intended use ([Godot AudioEffectCompressor](https://docs.godotengine.org/en/stable/classes/class_audioeffectcompressor.html)). A sidechain listens to one bus, so every sound that should cause ducking has to be routed to a single "Hero" bus (inference from the single `sidechain` property). For the master, `AudioEffectHardLimiter` has `ceiling_db` (default -0.3, which guards against inter-sample peaks), `pre_gain_db` and `release` (0.01 to 3 s) ([Godot AudioEffectHardLimiter](https://docs.godotengine.org/en/stable/classes/class_audioeffecthardlimiter.html)).

3. **Destruction games classify each break into a few material × size × event buckets instead of one sound per piece.** Red Faction: Guerrilla (Volition, Kate Nelson) works like this:
   - Materials were collapsed to "steel" and "concrete".
   - Each sound is built from material + shape + size + event, for example "Steel + Sheet + Large + Impact".
   - Size is set at the moment of breaking from an energy value (mass and velocity) against per-material thresholds for small, medium and large.
   - Volume scales with velocity.
   - Event types are impact and roll.
   - The team decided how many destruction sounds may play at once, and voice limiting plus extra mixing were added after triggering worked.
   - Creaks and groans warn of a collapse before it happens.

   Source: [Designing Sound, Physics Audio part 1](https://designingsound.org/2010/04/01/audio-implementation-greats-6-physics-audio-part-1/). For us, the sim already knows chunk mass and velocity, so it can emit one sized "break" event per cluster rather than per voxel.

4. **Voice limits need a steal policy, and Godot's built-in one only steals the oldest sound.** In Wwise, a limit can discard the oldest or the newest instance, and a sound pushed out goes "virtual" (tracked but not mixed) rather than being killed. Wwise 2011.1 changed limiting so inaudible virtual voices no longer push out audible ones, and added a global cap on physical voices ([Audiokinetic Q&A on playback limit](https://audiokinetic.com/qa/2233/make-playback-limit-actually-play-only-instance-gloabally); [Wwise 2011.1 notes](https://www.audiokinetic.com/products/wwise/versions/2011-1)). One practitioner notes that killing the oldest rumble is masked by the new explosion's transient (same Q&A). Godot's `max_polyphony` (default 1) on AudioStreamPlayer and AudioStreamPlayer3D simply "cut[s] off the oldest sounds" ([Godot AudioStreamPlayer3D](https://docs.godotengine.org/en/stable/classes/class_audiostreamplayer3d.html); [Godot AudioStreamPlayer](https://docs.godotengine.org/en/stable/classes/class_audiostreamplayer.html)). Godot has no priority, quietest-steal or virtual voices. Those take a small pooled manager that we write ourselves. The bus docs give no fixed bus or effect limit ("only the hardware … will limit"), and silent buses switch themselves off automatically ([Godot audio buses](https://docs.godotengine.org/en/stable/tutorials/audio/audio_buses.html)).

5. **Randomising pitch and volume on pooled one-shots is built in.** `AudioStreamRandomizer` has these settings ([Godot AudioStreamRandomizer](https://docs.godotengine.org/en/stable/classes/class_audiostreamrandomizer.html)):
   - `random_pitch`: the maximum frequency multiplier, where 1.0 means no change.
   - `random_volume_offset_db`.
   - `playback_mode`: "Random no repeats" (the default), Random, or Sequential, with per-stream weights.

   One randomizer per material × size bucket, with a handful of samples each, covers the "300 slightly different impacts" problem without 300 files. I found no primary source describing "grain clustering" or a "rubble stream" in a shipped destruction game. The usual approach is to replace many voices with one loop whose level follows the event rate, plus a few capped spot one-shots. It mirrors the density-crossfade crowd technique in finding 7, but that is inference, not a sourced technique.

6. **Distance in Godot gives you volume falloff, a low-pass filter, Doppler and reverb zones. It does not delay sound by distance.** AudioStreamPlayer3D has these settings ([Godot AudioStreamPlayer3D](https://docs.godotengine.org/en/stable/classes/class_audiostreamplayer3d.html)):
   - `attenuation_model`: linear, squared, logarithmic or none.
   - `unit_size` (default 10) and `max_distance`.
   - `max_db` (default 3).
   - A built-in distance low-pass, `attenuation_filter_cutoff_hz` (default 5000; 20500 turns it off), with `attenuation_filter_db` (default -24).
   - `doppler_tracking`, `panning_strength`, and an emission cone.
   - `area_mask`, which picks which Area3D layers apply bus or reverb overrides.

   Area3D itself has `audio_bus_override`/`audio_bus_name` and `reverb_bus_enabled`/`reverb_bus_name`, plus `reverb_bus_amount` and `reverb_bus_uniformity` (each 0 to 1) ([Godot Area3D](https://docs.godotengine.org/en/stable/classes/class_area3d.html)). That is enough for a "street canyon" reverb zone. Speed-of-sound delay has to be scripted: distance divided by about 340 m/s, roughly 3 s per km ([Godot forum thread](https://forum.godotengine.org/t/how-do-i-make-every-single-node-simulate-the-speed-of-sound-with-delays/143645)). The evidence on whether it helps is mixed:
   - Developers warn that it can read as audio out of sync with the picture (same thread).
   - An Arma bug ticket reports explosions going silent after a speed-of-sound change ([Bohemia feedback T78801](https://feedback.bistudio.com/T78801)).
   - A commercial Unity asset sells exactly this effect for explosions ([Unity Asset Store, Mach 1](https://assetstore.unity.com/packages/tools/audio/mach-1-156589)).

   I found no first-party Battlefield or Just Cause source confirming that they use it.

7. **Crowd panic beds are built from density-tiered loops crossfaded by a nearby-population parameter.** CRI's tutorial uses separate low, medium and high density loops (about 2-4, 4-8 and 10+ people), crossfaded by a density parameter that can also drive a band-pass filter. Each loop starts at a random point and plays at most three instances ([CRIWARE crowd system](https://blog.criware.com/index.php/2023/05/08/crowd-system/)). The Witcher 3 split the area around the listener into four quadrants and counted the NPCs and their state (such as afraid) in each before sending that to Wwise ([Wwise Tour 2016, CD Projekt Red](https://www.audiokinetic.com/learn/videos/bv4LBbrmu0A)). Planet Coaster keeps the important characters in sync and audible and treats background figures with less precision ([Audiokinetic, Planet Coaster part 1](https://www.audiokinetic.com/en/blog/planet-coaster-part-1-crowd-management-using-data-to-generate-dynamic-crowd-audio)). For us, the sim already counts civilians by position. Four quadrant counts feeding three loops is the whole system.

8. **Adaptive music: Godot 4.3+ has both vertical layering and horizontal re-sequencing built in.** The 4.3 release added AudioStreamInteractive, AudioStreamSynchronized and AudioStreamPlaylist "to create complex, layered music and transitions" ([Godot 4.3 release](https://godotengine.org/releases/4.3/)).
   - **Vertical layering (stems):** AudioStreamSynchronized plays up to 32 streams in sync (`MAX_STREAMS`), with `set_sync_stream_volume(index, db)` per stem ([Godot AudioStreamSynchronized](https://docs.godotengine.org/en/stable/classes/class_audiostreamsynchronized.html)). The docs do not say whether changing a stem's volume mid-playback is smooth, so verify by test.
   - **Horizontal re-sequencing (sections):** AudioStreamInteractive holds named clips and a transition table. A transition can start immediately, on the next beat, on the next bar or at the clip end. The destination can start from the same position, from the start or from the previous position. Fades can be cross, in, out or automatic, with length set in beats. It also supports filler clips and auto-advance or return-to-hold ([Godot AudioStreamInteractive](https://docs.godotengine.org/en/stable/classes/class_audiostreaminteractive.html)). Code switches with `get_stream_playback().switch_to_clip_by_name(&"rampage")` on AudioStreamPlaybackInteractive ([Godot AudioStreamPlaybackInteractive](https://docs.godotengine.org/en/4.4/classes/class_audiostreamplaybackinteractive.html)).

   The two techniques are usually combined: stems raise intensity within a section, and section changes land on bar lines ([IRPR glossary, vertical layering](https://sounddesign.irpr.agency/glossary/vertical-layering/); [IRPR glossary, horizontal re-sequencing](https://sounddesign.irpr.agency/glossary/horizontal-resequencing/)). Note that `get_playback_position()` always returns 0 for an interactive stream ([Godot AudioStreamPlayer](https://docs.godotengine.org/en/stable/classes/class_audiostreamplayer.html)).

9. **Loudness: the only formal game standard I found is the console one.** It is -24 LUFS integrated, ±2 LU. Wwise's guide attributes it to PlayStation and ASWG-R001, and says Microsoft and Nintendo aligned with it. The same guide quotes -18 LUFS ±2 LU for mobile and portable devices ([Audiokinetic, Mastering a Game with Wwise part 1](https://audiokinetic.com/en/mastering-a-game-with-wwise-part1); [Game Developer, Bridgett on loudness](https://www.gamedeveloper.com/audio/standardizing-loudness-in-virtual-reality)). I found no PC standard. The guide advises testing on the actual playback device.

10. **Scale cues from film exist mostly as anecdote.** Pacific Rim's sound team added small mechanical accents to parts of the Jaegers to sell scale ([TechRadar, Pacific Rim sound](https://www.techradar.com/news/home-cinema/how-pacific-rim-s-kaiju-and-jaegers-were-brought-to-life-1194718/2), from the search snippet only, because the page body would not load). One review warns the Jaeger footsteps will blow subwoofers ([Sound & Vision](https://www.soundandvision.com/content/movie-premiere-pacific-rim)). I found no primary interview covering technique (slowed recordings, sub-bass) for Pacific Rim or any Godzilla game. The point about TV speakers is my inference: they reproduce little below roughly 80-100 Hz, so a stomp needs an audible mid-bass "thud" and a crack transient on top of the sub layer, or it disappears on the director's TV. Verify that on the actual TV or soundbar.

## Suggested Godot bus layout

Godot buses can only send to a bus on their left ([audio buses](https://docs.godotengine.org/en/stable/tutorials/audio/audio_buses.html)). Order them left to right like this:

```
Master        HardLimiter (ceiling -1.0 dB)                      <- final safety
 Music        Compressor sidechain=Hero (gentle duck, ~3-6 dB)
 Hero         (roar, stomp, building-collapse "body")            <- the window-setter
 Bed          Compressor sidechain=Hero (deeper duck, ~6-10 dB, release ~600-1000 ms)
   Debris     (rubble-stream loops + capped spot one-shots)  -> Bed
   Crowd      (3 density loops)                              -> Bed
   Military   (tanks, helis, gunfire)                        -> Bed
   Ambience   (harbour water, city tone, sirens)             -> Bed
 CanyonVerb   Reverb (send-only target for Area3D reverb_bus_name)
 UI           (no duck)
```

The dB and millisecond values above are starting points, not sourced numbers. Keep them in a data file, not in the `.tres` alone.

## Sources
- https://designingsound.org/2013/06/21/finding-your-way-with-high-dynamic-range-audio-in-wwise/
- https://www.ea.com/frostbite/news/how-hdr-audio-makes-battlefield-bad-company-go-boom
- https://mcvuk.com/?p=146207
- https://forums.ea.com/discussions/battlefield-6-general-discussion-en/mid-range-gunfire-collapse--occlusion-mismatch-50%E2%80%9380m/13631537
- https://designingsound.org/2010/04/01/audio-implementation-greats-6-physics-audio-part-1/
- https://audiokinetic.com/qa/2233/make-playback-limit-actually-play-only-instance-gloabally
- https://www.audiokinetic.com/products/wwise/versions/2011-1
- https://docs.godotengine.org/en/stable/tutorials/audio/audio_buses.html
- https://docs.godotengine.org/en/stable/classes/class_audioeffectcompressor.html
- https://docs.godotengine.org/en/stable/classes/class_audioeffecthardlimiter.html
- https://docs.godotengine.org/en/stable/classes/class_audiostreamplayer3d.html
- https://docs.godotengine.org/en/stable/classes/class_audiostreamplayer.html
- https://docs.godotengine.org/en/stable/classes/class_audiostreamrandomizer.html
- https://docs.godotengine.org/en/stable/classes/class_area3d.html
- https://docs.godotengine.org/en/stable/classes/class_audiostreaminteractive.html
- https://docs.godotengine.org/en/stable/classes/class_audiostreamsynchronized.html
- https://docs.godotengine.org/en/4.4/classes/class_audiostreamplaybackinteractive.html
- https://godotengine.org/releases/4.3/
- https://forum.godotengine.org/t/how-do-i-make-every-single-node-simulate-the-speed-of-sound-with-delays/143645
- https://feedback.bistudio.com/T78801
- https://assetstore.unity.com/packages/tools/audio/mach-1-156589
- https://blog.criware.com/index.php/2023/05/08/crowd-system/
- https://www.audiokinetic.com/learn/videos/bv4LBbrmu0A
- https://www.audiokinetic.com/en/blog/planet-coaster-part-1-crowd-management-using-data-to-generate-dynamic-crowd-audio
- https://sounddesign.irpr.agency/glossary/vertical-layering/
- https://sounddesign.irpr.agency/glossary/horizontal-resequencing/
- https://audiokinetic.com/en/mastering-a-game-with-wwise-part1
- https://www.gamedeveloper.com/audio/standardizing-loudness-in-virtual-reality
- https://www.techradar.com/news/home-cinema/how-pacific-rim-s-kaiju-and-jaegers-were-brought-to-life-1194718/2
- https://www.soundandvision.com/content/movie-premiere-pacific-rim

## For Kaiju Incremental (ranked, simplest viable first)

Audio is presentation. It reads sim events and never feeds back into the sim. Its pitch and volume randomness must use a presentation RNG, not the seeded sim RNG, or replays will diverge (CLAUDE.md hard rules 2 and 3). Every number below belongs in a schema-validated `data/audio_*.json`.

1. **Bus layout + master HardLimiter + one Hero→Bed sidechain duck.**
   - Cost: one `default_bus_layout.tres` and about an hour, no new code.
   - Payoff: the roar and stomp always cut through the chaos. This is the cheapest share of DICE's HDR result.
2. **A pooled SFX manager with per-category voice caps from data.**
   - Behaviour: reserve the hero voices (roar and stomp always play); steal the quietest or farthest voice in the other categories; drop events below an audibility floor instead of playing them.
   - Cost: one presentation script of about 150-250 lines, a data table and one test that fires 500 events and asserts the voice count stays under the cap.
   - Starting caps to tune (no sourced numbers): Debris 8, Military 12, Crowd 3, Ambience 4, Hero 4.
3. **Size-bucketed break events from the sim, the Red Faction way.**
   - Behaviour: energy (mass × speed) against per-material thresholds picks small, medium or large. One AudioStreamRandomizer per bucket, with random_pitch about 1.1 and a volume offset of 2-3 dB.
   - Cost: a sim event field (energy is likely already there), 2 materials × 3 sizes × 4-6 samples each, so about 30 samples. The samples must be licence-cleared in the register.
4. **A rubble stream instead of per-chunk voices.**
   - Behaviour: count debris landings per 100 ms near the listener and map that rate to the volume of 2-3 looping rubble beds (light, medium, heavy crossfade), plus up to about 6 spot one-shots for the nearest impacts.
   - Cost: small script, 3 loops.
   - Payoff: this is what turns 300 voices into one readable sound that rises with the rampage.
5. **Distance cues.**
   - Behaviour: use a logarithmic attenuation model and keep the built-in distance low-pass on. Past a far-distance cut-off, swap to a "distant boom" variant that is low-passed with a long tail. Delay distant big events by distance ÷ 343 m/s, capped at about 1 s, and only for collapses beyond about 150 m (inference).
   - Cost: low.
   - Risk: it can read as out of sync with the picture (finding 6). Prove it with a clip before keeping it.
6. **Crowd panic bed.**
   - Behaviour: civilian counts in four quadrants around the listener drive the low, medium and high density loops (Witcher 3 and CRI pattern). The fear state raises the pitch and brightness of the screams.
   - Cost: 3 loops plus a short script reading counts the sim already has.
7. **Adaptive music with AudioStreamSynchronized stems.**
   - Behaviour: 3-4 stems (base, percussion, brass, choir) whose volumes follow a smoothed destruction rate, which serves the pillar "every rampage must feel bigger than the last". Later, use AudioStreamInteractive sections (calm, rampage, boss) switched on the next bar.
   - Cost: commissioned or licensed stems. That is spend or licence work, so it needs a written yes in DECISIONS.md. Code cost is small.
8. **Canyon reverb.**
   - Behaviour: Area3D zones over dense blocks, with `reverb_bus_name=CanyonVerb` and the amount tuned in data.
   - Cost: low, but defer it. One global reverb send may already be enough at our camera height.
9. **Loudness pass.**
   - Behaviour: mix to about -24 LUFS integrated (the console standard; nothing exists for PC). Check the result on the director's own TV or soundbar so the stomp's mid-bass layer actually shows up.
   - Cost: a free loudness meter, licence checked before use, and one 5-minute rampage capture.

**Evidence gaps:** I found no primary source on audio in Teardown, Just Cause, Rampage, Godzilla games or Mount & Blade. The Pacific Rim sources are reviews and snippets, not technique interviews. "Grain clustering into a rubble stream" is inference, not a sourced shipped technique. No source confirms that a AAA destruction game uses speed-of-sound delay. Godot does not document whether `set_sync_stream_volume` is smooth during playback, and gives no measured voice or performance limits. The voice caps, dB and millisecond values above are unsourced starting points. The -18 LUFS mobile figure and any PC loudness target are unconfirmed by a primary ASWG document.

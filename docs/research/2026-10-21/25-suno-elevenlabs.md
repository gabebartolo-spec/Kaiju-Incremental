# Suno and ElevenLabs for Kaiju Incremental: what to buy, what to make where, how to ship it

Researched 2026-10-21 (pages read live that day). Answers director comments #20, #22, #23 (docs/roadmap/2026-10-21-director-comments.md).
Marks: "(secondary)" = a blog or forum, not the vendor; "(guess)" = my inference, test before relying on it.
Not legal advice. The licence facts below are the vendors' own words as of the dates shown; the register row must cite the version.

## 0. The 8-line answer

1. Buy **Suno Pro, billed monthly, $10** (annual is $8/mo = $96 up front: do not commit yet). Premier ($30) adds only Suno Studio and a third stem type.
2. Suno rights follow the **download**, not the subscription: a song made and downloaded while on Pro is yours and commercial, perpetually, even after you cancel (Suno ToS, rev. 2026-08-10). Free-plan songs can never be licensed later.
3. Pro caps you at **20 song downloads a month** and 2,500 credits. Our whole adaptive score (3 sections) fits in one month; generate, download, cancel if wanted.
4. Suno has **no official API** (web only). The director generates in his browser; agents never log in or hold keys.
5. **ElevenLabs Starter ($6/mo, 30k shared credits) already covers SFX** and also Eleven Music v2.5 (trained on licensed music, API, 2 and 4 stems). Its catch: a **$500k game-revenue ceiling** for indie-game use (section 2.4). Try it as a free second opinion on the score before the Suno spend.
6. Neither tool gives us **copyright**: pure-AI audio is not copyrightable in the US, so nobody can stop a copy of our sounds or score. Steam's AI survey must list pre-generated AI audio (the demo's #87 sounds already count).
7. Suno legal risk is live: UMG and Sony filed a new suit on 2026-09-20 days after v6 shipped; a Munich court ruled against Suno on 2026-08-01. Users were not blamed in that ruling, but no Suno indemnity was found (section 1.5).
8. Big explosions: layer a short crack, a body, an in-house sub, delayed debris and a long low tail, plus a separate sonic-boom file that the game delays by distance (section 4).

## 1. Suno

### 1.1 Plans and prices (suno.com/pricing, read 2026-10-21)

| Plan | Price | Credits | Downloads/mo | Notes |
|---|---|---|---|---|
| Free | $0 | 50/day | none | v6-mini only; **no commercial rights**; no stems; no add-on credits |
| Pro | $10/mo monthly, $8/mo billed yearly (saves $24) | 2,500/mo | **20** | v6 and v6-wild; **commercial use rights**; stems: 2 types (Auto; Split from mix); priority queue (10 songs at once); custom models; own voice |
| Premier | $30/mo monthly, $24/mo yearly | 10,000/mo | 60 | all of Pro + Suno Studio (MIDI, effects, automation), 3rd stem type (Advanced split), uploads to 30 min |

Monthly vs yearly figures: the page showed the annual price; the monthly $10/$30 comes from secondary pages (lumimusic, dynamoi, 2026) and matches the page's "saves $24 / $72 by billing yearly" arithmetic. Credits do not carry over month to month; top-up credits do not expire but need an active subscription. The 20/60 download caps are new (reported 2026-09-03, secondary). Extra credits and downloads can be bought (price not published).

### 1.2 Commercial use and ownership: the exact terms

Primary sources: Suno Terms of Service, "Date of Last Revision: August 10, 2026" (suno.com/terms) and help.suno.com articles 2746945, 9601665, 2410177.

- Pro/Premier: "Suno hereby assigns to you all of its right, title and interest in and to any Output owned by Suno and generated from Submissions made by you", still subject to the ToS.
- Free: Output may be used "only for your lawful, personal and non-commercial purposes"; Suno owns it (help 2746945). A later upgrade is **not retroactive** (help 2410177).
- Commercial exploitation is allowed "provided you have obtained a permitted download of that Output in accordance with the download allocations for your applicable service tier". Rights tied to a Download "are perpetual and are not affected by ... the expiry, cancellation, downgrade or suspension of your subscription."
- Allowed uses (help 9601665): monetise, stream-distribute, "Use them in film, tv, or video games", sell independently. No attribution to Suno required (help 2410177). Suno takes no revenue share.
- You must not "remove, alter, obscure or circumvent any fingerprint, watermark or metadata Suno appends to an Output". Keep the original download; our encode to Ogg is fine in my reading (guess), but never strip metadata on purpose.
- You "must be the exclusive rights holder of 100% of the material": never paste someone else's lyrics or a reference melody (help 2410177).
- Other users can get similar output ("Other users may provide similar input ... receive the same or similar output"): exclusivity is not promised.
- Not read: the Indemnification clause (heading only). I found no clause where Suno indemnifies a user (guess: none). Have the director skim it once.

### 1.3 Copyright, Content ID, distribution

- Suno itself says: music made 100% with AI "would not qualify for copyright protection" in the US; "Writing the prompt does not constitute the creation of the song." Human lyrics may be registrable (help 2746945). Suno: "granting commercial use rights does not guarantee copyright protection" (help 9601665).
- Meaning for the game: we may ship and sell the audio, but cannot enforce rights on it; a pirate or rival may reuse it. Keep a human layer where it matters (our own arrangement, edits and mix in a DAW, hand-picked and trimmed sections) and write that down. How much human editing is enough is unsettled (guess: treat the score as unprotected).
- Content ID and distributors: secondary sources report AI tracks cross-matching each other and a distributor (Amuse) turning off Content ID for AI music in 2026 (undetectr.com, secondary, weak). Rule for us: **do not register the soundtrack with Content ID or a PRO**; when posting trailers or a soundtrack album, keep the receipt and the download date to dispute any false claim.
- Steam: Valve's survey asks for pre-generated AI content "art/code/sound/etc" and shows much of the disclosure on the store page (Steamworks news, 2024-01-09; rewritten 2026-01-16 to exempt behind-the-scenes tools only, per secondary reports). So AI music and ElevenLabs SFX both go in the survey. itch.io: not checked.

### 1.4 What Suno can and cannot make for a game

- Songs: v6 and v6-wild (Pro). Length: up to 8 minutes per generation on v6 (secondary: jackrighteous.com); v5.5 stopped near 4 min (reddit, secondary). Instrumental: yes (style tag plus `[Instrumental]` metatag, secondary). Exports: WAV from Studio (help 8128193), MP3/WAV from the library (secondary).
- Stems: Pro gets "Get Stems" (Auto = up to 12 instrument stems; "Split from mix"); Premier adds Advanced split with cleaner bleed (Suno video, 2026-06-12). Stems are separated after the fact, so expect bleed and reverb smear (users report it, secondary); a stem is not a recorded layer. For adaptive layering (08-soundscape: base, percussion, brass, choir) test one track's stems at low volume before committing (guess: usable for 3-4 coarse layers, not for solo isolation).
- Loops: songs have no loop mode and no guaranteed constant tempo (guess). Safe routes: (a) ask for a "button ending" and play whole tracks with Godot's `AudioStreamInteractive` bar-synced crossfades; (b) cut a bar-aligned section and crossfade the seam in a DAW; (c) use **Suno Sounds** loops for short beds (below).
- **Suno Sounds** (help 10625537, "experimental"/beta): text to one-shot or **loop** (seamless repeating clip), BPM and key fields, two samples per click, "cinematic whoosh", "thunder rumble", "heavy metal door slam". Max length, credit cost and commercial wording are **not on the page**; the ToS's generic "Output" probably covers it (guess) but confirm by email to support before shipping any Sounds file, and note whether it burns one of the 20 downloads (unknown). Our proven SFX tool is ElevenLabs, so Sounds is only for musical stingers and loops.
- Not Suno's job: voice-over, stylised UI blips, precise one-shot impacts. v6 reviews on reddit call it bright with "tell-tale suno sounds" (secondary): audition on the director's TV.

### 1.5 API and controversies

- **API:** no official public API (Music Business Worldwide, 2026-07-02: "exploring a developer API, starting with a curated group of partners"). Unofficial wrappers (kie.ai, sunoapi.org) exist; they drive the consumer site, risk the account and may breach the ToS. Do not use them. Generation is manual in the director's browser.
- **Labels:** Warner settled with Suno in Nov 2025 and licensed models are rolling out; v6 (launched 2026-09-09) uses music licensed from Warner, BMG and Believe. UMG and Sony **sued again on 2026-09-20** (60,202 recordings; "fruit of the same poisoned tree"; stream-ripping claims) in Massachusetts federal court (lawcommentary.com). Suno has admitted pulling YouTube audio for training and pleads fair use (Music Business Worldwide, 2026).
- **Germany:** Munich Regional Court I, GEMA v. Suno, 2026-08-01: infringement in training and in outputs (six songs found reproducibly stored), fair use rejected; not final; the court put responsibility on Suno, not users (the-decoder.com).
- What it means for us: (1) the risk is a retroactive claim that an output resembles a protected song or that Suno must retire models, not a ban on our use; (2) cut risk by instrumental only, no artist names in prompts, no lyrics, and by running each keeper against a quick listen for known melodies (guess: no tool does this reliably); (3) keep Suno as a swappable layer: music sits on its own bus and stems, so replacing the score later costs a content swap, not code; (4) no Suno spend beyond one Pro month until the first track is picked.

## 2. ElevenLabs

### 2.1 Sound Effects model and settings (docs read 2026-10-21)

- Model: `eleven_text_to_sound_v2` (the only allowed value). Prompt: up to **450 characters**. Duration 0.5 to 30 s (docs; two third-party pages say 22 s: assume the docs), or auto. `prompt_influence` 0 to 1, default **0.3** (high = literal and less variable; we used 0.6 in #87). `loop: true` = seamless loop (v2 only).
- UI: four takes per Generate; download MP3 44.1 kHz or **WAV 48 kHz** (non-looping). API: default `mp3_44100_128`; 192 kbps needs Creator; PCM/WAV 44.1 kHz needs Pro. So on Starter the UI WAV is the best-quality route; the API gives 128 kbps MP3 (two lossy steps before our Vorbis: fine for layers that get filtered, avoid for exposed tails; guess).
- Cost: pricing page says "Sound Effects 200 credits per generation"; the docs say 40 credits per second when a duration is set. #87 actually spent **532 credits for 13 generations** (about 41 each). The credit rules disagree: read the balance after the first batch. Starter has 30,000 credits a month shared with every product; unused credits roll over up to 2x the monthly amount while subscribed.

### 2.2 Starter plan and commercial terms

- Starter: **$6/month**, 30k credits, "Commercial License", "Music commercial use", API access (elevenlabs.io/pricing; the $1 first month in D-092 is no longer shown). Annual = $5/mo (pay 10 months).
- Terms of Service (updated 2026-10-09): free users "may only use the Services for non-commercial purposes"; paid users may use Output commercially, within the Prohibited Use Policy. Help centre: "Content created outside of a paid subscription (before or after) cannot be used commercially". **Rule: only generate while a paid plan is active, and log the date.** Output "may not be unique across users".
- ElevenLabs may train on our inputs and outputs unless we opt out ("Data use" in Terms and Privacy). Our prompts are non-sensitive; still opt out and keep Explore sharing off (already done in #87).

### 2.3 API use and keys

- Endpoint: text-to-sound-effects (`POST /v1/sound-generation`; the exact path was not shown on the page I read: check the API reference), header `xi-api-key`, Python and TypeScript SDKs, `enable_logging` default true. ElevenLabs also publishes a sound-effects agent skill (github.com/elevenlabs/skills).
- **Key holder: the director.** He creates the key at elevenlabs.io/app/settings/api-keys, keeps it in his own shell environment (`ELEVENLABS_API_KEY`), and never pastes it into chat, a file in the repo, or an agent session. Agents write and review `tools/sfx/gen_elevenlabs.py` (reads the env var, loops over a prompt sheet, writes WAV/MP3 plus a JSON log of prompt, settings, seed-less take id, credits before and after); the director runs it, or generates in the web UI as for #87. The script goes in `tools/` only after the register lists it (our own code: row "Ours").

### 2.4 Eleven Music (the music model, same Starter plan)

- Music v2.5 (`model_id="music_v2_5"`; v2 and v1 remain). 3 s to **5 min** per track, vocals or instrumental, MP3 (44.1 kHz, 128-192 kbps) and WAV, composition plans (section by section), inpainting, audio reference (30 s), 2 and 4 stems on Starter and Creator, 6 on Pro (secondary for stem counts). **Trained on licensed stems and music** (Merlin, Kobalt deals; UMG agreement announced). API: Starter and up. Cost 900 credits per minute (pricing FAQ): 30k credits is about 33 minutes shared with SFX.
- Music Terms (updated 2026-10-09), Starter column: monthly download limit **30 minutes**, API yes, concurrency 2, no lossless/192 kbps downloads (Pro and up; table read from scrambled text, so (guess) on the exact columns), **no streaming distribution** (no OST on Spotify), no attribution.
- Games: self-serve plans allow "all online and offline commercial use ... except film, TV, radio, and Studio Games". An **Indie Game** is one with under **$500,000** revenue since first release, made or published by an entity with under **$1,000,000** game revenue last financial year, net of fees and refunds. If the game stops qualifying you get **60 days** to buy a plan that permits Studio Games; copies distributed before then keep the music. This is a real ceiling for a game that does well.
- Output rules: no output that replicates an artist, no music-library creation or resale, review output for clearance yourself; no warranty of a watermark.
- Verdict: cleaner training provenance and an API, worse game-revenue terms and weaker export quality than Suno on Starter. Worth one parallel test of the same three section briefs.

### 2.5 Prompt craft for game SFX (what worked in #87, plus docs)

- Template that produced the 14 shipped files: "High-quality, professionally recorded [thing], one-shot. [3 audible qualities, in order]. [Perspective/space]. Sound effects foley, no music, no voices." (#87 prompts: docs/provenance/sfx.md).
- One sound per prompt. ElevenLabs' own FAQ says multi-event prompts ("walks then falls") work less well than generating parts and combining them. Chain events only for a single quick gesture.
- Name the **material and the event**, not the mood: "concrete tower collapsing", "steel girders groaning", "glass rain". Use their terms: *impact, whoosh, ambience, one-shot, loop, drone, braam*.
- Set duration yourself (cost scales with it): crack 0.8-1.5 s; body 2-3 s; tail 4-6 s; stomp 1.5-2.5 s; roar 3-4 s; loops 5-6 s.
- Do not ask for "distant": the distant-rifle prompt came back near-silent in #87 (peak about -45 dBFS). Generate **close**, then make distance in Godot (low-pass, volume, delayed arrival; 08-soundscape, findings 6).
- Quiet takes happen (rifle needed +24 dB): normalise in the processing step, never judge before level-matching.
- Prompt influence: 0.6 for repeatable core hits; leave 0.3 for textures and loops where variety helps; take all four variants for randomiser pools (08: AudioStreamRandomizer).
- Starter prompt bank (<=450 chars each; edit, then test; all untested here):
  - Explosion crack: "High-quality, professionally recorded massive explosion initial blast, one-shot. Sharp violent crack and concussive pressure-wave thump, very short, dry. Close perspective. Sound effects foley, no music, no voices."
  - Explosion body: "High-quality cinematic huge fireball explosion, one-shot. Roaring detonation with a deep sub-bass boom and crackling fire, medium tail. Sound effects, no music, no voices."
  - Rumble tail: "Low rolling explosion rumble echoing between tall buildings, long decaying tail, deep and dark. Sound effects, no music."
  - Debris: "Heavy concrete chunks, rebar and shattering glass raining down onto a street after a blast, one-shot, 4 seconds. Sound effects foley, no music."
  - Shockwave: "Powerful air-pressure shockwave whoomph, deep low thump with a rushing air burst that fades fast, one-shot. Sound effects, no music."
  - Sonic boom: "Sonic boom, a single deep concussive double thump of compressed air, rolling and low-frequency heavy, one-shot. Sound effects, no music."
  - Fire bed (loop on): "Large industrial fire roaring and crackling, steady, burning chemical tanks, loop. Sound effects ambience, no music."
- Risk with voices: crowd and roar prompts can produce word-like speech; reject any take with a recognisable word or a human-sounding voice on a roar (QA list).

## 3. Which tool for which sound

| Sound | Tool | Why |
|---|---|---|
| Roar, breath/lightning, stomps, collapse, tank, rifle, rotor, crowd (done, #87) | ElevenLabs SFX | Director-picked; keep. Re-roll only on his word. |
| Explosion crack + body (small/medium/large) | ElevenLabs SFX, 4 takes each | Fast textured transients; pick by ear after level-matching. |
| Explosion sub thump | In-house synth (`tools/sfx/build_sfx.py`) | Guaranteed low end; deterministic; TV speakers need mid-bass too (08 finding 10). Check spectrum of EL takes first. |
| Debris rain, glass, rebar | ElevenLabs SFX; Kenney CC0 impacts (already registered) as filler | Material detail; Kenney is free of any AI disclosure. |
| Rumble tail, distant boom variants | ElevenLabs SFX (close take) + Godot low-pass | "Distant" prompts fail; distance is runtime. |
| Shockwave whoomph, sonic boom | ElevenLabs SFX + synth sweep | Both are unmusical pressure sounds; delay and gain come from the sim event in code. |
| Fire/chemical burn beds, silo alarm, siren | ElevenLabs SFX, `loop:true` | Native seamless loop mode. |
| Debris-rate and crowd density loops (3 tiers) | ElevenLabs SFX loops (check voices) | Matches 08 findings 4 and 7. |
| UI clicks, confirm, deny, ready | Keep in-house synth | Tiny, deterministic, no disclosure. |
| Adaptive score (calm, rampage, boss) | Suno Pro (stems) and a parallel Eleven Music test | Only music tools we have; director picks by taste. |
| Short musical stingers (evolution, boss) | Suno Sounds or Eleven SFX "braam" | Both exist; confirm Sounds' licence line first. |
| Voice-over/barks | Neither (out of scope) | Not asked; ElevenLabs voice terms differ. |

## 4. Layering recipe for a big explosion (design; tune by ear, numbers are guesses)

Two files per explosion size so the sim can place the arrival and the voice pool stays small:

1. **`blast_<size>_close.ogg` (the hit, 2.5-4 s, plays at t=0)**: sum of
   - Crack (EL, 0.8-1.5 s, high-passed about 150 Hz), onset at 0 ms.
   - Body (EL, 2-3 s), onset aligned so the transients land within 5 ms.
   - Sub thump (synth sine, fast pitch drop 60 to 30 Hz, 1-1.5 s), +10-20 ms, 5 to 8 dB under the body.
   - Debris (EL, 4 s), onset +150-300 ms, 8 to 12 dB under the body, high-passed 300 Hz.
   - Ride the sum through a soft clipper or limiter so the crack stays readable (tutorials on separating transient and tail: daviddumaisaudio.com, 2026; sonilo.com layer guide; secondary).
2. **`blast_<size>_tail.ogg` (4-6 s)**: rumble tail (EL, low-passed about 400-800 Hz, long fade). Played with the hit for near events, alone for far events (hit swapped for a low-passed boom, per 08 finding 5).
3. **`sonic_boom.ogg` (1-1.5 s)** and **`shockwave.ogg` (0.8 s)**: played by presentation code, delayed by distance / 343 m/s, capped near 1 s and only past about 150 m (08 suggestion 5; it can read as out of sync, so prove it with a clip). Real sonic booms are a close double crack (N-wave); a short double-thump reads as it on speakers (inference, no source read).
4. Variants: 3 bodies and 3 debris takes per size, combined at build time by `build_sfx.py` with a seeded RNG (rebuild = identical).
5. Mix: all blast layers on the Hero bus; tail and debris may go to Bed (08 bus layout). Max 4 Hero voices.

## 5. Loudness and technical targets

- Mix target about **-24 LUFS integrated, +/-2 LU** over a 5-minute rampage (console figure, Wwise guide and ASWG-R001; no PC standard; 08 finding 9); check on the director's TV. Command: `ffmpeg -i capture.wav -af ebur128=peak=true -f null -` (ffmpeg is already a build-time tool).
- Files do not each sit at -24: SFX keep the repo's method (loud-part RMS matched to the sound they replace within 0.5 dB, `tools/sfx/mix_report.py`, peaks -0.8 dBFS or lower). New one-shots: sample peak at most -1.0 dBFS before encoding (lossy encoders overshoot; guess -1.5 for the blasts).
- Master HardLimiter ceiling -1.0 dB (08 bus layout).
- Music loops/stems: about -22 LUFS integrated each at full intensity, true peak at most -1.5 dBTP, stems summing to the track without clipping (guess; set the real value in `data/audio_*.json` after the first mix).
- Formats: SFX mono 44.1 kHz Vorbis 96 kb/s as shipped; music stereo Vorbis (quality about 6, guess), loop points set in the import, not baked as silence.

## 6. QA checklist (per file; record pass/fail in the PR)

1. Level-matched first; listened at 1x and on the TV; compared against the sound it replaces.
2. No artefacts: clicks at the start/end, clipping, digital warble, metallic ring, bandwidth cliff, a constant noise floor; zoom the waveform and spectrum.
3. No voice-like content: no recognisable word, laugh, scream or singing in roars, crowds, impacts and "instrumental" music (Suno vocal bleed is common in stems; secondary).
4. No recognisable existing melody or sample (music: a deliberate listen for known tunes; the GEMA ruling is about memorised songs).
5. Loops: render the loop 3x, inspect the join at the waveform and spectrogram, listen for a pulse or a level step; check the loop flag in the Godot import. Music: bars align at the loop point.
6. Tail: fades to silence without a gate cut; no 0 dBFS start; onset at 0 ms (set `sfx.start_s` to the real onset, as for the rifle).
7. Mono-compatible blasts: body and transient survive a mono fold-down.
8. Pitch and variants: randomiser pool has at least 3 distinct takes; no two identical.
9. Provenance row in `docs/provenance/sfx.md` (or `music.md`): prompt, plan, settings, take id, generation date, processing, final file name.
10. Licence row: the tool and plan were **active on the generation date** (receipt saved); file is CLEARED in `docs/LICENSING_REGISTER.md`; the Steam AI survey list is updated.
11. Raw takes kept outside the repo (`C:\Users\DANTE\Documents\GitHub\Kaiju-Assets-Raw\`; the 2026-10-19 ElevenLabs takes are in `elevenlabs_2026-10-19`).

## 7. Recommendation and workflow

**Buy: Suno Pro, monthly, $10** (not Premier, not annual). Why Pro: it carries the same commercial rights and v6 models as Premier; we need roughly 3 songs plus stems, far under 20 downloads and 2,500 credits (about 50-100 credits per polished song, secondary). Plan to cancel after the downloads are secured; the ToS keeps the rights on downloaded files.

What Pro does **not** do:
- No copyright, no indemnity found, no exclusivity, no protection if the labels' cases go badly.
- No API, no SFX guarantee (Sounds is beta and its terms are unclear), no seamless-loop songs, no Suno Studio (Premier).
- No retroactive licence for anything made on the free plan: **do not generate keepers before subscribing.**
- Stems come from separation and carry bleed.

Gate before he pays: DECISIONS.md written yes (spend); one Eleven Music v2.5 test of the same briefs on the plan he already owns costs about 5-15 minutes of credits and gives him a free comparison on taste and on the $500k ceiling.

Workflow (who does what):
1. Lead/agent writes `docs/audio/music_briefs.md`: three sections (calm, rampage, boss), key and tempo (fixed BPM to ease bar alignment), instrument list matching the stems (base, percussion, brass, choir), "instrumental, no vocals, no choir lyrics, button ending", prompts with no artist names. Also the SFX prompt sheet from section 2.5.
2. **Director** subscribes, logs in and generates in his own browser (taste is his; no agent logs in, enters passwords or holds keys). He downloads WAV and stems to `Kaiju-Assets-Raw\suno\<date>\` and saves the receipt and each song's URL/ID. For ElevenLabs he generates in the UI (as for #87) or runs the agent-written script with his own key.
3. An agent ingests: level-match, trim, loop-seam, encode (`tools/sfx/build_sfx.py` for SFX; a sibling `tools/music/` script for music, built-time only), writes provenance rows.
4. Critic pass: QA list above, one fresh Sonnet critic per batch; lead listens at 1x/2x and on the TV before the director hears finals (per CLAUDE.md the art-QA rule applies to the sound shootout: only passed picks reach him).
5. Register: new rows in `docs/LICENSING_REGISTER.md`: (a) "Suno Pro songs: assigned to the director by ToS rev. 2026-08-10, commercial, downloaded between <dates> while subscribed (receipt saved), perpetual after cancel; not copyrightable; AI-disclosed" and (b) "Eleven Music v2.5" only if used (with the Indie Game ceiling written in the row). Each file lists under its row in `provenance/music.md`. Mark CLEARED only after the receipt, the dates and the ToS snapshot (save the ToS PDF/page with the date next to the receipts) are in place.
6. Product follow-ups: Steam AI survey entry, an "audio is AI-assisted" credits line, and a task to track the Suno cases (monthly check; swap plan: replace the score if an injunction hits).

## 8. Sources (all fetched 2026-10-21 unless stated)

- Suno pricing: https://suno.com/pricing; ToS (rev. 2026-08-10): https://suno.com/terms
- Suno help: https://help.suno.com/en/articles/2746945, /9601665, /2410177, /10625537 (Sounds), /8128193 (Studio export)
- Suno API status: https://www.musicbusinessworldwide.com/suno-explores-developer-api-seeking-apps-that-unlock-experiences-generative-music-makes-possible-for-the-first-time/ (2026-07-02)
- UMG/Sony new suit: https://www.lawcommentary.com/articles/umg-sony-suno-ai-copyright-lawsuit-v6 (2026-09-20)
- Warner deal: https://www.musicbusinessworldwide.com/warner-music-group-settles-with-suno-strikes-first-of-its-kind-deal-with-ai-song-generator/
- Munich GEMA ruling: https://the-decoder.com/german-court-rules-ai-music-generator-suno-violated-copyrights-rejects-fair-use-defense/ (2026-08-01)
- Suno admits YouTube audio: https://www.musicbusinessworldwide.com/suno-admits-it-obtained-youtube-audio-to-train-its-ai-but-challenges-umg-and-sonys-standing-to-bring-stream-ripping-claim/
- Secondary (prices, caps, Content ID): https://lumimusic.ai/blog/suno-pricing, https://dynamoi.com/learn/ai-music-distribution/suno-commercial-rights-explained, https://undetectr.com/blog/ai-music-youtube-copyright-claims, https://undetectr.com/blog/suno-vs-elevenlabs-music, https://jackrighteous.com (v6 length)
- Steam AI disclosure: https://store.steampowered.com/news/group/4145017/view/3862463747997849618 (2024-01-09); 2026 rewrite: https://tech-insider.org/steam-ai-disclosure-2026/ (secondary)
- ElevenLabs pricing: https://elevenlabs.io/pricing; terms: https://elevenlabs.io/terms-of-use; help: https://help.elevenlabs.io/hc/en-us/articles/13313564601361-Can-I-publish-the-content-I-generate-on-the-platform
- ElevenLabs SFX docs: https://elevenlabs.io/docs/overview/capabilities/sound-effects, https://elevenlabs.io/docs/api-reference/text-to-sound-effects/convert, https://elevenlabs.io/docs/eleven-creative/playground/sound-effects
- Eleven Music: https://elevenlabs.io/docs/overview/capabilities/music, https://elevenlabs.io/music-terms (2026-10-09), https://elevenlabs.io/eleven-music-api
- Explosion layering (secondary): https://www.daviddumaisaudio.com/how-to-turn-thunder-into-massive-explosion-sound-effects/, https://sonilo.com/ai-music/explosion-sound-effect-guide
- Loudness and engine notes: docs/research/2026-10-21/08-soundscape.md (Wwise guide, Godot docs)
- Repo: docs/DECISIONS.md D-092 (line 83) and D-030 (line 395; it is in DECISIONS.md, not the archive file: free libraries only, "no paid packs", now partly superseded by D-092 for SFX), docs/LICENSING_REGISTER.md rows 15-18, docs/provenance/sfx.md, PR #87. The files 08-soundscape.md and the 2026-10-21 comments file exist only in other worktrees (e.g. Kaiju-Incremental-wt/audio-duck, lead-docs), not on this branch. assets/ has only `assets/sfx` (28 .ogg files) and no music yet.

## 9. Gaps

- Suno Sounds: credits, max length, whether it counts as a download, and commercial wording are unverified.
- Suno's indemnity and any clause on training use of our uploads were not read in full.
- Credits per ElevenLabs SFX generation: docs disagree (200 vs 40/s vs observed about 41).
- ElevenLabs Starter stem counts and HQ download column come from a secondary page and a scrambled table.
- No tool exists to verify "no known melody"; that stays a listening check.
- Content ID/Amuse report is a single secondary source.

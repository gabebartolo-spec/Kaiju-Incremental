# Itch release candidate checklist (roadmap M4, D-457)

Demo scope (docs/ROADMAP.md): Ostia Minor plus Carthago or Thule (D-425), croc only (D-424), dusk only (D-359),
English only (D-406), Windows exe on Itch, about 2 h. Tick each box in the release PR.

## Content gate
- [ ] Only the croc is selectable; Komodo and serpent hidden on the rack (D-454).
- [ ] Globe offers Ostia Minor, then Carthago / Thule; the second conquest shows the DEMO COMPLETE thanks screen with
      stats and the feedback link, and unlocks endless mode (DESIGN "Demo").
- [ ] Dusk only; no other time-of-day option reachable.
- [ ] English only; no language picker showing untranslated strings.
- [ ] Open M3 rows done or explicitly cut by the director (Taskforce, textures, helicopter deaths, overworld loop).

## Build
- [ ] `config/version` in project.godot bumped; export_presets.cfg file/product version match; the Unity build
      carries it to res/version.txt (tools/unity/build_release.py checks they match).
- [ ] `python tools/lint/licence_register.py --release` passes (no DEV ONLY files, D-301).
- [ ] release.yml run on the tag (`git tag vX.Y && git push origin vX.Y`, or `gh workflow run release.yml`) is green:
      export, pack check, headless launch reaches the main scene.
- [ ] Artifact zip holds KaijuEvolution.exe + libkaiju_carve DLL only; no tests/, tools/, docs/ in the pack.
- [ ] tools/release/demo_smoke.gd prints `DEMO_SMOKE PASS (0 failures)` against the zip's exe.

## Play test (director)
- [ ] Full demo played start to DEMO COMPLETE on a clean user folder; time it (target ~2 h).
- [ ] Save, quit, Continue restores the campaign.
- [ ] Keyboard and controller both work; rebinding works; F11 fullscreen.
- [ ] Low-end PC run: record CPU, GPU, RAM, fps for the system requirements line.
- [ ] Windows SmartScreen warning noted on the page (the exe is unsigned).

## Store page (docs/release/itch_page.md)
- [ ] Director approved title, pitch, description, tags, price.
- [ ] Screenshots and GIF captured from the RC build per the shot list; cover image made.
- [ ] AI disclosure set on the itch page.

## Upload (director's yes required; agents never upload)
- [ ] Director wrote yes in docs/DECISIONS.md for the upload.
- [ ] `BUTLER_API_KEY=... python tools/build_release.py --skip-export --push <user>/<game>` from the RC zip's build.
- [ ] Page set public; download tested from itch on a second PC.

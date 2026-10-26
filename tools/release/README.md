# Release checks

`demo_smoke.gd` walks a built demo: title, NEW KAIJU, Kaiju Creation (croc genome only), a rampage, then a save one evolution
short through Continue, Behemoth, the reveal and the DEMO COMPLETE card back to the title; one PASS/FAIL line per check.
The release exe ignores `--script`, so load its embedded pack into the same-version console editor binary (headless,
scratch APPDATA, nothing windowed):

```bash
APPDATA="$(cygpath -w <scratch>/appdata)" godot_console --headless --main-pack KaijuEvolution.exe --script tools/release/demo_smoke.gd
```

Pass = the last line reads `DEMO_SMOKE PASS (0 failures)`, exit 0. Godot's leak lines at exit are expected.

# Kaiju in Unity (D-470)

Unity 6000.3.23f1, HDRP (D-471). The slice runs on data generated from the Godot game, which git ignores:

1. `unity/native/build.bat` builds `kaiju_core.dll` into `Assets/Plugins/x86_64`.
2. `godot --headless --path . --script tools/unity/export_slice.gd -- --croc=<dir>/reptilian_adult` writes
   `Assets/StreamingAssets/slice/`. The approved croc's export is on PR #579 until it merges.
3. `Unity.exe -batchmode -quit -projectPath unity -executeMethod SliceBuild.Build` sets the project up and builds
   `Build/KaijuSlice.exe`. `SliceBuild.Setup` does the setup alone.

`Assets/Resources/Shaders/SliceLit.shader` is generated: run `python tools/unity/build_lit_shader.py` after an HDRP update.

# Creating 3D models inside Godot 4.x with code and AI (for Kaiju Incremental)

Researched 2026-10-21. Godot docs read are the 4.7 "stable" pages. Claims marked "(training knowledge, not re-checked)" come from memory, not a page fetched this session; verify before relying on them.

## Key findings

1. **Use ArrayMesh with packed arrays for static voxel meshes. SurfaceTool is the easier option but slightly slower, and MeshDataTool and ImmediateMesh are the wrong tools.** The 4.7 docs say ArrayMesh is "slightly faster than using a SurfaceTool, but the API is a little more challenging". Both suit "static geometry (meshes) that don't change over time". MeshDataTool "is not fast" and is worth using only when you need its edge and face data. ImmediateMesh "is slow because the geometry is rebuilt each time you make a change" and is only for geometry that changes every frame. Source: https://docs.godotengine.org/en/stable/tutorials/3d/procedural_geometry/index.html . The docs give no benchmark numbers.

2. **You can build meshes off the main thread. Only adding them to the scene must happen on the main thread.** Resources, meshes included, "can be loaded and manipulated on a thread and then added to the active scene on the main thread". The scene tree is not thread-safe, so use `add_child.call_deferred(...)`. Editing one unique resource from several threads is not supported. Source: https://docs.godotengine.org/en/stable/tutorials/performance/thread_safe_apis.html . The 4.1 release improved WorkerThreadPool and threaded loading: https://phoronix.com/news/Godot-4.1-Released . I found no benchmark of GDScript greedy meshing.

3. **MultiMesh is one draw for up to millions of instances, but it is culled as a whole.** It "can draw up to millions of objects in one go". However, "there is no screen or frustum culling possible for individual instances", so visibility is "all-or-none" unless you split the world into several MultiMeshes. Source: https://docs.godotengine.org/en/stable/tutorials/performance/using_multimesh.html . For this game, MultiMesh suits voxel debris, crowds of identical people and identical tank hulls. It does not suit drawing a creature cube by cube: a greedy mesh has far fewer triangles, and per-cube instances lose culling.

4. **Greedy meshing is the standard way to cut triangles, with two known trade-offs.** The MIT `ogt_voxel_meshify.h` from opengametools offers three routines. "Simple" makes one quad per voxel face. "Greedy" merges same-coloured rectangles but "generally produces T-junctions", so rasterisation may not be watertight. "Polygon" is mostly watertight and makes slightly more triangles than greedy. Source: https://github.com/jpaver/opengametools . Zylann's `VoxelMesherCubes` enables greedy meshing by default and merges only faces of the same colour (https://voxel-tools.readthedocs.io/en/latest/api/VoxelMesherCubes/). So greedy merging works per colour: a busy palette merges less. T-junction cracks show as flickering pixel seams, which matter most on large kaiju at 4K.

5. **godot_voxel (Zylann) is MIT and now ships as a GDExtension as well as a module, but the GDExtension is the less-tested edition.** The repo is a "C++ module/extension for ... Godot Engine 4" under the MIT licence: https://github.com/Zylann/godot_voxel . The Module edition needs a custom editor build. It also needs custom export templates, because the vanilla template lacks the module "so some scenes fail to open". The GDExtension edition runs on an official Godot build, 4.4.1 or later. It is a "recent addition" with less testing and "might crash", it omits FastNoise2, and its GPU features need Forward+ compute. Do not mix the two editions in one project. Source: https://voxel-tools.readthedocs.io/en/latest/getting_the_module/ . Its meshers are blocky, smooth Transvoxel with LOD, and cubes with greedy meshing and palette mode. All target volumetric terrain. The docs fetched do not show the cubes mesher used on its own to build object meshes, and the `.vox` import doc page returned 404.

6. **A maintained Godot 4 MagicaVoxel importer exists (MIT, tested on 4.7.1), but its publisher marks it unstable.** "MagicaVoxel Importer with Extensions" 1.3.0 by bakacandy was updated 2026-08-02. It supports Godot 4.0-4.7.1 and offers greedy or culled mesh generation, import scaling, snap-to-ground and per-model origin centring. Its source repo is not linked on the listing. Source: https://store.godotengine.org/asset/bakacandy/magicavoxel-importer-with-extensions/ . The original CloneDeath version was for Godot 3.1, and its greedy generator "does not currently support materials": https://godotengine.org/asset-library/asset/341 . Importers like this make vertex-coloured meshes, so the vertex-colour flag must be on in the material: https://godotengine.org/asset-library/asset/edit/532 . It runs at import time in the editor, so the shipped game carries only plain meshes.

7. **Vertex colours render differently in Forward+ and gl_compatibility.** `vertex_color_is_srgb` is "only effective when using the Forward+ and Mobile rendering methods, not Compatibility". It was found via a commit mirror of the class reference: https://remotebranch.eu/Stowage/godot/commit/46e40969a222bcd20bd12d36ed570f9148b3c9f5 . The renderer overview also warns that switching renderers "may require some manual tweaks": https://docs.godotengine.org/en/4.5/tutorials/rendering/renderers.html . So one vertex-coloured kaiju can look washed out or too dark on one of the two renderers this game ships. A palette texture sampled by UV avoids the vertex-colour encoding path in both renderers. That is an inference I did not test.

8. **CSG is for prototyping, not runtime content.** CSG is "mainly intended for prototyping". Complex trees "can take a while to process", and too many objects in one tree "will eventually start affecting performance". Since 4.4 you can bake CSG to a MeshInstance3D, which loads faster because the CSG no longer rebuilds when the scene loads. Source: https://docs.godotengine.org/en/stable/tutorials/3d/csg_tools.html . CSG also produces smooth solids, not voxels, so it adds nothing for this game.

9. **Godot MCP servers drive the editor (scenes, nodes, scripts, running the game, screenshots). None of them generates meshes.**
   - **Coding-Solo/godot-mcp** (MIT, about 6.2k stars). Its tools launch the editor, run the project, read debug output, create scenes, add nodes, load sprites, export a MeshLibrary, save scenes, and manage UIDs (4.4+). It shows no script editing: https://github.com/Coding-Solo/godot-mcp .
   - **ee0pdt/Godot-MCP** (MIT, 621 stars, no releases, 19 open issues). An editor plugin plus a Node server. It reads, creates and modifies nodes, scripts and scenes: https://github.com/ee0pdt/Godot-MCP .
   - **Godot MCP Pro** (youichi-uda). It is proprietary, $15 for the server, with only the addon free. It has 160+ tools (screenshots, input simulation, a headless mode), and its own feature matrix marks "AI 3D mesh generation" as "No": https://github.com/youichi-uda/godot-mcp-pro .

   A Claude Code agent can already edit `.gd` and `.tscn` files and run headless Godot, so MCP adds little over the existing `tools/run_tests.sh` flow. That is an inference.

10. **LLMs often write Godot 3 code in a Godot 4 project.** Typical slips are `yield` (now `await`), `.instance()` (now `instantiate()`), the three-argument string `connect()`, `Spatial` and `KinematicBody`, `empty()` (now `is_empty()`), and invented APIs. Sources: https://www.surmado.com/blog/ai-mistakes-in-godot-4-code , https://store.godotengine.org/asset/brocolriri/godot-guard/ , https://bugnet.io/blog/how-to-fix-godot-4-migration-gdscript-errors . Mesh-specific slips I remember from Godot 3 to 4 changes include `ArrayMesh.add_surface_from_arrays` arguments, `SurfaceTool.add_color` (now `set_color`), `PoolVector3Array` (now `PackedVector3Array`), and the Godot 3 `ImmediateGeometry` (now `ImmediateMesh`) (training knowledge, not re-checked). Model rankings are from vendor blogs only: https://www.summerengine.com/blog/best-ai-for-gdscript .

## Tools table

| Tool | What | Licence | Commercial OK | Godot 4 status |
|---|---|---|---|---|
| ArrayMesh / SurfaceTool (engine) | Build meshes from arrays at load time or in tools | MIT (Godot engine) | Yes | Core, 4.7 docs: https://docs.godotengine.org/en/stable/tutorials/3d/procedural_geometry/index.html |
| MultiMesh (engine) | One draw for many identical instances | MIT | Yes | Core, culled all-or-none: https://docs.godotengine.org/en/stable/tutorials/performance/using_multimesh.html |
| CSG (engine) | Boolean solids for prototyping, bakes to mesh since 4.4 | MIT | Yes | Core, prototyping only: https://docs.godotengine.org/en/stable/tutorials/3d/csg_tools.html |
| Zylann godot_voxel (Voxel Tools) | Volumetric terrain, blocky, Transvoxel and cubes meshers, greedy cubes with palette | MIT | Yes | Module edition needs a custom engine and export templates. GDExtension needs 4.4.1+, less tested: https://github.com/Zylann/godot_voxel , https://voxel-tools.readthedocs.io/en/latest/getting_the_module/ |
| MagicaVoxel Importer with Extensions 1.3.0 (bakacandy) | `.vox` to mesh at import, greedy or culled | MIT | Yes | Tested 4.7.1, publisher marks it unstable, updated 2026-08-02: https://store.godotengine.org/asset/bakacandy/magicavoxel-importer-with-extensions/ |
| MagicaVoxel importer with extensions++ (fork) | Adds a MeshLibrary importer (one mesh per keyframe) and hides voxels on hidden layers | Not checked | Unknown | https://godotengine.org/asset-library/asset/edit/6766 |
| opengametools ogt_vox.h / ogt_voxel_meshify.h | C++ `.vox` reader and writer, simple, greedy and polygon meshers | MIT (repo level) | Yes | Engine-agnostic C++, can be linked into a GDExtension: https://github.com/jpaver/opengametools |
| Coding-Solo/godot-mcp | MCP server: run the project, read debug output, create scenes and nodes, UIDs | MIT | Yes | Godot 4, UID tools need 4.4+: https://github.com/Coding-Solo/godot-mcp |
| ee0pdt/Godot-MCP | MCP editor plugin plus server: read and edit nodes, scripts and scenes | MIT | Yes | Godot 4, no releases: https://github.com/ee0pdt/Godot-MCP |
| Godot MCP Pro (youichi-uda) | 160+ tools: screenshots, input, headless | Proprietary, $15 | Paid licence, spend needs the director's yes | Godot 4, some tools need 4.6+ or 4.7+: https://github.com/youichi-uda/godot-mcp-pro |
| godot-mcp-server (npm 0.5.0) | 32 tools, script edits and syntax validation | MIT (per README) | Yes | https://cdn.jsdelivr.net/npm/godot-mcp-server@0.5.0/README.md |
| Blender MagicaVoxel add-on (AstrorEnales) | `.vox` into Blender with cube, quad or greedy meshing | Not checked | Unknown | Blender, not Godot: https://extensions.blender.org/add-ons/blender-magicavoxel/ |

## Sources

- https://docs.godotengine.org/en/stable/tutorials/3d/procedural_geometry/index.html
- https://docs.godotengine.org/en/stable/tutorials/performance/thread_safe_apis.html
- https://docs.godotengine.org/en/stable/tutorials/performance/using_multimesh.html
- https://docs.godotengine.org/en/stable/tutorials/3d/csg_tools.html
- https://docs.godotengine.org/en/4.5/tutorials/rendering/renderers.html
- https://remotebranch.eu/Stowage/godot/commit/46e40969a222bcd20bd12d36ed570f9148b3c9f5
- https://phoronix.com/news/Godot-4.1-Released
- https://github.com/Zylann/godot_voxel
- https://voxel-tools.readthedocs.io/en/latest/getting_the_module/
- https://voxel-tools.readthedocs.io/en/latest/api/VoxelMesherCubes/
- https://store.godotengine.org/asset/bakacandy/magicavoxel-importer-with-extensions/
- https://godotengine.org/asset-library/asset/341
- https://godotengine.org/asset-library/asset/edit/532
- https://godotengine.org/asset-library/asset/edit/6766
- https://github.com/jpaver/opengametools
- https://extensions.blender.org/add-ons/blender-magicavoxel/
- https://github.com/Coding-Solo/godot-mcp
- https://github.com/ee0pdt/Godot-MCP
- https://github.com/youichi-uda/godot-mcp-pro
- https://cdn.jsdelivr.net/npm/godot-mcp-server@0.5.0/README.md
- https://www.surmado.com/blog/ai-mistakes-in-godot-4-code
- https://store.godotengine.org/asset/brocolriri/godot-guard/
- https://bugnet.io/blog/how-to-fix-godot-4-migration-gdscript-errors
- https://www.summerengine.com/blog/best-ai-for-gdscript

## For Kaiju Incremental (ranked, simplest viable first)

1. **Use data-driven voxel models: a palette plus a grid in `data/`, meshed by one small GDScript culled mesher into ArrayMesh, one mesh per rigid body part.**
   - **How:** Each kaiju stage, vehicle or prop is a schema-validated file holding a palette and a set of named part grids (head, torso, limbs, tentacle segments). One script culls hidden faces and writes `PackedVector3Array` for positions, `PackedVector3Array` for flat normals (4 unshared vertices per face) and colours. It calls `add_surface_from_arrays` once per part. Animate by moving part nodes (rigid segments), which suits the voxel look and the cephalopod's segmented tentacles.
   - **Speed:** Bake the meshes to `.res` at build time or cache them on first load, so meshing is not on the play path. Run any load-time meshing on WorkerThreadPool and add nodes with `call_deferred` (finding 2).
   - **Fits the rules:** No dependency. It follows the hard rule that data holds content. It is deterministic and headless-testable: assert vertex and face counts per model in a suite.
   - **Cost:** About 1-2 builder days for the mesher, the schema and one test. No licence risk.
   - **Not covered:** Authoring the grids themselves (see 2).

2. **Author in MagicaVoxel, then convert `.vox` into the `data/` format with a dev tool, rather than shipping an importer addon.**
   - **How:** A small offline converter turns `.vox` into the item-1 data. Alternatively, it can be the bakacandy importer (MIT, tested 4.7.1, greedy or culled), used as editor-only tooling.
   - **Licensing:** MagicaVoxel's own licence was not checked this session (see gaps), so `docs/LICENSING_REGISTER.md` must clear it before use. The importer is marked "unstable" by its publisher, so pin a version.
   - **Cost:** Half a day for the converter, plus the artist's time in MagicaVoxel. It gives the director a visual editor instead of hand-typed grids.

3. **Add greedy meshing only if triangle counts measure too high, and pick a variant that does not crack.**
   - Greedy cuts triangles but merges only same-coloured faces and leaves T-junction seams (finding 4). Measure the culled mesh first. Kaiju at roughly 40-100 voxels per side are likely fine culled, but that is untested.
   - If needed, port the "polygon" routine from `ogt_voxel_meshify.h` (MIT) into the existing native carve GDExtension. That library is already C++, so it adds no new build system. Plain greedy is the fallback, with a crack check at 4K.
   - **Cost:** 1-3 days of C++ plus CI for the extension.

4. **Use MultiMesh for the many identical, small things, not for the creatures.** Fit: voxel debris chunks, crowds of people, a column of tanks or helicopters that share one mesh. Split each MultiMesh per city block, because culling is all-or-none (finding 3). Use per-instance colour or `INSTANCE_CUSTOM` for variety. **Cost:** About 1 day per use; reuses the item-1 meshes.

5. **Set colour and material rules once and check them on both renderers.**
   - **Colour:** Prefer a palette texture plus UVs (or one consistent linear-colour convention) over relying on `vertex_color_is_srgb`, which gl_compatibility ignores (finding 7). Prove it with a side-by-side capture of one kaiju on Forward+ and on gl_compatibility.
   - **Collision:** Keep collision in the sim as grid or box data. Presentation needs only a few BoxShape3D or capsule shapes per part, never a trimesh of the voxel mesh.
   - **LOD:** Use `visibility_range` or a coarser grid per model for distant vehicles. Engine auto-LOD applies to imported meshes, not to procedural ArrayMesh (training knowledge, not re-checked).
   - **Cost:** Half a day, mostly the capture.

6. **Give LLM-written mesh code a Godot-4 guard.** Static typing is already on. Add a headless parse or compile step on every generated script, using the project's own runner. Give agents a short "Godot 3 to 4 names" list (finding 10) in the mesh-builder brief. **Cost:** About an hour.

7. **Skip for now:**
   - **godot_voxel:** MIT, but built for terrain. Its GDExtension is the less-tested edition, its GPU features are Forward+ only, and the game already has its own native carve library, so it would duplicate that.
   - **CSG:** Prototyping only, and not voxel-shaped.
   - **Godot MCP servers:** They overlap what Claude Code already does with files and headless runs. If one is wanted for editor screenshots, ee0pdt or Coding-Solo (MIT) are free. Godot MCP Pro is a $15 spend and proprietary, so it needs the director's written yes in DECISIONS.md, and it makes no meshes anyway.

## Evidence gaps

- No benchmark numbers found for SurfaceTool vs ArrayMesh, for GDScript greedy meshing, or for threaded mesh building (docs give only qualitative rankings).
- The Zylann `.vox` import and meshing doc pages returned 404, and standalone use of `VoxelMesherCubes` on a buffer (outside a terrain) is unconfirmed. The godot_voxel latest release number and date were not visible.
- The bakacandy importer's source repo was not linked on its listing, and whether greedy mode now handles materials is unconfirmed. The extensions++ fork and AstrorEnales Blender add-on licences were not checked.
- MagicaVoxel's own licence and terms for commercial output were not checked this session.
- The `vertex_color_is_srgb` claim comes from a commit mirror, not the live class reference.
- LLM error-rate claims come from vendor blogs, and no independent benchmark exists.
- The engine auto-LOD and winding/normal details are training knowledge and should be checked against https://docs.godotengine.org .

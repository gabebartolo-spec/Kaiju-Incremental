# Building 3D models in Blender with AI: MCP servers, scripted bpy, voxelizing, and image-to-3D (October 2026)

Scope: AI as a development tool for the voxel art in Kaiju Incremental (kaiju species and growth stages, buildings, tanks, helicopters, people, props), feeding Godot 4.7.2. Research only: nothing was downloaded, installed or signed up for.

## Key findings

1. **There is now an official Blender MCP server, and the team is already using it.** Blender Lab, part of blender.org, publishes a "lightweight MCP server for Blender". It has three parts: a Blender add-on, an MCP client, and the server, which you install as an `.mcpb` bundle or from source. It needs Blender 5.1 or newer, and the current add-on is v1.0.3. Its demonstrated jobs are scene analysis, finding poly-count outliers, renaming, material queries and documenting geometry nodes. It is not shown modelling anything. Blender Lab warns that it runs LLM-written code "with no safeguards" against deleting data or sending it elsewhere, and that in its own demo the first answer missed a Solidify modifier that doubled an object's poly count. https://www.blender.org/lab/mcp-server/ . The release history comes from a single blog post by a vendor that sells a competing server: v0.1.0 on 24 March 2026, v1.0.0 on 27 April 2026, v1.0.3 on 11 September 2026. Treat those dates as unverified. https://www.strayspark.studio/blog/official-blender-mcp-server-comparison-2026 . The tools connected in this session (execute_blender_code, search_api_docs, search_manual_docs, get_blendfile_summary_*, render_thumbnail_to_path) match this server's description, along with docs bundled as RST files (inference from the session tool list).

2. **ahujasid/blender-mcp is the popular community alternative: MIT-licensed, about 31.8k stars.** Beyond `execute_blender_code`, it adds asset search and import from Poly Haven (CC0), Sketchfab (needs an API key) and Poly Pizza (about 69% CC-BY, so credit is required). Its `generate_3d` tool calls Tripo, Hunyuan3D, Hyper3D Rodin or Meshy, all of them paid cloud APIs. Downsides:
   - Anonymous usage telemetry is on by default, and the page says data "may be used to train AI models". Turn it off with `DISABLE_TELEMETRY=true`.
   - The socket server "has no authentication or encryption".
   - Safe mode is off by default.
   - Poly Haven downloads freeze the Blender UI, and long requests time out.

   https://github.com/ahujasid/blender-mcp . For this team it mainly adds the paid generator hooks and asset search. The official server already covers code execution and docs.

3. **The evidence says LLM-written bpy is unreliable for anything beyond simple, measurable geometry.** BlenderGym (CVPR 2025) tested 13 vision-language models, including GPT-4o and Claude 3.5 Sonnet, against human Blender users on code-based 3D reconstruction. The finding: "even the state-of-the-art VLM system struggles with tasks relatively easy for human Blender users". Spending more inference on generate-and-verify loops helps, and that compute is best split between generating and checking. https://arxiv.org/abs/2504.01786 . BlenderLLM, a Qwen2.5-Coder-7B fine-tuned on about 8k instruction-to-bpy pairs, reports that existing models "struggle with accurate CAD script generation". Its own CADBench scores the results with an MLLM judge, which is a weak bar. https://arxiv.org/abs/2412.14203 . Both benchmarks use models older than the current ones, and I found no 2026 benchmark of current models on organic modelling (see Evidence gaps).

4. **Voxel art suits scripted generation, because a voxel model is really a 3D grid of colour indices rather than a sculpt.** An LLM is strongest when it can lay out boxes on a grid with exact numbers (building floors, tank hull plus turret plus barrel, helicopter body plus rotor) and render the result to check it. That is far easier than placing edge loops on a creature (inference from findings 3 and 5). Blender has the parts this needs:
   - The Remesh modifier's **Blocks** mode does no smoothing. Octree Depth sets the resolution and Scale lowers it. Remove Disconnected drops small islands. Flat input needs a Solidify modifier first. https://docs.blender.org/manual/en/4.2/modeling/modifiers/generate/remesh.html
   - Geometry nodes can voxelize any mesh. The usual chain is Mesh to Points (or points scattered in a volume), Vector Snap to a grid, a weld or merge to remove duplicates, then Instance on Points with a cube. https://lesterbanks.com/?p=62171 , https://gamefromscratch.com/blender-3-geometry-node-beginner-tutorial/
   - Grid to Points turns each active voxel of a volume grid into a point. https://docs.blender.org/manual/ka/latest/modeling/geometry_nodes/volume/operations/grid_to_points.html

   One limit, from knowledge and not verified on a page: Remesh throws away UVs, so colour has to be carried over separately (see Evidence gaps).

5. **MagicaVoxel into Blender is free and well supported.** The extension "Blender MagicaVoxel VOX Importer" v1.6.0 (24 June 2026) is listed under GPL-3.0-or-later and MIT and needs Blender 4.2 or newer. It imports the .vox hierarchy, with per-voxel cubes, simple cubes, quads, or greedy meshing (optionally watertight). Materials can come in as vertex colours, one material per palette colour, a palette texture, or UV-textured models. https://extensions.blender.org/add-ons/blender-magicavoxel/ . Blender-to-.vox export is mostly paid: Vox Exporter and Voxility Pro on Superhive (formerly Blender Market). Voxility is built on the vengi-voxconvert command-line tool, which its listing says can be used free with fewer features. https://superhivemarket.com/products/voxelity-pro-voxel-file-format-exchange . A Godot-side .vox importer also exists ("MagicaVoxel importer with extensions++"). https://godotengine.org/asset-library/asset/edit/6805

6. **Open image-to-3D licences vary a lot. Only MIT models pass the house rule outright.**
   - **TRELLIS.2-4B** (Microsoft, December 2025): code and weights are MIT. Output is a GLB with PBR textures (base colour, roughness, metallic, opacity). The example decimates to about 1M faces. It needs Linux and an NVIDIA GPU with at least 24 GB, and is tested only on A100 and H100. It depends on NVIDIA's nvdiffrast and nvdiffrec, which "have their own licences". https://github.com/microsoft/TRELLIS.2 , https://huggingface.co/microsoft/TRELLIS.2-4B . A ComfyUI wiki page says the original pipeline relied on non-commercial nvdiffrast and nvdiffrec code, which the ComfyUI port replaces. That is unverified against NVIDIA's own licence text. https://comfyui-wiki.com/en/models/trellis/trellis-2
   - **TripoSG** (VAST): MIT code and MIT weights per the Hugging Face card. It outputs shape only, with no texture. It needs at least 8 GB VRAM and caps output with a `--faces` flag. https://github.com/VAST-AI-Research/TripoSG , https://huggingface.co/VAST-AI/TripoSG
   - **Stable Fast 3D** (Stability): under the Stability AI Community License, commercial use is free only for organisations and individuals with US $1M or less annual revenue, and an Enterprise licence is needed above that. Output is UV-unwrapped, textured, delit and "relatively low" in polygons, and takes under a second. https://huggingface.co/stabilityai/stable-fast-3d
   - **Hunyuan3D 2.1** (Tencent Community License, 13 June 2025) has three restrictions:
     - The licence "does not apply" in the EU, UK and South Korea.
     - A separate licence is required above 1M monthly active users.
     - Outputs may not be used to improve any other AI model.

     https://huggingface.co/tencent/Hunyuan3D-2.1/blob/main/LICENSE

7. **Paid generators: Meshy's free tier is CC BY 4.0 with attribution, and Tripo's free tier is contradictory.** Meshy's free plan is CC BY 4.0, allows commercial use with credit, and leaves ownership with the user. Private, no-credit ownership needs a paid plan, and free downloads are limited to 10 a month of Meshy 6 Lite models. https://intercom.help/meshy/en/articles/16102098-can-i-use-meshy-assets-commercially , https://docs.meshy.ai/en/webapp/pricing . On Tripo's free tier, a Tripo blog post says CC BY 4.0 commercial, https://www.tripo3d.ai/blog/commercial-use-ai-3d-models , but Tripo's own game-development page says "strictly for non-commercial use", https://www.tripo3d.ai/game-development/3d-assets-license-game-development . Paid Tripo tiers are private and commercial. https://www.tripo3d.ai/blog/cheaper-meshy-alternative-private-commercial-use-3d-models . The team already uses Tripo Studio through the director's Chrome, so only paid-tier output should ship.

8. **Godot import can build LODs and shadow meshes itself, so Blender only has to hand over one clean mesh.** "Generate LODs" makes lower-detail variants for distance, and "Create Shadow Meshes" welds vertices to save shadow bandwidth. Embedded glTF textures can be discarded, extracted to files, or embedded as Basis Universal or uncompressed. https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/import_configuration.html . For greedy-meshed voxel art the meshes are already low-poly, so automatic LODs may gain little (inference).

## Tools table

| Tool | What it does | Licence | Commercial-OK | Cost |
|---|---|---|---|---|
| Blender Lab MCP server (official) | LLM client to a live Blender: run code, docs, scene summaries, renders | Not stated on its page; source at projects.blender.org/lab/blender_mcp (unverified) | Yes as a dev tool (output is your own; licence text unread) | Free |
| ahujasid/blender-mcp | Community MCP: run code, Poly Haven, Sketchfab and Poly Pizza import, paid-API 3D generation | MIT | Yes (telemetry on by default) | Free; generators paid per API |
| Remesh modifier, Blocks/Voxel modes | Built-in conversion of any mesh to blocks | GPL (Blender) | Yes | Free |
| Geometry nodes voxelize (Mesh to Points, Vector Snap, Instance on Points) | Scriptable voxelization with an exact grid size | GPL (Blender) | Yes | Free |
| Blender MagicaVoxel VOX Importer 1.6.0 | .vox import with greedy, watertight meshing and palette materials | GPL-3.0+ / MIT | Yes | Free |
| MagicaVoxel | Hand voxel editor | Not checked in this pass | Unverified | Free |
| vengi-voxconvert | Command-line voxel format conversion and voxelizing | Not checked in this pass | Unverified | Free |
| Vox Exporter / Voxility Pro | Blender to .vox / .qb export, textured-mesh voxelize | Commercial product | Yes | Paid (spend needs director yes) |
| TRELLIS.2-4B | Image to textured 3D (PBR GLB) | MIT (code and weights); nvdiffrast/nvdiffrec deps separate | Model yes; deps unverified | Free; 24 GB GPU, Linux |
| TripoSG | Image to untextured mesh | MIT (code and weights per HF card) | Yes | Free; 8 GB GPU |
| Stable Fast 3D | Image to UV-textured low-poly mesh in under 1 s | Stability AI Community License | Yes only at or below US $1M revenue | Free under threshold |
| Hunyuan3D 2.1 | Image to textured mesh | Tencent Hunyuan 3D 2.1 Community License | Conditional: not in EU/UK/South Korea, 1M MAU cap; fails the house bar | Free |
| Meshy (free) | Cloud text/image to 3D | CC BY 4.0 on outputs | Yes with attribution | Free, 10 downloads a month (Lite) |
| Tripo Studio (paid) | Cloud image to 3D, rig, animation | Tripo terms (paid = private and commercial) | Paid yes; free tier contradictory | Credits (team already holds some) |

## Sources

- https://www.blender.org/lab/mcp-server/
- https://www.strayspark.studio/blog/official-blender-mcp-server-comparison-2026 (vendor blog, used for dates only)
- https://github.com/ahujasid/blender-mcp
- https://arxiv.org/abs/2504.01786 (BlenderGym, CVPR 2025)
- https://arxiv.org/abs/2412.14203 (BlenderLLM / CADBench)
- https://docs.blender.org/manual/en/4.2/modeling/modifiers/generate/remesh.html
- https://docs.blender.org/manual/ka/latest/modeling/geometry_nodes/volume/operations/grid_to_points.html
- https://lesterbanks.com/?p=62171
- https://gamefromscratch.com/blender-3-geometry-node-beginner-tutorial/
- https://extensions.blender.org/add-ons/blender-magicavoxel/
- https://superhivemarket.com/products/voxelity-pro-voxel-file-format-exchange
- https://godotengine.org/asset-library/asset/edit/6805
- https://github.com/microsoft/TRELLIS.2
- https://huggingface.co/microsoft/TRELLIS.2-4B
- https://comfyui-wiki.com/en/models/trellis/trellis-2
- https://github.com/VAST-AI-Research/TripoSG
- https://huggingface.co/VAST-AI/TripoSG
- https://huggingface.co/stabilityai/stable-fast-3d
- https://huggingface.co/tencent/Hunyuan3D-2.1/blob/main/LICENSE
- https://intercom.help/meshy/en/articles/16102098-can-i-use-meshy-assets-commercially
- https://docs.meshy.ai/en/webapp/pricing
- https://www.tripo3d.ai/blog/commercial-use-ai-3d-models
- https://www.tripo3d.ai/game-development/3d-assets-license-game-development
- https://www.tripo3d.ai/blog/cheaper-meshy-alternative-private-commercial-use-3d-models
- https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/import_configuration.html

## For Kaiju Incremental (ranked, simplest viable first)

1. **Hard-surface voxel props in code: buildings, landmarks, tanks, helicopters, bollards, cars.** Have the LLM write a small, data-driven generator: a JSON or array grid of palette indices goes in, greedy-meshed boxes come out. Run it headless with `blender -b`, or through the official MCP that is already connected, and render five views after every run. This plays to what LLMs do best (exact grids, simple measurable geometry) and is repeatable and seeded, in line with hard rules 2 and 4. It also gives building variety for "no empty space" cheaply. **Cost: free, time only.**
2. **Hand or LLM-authored .vox through the free VOX importer, for the kaiju and small people.** Draft creatures in MagicaVoxel, or have the LLM emit a .vox grid. Import with greedy, watertight meshing and palette or vertex-colour materials, then export glTF. Small voxel people (about 8 to 16 voxels tall) are close to pixel art in 3D, so a person can author and judge them quickly. MagicaVoxel's own licence was not checked in this pass: clear it in `docs/LICENSING_REGISTER.md` first. **Cost: free.**
3. **Image-to-3D, then voxelize, for organic kaiju stages, and the cephalopod in particular.** Generate a base shape and voxelize it. Use the Remesh modifier's Blocks mode for a quick look, or the geometry-nodes Vector Snap chain where the grid size must match the city's voxel size exactly. Then clean up by hand at the voxel level. Use TripoSG first (MIT, 8 GB VRAM, shape only, which suits voxels because colour gets repainted on the palette anyway), then TRELLIS.2 only if the GPU has 24 GB and its nvdiffrast dependency clears the licence register. Use the team's paid Tripo credits only where a rig or texture is worth it. Under the MERCS-style threshold, ask the director above the limit. **Cost: free locally; Tripo spends existing credits.**
4. **Avoid these:**
   - **Hunyuan3D 2.x:** the territory carve-out and the "no improving other models" clause fail the free-and-commercial bar.
   - **Stable Fast 3D:** fine today, but its $1M revenue ceiling is a future trap.
   - **Meshy free and Tripo free output:** attribution, or a conflicting non-commercial clause.
   - **ahujasid/blender-mcp:** only worth installing for its paid generator hooks. If installed, set `DISABLE_TELEMETRY=true` and `BLENDER_MCP_SAFE_MODE=1`.

   **Cost: none (not adopted).**
5. **QA on every asset before Godot, following the rulebook's generated-asset inspection.** The checklist below is house practice, not checked against a source this pass:
   - Apply scale with 1 Blender unit = 1 m, at the agreed voxel size.
   - Recalculate normals outward and check face orientation.
   - Check the mesh is manifold or watertight, with no loose islands (Remove Disconnected).
   - Record the poly count against a budget per asset class.
   - Render five views, untextured and textured, at 1x and 2x, and count anatomy against the species sheet.
   - Check the palette colours are the right ones.
   - Export glTF with modifiers applied and vertex colours on.
   - In Godot, check vertex-colour albedo and whether automatic LODs help.

   Have the official MCP's poly-count and scene-summary pass do the numbers, but verify them, because its own demo missed a Solidify modifier. **Cost: free.**

**Evidence gaps:**
- No 2026 benchmark of current LLMs writing organic bpy models, so claims about how well current models model creatures are inference.
- The official Blender MCP server's licence text and changelog were not read.
- nvdiffrast's current licence was not verified.
- MagicaVoxel's and vengi's licences were not checked.
- The Remesh modifier dropping UVs, how to carry colour onto voxels (for example, sampling the nearest surface colour in geometry nodes), and rigging voxelized creatures for animation were not sourced.
- I found no quality comparison of TRELLIS.2, TripoSG and SF3D outputs after voxelizing.
- The local GPU's VRAM was not checked against TRELLIS.2's 24 GB need.

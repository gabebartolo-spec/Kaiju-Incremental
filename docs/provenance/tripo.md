# Tripo provenance

Cap: 300 lines. One row per task: date | species | input | mode | task id | credits | privacy | verdict.

| Date | Species | Input | Mode | Task | Credits | Private | Verdict |
|---|---|---|---|---|---|---|---|
| 2026-10-16 | reptilian | text prompt (terrifying reptilian kaiju, T-pose) | HD Model H3.1, T-pose | 484078ce-1ed8-4853-b9f9-f59f2e6e70b2 | 30 | yes | generated (detailed spiky sculpt seen in viewer); six-view inspection pending: download needs the director's OK |
| 2026-10-16 | reptilian adult | (above) | HD H3.1 | 484078ce | (30) | yes | PASS six-view (anatomy ok, untextured clay); director: "he looks wonderful"; reference for the rig-ready set |
| 2026-10-16 | reptilian adult (rig-ready) | text prompt, same as 484078ce | Smart Mesh P2.0 x4 variants | f78fd78d-a640-442e-8d49-7f6624c22ecb | 100 | yes | generating |
| 2026-10-16 | reptilian adult | f78fd78d variant 01e78e11 (13,393 quad faces) | picked | 01e78e11-dfa1-4266-9704-3cceac04d6d7 | - | yes | PASS six-view: 1 head, 2 arms, 2 legs, tail, spikes; untextured (coloured in Blender) |
| 2026-10-16 | reptilian baby | text prompt (hatchling) | Smart Mesh P2.0 x4 | dd1fb56e-0707-4faf-a89b-4f14b5569e01 | 100 | yes | generating |
| 2026-10-16 | reptilian baby | dd1fb56e variant 5a84ed39 (33k faces, hunched hatchling) | picked | 5a84ed39-c735-46fa-9592-6fab41c290ab | - | yes | PASS six-view |
| 2026-10-16 | reptilian adolescent (v1) | dd1fb56e variant 512c7cad | rejected | 512c7cad-6cba-4efa-a8fa-48bf0194d468 | - | yes | director: too similar to the baby |
| 2026-10-16 | reptilian adolescent (v2) | text prompt (lanky growth spurt, half-grown plates; Lion King cub/teen/adult ref) | Smart Mesh P2.0 x4 | 70f4408b-7d7b-4824-a8d1-b420ce3ff0ea | 100 | yes | generating |
| 2026-10-16 | insectoid adult | text prompt | Smart Mesh P2.0 x4 | 843f55af-af03-4224-8d77-8539b3efaafe | 100 | yes | generating |
| 2026-10-16 | reptilian adolescent (v2) | 70f4408b variant adol_a | inspecting | 70f4408b-7d7b-4824-a8d1-b420ce3ff0ea | - | yes | six-view clean (2 arms, 2 legs, tail) but humanoid torso; b/c/d not yet downloaded |
| 2026-10-16 | insectoid adult | 843f55af | rejected | 843f55af-af03-4224-8d77-8539b3efaafe | - | yes | no arms (director: "a bit armless") |
| 2026-10-16 | insectoid adult (mantis) | text prompt (upright mantis, 2 scythe arms, 4 legs) | Smart Mesh P2.0 x4 | c7cdcd1e-9f53-46aa-827a-f67dbdf832da | 100 | yes | done |
| 2026-10-16 | insectoid adult | mantis variant 9668b815 (20,085 faces) | picked | 9668b815-c82b-441e-96d8-a941d77ac59a | - | yes | PASS six-view: 2 scythe arms, 4 legs, antennae, spiked; director: "keep pursuing the mantis look" |
| 2026-10-16 | insectoid | mantis variant 8ec4566c (19,677 faces) | rejected | 8ec4566c-5010-49f6-b577-74c7fbfaaf0e | - | yes | lost the raptorial arms (ant-like) |
| 2026-10-16 | insectoid adolescent? | mantis low-poly variant (5,535 faces) | candidate | c7cdcd1e (variant) | - | yes | lanky classic mantis, 2 arms 4 legs: adolescent candidate |
| 2026-10-16 | insectoid baby (mantis nymph) | text prompt (oversized head, stubby thorax, small scythes, 4 short legs) | Smart Mesh P2.0 x4 | b1ddb234-c406-4428-8f4b-4c4eb36d5ff5 | 100 | yes | generating |
| 2026-10-16 | reptilian adolescent (v2) | 70f4408b set: af0b8a1b / cedf6851 / f9cf6ba7 / 70f4408b | director picked B (f9cf6ba7) | af0b8a1b-1098-43de-a1fa-1d1334eed3df, cedf6851-d6a8-41f8-aaf4-b5c2878b5900, f9cf6ba7-7c6f-48cc-b927-837d7b86321d | - | yes | six-view: cedf6851 PICK (lanky, hunched, spined); f9cf6ba7 alt; af0b8a1b REJECT (doll-like ball joints); 70f4408b REJECT (humanoid torso) |
| 2026-10-16 | insectoid baby/adolescent | b1ddb234 set: b1ddb234 / 03e5a9e2 / 0161ad14 / 06ed8a12 | inspected | 06ed8a12-ae35-4632-bb56-f76cb16d590c (baby), 0161ad14-2f8f-46f0-9546-a704d8277afb (adolescent) | (100, above) | yes | six-view: 06ed8a12 baby PICK (big head, toothed scythes, 4 legs); 0161ad14 adolescent PICK (lanky); b1ddb234 REJECT (cute, 2 legs); 03e5a9e2 alt |
| 2026-10-16 | cephalopod adult | text prompt (scarred barnacled mantle, 8 thick clawed tentacles splayed, beak, slit eyes) | Smart Mesh P2.0 x4 | ff432a4f-bcca-4ed4-a208-f479e1ab9694 | 100 | yes | generating |
| 2026-10-16 | reptilian adult texture | texture prompt (dark charcoal/slate-green scutes, ivory spines, Remove Lighting on) on 01e78e11 | Texture | 01e78e11 (texture) | 30 | yes | done; director: "should be greener, less grey" |
| 2026-10-16 | reptilian adult texture v2 | greener prompt (director: "should be greener, less grey") | Texture | 01e78e11 (texture) | 30 | yes | done: bright green; director "i liked the green" |
| 2026-10-16 | reptilian adult texture v3 | dark olive crocodile prompt (middle ground) | Texture | 01e78e11 (texture) | 30 | yes | director PICK (C) |
| 2026-10-16 | reptilian baby texture | olive crocodile prompt (D-034) on 5a84ed39 | Texture | 5a84ed39 (texture) | 30 | yes | RIGGED (100 vox) |
| 2026-10-16 | reptilian adolescent texture | olive crocodile prompt (D-034) on f9cf6ba7 | Texture | f9cf6ba7 (texture) | 30 | yes | RIGGED (130 vox) |
| 2026-10-16 | cephalopod adult | ff432a4f set: ff432a4f / 8bf2f668 / f303b247 / 666430b3 | inspected | 8bf2f668-965b-47b0-b663-fe76a22104d9 (octo_2) | (100, above) | yes | director PICK C: 10+ barnacled tentacles (hydra); A f303b247 clawed, B ff432a4f smooth; 666430b3 not exported |
| 2026-10-16 | cephalopod baby | text prompt (soft oversized mantle, huge slit eyes, a dozen stubby uneven tentacles, budding barnacles) | Smart Mesh P2.0 x4 | (see Studio, 23:20) | 100 | yes | generating |
| 2026-10-16 | cephalopod baby | 23:19 set: 6176590f / b2edc684 / ede8c6a2 / f1eb550f | picked | 6176590f-5ece-4108-b0a5-d6d42a91bfd4 (5,524 faces) | (100, above) | yes | director: "i love him" (big round eyes, short curled tentacles) |
| 2026-10-16 | insectoid adult texture | dark chitin, rust underside, acid-green eyes on 9668b815 | Texture | 9668b815 (texture) | 30 | yes | REJECT (lead): came out uniform copper-orange |
| 2026-10-16 | cephalopod adolescent | text prompt (leaner angular mantle, brow ridges, 10 lanky whip tentacles, first barnacles) | Smart Mesh P2.0 x4 | 724612fd-2df8-4ca9-9f62-3b16044d3a1b | 100 | yes | generating |
| 2026-10-16 | insectoid adult texture v2 | near-black chitin, rust seams only, "no orange body" | Texture | 9668b815 (texture) | 30 | yes | director PICK (dark chitin, red eyes) |
| 2026-10-16 | insectoid baby texture | mantis skin prompt (nymph) on 06ed8a12 | Texture | 06ed8a12 (texture) | 30 | yes | REJECT (lead): blue body, orange eyes |
| 2026-10-16 | insectoid adolescent texture | mantis skin prompt on 0161ad14 | Texture | 0161ad14 (texture) | 30 | yes | REJECT (lead): orange belly, grey head |
| 2026-10-16 | insectoid baby texture v2 | strict "every part dark, no blue/orange" prompt | Texture | 06ed8a12 (texture) | 30 | yes | PASS (lead): dark chitin, red-rim eyes; mantis_baby_tex.glb |
| 2026-10-16 | insectoid adolescent texture v2 | strict "every part dark, no orange belly" prompt | Texture | 0161ad14 (texture) | 30 | yes | REJECT (lead): bright orange limbs |
| 2026-10-16 | cephalopod adolescent | 724612fd set | picked | a328effe-5a6b-4f6f-a3e4-53f00d8e2f9f (28k faces, low sprawl) | (100, above) | yes | director PICK B (octo_adolescent.glb) |
| 2026-10-17 | insectoid adolescent texture v3 | "legs, arms ... ALL the same dark brown-black" prompt | Texture | 0161ad14 (texture) | 30 | yes | PASS (lead): uniform red-brown chitin; mantis_adolescent_tex.glb |
| 2026-10-17 | cephalopod adult texture | deep-sea octopus: bruised purple-maroon, barnacles, pale pink-grey suckers, amber eyes on 8bf2f668 | Texture | 8bf2f668 (texture) | 30 | yes | generating |
| 2026-10-17 | reptilian adult auto-rig | Tripo Auto Rig (Humanoid, Mixamo preset) on 01e78e11 | Rig | 01e78e11 (rig) | 20 | yes | for look test B (rep_adult_rigged.glb) |
| 2026-10-17 | reptilian (D-045/046) refs | 3 text prompts x4 (croc titan / monitor titan / lean predator) | GPT Image 2.5 | image history 14:57-14:59 | 0 (free quota) | n/a | board reptile_directions.png; director PICK A croc titan |
| 2026-10-17 | reptilian adult new | 2 Nano Banana edits of A (upright, then arms clear = A-pose) | Image edit | image history 15:30-15:31 | 0 (free) | n/a | A-pose ref PASS (lead); multi-view 15:33 REJECTED (left view missing arm, right arm raised wrong) |
| 2026-10-17 | reptilian adult new | A-pose croc titan single image | Smart Mesh P2.0 x4 | 351ad916-623a-4b93-b919-cbb4ab52fd61 | 100 | yes | variant 1 PICKED (quad 6758 faces, clean joint loops) |
| 2026-10-17 | reptilian adult new | texture from A-pose ref | Texture | 351ad916 (texture) | 30 | yes | six-view PASS (lead): rep_croctitan_adult.glb, croctitan_six_view.png |
| 2026-10-17 | reptilian adult arms | 2 Nano Banana edits: shorter, scaly arms | Image edit | image history 21:2x | 0 (free) | n/a | REJECTED (lead): length barely changed; edit 1 added spiked bracers |
| 2026-10-17 | reptilian adult arms | GPT Image 2.5 redraw from the A-pose ref (screen capture), short T-rex arms x4 | Image gen | image history 21:31 | 0 (free) | n/a | short scaly arms PASS (lead); arms near the chest, tail shorter; board croctitan_arms_board.png -> director |
| 2026-10-17 | reptilian adult arms | director picked B; 2 Nano Banana pose edits (arms clear, long tail) | Image edit | image history 21:3x | 0 (free) | n/a | REJECTED: tail curled forward / no change |
| 2026-10-17 | reptilian adult arms | GPT Image 2.5 redraw of B: arms clear, long low tail x4 | Image gen | image history 21:50 | 0 (free) | n/a | variant 3 PASS (lead): long low tail, far arm clear, near arm close but separate |
| 2026-10-17 | reptilian adult v2 | croc titan short arms, variant 3 | Smart Mesh P2.0 x4 | c8185166-665e-4573-90f1-a2e647b8f2c0 | 100 | yes | variant 1 PICKED (quad 6623 faces; arms clear, long tail) |
| 2026-10-17 | reptilian adult v2 | texture | Texture | c8185166 (texture) | 30 | yes | textured, balance 19445; six-view after download |
| 2026-10-17 | reptilian adult v2 colour | 3 Nano Banana colour edits of the variant 3 ref: dark olive / charcoal / bronze-brown spines | Image edit | image history 22:1x | 0 (free) | n/a | board croctitan_spine_colour_board.png -> director (director disliked the pale spines) |
| 2026-10-17 | reptilian adult v2 colour | director picked B charcoal; re-texture of c8185166 from the charcoal ref, Remove Lighting on | Texture | c8185166 (texture 2) | 30 | yes | charcoal spines PASS (lead, Tripo viewer); balance 19415; six-view after download |
| 2026-10-18 | reptilian baby + adolescent refs | GPT Image 2.5 from the v2 adult ref (screen capture), x3 runs | Image gen | image history 03:11-03:17 | 0 (free) | n/a | FAILED on Tripo's side x3 (refunded) |
| 2026-10-18 | reptilian adolescent refs | Nano Banana Pro x4 (lanky teen) | Image gen | image history 03:26 | 0 (free) | n/a | olive back; edits for charcoal back cropped the tail square (dropped) |
| 2026-10-18 | reptilian baby refs | Nano Banana Pro x4 batches (03:28 toy-like, 03:38 realistic) | Image gen | image history | 0 (free) | n/a | board round 1 croctitan_stage_refs_board.png; fresh realism-critic FIX (arms on belly, gharial teen snout, tall spines) |
| 2026-10-18 | reptilian baby + adolescent refs round 2 | Nano Banana Pro x4 each (blunt head, low nub spines, arms out) | Image gen | image history 03:49 | 0 (free) | n/a | critic: adolescent A2 PASS; baby B1 FIX (near arm on belly) |
| 2026-10-18 | reptilian baby ref arm fix | Nano Banana edit of B1: arms out like a gentle T-pose | Image edit | image history 04:13 | 0 (free) | n/a | PASS (lead); director approved croctitan_stage_line.png |
| 2026-10-18 | reptilian baby | baby T-arms ref | Smart Mesh P2.0 x4 | edf7bb50-3810-4206-a0e1-2b037c840637 | 100 | yes | variant 1 PICKED (quad 6387 faces, arms clear) |
| 2026-10-18 | reptilian adolescent | A2 ref | Smart Mesh P2.0 x4 | 109910f0-5125-464b-afde-37c72193ef81 | 100 | yes | variant 1 PICKED (quad 6438 faces, limbs clear) |
| 2026-10-18 | reptilian baby | texture from ref | Texture | edf7bb50 (texture) | 30 | yes | six-view PASS: ~/Downloads/kaiju_tripo/rep_croctitan_baby.glb (2.2 MB, 2k), croctitan_baby_six_view.png |
| 2026-10-18 | reptilian adolescent | texture from ref | Texture | 109910f0 (texture) | 30 | yes | six-view PASS: ~/Downloads/kaiju_tripo/rep_croctitan_adolescent.glb (2.2 MB, 2k; faces +X, not -Y), croctitan_adolescent_six_view.png; balance 19155 |
| 2026-10-18 | cephalopod adult texture | (download only) 8bf2f668 textured GLB, 2k | Export | 8bf2f668 | 0 | yes | ~/Downloads/kaiju_tripo/octo_adult_tex.glb 4.6 MB (row 2026-10-17 "generating" -> downloaded) |
| 2026-10-23 | reptilian head python A ref | GPT Image 2.5 edit of croc titan ref (image history 2026-10-17 21:50, variant 3, 7d179062/image_2): reticulated python head, charcoal spines | Image edit | d9ef0685 | 0 (free quota) | n/a | ref for Smart Mesh; heads_board pending critic |
| 2026-10-23 | reptilian head python B ref | same ref, heavier armoured python head | Image edit | 83e61a14 | 0 (free quota) | n/a | ref for Smart Mesh |
| 2026-10-23 | reptilian head komodo A ref | same ref, classic Komodo head | Image edit | af0de59b | 0 (free quota) | n/a | ref, not yet meshed |
| 2026-10-23 | reptilian head komodo B ref | same ref, battle-scarred Komodo head | Image edit | 1d4d1ece | 0 (free quota) | n/a | ref, not yet meshed |
| 2026-10-23 | reptilian head python A | d9ef0685 | Smart Mesh P2.0 x4 | a24840d3-b805-4853-9c1d-cf8f2d112a52 | 100 | yes (Private) | generated, 4 variants, not yet inspected |
| 2026-10-23 | reptilian head python B | 83e61a14 | Smart Mesh P2.0 x4 | fc818f33-59d1-477d-bee5-c25f95d7830b | 100 | yes (Private) | generated; variant 1 = model 00c91098-1b6c-4ef5-9cb5-e04c3707755e |
| 2026-10-23 | reptilian head python B v1 untextured | export 00c91098 GLB | Export | 00c91098 | 0 | yes | ~/Downloads/kaiju_tripo/heads_python_b_v1_clay.glb (260 KB, glTF); director pressed Save on the native dialog |
| 2026-10-23 | reptilian head refs v2 (size) | croc titan ref (hist 2026-10-17 21:50 var 3), "same size as the croc head" prompt, x4 | Image edit | 699d0691, 17dbfc33, 860f8667 (+ pyB 2024 not kept) | 0 (free quota) | n/a | superseded by the kind-based refs (coordinator: A fits the croc skull, B free silhouette) |
| 2026-10-23 | reptilian head python A, fits skull | croc ref, GPT Image 2.5: croc head silhouette kept, python scales / heat pits / slit eyes only | Image edit | b4e41a04 | 0 | n/a | ref |
| 2026-10-23 | reptilian head python B, free shape | same, long flat python head | Image edit | 2408dfa4 | 0 | n/a | ref |
| 2026-10-23 | reptilian head komodo A, fits skull | same, croc silhouette kept, osteoderms, serrated teeth | Image edit | a40cfda5 | 0 | n/a | ref |
| 2026-10-23 | reptilian head komodo B, free shape | same, heavy deep Komodo jaw | Image edit | 0da919d9 | 0 | n/a | ref |
| 2026-10-23 | python A, fits skull | b4e41a04 | Smart Mesh P2.0 x4 | e89b4c62-24c4-49a7-9bd8-0b1f02dc4f31 | 100 | yes (Private) | generated, variant pick pending |
| 2026-10-23 | python B, free shape | 2408dfa4 | Smart Mesh P2.0 x4 | d60790df-1447-4a50-9666-6225675f2bad | 100 | yes (Private) | generated, variant pick pending |
| 2026-10-23 | komodo A, fits skull | a40cfda5 | Smart Mesh P2.0 x4 | 6d3fc3f4-de0d-4cce-880f-0e8f42da8b82 | 100 | yes (Private) | generated, variant pick pending |
| 2026-10-23 | komodo B, free shape | 0da919d9 | Smart Mesh P2.0 x4 | bc079d86-deed-4b95-bfb2-f41125f6781f | 100 | yes (Private) | generated, variant pick pending |
| 2026-10-23 | croc skin base (charcoal spines) | Nano Banana edit of the croc ref (hist 21:50 var 3): back spines charcoal | Image edit | 53b2081d | 0 | n/a | base for the skin edits (tail tip cut by the square crop) |
| 2026-10-23 | skin Obsidian | Nano Banana colour edit of 53b2081d | Image edit | 6c1353f0 | 0 | n/a | shape kept; ember seams, orange eyes |
| 2026-10-23 | skin Bone | same | Image edit | 48794b99 | 0 | n/a | shape kept; red eyes |
| 2026-10-23 | skin Abyssal | same | Image edit | 147939c4 | 0 | n/a | shape kept; teal, no electric blue |
| 2026-10-23 | skin Desert Rust v1 | same | Image edit | 67f2ec55 | 0 | n/a | REJECT: too bright orange |
| 2026-10-23 | skin Desert Rust v2 | same, "dusty, desaturated" | Image edit | 4e4921b1 | 0 | n/a | shape kept; sand with rust bands |
| 2026-10-23 | skin Gilded v1 | same | Image edit | 7202516f | 0 | n/a | REJECT: reads as brown |
| 2026-10-23 | skin Gilded v2 | same, gold plates on spines/scutes | Image edit | d2091616 | 0 | n/a | shape kept; gold plates on bronze |
| 2026-10-23 | python A, fits skull | texture on variant 1 (model 3b5889db / viewer 53798db1 textured) | Texture (bottom-bar default) | 53798db1-86b8-43aa-bdb7-5151ee76b2ed | 30 | yes | textured; six-view PASS (1 head, 2 arms, 2 legs, tail, no fused parts); croc silhouette kept; heads_python_a.glb |
| 2026-10-23 | python B, free shape | texture on variant 1 (model 2250ab52 / dd97b286 textured) | Texture | dd97b286-9f08-4b7c-aff9-180614a4516a | 30 | yes | textured; anatomy PASS; shape verdict FIX: gaping wide mouth, not the long narrow flat python head asked for; regenerate ref + mesh recommended; heads_python_b.glb |
| 2026-10-23 | komodo A, fits skull | texture on variant 1 (model 45f07fe7 / e4bf93cc textured) | Texture | e4bf93cc-aaa4-4f0d-b1d1-089c8daee7f0 | 30 | yes | textured; six-view PASS; croc silhouette kept, osteoderm skin, yellow tongue; heads_komodo_a.glb |
| 2026-10-23 | komodo B, free shape | texture on variant 1 (model 0fe894e8 / 5814f086 textured) | Texture | 5814f086-3917-4e2d-8b39-3259013dfe6d | 30 | yes | textured; six-view PASS; heavier, deeper, scarred head reads as its own shape; heads_komodo_b.glb |
| 2026-10-23 | heads, four textured models | (download only) tripo_texture_<id>.fbx fetched from the viewer's signed tripo-data URLs, converted FBX to GLB in Blender | Export | the four ids above | 0 | yes | ~/Downloads/kaiju_tripo/heads_{python_a,python_b,komodo_a,komodo_b}.{fbx,glb}; 8k texture; Save-dialog exports abandoned (4 dialogs left open on the lead's machine) |
| 2026-10-23 | croc skins (3D) | Blender luminance gradient map of rep_croctitan_adult_v2.glb texture, 5 palettes, same camera and light | Blender render | n/a | 0 | n/a | skins board rebuilt from these; the 2D Nano Banana skin edits above are dropped from the board |

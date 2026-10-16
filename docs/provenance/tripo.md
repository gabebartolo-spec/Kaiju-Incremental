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

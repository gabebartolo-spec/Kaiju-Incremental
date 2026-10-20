# AI animation for 3D models (auto-rig, video-to-mocap, text-to-motion) and the Godot 4 path: judged for Kaiju Incremental

Researched 2026-10-21. Web research only. Nothing was downloaded, signed up for or bought.

## Key findings

1. **Text-to-motion and video-to-mocap are humans only, and most open weights are research-only.** Tencent's HY-Motion 1.0, the strongest open text-to-motion model, says outright that animals and other non-human creatures are not supported. It needs 24-26 GB of VRAM and ships under a custom "tencent-hunyuan-community" licence ([HF model card](https://huggingface.co/tencent/HY-Motion-1.0), [GitHub](https://github.com/Tencent-Hunyuan/HY-Motion-1.0)). MDM, MoMask and MotionGPT have MIT code, but each depends on SMPL and trains on HumanML3D/AMASS ([MDM](https://www.sourcepulse.org/projects/528812), [MoMask](https://github.com/EricGuo5513/momask-codes), [MotionGPT](https://www.sourcepulse.org/projects/1594954)). The AMASS licence bars "incorporation in a commercial product" and producing artefacts for commercial purposes ([AMASS licence](https://amass.is.tue.mpg.de/license.html), [Motion-X note on HumanML3D](https://arxiv.org/pdf/2307.00818)). The GVHMR weights are "non-commercial research" ([HF mirror](https://huggingface.co/ryanrudes/gvhmr)). SMPL itself needs a paid Meshcapade commercial licence ([Meshcapade](https://meshcapade.com/assets/body-models), [SMPL licences](https://meshcapade.notion.site/The-SMPL-Model-Licenses-2144560e54388085af5eff111fcdf266)). **Under our rules this whole family is BANNED or blocked by spend.** None of it would animate a kaiju anyway.

2. **Tripo, which we already use, is the only service found with auto-rigs for seven non-human body plans.** The Tripo API `rig_type` accepts biped, quadruped, hexapod, octopod, avian, serpentine and aquatic. Rig v2.5-20260210 is the version for non-humanoid creatures, and v3.0-20260909 adds an "others" type. Rig Check is free (0 credits) and returns a recommended type. Auto Rigging costs 25 credits, and output is GLB or FBX ([Tripo developer docs: rig](https://developers.tripo3d.com/en/models/rig)). An octopod type exists, but no source shows how good it is on a tentacled mesh. Commercial rights come only with a paid plan: Tripo's help page says free users have no commercial rights. Third-party sites claim free output is CC BY 4.0, which conflicts with Tripo's page, so trust Tripo ([Tripo help](https://www.tripo3d.ai/help/privacy-policy/how-to-use-tripo-models-commercially)). Pro costs $19.90 a month ([costbench](https://costbench.com/software/ai-3d-generation/tripo-ai/)).

3. **Open auto-riggers with commercial-OK licences exist: UniRig and its successor SkinTokens are MIT.** UniRig (VAST-AI) predicts a skeleton and skin weights for "diverse model categories (humans, animals, objects)". It runs locally on a CUDA GPU with 8 GB or more of VRAM, reads OBJ/FBX/GLB/VRM and writes FBX/GLB ([UniRig GitHub](https://github.com/VAST-AI-Research/UniRig)). SkinTokens claims 98-133% better skinning accuracy. Third-party cards report its weights as MIT with an Apache-2.0 Qwen3-0.6B backbone and CC-BY-4.0 training data (Articulation-XL2.0); this is not confirmed from the upstream LICENSE ([ONNX card](https://huggingface.co/fernandotonon/QtMeshEditor-skintokens-onnx), [MLX card](https://huggingface.co/mlx-community/SkinTokens-bf16)). Neither tool animates; both only rig. RigNet (SIGGRAPH 2020) is GPL-3.0 code with no stated licence for its checkpoints, and its last update was 2023, so it is superseded ([RigNet GitHub](https://github.com/zhan-xu/RigNet)).

4. **The big humanoid auto-riggers do not handle creatures.** A Reallusion admin said AccuRIG is for "human and other types of bipedal characters" and "no plans to support quadruped". The tool is OK for commercial use, but exporting needs a free ActorCore account ([Reallusion forum](https://forum.reallusion.com/551972/reallusion-Accu-Rig-Free), [CG Channel 2025](https://www.cgchannel.com/?p=168596)). Mixamo is free and allows "unlimited commercial or non commercial use", but you may not redistribute the raw character or animation files. That wording comes from Adobe's 2022 FAQ, quoted in its community forum ([Adobe community FAQ](https://community.adobe.com/questions-696/mixamo-faq-licensing-royalties-ownership-eula-and-tos-589400)). Meshy auto-rigs humanoids and quadrupeds only, with 500+ presets. A "non-standard body plan" is not recognised, and you are told to animate it by hand in Blender ([Meshy animate docs](https://docs.meshy.ai/en/webapp/guides/animate)). Meshy's free plan is CC BY 4.0 (commercial use with attribution); Pro is private and fully commercial ([Meshy pricing docs](https://docs.meshy.ai/en/webapp/pricing)).

5. **Hand-keyed animation in Blender, helped by templates, is the dependable free route for quadrupeds.** Blender's built-in Rigify (GPL tool, output rig is yours) ships meta-rigs for Basic Quadruped, Cat, Wolf, Horse and Shark ([Blender manual: Rigify](https://docs.blender.org/manual/en/4.1/addons/rigging/rigify/basics.html)). Cascadeur added "Quadruped Support (Alpha)" to AutoPosing and its Quick Rigging Tool in 2025.3 ([Cascadeur blog](https://cascadeur.com/blog/view/cascadeur-2025-3-new-inbetweening-quadrupeds)), but quadrupeds are "only supported in the Pro and higher versions" ([Cascadeur help](https://cascadeur.com/help/tools/animation_tools/autoposing)). Indie needs revenue under $100k ([Cascadeur EULA](https://cascadeur.com/download)), so it costs money. Auto-Rig Pro costs $50 for the full version and $25 for core. Godot export is claimed only by third parties, and the official listing names Unity and Unreal ([Superhive](https://superhivemarket.com/products/auto-rig-pro/ratings?page=1)). Neither paid tool fits "no spend now".

6. **Godot 4.6+ (our 4.7.2) now has a full procedural-animation toolkit, and it fits voxel kaiju better than any AI mocap.** Godot 4.6 brought IK back as SkeletonModifier3D nodes: TwoBoneIK3D (legs), ChainIK3D, SplineIK3D ("always deterministic", good for tails and tentacles), FABRIK3D, CCDIK3D and JacobianIK3D. With SpringBoneSimulator3D (4.5) for secondary jiggle, there are 19 new modifier nodes across 4.4-4.6. Caveats: deterministic mode may never reach the goal with few iterations, large rotations need LimitAngularVelocityModifier3D, and full docs are "planned" ([Godot blog, 2025-12-16](https://godotengine.org/article/inverse-kinematics-returns-to-godot-4-6/)). One user reports a CCDIK3D bone-index bug ([Godot forum](https://forum.godotengine.org/t/some-questions-about-ccdik3d/137722)). Determinism matters for our replay rule: SplineIK3D, or IK with deterministic mode on, is the safe choice.

7. **Godot's built-in retargeting is humanoid-first; for kaiju, skip retargeting and give each body plan its own clips.** BoneMap and SkeletonProfile come with one preset, SkeletonProfileHumanoid. You can export a custom profile, but the rest fixer assumes a humanoid T-pose (+Z facing, +Y parent-to-child), and Fix Silhouette "can't fix very different shapes" ([Godot docs: retargeting](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/retargeting_3d_skeletons.html)). Root motion is handled through "Unimportant Positions" (it keeps the root and hips) and Normalize Position Tracks (`motion_scale`) (same page). Retargeting does work for the human crowd (Mixamo or Tripo biped onto one shared humanoid skeleton).

8. **Export GLB from Blender, not .blend, and loop clips by suffix or by hand.** `-loop` works on a .glb export but has been reported not to set the loop flag on direct .blend import. The workaround is to set loop in the import settings ([Godot forum](https://forum.godotengine.org/t/blender-import-integration-not-respecting-nla-action-track-loop-suffix/113928)). .blend import converts to glTF internally anyway ([godot-docs PR](https://github.com/godotengine/godot-docs/pull/8173/files)). Every action must be active or stashed on an NLA track to be exported, and repeated NLA strips need Animation Mode "NLA Tracks" ([Godot forum](https://forum.godotengine.org/t/how-to-keep-animation-repetitions-when-importing-blender-file-to-godot/103675), [Cinevva checklist](https://app.cinevva.com/guides/blender-to-godot-export-checklist)).

9. **Video-to-mocap services are humanoid and paid if you want commercial rights.** DeepMotion's licensing "is determined by your plan type", and you need a premium plan for licensed animation; the free tier is personal, non-commercial ([DeepMotion getting-started](https://deepmotion.com/article/getting-started), [toolradar](https://toolradar.com/tools/deepmotion)). Rokoko's free Starter tier caps Vision at 30 s a month ([Rokoko pricing](https://rokoko.com/pricing/)). Move.ai splits its plans into non-commercial and commercial tiers ([Move.ai docs](https://docs.move.ai/knowledge/move-ai-pricing-plans-credits)). FreeMoCap is AGPL-3.0: the tool is free, and output motion data is not code, so it should be usable, but it is human-only and needs a multi-webcam setup ([PyPI](https://pypi.org/project/freemocap/1.0.32/), [CG Channel](https://www.cgchannel.com/2021/07/the-freemocap-project-markerless-mocap-for-under-100)). No source found offers video-to-mocap for animals.

10. **Anything World rigs and animates animals, but costs money for us.** Its catalogue includes quadrupeds (cats, giraffes, llamas) ([Fab listing](https://www.fab.com/listings/0d4c0a2c-8c97-4f2c-a659-864117af383a?lang=de)). The free Individual tier covers students and personal use with revenue under $100k; Micro is $50 a month and Pro $250 a month ([Anything World pricing](https://anything.world/pricing)). It asks for attribution when it made the rig and animations ([AW blog](https://www.anything.world/blog/web-gallery)). Whether the free tier covers commercial use is unclear, so treat it as paid.

## Tool table

| Tool | What | Licence (tool / output or weights) | Commercial OK? | Cost | Local or cloud | Non-humanoid support |
|---|---|---|---|---|---|---|
| Tripo auto-rig + animate | Auto-rig and preset animations | Proprietary; paid users own output, free users have no commercial rights | Paid plan only | 25 credits per rig; Pro $19.90/mo | Cloud | **Yes: quadruped, hexapod, octopod, avian, serpentine, aquatic (v2.5), "others" (v3.0)**; quality unproven |
| Meshy rig + animate | Auto-rig, 500+ presets | Free plan CC BY 4.0; paid plans private | Free with attribution; paid fully | Free 100 credits/mo; Pro about $20/mo | Cloud | Humanoid and quadruped only |
| Mixamo | Auto-rig, large mocap library | Adobe preview terms; no redistribution of raw files | Yes (2022 FAQ wording) | Free (Adobe ID) | Cloud | Humanoid only |
| AccuRIG / ActorCore | Auto-rig | Reallusion freeware | Yes (tool); source mesh licence applies | Free (ActorCore account) | Local | Bipeds only, "no plans" for quadrupeds |
| Anything World | AI rig and animate, animal library | Proprietary; attribution asked | Paid tier (free tier unclear) | $0 / $50 / $250 a month | Cloud | Yes, quadrupeds and animals |
| UniRig | Open skeleton and skin prediction | MIT code (weights not separately stated) | Yes | Free | Local, 8 GB+ VRAM | Claims animals and objects; quality on kaiju untested |
| SkinTokens | UniRig successor | MIT per third-party cards; Qwen Apache-2.0; data CC-BY-4.0 | Yes (verify upstream) | Free | Local | As UniRig |
| RigNet | Older learned auto-rig | GPL-3.0 code; checkpoint licence unstated | Unclear | Free | Local | Generic, superseded |
| Blender Rigify | Template rigs | GPL tool; your rig is yours | Yes | Free (built-in) | Local | **Quadruped, Cat, Wolf, Horse, Shark meta-rigs** |
| Auto-Rig Pro | Blender auto-rig, export presets | Commercial add-on | Yes, after purchase | $25 / $50 | Local | "Universal" mode for any creature (third-party claim) |
| Cascadeur | AI AutoPosing, physics tools | Proprietary EULA; Indie needs revenue under $100k | Paid tiers | Paid (prices conflict across sites) | Local | Quadrupeds in Alpha, Pro tier only |
| HY-Motion 1.0 | Open text-to-motion | Tencent HY community licence (territory clause unverified) | Probably, but text unread; SMPL ties | Free | Local, 24-26 GB VRAM | **No**, humans only |
| MDM / MoMask / MotionGPT | Open text-to-motion | MIT code; AMASS/HumanML3D data non-commercial; SMPL | **No** (data and SMPL) | Free | Local | No |
| GVHMR / WHAM / 4DHumans | Open video-to-mocap | GVHMR weights non-commercial; all SMPL-based | **No** | Free | Local | No |
| FreeMoCap | Open multi-webcam mocap | AGPL-3.0 | Yes (output data) | Free | Local | No |
| DeepMotion | Video-to-mocap | Proprietary; free tier non-commercial | Paid tier only | Free 60 s/mo; paid tiers | Cloud | No (humanoid) |
| Rokoko Vision | Video-to-mocap | Proprietary | Unclear on free tier | Free 30 s/mo | Cloud | No |
| Move.ai | Video-to-mocap | Proprietary, commercial tiers | Paid tier only | Credits | Cloud | No |
| Godot SkeletonModifier3D / IK (4.6+) | Procedural animation at runtime (not AI) | MIT (engine) | Yes | Free | In engine | **Yes: any skeleton; SplineIK3D for tentacles and tails** |

## Sources

- https://developers.tripo3d.com/en/models/rig
- https://www.tripo3d.ai/help/privacy-policy/how-to-use-tripo-models-commercially
- https://costbench.com/software/ai-3d-generation/tripo-ai/
- https://docs.meshy.ai/en/webapp/guides/animate
- https://docs.meshy.ai/en/webapp/pricing
- https://community.adobe.com/questions-696/mixamo-faq-licensing-royalties-ownership-eula-and-tos-589400
- https://forum.reallusion.com/551972/reallusion-Accu-Rig-Free
- https://www.cgchannel.com/?p=168596
- https://anything.world/pricing
- https://www.anything.world/blog/web-gallery
- https://www.fab.com/listings/0d4c0a2c-8c97-4f2c-a659-864117af383a?lang=de
- https://github.com/VAST-AI-Research/UniRig
- https://huggingface.co/fernandotonon/QtMeshEditor-skintokens-onnx
- https://huggingface.co/mlx-community/SkinTokens-bf16
- https://github.com/zhan-xu/RigNet
- https://docs.blender.org/manual/en/4.1/addons/rigging/rigify/basics.html
- https://superhivemarket.com/products/auto-rig-pro/ratings?page=1
- https://cascadeur.com/blog/view/cascadeur-2025-3-new-inbetweening-quadrupeds
- https://cascadeur.com/help/tools/animation_tools/autoposing
- https://cascadeur.com/download
- https://huggingface.co/tencent/HY-Motion-1.0
- https://github.com/Tencent-Hunyuan/HY-Motion-1.0
- https://cgworld.jp/flashnews/01-202601-HY-Motion.html
- https://www.sourcepulse.org/projects/528812 (MDM)
- https://github.com/EricGuo5513/momask-codes
- https://www.sourcepulse.org/projects/1594954 (MotionGPT)
- https://amass.is.tue.mpg.de/license.html
- https://arxiv.org/pdf/2307.00818
- https://huggingface.co/ryanrudes/gvhmr
- https://meshcapade.com/assets/body-models
- https://meshcapade.notion.site/The-SMPL-Model-Licenses-2144560e54388085af5eff111fcdf266
- https://pypi.org/project/freemocap/1.0.32/
- https://www.cgchannel.com/2021/07/the-freemocap-project-markerless-mocap-for-under-100
- https://deepmotion.com/article/getting-started
- https://toolradar.com/tools/deepmotion
- https://rokoko.com/pricing/
- https://docs.move.ai/knowledge/move-ai-pricing-plans-credits
- https://godotengine.org/article/inverse-kinematics-returns-to-godot-4-6/
- https://forum.godotengine.org/t/some-questions-about-ccdik3d/137722
- https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/retargeting_3d_skeletons.html
- https://forum.godotengine.org/t/blender-import-integration-not-respecting-nla-action-track-loop-suffix/113928
- https://forum.godotengine.org/t/how-to-keep-animation-repetitions-when-importing-blender-file-to-godot/103675
- https://github.com/godotengine/godot-docs/pull/8173/files
- https://app.cinevva.com/guides/blender-to-godot-export-checklist

## For Kaiju Incremental

Ranked simplest viable first. The game reads as voxels, so rigid, chunky segments that move with weight are the look. Fluid mocap nuance would be lost at our camera distance.

1. **Tanks and helicopters: no rig and no AI.** Turret yaw, barrel pitch, rotor spin and tilt toward velocity are node transforms in presentation code, driven by sim events. **Cost: free, a few hours.**
2. **Kaiju: procedural animation in Godot 4.7, plus a few hand-keyed Blender clips per growth stage.** Rig each body plan once in Blender: a Rigify Basic Quadruped, Wolf or Horse meta-rig for the quadruped and reptile stages, and a simple hand-built bone chain per tentacle for the cephalopod. Key 3-6 short clips per stage (idle, stomp, roar, swipe, grow) and export GLB, with no retargeting. Add TwoBoneIK3D foot planting on rubble, SplineIK3D for tails and tentacles (deterministic), SpringBoneSimulator3D for jiggle, and LookAt/Aim at targets. This gives the "bigger than last" feel through scale and weight, and it works for every body plan. Keep IK in presentation only (sim stays authority) and use deterministic mode for replays. **Cost: free; the main cost is Blender time per stage.** The Blender MCP can script the meta-rig placement.
3. **Human crowd: Mixamo clips on one shared humanoid skeleton, retargeted in Godot with SkeletonProfileHumanoid.** You need 3-4 clips (run, panic run, fall, cower). People are tiny on screen, so this is plenty, and many instances can share one AnimationLibrary. Do not ship the raw Mixamo files as a separate asset pack (redistribution clause). **Cost: free.** A fallback with zero licence questions is procedural bob and limb swing on 6-part voxel people.
4. **Optional speed-up for rigging only: UniRig/SkinTokens run locally (MIT).** Try them on one kaiju mesh to auto-generate skin weights, then fix the result in Blender. It runs on our GPU (8 GB+), takes one GPU slot, and needs a Python/CUDA install that is not downloaded yet. Clear the licence in LICENSING_REGISTER first (confirm the upstream LICENSE covers the weights). **Cost: free; a few hours of setup; quality unproven.**
5. **If the director wants AI help on creature motion: Tripo auto-rig with a non-biped rig type** (quadruped or octopod, v2.5/v3.0) through his browser. The free Rig Check comes first, and only paid-plan output is commercial. **Cost: 25 credits per rig, paid plan required (about $19.90/mo). Needs his written yes in DECISIONS.md.** It does not give hand-keyed control, and no source proves its creature presets suit a kaiju stomp.
6. **Do not use:** any SMPL, AMASS or HumanML3D-based open model (MDM, MoMask, MotionGPT, GVHMR, WHAM, 4DHumans), which is banned (non-commercial). HY-Motion is humans only, needs 24-26 GB VRAM and its licence text is unread. Video-mocap services are humans only and need paid tiers for commercial use. Cascadeur Pro, Auto-Rig Pro and Anything World cost money and add little over option 2.

**Evidence gaps:** I did not read the actual HY-Motion License.txt (territory and output clauses), the official UniRig/SkinTokens LICENSE text for the weights, or Tripo's current ToS section on rigging output. No review shows Tripo octopod or quadruped rig quality on a real creature. Rokoko free-tier commercial terms and current Mixamo terms on Adobe's helpx page are also unconfirmed. No commercially licensed animal video-to-mocap or animal text-to-motion tool was found.

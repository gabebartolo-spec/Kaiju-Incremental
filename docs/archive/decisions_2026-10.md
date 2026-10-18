# Decisions archive, 2026-10

Rolled from docs/DECISIONS.md (cap 400), newest first, unchanged.

## 2026-10-16 · D-008 · Director · Look C (Concrete Realism), far more detailed; more voxels
Why: chosen from A Toy / B Night / C Concrete on the labelled board; "theres not enough voxels".
Changes: buildings at 4 voxels per floor with window grids, sills, balconies, awnings, roof gear;
kaiju at 5 voxels per design unit with teeth, claws, scales, plates; streets with lane markings,
cars, trees, streetlights that flatten underfoot. Looks A and B removed.

## 2026-10-16 · D-007 · Director · The third species is the Cephalopod
Why: chosen from Cephalopod / Primate / Crystalline / Mechanical; the clearest contrast to a brawler
lizard and a fast bug. Changes: data/species.json, Tentacle Lash (ring attack, huge reach, slow).

## 2026-10-16 · D-006 · Director · Players choose a species at the start: Reptilian, Insectoid, a third
Why: customisation. Each species has its own body, stats and signature attack (rule: a choice must
change play). One species per save; "New kaiju" starts over. Changes: species select screen.

## 2026-10-16 · D-005 · Director · Voxel graphics
Changes: buildings, kaiju, army and debris are voxels; destruction removes layers and spills blocks.

## 2026-10-16 · D-004 · Director · Controls: move + auto attacks, one signature button
Why: focus on positioning and builds; works on controller and the TV.

## 2026-10-16 · D-003 · Director · Short rampages (1-3 min) between visits to the upgrade tree
Why: tight loop, the evolution tree is the spine (Nodebuster / Brotato shape).

## 2026-10-16 · D-002 · Director · Active action game, NOT idle: deep upgrade tree, deliberate pacing,
3-5 hours of content, zero AFK progression
Why: director's words at kickoff. Changes: nothing accrues while closed; no passive income.

## 2026-10-16 · D-002a · Lead · Godot 4.7.2, PC first with a web export; private GitHub repo
Why: director chose Godot (PC + web). The repo-visibility question went unanswered; private is the
standard default and is reversible.

## 2026-10-16 · D-001 · Director · Kaiju Incremental is started with the shared kickoff scaffold
Why: the project-kickoff skill (~/.claude/skills) produced the repo skeleton: CLAUDE.md, CI with
check floors, PR template, board and log, project skills extending github-hygiene and
game-architecture.
Changes: the first commit.

# Decisions archive, 2026-11

Rolled from docs/DECISIONS.md (cap 400), newest first, unchanged.

## 2026-11-01 · D-428 · Director · The open sea is a copied FFT ocean; the sim's waves ride on top
Of the whole-bay water (D-426) "looks functional but ugly and not very realistic", and he picked "Copy a proven ocean
(Recommended)": the GodotOceanWaves Tessendorf FFT ocean (MIT, 2Retr0, commit a171446f; licence register row) runs
as OceanWaves, map 256, waves heading -107 degrees (in from the open sea). It is Froude-scaled by 0.1 (tuning
water.ocean.scale: tile, fetch and depth x0.1, wind x sqrt 0.1), so troughs stay under a metre and never bare the
seabed, while slopes stay those of the real sea. It fades out over the shelf where the sim's swell takes over. Its
wind-wave crest lights the water at 0.15 weight, as the sim's does: at full weight crest_light 1.4 drove a trough's
colour below zero, which the premultiplied blend drew as black blotches by the shore.

## 2026-11-01 · D-427 · Director · Load screen: 12 graded dusk stills, random each load
His shot list for load-screen art: "get caps of the powers / destruction / the city from panoramic angles / all three
kaiju forms / then edit the photos to be more epic", then "remove the ui from the screencaps". Shown the board of 12
(tools/capture/capture_load_art.gd: paused dusk rampage, staged cameras, no UI; graded for bloom, split tone,
contrast and vignette), he picked "All 12", grade "Keep as is" and "Random each load". The loading overlay shows one
4K still (assets/loading) behind INCOMING and the meter, never the same twice in a row (comment #92, D-140, D-359).
The band sits just above the crawl so the kaiju in mid-frame stays in view.

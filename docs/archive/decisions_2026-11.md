# Decisions archive, 2026-11

Rolled from docs/DECISIONS.md (cap 400), newest first, unchanged.

## 2026-11-01 · D-430 · Director · Globe continent states: grey coastline locked, pulsing yellow available, green conquered
Overworld plan row G3, his picks: "Grey / yellow / green" and, for locked, "Coastline only". A locked continent draws
only its coastline in UiKit LOCKED grey, no fill; an available one fills in ACCENT yellow and pulses slowly (one
breath every 2 s); a conquered one fills steady in UiKit GOOD green. Which continents are available follows D-420 and
D-422 (Campaign.states, read from the save's conquered list). Locked continents' markers turn LOCKED grey and the
continent neither lights on hover nor answers a click (his pick: "Grey, not clickable").

## 2026-11-01 · D-429 · Director · Globe mission markers: pin and name on all seven, click turns and zooms in
Overworld plan row G4, his picks: "Pin + name" (a small yellow diamond on the continent, a leader line up and right
to its name in caps, ACCENT yellow with a dark outline), "All seven now" (the offered-pair filter waits for T1, the
colour states for G3) and "Turn + zoom in" (a click turns the continent to the centre and closes the camera in over
0.7 s, eased; the spin holds while one is selected; a click on sea or Esc flies back out and the spin resumes). Shown the stills, "Keep both": Aurelia's pin (the south polar cap)
stays out of view at the default lean until the globe is dragged down, and Neptunia's one pin stays on its southern
islands with the northern islet chain unmarked.

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

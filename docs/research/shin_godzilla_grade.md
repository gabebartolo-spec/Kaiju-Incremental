# Shin Godzilla dusk grade (D-452)

Reference: Shin Godzilla GKIDS trailer, frames A C D H I (local only). Measured with grade.py (letterbox
cropped, Rec.709 luma). Game stills: tools/capture/shot.gd --time=dusk --still-at=6,10,14,20, 1920x1080, game camera.

## Targets
| frame | black | mid | white | sat mean/p90 | shadows | highlights | top/bot |
|---|---|---|---|---|---|---|---|
| A face | 0.070 | 0.348 | 0.752 | 0.20/0.26 | #18181b | #c4bd96 h51 | 0.48/0.42 |
| C plates | 0.003 | 0.174 | 0.517 | 0.25/0.57 | #020302 | #7b7c66 h63 | |
| D haze | 0.046 | 0.376 | 0.841 | 0.19/0.28 | #222822 | #cac2a0 h48 | 0.53/0.31 |
| H breath | 0.101 | 0.357 | 0.871 | 0.41/0.61 | #231f4a | #caa9b9 h331 | |
| I night | 0.043 | 0.169 | 0.933 | 0.54/0.68 | #12112b | #926d99 h291 | |

## Before (origin/main) / after
| still | before black/mid/white, sat, hl hue, shadows, top/bot | after |
|---|---|---|
| 6 s | 0.121/0.292/0.786, 0.37, h71, #162c34, 0.27/0.38 | 0.075/0.330/0.824, 0.18, h47, #2c2d2a, 0.33/0.41 |
| 10 s | 0.108/0.240/0.819, 0.41, h63, #15262d, 0.26/0.35 | 0.158/0.288/0.832, 0.18, h46, #34332d, 0.32/0.44 |
| 14 s | 0.058/0.221/0.823, 0.45, h74, #13232a, 0.26/0.31 | 0.101/0.269/0.835, 0.19, h47, #2f2f2a, 0.31/0.37 |
| 20 s | 0.031/0.251/0.801, 0.48, h112, #0b1a20, 0.29/0.24 | 0.061/0.295/0.823, 0.18, h49, #22231f, 0.37/0.28 |

Rounds r7-r10 (C:/kt/cine): r8 (exp 1.3, post_contrast 1.1) white 0.85-0.90; r9 (exp 1.2, pc 1.0, ambient 0.8,
fog 0.005) white 0.81-0.85; r10 (sky brighter, exp 1.25) white 0.82-0.86; final = r9 + brighter sky.

## Values
sky_top c4bd9c, sky_horizon d6cfae, ambient 0.8, ambient_color 667a78, sun_color e2dcb4, sun_energy 1.2,
fog_color 7e8274, fog_density 0.005, saturation 0.7, agx_contrast 1.7, post_contrast 1.0, exposure 1.2 (new key,
tonemap_exposure), sand aaa080.

## Open
- Black at 10 s / 14 s is 0.10-0.16 (target ~0.05): those frames are mostly fogged ground.
- Mid 0.27-0.33 is below A/D (0.35-0.38). Shadows are olive-grey (h51-82, s0.07-0.13), not the cool #18181b.
- top/bot is above 1 only at 20 s; at 6-14 s the camera looks down and the top of the frame is city, not sky.
- Breath violet (H/I): fx.bolt halo_mode is already "purple"; no grade follows the breath (needs new code).

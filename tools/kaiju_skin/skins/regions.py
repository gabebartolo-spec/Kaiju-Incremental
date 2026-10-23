"""Which body region each cell of a rigged kaiju's .kvox belongs to (D-164 skins: a colour table per region).

The baked cells carry only an rgb and a bone index, so the regions are read from three cheap cues: the
bone (limb ends, head, jaw), the original colour (pale low-saturation hide, near-black neutral, saturated
amber) and the cell's outward normal (up = dorsal, down = ventral). The same rules can be run by the
bake step later; nothing here touches game code.
"""
import numpy as np

REGIONS = ["back", "belly", "spines", "claws", "eyes", "teeth"]
BACK, BELLY, SPINES, CLAWS, EYES, TEETH = range(6)


def features(col):
    c = col.astype(np.float32) / 255
    mx, mn = c.max(1), c.min(1)
    lum = 0.2126 * c[:, 0] + 0.7152 * c[:, 1] + 0.0722 * c[:, 2]
    sat = (mx - mn) / np.maximum(mx, 1e-6)
    return lum, sat, c


def classify(pos, col, bone, nrm, names):
    """Returns an int8 region index per cell (see REGIONS). The mouth's pink inside is left to the game
    (BipedHead.MOUTH_RED splits it at runtime), so those cells stay in their own region and keep their colour."""
    lum, sat, c = features(col)
    idx = {n: i for i, n in enumerate(names)}
    isb = lambda *ns: np.isin(bone, [idx[n] for n in ns if n in idx])
    limb_end = isb("arm_l2", "arm_r2", "leg_l2", "leg_r2")
    torso_tail = isb("spine0", "spine1", "spine2", "head0", *[f"tail{i}" for i in range(9)])
    head = isb("head0", "head1", "jaw")
    ny = nrm[:, 1]
    reg = np.full(len(pos), BACK, np.int8)
    # belly: pale, low-saturation hide on the underside (chest, belly, throat, under the tail)
    reg[(lum > 0.38) & (sat < 0.5) & (ny < 0.6) & ~limb_end] = BELLY
    # spines: near-black neutral cells on the dorsal side of the body, neck and tail
    reg[(lum < 0.22) & (sat < 0.32) & torso_tail & (ny > 0.15)] = SPINES
    # claws: dark cells at the end of the arms and legs
    reg[(lum < 0.2) & (sat < 0.55) & limb_end] = CLAWS
    # teeth: the bright cells inside the mouth (the sculpt has no separate tooth cells; see README)
    reg[isb("head1") & (lum > 0.68) & (sat < 0.45) & (ny < -0.2)] = TEETH
    reg[isb("jaw") & (lum > 0.68) & (sat < 0.45) & (ny > 0.3)] = TEETH
    # eyes: the amber patch on the head, high on the skull; keep only the two real eye cells (a ball of about 2
    # voxels round the most amber cell on each side), not the brow or cheek cells that share the colour
    cand = head & (sat > 0.75) & (c[:, 0] > c[:, 1]) & (c[:, 1] > c[:, 2]) & (c[:, 2] < 0.2) & (pos[:, 1] > 270)
    score = np.where(cand, c[:, 0] - 0.5 * (c[:, 1] + c[:, 2]), -9)
    for side in (-1, 1):
        sel = np.nonzero(cand & (np.sign(pos[:, 0]) == side))[0]
        if len(sel):
            ctr = pos[sel[np.argmax(score[sel])]].astype(float)
            reg[sel[np.linalg.norm(pos[sel] - ctr, axis=1) <= 2.0]] = EYES
    return reg

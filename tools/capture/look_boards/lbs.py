"""shrink.py in.png out.png width   |   crop: shrink.py in.png out.png x0 y0 x1 y1 [scale]"""
import sys
from PIL import Image

a = sys.argv
im = Image.open(a[1]).convert("RGB")
if len(a) == 4:
    w = int(a[3])
    im = im.resize((w, int(im.height * w / im.width)), Image.LANCZOS)
else:
    x0, y0, x1, y1 = map(int, a[3:7])
    im = im.crop((x0, y0, x1, y1))
    s = float(a[7]) if len(a) > 7 else 1.0
    if s != 1.0:
        im = im.resize((int(im.width * s), int(im.height * s)), Image.NEAREST if s > 1 else Image.LANCZOS)
im.save(a[2])
print(im.size)

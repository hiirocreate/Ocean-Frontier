"""主人公の立ち絵から「上着（フードを含む）」のマスクを作る。

生成イラストの上着は紺〜青。目も青いため色だけでは区別できないので、
青い画素の連結領域のうち大きいもの（上着・フード）だけを残し、小さいもの（目）を除く。
出力: assets/characters/portraits/<id>_<表情>_outer.png（グレースケール。白=上着）
使い方: python3 tools/make_outfit_masks.py
"""
import colorsys
import glob
import os

import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "characters", "portraits")
SCALE = 4  # マスクは 1/4 の大きさで保存（シェーダーで線形補間）
MIN_AREA = 0.006  # 画像全体に対するこの割合より小さい青い領域（目など）は除く


def mask_for(path: str) -> Image.Image:
    im = Image.open(path).convert("RGBA")
    a = np.asarray(im).astype(np.float32) / 255.0
    rgb, alpha = a[..., :3], a[..., 3]
    hsv = np.asarray(im.convert("RGB").convert("HSV")).astype(np.float32) / 255.0
    h, s = hsv[..., 0], hsv[..., 1]
    blue = (h > 0.53) & (h < 0.74) & (s > 0.18) & (alpha > 0.5)
    blue = ndimage.binary_closing(blue, iterations=2)
    lab, n = ndimage.label(blue, structure=np.ones((3, 3)))
    areas = ndimage.sum(blue, lab, range(1, n + 1))
    keep = np.zeros(n + 1, bool)
    keep[1:] = areas >= MIN_AREA * blue.size
    m = keep[lab]
    # 上着の中の小さな隙間（しわの暗部・縫い目）も埋める
    m = ndimage.binary_closing(m, iterations=3) & (alpha > 0.5)
    out = Image.fromarray((m * 255).astype(np.uint8), "L")
    out = out.filter(ImageFilter.GaussianBlur(1.5))
    return out.resize((im.width // SCALE, im.height // SCALE), Image.LANCZOS)


def main() -> None:
    for p in sorted(glob.glob(os.path.join(DIR, "player_*_*.webp"))):
        dst = p[: -len(".webp")] + "_outer.png"
        mask_for(p).save(dst, optimize=True)
        print(os.path.basename(dst))


if __name__ == "__main__":
    main()

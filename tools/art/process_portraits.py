"""生成した立ち絵を ゲーム用に仕上げる: 背景除去（rembg isnet-anime）→ 会話枠の縦横比で切り抜き → WebP（透過）。

使い方: python tools/art/process_portraits.py <生成画像のディレクトリ> <出力ディレクトリ>
  *_normal.png / *_smile.png など（*_full.png は3D用なので対象外）を処理し、<id>_<表情>.webp を書き出す。
"""
import os
import sys

from PIL import Image
from rembg import new_session, remove

ASPECT = 300 / 380  # 会話画面の立ち絵の枠（DialoguePanel）
OUT_H = 760


def main() -> None:
    src, dst = sys.argv[1:3]
    os.makedirs(dst, exist_ok=True)
    session = new_session("isnet-anime")
    for name in sorted(os.listdir(src)):
        if not name.endswith(".png") or name.endswith("_full.png"):
            continue
        out = os.path.join(dst, name[:-4] + ".webp")
        if os.path.exists(out):
            continue
        img = Image.open(os.path.join(src, name)).convert("RGB")
        cut = remove(img, session=session, post_process_mask=True)
        w, h = cut.size
        ch = min(h, int(w / ASPECT))
        cut = cut.crop((0, 0, w, ch))  # 頭を残すため上端から切り抜く
        cut = cut.resize((int(OUT_H * ASPECT), OUT_H), Image.LANCZOS)
        # 上端で切れた髪が直線にならないよう、上端 4% の不透明度をなだらかに下げる
        a = cut.getchannel("A")
        fade = int(OUT_H * 0.04)
        for y in range(fade):
            k = y / fade
            row = a.crop((0, y, a.width, y + 1)).point(lambda v, k=k: int(v * k))
            a.paste(row, (0, y))
        cut.putalpha(a)
        cut.save(out, "WEBP", quality=90, method=6)
        print(out, os.path.getsize(out) // 1024, "KB", flush=True)


if __name__ == "__main__":
    main()

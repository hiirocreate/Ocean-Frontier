"""キャラクター画像の生成ジョブ（gen_images.py 用）を作る。

  python tools/art/character_jobs.py base  > jobs_base.json   # 立ち絵の基本（normal）と3D化用の全身画像
  python tools/art/character_jobs.py expr  > jobs_expr.json   # 表情差分（基本画像から img2img）

主人公は性別×年齢帯の8種。髪は緑で生成し、ゲーム内で選んだ髪色にシェーダーで置き換える（D-050）。
"""
import json
import sys

STYLE = "anime screencap, simple background, white background"
PORTRAIT = "upper body, facing viewer, looking at viewer"
FULL = "full body, standing, straight-on, front view, arms at sides, looking at viewer"

NPC = {
    "mira": ("1girl, solo, original, adult woman, marine researcher, round glasses, long brown hair, gentle eyes, "
             "white waterproof coat, light gray-blue shirt, small data terminal hanging from neck", 1101),
    "tobi": ("1boy, solo, original, teenage boy, mechanic, spiky orange hair, goggles on head, oil stain on cheek, "
             "ochre jacket, tool belt, energetic", 1202),
    "garrett": ("1boy, solo, original, old man, former soldier, short gray hair, stubble, muscular, scar on arm, "
                "olive military jacket, stern", 1303),
    "selene": ("1girl, solo, original, adult woman, traveling merchant, long wavy dark purple hair, earrings, necklace, "
               "layered purple and gold clothes, confident", 1404),
    "rook": ("1boy, solo, original, adult man, pirate, black hair tied back, eyepatch, dark red patched long coat, "
             "harpoon on back, smirk", 1505),
}
PLAYER_OUTFIT = "castaway, green hair, blue eyes, navy blue hooded jacket, white t-shirt, brown leather harness, ring pendant necklace"
PLAYER = {
    ("male", "young"): ("1boy, solo, original, child, little boy, short messy hair", 2101),
    ("male", "youth"): ("1boy, solo, original, teenage boy, messy hair", 2102),
    ("male", "adult"): ("1boy, solo, original, young man, messy hair", 2103),
    ("male", "mature"): ("1boy, solo, original, mature male, short hair, stubble", 2104),
    ("female", "young"): ("1girl, solo, original, child, little girl, short hair", 2201),
    ("female", "youth"): ("1girl, solo, original, teenage girl, medium hair, ponytail", 2202),
    ("female", "adult"): ("1girl, solo, original, young woman, medium hair, ponytail", 2203),
    ("female", "mature"): ("1girl, solo, original, mature female, long hair, ponytail", 2204),
}
# 立ち絵（768x1024）上の顔の位置（中心x, 中心y, 半径x, 半径y の比率）。基本画像を見て決めた値
FACE_BOX = {"garrett": [0.48, 0.2, 0.3, 0.2], "rook": [0.52, 0.36, 0.42, 0.3], "tobi": [0.5, 0.3, 0.3, 0.2],
            "selene": [0.5, 0.25, 0.3, 0.2]}
EXPR_STRENGTH = {"rook": 0.8}  # 元の表情（不敵な笑み）が強く残るため強めに描き直す
EXPR = {
    "smile": "smile, happy, open mouth",
    "sad": "sad, frown, looking down",
    "angry": "angry, frown, clenched teeth",
    "surprised": "surprised, open mouth, wide-eyed",
}
PLAYER_EXPR = ["smile", "sad", "surprised"]  # 主人公はこの3種（怒りは通常で代用）
# 全身画像の乱数シードの個別指定（頭が切れた・背景に大きな物が入った画像を選び直した結果）
FULL_SEED = {"garrett": 1371, "tobi": 1288, "player_female_young": 2311}
# 全身画像だけ説明を差し替える（「mechanic」だと背景に大きな機械が描かれ、3D化で人物と一体になるため）
FULL_DESC = {"tobi": "1boy, solo, original, teenage boy, spiky orange hair, goggles on head, ochre jacket, tool belt, energetic, "
                     "no background objects"}


def characters():
    for cid, (desc, seed) in NPC.items():
        yield cid, desc, seed, list(EXPR)
    for (g, band), (desc, seed) in PLAYER.items():
        yield f"player_{g}_{band}", f"{desc}, {PLAYER_OUTFIT}", seed, PLAYER_EXPR


def main() -> None:
    mode = sys.argv[1] if len(sys.argv) > 1 else "base"
    jobs = []
    for cid, desc, seed, exprs in characters():
        if mode == "base":
            jobs.append({"id": f"{cid}_normal", "prompt": f"{desc}, {PORTRAIT}, {STYLE}", "seed": seed, "w": 768, "h": 1024})
            jobs.append({"id": f"{cid}_full", "prompt": f"{FULL_DESC.get(cid, desc)}, {FULL}, {STYLE}", "seed": FULL_SEED.get(cid, seed + 50),
                         "w": 832, "h": 1216})
        else:
            for e in exprs:
                # 表情に関する語（smirk など）を元の説明から除き、顔だけを強めに描き直す
                base = ", ".join(t for t in desc.split(", ") if t not in ("smirk", "confident", "stern", "energetic"))
                jobs.append({"id": f"{cid}_{e}", "prompt": f"{base}, {EXPR[e]}, {PORTRAIT}, {STYLE}", "seed": seed,
                             "init": f"{cid}_normal", "strength": EXPR_STRENGTH.get(cid, 0.68), "face_only": True,
                             "face_box": FACE_BOX.get(cid, [0.5, 0.32, 0.36, 0.24])})
    json.dump(jobs, sys.stdout, ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()

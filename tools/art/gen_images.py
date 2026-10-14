"""キャラクター画像をローカルの CPU で生成する（GPU・アカウント・有料APIは不要）。

モデル: Animagine XL 4.0（CreativeML Open RAIL++-M）。LoRA に "none" を渡すと通常生成（CFG・DPM++ 2M Karras）、
       SDXL-Lightning LoRA（ByteDance, OpenRAIL++）を渡すと CFG なしの高速生成（画質は落ちる）
使い方:
  python tools/art/gen_images.py <animagineのディレクトリ> <LoRAファイル> <ジョブJSON> <出力ディレクトリ>
ジョブJSON: [{"id": "mira_normal", "prompt": "...", "seed": 1, "w": 832, "h": 1216},
           {"id": "mira_smile", "prompt": "...smile...", "init": "mira_normal", "strength": 0.5}, ...]
init 付きのジョブは同じ出力ディレクトリの元画像から img2img する（元画像が先に並んでいること）。
既に出力がある id は飛ばすので、中断しても続きから再実行できる。

メモリ対策（約14GBの環境で動かすため）:
  1) テキストエンコーダーだけを読み込み、全ジョブのプロンプトを先にベクトル化して解放する
  2) その後 UNet と VAE だけを fp32 で読み込んで画像を作る（CPU の bf16 は非常に遅いため fp32）
"""
import gc
import json
import os
import sys
import time

import torch
from diffusers import DPMSolverMultistepScheduler, EulerDiscreteScheduler, StableDiffusionXLImg2ImgPipeline, StableDiffusionXLPipeline
from PIL import Image, ImageDraw, ImageFilter

QUALITY = ", masterpiece, high score, great score, absurdres"
NEGATIVE = ("lowres, bad anatomy, bad hands, text, error, missing finger, extra digits, fewer digits, cropped, worst quality, "
            "low quality, low score, bad score, average score, signature, watermark, username, blurry, nsfw, multiple views, "
            "sketch, watercolor, monochrome, cropped head, head out of frame, out of frame")


def main() -> None:
    model_dir, lora_path, jobs_path, out_dir = sys.argv[1:5]
    fast = lora_path not in ("", "none")  # LoRA 指定時は Lightning（CFGなし）、"none" なら通常生成（CFGあり・DPM++ 2M Karras）
    steps = int(os.environ.get("STEPS", "8" if fast else "14"))
    os.makedirs(out_dir, exist_ok=True)
    jobs = json.load(open(jobs_path, encoding="utf-8"))
    todo = [j for j in jobs if not os.path.exists(os.path.join(out_dir, j["id"] + ".png"))]
    print(f"{len(todo)} / {len(jobs)} 件を生成", flush=True)
    if not todo:
        return
    torch.set_num_threads(os.cpu_count() or 4)

    # 1) プロンプトのベクトル化
    enc = StableDiffusionXLPipeline.from_pretrained(model_dir, unet=None, vae=None, dtype=torch.float32, use_safetensors=True)
    embeds = {}
    with torch.no_grad():
        for j in todo:
            embeds[j["id"]] = enc.encode_prompt(j["prompt"] + QUALITY, device="cpu", num_images_per_prompt=1,
                                                do_classifier_free_guidance=not fast, negative_prompt=j.get("negative", NEGATIVE))
    del enc
    gc.collect()

    # 2) 画像生成（Lightning LoRA を結合、CFG なし）
    pipe = StableDiffusionXLPipeline.from_pretrained(model_dir, text_encoder=None, text_encoder_2=None, tokenizer=None,
                                                     tokenizer_2=None, dtype=torch.float32, use_safetensors=True)
    if fast:
        pipe.load_lora_weights(lora_path)
        pipe.fuse_lora()
        pipe.unload_lora_weights()
        pipe.scheduler = EulerDiscreteScheduler.from_config(pipe.scheduler.config, timestep_spacing="trailing")
    else:
        pipe.scheduler = DPMSolverMultistepScheduler.from_config(pipe.scheduler.config, use_karras_sigmas=True)
    i2i = StableDiffusionXLImg2ImgPipeline(**pipe.components)
    pipe.vae.enable_tiling()
    pipe.set_progress_bar_config(disable=True)
    for j in todo:
        t = time.time()
        pe, npe, ppe, nppe = embeds[j["id"]]
        g = torch.Generator("cpu").manual_seed(int(j.get("seed", 0)))
        kw = dict(prompt_embeds=pe, pooled_prompt_embeds=ppe, num_inference_steps=steps, generator=g,
                  guidance_scale=0.0 if fast else float(j.get("cfg", 5.0)))
        if not fast:
            kw.update(negative_prompt_embeds=npe, negative_pooled_prompt_embeds=nppe)
        with torch.no_grad():
            if j.get("init"):  # 表情差分など: 元画像から img2img（構図と人物を保つ）
                init = Image.open(os.path.join(out_dir, j["init"] + ".png")).convert("RGB")
                img = i2i(image=init, strength=float(j.get("strength", 0.5)), **kw).images[0]
                if j.get("face_only"):  # 顔のまわりだけ差し替え、髪・服・構図は元画像のまま保つ
                    w, h = init.size
                    cx, cy, rx, ry = j.get("face_box", [0.5, 0.32, 0.36, 0.24])
                    mask = Image.new("L", (w, h), 0)
                    ImageDraw.Draw(mask).ellipse(((cx - rx) * w, (cy - ry) * h, (cx + rx) * w, (cy + ry) * h), fill=255)
                    img = Image.composite(img, init, mask.filter(ImageFilter.GaussianBlur(w * 0.04)))
            else:
                img = pipe(width=int(j.get("w", 832)), height=int(j.get("h", 1216)), **kw).images[0]
        img.save(os.path.join(out_dir, j["id"] + ".png"))
        print(f"{j['id']}: {time.time() - t:.0f}s", flush=True)


if __name__ == "__main__":
    main()

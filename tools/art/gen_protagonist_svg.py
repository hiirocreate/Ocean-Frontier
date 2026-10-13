import math, sys

OUT = sys.argv[1]
LINE = "#1A1A2E"
C = {
    "skin": ("#F4CDA8", "#D9967A"),
    "jacket": ("#1C3A66", "#0A192F"),
    "cape": ("#0A192F", "#040B17"),
    "lining": ("#1E4C7A", "#12345A"),
    "hair": ("#2B4C7E", "#142849"),
    "pants": ("#22314F", "#111B30"),
    "shirt": ("#EEF2F7", "#B5C3D6"),
    "gold": ("#FFD700", "#C99A00"),
    "belt": ("#4A3426", "#2B1D14"),
    "boots": ("#2A2230", "#15111A"),
}
defs, body = [], []
n = 0


def part(d, col, shadows=(), lw=4, extra="", hi=None, transform=""):
    """ベース面・クリップされた影面（2度塗り）・ハイライト・輪郭線を別レイヤーで描く"""
    global n
    n += 1
    pid = f"p{n}"
    defs.append(f'<path id="{pid}" d="{d}"/>')
    base, shade = C[col] if col in C else (col, col)
    tr = f' transform="{transform}"' if transform else ""
    g = [f'<g{tr}>', f'<use xlink:href="#{pid}" href="#{pid}" fill="{base}"/>']
    if shadows or hi:
        defs.append(f'<clipPath id="c{pid}"><use xlink:href="#{pid}" href="#{pid}"/></clipPath>')
        g.append(f'<g clip-path="url(#c{pid})">')
        for s in shadows:
            g.append(f'<path d="{s}" fill="{shade}"/>')
        if hi:
            for h, hc in hi:
                g.append(f'<path d="{h}" fill="{hc}"/>')
        g.append("</g>")
    g.append(extra)
    g.append(f'<use xlink:href="#{pid}" href="#{pid}" fill="none" stroke="{LINE}" stroke-width="{lw}" stroke-linejoin="round" stroke-linecap="round"/>')
    g.append("</g>")
    body.append("\n".join(g))


def line(d, w=2.5, col=LINE, extra=""):
    body.append(f'<path d="{d}" fill="none" stroke="{col}" stroke-width="{w}" stroke-linecap="round" stroke-linejoin="round"{extra}/>')


def capsule(bx, by, ang, L, w, off=0.0):
    a = math.radians(ang)
    ux, uy = math.cos(a), math.sin(a)
    nx, ny = -uy, ux
    bx, by = bx + nx * off, by + ny * off
    r = w / 2
    tx, ty = bx + ux * L, by + uy * L
    p = lambda x, y: f"{x:.1f} {y:.1f}"
    return (f"M {p(bx + nx * r, by + ny * r)} L {p(tx + nx * r, ty + ny * r)} "
            f"A {r:.1f} {r:.1f} 0 0 0 {p(tx - nx * r, ty - ny * r)} L {p(bx - nx * r, by - ny * r)} Z")


def star(cx, cy, r1, r2, k=5, rot=-90):
    pts = []
    for i in range(k * 2):
        r = r1 if i % 2 == 0 else r2
        a = math.radians(rot + i * 180 / k)
        pts.append(f"{cx + r * math.cos(a):.1f} {cy + r * math.sin(a):.1f}")
    return "M " + " L ".join(pts) + " Z"


def ellipse(cx, cy, rx, ry):
    a = f"A {rx} {ry} 0 0 1"
    return f"M {cx - rx} {cy} {a} {cx} {cy - ry} {a} {cx + rx} {cy} {a} {cx} {cy + ry} {a} {cx - rx} {cy} Z"


# ---- 背景の海風（流線） ----
for d, o in [("M 455 236 C 510 230 555 238 596 226", .6), ("M 450 430 C 505 420 552 430 598 418", .5),
             ("M 470 640 C 520 630 560 640 598 632", .45), ("M 8 560 C 50 552 90 558 128 548", .35),
             ("M 230 40 C 300 30 380 34 460 22", .35)]:
    line(d, 3, "#00F2FE", f' opacity="{o}"')

# ---- マント（背面・海風で右後方へなびく） ----
cape = ("M 268 288 C 320 268 395 268 420 290 C 470 300 530 292 594 262 L 562 318 L 598 346 "
        "C 548 402 545 502 576 602 L 516 586 L 536 692 C 482 656 440 652 404 694 C 398 600 394 520 392 460 Z")
part(cape, "cape", [
    "M 430 300 C 470 360 482 450 472 560 L 516 586 C 500 480 494 380 468 305 Z",
    "M 540 330 C 518 420 520 500 536 600 L 576 602 C 546 502 548 402 598 346 Z",
    "M 392 460 C 400 560 404 640 404 694 C 420 670 432 660 445 655 C 430 600 420 520 400 440 Z",
])
part("M 420 290 C 470 300 530 292 594 262 L 562 318 C 522 332 470 330 430 314 Z", "lining",
     ["M 500 300 C 530 296 560 284 594 262 L 562 318 C 540 322 520 324 500 324 Z"], lw=3)
line("M 422 292 C 470 302 530 294 590 265", 5, "#FFD700")

# ---- 脚 ----
part("M 291 512 L 341 512 L 322 800 L 252 800 Z", "pants", ["M 318 512 L 341 512 L 322 800 L 296 800 Z"])
part("M 338 512 L 388 506 L 412 800 L 340 800 Z", "pants", ["M 368 508 L 388 506 L 412 800 L 384 800 Z"])
line("M 318 600 L 312 640", 2.5)
line("M 372 610 L 378 650", 2.5)

# ---- 胴体（ジャケット） ----
torso = "M 262 292 C 300 274 362 274 404 292 L 410 330 C 402 400 394 450 388 508 L 290 514 C 288 450 280 380 262 292 Z"
part(torso, "jacket", ["M 352 286 L 404 292 L 410 330 C 402 400 394 450 388 508 L 344 510 C 360 440 366 360 352 286 Z",
                       "M 262 292 C 285 300 300 320 306 340 L 270 330 Z"])
part("M 305 284 L 346 282 L 323 346 Z", "shirt", ["M 330 283 L 346 282 L 323 346 Z"], lw=3)
line("M 323 346 L 318 508", 3)
line("M 312 350 L 307 506", 3, "#FFD700")
for y in (380, 420, 460):
    part(ellipse(331, y, 5, 5), "gold", [], lw=2)
part("M 298 286 C 306 268 318 264 330 276 L 318 302 Z", "jacket", [], lw=3)
part("M 342 276 C 358 266 374 272 384 288 L 352 304 Z", "jacket", ["M 360 272 C 370 274 378 280 384 288 L 368 296 Z"], lw=3)
# ベルト
part("M 289 494 L 389 487 L 388 514 L 290 520 Z", "belt", ["M 350 490 L 389 487 L 388 514 L 350 517 Z"], lw=3)
part("M 308 490 L 334 489 L 334 518 L 308 519 Z", "gold", ["M 324 489 L 334 489 L 334 518 L 324 518 Z"], lw=3)

# ---- 左腕（画面右・後ろに引いて拳を握る） ----
part("M 392 290 C 422 298 440 345 444 405 L 412 413 C 408 366 398 336 382 314 Z", "jacket",
     ["M 420 300 C 436 330 442 370 444 405 L 428 409 C 428 370 422 330 410 305 Z"])
part("M 411 404 L 444 399 L 434 478 L 404 481 Z", "jacket", ["M 428 401 L 444 399 L 434 478 L 420 479 Z"])
part("M 402 470 L 435 466 L 434 484 L 402 487 Z", "gold", ["M 424 467 L 435 466 L 434 484 L 424 485 Z"], lw=3)
part("M 402 486 C 398 504 408 516 420 516 C 433 516 441 504 436 484 Z", "skin", ["M 424 486 L 436 484 C 441 504 433 516 422 516 Z"], lw=3)
line("M 410 498 L 428 497", 2)

# ---- 首・顔 ----
part("M 312 236 L 350 234 L 352 290 L 310 292 Z", "skin", ["M 312 236 L 350 234 L 352 264 C 334 270 320 264 312 256 Z"], lw=3)
face = "M 280 128 C 270 165 270 200 282 222 C 292 240 300 250 310 252 C 330 252 355 238 372 218 L 384 190 C 390 160 386 130 380 118 Z"
part(face, "skin", ["M 384 186 L 372 218 C 360 232 345 244 330 250 C 348 236 360 214 366 186 Z",
                    "M 270 140 L 392 128 L 392 156 L 270 168 Z"])
part("M 376 176 C 392 168 400 190 393 203 C 389 211 381 210 376 203 Z", "skin", ["M 383 182 C 390 186 391 196 386 202 L 380 196 Z"], lw=3)
# 目（近い目・遠い目）
part("M 325 180 C 335 172 355 172 366 180 C 361 195 340 199 327 192 Z", "#FFFFFF", [], lw=2)
part(ellipse(344, 186, 9, 11), "#12C6E8", ["M 334 170 L 354 170 L 354 184 L 334 186 Z"], lw=1.5)
part(ellipse(344, 188, 4, 6), "#0A192F", [], lw=0.1)
part(ellipse(340, 181, 3, 3), "#FFFFFF", [], lw=0.1)
part("M 322 182 C 332 167 357 167 369 178 L 367 183 C 355 174 334 174 324 186 Z", LINE, [], lw=1)
part("M 283 182 C 289 176 300 175 307 180 C 304 192 292 195 285 190 Z", "#FFFFFF", [], lw=2)
part(ellipse(297, 186, 6, 10), "#12C6E8", ["M 288 172 L 306 172 L 306 184 L 288 186 Z"], lw=1.5)
part(ellipse(297, 188, 2.5, 5), "#0A192F", [], lw=0.1)
part(ellipse(295, 182, 2, 2), "#FFFFFF", [], lw=0.1)
part("M 280 185 C 287 172 302 171 310 178 L 308 182 C 299 176 289 178 282 188 Z", LINE, [], lw=1)
part("M 324 164 C 338 156 356 156 369 163 L 367 168 C 354 162 339 162 327 170 Z", LINE, [], lw=1)
part("M 282 166 C 290 160 300 159 308 162 L 307 166 C 299 164 291 165 285 170 Z", LINE, [], lw=1)
line("M 312 197 L 305 212 L 313 214", 2.5)
part("M 304 229 C 313 238 324 237 330 227 C 320 231 312 231 304 229 Z", "#8C3A3A", [], lw=2)
line("M 352 210 L 356 204 M 359 211 L 363 205 M 366 212 L 370 206", 2, "#E07A6A")

# ---- 髪（海風で右後方へなびく） ----
hair = ("M 272 168 C 256 130 270 88 310 72 C 345 58 392 66 414 92 L 472 76 L 438 108 L 522 110 L 444 132 "
        "L 502 160 L 432 156 L 462 202 L 410 182 L 402 224 L 388 186 C 386 165 380 148 370 140 L 360 168 "
        "L 346 140 L 330 172 L 318 138 L 300 170 L 292 140 Z")
part(hair, "hair", [
    "M 414 92 L 472 76 L 438 108 L 522 110 L 444 132 L 502 160 L 432 156 L 462 202 L 410 182 L 402 224 L 388 186 C 386 165 380 148 370 140 C 392 134 406 116 414 92 Z",
    "M 292 140 L 300 170 L 318 138 L 330 172 L 346 140 L 360 168 L 370 140 C 340 128 312 128 292 140 Z",
], hi=[("M 284 112 C 304 88 346 78 384 88 L 380 98 C 346 90 310 98 290 120 Z", "#00F2FE"),
       ("M 440 118 L 500 113 L 446 124 Z", "#00F2FE")])

# ---- マント前垂れ（画面右肩） ----
part("M 380 280 C 400 270 420 278 428 292 C 442 320 448 352 474 382 L 432 362 C 416 336 402 312 380 300 Z", "cape",
     ["M 410 282 C 428 300 440 340 474 382 L 452 372 C 432 340 424 306 410 282 Z"], lw=3)
part(star(282, 294, 15, 7), "gold", [star(286, 298, 8, 4)], lw=3)

# ---- 右腕（手前へ伸ばす・パース） ----
part("M 292 300 C 262 284 240 298 226 324 L 158 392 L 212 472 C 242 432 264 396 288 360 Z", "jacket",
     ["M 288 360 C 264 396 242 432 212 472 L 196 448 C 228 410 250 372 272 330 C 280 340 286 350 288 360 Z",
      "M 292 300 C 270 292 252 296 240 310 C 258 304 276 304 292 316 Z"])
line("M 236 340 C 228 360 222 372 210 386", 2.5)

# 掌の光（セル調の段階的なリング）
for r, o in [(112, .12), (84, .2), (60, .32)]:
    body.append(f'<circle cx="118" cy="408" r="{r}" fill="#00F2FE" opacity="{o}"/>')

# 袖口
part(ellipse(0, 0, 40, 54), "jacket", ["M 10 -60 L 50 -60 L 50 60 L 6 60 C 22 30 22 -30 10 -60 Z"], transform="translate(186 434) rotate(-38)")
part(ellipse(0, 0, 33, 46), "gold", ["M 8 -50 L 40 -50 L 40 50 L 6 50 C 18 25 18 -25 8 -50 Z"], lw=3, transform="translate(182 432) rotate(-38)")

# 手（手前で大きく）
fingers = [(104, 404, -118, 54, 21), (124, 394, -103, 66, 22), (145, 392, -88, 63, 21), (162, 400, -73, 50, 19)]
for bx, by, ang, L, w in fingers:
    part(capsule(bx, by, ang, L, w), "skin", [capsule(bx, by, ang, L + 2, w, w * 0.62)], lw=3.5)
part(capsule(164, 440, -28, 44, 24), "skin", [capsule(164, 440, -28, 46, 24, 15)], lw=3.5)
palm = "M 94 398 C 120 386 152 388 170 402 L 174 456 C 152 474 116 476 100 462 C 88 442 86 418 94 398 Z"
part(palm, "skin", ["M 150 392 C 160 395 166 398 170 402 L 174 456 C 166 464 158 468 150 470 C 160 440 158 412 150 392 Z"], lw=4)
line("M 104 430 C 118 420 138 418 156 424", 2)
line("M 110 448 C 124 440 140 440 154 446", 2)

# 星痕（掌のゴールド）と魔力の輝き
part(star(130, 432, 16, 7), "gold", [star(134, 436, 9, 4)], lw=2.5)
for cx, cy, r, col in [(50, 330, 16, "#00F2FE"), (212, 330, 11, "#FFD700"), (48, 486, 12, "#FFD700"),
                       (88, 296, 9, "#00F2FE"), (196, 520, 9, "#00F2FE")]:
    part(star(cx, cy, r, r * 0.28, 4, -90), col, [], lw=2)

svg = f'''<?xml version="1.0" encoding="UTF-8"?>
<!-- Ocean Frontier: LAST TIDE — 主人公（青年層 16〜19歳・中性的ベースデザイン）セルアニメ調立ち絵
     輪郭 #1A1A2E / 影は2度塗り（ベース面とクリップした影面を別レイヤー化）/ グラデーション不使用
     基調色: 深海ブルー #0A192F・星痕ゴールド #FFD700・魔力ライトブルー #00F2FE
     生成元: tools/art/gen_protagonist_svg.py（独自制作・CC0扱い） -->
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="600" height="800" viewBox="0 0 600 800">
<defs>
{chr(10).join(defs)}
</defs>
{chr(10).join(body)}
</svg>
'''
open(OUT, "w").write(svg)
print("parts", n, "bytes", len(svg))

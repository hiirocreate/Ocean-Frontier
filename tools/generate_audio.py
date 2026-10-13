#!/usr/bin/env python3
"""効果音・環境音・BGMを数式で合成して assets/audio/ に WAV で書き出す（外部素材なし・本プロジェクト独自）。
使い方: python3 tools/generate_audio.py
"""
import os
import wave

import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
rng = np.random.default_rng(20261013)


def t_axis(sec):
    return np.arange(int(SR * sec)) / SR


def lowpass(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc = (1 - a) * x[i] + a * acc
        y[i] = acc
    return y


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def env(n, attack=0.005, release=0.2, sustain_level=1.0):
    t = np.arange(n) / SR
    e = np.minimum(1.0, t / max(attack, 1e-4))
    rel = np.exp(-np.maximum(0, t - attack) / max(release, 1e-4))
    return e * (sustain_level * rel + (1 - sustain_level) * 0)


def tone(freq, sec, kind="sine", decay=0.4, attack=0.005):
    t = t_axis(sec)
    if kind == "sine":
        w = np.sin(2 * np.pi * freq * t)
    elif kind == "tri":
        w = 2 * np.abs(2 * ((t * freq) % 1) - 1) - 1
    else:
        w = np.sign(np.sin(2 * np.pi * freq * t)) * 0.6
    return w * env(len(t), attack, decay)


def norm(x, peak=0.8):
    m = np.max(np.abs(x)) or 1.0
    return x / m * peak


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[: len(p)] += p
    return out


def place(buf, part, at):
    i = int(at * SR)
    end = min(len(buf), i + len(part))
    buf[i:end] += part[: end - i]


def loopable(x, fade=0.5):
    """末尾を先頭にクロスフェードしてループの継ぎ目をなくす"""
    n = int(SR * fade)
    head = x[:n].copy()
    tail = x[-n:]
    ramp = np.linspace(0, 1, n)
    x = x[:-n].copy()
    x[:n] = head * ramp + tail * (1 - ramp)
    return x


def save(name, x, peak=0.8):
    x = norm(x, peak)
    data = (np.clip(x, -1, 1) * 32767).astype("<i2")
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print("wrote", name, f"{len(x) / SR:.1f}s")


def noise(sec):
    return rng.uniform(-1, 1, int(SR * sec))


# ---------------- 効果音 ----------------
def sfx_collect():
    n = noise(0.45)
    splash = lowpass(highpass(n, 400), 3000) * env(len(n), 0.01, 0.12)
    pluck = mix(tone(660, 0.35, "tri", 0.15) * 0.5, tone(990, 0.3, "sine", 0.1) * 0.3)
    return mix(splash, np.concatenate([np.zeros(int(SR * 0.08)), pluck]))


def sfx_build():
    buf = np.zeros(int(SR * 0.9))
    for i, at in enumerate([0.0, 0.28, 0.56]):
        thump = mix(tone(110 - i * 8, 0.18, "sine", 0.06), lowpass(noise(0.12), 1800) * env(int(SR * 0.12), 0.001, 0.03))
        place(buf, thump, at)
    return buf


def sfx_craft():
    parts = [tone(f, 0.6, "sine", 0.25) * a for f, a in [(1200, 0.6), (1840, 0.35), (2730, 0.2)]]
    return mix(mix(*parts), np.concatenate([np.zeros(int(SR * 0.12)), tone(1500, 0.4, "sine", 0.2) * 0.4]))


def sfx_click():
    return mix(tone(1800, 0.05, "sine", 0.015), lowpass(noise(0.03), 4000) * env(int(SR * 0.03), 0.001, 0.008) * 0.3)


def sfx_hit():
    return lowpass(noise(0.3), 900) * env(int(SR * 0.3), 0.001, 0.06) + tone(80, 0.3, "sine", 0.08)


def sfx_success():
    buf = np.zeros(int(SR * 1.0))
    for i, f in enumerate([523.25, 659.25, 783.99, 1046.5]):
        place(buf, tone(f, 0.6, "tri", 0.3) * 0.6, i * 0.09)
    return buf


def sfx_fail():
    t = t_axis(0.7)
    f = 300 * np.exp(-t * 1.5)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * env(len(t), 0.01, 0.35)


def sfx_alert():
    buf = np.zeros(int(SR * 1.4))
    for at in [0.0, 0.35]:
        bell = mix(*[tone(f, 1.0, "sine", 0.5) * a for f, a in [(880, 0.6), (2210, 0.25), (3520, 0.1)]])
        place(buf, bell, at)
    return buf


# ---------------- 環境音（ループ） ----------------
def amb_ocean():
    sec = 8.5
    t = t_axis(sec)
    base = lowpass(noise(sec), 500)
    swell = 0.55 + 0.45 * np.sin(2 * np.pi * t / 4.25) ** 2
    foam = lowpass(highpass(noise(sec), 1500), 5000) * (0.15 + 0.2 * np.sin(2 * np.pi * t / 4.25 + 1.2) ** 8)
    return loopable(base * swell + foam)


def amb_rain():
    sec = 6.5
    n = highpass(noise(sec), 2000)
    drops = np.zeros(int(SR * sec))
    for _ in range(140):
        at = rng.uniform(0, sec - 0.05)
        place(drops, tone(rng.uniform(2500, 5000), 0.03, "sine", 0.01) * rng.uniform(0.2, 0.6), at)
    return loopable(n * 0.5 + drops)


def amb_storm():
    sec = 9.5
    t = t_axis(sec)
    wind = lowpass(highpass(noise(sec), 200), 900) * (0.5 + 0.5 * np.sin(2 * np.pi * t / 3.1) ** 2)
    rumble = lowpass(noise(sec), 120) * 2.5
    rain = highpass(noise(sec), 2500) * 0.4
    return loopable(wind + rumble + rain)


# ---------------- BGM（ループ） ----------------
def note(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


def pad(freqs, sec):
    t = t_axis(sec)
    x = sum(np.sin(2 * np.pi * f * t) + 0.3 * np.sin(2 * np.pi * f * 2.003 * t) for f in freqs)
    e = np.minimum(1, t / 0.8) * np.minimum(1, (sec - t) / 0.8)
    return x * e


def bgm(chords, bpm, arp_pattern, sec_per_chord, name, bright=1.0):
    beat = 60.0 / bpm
    total = sec_per_chord * len(chords)
    buf = np.zeros(int(SR * total) + SR)
    for ci, ch in enumerate(chords):
        start = ci * sec_per_chord
        place(buf, pad([note(m) for m in ch], sec_per_chord) * 0.12, start)
        steps = int(sec_per_chord / (beat / 2))
        for s in range(steps):
            m = ch[arp_pattern[s % len(arp_pattern)] % len(ch)] + 12
            place(buf, tone(note(m), beat * 1.5, "tri", beat * 0.6 * bright) * 0.22, start + s * beat / 2)
        place(buf, tone(note(ch[0] - 12), sec_per_chord, "sine", sec_per_chord * 0.5) * 0.25, start)
    return loopable(buf[: int(SR * total) + int(SR * 0.6)], 0.6)


def bgm_combat():
    bpm = 132
    beat = 60.0 / bpm
    sec = beat * 32
    buf = np.zeros(int(SR * sec) + SR)
    for i in range(32):
        at = i * beat
        if i % 2 == 0:
            place(buf, mix(tone(55, 0.25, "sine", 0.08), lowpass(noise(0.08), 300) * 0.5 * env(int(SR * 0.08), 0.001, 0.02)), at)
        else:
            place(buf, highpass(noise(0.12), 2500) * env(int(SR * 0.12), 0.001, 0.03) * 0.5, at)
        bass = [45, 45, 48, 43][(i // 8) % 4]
        place(buf, tone(note(bass), beat * 0.9, "square", beat * 0.4) * 0.18, at)
    return loopable(buf[: int(SR * sec) + int(SR * 0.4)], 0.4)


if __name__ == "__main__":
    for fn in [sfx_collect, sfx_build, sfx_craft, sfx_click, sfx_hit, sfx_success, sfx_fail, sfx_alert]:
        save(fn.__name__, fn(), 0.7)
    save("amb_ocean", amb_ocean(), 0.5)
    save("amb_rain", amb_rain(), 0.4)
    save("amb_storm", amb_storm(), 0.55)
    # 昼: Cメジャー系のゆったりした分散和音 / 夜: Aマイナー系
    save("bgm_day", bgm([[60, 64, 67, 71], [57, 60, 64, 67], [53, 57, 60, 64], [55, 59, 62, 65]], 84, [0, 1, 2, 3, 2, 1], 6.0, "day"), 0.5)
    save("bgm_night", bgm([[57, 60, 64], [53, 57, 60], [48, 52, 55], [52, 55, 59]], 66, [0, 2, 1, 2], 7.0, "night", 1.5), 0.45)
    save("bgm_combat", bgm_combat(), 0.55)

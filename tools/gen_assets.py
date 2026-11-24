# -*- coding: utf-8 -*-
"""生成占位音效 / BGM（WAV）与占位像素图。

正式资源（OGG 音乐、Tabler PNG、像素字体）到位后替换，清单见 assets/MISSING.md。
"""
import math
import os
import struct
import wave

import numpy as np
from PIL import Image, ImageDraw

ROOT = r"E:\MyGame\newGame1"
MUSIC = os.path.join(ROOT, "assets", "music")
SFX = os.path.join(ROOT, "assets", "sfx")
SPRITE = os.path.join(ROOT, "assets", "sprite")
TEMP = os.path.join(ROOT, "assets", "_temp")

for d in (MUSIC, SFX, SPRITE, TEMP):
    os.makedirs(d, exist_ok=True)

SR = 22050


def write_wav(path, samples, sr=SR):
    samples = np.clip(samples, -0.98, 0.98)
    data = (samples * 32767).astype(np.int16).tobytes()
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(data)


def midi(m):
    return 440.0 * (2.0 ** ((m - 69) / 12.0))


def osc(freq, dur, kind="square", amp=0.25, attack=0.004, release=0.01, sr=SR):
    n = max(1, int(sr * dur))
    t = np.arange(n) / sr
    ph = 2 * np.pi * freq * t
    if kind == "sine":
        w = np.sin(ph)
    elif kind == "square":
        w = np.sign(np.sin(ph))
    elif kind == "saw":
        w = 2.0 * (t * freq - np.floor(0.5 + t * freq))
    elif kind == "tri":
        w = 2.0 * np.abs(2.0 * (t * freq - np.floor(0.5 + t * freq))) - 1.0
    else:
        w = np.sin(ph)
    env = np.ones(n)
    a = max(1, int(sr * attack))
    env[:a] = np.linspace(0, 1, a)
    r = max(1, int(sr * release))
    env[-r:] *= np.linspace(1, 0, r)
    return w * env * amp


def add_note(buf, beat, dur, m, kind="square", amp=0.2, bpm=120.0, sr=SR):
    start = int(beat * 60.0 / bpm * sr)
    note = osc(midi(m), dur * 60.0 / bpm, kind, amp, sr=sr)
    end = min(len(buf), start + len(note))
    if start >= len(buf):
        return
    buf[start:end] += note[: end - start]


def add_noise(buf, beat, dur, amp=0.1, bpm=120.0, sr=SR, decay=0.6):
    start = int(beat * 60.0 / bpm * sr)
    n = int(dur * 60.0 / bpm * sr)
    noise = np.random.uniform(-1, 1, n)
    env = np.exp(-np.linspace(0, 6, n))
    seg = noise * env * amp
    end = min(len(buf), start + n)
    if start >= len(buf):
        return
    buf[start:end] += seg[: end - start]


def add_kick(buf, beat, bpm=120.0, sr=SR, amp=0.55):
    start = int(beat * 60.0 / bpm * sr)
    n = int(0.14 * sr)
    t = np.arange(n) / sr
    freq = 120 * np.exp(-28 * t) + 45
    w = np.sin(2 * np.pi * np.cumsum(freq) / sr) * np.exp(-14 * t) * amp
    end = min(len(buf), start + n)
    if start >= len(buf):
        return
    buf[start:end] += w[: end - start]


PROGRESSIONS = {
    "menu": [(57, 60, 64), (53, 57, 60), (60, 64, 67), (55, 59, 62)],
    "talent": [(57, 60, 64), (55, 59, 62), (53, 57, 60), (55, 58, 62)],
    "battle1": [(45, 48, 52), (41, 45, 48), (43, 46, 50), (45, 48, 52)],
    "battle2": [(45, 48, 52), (45, 48, 52), (41, 45, 48), (43, 46, 50)],
    "battle3": [(45, 48, 52), (44, 47, 51), (43, 46, 50), (41, 44, 48)],
    "fail": [(45, 48, 52), (44, 47, 51), (42, 45, 49), (40, 43, 47)],
}


def build_track(name, bpm, bars, arp, bass, drums, seed, lead=True):
    np.random.seed(seed)
    arp_kind, bass_kind = arp, bass
    beats = bars * 4
    total = int(beats * 60.0 / bpm * SR)
    buf = np.zeros(total)
    prog = PROGRESSIONS[name]
    for bar in range(bars):
        chord = prog[bar % len(prog)]
        base = bar * 4
        if drums >= 1:
            for b in range(4):
                add_kick(buf, base + b, bpm)
        if drums >= 2:
            for b in range(4):
                add_noise(buf, base + b + 0.5, 0.18, 0.06, bpm)
        if drums >= 3:
            for b in range(8):
                add_noise(buf, base + b * 0.5, 0.09, 0.05, bpm, decay=0.4)
        # 低音
        add_note(buf, base, 1.9, chord[0] - 12, bass_kind, 0.20, bpm)
        add_note(buf, base + 2, 1.9, chord[0] - 12, bass_kind, 0.16, bpm)
        # 琶音
        seq = [chord[0], chord[2], chord[1] + 12, chord[2], chord[1], chord[0] + 12]
        for i in range(8):
            add_note(
                buf,
                base + i * 0.5,
                0.42,
                seq[i % len(seq)],
                arp_kind,
                0.11 if lead else 0.07,
                bpm,
            )
        if lead:
            lead_seq = [chord[2] + 12, chord[1] + 12, chord[0] + 12, chord[1] + 12]
            for i in range(4):
                add_note(buf, base + i, 0.85, lead_seq[i % len(lead_seq)], "sine", 0.09, bpm)
    # 首尾淡入淡出，循环不爆音
    fade = int(0.02 * SR)
    buf[:fade] *= np.linspace(0, 1, fade)
    buf[-fade:] *= np.linspace(1, 0, fade)
    peak = np.max(np.abs(buf)) or 1.0
    return buf / peak * 0.75


def build_sfx():
    sr = 44100
    out = {}

    # 打字：极短的咔哒
    t = np.linspace(0, 0.018, int(sr * 0.018))
    click = np.sin(2 * np.pi * 1400 * t) * np.exp(-90 * t) * 0.5
    click += np.random.uniform(-1, 1, len(t)) * np.exp(-180 * t) * 0.35
    out["type"] = click

    # 空键：更轻
    out["empty"] = click * 0.35

    # 整句完成：两声上行
    n1 = osc(880, 0.07, "square", 0.28, sr=sr)
    n2 = osc(1320, 0.12, "square", 0.24, sr=sr)
    out["complete"] = np.concatenate([n1, n2])

    # 暴击：金属高音
    out["crit"] = np.concatenate(
        [
            osc(1760, 0.08, "sine", 0.35, sr=sr),
            osc(2349, 0.08, "sine", 0.3, sr=sr),
            osc(2637, 0.16, "sine", 0.25, sr=sr),
        ]
    )

    # 失误：低频咚
    t = np.linspace(0, 0.18, int(sr * 0.18))
    out["miss"] = np.sin(2 * np.pi * np.cumsum(110 * np.exp(-6 * t) + 55) / sr) * np.exp(-9 * t) * 0.6

    # 点击/购买
    out["click"] = np.concatenate([osc(660, 0.03, "square", 0.2, sr=sr), osc(990, 0.05, "square", 0.15, sr=sr)])
    out["buy"] = np.concatenate([osc(880, 0.05, "sine", 0.3, sr=sr), osc(1320, 0.14, "sine", 0.25, sr=sr)])

    # 受击
    t = np.linspace(0, 0.22, int(sr * 0.22))
    out["hurt"] = np.sin(2 * np.pi * np.cumsum(180 * np.exp(-10 * t) + 60) / sr) * np.exp(-10 * t) * 0.7

    # 清场
    out["clear"] = np.concatenate(
        [osc(m, 0.1, "square", 0.18, sr=sr) for m in [523, 659, 784, 1046]]
    )

    # 失败
    out["fail"] = np.concatenate(
        [osc(m, 0.22, "saw", 0.18, sr=sr) for m in [392, 330, 262, 196]]
    )

    # 胜利
    out["win"] = np.concatenate(
        [osc(m, 0.16, "square", 0.2, sr=sr) for m in [523, 659, 784, 1046, 1318]]
    )
    return out


def build_music():
    tracks = {
        "music_menu": dict(name="menu", bpm=100, bars=4, arp="tri", bass="tri", drums=0, seed=1, lead=False),
        "music_battle_L1": dict(name="battle1", bpm=124, bars=4, arp="square", bass="saw", drums=1, seed=2, lead=False),
        "music_battle_L2": dict(name="battle2", bpm=142, bars=4, arp="square", bass="saw", drums=2, seed=3, lead=True),
        "music_battle_L3": dict(name="battle3", bpm=162, bars=4, arp="saw", bass="saw", drums=3, seed=4, lead=True),
        "music_fail": dict(name="fail", bpm=76, bars=4, arp="tri", bass="tri", drums=0, seed=5, lead=False),
        "music_talent": dict(name="talent", bpm=104, bars=4, arp="tri", bass="tri", drums=0, seed=6, lead=True),
    }
    out = {}
    for fname, cfg in tracks.items():
        out[fname] = build_track(**cfg)
    return out


def build_sprites():
    def block(path, size, label, color):
        img = Image.new("RGBA", size, color)
        d = ImageDraw.Draw(img)
        d.rectangle([0, 0, size[0] - 1, size[1] - 1], outline=(255, 255, 255, 160))
        d.text((4, size[1] // 2 - 4), label, fill=(255, 255, 255, 220))
        img.save(path)

    block(os.path.join(SPRITE, "hero_placeholder.png"), (64, 64), "HERO", (36, 44, 58, 255))
    block(os.path.join(SPRITE, "account_placeholder.png"), (48, 48), "ACC", (58, 44, 44, 255))
    block(os.path.join(SPRITE, "keyboard_placeholder.png"), (220, 46), "KEYBOARD", (30, 34, 44, 255))
    block(os.path.join(TEMP, "icon_placeholder.png"), (48, 48), "ICON", (44, 44, 44, 255))
    print("sprites: 4 placeholders")


def main():
    np.random.seed(0)
    sfx = build_sfx()
    for name, data in sfx.items():
        path = os.path.join(SFX, name + ".wav")
        write_wav(path, data, 44100 if name in ("type", "empty", "click") else 22050)
        print("sfx", path, round(len(data) / 44100, 2), "s")
    music = build_music()
    for name, data in music.items():
        path = os.path.join(MUSIC, name + ".wav")
        write_wav(path, data)
        print("music", path, round(len(data) / SR, 2), "s")
    build_sprites()


if __name__ == "__main__":
    main()

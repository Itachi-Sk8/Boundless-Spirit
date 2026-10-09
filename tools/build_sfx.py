"""Generates the game's retro sound effects (sfxr style) as WAV files in audio/sfx/.

Run from the repo root:   python tools/build_sfx.py
Placeholder sounds made in code, so there are no licenses to track. Standard library only.
"""
import math
import os
import random
import struct
import wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RATE = 22050


def tone(start_hz, end_hz, seconds, shape="square", duty=0.5, volume=0.5, attack=0.005,
         curve=1.0, vibrato=0.0):
    """A tone sweeping from start_hz to end_hz with a quick attack and a decaying tail."""
    n = int(seconds * RATE)
    out, phase = [], 0.0
    for i in range(n):
        t = i / n
        hz = start_hz + (end_hz - start_hz) * (t ** curve)
        if vibrato:
            hz *= 1.0 + vibrato * math.sin(i / RATE * 2 * math.pi * 14)
        phase = (phase + hz / RATE) % 1.0
        if shape == "square":
            s = 1.0 if phase < duty else -1.0
        elif shape == "triangle":
            s = 4 * abs(phase - 0.5) - 1
        elif shape == "saw":
            s = 2 * phase - 1
        else:
            s = math.sin(phase * 2 * math.pi)
        env = min(1.0, i / max(1, attack * RATE)) * (1.0 - t) ** 1.5
        out.append(s * env * volume)
    return out


def noise(seconds, volume=0.5, smooth=0.5, seed=1, decay=1.5):
    """Low-passed white noise; `smooth` near 1 is darker and duller."""
    rng = random.Random(seed)
    n = int(seconds * RATE)
    out, last = [], 0.0
    for i in range(n):
        last = last * smooth + rng.uniform(-1, 1) * (1 - smooth)
        out.append(last * volume * (1.0 - i / n) ** decay * 2.5)
    return out


def mix(*tracks, offsets=None):
    offsets = offsets or [0.0] * len(tracks)
    length = max(int(o * RATE) + len(t) for t, o in zip(tracks, offsets))
    out = [0.0] * length
    for track, offset in zip(tracks, offsets):
        start = int(offset * RATE)
        for i, s in enumerate(track):
            out[start + i] += s
    return out


def write(name, samples):
    path = os.path.join(ROOT, "audio", "sfx", f"{name}.wav")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    peak = max(1e-6, max(abs(s) for s in samples))
    gain = min(1.0, 0.9 / peak)
    with wave.open(path, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(b"".join(struct.pack("<h", int(s * gain * 32767)) for s in samples))


def build():
    write("jump", tone(260, 560, 0.13, "square", 0.4, 0.35, curve=0.6))
    write("double_jump", tone(420, 880, 0.15, "square", 0.25, 0.3, curve=0.5, vibrato=0.04))
    write("wall_jump", mix(tone(320, 640, 0.11, "square", 0.3, 0.3), noise(0.06, 0.25, 0.3, 4)))
    write("land", noise(0.07, 0.5, 0.85, 2, 2.0))
    write("dash", mix(noise(0.2, 0.45, 0.35, 3, 1.2), tone(900, 300, 0.12, "square", 0.5, 0.18)))
    write("slide", noise(0.25, 0.35, 0.6, 5, 0.8))
    write("death", mix(tone(620, 70, 0.38, "square", 0.5, 0.35, curve=0.7), noise(0.22, 0.3, 0.5, 6)))
    write("respawn", tone(300, 680, 0.16, "sine", volume=0.4, curve=0.5))
    write("checkpoint", mix(tone(660, 660, 0.14, "triangle", volume=0.45),
                            tone(990, 990, 0.3, "triangle", volume=0.45), offsets=[0, 0.1]))
    write("crumble", mix(noise(0.3, 0.45, 0.75, 7, 1.0), noise(0.15, 0.3, 0.4, 8, 2.0), offsets=[0, 0.08]))
    write("gate", mix(tone(70, 50, 0.45, "saw", volume=0.35), noise(0.4, 0.2, 0.9, 9, 1.0)))
    write("spirit", mix(tone(520, 780, 0.35, "sine", volume=0.3, curve=0.4),
                        tone(780, 1170, 0.35, "sine", volume=0.2, curve=0.4, vibrato=0.02)))
    notes = [523.25, 659.25, 783.99, 1046.5]
    write("color_unlock", mix(*[tone(hz, hz, 0.6 - i * 0.08, "triangle", volume=0.35) for i, hz in enumerate(notes)],
                              tone(2093, 2093, 0.7, "sine", volume=0.08, vibrato=0.01),
                              offsets=[0, 0.09, 0.18, 0.27, 0.27]))
    write("ui_confirm", tone(700, 1050, 0.08, "square", 0.25, 0.25))
    # Hazards, objects, and creatures.
    write("bounce", tone(180, 720, 0.22, "square", 0.3, 0.32, curve=0.45, vibrato=0.05))
    write("plate", mix(tone(240, 200, 0.06, "square", 0.5, 0.25), noise(0.05, 0.2, 0.7, 10)))
    write("door", mix(tone(90, 60, 0.35, "saw", volume=0.3), noise(0.3, 0.2, 0.85, 11, 1.2)))
    write("break", mix(noise(0.4, 0.55, 0.55, 12, 1.0), tone(160, 50, 0.25, "square", 0.5, 0.25)))
    write("crack", noise(0.12, 0.35, 0.2, 13, 2.5))
    write("shatter", mix(noise(0.25, 0.5, 0.45, 14, 1.4), tone(300, 80, 0.15, "square", 0.5, 0.15)))
    write("buzz", tone(180, 220, 0.35, "saw", volume=0.22, vibrato=0.08))
    write("squash", mix(tone(400, 90, 0.2, "square", 0.4, 0.3), noise(0.1, 0.25, 0.5, 15)))
    write("snort", mix(noise(0.18, 0.4, 0.8, 16, 1.0), tone(120, 90, 0.15, "saw", volume=0.2)))
    write("thud", mix(noise(0.12, 0.55, 0.9, 17, 2.0), tone(90, 40, 0.15, "sine", volume=0.4)))
    write("hide", tone(500, 250, 0.1, "triangle", volume=0.3))
    print("sfx built")


if __name__ == "__main__":
    build()

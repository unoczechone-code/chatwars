"""Generate the game's own SFX as WAV files with the standard library only.

No third-party samples: every sound is synthesised here, so CREDITS stays clean.
Run: python tools/make_sfx.py
"""
import math
import os
import struct
import wave

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "game", "audio")
RATE = 44100


def write_wav(name: str, samples: list[float], peak: float = 0.8) -> None:
    os.makedirs(OUT, exist_ok=True)
    top = max((abs(s) for s in samples), default=1.0) or 1.0
    gain = peak / top
    frames = bytearray()
    for s in samples:
        v = int(max(-1.0, min(1.0, s * gain)) * 32767)
        frames += struct.pack("<h", v)
    path = os.path.join(OUT, name)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(bytes(frames))
    print(f"  {name}: {len(samples)/RATE:.3f}s")


def env(i: int, n: int, attack: float = 0.01, release: float = 0.6) -> float:
    """Simple attack/decay envelope, 0..1."""
    t = i / n
    a = min(1.0, t / attack) if attack > 0 else 1.0
    r = max(0.0, 1.0 - t) ** (1.0 / max(release, 0.01))
    return a * r


def sine(freq: float, dur: float, i: int) -> float:
    return math.sin(2 * math.pi * freq * i / RATE)


def square(freq: float, dur: float, i: int) -> float:
    return 1.0 if math.sin(2 * math.pi * freq * i / RATE) >= 0 else -1.0


def noise(i: int, seed: int = 12345) -> float:
    # Deterministic LCG so regenerating gives identical files.
    x = (i * 1103515245 + seed) & 0x7FFFFFFF
    return (x / 0x3FFFFFFF) - 1.0


def sweep(f0: float, f1: float, dur: float, i: int, n: int) -> float:
    t = i / n
    f = f0 + (f1 - f0) * t
    return math.sin(2 * math.pi * f * (i / RATE))


def sfx_shoot() -> list[float]:
    n = int(RATE * 0.09)
    return [sweep(900, 380, 0.09, i, n) * env(i, n, 0.005, 0.9) * 0.6 for i in range(n)]


def sfx_hit() -> list[float]:
    n = int(RATE * 0.07)
    return [noise(i) * env(i, n, 0.002, 1.4) * 0.5 for i in range(n)]


def sfx_kill() -> list[float]:
    n = int(RATE * 0.16)
    out = []
    for i in range(n):
        e = env(i, n, 0.004, 1.2)
        out.append((sweep(520, 120, 0.16, i, n) * 0.6 + noise(i, 777) * 0.4) * e)
    return out


def sfx_hurt() -> list[float]:
    n = int(RATE * 0.25)
    return [sweep(240, 70, 0.25, i, n) * env(i, n, 0.003, 1.1) for i in range(n)]


def sfx_aoe() -> list[float]:
    n = int(RATE * 0.35)
    out = []
    for i in range(n):
        e = env(i, n, 0.005, 1.5)
        out.append((sweep(120, 900, 0.35, i, n) * 0.5 + noise(i, 4242) * 0.3) * e)
    return out


def sfx_upgrade() -> list[float]:
    n = int(RATE * 0.3)
    out = []
    for i in range(n):
        t = i / n
        # Two-note rising chime.
        f = 660 if t < 0.5 else 990
        out.append((sine(f, 0.3, i) * 0.7 + sine(f * 2, 0.3, i) * 0.2) * env(i, n, 0.01, 0.8))
    return out


def main() -> None:
    print(f"Writing SFX to {OUT}")
    write_wav("shoot.wav", sfx_shoot(), 0.45)
    write_wav("hit.wav", sfx_hit(), 0.35)
    write_wav("kill.wav", sfx_kill(), 0.55)
    write_wav("hurt.wav", sfx_hurt(), 0.65)
    write_wav("aoe.wav", sfx_aoe(), 0.6)
    write_wav("upgrade.wav", sfx_upgrade(), 0.5)


if __name__ == "__main__":
    main()

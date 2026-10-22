#!/usr/bin/env python3
"""Build the package images the Windows widget manifest points at."""

import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "src" / "CursorTokens.App"
BG = (23, 32, 46, 255)
BLUE = (0, 120, 212, 255)
AMBER = (202, 122, 28, 255)
TRACK = (48, 60, 74, 255)
WHITE = (236, 240, 244, 255)
MUTED = (150, 162, 176, 255)
CLEAR = (0, 0, 0, 0)


def chunk(tag: bytes, data: bytes) -> bytes:
    return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)


def write_png(path: Path, width: int, height: int, pixel) -> None:
    raw = bytearray()
    for y in range(height):
        raw.append(0)
        for x in range(width):
            raw.extend(pixel(x, y))
    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
    png += chunk(b"IEND", b"")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(png)


def inside_round(x: int, y: int, width: int, height: int, radius: int) -> bool:
    if x < 0 or y < 0 or x >= width or y >= height:
        return False
    if radius <= 0:
        return True
    left = x < radius
    right = x >= width - radius
    top = y < radius
    bottom = y >= height - radius
    if not (left or right) or not (top or bottom):
        return True
    cx = radius - 1 if left else width - radius
    cy = radius - 1 if top else height - radius
    dx = x - cx
    dy = y - cy
    return dx * dx + dy * dy <= radius * radius


def tile(x: int, y: int, width: int, height: int):
    radius = max(4, min(width, height) // 6)
    if not inside_round(x, y, width, height, radius):
        return CLEAR
    margin = max(4, width // 8)
    bar_h = max(3, height // 14)
    gap = max(6, height // 7)
    first = height // 2 - gap
    if first <= y < first + bar_h:
        return BLUE if x < margin + int((width - 2 * margin) * 0.44) else TRACK
    second = first + gap + bar_h
    if second <= y < second + bar_h and margin <= x < width - margin:
        return AMBER if x < margin + int((width - 2 * margin) * 0.83) else TRACK
    return BG


def wide(x: int, y: int, width: int, height: int):
    if not inside_round(x, y, width, height, max(8, height // 12)):
        return CLEAR
    pad = max(12, width // 18)
    title_h = max(8, height // 16)
    if pad <= x < pad + width // 5 and pad <= y < pad + title_h:
        return WHITE
    bar_h = max(6, height // 18)
    bar_top = pad + title_h + max(10, height // 10)
    span = width - 2 * pad
    if bar_top <= y < bar_top + bar_h and pad <= x < width - pad:
        return BLUE if x < pad + int(span * 0.44) else TRACK
    second = bar_top + bar_h + max(8, height // 16)
    if second <= y < second + bar_h and pad <= x < width - pad:
        return AMBER if x < pad + int(span * 0.83) else TRACK
    line = second + bar_h + max(12, height // 12)
    for index in range(3):
        top = line + index * max(8, height // 14)
        if top <= y < top + max(3, height // 40) and pad <= x < pad + span // (3 + index):
            return MUTED
    return BG


def main() -> None:
    assets = ROOT / "Assets"
    provider = ROOT / "ProviderAssets"
    squares = {
        assets / "StoreLogo.png": (50, 50),
        assets / "Square44x44Logo.scale-200.png": (88, 88),
        assets / "Square44x44Logo.targetsize-24_altform-unplated.png": (24, 24),
        assets / "Square150x150Logo.scale-200.png": (300, 300),
        assets / "LockScreenLogo.scale-200.png": (48, 48),
        provider / "CursorUsage_Icon.png": (128, 128),
    }
    for path, (width, height) in squares.items():
        write_png(path, width, height, lambda x, y, w=width, h=height: tile(x, y, w, h))
    for path, (width, height) in {
        assets / "Wide310x150Logo.scale-200.png": (620, 300),
        assets / "SplashScreen.scale-200.png": (620, 300),
        provider / "CursorUsage_Screenshot.png": (600, 400),
    }.items():
        write_png(path, width, height, lambda x, y, w=width, h=height: wide(x, y, w, h))


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Read-only analysis: for each lock sheet, find which frame is 'most open'.

The catalog assumes the open pose is at frameCount//2. This checks that against
two independent pixel metrics so we know the true closed->open / open->closed
split for each lock.
"""
import os
from PIL import Image

LOCKS_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites", "locks")

# (id, frameCount, frameWidth, frameHeight) straight from lock_catalog.dart
SPECS = [
    ("small_sturdy", 10, 16, 22),
    ("small_round", 13, 16, 23),
    ("small_oval", 11, 16, 23),
    ("small_square", 12, 14, 20),
    ("shield_like", 13, 14, 27),
    ("sturdy", 17, 20, 30),
    ("robust", 17, 20, 31),
    ("round", 17, 20, 36),
    ("triangle", 16, 20, 33),
    ("old", 17, 24, 32),
    ("hefty", 18, 24, 33),
    ("extending", 31, 33, 25),
]

# A color that exists for each id (grey exists for all but check fallbacks).
COLOR_FALLBACK = ["grey", "gold", "bronze", "black", "beige", "red", "copper", "mossy"]


def find_sheet(lock_id):
    for c in COLOR_FALLBACK:
        p = os.path.join(LOCKS_DIR, f"{lock_id}_{c}.png")
        if os.path.exists(p):
            return p
    return None


def frame_pixels(sheet, idx, fw, fh):
    box = (idx * fw, 0, idx * fw + fw, fh)
    return sheet.crop(box).convert("RGBA")


def diff_count(a, b):
    """Number of pixels that differ between two RGBA frames (alpha-aware)."""
    pa, pb = a.load(), b.load()
    w, h = a.size
    n = 0
    for y in range(h):
        for x in range(w):
            ra, ga, ba, aa = pa[x, y]
            rb, gb, bb, ab = pb[x, y]
            # treat fully-transparent as equal regardless of rgb
            if aa < 16 and ab < 16:
                continue
            if abs(ra - rb) + abs(ga - gb) + abs(ba - bb) + abs(aa - ab) > 24:
                n += 1
    return n


def top_opaque_row(frame):
    """Highest row (smallest y) containing an opaque pixel. Lower = taller/more open."""
    px = frame.load()
    w, h = frame.size
    for y in range(h):
        for x in range(w):
            if px[x, y][3] >= 16:
                return y
    return h


def opaque_area(frame):
    px = frame.load()
    w, h = frame.size
    return sum(1 for y in range(h) for x in range(w) if px[x, y][3] >= 16)


def main():
    for lock_id, fc, fw, fh in SPECS:
        path = find_sheet(lock_id)
        if not path:
            print(f"{lock_id}: NO SHEET FOUND")
            continue
        sheet = Image.open(path).convert("RGBA")
        sw, sh = sheet.size
        actual_frames = sw / fw
        frames = [frame_pixels(sheet, i, fw, fh) for i in range(fc)]
        f0 = frames[0]

        diffs = [diff_count(f, f0) for f in frames]
        tops = [top_opaque_row(f) for f in frames]
        areas = [opaque_area(f) for f in frames]

        max_diff = max(diffs)
        # frames within 92% of peak diff = the "open" plateau
        plateau = [i for i, d in enumerate(diffs) if d >= 0.92 * max_diff and max_diff > 0]
        diff_pivot = diffs.index(max_diff)
        # highest shackle (min top row); ties -> middle of the tie run
        min_top = min(tops)
        top_pivot_run = [i for i, t in enumerate(tops) if t == min_top]
        midpoint = fc // 2

        size_ok = "OK" if abs(actual_frames - fc) < 0.01 and sh == fh else \
            f"MISMATCH sheet={sw}x{sh} -> {actual_frames:.2f} frames, fh expected {fh}"

        print(f"\n=== {lock_id}  (frameCount={fc}, midpoint={midpoint}) [{size_ok}]")
        print(f"  diff-from-frame0 peak at frame {diff_pivot}; open plateau frames {plateau}")
        print(f"  shackle-highest at frames {top_pivot_run} (top row {min_top})")
        print(f"  diff profile : {diffs}")
        print(f"  top-row prof : {tops}")
        print(f"  area profile : {areas}")


if __name__ == "__main__":
    main()

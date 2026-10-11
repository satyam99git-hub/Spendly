#!/usr/bin/env python3
"""Re-derives the constants in generate_launcher_icons.py from the logo.

    python3 tool/measure_logo.py

The generator is driven by six numbers — where the navy square sits inside the
source's black matte, how round its corners are, where the emblem ends and the
wordmark begins, and what the background navy actually is. All six were measured
from `assets/images/logo/Logo.png` rather than guessed, and all six change if the
artwork is ever redrawn or re-exported at a different size.

This prints them. It does not edit anything: copy what it reports into the
constants at the top of generate_launcher_icons.py, then re-run that.

It also reports where the generated adaptive foreground lands against the 66.7%
safe zone, which is the one number worth checking by eye afterwards — an icon
that merely *fits* still looks wrong pressed up against the launcher's mask.

Requires Pillow and NumPy:
    pip install Pillow numpy
"""

from __future__ import annotations

import os
import sys

try:
    import numpy as np
    from PIL import Image
except ImportError:  # pragma: no cover - developer tooling
    sys.exit('Pillow and NumPy are required: pip install Pillow numpy')

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(ROOT, 'assets', 'images', 'logo', 'Logo.png')
FOREGROUND = os.path.join(
    ROOT, 'android', 'app', 'src', 'main', 'res',
    'mipmap-xxxhdpi', 'ic_launcher_foreground.png',
)

#: Anything this much brighter than pure black is the navy tile rather than the
#: matte around it. The matte is flat #000 and the navy is ~#0E2035, so there is
#: a wide gap to sit in.
MATTE_THRESHOLD = 40

#: Separates the white/blue artwork from the navy it is drawn on.
ART_THRESHOLD = 260

#: A gap of more than this many blank rows means a new block of artwork — the
#: emblem and the wordmark are ~46 rows apart.
BAND_GAP = 8


def main() -> None:
    if not os.path.exists(SOURCE):
        sys.exit(f'Missing {SOURCE}')

    rgb = np.asarray(Image.open(SOURCE).convert('RGB')).astype(int)
    height, width, _ = rgb.shape
    luminance = rgb.sum(axis=2)

    print(f'Source: {os.path.relpath(SOURCE, ROOT)}  {width}x{height}\n')

    # --- the navy tile inside the matte ------------------------------------
    tile = luminance > MATTE_THRESHOLD
    ys, xs = np.where(tile)
    left, right, top, bottom = xs.min(), xs.max(), ys.min(), ys.max()
    print(f'navy tile   x {left}..{right}   y {top}..{bottom}'
          f'   ({right - left + 1}x{bottom - top + 1})')
    if (right - left) != (bottom - top):
        print('            NOTE: not square — antialiasing rounds the edges '
              'differently. Square SQUARE off about the same centre.')

    # --- corner radius ------------------------------------------------------
    side = right - left + 1
    for dy in range(height):
        row = np.where(tile[top + dy, left:right + 1])[0]
        if len(row) and row.min() == 0:
            print(f'corner      radius ~{dy}px = {dy / side:.3f} of the side'
                  f'   -> CORNER_RADIUS = {dy / side:.3f}')
            break

    # --- background navy ----------------------------------------------------
    # Sampled from four points well inside the tile and clear of the artwork.
    inset = side // 12
    samples = [
        rgb[top + inset, left + inset],
        rgb[bottom - inset, left + inset],
        rgb[top + inset, right - inset],
        rgb[bottom - inset, right - inset],
    ]
    navy = tuple(int(round(np.median([s[i] for s in samples]))) for i in range(3))
    print(f'navy        {navy}  #{navy[0]:02X}{navy[1]:02X}{navy[2]:02X}'
          f'   -> NAVY = {navy}')

    # --- artwork bands ------------------------------------------------------
    art = luminance > ART_THRESHOLD
    rows = np.where(art.any(axis=1))[0]
    bands, start, previous = [], rows[0], rows[0]
    for row in rows[1:]:
        if row - previous > BAND_GAP:
            bands.append((start, previous))
            start = row
        previous = row
    bands.append((start, previous))

    print('\nartwork bands (top to bottom):')
    for index, (band_top, band_bottom) in enumerate(bands):
        cols = np.where(art[band_top:band_bottom + 1].any(axis=0))[0]
        name = 'emblem' if index == 0 else 'wordmark' if index == 1 else '?'
        print(f'  {name:9s} x {cols.min()}..{cols.max()}   '
              f'y {band_top}..{band_bottom}')

    emblem_top, emblem_bottom = bands[0]
    cols = np.where(art[emblem_top:emblem_bottom + 1].any(axis=0))[0]
    centre_x = (cols.min() + cols.max()) / 2
    centre_y = (emblem_top + emblem_bottom) / 2
    # A square crop centred on the emblem, with ~4% air so the ring is not cut.
    half = max(cols.max() - cols.min(), emblem_bottom - emblem_top) / 2 * 1.04
    crop = (
        round(centre_x - half), round(centre_y - half),
        round(centre_x + half), round(centre_y + half),
    )
    print(f'\n  -> EMBLEM = {crop}')

    # --- how the generated foreground sits in the safe zone -----------------
    if os.path.exists(FOREGROUND):
        alpha = np.asarray(Image.open(FOREGROUND).getchannel('A'))
        canvas = alpha.shape[0]
        ys, xs = np.where(alpha > 8)
        art_width = xs.max() - xs.min() + 1
        safe = canvas * 2 / 3
        drift_x = (xs.min() + xs.max()) / 2 - canvas / 2
        drift_y = (ys.min() + ys.max()) / 2 - canvas / 2
        print(f'\nadaptive foreground ({os.path.basename(FOREGROUND)}):')
        print(f'  art fills {100 * art_width / canvas:.1f}% of the canvas, '
              f'{100 * art_width / safe:.1f}% of the safe zone')
        print(f'  off-centre by ({drift_x:+.1f}, {drift_y:+.1f}) px')
        if art_width > safe:
            print('  TOO BIG — a circle mask will clip it. Lower ADAPTIVE_SCALE.')
        elif art_width / safe > 0.85:
            print('  Tight. Around 0.78 of the safe zone reads better.')
    else:
        print('\nadaptive foreground not generated yet — run '
              'tool/generate_launcher_icons.py')


if __name__ == '__main__':
    main()

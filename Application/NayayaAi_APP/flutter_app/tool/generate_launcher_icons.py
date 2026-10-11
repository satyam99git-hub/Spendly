#!/usr/bin/env python3
"""Derives every launcher-icon asset from the single brand file.

    python3 tool/generate_launcher_icons.py

Source of truth is `assets/images/logo/Logo.png` — the designed lockup: a navy
rounded square, the scales-and-sword emblem in a ring, and the NyayaAI wordmark.
Everything below is generated from it, so re-running this after the logo changes
is the whole update.

It exists as a script rather than as a set of hand-exported PNGs because there
are sixteen of them at five densities, and a hand-exported set drifts: someone
replaces the logo, updates the three icons they can find, and the app ships with
two different marks depending on which launcher the phone uses.

WHAT IT WRITES
    assets/images/logo/emblem.png                     in-app mark, keyed to alpha
    res/mipmap-*/ic_launcher.png                      legacy icon (pre-API 26)
    res/mipmap-*/ic_launcher_foreground.png           adaptive foreground
    res/mipmap-*/ic_launcher_monochrome.png           themed-icon silhouette
    res/drawable*/nyayaai_logo.png                    the launch-screen mark

THE THREE ICONS ARE NOT THE SAME PICTURE, and that is the point:

  - **Legacy** is the full lockup, wordmark included. Nothing masks it, so it is
    shown exactly as drawn — with its own corners rounded into the alpha channel,
    because the source has a black matte where its corners should be transparent.

  - **Adaptive** (API 26+, which is every current device) is the emblem ALONE on
    a navy background layer. The system masks the foreground to a circle, a
    squircle or a teardrop depending on the launcher, and any of those would cut
    the wordmark in half — it sits within a few percent of the bottom edge. The
    emblem is scaled to the 66% safe zone so no mask can reach it.

  - **Monochrome** (API 33 themed icons) is the emblem's alpha channel; the
    system supplies the colour. Without it, a themed launcher falls back to
    showing the adaptive icon shrunk inside a grey circle.

Requires Pillow. It is a build-time tool, not an app dependency:
    pip install Pillow
"""

from __future__ import annotations

import os
import sys

try:
    from PIL import Image, ImageDraw
except ImportError:  # pragma: no cover - developer tooling
    sys.exit('Pillow is required: pip install Pillow')

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(ROOT, 'assets', 'images', 'logo', 'Logo.png')
RES = os.path.join(ROOT, 'android', 'app', 'src', 'main', 'res')

# ---------------------------------------------------------------------------
# Measurements, all taken from the source rather than eyeballed. Re-derive them
# with tool/measure_logo.py if the artwork is ever redrawn.
# ---------------------------------------------------------------------------

#: The navy rounded square inside the source's black matte, (left, top, right,
#: bottom). The measured bounds are 50..1203 across and 49..1204 down — two
#: pixels taller than they are wide, which is the antialiased edge rounding
#: differently on each side rather than a non-square logo. Squared off here
#: about the same centre so the icon cannot come out a rectangle.
SQUARE = (50, 50, 1205, 1205)

#: Corner radius of that square, as a fraction of its side. Measured at 245/1154.
CORNER_RADIUS = 0.212

#: A square crop centred on the emblem — the ring and everything inside it —
#: with ~4% air around it. Excludes the wordmark, which starts at y=872.
#: Reported verbatim by tool/measure_logo.py.
EMBLEM = (309, 206, 944, 841)

#: The flat navy the emblem is drawn on, as the median of four samples clear
#: of the artwork. Keying against it is what turns the emblem into an
#: alpha-masked mark that can sit on any surface. Reported by
#: tool/measure_logo.py — keep the two in step.
NAVY = (13, 31, 52)

#: How much of the adaptive icon's 108dp canvas the emblem occupies.
#:
#: The guaranteed-visible area is the central 66.7%, and merely fitting inside it
#: is not the target: at 0.62 the ring lands at 90% of the safe zone and reads as
#: a mark pressed against the inside of the launcher's mask. This puts it at
#: about 78%, which is where the ring keeps a visible margin under a circle mask
#: and still fills a squircle properly.
#:
#: The emblem crop carries ~4% of its own air, so the art ends up a little
#: smaller than this number suggests — check with the bbox measurement in
#: tool/measure_logo.py after changing it.
ADAPTIVE_SCALE = 0.54

#: Android density buckets, as multiples of mdpi.
DENSITIES = {
    'mdpi': 1,
    'hdpi': 1.5,
    'xhdpi': 2,
    'xxhdpi': 3,
    'xxxhdpi': 4,
}

LEGACY_BASE = 48   # dp
ADAPTIVE_BASE = 108  # dp — fixed by the adaptive-icon spec
LAUNCH_BASE = 96   # dp, the mark on the native launch screen

#: Everything is rendered at this multiple and then downsampled, so edges and
#: the rounded corners come out smooth instead of stair-stepped.
SUPERSAMPLE = 4


def keyed_emblem() -> Image.Image:
    """The emblem with [NAVY] removed, as straight (unpremultiplied) alpha.

    The emblem is light-on-navy with no transparency of its own, so its
    background has to be *computed* away rather than deleted. Every pixel is
    treated as `c = a·F + (1-a)·B` for a known background B: the channel that
    travelled furthest from B gives the coverage, and dividing it back out
    recovers the original colour.

    Naively deleting near-navy pixels instead would leave a hard, aliased edge
    and a navy halo around every white stroke — visible the moment the mark is
    placed on anything that is not this exact navy, which is precisely what the
    in-app crest does.
    """
    source = Image.open(SOURCE).convert('RGB').crop(EMBLEM)
    width, height = source.size
    pixels = source.load()

    out = Image.new('RGBA', (width, height))
    out_pixels = out.load()

    headroom = [255 - channel for channel in NAVY]

    for y in range(height):
        for x in range(width):
            pixel = pixels[x, y]
            deltas = [pixel[i] - NAVY[i] for i in range(3)]

            alpha = max(
                max(0.0, deltas[i] / headroom[i]) for i in range(3)
            )
            alpha = min(1.0, alpha)

            if alpha <= 0.004:
                out_pixels[x, y] = (0, 0, 0, 0)
                continue

            colour = tuple(
                min(255, max(0, round(NAVY[i] + deltas[i] / alpha)))
                for i in range(3)
            )
            out_pixels[x, y] = colour + (round(alpha * 255),)

    return out


def rounded_lockup() -> Image.Image:
    """The full lockup, cropped out of its matte and given real round corners.

    The source stores its corners as opaque black — it has no alpha channel at
    all — so used as-is the legacy icon would show black triangles on every
    launcher that does not mask it.
    """
    lockup = Image.open(SOURCE).convert('RGB').crop(SQUARE)
    side, height = lockup.size
    if side != height:
        sys.exit(f'SQUARE must be square, got {side}x{height}')

    mask = Image.new('L', (side * SUPERSAMPLE, side * SUPERSAMPLE), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, side * SUPERSAMPLE - 1, side * SUPERSAMPLE - 1),
        radius=side * SUPERSAMPLE * CORNER_RADIUS,
        fill=255,
    )
    mask = mask.resize((side, side), Image.LANCZOS)

    out = lockup.convert('RGBA')
    out.putalpha(mask)
    return out


def centred_on_canvas(art: Image.Image, canvas: int, scale: float) -> Image.Image:
    """Places [art] centred on a transparent square of [canvas] px."""
    target = round(canvas * scale)
    resized = art.resize((target, target), Image.LANCZOS)

    out = Image.new('RGBA', (canvas, canvas), (0, 0, 0, 0))
    offset = (canvas - target) // 2
    out.paste(resized, (offset, offset), resized)
    return out


def as_monochrome(art: Image.Image) -> Image.Image:
    """White pixels carrying [art]'s alpha. The system tints this itself."""
    out = Image.new('RGBA', art.size, (255, 255, 255, 0))
    out.putalpha(art.getchannel('A'))
    return out


def write(image: Image.Image, path: str) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    image.save(path, 'PNG', optimize=True)
    print(f'  {os.path.relpath(path, ROOT)}  {image.size[0]}x{image.size[1]}')


def main() -> None:
    if not os.path.exists(SOURCE):
        sys.exit(f'Missing {SOURCE}')

    print('Reading', os.path.relpath(SOURCE, ROOT))
    emblem = keyed_emblem()
    lockup = rounded_lockup()

    # The in-app mark. Kept large: the splash draws it at up to 96 logical px on
    # a 4x screen, and there is no point shipping something it has to upscale.
    print('\nIn-app mark')
    write(
        emblem.resize((512, 512), Image.LANCZOS),
        os.path.join(ROOT, 'assets', 'images', 'logo', 'emblem.png'),
    )

    print('\nLauncher icons')
    for bucket, factor in DENSITIES.items():
        mipmap = os.path.join(RES, f'mipmap-{bucket}')
        drawable = os.path.join(RES, f'drawable-{bucket}')

        legacy = round(LEGACY_BASE * factor)
        adaptive = round(ADAPTIVE_BASE * factor)
        launch = round(LAUNCH_BASE * factor)

        write(
            lockup.resize((legacy, legacy), Image.LANCZOS),
            os.path.join(mipmap, 'ic_launcher.png'),
        )
        write(
            centred_on_canvas(emblem, adaptive, ADAPTIVE_SCALE),
            os.path.join(mipmap, 'ic_launcher_foreground.png'),
        )
        write(
            as_monochrome(centred_on_canvas(emblem, adaptive, ADAPTIVE_SCALE)),
            os.path.join(mipmap, 'ic_launcher_monochrome.png'),
        )
        write(
            emblem.resize((launch, launch), Image.LANCZOS),
            os.path.join(drawable, 'nyayaai_logo.png'),
        )

    print('\nDone. XML descriptors are checked in, not generated — see')
    print('res/mipmap-anydpi-v26/ic_launcher.xml and res/values/colors.xml.')


if __name__ == '__main__':
    main()

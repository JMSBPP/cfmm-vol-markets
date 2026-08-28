"""Verify favicon.ico against acceptance criterion 5 using Pillow.

Independent read-back check: Pillow parses the ICO container completely
separately from mkico.py's writer, so a bug in one is unlikely to be
masked by the other.

This DECODES every frame's pixel data (not just reads the declared directory
sizes). Reading `image.info["sizes"]` alone only proves the six-byte
directory entries say "16x16" etc. -- it says nothing about whether the
embedded PNG bytes actually decode, or decode to that many pixels. A frame
whose pixel data is corrupt but whose directory header is untouched still
reports a clean declared size; only forcing a real decode of each frame,
and comparing what comes out to what the directory claimed going in, catches
that class of malformation.
"""

from __future__ import annotations

import sys

from PIL import Image

REQUIRED = {(16, 16), (32, 32), (48, 48)}


def main(path: str) -> int:
    with Image.open(path) as image:
        declared = set(image.ico.sizes())
        print(f"{path}: directory declares = {sorted(declared)}")
        missing = REQUIRED - declared
        if missing:
            print(f"FAIL  missing entries: {sorted(missing)}", file=sys.stderr)
            return 1

        for idx, header in enumerate(image.ico.entry):
            frame = image.ico.frame(idx)
            try:
                frame.load()  # force full pixel decode of this frame, not just its header
            except Exception as exc:  # noqa: BLE001 - any decode failure is a FAIL here
                print(
                    f"FAIL  frame {idx} (directory declares {header.dim}) failed to decode: {exc}",
                    file=sys.stderr,
                )
                return 1
            if frame.size != header.dim:
                print(
                    f"FAIL  frame {idx}: directory declares {header.dim}, "
                    f"decoded pixel size is {frame.size}",
                    file=sys.stderr,
                )
                return 1
            print(f"  frame {idx}: {header.dim} decoded OK, pixel size matches directory")

    print("OK    16/32/48 all present and decode cleanly")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1] if len(sys.argv) > 1 else "favicon/favicon.ico"))

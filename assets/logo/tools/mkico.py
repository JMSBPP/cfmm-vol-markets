"""Deterministic multi-resolution ICO writer. Stdlib only.

Each entry embeds its source PNG verbatim, so every size keeps the art of
its own tier (spec Sec7.1) instead of being downsampled from one image.
PNG-in-ICO is understood by every browser in current use.
"""

from __future__ import annotations

import pathlib
import struct
import sys

_PNG_MAGIC = b"\x89PNG\r\n\x1a\n"


def _png_size(data: bytes) -> tuple[int, int]:
    if not data.startswith(_PNG_MAGIC):
        raise ValueError("not a PNG")
    width, height = struct.unpack(">II", data[16:24])
    return width, height


def write_ico(out_path: str, png_paths: list[str]) -> None:
    """Write a multi-resolution .ico embedding each PNG verbatim."""
    if not png_paths:
        raise ValueError("need at least one PNG")

    blobs = [pathlib.Path(p).read_bytes() for p in png_paths]
    offset = 6 + 16 * len(blobs)
    directory = []
    for blob in blobs:
        width, height = _png_size(blob)
        if width > 256 or height > 256:
            raise ValueError(f"ICO entries must be <= 256px, got {width}x{height}")
        directory.append(
            struct.pack(
                "<BBBBHHII",
                0 if width == 256 else width,
                0 if height == 256 else height,
                0,      # palette count
                0,      # reserved
                1,      # colour planes
                32,     # bits per pixel
                len(blob),
                offset,
            )
        )
        offset += len(blob)

    with open(out_path, "wb") as handle:
        handle.write(struct.pack("<HHH", 0, 1, len(blobs)))  # reserved, type=icon, count
        for entry in directory:
            handle.write(entry)
        for blob in blobs:
            handle.write(blob)


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("usage: mkico.py OUT.ico IN1.png [IN2.png ...]", file=sys.stderr)
        raise SystemExit(2)
    write_ico(sys.argv[1], sys.argv[2:])
    print(f"wrote {sys.argv[1]} with {len(sys.argv) - 2} entries")

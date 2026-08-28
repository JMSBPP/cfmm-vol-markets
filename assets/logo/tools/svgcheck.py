"""Structural invariants for the delivered SVG masters.

Enforces the binding rules from docs/superpowers/specs/2026-08-28-logo-design.md:
  §2.5  the two plane curves are the same shape under an affine transform
  §4    no font dependency survives in a delivered file
  §6    masters are drawn on the 512 x 512 grid
"""

from __future__ import annotations

import argparse
import pathlib
import re
import sys
import xml.etree.ElementTree as ET

SVG_NS = "http://www.w3.org/2000/svg"
EXPECTED_VIEWBOX = "0 0 512 512"
CURVE_IDS = ("curve-source", "curve-target")

_NUMBER = re.compile(r"[-+]?\d*\.?\d+(?:[eE][-+]?\d+)?")
_COMMAND = re.compile(r"[A-Za-z][^A-Za-z]*")


def path_points(d: str) -> list[tuple[float, float]]:
    """Every coordinate pair in a path's `d`, in order.

    Absolute M/L/C/S/Q/T commands only. Relative commands raise, because a
    shape comparison across two differently-placed copies is only meaningful
    on absolute coordinates.
    """
    points: list[tuple[float, float]] = []
    for chunk in _COMMAND.findall(d):
        op, rest = chunk[0], chunk[1:]
        if op in "Zz":
            continue
        if op.islower():
            raise ValueError(f"relative command {op!r}: export absolute coordinates")
        if op in "HhVv Aa":
            raise ValueError(f"command {op!r} unsupported; expected M/L/C/S/Q/T")
        nums = [float(n) for n in _NUMBER.findall(rest)]
        if len(nums) % 2:
            raise ValueError(f"odd coordinate count after {op!r}")
        points.extend(zip(nums[0::2], nums[1::2]))
    if not points:
        raise ValueError("path has no coordinates")
    return points


def _unit_normalized(points: list[tuple[float, float]]) -> list[tuple[float, float]]:
    xs = [p[0] for p in points]
    ys = [p[1] for p in points]
    w, h = max(xs) - min(xs), max(ys) - min(ys)
    if w == 0 or h == 0:
        raise ValueError("degenerate bounding box")
    return [((x - min(xs)) / w, (y - min(ys)) / h) for x, y in points]


def same_shape(d1: str, d2: str, tol: float = 1e-3) -> bool:
    """True when two paths are the same shape under an affine transform.

    Compares normalized coordinate sequences after translation to origin and
    independent x/y scaling to [0,1]. Invariant to translation and scaling.

    KNOWN LIMITATION: Does NOT inspect command letters (M/L/C/etc). Two paths
    with identical coordinate sequences but different command types (e.g. cubic
    bezier vs polyline) compare equal. This is acceptable here because both
    curves originate as duplicates of one vector in a single tool, so command
    family mismatches cannot arise from sanctioned workflow. Do not over-trust
    this function for other use cases.
    """
    a = _unit_normalized(path_points(d1))
    b = _unit_normalized(path_points(d2))
    if len(a) != len(b):
        return False
    return all(
        abs(ax - bx) < tol and abs(ay - by) < tol for (ax, ay), (bx, by) in zip(a, b)
    )


def check_file(path: pathlib.Path, *, expect_curves: int) -> list[str]:
    """Return a list of violation strings; empty means the file is clean."""
    root = ET.parse(path).getroot()
    name = path.name
    violations: list[str] = []

    view_box = root.get("viewBox")
    if view_box != EXPECTED_VIEWBOX:
        violations.append(
            f"{name}: viewBox is {view_box!r}, expected {EXPECTED_VIEWBOX!r} (spec §6)"
        )

    for element in root.iter():
        style = element.get("style") or ""
        if element.get("font-family") or "font-family" in style:
            violations.append(
                f"{name}: font-family on <{element.tag.split('}')[-1]}> — "
                "outlines are not vendored (spec §4)"
            )
    if any(el.tag == f"{{{SVG_NS}}}text" for el in root.iter()):
        violations.append(f"{name}: text element present — outlines not vendored (spec §4)")

    if expect_curves == 2:
        curves = [
            el
            for el in root.iter(f"{{{SVG_NS}}}path")
            if el.get("id") in CURVE_IDS
        ]
        if len(curves) != 2:
            violations.append(
                f"{name}: expected 2 paths with id in {CURVE_IDS}, found {len(curves)}"
            )
        else:
            by_id = {el.get("id"): el.get("d", "") for el in curves}
            try:
                if not same_shape(by_id["curve-source"], by_id["curve-target"]):
                    violations.append(
                        f"{name}: curve identity violated — source and target curves "
                        "are not the same shape under an affine transform (spec §2.5)"
                    )
            except ValueError as exc:
                violations.append(f"{name}: curve identity uncheckable: {exc}")

    return violations


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("files", nargs="+", type=pathlib.Path)
    parser.add_argument("--curves", type=int, default=2)
    args = parser.parse_args(argv[1:])

    all_violations: list[str] = []
    for file_path in args.files:
        all_violations.extend(check_file(file_path, expect_curves=args.curves))

    for violation in all_violations:
        print(f"FAIL  {violation}", file=sys.stderr)
    if not all_violations:
        print(f"OK    {len(args.files)} file(s) clean")
    return 1 if all_violations else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))

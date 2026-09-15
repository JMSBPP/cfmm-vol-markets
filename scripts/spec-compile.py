#!/usr/bin/env python3
"""Orchestrate domain-scoped Agda / Idris 2 / Plank compiles from compile.toml."""

from __future__ import annotations

import os
import subprocess
import sys
import tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DOMAINS = ROOT / ".spec" / "domains.toml"


def die(msg: str, code: int = 1) -> None:
    print(f"error: {msg}", file=sys.stderr)
    raise SystemExit(code)


def load_toml(path: Path) -> dict:
    if not path.is_file():
        die(f"missing {path.relative_to(ROOT)}")
    with path.open("rb") as f:
        return tomllib.load(f)


def resolve_domain() -> tuple[str, Path]:
    catalog = load_toml(DOMAINS)
    default = catalog.get("default")
    domains = catalog.get("domains") or {}
    if not isinstance(domains, dict) or not domains:
        die(".spec/domains.toml has no [domains.*] entries")
    name = os.environ.get("SPEC_DOMAIN") or default
    if not name:
        die("SPEC_DOMAIN unset and domains.toml has no default")
    if name not in domains:
        known = ", ".join(sorted(domains))
        die(f"unknown SPEC_DOMAIN={name!r} (known: {known})")
    entry = domains[name]
    compile_rel = entry.get("compile")
    if not compile_rel:
        die(f"domains.{name} missing compile = ...")
    compile_path = ROOT / compile_rel
    return name, compile_path


def run(cmd: list[str]) -> None:
    print("+", " ".join(cmd), flush=True)
    subprocess.run(cmd, cwd=ROOT, check=True)


def compile_file(kind: str, rel: str) -> None:
    path = ROOT / rel
    if not path.is_file():
        die(f"listed {kind} path does not exist: {rel}")
    if kind == "agda":
        run(["just", "agda", rel])
    elif kind == "idris":
        run(["just", "idris", rel])
    elif kind == "plank":
        run(["just", "plank", rel])
    else:
        die(f"unknown language section {kind!r}")


def main() -> None:
    name, compile_path = resolve_domain()
    print(f"spec-compile domain={name} manifest={compile_path.relative_to(ROOT)}", flush=True)
    manifest = load_toml(compile_path)

    for kind in ("agda", "idris", "plank"):
        section = manifest.get(kind) or {}
        files = section.get("files") or []
        if not isinstance(files, list):
            die(f"{compile_path.name}: [{kind}].files must be an array")
        for rel in files:
            if not isinstance(rel, str) or not rel.strip():
                die(f"{compile_path.name}: [{kind}].files entries must be non-empty strings")
            compile_file(kind, rel)

    print("spec-compile ok", flush=True)


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as e:
        raise SystemExit(e.returncode) from e

# FEATURES phase layout

This milestone (Haskell↔Plank Differential Conformance) adopts a FEATURES-oriented phase
directory layout. Requirement PROC-01.

## The convention

    .planning/phases/FEATURES/feat-<slug>/
        <NN>-<NN>-PLAN.md
        <NN>-<NN>-SUMMARY.md

Every phase is a FEATURE, named after the `feat/<slug>` git branch it is built on, plus a
tracking issue on `develop`. Phases start **inline, in the current tree** — the earlier
worktree-per-phase rule was retired after Phase 1.1.

## Why the entries here are symlinks

GSD's own tooling (`gsd-tools.cjs`) scans `.planning/phases/` for `NN-<name>` directories and
its scan does NOT follow symlinks. The real phase directory therefore lives at the numbered
path and the FEATURES entry is a git-tracked symlink into it:

    .planning/phases/FEATURES/feat-red-diff-scaffold -> ../01-red-differential-scaffold

Both paths address the same files. Read or write either; nothing is duplicated.

Making FEATURES phases a first-class GSD structure is deferred to v2 (requirement V2-05).

## Roster

| Phase | FEATURES path | Branch |
|-------|---------------|--------|
| 1 | `feat-red-diff-scaffold` | `feat/red-diff-scaffold` |
| 1.1 (INSERTED) | `feat-ci-feedback-loop` | `feat/ci-feedback-loop` |
| 2 | `feat-volorder-t-minimal` | `feat/volorder-t-minimal` |
| 2.5 (INSERTED) | `feat-volmarketkey` | `feat/volmarketkey` |
| 3 | `feat-volorder-t-rich` | `feat/volorder-t-rich` |
| 4 | `feat-volorder-t-wire-format` | `feat/volorder-t-wire-format` |
| 5 | `feat-rpc-design` | `feat/rpc-design` |
| 6 | `feat-spec-oracle-entrypoint` | `feat/spec-oracle-entrypoint` |
| 7 | `feat-spec-transport` | `feat/spec-transport` |
| 8 | `feat-plank-guards` | `feat/plank-guards` |
| 9 | `feat-guard-parity` | `feat/guard-parity` |
| 10 | `feat-diff-test-green` | `feat/diff-test-green` |
| 11 | `feat-ci-enforcement` | `feat/ci-enforcement` |

Inserted phases (decimal numbers, per the ROADMAP's "Phase Numbering") follow the identical
convention: the numbered tool-facing directory carries the decimal (`01.1-ci-feedback-loop`) and
the FEATURES entry is the same kind of tracked symlink into it.

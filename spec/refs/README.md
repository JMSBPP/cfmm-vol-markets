# spec/refs — vendored proof-source notes

The files under `cfmm-discrete/` are vendored copies of the author's own
`cfmm-discrete/` notes from the local **cfmm-theory knowledge base**. They are
kept in-tree as the load-bearing proof source for Phase 8 (panoptic vol-claim
Lean4 formalization): the lattice discrete Black–Scholes / CRR machinery
(`FINANCE.md`), the streaming-premium θ derivation (`STREAMING_PREMIUM.md`), the
discrete Itô operator (`DIFFERENTIATION.md`, `BINARY_TREES.md`), and the
supporting lattice calculus (`INTEGRATION.md`, `COORDINATES.md`). The
`spec/panoptic.md` θ kernel and the downstream Lean formalization proceed from
these vendored paths — never from home-absolute or user-directory paths, per the
Phase-1 sanitization rule (no home-relative or absolute filesystem targets in
tracked files).

The **canonical citekey remains the cfmm-theory knowledge base**: these copies
are cited-as-proof-source and vendored for reproducibility, not asserted as the
authoritative home of the notes. Cross-tree links that pointed outside the
vendored set (e.g. `../lp-derivatives/notes/CFMM_DISCRETE.md`,
`../cfmm-options/notes/NOTATION.md`) have been neutralized to plain-text
citekeys (`… (cfmm-theory KB — not vendored)`); in-tree sibling links
(`./FINANCE.md`, `./BINARY_TREES.md`, `./INTEGRATION.md`, `./DIFFERENTIATION.md`)
resolve because their targets are vendored alongside.

The Demeterfi et al. (1999) volatility-swaps reference is cited by URL/citekey
from `spec/panoptic.md` and is **not** vendored (public repo; redistribution
rights unclear).

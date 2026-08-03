# Core claims and their prerequisites

**Created 2026-08-03.** The four work tracks accumulated prerequisites faster than they were being
recorded, and several of them turned out to sit underneath claims the program treats as settled.
This file separates the two: **what we are trying to prove** (`CC-*`), and **what must hold first**
(`PR-*`). Every `PR-*` names the claims it blocks, so the critical path is readable off the matrix
rather than reconstructed from five phase files.

Rule: a `PR-*` is a prerequisite only if a core claim is **unsound or unstatable** without it. Work
that merely *would be nice* is not a prerequisite — it is phase work, and lives in the phase file.

---

## Core claims (`CC-*`)

Grounded in the document's own block structure, not invented.

| id | Core claim | Doc | Status |
|---|---|---|---|
| **CC-REPL** | The vol order replicates the variance-swap payoff `π^σ = ΔQ_v·(σ²(i(t)) − σ²_K)⁺`, with `ΔQ_v` first-class and the `ξ⋆` log-contract ladder | doc opening, Theorem 1 (Fee Envelope) | **AT RISK** — see PR-REGION |
| **CC-MAT** | Maturity `T` is endogenously controlled by target vega and liquidations (`tStarJointMult`; linear burn preserves `υ = t/2`) | `## VOL ORDER COMPLETION` | DECIDED, formalized |
| **CC-HAZ** | The hazard ledger — `λ_FLAIR`, `λ_ARB`, `λ_MEV`, `λ̃_JIT` — plus the `τ_MEV` monoid and the `τ_JIT` liquidity tax | `## HAZARD RATES`, M0–M10, J0–J9 | PROVEN (Phase 11 + τ/JIT bundles) |
| **CC-CURV** | A curvature parameter trades arb-loss against investor surplus with an **interior** optimum | E1–E7 | PROVEN — but see PR-ORIENT: the index is SHARE, not curvature, so E1–E7 **re-read** |
| **CC-GREEK** | The LP-kernel Greeks, and whether they can bind the free `(β,γ)`. **G4's answer is NO, and structurally so** — the matrix is block-triangular and `(β,γ)`'s column is zero on every shape row | G0–G6, control matrix G3, underspecification count G4 | OPEN — bundle UNFORMALIZED (Phase 15) |
| **CC-IV** | The framework produces an implied-volatility **LEVEL**, not only the Greeks' shape | `## IMPLIED VOLATILTIY` | RESEARCH DONE, gated |
| **CC-OCC** | The occupancy fraction `T_ITM/T` connects to our endogenous `T` | `## OTHER KRSITENSEN CONNECTIONS` | SPIKE — object not yet confirmed to exist |

---

## Prerequisite register (`PR-*`)

| id | Prerequisite | Blocks | Kind | Owner | Status |
|---|---|---|---|---|---|
| **PR-REGION** | The admissibility region of `ΔQ`, and whether the legs are **signed**. The doc sentence *"Consider a exogenous tuple flow ΔQ = (ΔQ_M, ΔQ_X) on the region:"* is followed by **nothing** — the region is absent. Theorem 1 builds `u` from `φ_{1/2,0}(i_K;ΔQ,0;t)`, which at `L=0` is exactly `√(ΔQ_M·ΔQ_X)`. If the legs are signed, that root is not real and `u` is **ill-posed on exactly the swaps it measures**. | **CC-REPL**, CC-IV | doc defect | Ph 13 (g) | **OPEN — BLOCKER** |
| **PR-ORIENT** | `χ_{X/M}` leg orientation — **really a canonical ARGUMENT-ORDER question**: the CES display orders `(Q_X, Q_M)` and the trading-function display orders the `M` leg first, so the same symbol weights whichever leg comes first. The 2026-08-03 endpoint witnesses give **machine evidence**: `phiCES`'s weight multiplies its FIRST argument, and the canonical embedding puts `χ` on the `pA`/`Q_X` leg — i.e. the CES display's order is the one the proofs use. Two displays 32 lines apart put it on opposite legs; Theorem 1 consumes one, Lean `phiCES` matches the other. Flips the `χ/(1−χ) = λ^{ηΔ_i/2}` bridge and the doc reading of `curvIndex_is_rho_zero_slice`. | **CC-REPL**, **CC-CURV** | author decision | Ph 13 (f) | **OPEN — flagged in doc** |
| **PR-WSIGMA** | Does `W` depend on `σ`? Kristensen's does (occupation time ∝ 1/σ); ours is measured data. Decides whether `σ_IV^ATM` is a **closed form** or a **fixed point** — different objects. | **CC-IV** | author decision | Ph 14 | **OPEN** |
| **PR-THETA** | The θ exponent-sign FLAG (`FLAG (author decision pending): exponent sign above`), restated as blocking in three later blocks — it "blocks any frozen `θ_decay` constant". θ cannot be promoted to a definition while its display carries an unresolved sign. | **CC-GREEK**, CTX-DEFORDER | author decision | Ph 12.1 | **OPEN** |
| **PR-CARRY** | Carry-profile objective: **per-event (M6b) vs time-integrated (λ_FLAIR)**. G6(4) says *"decide before bundling"*, and the M2 hedge claim needs the **time-integrated** form. This decides *what gets proved*, not how — bundling the wrong one yields a correct proof of the wrong objective. | **CC-GREEK** | author decision | Ph 15 | **OPEN** |
| **PR-ETAL** | E8(6) `η_L = η`. G2's skew law is an `η_L` statement until this closes, so G2 cannot be bundled as a statement about `η`. | **CC-GREEK** (G2 only) | open theorem | Ph 15 | **OPEN — carried from Phase 12** |
| **PR-GATE** | The notation gate. The Phase-12 `eta-notation-gate.sh` is **self-contradictory** under the new scheme (its Rule 2 demands `\chi` as Capponi's mapping target while Rule 4c forbids `\chi` outright) and false-positives on Angstrom's auction `k`. **Successor `phi-notation-gate.sh` WRITTEN 2026-08-03** encoding the 2026-08-03 scheme, with κ/ς/F_κ rules downgraded to WARN (the doc carries three legitimate distinct κ's — the closed-phase econometric decay rate, an M6a multiplier, and Capponi's own κ quoted inside the block that refutes him). **Does not yet PASS** — blocked by PR-EPSTOL. | **every claim with a pending doc block** — CC-IV, CC-GREEK, CC-OCC, CTX-DEFORDER | tooling | Ph 13 (c) | **DRAFTED, not passing** |
| **PR-EMBED** | Embedding-test verdict `232c8ee4`. **PARTIAL RETURN 2026-08-03: both ENDPOINTS embed (proven), the INTERIOR is open.** `Fcap_zero_is_rho_one` (linear endpoint = the ρ=1 CES slice, explicit witnesses) and `Fcap_one_is_rho_zero_limit` (constant-product endpoint = the equal-share punctured ρ→0 limit) are PROVEN; `canon_Fcap_not_CES` (the interior verdict at κ=1/2) and `kappa_not_reparam_of_rho` are SORRIED — the task hit **OUT_OF_BUDGET**, not an API fault. Decides whether E4 is redone on the ε axis or closed MOOT. | **CC-CURV** | external | Ph 13 (a) | **PARTIAL — repair bundle owed** |
| **PR-SYNC** | `VOLATILITY_INSTRUMENTS_ETA_ADDENDUM.md` desynced from the plank copy (155 stale `\kappa_{\varphi` sites, 0 `\varsigma`), and its `APPROVED-ETA-SHA256` disclosure is itself stale. Re-pinning is required before any **new** bundle is submitted against that section. | CC-CURV (re-submission only) | integrity | Ph 13 (d) | **OPEN** |
| **PR-CSYM** | A **free** symbol pair for the replication weights. `c₁`/`c₂` are already taken as the E4 branch coefficients (13 sites, `c₁`'s sign load-bearing in four displays), so the rename as stated collides. | CTX-DEFORDER | notation | Ph 12.1 | **OPEN — needs user proposal** |
| **PR-PHICES** | The `PhiCES` glyph/name swap (`phiCES ρ ε` vs doc `φ_{χ,ε}`) recorded only in planning files; the doc's `> LEAN` note is silent on it. Aristotle prompts are doc-derived, so the trap sits where a prompt author will miss it. | any future bundle touching φ | notation | Ph 13 (i) | **OPEN** |
| **PR-OCCOBJ** | Does Kristensen's `T` denote a maturity at all? Perpetual options have none. If it is a horizon parameter, CC-OCC may have no connectable object — a valid, reportable outcome. | **CC-OCC** | research | spike | **NOT STARTED** |
| **PR-EPSTOL** | **UPGRADED 2026-08-03 from MINOR to CRITICAL PATH.** Two bare unsubscripted `ε` sites survive — the lens-spec tolerance, and the user's own IMPLIED-VOLATILITY note (`\varphi_{\chi, \epsilon}`, both letters unsubscripted). The new `phi-notation-gate.sh` **fails on them**, and the gate is the precondition for every doc insertion — so this MINOR now blocks the widest blocker. The tolerance needs a symbol that is **not** ε (ε is elasticities, σ is volatilities, δ is the Greeks) — **needs a user-approved symbol**. | via PR-GATE: CC-IV, CC-GREEK, CC-OCC, CTX-DEFORDER | notation | Ph 13 (h) | **OPEN — user decision** |
| **PR-UNAME** | `u` is called "the utilization factor" in the doc — an interpretive name against the binding rule (the 'utilization' → `sigmoidR` precedent). Needs an authorship ruling before it is swept or grandfathered. | notation hygiene only | notation | Ph 13 (j) | OPEN — MINOR |

---

## Blocking matrix — what stops what

```
PR-REGION ──┬──> CC-REPL   (the central claim: u is ill-posed if legs are signed)
            └──> CC-IV     (VOL/AMT ↔ u relation consumes the same u)

PR-ORIENT ──┬──> CC-REPL   (Theorem 1 consumes the ΔQ_M-leg form)
            └──> CC-CURV   (flips the doc reading of curvIndex_is_rho_zero_slice)

PR-GATE  ───┬──> CC-IV, CC-GREEK, CC-OCC, CTX-DEFORDER   (ALL doc insertions)

PR-WSIGMA ──> CC-IV        (closed form vs fixed point)
PR-THETA  ──┬──> CC-GREEK   (blocks G1's theta_decay + any on-chain constant)
            └──> CTX-DEFORDER (theta cannot become a definition with an unresolved sign)
PR-CARRY  ──> CC-GREEK     (decides WHICH objective gets proved)
PR-ETAL   ──> CC-GREEK     (keeps G2 off-bundle)
PR-EMBED  ──> CC-CURV      (E4 redo vs MOOT)
PR-OCCOBJ ──> CC-OCC       (does the object exist?)
```

## Critical path, stated plainly

**Two prerequisites sit underneath the program's central claim and neither is discharged.**
`CC-REPL` is the claim the whole document exists to support, and Theorem 1 — the block that carries
it — depends on both `PR-REGION` (an admissibility region that is *literally absent from the page*)
and `PR-ORIENT` (a leg orientation that contradicts itself between two displays). Until those are
ruled, the fee envelope is not a proven statement about this project's AMM; it is a statement about
an object whose domain has not been written down.

**`PR-GATE` is the widest blocker** — it stops every pending doc insertion in the program, so it is
the cheapest high-value item on the board and should go first.

**Six of the fourteen are author decisions only** (`PR-ORIENT`, `PR-WSIGMA`, `PR-THETA`, `PR-CARRY`, plus `PR-CSYM`
and `PR-UNAME` as proposals): no research, no proving, no compute — they need a ruling. Those are what a single sitting
with the user could clear — and `PR-CARRY` and `PR-THETA` between them unblock all of Phase 15.

## Maintenance rule

When a phase discovers a new prerequisite, it is registered **here** with its blocking edges before
the phase continues. A prerequisite discovered and left only in a phase file is exactly how
`PR-REGION` and `PR-THETA` stayed invisible while sitting underneath committed claims.

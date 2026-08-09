# Verdict — `Ḡ = ∂ν/∂λ_MEV` via the `Δt` instrument

**Date:** 2026-08-09
**Status:** TERMINAL — the `Δt` instrument is dead. Recorded as a delivered result, on the `υ` precedent.
**Evidence:** `control/spec/RESEARCH-REGISTER.md` @ `5f7f3d81fce1c1c00e60a03814927a5a96b991ac` (first commit; §5's instrument-selection rule is present in it, written before any dispersion was measured).
**Ruled by the user, 2026-08-09.** Two rulings, recorded verbatim in §1 and §2.

---

## 1. VERDICT: NOT IDENTIFIED — the exclusion restriction is refuted

`ECONOMETRICS-DESIGN.md` §2 rests the identification of `Ḡ` on `Δt` being excludable: it enters
the arb probability

\[
\mathbb{P}_{\Delta_{\text{ARB}}} \; = \; \frac{\sigma}{\sigma + \phi\sqrt{2/\Delta t}}
\]

but not the fee schedule `φ = φ̄ + volSurcharge(σ)·gate(ν)`. That structural claim is true and is
not what fails.

**What fails is the exclusion restriction itself.** `RESEARCH-REGISTER.md` source `S-35`
establishes a direct `Δt` → participation path that **bypasses the fee schedule entirely**. The
restriction is therefore not *at risk* — the state `EST-08` was written to test for — it is
**already refuted in the literature**, before this project measured anything.

**User ruling (2026-08-09):** terminal for the `Δt` instrument. Record and stop.

**No instrument substitution follows.** `ROADMAP.md`'s standing constraints, `06B-CONTEXT.md`'s
locked decisions and `RESEARCH-REGISTER.md` §5's frozen menu all forbid post-hoc substitution,
and `EST-09` exists to stop exactly this move. The peer-reviewed latency-instrument family the
sweep surfaced (Hendershott–Jones–Menkveld; Boehmer–Fong–Wu; Rzayev et al., min first-stage
`F = 39`; `S-25` as its DeFi member) is **not** adopted here. It is named in §4 as a proposal and
is not acted on.

---

## 2. SECOND RULING — the time base is `FRM-03`'s, not this phase's

The sweep established that `Ḡ`'s **sign is indeterminate under a free choice of time base**:

| Reading of `λ` | Scaling in `Δt` |
|---|---|
| incidence per block | `Δt^{+1/2}` |
| count per unit time | `Δt^{−1/2}` |
| value per unit time | `Δt^{+1/2}` |

The first stage **flips sign** with the base. Since `H2`'s sign is exactly what `EST-03` was built
to test, an unruled researcher degree of freedom would have mechanically determined the study's
answer. Pre-registration discipline cannot fix this by fiat; it requires a principled ruling.

**User ruling (2026-08-09): defer to `FRM-03`.** The base is not a free choice. `DOC` Definition 22
sums over `s < t` where `s` is a **swap** (`Convention 7`, event time), while the `Δt` inside
`ℙ_{Δ_ARB}` is **interblock** time — the two-clock defect `NEC-02` and `FRM-03` already name. The
ruling belongs to Phase 2, which has not executed.

**Consequence:** `06B-01` is blocked on Phase 2. It must not pick a base from downstream — that is
the pre-emption failure this project retracted once already on 2026-08-09.

---

## 3. What this does and does not say about `H2`

**`H2_dnu_dlamMEV_pos` is NOT REFUTED. It is UNDISCHARGEABLE BY THIS ROUTE.** The distinction is
load-bearing and must not erode:

- A refutation would flip signs downstream — `Theorem34_signs_from_H1_H2`'s conclusion would fail
  and `Proposition 13`'s conjunct-2 antecedent would be false.
- **Non-identification changes nothing about the mathematics.** Every conditional result stands
  exactly as written, still conditional. Nothing flips.

`SRC`'s `Proposition 13` (@ `0fc821a`, blob `33af6a85`) already carries this correctly: conjunct 1
is unconditional, conjunct 2 sits under `0 < ∂φ/∂ν, ∂ν/∂τ_MEV < 0, φ_X < 1`, and the rider states
`∂ν/∂τ_MEV < 0 rests on (H2) — UNDISCHARGED`. **That rider is now more durable than "pending
`EST-03`" — `EST-03` cannot discharge it via `Δt`.** No document may upgrade it.

**`H1` is likewise undischarged**, and was never in this route's scope: `EST-03`'s specification
regressed `ν` on `λ` and tested `H2` only.

### The binding constraint, stated plainly

Both routes to a controller need `sign(H2)`:

- **Phase 6b (set-point):** `Proposition 13`'s domain lines are conditional on it.
- **Phase 6a (on-chain iteration):** `NEC-05`/`NEC-07` require `sign(∂²π̂^σ/∂τ²)` for loop
  direction, which reaches `H2` through `∂ν/∂τ`. `NEC-07` additionally records that **`H1` scales
  and signs the loop gain** and is undischarged on every branch.

So `H2` is not a Phase 6b problem that Phase 6a routes around. **It is the binding constraint on
the whole controller**, and this verdict removes the one empirical route that was specified to
settle it.

---

## 4. Named, not acted on — the alternative-data proposal

Per `06B-CONTEXT.md`'s ruling (verdict **plus** a named alternative-data proposal) and its binding
guard: this section **names** what data could identify `Ḡ`, **does not act on it**, does not reopen
§5's frozen menu, and is written **after** the verdict above, never as an alternative to recording
it. `anti-fishing-replication` governs this boundary.

1. **The latency-instrument family.** `S-25` adapts Hendershott–Jones–Menkveld to DeFi with a
   strong first stage. Its construction is not raw `Δt` and would need its own exclusion argument
   — which is the work, not a shortcut past it.
2. **A live `τ_MEV` actuator.** The deepest problem throughout has been that `τ_MEV` is not
   implemented, so `∂ν/∂τ` is unobservable and must be reached through `∂λ/∂τ`. A deployed tax
   with deliberate variation identifies `Ḡ` directly. Cost: `NEC-05` already establishes that
   dithering a live fee is an experiment on real users, needs persistency of excitation, and
   violates timescale separation unless analysed.
3. **Cross-venue fee variation.** Pools differing in `φ̄` by construction rather than by response.
   Requires an argument that assignment is not selected on utilization — not supplied here.

**None of these is adopted.** Adopting one is a scope change requiring a user ruling and a fresh
frozen menu, not a research decision.

---

## 5. Disposition of the Estimation requirements

| Req | Disposition |
|---|---|
| `LIT-01`…`LIT-04` | **DELIVERED.** The sweep ran and returned the finding that ended the route. `LIT-04`'s pool algebra is unrun — the venue question is moot for `Δt` |
| `EST-01` | Moot for the external route. `ν`'s constructibility from our own state survives as `NEC-03` |
| `EST-02` | **DOES NOT RUN.** Dispersion is not measured; the instrument is dead regardless of its dispersion. **Decision #10 (`Δt` exogenous or endogenous) is ANSWERED: endogenous, via `S-35`** |
| `EST-03` | **DOES NOT RUN.** Terminal non-identification is its third outcome, reached before Stage 1 rather than by it |
| `EST-04` | **DOES NOT RUN** — gate never opens |
| `EST-05` | **THIS DOCUMENT** is the output contract. No `(a,b,c,d)`, no covariance, no admissible band. The back-propagation is the `H2` disposition in §3 |
| `EST-06`…`EST-09` | Moot as specified; the disciplines they encode (bad control, numeric thresholds, `Δt ⟂̸ σ`, winner's curse) are **retained for any future route** |

---

## 6. The `υ` precedent, applied

The `υ` exercise terminated in *"this market cannot identify `υ`"* and was correctly never
reopened. This is the same class of result and gets the same treatment: **a delivered finding, not
a failure to re-specify around.**

What was bought: the design's central identification claim was refuted **before any data was
touched**, by a research sweep that the estimation phase originally did not contain at all. Had
`06B-00` not existed, `06B-02` would have measured dispersion on an instrument already known to be
endogenous, and `06B-03` would have frozen a pre-registration around it.

**Reviewer status, honestly:** neither reviewer certified `RESEARCH-REGISTER.md`. All BLOCKERs were
resolved and MAJORs routed, but Reality Checker (7/20/6) and Model QA (6/12/7) both stopped short
of certification, and the register was committed anyway so §5's ordering guarantee would bite. The
carried MAJORs are open. This verdict rests on `S-35`, which should be re-read directly by anyone
acting on it.

---

*Ruled 2026-08-09. Register pinned at `5f7f3d8`. `SRC` at `0fc821a` / blob `33af6a85`.*

# Realized-Vol Control Layer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Append the normative open-loop drift-scale control requirements to `.spec/REALIZED_VOLATILITY.md`, continue Aristotle project `be429bef-1ac0-407a-85ec-48d1aa157201` so it proposes and proves the discrete recursion + \(\kappa^\star\) pin, and verify the artifact builds with no `sorryAx`.

**Architecture:** Spec owns requirements; Aristotle owns the discrete math (Approach A). Forge cron is out of scope for this plan — only documented evaluation order (`ε → κ* → path`). Reuse `TickDualMapping` / \(g(i)=e^{\beta i}\) as given.

**Tech Stack:** Markdown notes under `.spec/`; Aristotle CLI (`aristotlelib` ≥ 2.1.0) + Lean 4.28 / Lake / Mathlib; local `ARISTOTLE_API_KEY` from `.env` (gitignored).

**Spec:** `docs/superpowers/specs/2026-09-11-realized-vol-control-layer-design.md`

## Global Constraints

- Do **not** reopen the affine-`⊗` / `ln` dual problem; `TickDualMapping` is given.
- Drift-scale pin only; do **not** refit \(\varepsilon_j\).
- \(\varepsilon_j\) modeled as arbitrary fixed sequence (Solidity seed⊕`blockhash` PRNG semantics).
- Aristotle output must be **sorry-free** (`lake build` clean; `#print axioms` has no `sorryAx`).
- Do **not** implement forge cron, commit–reveal Solidity, gas batching, or Plank types in this plan.
- Do **not** commit `.env` or API keys.
- Per repo workflow: present each source chunk for maintainer **approve / modify** before `git commit`.
- Do **not** run `forge test` / `make compile-plank` locally; Lean `lake build` **is** required for the Aristotle artifact (explicit verification bar in the spec).

## File map

| Path | Responsibility |
|------|----------------|
| `.spec/REALIZED_VOLATILITY.md` | Binding notes; append Control-layer requirements; remove dangling “missing control” sentence |
| `.spec/REALIZED_VOLATILITY.lean/<new-artifact>/` | Downloaded Aristotle continue result (Lean modules + summary) |
| `docs/superpowers/specs/2026-09-11-realized-vol-control-layer-design.md` | Already committed design; do not re-litigate decisions |

---

### Task 1: Append control-layer requirements to the md

**Files:**
- Modify: `.spec/REALIZED_VOLATILITY.md` (replace the final paragraph starting “This helps tiying…” through end of file)

**Interfaces:**
- Consumes: locked decisions in the design spec (open-loop, diffusion-shaped, drift-scale, PRNG \(\varepsilon\), Aristotle fill-gaps)
- Produces: normative “Control layer (requirements)” section in the md for the continue prompt to cite

- [x] **Step 1: Show the chunk for approval**

Replace the trailing incomplete prose (from “This helps tiying the state variable…” inclusive) with:

```markdown
This ties the state to its lag under \(g\), but does not yet steer the path to target volatility.

### Control layer (requirements)

**Goal.** Open-loop forge-cron schedule: diffusion-shaped tick path; noise from the Solidity seed⊕`blockhash` PRNG; one drift scalar pins \(i(N)\) implied by target \(\bar\sigma\).

**Given.**

- \(\sigma(i)=e^{\alpha-\beta i}\), \(\beta=\ln 1.0001\), \(g(i)=e^{\beta i}\), inverse \(i=\ln(g(i))/\beta\).
- Terminal: \(\sigma(N)=\bar\sigma \implies i(N)=(\alpha-\ln\bar\sigma)/\beta\).
- Discrete tick increment form from the net-flow section (\(\mu(i),\sigma(i),\Delta W\)), with \(\Delta W_j=\sqrt{\bar dt}\,\varepsilon_j\).

**Requirements.**

1. **Inputs:** \(i(0)\), \(\bar\sigma\) (hence \(i(N)\)), \(\bar dt\), \(N\), and a fixed PRNG stream \(\{\varepsilon_j\}_{j=1}^{N}\) (abstract; interpret as derived from `keccak(seed, blockhash, j)`).
2. **Recursion:** Propose \(i_j=i_{j-1}+\Delta i_j(\mu_\kappa,\varepsilon_j)\) where the drift is a one-parameter family \(\mu_\kappa=\kappa\cdot\mu(\cdot)\) (or an equivalent single scalar on the md drift).
3. **Pin:** For any fixed \(\{\varepsilon_j\}\), construct (or uniquely determine) \(\kappa^\star\) such that \(i_N=i(N)\).
4. **Preserve:** Keep the diffusion-coefficient / \(\sigma(i)\) profile; **do not** refit or replace \(\varepsilon_j\).
5. **Output:** \(\{i_j\}_{j=0}^{N}\) and \(\kappa^\star\), sufficient for a forge script to evaluate the path after \(\varepsilon\) is known.

**Out of scope for the formalization.** On-chain commit–reveal protocol, gas batching, Plank `TickState` / factory types.

**Forge evaluation order (consumer).** Obtain \(\varepsilon\) → solve \(\kappa^\star\) → emit \(\{i_j\}\).
```

Present this hunk to the maintainer with options **approve** / **modify**. Do not commit until approved.

- [x] **Step 2: Apply the approved edit**

Apply the replacement in `.spec/REALIZED_VOLATILITY.md` exactly as approved (or as modified).

- [x] **Step 3: Commit** (`2c02182`, via `git add -f` — `.spec/` is gitignored)

---

### Task 2: Continue Aristotle with the control-layer prompt

**Files:**
- None in-repo until download (Task 3)
- Uses: `.env` → `ARISTOTLE_API_KEY` (source; never commit)
- Project: `be429bef-1ac0-407a-85ec-48d1aa157201`

**Interfaces:**
- Consumes: Task 1 requirements text + design prompt draft
- Produces: Aristotle task id + COMPLETE status (or COMPLETE_WITH_ERRORS with sorry-free Lean still expected — verify in Task 4)

- [x] **Step 1: Authenticate and confirm project**
- [x] **Step 2: Submit continue** (task `ad1c3b4c-d1bc-49d4-b32a-a568e6d09a44`)
- [x] **Step 3: Record task id** (`ad1c3b4c-d1bc-49d4-b32a-a568e6d09a44`)

---

### Task 3: Download artifact into `.spec/REALIZED_VOLATILITY.lean/`

**Files:**
- Create: `.spec/REALIZED_VOLATILITY.lean/<task-id>-aristotle/` (or tar extract layout Aristotle returns)
- Create: tarball only if needed as intermediate (prefer extract; do not commit secrets)

**Interfaces:**
- Consumes: project id `be429bef-…`, task id from Task 2
- Produces: Lean sources including a new control-layer module + `ARISTOTLE_SUMMARY.md`

- [ ] **Step 1: Download**

```bash
set -a && source .env && set +a
mkdir -p .spec/REALIZED_VOLATILITY.lean
aristotle download be429bef-1ac0-407a-85ec-48d1aa157201 \
  --destination .spec/REALIZED_VOLATILITY.lean/be429bef-control-layer.tar.gz
tar -tzf .spec/REALIZED_VOLATILITY.lean/be429bef-control-layer.tar.gz | head
tar -xzf .spec/REALIZED_VOLATILITY.lean/be429bef-control-layer.tar.gz \
  -C .spec/REALIZED_VOLATILITY.lean/
```

- [ ] **Step 2: Sanity-check contents**

Confirm presence of:

- `RequestProject/TickDualMapping.lean` (prior work retained or present)
- a new module for the control / drift-scale recursion (name may vary; locate via `rg -n 'kappa|drift|κ' --glob '*.lean'`)
- `ARISTOTLE_SUMMARY.md` mentioning forge order `ε → κ* → path` (or equivalent)

- [ ] **Step 3: Present artifact tree for approval before commit**

List new/changed paths under `.spec/REALIZED_VOLATILITY.lean/` to the maintainer (**approve** / **modify**). Do not commit until approved. Prefer committing the extracted project (and optionally the tarball if the repo already tracks Aristotle tarballs under `.spec/`); never commit `.env`.

---

### Task 4: Build and prove no `sorryAx`

**Files:**
- Test against: extracted Lake project from Task 3 (cwd = that project root, where `lakefile.toml` + `lean-toolchain` live)

**Interfaces:**
- Consumes: Lean project from Task 3
- Produces: pass/fail verification evidence (build log + axiom printout)

- [ ] **Step 1: Mathlib cache (if needed) + build**

```bash
cd .spec/REALIZED_VOLATILITY.lean/<extracted-project-root>
lake exe cache get
lake build
```

Expected: `Build completed successfully` with no `declaration uses 'sorry'` warnings for `RequestProject.*`.

- [ ] **Step 2: Axiom check on pin/recursion theorems**

Identify theorem names from the new module (via `rg '^(theorem|lemma)' RequestProject/*.lean`), then:

```bash
lake env lean --stdin <<'EOF'
import RequestProject.<NewModule>
#print axioms <pin_theorem>
#print axioms <recursion_or_path_theorem>
EOF
```

Expected: axioms ⊆ `{propext, Classical.choice, Quot.sound}` — **no `sorryAx`**.

- [ ] **Step 3: Commit verified artifact (after approval)**

```bash
git add .spec/REALIZED_VOLATILITY.lean/
git commit -m "$(cat <<'EOF'
chore: add Aristotle drift-scale control-layer Lean artifact

EOF
)"
```

Only include paths the maintainer approved in Task 3.

---

## Spec coverage (self-review)

| Spec item | Task |
|-----------|------|
| Append Control-layer requirements to md | Task 1 |
| `aristotle continue` with design prompt | Task 2 |
| Download into `.spec/REALIZED_VOLATILITY.lean/` | Task 3 |
| `lake build` + no `sorryAx` | Task 4 |
| Forge cron implementation | Deferred (spec non-goal) |
| Commit–reveal Solidity / Plank types | Deferred (spec non-goal) |

## Placeholder scan

No TBD/TODO steps; prompt text and md replacement are verbatim from the approved design.

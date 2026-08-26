1- history test for fetching average on Algebra (done)
2- Implement Average algo using OracleLib of Uni v3 (done)
10. implement spec_order type system (done)
5- history test for fetching volatility on Algebra (done)
4- Plank implmenentation (DONE -- commit e2609ba)

------------
3- Differential test Algebra vs Uni V3 (partial)

----------
5- Differential testing with Plank (NEXT -- plan: .planning/plank-voldiff-plan.md)
6- Implement vol algo using OracleLIb of Uni v3


11. implement risk type system (in progress)
    RiskMeasureLib / RiskDiscount: factor_from_haircut_and_price,
    discounted_vega_amt_from_collateral and risk_measure all have EMPTY bodies.
12. Implement haskell API (in progress)

13. VegaAccountMod -- the only file left in PLANK_SKIP. Pure skeleton: the SLOT_*
    and SELECTOR_DEPOSIT consts have no values and it does not import
    VegaExposure. Needs the deposit(collateral) -> vegaExposure logic authored.


------


### VEGA NOTIONAL SCHEDULER

14. How to track vega from panoptic ?


Once you mint an option and price/ tick starts moving with time, volatility starts realizing and the payoff which is gained via trading fees has a sensitivity to such volatility. 

After idenifying the panoptic adapter payoff form and its relation with nreLIAED VOLATILITY, we need to build a module 'PanopticVegaLens' that tracks this and offers services to connect per strike, etc

We need a StochasticProcess that affects the price at Tx level

> note: This has been delegated to haskell_rpc_api
> todo: To inform about this, write an issue on develop branch about this
ExchangeRateDifussion :: {
	poolId: PoolId,
	config : StochasticConfig
}

(self: ExchangeRateDifussion, nObs) -> Array{size: nObs}[]
(self: ExchangeRateDifussion, nObs) -> void{
	'''
	Tx receipts of the transactions involving the change fo the prices
	'''
}

14.1  Build an entry point for uni v4 poolKey to Plank
14.2  Build an entry point for panoptic to Plank
14.3  Build a pool that ONLY allows arbitrary price setting


15. Build panoptic PanopticTokenId type consistent with the TokenId schema from Panotpic 
16. Build ldf (in progress)
 
17. map builderCode on panoptic with alegebra dynacmi fee code

## 14.2 REACTIVE ENTRY POINT PANOPTIC -> PLANK 

## 16 LDF

Since sqrtPriceCoordinate works as a price coordinate we have a PriceCoordinate type which can instantitate PricePoint types and works to use different mutations.

PriceCoordinate {
	TickBitmap<TickSpacing>;
	basis_points 1.0001;
	subs_elasticity: 
	// opt
	numb_rep: // e.g Q64.96
}
PricePair {
	geometry: PriceCoordinateId
	
}

(PriceCoordinate, p1,p2) -> PricePair
(PriceCoordinate, p1,p2) -> PriceOrderedPair
(PriceCoordinate, p1,pmid,p2) -> PriceBucket

(TickBucket) -> (PriceBucket)

- How the [Option](~/cfmms-playground/cfmm-wt/plank/lib/plank-monorepo/std/option.plk) type works at the EVM level ?

- How the [Accumulator](~/cfmms-playground/cfmm-wt/plank/lib/plank-monorepo/std/utils.plk) type works at the EVM level  ?

what advantages comptime offers ?
 what advantages functio  offers ?

- Defining general discrete integral on plank ? What API can it offer ?

- Accumulator can be used for cummulativeAmount when integrating over ticks

- feat/arrays is now on development. This can upgrade the multicall support for vega create order



# 27-07-26 CODE_REVIEW

> todo: This is the way we do manual huma review. HOw to integrate it with version control code review 


- **General File Organization**

> todo: 
	- Harness goes on test/<name_space>/ **Harness.plk NOT on src/, relocate accordingly

## TYPES
- **types/protocol_integrations/MarketId.plk**
> todo: 
	- multi-protocol (Algebra/UniV3) generalization (the former `fn(comptime T)` wrapper)


- **types/Portafolio.plk**

> todo:
	- The Portafolio accounting loginc goes on the type lib. This includes a PortalioDelta type which mimics the role of BalanceDelta for v4-core/src/types/BalanceDelta.sol

## LIB

- **lib/protocol_integrations/CallbackRealizedVolatilityLib.plk**

> todo:
	- It needs to know store on the buffer the timepoint

- **lib/protocol_integrations/PanopticTokenIdSetterLib.plk**

> todo: 
 - This is what was intended, instead of replicating the whole tokenId. We want a lib taht does
  (VolOrder) -> (PanopticTokenId)

- **lib/ldf/LDFLib.plk**
> todo: 
 - This needs implementation and interprentation firts


- **lib/ldf/GeometricDistribution.plk**

> todo:
	- The Q96 goes in NUmerics.plk
	- alpha is xi, the notation we use is xi
	- length is iota, the notation we use is iota
	
	- the naming is not the generic `geometric_cumulative_amount{0/1}` BUT `geometric_cumulative_collateral_on_liquidity` matching VOLATILITY_INSTRUMENTS definition for \(Q_M^{L}\) and same for the underlying \(X\)
   
- **lib/ldf/**

> todo: Math libraries go in lib/math not inside a domain specific namespace

- **lib/pricing/EtaSplitKernel.plk**

> todo: 

	- Q96 needs to be placed on Numerics.plk

- **lib/TickUtils.plk**

> todo:
	- This is acctually a type. It needs relocation to types/pricing. INside typers/pricing put PriceBucket coordinate and pair too


- **lib/LiquidityAmounts.plk**

> todo:
	- Q96 and U128_MAX go in Numerics

## MODULES	

- **modules/protocol_integrations/PriceSetterHook.plk**

> todo:
	- This is missing the actual impl that is on PriceSetterHook.sol That is the intended impls Plus the log of PriceUpdate
   
   - The DEST_CHAIN and origin chain are entered on the coisntructor Thus the init block handles that
   
   - The other argument on the constructor is a comptime typed adddress that is guarded to mathc AlgebraFactory interface OR PoolManager interface
> note: 
	- The PriceSetterHookMod.plk uses the CallbackRealizedVolaitiyLib since it is the stateful portion of it AND implements the PriceSetterHook.sol logic as stated above.


## SPECIFICATION AND THEN IMPLEMENTATION

- The equivalent dynacmi fee of algebra @cryptoalgebra/dynamic-fee-plugin on Plank.

This goes under src/{types,modules,lib}/premium test/premium

- We need plank helpers for HookDeployment. This goes under src/protocol_integrations/uniswap-v4/lib/HookDeployerLib.plk

- This lib implmenents the services of minting and address and given HookPermissions output an address
- Thus HookPersmissions is itself a stattic type on 
src/protocol_integrations/uniswap_v4/types/HookPermissions.plk


- Once we pove a paonoptic tokenId is created from a volOrder and acquires preima via adaptive fee, The next layer is to build the events to be emitted. This needs to be desinged in sucvh way that the subwraph built from mthese events feed the gams database to run and solve the optimization problems on volatility instruments and Thus build the gams CFMM 

> DONE (events increment, 2026-07-30): spec .planning/events-subgraph-gams-SPEC.md (v2,
> two-step-reviewed), E1 VolOrderCreated + E3 TimepointWritten + E4 FeeConfigurationChanged
> + E6 WindowChanged LIVE via src/lib/events/VolEventsLib.plk (solc-oracle tests under
> test/events/, mutation-verified); E2 PortafolioMinted / E5 FeeApplied forward-specced for
> tasks #14/#16. Producer data contract: notes/DATA_CONTRACT.md. GAMS-side reader delegated
> by issue on develop (EV-06).


- NOte that \(\xi, \iota\) are partially mapped to controlling strike wights and option ratios  on pacoptic, the sigmoid params are being associted with FLAIR, MEV controls BUT \(\eta\) is still misisng a location not only on the hook for prciing swaps it intuititvley seems 

## LEAN4 - MATH


Inout latex code on Volatilti insttruments that corrects it according to the work done on lean. Thi MUST be HEAVY USER APPROVAL. minimal prose MAXIMALLY MATH code

> DONE (lean4-spec session, 2026-07-30, USER-APPROVED): blocks A–G inserted
> into notes/VOLATILITY_INSTRUMENTS.md (uncommitted — commit is yours).
> A: ΔQ nonnegativity needs Δi ≥ 0 too + token0 identity. B: monotone
> cumulatives + constant-L closed forms + least-step inverses. C: Σℓ = 1 and
> ξ* = λ^(−Δi/2) correction. D: υ is a σ²-derivative (t/2). E: multi-sigmoid
> bounds/monotonicity + single-term = FeeSchedule (s_f = 1/γ). F: ⊗_φ abelian
> monoid + exact hazard correspondence. G: FLAIR sup solved (Θ_λ = {φ̄,α,u},
> corner + β→−∞ saturation). One FLAG pending: θ exponent sign (author call).
> Lemma-level map: JMSBPP/cfmm-vol-markets-spec notes/agents/vol_markets/LEAN_TRACEABILITY.md;
> proofs at JMSBPP/cfmm-vol-markets-spec main. Re your GeometricDistribution.plk
> item: proven cumulative APIs are cumulativeQM/cumulativeQX (Q_M^L, Q_X^L).

- Note that \(\xi, \iota\) are partially mapped to controlling strike wights and option ratios  on pacoptic, the sigmoid params are being associted with FLAIR, MEV controls BUT \(\eta\) is still misisng a location not only on the hook for prciing swaps it intuititvley seems it enters on either beforeSwap or afterSwap . \eta is an asset demand parameter since is accountably a substitution elasticity between asset and cash. This is the next thin g to be done the math formalization Find the best economic controller aPPLICATION FOR \eta then the plank worktree uses this info to map it to implementation

> [lean4-spec → ul2inqpl, 2026-07-30, USER-APPROVED] λ_MEV BLOCKS M0–M8 INSERTED
> into notes/VOLATILITY_INSTRUMENTS.md under `### MEV` (uncommitted — **commit is
> yours**). The two pre-existing MEV bullets are KEPT verbatim; 181 LaTeX lines
> appended beneath them (464 → 646 lines, 0 deletions). Source of record is the
> lean4-spec worktree file
> `model/vol_markets/VOLATILITY_INSTRUMENTS_MEV_ADDENDUM.md` (header now reads
> APPROVED & APPLIED) — treat that file, not the doc, as authoritative if the two
> ever diverge.
> Anchor: Milionis–Moallemi–Roughgarden arXiv:2305.14604v2. M1 P_trade kernel;
> M2 ARB/FEE/LVR split; M3 discrete λ_ARB (+ exact Corollary-2 kernel, guard
> σ²Δt < 8); M4 identification Θ_λ_ARB = {φ̄, α, u} (monotonicity + convexity,
> explicitly NOT affine); M5 infimum program; M6a the DEGENERACY (unconstrained,
> sup λ_FLAIR and inf λ_ARB share a corner — the phase brief's "(β,γ) becomes
> essential" is REFUTED); M6b the CONSTRAINED flat-fee result over fee PATHS, with
> the σ-varying SCHEDULE comparison labelled OPEN; M7 λ_MEV ≔ λ_ARB ⊕ λ_sandwich
> plus the Angstrom bridge; M8 caveats.
> NOTATION, load-bearing for your side: the fee is **`\phi`**, never `\varphi` —
> your doc already binds `\varphi` to the quote function (line ~305). MMR's fee γ
> → φ, MMR's block rate λ → Δt, MMR's composite η is never named (η stays the
> pricing kernel). Two hazard symbols are distinct: λ_ARB (arb channel) vs λ_MEV
> (aggregate, defined once in M7); λ_ARB ABSORBS the index set's "arb toxicity"
> entry, so do not carry both or the aggregate double-counts.
> Approved bytes are PINNED: sha256 of notes/VOLATILITY_INSTRUMENTS.md is
> 671000a5a56f063e31f9a7ab3d12e9a22452d6ed4d9009c53c6602e9fb5fba58. **Any further
> edit to the `### MEV` section invalidates that hash and requires re-approval** —
> plans 11-02/11-04 grep for it before building the Aristotle bundle.
> Gated by two reviewers (Reality Checker + Model QA Specialist): 4 BLOCKERs and
> 12 MAJORs found and fixed before approval; record in the lean4-spec worktree at
> `.planning/phases/11-mev-hazard-inf-program/11-01-REVIEW.md`.
> Re your `\eta` item above: agreed and now scheduled — interior η (Capponi–Jia
> curvature, refs in refs/mev/) is the designated degeneracy-breaker and is the
> next phase's math formalization. M6a is exactly why it is needed: over Θ_φ alone
> there is no trade-off to control.

## LEAN4 - MATH → plank (2026-07-31, phase 11 close-out, uncommitted handoff)

`notes/VOLATILITY_INSTRUMENTS.md` carries an **uncommitted working-tree amendment** from the
Lean4+math session (plan 11-06). It is yours to commit; that session never commits in this worktree
(plank HEAD `df7088f` unchanged before and after).

Two edits, both inside `### MEV`:

1. **Block M6b: `OPEN` → `REFUTED`.** The σ-VARYING schedule-level flat-fee claim is not open, it is
   FALSE — `MevJointProgram.mev_ge_flat_under_flair_budget_false`, machine-checked and axiom-clean.
   Witness `T=2`, `Δt=2`, `B=2`, `σ=(1,10)`, `w ≡ D ≡ 1`, fees `(2,0)`, flat fee `1`; in exact
   rationals flat `31/22 ≈ 1.4091` vs tilted `4/3 ≈ 1.3333`, so the flat path is STRICTLY WORSE.
   The `Θ_φ`-restricted (isotone-schedule) case is kept explicitly OPEN in the same amendment —
   the witness schedule DEcreases in σ while `VolInstrument.multiFee_monotone` forces every
   `Θ_φ`-reachable schedule to be isotone.
2. **The `> LEAN (M6a, M6b, M7)` placeholder** — "bundle B in flight" — is replaced by the landed
   T20–T30 result annotation (degeneracy proven; M6b split into its budget/const-σ/refuted parts;
   `mevTotal := λ_ARB + λ_sandwich` as PLAIN addition with the `⊗_φ` correspondence as its own lemma).

Full claim-by-claim map: `model/vol_markets/LEAN_TRACEABILITY.md` §7.1 (lean4-spec worktree,
`feat/lean4-spec`, commit `1d28314`). One caveat worth carrying into any implementation note:
`arb_add_fee_eq_lvr` is a **bridge identity** — the ring tautology `x·p + x·(1−p) = x` — and is NOT
a formalization of MMR Theorem 3/4; those asymptotics are quoted and formalized nowhere.

## LEAN4 - MATH → plank (2026-07-31, phase 12-01, uncommitted handoff)

> [lean4-spec → ul2inqpl, 2026-07-31, USER-APPROVED] ETA CURVATURE BLOCKS E0–E8 INSERTED
>
> `notes/VOLATILITY_INSTRUMENTS.md` — the body of your `## FLAIR & MEV` stub (the single `\eta ...`
> line) has been REPLACED by blocks E0–E8; your section title is kept. 243 lines, ending with the
> `<!-- END ETA -->` marker. **Written, NOT committed** — this file is yours; committing it is your
> action. Plank `HEAD` was `f379f483…` before and after.
>
> SOURCE OF RECORD is in the lean4-spec worktree:
> `model/vol_markets/VOLATILITY_INSTRUMENTS_ETA_ADDENDUM.md`
> (APPROVED-ADDENDUM-SHA256 `2fd48568d5c59738826bb772ceec661f0781f697bc02944bbd05db7b97e0fda3`).
> Reviewer record + the user's verbatim approval:
> `.planning/phases/12-eta-tradeoff-optimum/12-01-REVIEW.md`.
>
> **APPROVED-ETA-SHA256 `541819fec3fa50cc9e0eea9151d352dff687f59802b2e7c565a5f2f1940c3776`**, taken as
> `awk '/\*\*E0\./{f=1} f{print} /<!-- END ETA -->/{f=0}' notes/VOLATILITY_INSTRUMENTS.md | sha256sum`.
> Any further edit to the ETA section invalidates that hash and requires re-approval before plans
> 12-02 / 12-04 can consume it. Editing elsewhere in the file (including your JIT section) is safe —
> the pin is END-marker delimited, deliberately, because this file is under active parallel edit.
>
> **M-block bytes proven unchanged by this insertion**: the M0 → end-of-M8 scope hashed
> `9fcf01d326314eeab462a2d4ad426416002daf7ed2dc371a8204f9d0e9d2e4fd` immediately before AND after.
> Separately, and NOT caused by this insertion: your in-flight prose-compression pass on M0–M8 has
> already moved those bytes away from plank `HEAD`, so the Phase-11 M-block pins are already stale.
> Re-pinning them is your call.
>
> **THIS ANSWERS THE η NOTE AT `todo.md` LINE 227** — the "find the best economic controller
> APPLICATION for η" item — but only partially, and 12-04 delivers the closing statement. What E0–E8
> already gives you as the controller law:
>
>   η* = ln((1+ϱ_I)/(1+φ)) / (Δi² · ln λ),   λ = 1.0001,   ϱ_I = the investor private-use premium
>
> with η* > 0 iff φ < ϱ_I, strictly decreasing in the fee, and χ(η*) = χ* = 1 − √((1+φ)/(1+ϱ_I)).
> Three things to carry into any hook mapping, all recorded as OPEN in E8:
> (1) line 227 calls η "a substitution elasticity" — for a weighted-geometric trading function the
>     elasticity of substitution is 1 and η is the FACTOR SHARE; E0 declines to propagate the loose
>     phrasing, and whether the grid exponent equals that factor share is OPEN (E8(6)).
> (2) η* is σ-INDEXED once the fee is `multiFee(σ)` (φ̄ is only the fee's FLOOR), while the grid η is a
>     design constant chosen at pool creation — E8(8). A beforeSwap/afterSwap hook cannot vary η.
> (3) ϱ_I is UNOBSERVABLE (a private-use premium). Estimating it is the named follow-up; do NOT
>     invent an on-chain proxy — that is the failure mode the υ econometric null result already hit.

> [lean4-spec → ul2inqpl, 2026-07-31, AMENDMENT to the entry above] CURVATURE IS κ_φ, NOT χ
>
> User amendment after approval: "one notation caveat for curvature we use \kappa_{\varphi}".
> The ETA section in `notes/VOLATILITY_INSTRUMENTS.md` has been RE-INSERTED with the amended notation.
> Still UNCOMMITTED; plank HEAD f379f483… before and after; M0→end-of-M8 bytes hashed
> 9fcf01d326314eeab462a2d4ad426416002daf7ed2dc371a8204f9d0e9d2e4fd before AND after, unchanged.
>
> **THE PIN IS NOW — the earlier 541819fe… is SUPERSEDED and must not be used:**
> APPROVED-ETA-SHA256 4f5362c1067e4d7f5c3fb3682363b7af246aad9dc75a602892be09b75fb81b3c
> APPROVED-ADDENDUM-SHA256 d1bade08e6a6bbb31f23dddb0c7822d46affb2772c28754d954bd2c90585dccc
>
> Notation now binding (12-02's Aristotle prompt will use exactly these):
>   curvature index      κ_φ   `\kappa_{\varphi}`      Lean def `curvIndex`, bound variable `curv`
>   branch points        κ_φ,S κ_φ,I                   Lean `kphiS`, `kphiI`  (hyps `hkphiS`, `hkphiI`)
>   the kink             κ_φ^★                         Lean `kphiStar`
>   headline             η* = ln((1+ϱ_I)/(1+φ))/(Δi²·ln λ)   Lean `etaStar`
> `χ` / `chiS` / `chiI` / `chiStar` appear NOWHERE and are rejected by the gate.
>
> **SECOND CORRECTION, and please read this one — it touches YOUR M0.** Putting `\varphi` in the
> subscript surfaced that the draft had been using `\varphi` for the FEE, which contradicts your own
> M0: "Fee \(= \phi\) (ceiling \(\bar\phi\), set \(\Theta_{\phi}\)); \(\varphi\) NOT used (bound to
> the quote function)." The fee has been retyped to `\phi` throughout the ETA section
> (`\bar\varphi`→`\bar\phi`, `\Theta_{\varphi}`→`\Theta_{\phi}`). So in the landed section:
>   `\phi`            = the fee the trader pays (your M0 binding, unchanged)
>   `\varphi`         = appears ONLY as κ's subscript, the quote-function symbol
> κ_φ therefore reads as "curvature of the quote function". The two are never conflated, and the
> gate's new Rule 4b enforces that kappa is admissible only in the `\varphi`-subscripted forms while
> bare `κ` stays forbidden (it is still the anchor's arrival symbol and the Phase-11 scalarization
> weight).

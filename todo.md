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
> Lemma-level map: lean4-spec worktree model/vol_markets/LEAN_TRACEABILITY.md;
> proofs at JMSBPP/cfmm-lean4-spec main. Re your GeometricDistribution.plk
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

-- | The Lean-mirrored structural model function (CTX-EST, plan 09-07).
--
-- This module encodes — byte-for-byte with the Lean twins — the three objects the
-- \"formal witness\" claim depends on:
--
--   * the exponential-moneyness vega model @π = β₀ + υ₀·exp(−κ·d)·σ̂²@
--     (spec §4.3; Lean 'Upsilon.upsilon' family),
--   * the tick-grid moneyness distance @d = |i_K − i_t|@
--     (spec §4.3; Lean @|(i:ℝ) − iK|@ inside 'Upsilon.ATMOTMNullHypothesis'),
--   * the λ = 1.0001 tick base ('PosSpec.lam').
--
-- The mapping Lean-name ↔ Haskell-name ↔ spec-§ is documented in
-- @notes/structural-econometrcics/analysis/lean-haskell-crosswalk.md@; keep the two
-- in sync (that table is the auditable evidence for the bridging-lemma witness).
--
-- 'model' is generic over 'Floating' so the @ad@ cross-check in "Model.NLS" can
-- differentiate it exactly.
module Model.Upsilon
  ( model
  , modelSplit
  , moneyness
  , signedMoneyness
  , tickBase
  ) where

-- | The structural model function, VERBATIM from spec §4.3:
--
-- @model [β₀, υ₀, κ] (d, σ̂²) = β₀ + υ₀ · exp(−κ · d) · σ̂²@
--
-- with @d = |i_K − i_t|@ the tick-grid moneyness distance ('moneyness'). Generic
-- over 'Floating' so @Numeric.AD@ can take its exact Jacobian. This is the
-- econometric twin of Lean's @Upsilon.upsilon@ vega family
-- @υfun i = υ₀·exp(−κ·Δi·|i − iK|)@.
model :: Floating a => [a] -> (a, a) -> a
model [b0, u0, k] (d, s2) = b0 + u0 * exp (negate k * d) * s2
model _ _ = error "Model.Upsilon.model: expected parameter vector [b0, u0, k]"

-- | The κ⁺/κ⁻ split variant used by the symmetry specification test (§5, test 3;
-- built out in plan 09-08). Parameters are @[β₀, υ₀, κ⁺, κ⁻]@; the input carries
-- the distance already split by the sign of @i_K − i_t@ into an OTM-above leg
-- @d⁺@ (0 below the money) and an OTM-below leg @d⁻@ (0 above the money):
--
-- @modelSplit [β₀,υ₀,κ⁺,κ⁻] (d⁺, d⁻, σ̂²)
--    = β₀ + υ₀ · (exp(−κ⁺·d⁺) + exp(−κ⁻·d⁻) − 1) · σ̂²@
--
-- Exactly one of @d⁺,d⁻@ is non-zero off the money, so the bracket collapses to
-- the single active exponential; at the money (@d⁺ = d⁻ = 0@) it is @1@ with no
-- double counting. Staying in 'Floating' (no 'Ord') keeps it @ad@-differentiable.
-- H₀: κ⁺ = κ⁻ (symmetric decay).
modelSplit :: Floating a => [a] -> (a, a, a) -> a
modelSplit [b0, u0, kp, km] (dP, dM, s2) =
  b0 + u0 * (exp (negate kp * dP) + exp (negate km * dM) - 1) * s2
modelSplit _ _ = error "Model.Upsilon.modelSplit: expected parameter vector [b0, u0, kPlus, kMinus]"

-- | The tick-grid moneyness distance @d = |i_K − i_t|@ (spec §4.3), a NON-negative
-- integer tick count. Mirrors the Lean @|(i:ℝ) − iK|@ appearing in
-- 'Upsilon.ATMOTMNullHypothesis' / the exp-family witness.
moneyness :: Int -> Int -> Double
moneyness iK it = abs (fromIntegral (iK - it))

-- | The SIGNED tick distance @i_K − i_t@ (positive above the money). Feeds the
-- κ⁺/κ⁻ split: @d⁺ = max 0 s@, @d⁻ = max 0 (−s)@ with @s = signedMoneyness iK it@.
signedMoneyness :: Int -> Int -> Double
signedMoneyness iK it = fromIntegral (iK - it)

-- | The tick/price grid base λ = 1.0001 — mirrors @PosSpec.lam@ (Lean) and the
-- @round(log K / log 1.0001)@ strike-tick map in "Panel.Build". The strike tick
-- i_K = log_λ K and the distance |i_K − i_t| both live on this grid.
tickBase :: Double
tickBase = 1.0001  -- mirrors PosSpec.lam

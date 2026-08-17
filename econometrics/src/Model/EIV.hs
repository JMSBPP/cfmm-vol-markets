-- | Errors-in-variables remedy: two-noisy-measures instrumental variables for the
-- vega level υ₀ (CTX-EST, plan 09-07).
--
-- The regressor σ̂²_t is estimated realized variance and is EIV-mismeasured
-- (spec §3.3 threat M1: σ̂² = σ² + e), which ATTENUATES the naive υ̂₀ toward zero.
-- Remedy (spec §4.3, LOCKED): instrument σ̂²_t with a SECOND, independently-windowed
-- variance estimate σ̃²_t (@Obs.obsSigma2Instr@; the disjoint even-swap sub-window
-- from "Panel.Variance"). Because σ̃² shares the true σ² but carries INDEPENDENT
-- measurement noise, it is a valid instrument for σ̂² — the classical
-- two-noisy-measures IV for errors-in-variables.
--
-- Implementation is a hand-rolled 2-step (no Haskell package ships nonlinear IV):
--
--   1. Take the shape κ̂ from the NLS fit ("Model.NLS".'Model.NLS.fitGSL'): κ is
--      identified from cross-sectional moneyness variation, NOT from the
--      EIV-threatened variance level, so it is safe to condition on.
--   2. Form the regressor @w_it = exp(−κ̂·d_it)·σ̂²_t@ and its instrument
--      @z_it = exp(−κ̂·d_it)·σ̃²_t@, then estimate @(β₀, υ₀)@ by just-identified IV
--      @θ̂_IV = (ZᵀX)⁻¹ Zᵀy@ with @X = [1, w]@, @Z = [1, z]@ — the moment
--      @E[Z·v] = 0@ (spec §4.3).
--
-- On the money (@d = 0@, so @w = σ̂²@, @z = σ̃²@) this is exactly the textbook
-- two-noisy-measures IV @υ̂₀ = Cov(π, σ̃²)/Cov(σ̂², σ̃²)@, which is consistent for
-- υ₀ where the naive OLS/NLS slope is attenuated.
module Model.EIV
  ( ivFit
  ) where

import qualified Numeric.LinearAlgebra  as LA

import           Econ.Types             (Obs (..), Panel, Theta (..))
import           Model.NLS              (fitGSL)
import           Model.Upsilon          (moneyness)

-- | Two-noisy-measures IV estimate of @(β₀, υ₀)@, holding the shape κ̂ at its NLS
-- value. Instruments the mismeasured σ̂²_t with the disjoint-window σ̃²_t to undo
-- the M1 attenuation on υ̂₀.
ivFit :: Panel -> Theta
ivFit panel = Theta bIV uIV kHat
  where
    -- Step 1: shape from NLS (κ identified off moneyness, not the variance level).
    kHat = kappa (fitGSL panel)

    -- Step 2: build the exp-weighted regressor w = g·σ̂² and instrument z = g·σ̃².
    rows =
      [ (w, z, y)
      | o <- panel
      , let d   = moneyness (obsStrikeTick o) (obsPoolTick o)
            s2  = obsSigma2 o
            s2i = obsSigma2Instr o
            y'  = obsPremium o
      , finite s2, finite s2i, finite y'
      , let g = exp (negate kHat * d)
            w = g * s2
            z = g * s2i
            y = y'
      ]
    finite x = not (isNaN x || isInfinite x)

    -- X = [1, w]  (regressors),  Z = [1, z]  (instruments).
    xMat = LA.fromLists [ [1, w] | (w, _, _) <- rows ]
    zMat = LA.fromLists [ [1, z] | (_, z, _) <- rows ]
    yVec = LA.vector    [ y      | (_, _, y) <- rows ]

    -- Just-identified IV: θ̂ = (ZᵀX)⁻¹ Zᵀy  (moment ZᵀvÌ‚ = 0).
    ztx  = LA.tr zMat LA.<> xMat          -- (2 × 2)
    zty  = LA.tr zMat LA.#> yVec          -- (2)
    beta = ztx LA.<\> zty                 -- solve (2 × 2) system
    (bIV, uIV) = case LA.toList beta of
      (b : u : _) -> (b, u)
      _           -> error "Model.EIV.ivFit: IV solve did not return 2 coefficients"

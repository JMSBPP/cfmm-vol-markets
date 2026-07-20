{-# LANGUAGE RankNTypes #-}

-- | Nonlinear least squares for the exponential-moneyness vega model (CTX-EST,
-- plan 09-07).
--
-- Two independent fits of the SAME model @π = β₀ + υ₀·exp(−κ·d)·σ̂²@
-- ("Model.Upsilon".'model'):
--
--   * 'fitGSL' — the PRIMARY optimizer: hmatrix-gsl Levenberg–Marquardt
--     (@Numeric.GSL.Fitting.fitModel@, system GSL 2.8). Also returns the GSL
--     covariance handle ('fitGSLCov') for the clustered sandwich SE in 09-08.
--   * 'fitAD' — a CROSS-CHECK golden only: a hand-rolled Gauss–Newton /
--     Levenberg–Marquardt loop whose Jacobian is the EXACT @ad@ derivative of the
--     same 'model'. On synthetic data both recover the planted (β₀,υ₀,κ) — the
--     agreement is the correctness witness, not a second production estimator.
module Model.NLS
  ( fitGSL
  , fitGSLCov
  , fitAD
  , designPoints
  ) where

import           Numeric.AD             (grad)
import           Numeric.GSL.Fitting    (fitModel)
import qualified Numeric.LinearAlgebra  as LA

import           Econ.Types             (Obs (..), Panel, Theta (..))
import           Model.Upsilon          (model, moneyness)

-- | Initial parameter guess @[β₀, υ₀, κ]@ for both optimizers. Neutral: zero
-- intercept, unit vega level, mild decay — deliberately away from any planted
-- truth so a successful recovery is informative.
initTheta :: [Double]
initTheta = [0.0, 1.0, 0.2]

-- | Extract the estimation design from the panel: one @((d, σ̂²), π)@ per
-- observation, with @d = |i_K − i_t|@ the tick-grid 'moneyness'. Rows whose σ̂² or
-- π is not finite (e.g. the un-joined placeholder) are dropped so the fit sees
-- only real data.
designPoints :: Panel -> [((Double, Double), Double)]
designPoints panel =
  [ ((d, s2), y)
  | o <- panel
  , let d  = moneyness (obsStrikeTick o) (obsPoolTick o)
        s2 = obsSigma2 o
        y  = obsPremium o
  , isFinite s2, isFinite y
  ]
  where
    isFinite x = not (isNaN x || isInfinite x)

toTheta :: [Double] -> Theta
toTheta [b0', u0', k'] = Theta b0' u0' k'
toTheta xs = error ("Model.NLS.toTheta: expected 3 parameters, got " ++ show (length xs))

-- | PRIMARY fit + covariance. hmatrix-gsl Levenberg–Marquardt of 'model' onto the
-- panel, supplying the analytic 3-column Jacobian
-- @∂f/∂θ = [1, e·σ̂², −d·υ₀·e·σ̂²]@ with @e = exp(−κ·d)@. Returns the fitted 'Theta'
-- and the GSL covariance matrix (the @(JᵀJ)⁻¹σ²@ handle 09-08 turns into
-- cluster-robust SEs).
fitGSLCov :: Panel -> (Theta, LA.Matrix Double)
fitGSLCov panel = (toTheta sol, cov)
  where
    dat = [ (x, [y]) | (x, y) <- designPoints panel ]  -- GSL wants [output] per point
    modelF ps (d, s2) = [model ps (d, s2)]
    jacF [_b0, u0', k'] (d, s2) =
      let e = exp (negate k' * d)
      in [[1, e * s2, negate d * u0' * e * s2]]
    jacF ps _ = error ("Model.NLS.fitGSLCov: bad param length " ++ show (length ps))
    (sol, cov) = fitModel 1e-9 1e-9 200 (modelF, jacF) dat initTheta

-- | PRIMARY point estimate (the covariance is discarded here; use 'fitGSLCov'
-- when the SE handle is needed).
fitGSL :: Panel -> Theta
fitGSL = fst . fitGSLCov

-- | CROSS-CHECK fit: hand-rolled Levenberg–Marquardt with an EXACT @ad@ Jacobian
-- of 'model'. Update @θ ← θ + (JᵀJ + μI)⁻¹ Jᵀr@ with @r = y − f(θ)@ and @J = ∂f/∂θ@;
-- μ is halved on an accepted (SSE-reducing) step and multiplied by 10 on a
-- rejected one. Present purely to reproduce 'fitGSL' on synthetic data.
fitAD :: Panel -> Theta
fitAD panel = toTheta (lmLoop (200 :: Int) 1.0e-3 initTheta)
  where
    dat = designPoints panel
    xs  = map fst dat
    ys  = map snd dat

    residuals ps = zipWith (\(d, s2) y -> y - model ps (d, s2)) xs ys
    sse ps = sum [ r * r | r <- residuals ps ]

    -- Exact ∂f/∂θ at one design point via reverse-mode ad on 'model'.
    jacRow ps (d, s2) = grad (\p -> model p (realToFrac d, realToFrac s2)) ps

    lmLoop :: Int -> Double -> [Double] -> [Double]
    lmLoop 0 _  ps = ps
    lmLoop n mu ps =
      let jf  = LA.fromLists (map (jacRow ps) xs)      -- (#obs × 3)
          r   = LA.vector (residuals ps)               -- (#obs)
          jtj = LA.tr jf LA.<> jf                      -- (3 × 3)
          jtr = LA.tr jf LA.#> r                       -- (3)
          h   = jtj + LA.scale mu (LA.ident 3)
          step = h LA.<\> jtr
          ps' = zipWith (+) ps (LA.toList step)
      in if sse ps' < sse ps
           then lmLoop (n - 1) (max 1.0e-12 (mu / 2)) ps'
           else if mu > 1.0e12 then ps
                else lmLoop (n - 1) (mu * 10) ps

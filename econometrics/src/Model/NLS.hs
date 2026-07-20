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

import           Data.List              (sortOn)
import           Numeric.AD             (grad)
import           Numeric.GSL.Fitting    (fitModel)
import qualified Numeric.LinearAlgebra  as LA

import           Econ.Types             (Obs (..), Panel, Theta (..))
import           Model.Upsilon          (model, moneyness)

-- | Fallback initial guess @[β₀, υ₀, κ]@. Neutral: zero intercept, unit vega
-- level, mild decay — deliberately away from any planted truth so a successful
-- recovery is informative. Used by 'fitAD' and as the last multi-start of
-- 'fitGSLCov'.
initTheta :: [Double]
initTheta = [0.0, 1.0, 0.2]

-- | Data-driven MULTI-START values for @[β₀, υ₀, κ]@.
--
-- __Why this exists.__ @κ@ enters as @exp(−κ·d)@ where @d@ is a moneyness
-- distance in TICKS. On the live Base market @d@ has median ≈ 153 and reaches
-- ≈ 2950, so the fixed start @κ = 0.2@ evaluates @exp(−0.2·153) ≈ 5e−14@: the
-- model is numerically zero at the start point, both @∂f/∂υ₀@ and @∂f/∂κ@
-- vanish, and Levenberg–Marquardt cannot move. The optimizer then "converges"
-- to a degenerate point that is an artifact of the start value, not an estimate.
--
-- The informative scale of @κ@ is set by the data: decay must be resolvable over
-- the observed spread of @d@, i.e. @κ ~ 1/d@. The starts below therefore span a
-- log grid anchored on the observed distances, with @υ₀@ started at the
-- data-implied vega scale @median(π)/median(σ̂²)@ (and its negation, so a
-- negative vega level is reachable).
multiStarts :: [((Double, Double), Double)] -> [[Double]]
multiStarts pts =
  [ [b0Start, u0s, k] | k <- kStarts, u0s <- [u0Scale, negate u0Scale] ]
    ++ [initTheta]
  where
    ds  = [ d | ((d, _), _) <- pts, d > 0 ]
    s2s = [ s2 | ((_, s2), _) <- pts ]
    ys  = [ y | (_, y) <- pts ]
    med xs = case xs of
      [] -> 1
      _  -> let s = sortOn id xs in s !! (length s `div` 2)
    dMed = max 1 (med ds)
    -- Decay half-lives from a fraction of the median distance out to many
    -- multiples of it: kappa = 1/(c * dMed) for c across four orders.
    kStarts = [ 1 / (c * dMed) | c <- [0.1, 0.3, 1, 3, 10, 100, 1000] ]
    u0Scale = let m = med s2s in if m > 0 then abs (med ys) / m else 1
    b0Start = med ys

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

-- | Sum of squared residuals of a parameter vector on the design.
sseAt :: [((Double, Double), Double)] -> [Double] -> Double
sseAt pts ps = sum [ (y - model ps x) ^ (2 :: Int) | (x, y) <- pts ]

-- | PRIMARY fit + covariance. hmatrix-gsl Levenberg–Marquardt of 'model' onto the
-- panel, supplying the analytic 3-column Jacobian
-- @∂f/∂θ = [1, e·σ̂², −d·υ₀·e·σ̂²]@ with @e = exp(−κ·d)@, run from the data-scaled
-- 'multiStarts' and keeping the lowest-SSE solution. Returns the fitted 'Theta'
-- and the GSL covariance matrix (the @(JᵀJ)⁻¹σ²@ handle 09-08 turns into
-- cluster-robust SEs).
fitGSLCov :: Panel -> (Theta, LA.Matrix Double)
fitGSLCov panel = (toTheta best, bestCov)
  where
    pts = designPoints panel
    dat = [ (x, [y]) | (x, y) <- pts ]  -- GSL wants [output] per point
    modelF ps (d, s2) = [model ps (d, s2)]
    jacF [_b0, u0', k'] (d, s2) =
      let e = exp (negate k' * d)
      in [[1, e * s2, negate d * u0' * e * s2]]
    jacF ps _ = error ("Model.NLS.fitGSLCov: bad param length " ++ show (length ps))

    -- MULTI-START (see 'multiStarts'): a single fixed start is not safe here,
    -- because kappa's informative scale is set by the tick-distance units of the
    -- data and a mis-scaled start lands in a numerically flat region where the
    -- Jacobian vanishes. Every start is run and the lowest-SSE finite solution
    -- wins.
    runs =
      [ (sseAt pts s, (s, c))
      | st <- multiStarts pts
      , let (s, c) = fitModel 1e-9 1e-9 500 (modelF, jacF) dat st
      , all ok s, ok (sseAt pts s)
      ]
    ok x = not (isNaN x || isInfinite x)

    (best, bestCov) = case sortOn fst runs of
      ((_, r) : _) -> r
      []           -> fitModel 1e-9 1e-9 200 (modelF, jacF) dat initTheta

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

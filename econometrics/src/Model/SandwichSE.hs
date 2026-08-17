-- | Hand-rolled tokenId-clustered CR0 sandwich covariance (CTX-EST SE, plan
-- 09-08) — THE one estimator artifact no Haskell package ships (RESEARCH
-- §Don't Hand-Roll; locked decision). Everything numeric underneath is a library
-- call (@hmatrix@ inverse / matrix products); only the cluster aggregation is
-- hand-written, and it is golden-tested to 1e-9 against the frozen fixture in
-- "Golden.SandwichFixture".
--
-- For NLS with per-observation score contributions, the covariance clustered by
-- tokenId @g@ is the CR0 sandwich (spec §4.2, RESEARCH §168):
--
-- @
--   V = (JᵀJ)⁻¹ · [ Σ_g (Σ_{it∈g} J_it·v_it)(Σ_{it∈g} J_it·v_it)ᵀ ] · (JᵀJ)⁻¹
--        \\_______/     \\_________________________________________/    \\_______/
--          bread                          meat                           bread
-- @
--
-- where @J_it@ is the row-gradient @∂f/∂θ@ at observation @(i,t)@, @v_it@ the
-- residual, and @g@ ranges over tokenId clusters.
--
-- __Finite-sample correction — decision (documented).__ The frozen 09-01 golden
-- freezes /pure CR0/ (no correction), and Wald/t inference in "Tests.Specification"
-- consumes this same covariance, so 'clusterSandwich' applies __no__ finite-sample
-- correction — it is exactly @bread · meat · bread@. The optional
-- @(G/(G−1))·((N−1)/(N−k))@ Stata-style CR1 multiplier is provided separately as
-- 'clusterCR1Factor' for callers who want the small-sample-corrected variant; it
-- is deliberately NOT baked in so the golden stays exact.
module Model.SandwichSE
  ( clusterSandwich
  , standardErrors
  , clusterCR1Factor
  ) where

import           Data.Text             (Text)
import qualified Data.Map.Strict       as Map
import           Numeric.LinearAlgebra (Matrix, Vector)
import qualified Numeric.LinearAlgebra as LA

-- | The tokenId-clustered CR0 sandwich covariance @V = bread · meat · bread@.
--
-- Inputs:
--
--   * @jRows@ — one row-gradient @∂f/∂θ@ per observation (each length @k@),
--   * @resids@ — the residual @v_it@ per observation,
--   * @clusters@ — the tokenId cluster label per observation.
--
-- All three lists must be the same length @N@ and observation-aligned. Returns
-- the @k×k@ covariance. No finite-sample correction (see module header).
clusterSandwich :: [[Double]] -> [Double] -> [Text] -> Matrix Double
clusterSandwich jRows resids clusters
  | n == 0            = error "Model.SandwichSE.clusterSandwich: no observations"
  | length resids /= n =
      error "Model.SandwichSE.clusterSandwich: residual count /= observation count"
  | length clusters /= n =
      error "Model.SandwichSE.clusterSandwich: cluster count /= observation count"
  | otherwise        = bread LA.<> meat LA.<> bread
  where
    n = length jRows
    k = length (head jRows)

    j :: Matrix Double
    j = LA.fromLists jRows

    -- bread = (JᵀJ)⁻¹
    bread :: Matrix Double
    bread = LA.inv (LA.tr j LA.<> j)

    -- Per-observation score vector J_it · v_it (length k).
    scoreVecs :: [Vector Double]
    scoreVecs = zipWith (\row v -> LA.scale v (LA.vector row)) jRows resids

    -- Sum the scores within each tokenId cluster: s_g = Σ_{it∈g} J_it·v_it.
    clusterSums :: [Vector Double]
    clusterSums = Map.elems (Map.fromListWith LA.add (zip clusters scoreVecs))

    -- meat = Σ_g s_g s_gᵀ (outer products of the per-cluster score sums).
    meat :: Matrix Double
    meat = foldr (LA.add . (\s -> LA.outer s s)) (LA.konst 0 (k, k)) clusterSums

-- | Standard errors = √(diagonal) of a covariance matrix. @SE(θ̂_j) = √V_jj@.
standardErrors :: Matrix Double -> [Double]
standardErrors v = map sqrt (LA.toList (LA.takeDiag v))

-- | The optional Stata-style CR1 small-sample multiplier @(G/(G−1))·((N−1)/(N−k))@,
-- with @G@ = number of clusters, @N@ = observations, @k@ = parameters. Provided for
-- callers who want the corrected covariance @factor · V@; NOT applied by
-- 'clusterSandwich' (which stays pure CR0 to match the frozen golden).
clusterCR1Factor :: Int -> Int -> Int -> Double
clusterCR1Factor g n k =
  (fromIntegral g / fromIntegral (g - 1))
    * (fromIntegral (n - 1) / fromIntegral (n - k))

{-# LANGUAGE OverloadedStrings #-}

-- | Golden spec for the hand-rolled tokenId-clustered CR0 sandwich covariance
-- ('Model.SandwichSE'). The frozen truth lives in "Golden.SandwichFixture"
-- (2-cluster, 3-obs toy panel with V and SE hand-computed in that file's header);
-- this spec asserts 'clusterSandwich' reproduces it to 1e-9, and that with
-- singleton clusters the estimator collapses to the heteroskedasticity-robust
-- HC0 sandwich computed by an independent closed form.
module Model.SandwichSpec (spec) where

import           Test.Hspec
import qualified Numeric.LinearAlgebra as LA

import qualified Golden.SandwichFixture as F
import           Model.SandwichSE       (clusterSandwich, standardErrors)

-- | Flatten a matrix (as row lists) for element-wise comparison.
flatten :: [[Double]] -> [Double]
flatten = concat

-- | Assert two equal-length @Double@ lists agree to an absolute tolerance.
closeTo :: Double -> [Double] -> [Double] -> Expectation
closeTo tol xs ys = do
  length xs `shouldBe` length ys
  mapM_ (\(a, b) -> abs (a - b) `shouldSatisfy` (< tol)) (zip xs ys)

spec :: Spec
spec = describe "Model.SandwichSE (CR0 tokenId-clustered sandwich, plan 09-08)" $ do

  it "reproduces the frozen golden covariance V to 1e-9" $
    closeTo 1e-9
      (flatten (LA.toLists (clusterSandwich F.toyJacobianRows F.toyResiduals F.toyClusters)))
      (flatten F.expectedV)

  it "reproduces the frozen golden standard errors to 1e-9" $
    closeTo 1e-9
      (standardErrors (clusterSandwich F.toyJacobianRows F.toyResiduals F.toyClusters))
      F.expectedSE

  it "collapses to the HC0 sandwich when every cluster is a singleton" $ do
    -- With one observation per cluster there is no within-cluster correlation, so
    -- the CR0 meat Σ_g s_g s_gᵀ equals the HC0 meat Σ_i v_i² J_iᵀ J_i = Jᵀ diag(v²) J.
    let jRows   = [[1, 0.5, 0.0], [0.0, 2, 1], [1, 1, 3], [0.5, 0.0, 2]]
        resids  = [0.7, -1.3, 2.1, 0.4]
        labels  = ["t1", "t2", "t3", "t4"]      -- all distinct ⇒ singletons
        j       = LA.fromLists jRows
        bread   = LA.inv (LA.tr j LA.<> j)
        vsq     = LA.diagl (map (^ (2 :: Int)) resids)
        hc0Meat = LA.tr j LA.<> vsq LA.<> j
        hc0     = bread LA.<> hc0Meat LA.<> bread
    closeTo 1e-9
      (flatten (LA.toLists (clusterSandwich jRows resids labels)))
      (flatten (LA.toLists hc0))

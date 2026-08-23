{-# LANGUAGE OverloadedStrings #-}

-- | Spec for the three committed specification tests (spec §5), exercised on
-- constructed @Theta@ + clustered-covariance inputs:
--
--   * 'testUpsilonPos' — one-sided υ₀ > 0 (υ is a vega),
--   * 'testKappaPos'   — one-sided κ > 0 (THE null-hypothesis test, H₀: κ = 0),
--   * 'testSymmetry'   — Wald κ⁺ = κ⁻ on the 2×2 sub-block of the split fit.
--
-- Each test is checked in both directions: a planted-away-from-null fit rejects
-- with a small p-value, and a planted-at-null fit does not reject.
module Tests.SpecificationSpec (spec) where

import           Test.Hspec
import qualified Numeric.LinearAlgebra as LA

import           Econ.Types         (Theta (..))
import           Tests.Specification
                   ( TestResult (..)
                   , Theta4 (..)
                   , testUpsilonPos
                   , testKappaPos
                   , testSymmetry
                   )

-- | A 3×3 diagonal covariance from per-parameter variances [Var b0, Var u0, Var k].
cov3 :: Double -> Double -> Double -> LA.Matrix Double
cov3 vb vu vk = LA.diagl [vb, vu, vk]

spec :: Spec
spec = describe "Tests.Specification (the three committed tests, spec §5)" $ do

  describe "testUpsilonPos — one-sided υ₀ > 0 (υ is a vega)" $ do
    it "rejects H₀ with a positive statistic and small p when υ̂₀ ≫ 0" $ do
      let r = testUpsilonPos (Theta 0 2.0 0.3) (cov3 0.01 0.01 0.01) -- z = 2/0.1 = 20
      statistic r `shouldSatisfy` (> 0)
      pValue r    `shouldSatisfy` (< 1e-3)
      reject r    `shouldBe` True
    it "does not reject when υ̂₀ ≈ 0 (large p-value)" $ do
      let r = testUpsilonPos (Theta 0 1e-9 0.3) (cov3 0.01 0.01 0.01)
      pValue r `shouldSatisfy` (> 0.4)
      reject r `shouldBe` False

  describe "testKappaPos — one-sided κ > 0 (the null-hypothesis test)" $ do
    it "rejects H₀: κ = 0 with small p when κ̂ ≫ 0" $ do
      let r = testKappaPos (Theta 0 2.0 0.5) (cov3 0.01 0.01 0.0025) -- z = 0.5/0.05 = 10
      statistic r `shouldSatisfy` (> 0)
      pValue r    `shouldSatisfy` (< 1e-3)
      reject r    `shouldBe` True
    it "does not reject a flat profile κ̂ ≈ 0 (large p-value)" $ do
      let r = testKappaPos (Theta 0 2.0 1e-9) (cov3 0.01 0.01 0.0025)
      pValue r `shouldSatisfy` (> 0.4)
      reject r `shouldBe` False

  describe "testSymmetry — Wald κ⁺ = κ⁻ (2×2 sub-block of the split fit)" $ do
    it "rejects symmetry when κ⁺ and κ⁻ are planted far apart" $ do
      let cov = LA.diagl [0.01, 0.01, 0.0025, 0.0025]
          r   = testSymmetry (Theta4 0 2.0 0.8 0.1) cov          -- diff 0.7, se≈0.0707
      statistic r `shouldSatisfy` (> 0)
      pValue r    `shouldSatisfy` (< 1e-3)
      reject r    `shouldBe` True
    it "fails to reject when κ⁺ = κ⁻ (symmetric decay)" $ do
      let cov = LA.diagl [0.01, 0.01, 0.0025, 0.0025]
          r   = testSymmetry (Theta4 0 2.0 0.3 0.3) cov          -- diff 0 ⇒ W = 0
      statistic r `shouldSatisfy` (< 1e-9)
      pValue r    `shouldSatisfy` (> 0.99)
      reject r    `shouldBe` False

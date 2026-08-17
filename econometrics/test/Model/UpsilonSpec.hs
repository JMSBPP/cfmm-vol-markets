-- | Behavioural spec for "Model.Upsilon": the estimating equation is VERBATIM
-- spec §4.3, the moneyness distance is the tick-grid @|i_K − i_t|@, and the tick
-- base is λ = 1.0001 (mirrors @PosSpec.lam@). These three are the fidelity
-- anchors for the Lean↔Haskell↔spec cross-walk and the bridging-lemma witness.
module Model.UpsilonSpec (spec) where

import           Test.Hspec

import           Model.Upsilon (model, modelSplit, moneyness, signedMoneyness, tickBase)

approx :: Double -> Double -> Bool
approx expected actual = abs (expected - actual) < 1e-12

spec :: Spec
spec = describe "Model.Upsilon (CTX-EST)" $ do

  describe "model — verbatim spec §4.3: β₀ + υ₀·exp(−κ·d)·σ̂²" $ do
    it "equals β₀ + υ₀·exp(−κ·d)·σ̂² on a sample point" $ do
      let b0 = 0.5; u0 = 2.0; k = 0.3; d = 4.0; s2 = 1.7
          expected = b0 + u0 * exp (negate k * d) * s2
      model [b0, u0, k] (d, s2) `shouldSatisfy` approx expected
    it "collapses to β₀ + υ₀·σ̂² at the money (d = 0)" $
      model [0.5, 2.0, 0.3] (0.0, 1.7) `shouldSatisfy` approx (0.5 + 2.0 * 1.7)
    it "modelSplit reduces to model on the above-the-money branch (κ⁺ active)" $ do
      let b0 = 0.1; u0 = 1.5; kp = 0.4; km = 0.9; d = 3.0; s2 = 2.1
      -- d⁺ = d, d⁻ = 0 ⇒ only κ⁺ contributes ⇒ same as model [b0,u0,kp]
      modelSplit [b0, u0, kp, km] (d, 0.0, s2)
        `shouldSatisfy` approx (model [b0, u0, kp] (d, s2))
    it "modelSplit reduces to model on the below-the-money branch (κ⁻ active)" $ do
      let b0 = 0.1; u0 = 1.5; kp = 0.4; km = 0.9; d = 3.0; s2 = 2.1
      modelSplit [b0, u0, kp, km] (0.0, d, s2)
        `shouldSatisfy` approx (model [b0, u0, km] (d, s2))

  describe "moneyness — the tick-grid distance |i_K − i_t|" $ do
    it "equals abs (fromIntegral (iK − it))" $ do
      moneyness 100 88  `shouldSatisfy` approx (abs (fromIntegral (100 - 88 :: Int)))
      moneyness 88 100  `shouldSatisfy` approx (abs (fromIntegral (88 - 100 :: Int)))
    it "is symmetric and non-negative" $ do
      moneyness 100 88 `shouldBe` moneyness 88 100
      moneyness (-5) 5 `shouldSatisfy` (>= 0)
    it "signedMoneyness carries the sign (positive above the money)" $ do
      signedMoneyness 100 88 `shouldSatisfy` (> 0)
      signedMoneyness 88 100 `shouldSatisfy` (< 0)

  describe "tickBase — the λ = 1.0001 grid (mirrors PosSpec.lam)" $
    it "equals 1.0001" $
      tickBase `shouldBe` 1.0001

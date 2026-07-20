{-# LANGUAGE OverloadedStrings #-}

-- | Synthetic-recovery spec for the estimator core (CTX-EST): the GSL
-- Levenberg–Marquardt primary fit and the @ad@ cross-check both recover planted
-- parameters, and the two-noisy-measures IV reduces attenuation relative to the
-- naive fit on the mismeasured regressor.
--
-- All randomness is a fixed deterministic LCG ('noiseSeq'), so the suite is
-- reproducible and network-free.
module Model.NLSSpec (spec) where

import qualified Data.Text as T
import           Test.Hspec

import           Econ.Types    (Obs (..), Panel, Theta (..))
import           Model.EIV     (ivFit)
import           Model.NLS     (fitAD, fitGSL)

-- | Deterministic pseudo-noise in (−1, 1) from a linear congruential generator
-- (glibc constants). A fixed seed makes every draw reproducible across runs.
noiseSeq :: Int -> [Double]
noiseSeq seed = go (fromIntegral seed)
  where
    m = 2147483648 :: Integer      -- 2^31
    a = 1103515245 :: Integer
    c = 12345      :: Integer
    go x = let x' = (a * x + c) `mod` m
               u  = fromIntegral x' / fromIntegral m   -- [0,1)
           in (2 * u - 1) : go x'

relErr :: Double -> Double -> Double
relErr truth est = abs (est - truth) / abs truth

-- Planted parameters for the recovery tests.
plantedB0, plantedU0, plantedK :: Double
plantedB0 = 0.5
plantedU0 = 2.0
plantedK  = 0.3

-- | A well-identified panel: moneyness d ∈ {0..10} crossed with 20 epochs of
-- varying σ² gives both the level (υ₀) and the cross-sectional shape (κ)
-- variation identification needs. σ̂² = σ² (no EIV here); only a tiny premium
-- measurement error is added.
recoveryPanel :: Panel
recoveryPanel =
  [ mkObs i d s2 y
  | (row, ((i, d), s2)) <- zip [0 ..] design
  , let clean = plantedB0 + plantedU0 * exp (negate plantedK * fromIntegral d) * s2
        y     = clean + 1.0e-3 * (noiseSeq 42 !! row)
  ]
  where
    epochs = [0 .. 19 :: Int]
    dists  = [0 .. 10 :: Int]
    design = [ ((i, d), 0.4 + 0.05 * fromIntegral i) | i <- epochs, d <- dists ]
    mkObs i d s2 y =
      Obs { obsTokenId     = T.pack ("pos-" ++ show (d `mod` 3))
          , obsEpoch       = i
          , obsPremium     = y
          , obsStrikeTick  = d          -- iK − it = d  ⇒ moneyness = d
          , obsPoolTick    = 0
          , obsSigma2      = s2
          , obsSigma2Instr = s2
          }

-- | An at-the-money (d = 0, so exp(−κ·d) = 1) panel where σ̂² is mismeasured:
-- σ̂² = σ² + e, σ̃² = σ² + e' with INDEPENDENT noises. The naive fit on σ̂²
-- attenuates υ̂₀; σ̃² is a valid instrument that undoes it.
attenuationPanel :: Panel
attenuationPanel =
  [ Obs { obsTokenId     = T.pack ("pos-" ++ show (i `mod` 5))
        , obsEpoch       = i
        , obsPremium     = plantedB0 + plantedU0 * s2True + 5.0e-3 * vNoise
        , obsStrikeTick  = 0
        , obsPoolTick    = 0            -- d = 0 ⇒ level-only, κ irrelevant
        , obsSigma2      = s2True + eHat     -- mismeasured regressor σ̂²
        , obsSigma2Instr = s2True + eTilde   -- independent second measure σ̃²
        }
  | i <- [0 .. 299 :: Int]
  , let s2True  = 0.6 + 0.4 * (0.5 * (nA !! i + 1))   -- true variance, ~[0.6,1.0]
        eHat    = 0.30 * nB !! i                       -- measurement noise on σ̂²
        eTilde  = 0.30 * nC !! i                       -- independent noise on σ̃²
        vNoise  = nD !! i
  ]
  where
    nA = noiseSeq 7
    nB = noiseSeq 101
    nC = noiseSeq 202
    nD = noiseSeq 303

spec :: Spec
spec = describe "Model.NLS / Model.EIV (CTX-EST synthetic recovery)" $ do

  describe "fitGSL — PRIMARY hmatrix-gsl Levenberg–Marquardt" $
    it "recovers the planted (β₀, υ₀, κ) within 1e-2 relative" $ do
      let Theta b0 u0 k = fitGSL recoveryPanel
      relErr plantedB0 b0 `shouldSatisfy` (< 1.0e-2)
      relErr plantedU0 u0 `shouldSatisfy` (< 1.0e-2)
      relErr plantedK  k  `shouldSatisfy` (< 1.0e-2)

  describe "fitAD — hand-rolled ad Gauss–Newton/LM cross-check" $ do
    it "recovers the SAME planted params within 1e-2 relative" $ do
      let Theta b0 u0 k = fitAD recoveryPanel
      relErr plantedB0 b0 `shouldSatisfy` (< 1.0e-2)
      relErr plantedU0 u0 `shouldSatisfy` (< 1.0e-2)
      relErr plantedK  k  `shouldSatisfy` (< 1.0e-2)
    it "agrees with the GSL fit (the cross-check)" $ do
      let Theta bg ug kg = fitGSL recoveryPanel
          Theta ba ua ka = fitAD  recoveryPanel
      abs (bg - ba) `shouldSatisfy` (< 1.0e-3)
      abs (ug - ua) `shouldSatisfy` (< 1.0e-3)
      abs (kg - ka) `shouldSatisfy` (< 1.0e-3)

  describe "ivFit — two-noisy-measures IV reduces EIV attenuation" $ do
    it "the naive GSL fit on σ̂² is attenuated below the true υ₀" $ do
      let Theta _ u0Naive _ = fitGSL attenuationPanel
      u0Naive `shouldSatisfy` (< plantedU0)          -- attenuation present
    it "instrumenting σ̂² with σ̃² gets υ̂₀ closer to the truth than the naive fit" $ do
      let Theta _ u0Naive _ = fitGSL attenuationPanel
          Theta _ u0IV    _ = ivFit  attenuationPanel
      relErr plantedU0 u0IV `shouldSatisfy` (< relErr plantedU0 u0Naive)

  -- REGRESSION (plan 09-09): the live Base market has moneyness distances of
  -- O(10^2)-O(10^3) TICKS, where the old fixed start kappa = 0.2 evaluates
  -- exp(-0.2*153) ~ 5e-14. The model is numerically zero there, the Jacobian
  -- vanishes, and LM "converges" to an artifact of the start value. The
  -- data-scaled multi-start must recover the planted parameters at that scale.
  describe "fitGSL at LIVE tick scale (multi-start regression)" $ do
    let bTrue = 3.0e-4
        uTrue = 5.0e-2
        kTrue = 4.0e-3          -- e-folding over 250 ticks
        tickScalePanel =
          [ Obs { obsTokenId = T.pack ("t" <> show j)
                , obsEpoch = 20600 + j
                , obsPremium = bTrue + uTrue * exp (negate kTrue * d) * s2
                , obsStrikeTick = -200000 + dev
                , obsPoolTick = -200000
                , obsSigma2 = s2
                , obsSigma2Instr = s2 }
          | (j, dev) <- zip [0 ..] [ 13, 40, 90, 153, 240, 380, 600, 900
                                   , 1400, 2100, 2954, -20, -75, -160, -310
                                   , -520, -880, -1300, -2000, -2800 ]
          , let d  = fromIntegral (abs dev) :: Double
                s2 = 3.13e-4 * (1 + 0.2 * fromIntegral (j `mod` 5))
          ]

    it "recovers the planted params where a fixed kappa=0.2 start cannot" $ do
      let Theta b0 u0 k = fitGSL tickScalePanel
      relErr bTrue b0 `shouldSatisfy` (< 1.0e-2)
      relErr uTrue u0 `shouldSatisfy` (< 1.0e-2)
      relErr kTrue k  `shouldSatisfy` (< 1.0e-2)

    it "returns a POSITIVE kappa on a genuinely decaying profile" $ do
      let Theta _ _ k = fitGSL tickScalePanel
      k `shouldSatisfy` (> 0)

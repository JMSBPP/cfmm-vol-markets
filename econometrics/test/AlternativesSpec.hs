{-# LANGUAGE OverloadedStrings #-}

-- | Behaviours of the four locked alternative specifications (plan 09-09,
-- CTX-ALT). All fixtures are SYNTHETIC panels with planted structure — the live
-- estimation is a separate, non-test artifact.
module AlternativesSpec (spec) where

import qualified Data.Text as T
import           Test.Hspec

import           Alternatives
import           Econ.Types  (Obs (..), Panel, Theta (..))
import           Model.NLS   (fitGSL)

-- | Build one synthetic observation.
mkObs :: T.Text -> Int -> Int -> Int -> Double -> Double -> Obs
mkObs tok ep iK it s2 y = Obs
  { obsTokenId     = tok
  , obsEpoch       = ep
  , obsPremium     = y
  , obsStrikeTick  = iK
  , obsPoolTick    = it
  , obsSigma2      = s2
  , obsSigma2Instr = s2
  }

-- | A panel generated from the TRUE exponential profile
-- @pi = b0 + u0*exp(-k*|iK - it|)*sigma2@ with no noise. Strikes are spread
-- around the pool tick so the moneyness distribution has real support, and each
-- tokenId is observed over several epochs (so the within estimator has
-- something to work with).
plantedPanel :: Double -> Double -> Double -> Panel
plantedPanel b0 u0 k =
  [ mkObs (T.pack ("tok" <> show j)) ep iK it s2 y
  | (j, iK) <- zip [0 :: Int ..] strikes
  , (ep, it, s2) <- epochs
  , let d = fromIntegral (abs (iK - it)) :: Double
        y = b0 + u0 * exp (negate k * d) * s2
  ]
  where
    strikes = [ -200000 + 20 * s | s <- [-6 .. 6 :: Int] ]
    epochs  = [ (20600 + t, -200000 + 5 * t, 1.0e-4 * (1 + 0.35 * fromIntegral t))
              | t <- [0 .. 5 :: Int] ]

-- | Look a coefficient up by name.
coefOf :: T.Text -> Estimates -> Maybe Double
coefOf n e = lookup n (estCoefs e)

spec :: Spec
spec = describe "Alternatives (the four locked specifications, spec 6.2)" $ do

  -- Behaviour 1 --------------------------------------------------------------
  describe "runAlternatives" $ do
    let res = runAlternatives (plantedPanel 0.0 2.0 2.0e-3)

    it "returns exactly the four labelled specifications, in spec order" $
      map fst res
        `shouldBe` ["semiparametric", "seed-linear", "position-FE", "collateral"]

    it "labels each Estimates record consistently with its key" $
      map (estLabel . snd) res `shouldBe` map fst res

    it "identifies the three premium-channel specs on a rich planted panel" $ do
      let ident = [ (l, estIdentified e) | (l, e) <- res ]
      lookup "semiparametric" ident `shouldBe` Just True
      lookup "seed-linear"    ident `shouldBe` Just True
      lookup "position-FE"    ident `shouldBe` Just True

    it "reports the collateral channel NOT ESTIMABLE when no Q_M data is supplied" $ do
      let Just c = lookup "collateral" res
      estIdentified c `shouldBe` False
      estNote c `shouldSatisfy` T.isInfixOf "NOT ESTIMABLE"

    it "estimates the collateral channel once Q_M observations ARE supplied" $ do
      -- Q_M = 10 + 500*sigma2, two accounts, planted exactly.
      let cobs = [ CollateralObs acct ep (10 + 500 * s2) s2
                 | acct <- ["acctA", "acctB"]
                 , (ep, s2) <- zip [20600 ..] [1.0e-4, 2.0e-4, 3.0e-4, 4.0e-4] ]
          Just c = lookup "collateral" (runAlternativesWith cobs (plantedPanel 0 2 2.0e-3))
      estIdentified c `shouldBe` True
      coefOf "upsilon_collateral" c `shouldSatisfy` maybe False (\v -> abs (v - 500) < 1e-6)

  -- Behaviour 2 --------------------------------------------------------------
  describe "seed-linear (spec 6.2.2) recovers the first-order expansion near ATM" $ do
    -- Near the money the exponential profile u0*exp(-k*d)*s2 linearizes to
    -- u0*(1 - k*d)*s2, so on a NEAR-ATM sample the centered strike interaction
    -- gamma must come out NEGATIVE (the linear echo of kappa > 0), and the
    -- level coefficient must sit near u0.
    let u0 = 2.0
        k  = 2.0e-3
        atmPanel =
          [ mkObs (T.pack ("tok" <> show j)) (20600 + t) iK it s2 y
          | (j, iK) <- zip [0 :: Int ..] [ -200000 + 5 * s | s <- [0 .. 12 :: Int] ]
          , (t, it, s2) <- [ (t', -200000, 1.0e-4 * (1 + 0.4 * fromIntegral t'))
                           | t' <- [0 .. 4 :: Int] ]
          , let d = fromIntegral (abs (iK - it)) :: Double
                y = u0 * exp (negate k * d) * s2
          ]
        e = seedLinearSpec atmPanel

    it "is identified on the near-ATM panel" $
      estIdentified e `shouldBe` True

    it "recovers the level coefficient near u0" $
      coefOf "upsilon_ibar" e `shouldSatisfy` maybe False (\v -> abs (v - u0) < 0.5 * u0)

    it "returns a NEGATIVE strike interaction (the linear echo of kappa > 0)" $
      coefOf "gamma" e `shouldSatisfy` maybe False (< 0)

    it "reports the centering tick in its note" $
      estNote e `shouldSatisfy` T.isInfixOf "i-bar"

  -- Behaviour 3 --------------------------------------------------------------
  describe "position-FE (spec 6.2.3) is the strike-composition diagnostic" $ do
    it "opens a kappa gap vs the PRIMARY fit under planted strike confounding" $ do
      -- Plant CONFOUNDING: the premium carries a per-tokenId level that is
      -- correlated with the strike. The pooled (primary) fit cannot tell that
      -- level apart from the moneyness profile and so mis-states kappa; the
      -- within estimator sweeps the levels out and is unaffected.
      --
      -- THE DIAGNOSTIC (spec 6.2.3) is therefore the GAP between kappa_FE and the
      -- primary kappa: it must open up on the confounded panel and stay closed on
      -- the clean one.
      let u0 = 2.0
          kTrue = 2.0e-3
          strikes = [ -200000 + 40 * s | s <- [-6 .. 6 :: Int] ]
          epochs  = [ (t, -200000 + 5 * t, 1.0e-4 * (1 + 0.4 * fromIntegral t))
                    | t <- [0 .. 5 :: Int] ]
          panelWith alphaOf =
            [ mkObs (T.pack ("tok" <> show j)) (20600 + t) iK it s2 y
            | (j, iK) <- zip [0 :: Int ..] strikes
            , (t, it, s2) <- epochs
            , let d = fromIntegral (abs (iK - it)) :: Double
                  y = alphaOf iK + u0 * exp (negate kTrue * d) * s2
            ]
          confounded = panelWith (\iK -> 3.0e-4 * fromIntegral (iK + 200000))
          clean      = panelWith (const 0)
          gap p = case coefOf "kappa_FE" (positionFESpec p) of
            Nothing -> error "position-FE did not report kappa_FE"
            Just kFE -> abs (kFE - kappa (fitGSL p))
      estIdentified (positionFESpec confounded) `shouldBe` True
      estIdentified (positionFESpec clean)      `shouldBe` True
      gap confounded `shouldSatisfy` (> gap clean)

    it "reports NOT IDENTIFIED when every tokenId is a singleton" $ do
      let singletons =
            [ mkObs (T.pack ("tok" <> show j)) 20600 (-200000 + 30 * j) (-200000) 1.0e-4
                    (2.0 * exp (negate 2.0e-3 * fromIntegral (abs (30 * j))) * 1.0e-4)
            | j <- [0 .. 9 :: Int] ]
          e = positionFESpec singletons
      estIdentified e `shouldBe` False
      estNote e `shouldSatisfy` T.isInfixOf "SINGLETON"

  -- Semiparametric shape read-off -------------------------------------------
  describe "semiparametric (spec 6.2.1) exposes the profile as a curve" $ do
    it "emits a multi-point (moneyness, upsilon-hat) curve" $ do
      let e = semiparametricSpec (plantedPanel 0.0 2.0 2.0e-3)
      estIdentified e `shouldBe` True
      length (estCurve e) `shouldSatisfy` (>= 2)

    it "produces a DECLINING profile when kappa > 0 was planted" $ do
      let e  = semiparametricSpec (plantedPanel 0.0 2.0 2.0e-3)
          us = map snd (estCurve e)
      -- first bin (nearest the money) must carry more vega than the last
      head us `shouldSatisfy` (> last us)

    it "produces a FLAT profile when kappa = 0 was planted (the null)" $ do
      let e  = semiparametricSpec (plantedPanel 0.0 2.0 0.0)
          us = map snd (estCurve e)
          spread = maximum us - minimum us
      spread `shouldSatisfy` (< 1e-6 * maximum (map abs us) + 1e-6)

    it "reports NOT IDENTIFIED on a sample too small for two bins" $ do
      let tiny = take 5 (plantedPanel 0.0 2.0 2.0e-3)
          e    = semiparametricSpec tiny
      estIdentified e `shouldBe` False
      estNote e `shouldSatisfy` T.isInfixOf "NOT identified"

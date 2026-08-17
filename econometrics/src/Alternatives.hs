{-# LANGUAGE OverloadedStrings #-}

-- | The four LOCKED alternative specifications of the υ-identification spec
-- (§6.2), plan 09-09 / CTX-ALT.
--
-- The primary specification ("Model.NLS".'Model.NLS.fitGSL' on
-- "Model.Upsilon".'Model.Upsilon.model') imposes an exponential-moneyness vega
-- profile. Each alternative here relaxes exactly one of the assumptions that
-- profile embeds, so the four together are the spec's sensitivity analysis:
--
--   1. __semiparametric__ — υ(moneyness) is left unrestricted (a degree-0 B-spline
--      basis on moneyness quantile knots), σ̂² enters linearly. The null becomes a
--      SHAPE READ-OFF: does the estimated υ̂ profile decline in |i_K − i_t|? This
--      is the functional-form check for spec §6.1 sensitivity 1.
--   2. __seed-linear__ — the ORIGINAL @spec/panoptic.md@ tick linearization
--      @π = β₀ + υ(ī)·σ̂² + γ·((i_K − ī)·σ̂²)@, the reduced-form benchmark. It is the
--      first-order expansion of the exponential profile around the mean tick ī,
--      so the SIGN of @γ@ is the linear-benchmark echo of @κ@ (@γ < 0@ ⇔ @κ > 0@).
--   3. __position-FE__ — tokenId fixed effects (within transformation). A material
--      move in κ̂ versus the primary indicates strike-composition SELECTION was
--      doing work (spec §6.1 sensitivity 2, §6.2 diagnostic 3).
--   4. __collateral__ — the DEMOTED seed equation @Q_M = Q_M(υ=0) + υ·σ̂²@ re-run on
--      the collateral channel, so υ̂ can be compared across the premium and
--      collateral channels.
--
-- __Only these four.__ The spec locks the list; no further specifications are
-- added here.
--
-- __Honest non-identification.__ The live cross-section is thin (see the phase's
-- analysis output). Every estimator below returns an 'Estimates' record whose
-- 'estIdentified' flag is 'False' — with the reason in 'estNote' — when the design
-- cannot support it (too few observations, a rank-deficient design, no
-- within-cluster variation, or an absent data channel). A non-identified
-- alternative is REPORTED, never silently dropped and never padded with synthetic
-- data.
module Alternatives
  ( -- * Result record
    Estimates (..)
  , CollateralObs (..)
    -- * The four locked specifications
  , runAlternatives
  , runAlternativesWith
  , semiparametricSpec
  , seedLinearSpec
  , positionFESpec
  , collateralSpec
    -- * Shared least-squares machinery
  , olsCluster
  ) where

import           Data.List             (nub, sort, sortOn)
import qualified Data.Map.Strict       as Map
import           Data.Text             (Text)
import qualified Data.Text             as T
import qualified Numeric.LinearAlgebra as LA

import           Econ.Types            (Obs (..), Panel)
import           Model.SandwichSE      (clusterSandwich, standardErrors)
import           Model.Upsilon         (moneyness)

-- ---------------------------------------------------------------------------
-- Result record
-- ---------------------------------------------------------------------------

-- | One alternative specification's estimates, in a shape that is directly
-- comparable across the four (and against the primary fit).
data Estimates = Estimates
  { estLabel      :: !Text
    -- ^ Specification label (@"semiparametric"@, @"seed-linear"@,
    --   @"position-FE"@, @"collateral"@).
  , estCoefs      :: ![(Text, Double)]
    -- ^ Named point estimates, in design-column order.
  , estSEs        :: ![(Text, Double)]
    -- ^ tokenId-CLUSTERED CR0 standard errors, aligned with 'estCoefs'.
  , estNobs       :: !Int          -- ^ Observations entering the fit.
  , estClusters   :: !Int          -- ^ Distinct tokenId clusters.
  , estIdentified :: !Bool         -- ^ 'False' ⇒ read 'estNote', ignore the numbers.
  , estNote       :: !Text         -- ^ Interpretation / non-identification reason.
  , estCurve      :: ![(Double, Double)]
    -- ^ For the semiparametric spec: the estimated @(moneyness, υ̂)@ profile —
    --   the shape the null is read off. Empty for the other three.
  } deriving (Show, Eq)

-- | One observation of the COLLATERAL channel (alternative 4): a per-epoch
-- collateral requirement @Q_M@ for an account, to be regressed on σ̂².
-- Kept separate from 'Obs' because the collateral channel is account-level
-- (@PanopticPoolAccount.collateral{0,1}Shares@), not position-level.
data CollateralObs = CollateralObs
  { coAccount :: !Text    -- ^ Clustering unit for this channel.
  , coEpoch   :: !Int     -- ^ Daily epoch (same boundary as the panel).
  , coQM      :: !Double  -- ^ Collateral requirement Q_M.
  , coSigma2  :: !Double  -- ^ σ̂²_t joined onto the epoch.
  } deriving (Show, Eq)

-- ---------------------------------------------------------------------------
-- Entry points
-- ---------------------------------------------------------------------------

-- | Run all four locked alternatives on the premium panel. The collateral
-- channel has no data in this form, so alternative 4 reports itself
-- NOT ESTIMABLE; use 'runAlternativesWith' to supply it.
runAlternatives :: Panel -> [(Text, Estimates)]
runAlternatives = runAlternativesWith []

-- | Run all four locked alternatives, supplying the collateral-channel
-- observations for alternative 4.
runAlternativesWith :: [CollateralObs] -> Panel -> [(Text, Estimates)]
runAlternativesWith collat panel =
  [ ("semiparametric", semiparametricSpec panel)
  , ("seed-linear",    seedLinearSpec panel)
  , ("position-FE",    positionFESpec panel)
  , ("collateral",     collateralSpec collat)
  ]

-- ---------------------------------------------------------------------------
-- Shared design extraction
-- ---------------------------------------------------------------------------

-- | @(cluster, moneyness d, strike tick i_K, pool tick i_t, σ̂², π)@ for every
-- usable observation — the same finiteness filter as
-- "Model.NLS".'Model.NLS.designPoints', so all specifications see one design.
rows :: Panel -> [(Text, Double, Double, Double, Double, Double)]
rows panel =
  [ (obsTokenId o, d, fromIntegral (obsStrikeTick o), fromIntegral (obsPoolTick o), s2, y)
  | o <- panel
  , let d  = moneyness (obsStrikeTick o) (obsPoolTick o)
        s2 = obsSigma2 o
        y  = obsPremium o
  , finite s2, finite y, finite d
  ]

finite :: Double -> Bool
finite x = not (isNaN x || isInfinite x)

-- ---------------------------------------------------------------------------
-- Least squares with clustered SEs
-- ---------------------------------------------------------------------------

-- | OLS @β̂ = (XᵀX)⁻¹Xᵀy@ with tokenId-CLUSTERED CR0 standard errors from
-- "Model.SandwichSE".'clusterSandwich' (for a linear model the score row IS the
-- regressor row, so the sandwich applies unchanged).
--
-- Returns 'Nothing' when the design cannot support the fit: fewer observations
-- than columns, or a numerically rank-deficient @XᵀX@ (reciprocal condition
-- number below @1e-12@) — the two ways a thin cross-section fails to identify a
-- specification. Callers turn that into an explicit NOT-IDENTIFIED report.
olsCluster :: [[Double]] -> [Double] -> [Text] -> Maybe ([Double], [Double])
olsCluster xRows y clusters
  | n == 0 || n <= k          = Nothing
  | LA.rcond xtx < 1e-12      = Nothing
  | otherwise                 = Just (coefs, ses)
  where
    n     = length xRows
    k     = case xRows of { (r : _) -> length r; [] -> 0 }
    xMat  = LA.fromLists xRows
    yVec  = LA.vector y
    xtx   = LA.tr xMat LA.<> xMat
    coefs = LA.toList (xMat LA.<\> yVec)
    resid = zipWith (\r yi -> yi - sum (zipWith (*) r coefs)) xRows y
    ses   = standardErrors (clusterSandwich xRows resid clusters)

-- | Distinct cluster count.
nClusters :: [Text] -> Int
nClusters = length . nub

-- | A uniform NOT-IDENTIFIED result.
notIdentified :: Text -> Int -> Int -> Text -> Estimates
notIdentified lbl n g why = Estimates
  { estLabel = lbl, estCoefs = [], estSEs = []
  , estNobs = n, estClusters = g
  , estIdentified = False, estNote = why, estCurve = [] }

-- ---------------------------------------------------------------------------
-- (1) Semiparametric υ(moneyness), σ² linear
-- ---------------------------------------------------------------------------

-- | __Alternative 1 (spec §6.2.1).__ Leave the vega profile unrestricted:
--
-- @π_it = β₀ + Σ_b υ_b · 1[d_it ∈ bin b] · σ̂²_t + v_it@
--
-- The bins are a degree-0 B-spline (regressogram) basis on QUANTILE knots of the
-- moneyness distribution — deliberately the lowest-order basis, because a cubic
-- spline or a kernel bandwidth cannot be honestly selected on a cross-section of
-- this size. The number of bins is chosen so each bin holds at least
-- 'minPerBin' observations, capped at 'maxBins'.
--
-- The null is then a SHAPE READ-OFF from 'estCurve': under H₁ (κ > 0) the υ̂_b
-- decline monotonically in the bin's moneyness; under H₀ (κ = 0) they are flat.
-- No functional form is imposed, so this is the check on spec §6.1 sensitivity 1.
semiparametricSpec :: Panel -> Estimates
semiparametricSpec panel
  | nObs == 0 = notIdentified lbl 0 0 "no usable observations"
  | nBins < 2 =
      notIdentified lbl nObs nG
        (T.pack ("only " <> show nObs <> " usable observations — fewer than the "
                 <> show (2 * minPerBin) <> " needed for a 2-bin profile; "
                 <> "a semiparametric shape is NOT identified"))
  | otherwise = case olsCluster xRows ys clusters of
      Nothing -> notIdentified lbl nObs nG
                   "design rank-deficient (bins collinear after the σ̂² interaction)"
      Just (coefs, ses) ->
        Estimates
          { estLabel      = lbl
          , estCoefs      = zip names coefs
          , estSEs        = zip names ses
          , estNobs       = nObs
          , estClusters   = nG
          , estIdentified = True
          , estNote       =
              T.pack ("degree-0 B-spline (regressogram) vega profile on "
                      <> show nBins <> " moneyness quantile bins, σ̂² linear; "
                      <> "read the null off estCurve: declining υ̂ in moneyness = "
                      <> "evidence for κ>0, flat = evidence for H₀")
          , estCurve      = zip binMids (drop 1 coefs)
          }
  where
    lbl        = "semiparametric"
    ds         = rows panel
    nObs       = length ds
    clusters   = [ c | (c, _, _, _, _, _) <- ds ]
    nG         = nClusters clusters
    minPerBin  = 6 :: Int
    maxBins    = 5 :: Int
    nBins      = min maxBins (nObs `div` minPerBin)
    -- Quantile knots on the moneyness distribution.
    sortedD    = sort [ d | (_, d, _, _, _, _) <- ds ]
    cuts       = [ sortedD !! min (nObs - 1) (j * nObs `div` nBins)
                 | j <- [1 .. nBins - 1] ]
    binOf d    = length (takeWhile (<= d) cuts)
    binMids    = [ mid b | b <- [0 .. nBins - 1] ]
    mid b      = let inB = [ d | (_, d, _, _, _, _) <- ds, binOf d == b ]
                 in if null inB then 0 / 0 else sum inB / fromIntegral (length inB)
    -- Design: intercept, then one (bin indicator × σ̂²) column per bin.
    xRows      = [ 1 : [ if binOf d == b then s2 else 0 | b <- [0 .. nBins - 1] ]
                 | (_, d, _, _, s2, _) <- ds ]
    ys         = [ y | (_, _, _, _, _, y) <- ds ]
    names      = "beta0" : [ T.pack ("upsilon_bin" <> show b) | b <- [0 .. nBins - 1] ]

-- ---------------------------------------------------------------------------
-- (2) Seed linear interaction
-- ---------------------------------------------------------------------------

-- | __Alternative 2 (spec §6.2.2).__ The original @spec/panoptic.md@ tick
-- linearization, as a reduced-form benchmark:
--
-- @π_it = β₀ + υ(ī)·σ̂²_t + γ·((i_K − ī)·σ̂²_t) + v_it@
--
-- The strike tick enters CENTERED at the sample mean pool tick ī. Centering is
-- not cosmetic: spec §4.3 derives this equation as the first-order expansion of
-- @υ₀·exp(−κ|i_K − i_t|)@ AROUND ī, so @(i_K − ī)@ is the expansion variable, and
-- on this market raw ticks are ≈ −200 000, which would leave the uncentered
-- design numerically rank-deficient against the intercept.
--
-- Interpretation: the linear benchmark cannot express an ATM PEAK (it is
-- monotone in the tick), so it detects only the local slope. @γ < 0@ for strikes
-- above the money is the linear echo of @κ > 0@; the semiparametric spec is what
-- actually adjudicates the shape.
seedLinearSpec :: Panel -> Estimates
seedLinearSpec panel
  | nObs == 0 = notIdentified lbl 0 0 "no usable observations"
  | nObs <= 3 = notIdentified lbl nObs nG "fewer observations than parameters (3)"
  | otherwise = case olsCluster xRows ys clusters of
      Nothing -> notIdentified lbl nObs nG
                   "design rank-deficient — no strike variation at given σ̂² (γ not identified)"
      Just (coefs, ses) ->
        Estimates
          { estLabel      = lbl
          , estCoefs      = zip names coefs
          , estSEs        = zip names ses
          , estNobs       = nObs
          , estClusters   = nG
          , estIdentified = True
          , estNote       =
              let gHat = case drop 2 coefs of { (g : _) -> g; [] -> 0 / 0 }
                  gSE  = case drop 2 ses   of { (g : _) -> g; [] -> 0 / 0 }
                  gRead
                    | isNaN gHat = "gamma was not estimated."
                    | abs gHat <= gSE =
                        "gamma = " <> show gHat <> " is SMALLER than its clustered SE ("
                          <> show gSE <> "), i.e. indistinguishable from zero: the linear "
                          <> "benchmark detects no strike tilt in either direction."
                    | gHat < 0 =
                        "gamma = " <> show gHat <> " < 0 - the linear echo of kappa > 0 "
                          <> "(vega falling as the strike moves above the money)."
                    | otherwise =
                        "gamma = " <> show gHat <> " > 0 - the OPPOSITE sign to the one "
                          <> "kappa > 0 predicts (vega RISING with the strike). Read "
                          <> "alongside the semiparametric profile before concluding "
                          <> "anything from it."
              in T.pack ("seed tick-linearization, strike centered at the mean pool tick "
                         <> "i-bar = " <> show (round iBar :: Int)
                         <> ". This form cannot express an ATM PEAK (it is monotone in "
                         <> "the tick), so it detects only a local slope. " <> gRead)
          , estCurve      = []
          }
  where
    lbl      = "seed-linear"
    ds       = rows panel
    nObs     = length ds
    clusters = [ c | (c, _, _, _, _, _) <- ds ]
    nG       = nClusters clusters
    iBar     = if nObs == 0 then 0
               else sum [ it | (_, _, _, it, _, _) <- ds ] / fromIntegral nObs
    xRows    = [ [1, s2, (iK - iBar) * s2] | (_, _, iK, _, s2, _) <- ds ]
    ys       = [ y | (_, _, _, _, _, y) <- ds ]
    names    = ["beta0", "upsilon_ibar", "gamma"]

-- ---------------------------------------------------------------------------
-- (3) Position-FE / within estimator
-- ---------------------------------------------------------------------------

-- | __Alternative 3 (spec §6.2.3).__ The no-selection diagnostic: add tokenId
-- fixed effects and re-estimate the exponential profile WITHIN position.
--
-- Because the model is nonlinear in κ, the within estimator is computed by
-- CONCENTRATION: for each κ on a grid, form @w_it(κ) = exp(−κ·d_it)·σ̂²_t@,
-- demean both @π@ and @w@ within tokenId, take the within OLS slope, and select
-- the κ minimizing the within sum of squares. The reported κ̂ is that minimizer
-- and υ̂₀ the associated within slope; the intercept is absorbed by the effects.
--
-- __The diagnostic.__ A material move in κ̂ versus the primary fit means the
-- cross-position (strike-composition) variation — which the FE transformation
-- discards — was doing the identifying work, i.e. selection contaminates the
-- primary κ̂ (spec §6.1 sensitivity 2).
--
-- __Identification requirement.__ The within transformation annihilates every
-- SINGLETON tokenId. If no tokenId contributes ≥ 2 observations there is no
-- within variation at all and the specification is reported NOT IDENTIFIED — the
-- expected outcome on a cross-section of one-spell-per-position, and an honest
-- null result rather than a fabricated coefficient.
positionFESpec :: Panel -> Estimates
positionFESpec panel
  | nObsAll == 0 = notIdentified lbl 0 0 "no usable observations"
  | nObs == 0 =
      notIdentified lbl nObsAll nGAll
        (T.pack ("every tokenId is a SINGLETON (" <> show nGAll <> " clusters over "
                 <> show nObsAll <> " observations) — the within transformation "
                 <> "annihilates the whole sample; position fixed effects are NOT "
                 <> "identified on this cross-section"))
  | nObs < 3 =
      notIdentified lbl nObs nG
        (T.pack ("only " <> show nObs <> " observations survive the within "
                 <> "transformation (" <> show nG <> " multi-spell tokenIds) — too "
                 <> "few to identify the within profile"))
  | otherwise = case olsCluster xRows ys clusters of
      Nothing -> notIdentified lbl nObs nG
                   "within design rank-deficient (no within-tokenId variation in w)"
      Just (coefs, ses) ->
        Estimates
          { estLabel      = lbl
          , estCoefs      = [("kappa_FE", kHat)] <> zip names coefs
          , estSEs        = [("kappa_FE", 0 / 0)] <> zip names ses
          , estNobs       = nObs
          , estClusters   = nG
          , estIdentified = not kAtBoundary
          , estNote       = T.pack $
              if kAtBoundary
                then "kappa_FE = " <> show kHat <> " sits ON THE BOUNDARY of the search "
                     <> "grid, so the within objective is FLAT in kappa: the within "
                     <> "variation (only " <> show nObs <> " observations across "
                     <> show nG <> " multi-spell tokenIds) does not identify the decay "
                     <> "rate. The no-selection diagnostic is therefore UNAVAILABLE and "
                     <> "the strike-composition threat is UNRESOLVED, not cleared."
                else "within (tokenId-FE) estimator, kappa concentrated over a grid; "
                     <> "SE(kappa_FE) is NaN by construction — kappa is profiled, not "
                     <> "jointly estimated. Compare kappa_FE with the primary kappa: a "
                     <> "material move indicates strike-composition selection"
          , estCurve      = []
          }
  where
    lbl      = "position-FE"
    dsAll    = rows panel
    nObsAll  = length dsAll
    nGAll    = nClusters [ c | (c, _, _, _, _, _) <- dsAll ]
    -- Keep only tokenIds with >= 2 observations: singletons carry no within info.
    counts   = Map.fromListWith (+) [ (c, 1 :: Int) | (c, _, _, _, _, _) <- dsAll ]
    ds       = [ r | r@(c, _, _, _, _, _) <- dsAll
               , Map.findWithDefault 0 c counts >= 2 ]
    nObs     = length ds
    clusters = [ c | (c, _, _, _, _, _) <- ds ]
    nG       = nClusters clusters

    -- Concentrated grid search over kappa (log-spaced; ticks are O(10^3) here so
    -- the informative kappa range is small).
    kGrid    = [ 10 ** e | e <- [-6, -5.75 .. -1] ] :: [Double]
    kHat     = case sortOn snd [ (k, withinSSE k) | k <- kGrid ] of
                 ((k, _) : _) -> k
                 []           -> 0 / 0
    -- A minimizer sitting on an endpoint of the grid is not an interior optimum:
    -- the within objective is flat in kappa and the value carries no information.
    kAtBoundary = not (null kGrid)
                    && (kHat <= minimum kGrid * 1.001 || kHat >= maximum kGrid * 0.999)

    withinD k = demeanBy clusters [ exp (negate k * d) * s2
                                  | (_, d, _, _, s2, _) <- ds ]
    yDemeaned = demeanBy clusters [ y | (_, _, _, _, _, y) <- ds ]
    withinSSE k =
      let w  = withinD k
          sw = sum (zipWith (*) w yDemeaned)
          ww = sum (zipWith (*) w w)
          b  = if ww <= 0 then 0 else sw / ww
      in sum [ (yi - b * wi) ^ (2 :: Int) | (yi, wi) <- zip yDemeaned w ]

    xRows    = [ [w] | w <- withinD kHat ]
    ys       = yDemeaned
    names    = ["upsilon0_within"]

-- | Subtract each group's mean from its members (the within transformation).
demeanBy :: [Text] -> [Double] -> [Double]
demeanBy gs xs = zipWith (\g x -> x - Map.findWithDefault 0 g means) gs xs
  where
    sums   = Map.fromListWith (+) (zip gs xs)
    counts = Map.fromListWith (+) [ (g, 1 :: Int) | g <- gs ]
    means  = Map.intersectionWith (\s c -> s / fromIntegral c) sums counts

-- ---------------------------------------------------------------------------
-- (4) Collateral-channel robustness
-- ---------------------------------------------------------------------------

-- | __Alternative 4 (spec §6.2.4).__ The DEMOTED seed equation, re-run on the
-- collateral channel:
--
-- @Q_M,at = Q_M(υ=0)_a + υ·σ̂²_t + v_at@
--
-- The protocol collateral schedule is known code, so a υ̂ recovered here is
-- directly comparable with the premium-channel υ̂₀: agreement is evidence the
-- vega is a property of the position rather than of the premium accounting.
--
-- Clustered by ACCOUNT (the collateral channel's unit —
-- @PanopticPoolAccount.collateral{0,1}Shares@), not by tokenId.
collateralSpec :: [CollateralObs] -> Estimates
collateralSpec obs
  | null usable =
      notIdentified "collateral" 0 0
        ("NOT ESTIMABLE: no collateral-channel observations supplied. The Panoptic \
         \subgraph exposes PanopticPoolAccount.collateral{0,1}Shares only as a \
         \CURRENT snapshot (no historical series) and CollateralDayData carries no \
         \per-account requirement, so Q_M cannot be formed as a per-epoch panel \
         \from this source.")
  | length usable <= 2 =
      notIdentified "collateral" (length usable) nG
        "fewer collateral observations than parameters (2)"
  | otherwise = case olsCluster xRows ys clusters of
      Nothing -> notIdentified "collateral" (length usable) nG
                   "collateral design rank-deficient (no sigma2 variation)"
      Just (coefs, ses) ->
        Estimates
          { estLabel      = "collateral"
          , estCoefs      = zip names coefs
          , estSEs        = zip names ses
          , estNobs       = length usable
          , estClusters   = nG
          , estIdentified = True
          , estNote       = "CAVEAT FIRST: Q_M here is DEPOSITED collateral shares \
                            \reconstructed from CollateralDeposit/Withdraw events, NOT \
                            \the protocol's required margin. The subgraph exposes no \
                            \per-position collateral requirement (collateral*Shares is a \
                            \CURRENT snapshot only; CollateralDayData is vault-level), so \
                            \this is a behavioural quantity and is NOT the spec's Q_M. \
                            \Any comparison with the premium-channel upsilon0 is \
                            \suggestive at best. Clustered by ACCOUNT."
          , estCurve      = []
          }
  where
    usable   = [ o | o <- obs, finite (coQM o), finite (coSigma2 o) ]
    clusters = map coAccount usable
    nG       = nClusters clusters
    xRows    = [ [1, coSigma2 o] | o <- usable ]
    ys       = [ coQM o | o <- usable ]
    names    = ["QM_upsilon0", "upsilon_collateral"]

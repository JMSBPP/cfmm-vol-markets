-- | The three committed specification tests (spec §5, plan 09-08), each computed
-- against the tokenId-__clustered__ CR0 covariance from "Model.SandwichSE" —
-- never the naive OLS SEs.
--
-- The restrictions (spec §5, and the econometric twin of the Lean conjecture in
-- @lean/vol_markets/Upsilon.lean@):
--
--   1. __υ₀ > 0__  — sign restriction, "υ is a vega": one-sided t/Wald ('testUpsilonPos').
--   2. __κ > 0__   — sign restriction, ATM-max + exponential OTM decay: one-sided
--      t/Wald ('testKappaPos'). This IS the null-hypothesis test (H₀: κ = 0 vs H₁: κ > 0).
--   3. __κ⁺ = κ⁻__ — equality restriction, symmetric decay: a Wald test on the 2×2
--      sub-block of the split (4-param) covariance ('testSymmetry'); rejection ⇒
--      put/call-side skew.
--
-- The two restrictions that were DELIBERATELY excluded during questioning (see
-- the spec §5 parenthetical) are intentionally not implemented here — only the
-- three committed tests above appear in this module.
--
-- p-values come from the @statistics@ package (standard Normal upper tail for the
-- one-sided sign tests, χ²₁ upper tail for the one-restriction Wald), never a
-- hand-rolled series.
module Tests.Specification
  ( TestResult (..)
  , Theta4 (..)
  , testUpsilonPos
  , testKappaPos
  , testSymmetry
  ) where

import           Numeric.LinearAlgebra           (Matrix, atIndex)
import           Statistics.Distribution         (complCumulative)
import           Statistics.Distribution.ChiSquared (chiSquared)
import           Statistics.Distribution.Normal  (standard)

import           Econ.Types                      (Theta (..))

-- | Significance level for the @reject@ decision (5%).
alpha :: Double
alpha = 0.05

-- | A single specification-test outcome: the (signed, one-sided or χ²) statistic,
-- its p-value, and the @reject at α = 0.05@ decision.
data TestResult = TestResult
  { statistic :: Double  -- ^ Wald/t statistic.
  , pValue    :: Double  -- ^ Upper-tail p-value (one-sided Normal / χ²₁).
  , reject    :: Bool    -- ^ @pValue < α@.
  } deriving (Show, Eq)

-- | The split (κ⁺/κ⁻) parameter vector @[β₀, υ₀, κ⁺, κ⁻]@ fitted with
-- 'Model.Upsilon.modelSplit'; the input to the symmetry Wald test. Indices line up
-- with the 4×4 split covariance: β₀=0, υ₀=1, κ⁺=2, κ⁻=3.
data Theta4 = Theta4
  { s4b0     :: !Double
  , s4u0     :: !Double
  , s4kPlus  :: !Double
  , s4kMinus :: !Double
  } deriving (Show, Eq)

-- | One-sided test of __υ₀ > 0__ (spec §5, test 1 — "υ is a vega"). Statistic
-- @z = υ̂₀ / SE(υ̂₀)@ with @SE@ from the clustered covariance (index 1); p-value is
-- the upper Normal tail @P(Z > z)@, so a large positive υ̂₀ yields a small p.
testUpsilonPos :: Theta -> Matrix Double -> TestResult
testUpsilonPos (Theta _ u0Hat _) cov = oneSidedUpper u0Hat (cov `atIndex` (1, 1))

-- | One-sided test of __κ > 0__ (spec §5, test 2) — __THE null-hypothesis test__,
-- H₀: κ = 0 (flat vega profile) vs H₁: κ > 0 (ATM max, exponential OTM decay).
-- Statistic @z = κ̂ / SE(κ̂)@ from the clustered covariance (index 2); upper-tail p.
testKappaPos :: Theta -> Matrix Double -> TestResult
testKappaPos (Theta _ _ kHat) cov = oneSidedUpper kHat (cov `atIndex` (2, 2))

-- | Shared one-sided (H₁: parameter > 0) Normal test given the point estimate and
-- its variance from the clustered covariance.
oneSidedUpper :: Double -> Double -> TestResult
oneSidedUpper est var =
  let se = sqrt var
      z  = est / se
      p  = complCumulative standard z   -- P(Z > z), upper tail
  in TestResult { statistic = z, pValue = p, reject = p < alpha }

-- | Wald test of __κ⁺ = κ⁻__ (spec §5, test 3 — symmetric decay) on the 2×2
-- κ-sub-block of the split (4-param) clustered covariance. The single linear
-- restriction is @R θ = κ⁺ − κ⁻ = 0@, so
--
-- @
--   W = (κ̂⁺ − κ̂⁻)² / [ Var(κ̂⁺) + Var(κ̂⁻) − 2·Cov(κ̂⁺, κ̂⁻) ]   ~  χ²₁  under H₀
-- @
--
-- (indices 2 = κ⁺, 3 = κ⁻). Rejection ⇒ asymmetric put/call-side skew.
testSymmetry :: Theta4 -> Matrix Double -> TestResult
testSymmetry (Theta4 _ _ kp km) cov =
  let vkp  = cov `atIndex` (2, 2)
      vkm  = cov `atIndex` (3, 3)
      ckk  = cov `atIndex` (2, 3)
      diff = kp - km
      var  = vkp + vkm - 2 * ckk
      w    = diff * diff / var
      p    = complCumulative (chiSquared 1) w   -- χ²₁ upper tail
  in TestResult { statistic = w, pValue = p, reject = p < alpha }

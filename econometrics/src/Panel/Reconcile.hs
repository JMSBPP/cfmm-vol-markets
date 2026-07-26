{-# LANGUAGE OverloadedStrings #-}

-- | The reconciliation gate: rebuild each accrual spell's premium from the
-- endpoint accumulator readings and compare it against the protocol's own
-- @OptionBurn.premium0@.
--
-- == Why the tolerance is 1% and not 10%
--
-- @OptionBurn.premiaByLeg@ is, by construction (@PanopticPool._getPremia@
-- L2272-2298),
--
-- @
-- premium = (acc(t_burn) - s_options[owner][tokenId][leg]) * legLiquidity \`div\` 2^64
-- @
--
-- and the per-epoch panel sums TELESCOPICALLY over the same accumulator to the
-- same endpoint difference (@Panoptic.Premium.telescope@, asserted as exact
-- integer equality). The reconstructed panel is therefore a /decomposition/ of
-- the ground truth, not an independent estimate of it. A miss between 1% and 10%
-- means an unaccounted wedge and should trigger diagnosis, not celebration.
--
-- == Three properties this module refuses to give up
--
--   * __The gate runs in ETH wei.__ Every quantity through 'reconstructSpell' is
--     'Integer' wei; the first 'Double' appears in 'srRelError'. No price
--     conversion enters the gate path at all — Phase 9 found token1's 6 decimals
--     truncate small premia (61 non-zero @premium0@ against 38 non-zero
--     @premium1@), and a conversion factor is exactly the kind of noise that
--     would make a 1% target meaningless.
--   * __Short and long strata are reported SEPARATELY and never pooled__
--     ('stratify'). @PanopticPool._getAvailablePremium@ (L588-599) caps settled
--     long premium at what the pool can actually pay, so @OptionBurn.premium@
--     reports the SETTLED amount while the accumulator reports the ACCRUED one.
--     A downward long-stratum wedge is EXPECTED. Do not let a handful of capped
--     longs fail a gate the shorts pass, and do not hide them either.
--   * __Leg-count mismatches are surfaced, never quietly absorbed__ (RESEARCH
--     Pitfall 7). The scalar @premium0@ is the sum over legs; if the
--     reconstruction covered fewer legs than the position has, the comparison is
--     not like-for-like and the spell is listed as a mismatch.
module Panel.Reconcile
  ( -- * Spell reconstruction
    SpellInput
  , SpellRecon (..)
  , AccIndex
  , buildAccIndex
  , reconstructSpell
  , reconstructSpellWith
    -- * Ground-truth units
  , GroundTruthUnit (..)
  , classifyGroundTruthUnit
  , groundTruthWei
  , groundTruthExpr
    -- * Error distribution
  , ErrorDist (..)
  , errorDist
  , stratify
    -- * The gate
  , gateTolerance
  , ReconReport (..)
  , reportOf
  , reconcileSpells
  , reconcile
  , renderReconReport
  ) where

import           Data.List          (intercalate, nub, sort, sortOn)
import           Data.Map.Strict    (Map)
import qualified Data.Map.Strict    as Map
import           Data.Maybe         (isNothing, mapMaybe)
import           Data.Text          (Text)
import qualified Data.Text          as T
import           Text.Printf        (printf)

import           Panel.Subgraph     (BurnEvent (..), MintEvent (..))
import           Panoptic.Chunk     (ChunkKey (..), LegChunk (..), storedValueTick)
import           Panoptic.Premium   (PremiumFlag (..), isFrozenAcc, premiumWei)
import           Panoptic.ReadDriver (AccKey, AccRow (..), loadAccumulators)

-- ---------------------------------------------------------------------------
-- THE GATE TOLERANCE
-- ---------------------------------------------------------------------------

-- | __The reconciliation gate tolerance: median relative error <= 1%.__
--
-- Defined ONCE, as a named top-level constant, and referenced from the CLI and
-- the spec alike — it exists as a single greppable symbol precisely so that any
-- future attempt to relax it is a visible, reviewable diff rather than an inline
-- number quietly edited at a call site.
--
-- __Relaxing this constant to make a failing gate pass is forbidden by the phase
-- contract.__ A failed gate is a legitimate phase outcome; a moved goalpost is
-- not. See @10-CONTEXT.md@ \"Validation gate\": diagnose and fix the
-- reconstruction, do NOT relax the tolerance.
gateTolerance :: Double
gateTolerance = 0.01

-- ---------------------------------------------------------------------------
-- Inputs
-- ---------------------------------------------------------------------------

-- | One spell to reconcile: its tokenId, the paired mint\/burn events, and the
-- legs already resolved to chunks (@width == 0@ legs dropped by
-- 'Panoptic.Chunk.resolveLegChunks', exactly as @_getPremia@ L2250 skips them).
type SpellInput = (Text, MintEvent, BurnEvent, [LegChunk])

-- | Accumulator readings keyed on the POOL-WIDE read identity WITHOUT the
-- @atTick@ component: @(tokenType, tickLower, tickUpper, block, isLong)@.
--
-- The @atTick@ is deliberately dropped from the key. An endpoint read is
-- scheduled at the exact mint\/burn block with that event's tick, but the
-- pool-wide dedup in @buildReadSchedule@ can retain an interior epoch-boundary
-- row instead when the two coincide on a block. Keying on the block alone finds
-- the reading either way; the endpoint-tagged row is preferred when both exist.
type AccIndex = Map (Int, Int, Int, Integer, Bool) [AccRow]

-- | Index the loaded accumulator cache for endpoint lookup.
buildAccIndex :: Map AccKey AccRow -> AccIndex
buildAccIndex m =
  Map.fromListWith (++)
    [ ( (acTokenType r, acTickLower r, acTickUpper r, acBlock r, acIsLong r), [r] )
    | r <- Map.elems m ]

-- | The reading for a chunk\/side at an exact block, preferring the row tagged
-- with the requested spell endpoint. 'Nothing' means the cache has no reading
-- there — a hole, which is reported as a leg-count mismatch rather than
-- substituted with a zero.
lookupAt :: AccIndex -> Text -> ChunkKey -> Integer -> Bool -> Maybe AccRow
lookupAt ix tag ck blk isLong =
  case Map.lookup (ckTokenType ck, ckTickLower ck, ckTickUpper ck, blk, isLong) ix of
    Nothing   -> Nothing
    Just rows -> case [ r | r <- rows, acEndpoint r == Just tag ] of
      (r : _) -> Just r
      []      -> case rows of
        (r : _) -> Just r
        []      -> Nothing

-- ---------------------------------------------------------------------------
-- Ground-truth units
-- ---------------------------------------------------------------------------

-- | Which unit the subgraph reports @OptionBurn.premium0@ in.
--
-- @BurnEvent.bePremium0@ is a 'Double' decoded from the subgraph's BigInt
-- string, so its unit must be DETERMINED, not assumed: a @1e18@ unit error is
-- the single most likely cause of a catastrophic gate failure and the cheapest
-- to rule out first (RESEARCH Pitfall 2 names \"off by exactly 1e18\" as a
-- diagnostic signature).
data GroundTruthUnit
  = RawWei   -- ^ already in raw 18-decimal token units (wei).
  | WholeEth -- ^ in whole token units; multiply by @1e18@.
  deriving (Show, Eq)

-- | Classify the reported unit from the MAGNITUDE of the observed premia.
--
-- On this market a spell's premium is on the order of @1e-6 .. 1e-2@ ETH, which
-- is @1e12 .. 1e16@ in raw 18-decimal units. The two populations are twelve
-- orders of magnitude apart, so the median non-zero magnitude separates them
-- with an enormous margin; @1e6@ is the (arbitrary, safely-placed) cut.
classifyGroundTruthUnit :: [BurnEvent] -> GroundTruthUnit
classifyGroundTruthUnit bs
  | null mags = RawWei
  | med >= 1e6 = RawWei
  | otherwise  = WholeEth
  where
    mags = sort [ abs (bePremium0 b) | b <- bs, bePremium0 b /= 0 ]
    med  = medianD mags

-- | The ground truth in wei under a determined unit. @round@ is exact for every
-- magnitude on this market (all well under @2^53@).
groundTruthWei :: GroundTruthUnit -> BurnEvent -> Integer
groundTruthWei RawWei   b = round (bePremium0 b)
groundTruthWei WholeEth b = round (bePremium0 b * 1e18)

-- | The converting expression, recorded verbatim in the report so the
-- determination is auditable rather than folded away.
groundTruthExpr :: GroundTruthUnit -> Text
groundTruthExpr RawWei   = "truthWei = round(premium0)                -- premium0 is ALREADY raw 18-decimal units"
groundTruthExpr WholeEth = "truthWei = round(premium0 * 1e18)         -- premium0 is in whole token units"

-- ---------------------------------------------------------------------------
-- Spell reconstruction
-- ---------------------------------------------------------------------------

-- | One reconciled spell. Everything but 'srRelError' is exact 'Integer' wei.
data SpellRecon = SpellRecon
  { srTokenId        :: !Text
  , srIsLong         :: !Bool           -- ^ stratum, from the position's first resolved leg.
  , srLegCount       :: !Int            -- ^ legs actually reconstructed (both endpoint readings found).
  , srLegCountTruth  :: !Int            -- ^ legs the scalar ground truth sums over (RESEARCH Pitfall 7).
  , srReconWei       :: !Integer        -- ^ reconstructed premium0, wei.
  , srTruthWei       :: !Integer        -- ^ @OptionBurn.premium0@, wei.
  , srRelError       :: !(Maybe Double) -- ^ @|recon - truth| \/ |truth|@; 'Nothing' when truth is 0.
  , srSignedErrorWei :: !Integer        -- ^ @recon - truth@; its SIGN is the multiplier-vs-rounding diagnostic.
  , srFlags          :: ![PremiumFlag]
  , srMintBlock      :: !Integer
  , srBurnBlock      :: !Integer
  }
  deriving (Show, Eq)

-- | True when the reconstruction did not cover every leg the scalar ground truth
-- sums over — reported, never quietly reconciled.
isMismatch :: SpellRecon -> Bool
isMismatch r = srLegCount r /= srLegCountTruth r

-- | Reconstruct one spell against an already-built index and a determined
-- ground-truth unit.
--
-- For each leg: read the accumulator at the EXACT mint block and the EXACT burn
-- block (the @rrEndpoint = mint\/burn@ rows written by 10-06 — not the nearest
-- epoch boundary, which RESEARCH lists as a wedge), selecting the gross
-- accumulator for short legs and the owed accumulator for long legs, then
--
-- @
-- legWei = premiumWei accBurn accMint (lcLiquidity lc) (lcIsLong lc)
-- @
--
-- and sum over legs. No conversion of any kind happens here.
reconstructSpellWith :: GroundTruthUnit -> AccIndex -> SpellInput -> SpellRecon
reconstructSpellWith unit ix (tid, me, be, legChunks) =
  SpellRecon
    { srTokenId        = tid
    , srIsLong         = isLongStratum
    , srLegCount       = length legs
    , srLegCountTruth  = length legChunks
    , srReconWei       = reconWei
    , srTruthWei       = truthWei
    , srRelError       = relErrorOf reconWei truthWei
    , srSignedErrorWei = reconWei - truthWei
    , srFlags          = nub (sort (concatMap snd legs))
    , srMintBlock      = mb
    , srBurnBlock      = bb
    }
  where
    mb = meBlock me
    bb = beBlock be
    isLongStratum = case legChunks of
      (lc : _) -> lcIsLong lc
      []       -> False
    legs     = mapMaybe legOf legChunks
    reconWei = sum (map fst legs)
    truthWei = groundTruthWei unit be

    legOf lc = do
      rMint <- lookupAt ix "mint" (lcChunkKey lc) mb (lcIsLong lc)
      rBurn <- lookupAt ix "burn" (lcChunkKey lc) bb (lcIsLong lc)
      let w = premiumWei (acAcc0 rBurn) (acAcc0 rMint) (lcLiquidity lc) (lcIsLong lc)
      pure (w, flagsOf rMint ++ flagsOf rBurn)

    flagsOf r = concat
      [ [ChunkEmpty   | acNetLiq r == 0]
      , [AccFrozen    | isFrozenAcc (acAcc0 r) || isFrozenAcc (acAcc1 r)]
      , [Extrapolated | acAtTick r /= storedValueTick]
      ]

-- | 'reconstructSpellWith' against the raw cache map, classifying the
-- ground-truth unit from the spell's own burn. Batch callers should prefer
-- 'reconcileSpells', which classifies over the whole population and builds the
-- index once.
reconstructSpell :: Map AccKey AccRow -> SpellInput -> SpellRecon
reconstructSpell accMap si@(_, _, be, _) =
  reconstructSpellWith (classifyGroundTruthUnit [be]) (buildAccIndex accMap) si

-- | @|recon - truth| \/ |truth|@, or 'Nothing' when the ground truth is zero —
-- such spells are EXCLUDED from the distribution and counted separately
-- ('edZeroTruth') rather than contributing a division by zero or a silent 0.
relErrorOf :: Integer -> Integer -> Maybe Double
relErrorOf recon truth
  | truth == 0 = Nothing
  | otherwise  = Just (abs (fromInteger (recon - truth)) / abs (fromInteger truth))

-- ---------------------------------------------------------------------------
-- Error distribution
-- ---------------------------------------------------------------------------

-- | The error distribution of a set of spells. The median alone is not the
-- report: the quantiles show the tail, and the SIGN counts separate a multiplier
-- bug (systematic one-sided bias) from a rounding issue (balanced) — RESEARCH's
-- stated diagnostic.
data ErrorDist = ErrorDist
  { edN         :: !Int     -- ^ spells with a defined relative error.
  , edMedian    :: !Double
  , edP25       :: !Double
  , edP75       :: !Double
  , edP90       :: !Double
  , edMax       :: !Double
  , edPosCount  :: !Int     -- ^ spells over-reconstructed (@recon > truth@).
  , edNegCount  :: !Int     -- ^ spells under-reconstructed (@recon < truth@).
  , edZeroTruth :: !Int     -- ^ spells EXCLUDED because the ground truth is 0.
  }
  deriving (Show, Eq)

-- | Median, IQR, p90, max and sign counts over a set of reconciled spells. An
-- empty set yields NaN quantiles — an honest \"no measurement\", never a 0 that
-- would read as a perfect gate.
errorDist :: [SpellRecon] -> ErrorDist
errorDist rs = ErrorDist
  { edN         = length es
  , edMedian    = medianD es
  , edP25       = quantileD 0.25 es
  , edP75       = quantileD 0.75 es
  , edP90       = quantileD 0.90 es
  , edMax       = if null es then 0 / 0 else maximum es
  , edPosCount  = length [ () | r <- included, srSignedErrorWei r > 0 ]
  , edNegCount  = length [ () | r <- included, srSignedErrorWei r < 0 ]
  , edZeroTruth = length [ () | r <- rs, isNothing (srRelError r) ]
  }
  where
    es       = mapMaybe srRelError rs
    included = [ r | r <- rs, not (isNothing (srRelError r)) ]

-- | Split into @(short, long)@ and give each stratum its OWN distribution.
--
-- These are never pooled into one verdict number: the long stratum carries the
-- known @_getAvailablePremium@ settlement cap, so pooling would either hide a
-- real short-side defect behind capped longs or fail a gate the shorts pass.
stratify :: [SpellRecon] -> (ErrorDist, ErrorDist)
stratify rs =
  ( errorDist [ r | r <- rs, not (srIsLong r) ]
  , errorDist [ r | r <- rs,      srIsLong r  ]
  )

-- ---------------------------------------------------------------------------
-- The report
-- ---------------------------------------------------------------------------

-- | The gate result: every spell, the three distributions, the mismatch list,
-- and the verdict.
data ReconReport = ReconReport
  { rrSpells     :: ![SpellRecon]
  , rrAll        :: !ErrorDist
  , rrShort      :: !ErrorDist
  , rrLong       :: !ErrorDist
  , rrMismatches :: ![SpellRecon]
  , rrPassed     :: !Bool
  , rrUnit       :: !GroundTruthUnit
  , rrLineage    :: ![(Text, Text)]
  }
  deriving (Show, Eq)

-- | Assemble the report — and THE VERDICT RULE — from reconciled spells. The
-- single definition of what passing means; every caller and the spec go through
-- it, so the rule cannot drift between them.
--
-- The verdict is scored on the SHORT stratum plus the absence of leg-count
-- mismatches. That is not a convenience: the long stratum's settlement cap is a
-- known protocol behaviour rather than a reconstruction defect, so it is
-- REPORTED in full and excluded from the pass\/fail arithmetic — RESEARCH's
-- instruction is exact on both halves of that. A leg-count mismatch means the
-- comparison was not like-for-like, so it cannot pass either.
reportOf :: [(Text, Text)] -> GroundTruthUnit -> [SpellRecon] -> ReconReport
reportOf lineage unit recons = ReconReport
  { rrSpells     = recons
  , rrAll        = errorDist recons
  , rrShort      = shortD
  , rrLong       = longD
  , rrMismatches = mismatches
  , rrPassed     = passed
  , rrUnit       = unit
  , rrLineage    = lineage
  }
  where
    (shortD, longD) = stratify recons
    mismatches      = filter isMismatch recons
    passed          = edN shortD > 0
                        && not (isNaN (edMedian shortD))
                        && edMedian shortD <= gateTolerance
                        && null mismatches

-- | Reconcile a population of spells against loaded accumulator readings.
reconcileSpells :: [(Text, Text)] -> Map AccKey AccRow -> [SpellInput] -> ReconReport
reconcileSpells lineage accMap sis =
  reportOf lineage unit (map (reconstructSpellWith unit ix) sis)
  where
    unit = classifyGroundTruthUnit [ be | (_, _, be, _) <- sis ]
    ix   = buildAccIndex accMap

-- | Load the accumulator cache and reconcile.
reconcile :: FilePath -> [SpellInput] -> IO ReconReport
reconcile accPath sis = do
  accMap <- loadAccumulators accPath
  pure (reconcileSpells
          [ ("accumulator readings", T.pack accPath)
          , ("readings loaded", tshow (Map.size accMap))
          , ("spells reconciled", tshow (length sis))
          ]
          accMap sis)

-- ---------------------------------------------------------------------------
-- Rendering
-- ---------------------------------------------------------------------------

-- | The markdown report: lineage, the two stratum tables, the full per-spell
-- table, the mismatch list, and the verdict.
renderReconReport :: ReconReport -> Text
renderReconReport rep = T.unlines $
  [ "# Reconciliation — reconstructed spell premium vs `OptionBurn.premium0`"
  , ""
  , "**Units: ETH wei on `premium0`.** No price conversion appears anywhere in the"
  , "gate path (token1's 6 decimals truncate small premia, and a conversion factor"
  , "is exactly the noise a 1% target cannot absorb)."
  , ""
  , "## Lineage"
  , ""
  , "| what | value |"
  , "|---|---|"
  ] ++
  [ "| " <> k <> " | `" <> v <> "` |" | (k, v) <- rrLineage rep ] ++
  [ "| ground-truth unit | `" <> tshow (rrUnit rep) <> "` |"
  , "| converting expression | `" <> groundTruthExpr (rrUnit rep) <> "` |"
  , "| gate tolerance (`gateTolerance`) | `" <> T.pack (show gateTolerance) <> "` |"
  , ""
  , "## Strata"
  , ""
  , "Reported SEPARATELY and never pooled. `_getAvailablePremium` (PanopticPool"
  , "L588-599) caps SETTLED long premium at what the pool can pay while the"
  , "accumulator reports ACCRUED premium, so a downward long-stratum wedge is"
  , "expected. The verdict is scored on the short stratum; the long stratum is"
  , "reported in full and neither hidden nor allowed to fail a gate the shorts pass."
  , ""
  , "| stratum | n | median | p25 | p75 | p90 | max | recon>truth | recon<truth | zero-truth excluded |"
  , "|---|---|---|---|---|---|---|---|---|---|"
  , distRow "short" (rrShort rep)
  , distRow "long"  (rrLong rep)
  , distRow "all (diagnostic only)" (rrAll rep)
  , ""
  , "## Per-spell"
  , ""
  , "| tokenId | isLong | legs | legs (truth) | recon wei | truth wei | rel error | signed error wei | flags |"
  , "|---|---|---|---|---|---|---|---|---|"
  ] ++
  [ spellRow r | r <- sortOn srTokenId (rrSpells rep) ] ++
  [ ""
  , "## Leg-count mismatches"
  , ""
  ] ++ mismatchSection ++
  [ ""
  , "## Verdict"
  , ""
  , "median_rel_error: " <> fmtD (edMedian (rrAll rep))
  , ""
  , "- `MEDIAN_REL_ERROR_SHORT`: " <> fmtD (edMedian (rrShort rep))
  , "- `MEDIAN_REL_ERROR_LONG`: " <> fmtD (edMedian (rrLong rep))
  , "- `GATE_TOLERANCE`: " <> T.pack (show gateTolerance)
  , "- `LEGCOUNT_MISMATCHES`: " <> tshow (length (rrMismatches rep))
  , ""
  , "**GATE: " <> (if rrPassed rep then "PASS" else "FAIL") <> "**"
  ]
  where
    mismatchSection
      | null (rrMismatches rep) =
          [ "None — every spell's reconstruction covered exactly the legs the scalar"
          , "ground truth sums over." ]
      | otherwise =
          [ "| tokenId | legs reconstructed | legs in the ground truth | mint block | burn block |"
          , "|---|---|---|---|---|"
          ] ++
          [ "| `" <> srTokenId r <> "` | " <> tshow (srLegCount r) <> " | "
              <> tshow (srLegCountTruth r) <> " | " <> tshow (srMintBlock r)
              <> " | " <> tshow (srBurnBlock r) <> " |"
          | r <- rrMismatches rep ]

    distRow lbl d = T.intercalate " | "
      [ "| " <> lbl, tshow (edN d), fmtD (edMedian d), fmtD (edP25 d), fmtD (edP75 d)
      , fmtD (edP90 d), fmtD (edMax d), tshow (edPosCount d), tshow (edNegCount d)
      , tshow (edZeroTruth d) <> " |" ]

    spellRow r = T.intercalate " | "
      [ "| `" <> srTokenId r <> "`"
      , if srIsLong r then "long" else "short"
      , tshow (srLegCount r)
      , tshow (srLegCountTruth r)
      , tshow (srReconWei r)
      , tshow (srTruthWei r)
      , maybe "n/a (zero truth)" fmtD (srRelError r)
      , tshow (srSignedErrorWei r)
      , (if null (srFlags r) then "—" else T.pack (intercalate "," (map show (srFlags r)))) <> " |"
      ]

-- ---------------------------------------------------------------------------
-- Small numeric helpers
-- ---------------------------------------------------------------------------

-- | Median of a list of doubles (NaN on empty — an honest \"no data\", not 0).
medianD :: [Double] -> Double
medianD [] = 0 / 0
medianD xs
  | odd n     = s !! (n `div` 2)
  | otherwise = (s !! (n `div` 2 - 1) + s !! (n `div` 2)) / 2
  where s = sort xs
        n = length xs

-- | Nearest-rank quantile (NaN on empty).
quantileD :: Double -> [Double] -> Double
quantileD _ [] = 0 / 0
quantileD q xs = sort xs !! idx
  where
    n   = length xs
    idx = min (n - 1) (max 0 (ceiling (q * fromIntegral n) - 1 :: Int))

fmtD :: Double -> Text
fmtD x
  | isNaN x = "n/a"
  | otherwise = T.pack (printf "%.6g" x)

tshow :: Show a => a -> Text
tshow = T.pack . show

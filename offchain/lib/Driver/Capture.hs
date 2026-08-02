{-# LANGUAGE OverloadedStrings #-}

-- |
-- The DRIV-01 run record: what the driver did, step by step, with enough provenance that an
-- offline check can assert it and enough tolerance that a run which DIED halfway still leaves
-- something readable behind.
--
-- == WHY EVERY PER-STEP FIELD THAT NEEDS A RECEIPT IS 'Maybe', AND WHY 'dr_complete' EXISTS
--
-- 22-CONTEXT's G2 is the reason the driver aborts on the first bad step rather than completing and
-- reporting: once a bad timestamp lands, the oracle's window math is silently wrong for every
-- subsequent step, so a complete-and-report-all run would produce evidence that LOOKS fine and is
-- not. Aborting is only useful if the partial run survives, and a @fail@ inside 'Network.Web3.Provider.Web3'
-- surfaces as an UNCAUGHT 'IOException' mid-fold, after earlier transactions have already mined.
-- So the writer must be reachable from an exception handler, and the type must be able to describe
-- three steps where five were configured.
--
-- 'dr_complete' is the flag that keeps that tolerance from becoming a hole. Without it a reader has
-- to COUNT to tell a truncated run from a short one, and an offline check would happily treat three
-- good steps as evidence for a five-step requirement. With it, a check can refuse a partial run
-- outright. 'dr_configured_size' records what was ASKED for, so the two disagree visibly.
--
-- == THE 2^53 RULE, INHERITED FROM 22-04
--
-- Every field that can exceed 2^53 is emitted as a DECIMAL STRING, never as a JSON number: @jq@'s
-- numbers are doubles, and a rounded 256-bit word still looks like a word. That covers
-- @volatilityCumulative@, @tickCumulative@ and @sigma@. Ticks, timestamps, fees and counts are
-- small by construction and stay numbers so the acceptance @jq@ expressions can do arithmetic on
-- them.
--
-- == PROVENANCE
--
-- @generatedFrom@ is written UNCONDITIONALLY. Phase 21's F4 measured that a freshness check
-- asserting @chainId@ and a @CREATE@ address cannot see a MODULE change, because a @CREATE@ address
-- is bytecode-independent and was identical across three from-scratch deploys. @generatedFrom@ (the
-- imported source-of-truth ref) can see it. @blockNumber@ is deliberately absent: 21-02 measured
-- three from-scratch deploys landing at heights 9, 11 and 10, so asserting it would redden the
-- suite after any redeploy.
--
-- == EXTENSION
--
-- Plan 22-06 adds an @orders@ object to this same record. Adding a top-level 'Maybe' field and one
-- line in 'ToJSON' is the whole change; nothing below is positional.
module Driver.Capture
  ( -- * The run record
    DriverRun (..)
  , DriverRig (..)
  , DriverSeed (..)
  , StepRecord (..)
  , E3Record (..)
  , E5Record (..)
  , LegacyWritePrice (..)
    -- * Path resolution and writing
  , capture_env_var
  , capture_path
  , write_capture
  , step_record
  ) where

import Data.Aeson (ToJSON (..), Value, encodeFile, object, (.=))
import Data.Maybe (fromMaybe)
import Data.Word (Word32)
import System.Environment (lookupEnv)

-- ---------------------------------------------------------------------------------------------
-- Types
-- ---------------------------------------------------------------------------------------------

-- | One driver run.
data DriverRun = DriverRun
  { dr_generated_at       :: String
  , dr_chain_id           :: Integer
  , dr_generated_from     :: String
    -- | 'False' unless the fold returned normally. An offline check may refuse to treat a run with
    -- 'False' here as evidence for anything.
  , dr_complete           :: Bool
    -- | How many steps were ASKED for. Compared against @length dr_steps@, this is what turns a
    -- truncated run into a visible fact rather than an arithmetic exercise.
  , dr_configured_size    :: Int
  , dr_rig                :: DriverRig
  , dr_seed               :: DriverSeed
  , dr_steps              :: [StepRecord]
    -- | 'Nothing' when the legacy @write_price@ flow did not run (i.e. the run died before it).
  , dr_legacy_write_price :: Maybe LegacyWritePrice
  }
  deriving (Eq, Show)

-- | The rig the run was taken against. Every value comes from @rig-manifest.json@; nothing here is
-- a literal.
data DriverRig = DriverRig
  { drg_pool_manager      :: String
  , drg_dynamic_fee_hook  :: String
  , drg_price_setter_hook :: String
  , drg_swap_router       :: String
  , drg_vol_order_manager :: String
  , drg_pool_id           :: String
  , drg_tick_spacing      :: Integer
  , drg_deployer          :: String
  , drg_sender            :: String
  }
  deriving (Eq, Show)

-- | The three numbers a replay needs.
--
-- 'ds_t0' is 'Maybe' because it is the first step's own submitted timestamp: a run that died before
-- any step mined has no origin to record, and inventing one would make a partial artifact lie.
data DriverSeed = DriverSeed
  { ds_rng    :: Word32
  , ds_t0     :: Maybe Integer
  , ds_stride :: Integer
  }
  deriving (Eq, Show)

-- | One step. @sr_k@, @sr_tick@ and @sr_expected_ts@ are known BEFORE the send; everything below
-- them exists only after one.
data StepRecord = StepRecord
  { sr_k           :: Int
  , sr_tick        :: Integer
  , sr_expected_ts :: Integer
  , sr_tx_hash     :: Maybe String
  , sr_status      :: Maybe Integer
  , sr_e3_count    :: Maybe Int
  , sr_e5_count    :: Maybe Int
  , sr_e3          :: Maybe E3Record
  , sr_e5          :: Maybe E5Record
  }
  deriving (Eq, Show)

-- | @TimepointWritten@ — the ground truth of what the hook recorded.
data E3Record = E3Record
  { e3r_timestamp :: Integer
  , e3r_tick      :: Integer
  , e3r_vol_cum   :: Integer
  , e3r_avg_tick  :: Integer
  , e3r_tick_cum  :: Integer
  }
  deriving (Eq, Show)

-- | @FeeApplied@ — emitted on EVERY swap, including one the write guard ate. That asymmetry is what
-- makes @count(E5) - count(E3)@ a direct on-chain count of lost timepoints.
data E5Record = E5Record
  { e5r_sigma :: Integer
  , e5r_fee   :: Integer
  }
  deriving (Eq, Show)

-- | The legacy @PriceSetterHook@ write, recorded so the roadmap's SC-1 clause — the existing flow is
-- ADDED BESIDE the new driver, never replaced — is asserted by the artifact rather than by prose.
-- Its @poolManager@ is the OTHER manager, which is exactly why this flow could never have satisfied
-- DRIV-01 on its own.
data LegacyWritePrice = LegacyWritePrice
  { lwp_tick         :: Integer
  , lwp_pool_manager :: String
  , lwp_slot         :: String
  , lwp_value        :: String
  }
  deriving (Eq, Show)

-- ---------------------------------------------------------------------------------------------
-- Construction
-- ---------------------------------------------------------------------------------------------

-- | Build a step record from the index, the submitted tick and the submitted timestamp plus the
-- receipt-derived parts. Kept here so a caller cannot get @k@ and @expected_ts@ out of step with
-- each other by assembling the record by hand in two places.
step_record
  :: Int -> Integer -> Integer
  -> Maybe String -> Maybe Integer -> Maybe Int -> Maybe Int
  -> Maybe E3Record -> Maybe E5Record
  -> StepRecord
step_record k tick expected_ts tx_hash status e3c e5c e3 e5 =
  StepRecord
    { sr_k           = k
    , sr_tick        = tick
    , sr_expected_ts = expected_ts
    , sr_tx_hash     = tx_hash
    , sr_status      = status
    , sr_e3_count    = e3c
    , sr_e5_count    = e5c
    , sr_e3          = e3
    , sr_e5          = e5
    }

-- ---------------------------------------------------------------------------------------------
-- Path resolution and writing
-- ---------------------------------------------------------------------------------------------

-- | The override that lets a falsification be aimed somewhere other than the committed evidence.
--
-- 22-03 measured @RIG_MANIFEST@ being silently ignored by the test suite, and 22-04 measured the
-- cheat-swap proof path being a hardcoded constant — the same defect on a second surface, twice
-- defeating the falsification aimed through it. Naming the variable once, here, is what keeps the
-- writer and the checks from drifting apart the way those two did.
capture_env_var :: String
capture_env_var = "DRIVER_CAPTURE"

-- | @DRIVER_CAPTURE@, defaulting to the committed artifact.
capture_path :: IO FilePath
capture_path = fromMaybe default_capture_path <$> lookupEnv capture_env_var

default_capture_path :: FilePath
default_capture_path = "offchain/rig/driver-run-capture.json"

-- | Write the run. Total: a 'DriverRun' with no steps and no legacy write is still valid JSON that
-- decodes, which is the entire value of the flush-on-failure policy.
write_capture :: FilePath -> DriverRun -> IO ()
write_capture path = encodeFile path

-- ---------------------------------------------------------------------------------------------
-- Serialisation
-- ---------------------------------------------------------------------------------------------

instance ToJSON DriverRun where
  toJSON r =
    object
      [ "generatedAt"         .= dr_generated_at r
      , "chainId"             .= dr_chain_id r
      , "generatedFrom"       .= dr_generated_from r
      , "dr_complete"         .= dr_complete r
      , "configuredSize"      .= dr_configured_size r
      , "_provenance"         .= provenance_note
      , "rig"                 .= dr_rig r
      , "seed"                .= dr_seed r
      , "steps"               .= dr_steps r
      , "legacy_write_price"  .= dr_legacy_write_price r
      ]

instance ToJSON DriverRig where
  toJSON g =
    object
      [ "poolManager"     .= drg_pool_manager g
      , "dynamicFeeHook"  .= drg_dynamic_fee_hook g
      , "priceSetterHook" .= drg_price_setter_hook g
      , "swapRouter"      .= drg_swap_router g
      , "volOrderManager" .= drg_vol_order_manager g
      , "poolId"          .= drg_pool_id g
      , "tickSpacing"     .= drg_tick_spacing g
      , "deployer"        .= drg_deployer g
      , "sender"          .= drg_sender g
      ]

instance ToJSON DriverSeed where
  toJSON s =
    object
      [ "rng"    .= ds_rng s
      , "t0"     .= ds_t0 s
      , "stride" .= ds_stride s
      ]

instance ToJSON StepRecord where
  toJSON s =
    object
      [ "k"           .= sr_k s
      , "tick"        .= sr_tick s
      , "expected_ts" .= sr_expected_ts s
      , "txHash"      .= sr_tx_hash s
      , "status"      .= sr_status s
      , "e3_count"    .= sr_e3_count s
      , "e5_count"    .= sr_e5_count s
      , "e3"          .= sr_e3 s
      , "e5"          .= sr_e5 s
      ]

instance ToJSON E3Record where
  toJSON e =
    object
      [ "timestamp"            .= e3r_timestamp e
      , "tick"                 .= e3r_tick e
      , "volatilityCumulative" .= decimal (e3r_vol_cum e)
      , "averageTick"          .= e3r_avg_tick e
      , "tickCumulative"       .= decimal (e3r_tick_cum e)
      ]

instance ToJSON E5Record where
  toJSON e =
    object
      [ "sigma" .= decimal (e5r_sigma e)
      , "fee"   .= e5r_fee e
      ]

instance ToJSON LegacyWritePrice where
  toJSON w =
    object
      [ "tick"        .= lwp_tick w
      , "poolManager" .= lwp_pool_manager w
      , "slot"        .= lwp_slot w
      , "value"       .= lwp_value w
      ]

-- | A value that can exceed 2^53, as a decimal string.
decimal :: Integer -> Value
decimal = toJSON . show

provenance_note :: String
provenance_note =
  "Every value below was produced by offchain/app/Main.hs against the live rig stood up by"
    ++ " offchain/rig/deploy-rig.sh. Nothing here was transcribed. `steps` records one cheat ->"
    ++ " clock -> swap step each: `tick` and `expected_ts` are what the driver SUBMITTED and `e3`"
    ++ " is what DynamicFeeHook actually recorded, so the two are comparable by value."
    ++ " dr_complete is false when the run aborted mid-fold and the artifact was flushed from the"
    ++ " exception path -- a partial run is evidence of a failure, never of a requirement."
    ++ " Absolute timestamps do NOT replay across rigs (t0 = chain head + stride, and anvil's"
    ++ " --timestamp fixes the origin, not the rate); the seed replays the TICK path and the"
    ++ " schedule replays in shape, t_k - t0 = k*stride. blockNumber is deliberately absent:"
    ++ " three from-scratch deploys were measured at heights 9, 11 and 10."

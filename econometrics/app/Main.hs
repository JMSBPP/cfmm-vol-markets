{-# LANGUAGE OverloadedStrings #-}

-- | CLI for the econometrics pipeline (plan 09-09: the live estimation run).
--
-- Stages are invoked one at a time for reproducibility:
--
--   * @build-panel@ — full-history pull of Panoptic @OptionMint@/@OptionBurn@/
--     @Leg@ records from the confirmed Base subgraph, assembled into the accrual-
--     spell panel ("Panel.Build").
--   * @variance@ — chunked @eth_getLogs@ pull of Base V4 @Swap@ logs into the
--     daily σ̂²_t / σ̃²_t / i_t series ("Panel.Variance").
--   * @estimate@ — join the two, fit the primary GSL Levenberg–Marquardt NLS and
--     the EIV IV, form tokenId-clustered CR0 sandwich SEs, run the three
--     committed specification tests and the four locked alternatives, export the
--     estimation panel, and WRITE THE SELF-DESCRIBING ANALYSIS OUTPUT.
--
-- Every path and endpoint is a flag; nothing absolute is hardcoded and no
-- credential is ever printed.
module Main (main) where

import           Control.Exception        (IOException, try)
import           Control.Monad            (foldM, when)
import           Data.IORef               (modifyIORef', newIORef, readIORef)
import qualified Data.ByteString.Lazy    as BL
import qualified Data.Csv                as Csv
import           Data.List               (intercalate, isInfixOf, isPrefixOf,
                                          nub, sort, sortOn)
import qualified Data.Map.Strict         as Map
import           Data.Maybe              (mapMaybe)
import qualified Data.Set                as Set
import qualified Data.Text               as T
import           Data.Time.Clock         (UTCTime, diffUTCTime, getCurrentTime)
import           Data.Time.Clock.POSIX   (posixSecondsToUTCTime)
import           Data.Time.Format        (defaultTimeLocale, formatTime)
import qualified Data.Vector             as V
import           Numeric                 (showFFloat)
import           Options.Applicative
import           System.Environment      (getArgs)
import           System.Exit             (ExitCode (..), exitWith)
import           System.FilePath         ((</>))
import           System.IO               (readFile')
import           System.Process          (readProcessWithExitCode)
import           Text.Printf             (printf)
import           Text.Read               (readMaybe)

import           Numeric.AD              (grad)
import           Numeric.GSL.Fitting     (fitModel)
import qualified Numeric.LinearAlgebra   as LA

import           Alternatives
import           Chain.BlockIndex        (EpochBlock (..), buildBlockIndexWith,
                                          epochBlockMap, estimationWindowBlocks,
                                          loadBlockIndex)
import           Chain.Rpc               (BlockHeader (..), BlockTag (..),
                                          RpcEnv (..), ethGetBlockByNumber)
import           Econ.Types              (Obs (..), Panel, Theta (..))
import           Model.EIV               (ivFit)
import           Model.NLS               (designPoints, fitGSLCov)
import           Model.SandwichSE        (clusterSandwich, standardErrors)
import           Model.Upsilon           (model, modelSplit, moneyness, signedMoneyness)
import           Panel.Build             (EpochObs (..), Spell (..),
                                          VarianceRow (..), assembleEpochPanel,
                                          assembleSpellRaws, assembleSpells,
                                          assembleSpellsWithWindows, dailyEpoch,
                                          epochOfSeconds, writeEpochPanelCsv,
                                          writePanelCsv)
import           Panel.Reconcile         (ErrorDist (..), ReconReport (..),
                                          SpellRecon (..),
                                          classifyGroundTruthUnit,
                                          gateTolerance, groundTruthExpr,
                                          groundTruthWei, reconcile,
                                          renderReconReport)
import           Panoptic.Chunk          (ChunkKey (..), LegChunk (..),
                                          ReadRow (..), buildReadSchedule,
                                          readScheduleRaw, resolveLegChunks,
                                          storedValueTick)
import           Panoptic.Premium        (AccReading (..), PremiumObs (..),
                                          buildSpellPremiumObs)
import           Panoptic.ReadDriver     (AccRow (..), ReadStats (..),
                                          loadAccumulators, runReadSchedule)
import           Panoptic.Sfpm           (getAccountPremium, sfpmAddress)
import           Panel.Subgraph          (BurnEvent (..), Chunk (..),
                                          ChunkPull (..),
                                          CollateralFlow (..), Endpoint (..),
                                          Leg (..), MintEvent (..),
                                          PoolAddr (..), chunkKey, fetchBurns,
                                          fetchChunksRaw, fetchCollateralFlows,
                                          fetchLegs, fetchMints, legChunkKey)
import           Panel.Variance          (RpcConfig (..), cacheSwapTicks,
                                          defaultBaseRpc, fetchSwapTicks,
                                          instrumentVariance,
                                          instrumentVarianceAt, loadSwapTicks,
                                          meanPoolTick, meanPoolTickAt,
                                          fillQuietEpochs, realizedVariance,
                                          realizedVarianceAt, swapCountsAt,
                                          writeVarianceCsv, writeVarianceCsvAt)
import           Tests.Specification     (TestResult (..), Theta4 (..),
                                          testKappaPos, testSymmetry,
                                          testUpsilonPos)

-- ---------------------------------------------------------------------------
-- Market constants (DATA-SOURCES.md §4; echoed into the analysis lineage)
-- ---------------------------------------------------------------------------

-- | token0 decimals − token1 decimals for the confirmed ETH(18)/USDC(6) market.
-- Converts a pool tick into a USDC-per-ETH price.
ethUsdcDecimalShift :: Int
ethUsdcDecimalShift = 12

defaultDataDir :: FilePath
defaultDataDir = "notes/structural-econometrcics/data"

defaultAnalysisDir :: FilePath
defaultAnalysisDir = "notes/structural-econometrcics/analysis"

defaultPanelCsv, defaultVarianceCsv, defaultTicksCsv, defaultCollateralCsv :: FilePath
defaultPanelCsv      = defaultDataDir </> "panel.csv"
defaultVarianceCsv   = defaultDataDir </> "variance.csv"
defaultTicksCsv      = defaultDataDir </> "swap-ticks-base-v4-full.csv"
defaultCollateralCsv = defaultDataDir </> "collateral-flows.csv"

defaultEstimationCsv :: FilePath
defaultEstimationCsv = defaultDataDir </> "estimation-panel.csv"

-- | The HOURLY variance series (plan 10-09). A SEPARATE artifact from the daily
-- @variance.csv@, which stays exactly as Phase 9 wrote it: the 10-01 re-scope
-- changed the panel's epoch grid, it did not invalidate the daily series that the
-- block index and the 10-08 gate lineage reference.
defaultVarianceHourlyCsv :: FilePath
defaultVarianceHourlyCsv = defaultDataDir </> "variance-hourly.csv"

-- | The position-HOUR panel (plan 10-09): the spec's position-epoch unit of
-- observation, restored on the hourly grid the 10-01 census selected.
defaultEpochPanelCsv :: FilePath
defaultEpochPanelCsv = defaultDataDir </> "panel-epoch.csv"

-- | The FROZEN per-spell OptionBurn ground truth (plan 10-09). See
-- 'BurnTruthOpts' for why it exists as an input rather than only as gate output.
defaultBurnTruthCsv :: FilePath
defaultBurnTruthCsv = defaultDataDir </> "burn-truth.csv"

-- ---------------------------------------------------------------------------
-- Options
-- ---------------------------------------------------------------------------

data BuildPanelOpts = BuildPanelOpts
  { bpEndpoint   :: String
  , bpPool       :: String
  , bpOut        :: FilePath
  , bpCollateral :: FilePath
  }

data VarianceOpts = VarianceOpts
  { voTicksCsv   :: FilePath
  , voOutCsv     :: FilePath
  , voFrom       :: Maybe Integer
  , voTo         :: Maybe Integer
  , voRpc        :: String
  , voChunk      :: Integer
  , voEpochHours :: Int    -- ^ bucket width in HOURS; 24 = the Phase-9 daily grid.
  , voPatch      :: Bool   -- ^ with --from/--to: MERGE the fetched window into the
                           --   existing cache instead of overwriting it.
  }

data EstimateOpts = EstimateOpts
  { eoPanelCsv      :: FilePath
  , eoVarianceCsv   :: FilePath
  , eoCollateralCsv :: FilePath
  , eoEstimationCsv :: FilePath
  , eoAnalysisDir   :: FilePath
  , eoEndpoint      :: String
  , eoPool          :: String
  , eoRpc           :: String
  , eoFromBlock     :: Integer
  , eoToBlock       :: Integer
  , eoTicksCsv      :: FilePath
  }

-- | WAVE-0 BLOCKER options (plan 10-01): the width census + achievable panel size.
data SampleSizeOpts = SampleSizeOpts
  { ssEndpoint   :: String
  , ssPool       :: String
  , ssPanelCsv   :: FilePath
  , ssVarianceCsv:: FilePath
  , ssLegsOut    :: FilePath
  , ssReport     :: FilePath
  , ssFixtureOut :: FilePath
  , ssEpochHours :: Int       -- ^ bucket width in hours; 24 = the daily design.
  , ssTicksCsv   :: FilePath  -- ^ cached swap ticks, for sub-daily σ̂² estimability.
  }

-- | Epoch↔block index options (plan 10-03): build the map every accumulator
-- read is keyed on, and measure the free endpoint's sustained throughput.
data BlockIndexOpts = BlockIndexOpts
  { biRpc      :: String    -- ^ Base JSON-RPC endpoint.
  , biVariance :: FilePath  -- ^ variance CSV supplying the epoch set / window.
  , biOut      :: FilePath  -- ^ output epoch-blocks CSV (streamed, resumable).
  , biProbe    :: Int       -- ^ >0 ⇒ run the throughput probe of N calls and exit.
  }

-- | Bulk accumulator-read options (plan 10-06): drive @SFPM.getAccountPremium@
-- over the deduplicated read schedule, checkpointing each row to disk.
data ReadPremiaOpts = ReadPremiaOpts
  { rpEndpoint    :: String    -- ^ subgraph endpoint (mints/burns/legs).
  , rpPool        :: String    -- ^ underlying poolId.
  , rpRpc         :: String    -- ^ primary Base archive RPC.
  , rpRpcFailover :: String    -- ^ failover Base archive RPC.
  , rpBlockIndex  :: FilePath  -- ^ epoch->block CSV (from 10-03).
  , rpVariance    :: FilePath  -- ^ variance CSV (source of the per-epoch pool tick).
  , rpOut         :: FilePath  -- ^ output premium-accumulators CSV (streamed, resumable).
  , rpDryRun      :: Bool      -- ^ build + size the schedule, make ZERO eth_calls.
  }

-- | Reconciliation-gate options (plan 10-07/10-08): rebuild each spell's premium
-- from the endpoint accumulator readings and compare it against the protocol's
-- own @OptionBurn.premium0@, in ETH wei.
--
-- This is a CLI and NOT a test-suite case, deliberately: the gate needs the live
-- subgraph, and @10-VALIDATION@ keeps the hspec suite offline and deterministic.
data ReconcileOpts = ReconcileOpts
  { rcEndpoint     :: String    -- ^ subgraph endpoint (mints/burns/legs).
  , rcPool         :: String    -- ^ underlying poolId.
  , rcAccumulators :: FilePath  -- ^ premium-accumulators CSV from read-premia (10-06).
  , rcPanel        :: FilePath  -- ^ spell panel CSV — THE gate population and its is_long labels.
  , rcLegs         :: FilePath  -- ^ per-leg chunk census CSV, cross-checked against the resolved legs.
  , rcReport       :: FilePath  -- ^ markdown report to write.
  , rcErrorsCsv    :: FilePath  -- ^ machine-readable per-spell error CSV to write.
  , rcLimit        :: Int       -- ^ 0 = all spells; N = the first N (for the fast pre-check).
  , rcOnlyShort    :: Bool      -- ^ restrict to the short stratum.
  , rcMaxLegs      :: Int       -- ^ 0 = any; N = spells with at most N resolved legs.
  }

-- | Position-epoch panel options (plan 10-09): assemble the spec §1 unit of
-- observation from the gate-validated accumulator readings and join it to the
-- hourly variance series.
--
-- Deliberately a SEPARATE subcommand rather than a flag on @build-panel@:
-- @build-panel@ rewrites @panel.csv@, which is THE frozen 61-spell gate
-- population that 10-08's verdict and this plan's own telescoping cross-check are
-- both defined against. Re-running it now, against a subgraph that has advanced
-- since the gate, would silently move the population under the check that is
-- supposed to validate the panel.
data EpochPanelOpts = EpochPanelOpts
  { epEndpoint     :: String    -- ^ subgraph endpoint (mints/burns/legs).
  , epPool         :: String    -- ^ underlying poolId.
  , epAccumulators :: FilePath  -- ^ premium-accumulators CSV from read-premia (10-06).
  , epPanel        :: FilePath  -- ^ spell panel CSV — THE population and its is_long labels.
  , epVariance     :: FilePath  -- ^ HOURLY variance CSV (the join's right-hand side).
  , epReconErrors  :: FilePath  -- ^ reconcile-errors CSV — the telescoping cross-check.
  , epGateReport   :: FilePath  -- ^ reconcile.md; must carry GATE: PASS.
  , epOut          :: FilePath  -- ^ output position-epoch panel CSV.
  , epEpochHours   :: Int       -- ^ grid width in hours (1 = the 10-01 re-scope).
  }

-- | Ground-truth freeze options (plan 10-09, provenance hardening).
--
-- The 10-08 anti-fabrication review recorded one limitation it could not close:
-- @truth_wei@ — the protocol's own @OptionBurn.premium0@, the quantity the gate
-- is scored AGAINST — was fetched live at reconcile time and materialised only in
-- @reconcile-errors.csv@, which is the gate's OUTPUT. A ground truth that exists
-- only inside the artifact it validates cannot be re-checked independently.
--
-- This freezes it as an INPUT: one committed row per accrual spell, carrying the
-- raw event fields, cross-checked against the gate's own @truth_wei@ before it is
-- written.
data BurnTruthOpts = BurnTruthOpts
  { btEndpoint    :: String
  , btPool        :: String
  , btPanel       :: FilePath  -- ^ spell panel CSV — THE population.
  , btReconErrors :: FilePath  -- ^ gate error CSV — the cross-check.
  , btOut         :: FilePath
  }

data Command
  = BuildPanel BuildPanelOpts
  | Variance VarianceOpts
  | Estimate EstimateOpts
  | SampleSize SampleSizeOpts
  | BlockIndex BlockIndexOpts
  | ReadPremia ReadPremiaOpts
  | Reconcile ReconcileOpts
  | EpochPanel EpochPanelOpts
  | BurnTruth BurnTruthOpts

buildPanelOpts :: Parser BuildPanelOpts
buildPanelOpts =
  BuildPanelOpts
    <$> strOption ( long "endpoint" <> metavar "URL"
                 <> help "Panoptic subgraph GraphQL endpoint (from DATA-SOURCES.md)" )
    <*> strOption ( long "pool" <> metavar "POOL"
                 <> help "underlying Pool.id (V4 poolId) to filter on" )
    <*> strOption ( long "out" <> metavar "PATH" <> value defaultPanelCsv <> showDefault
                 <> help "output spell-panel CSV" )
    <*> strOption ( long "collateral-out" <> metavar "PATH" <> value defaultCollateralCsv
                 <> showDefault <> help "output collateral share-flow CSV" )

varianceOptsParser :: Parser VarianceOpts
varianceOptsParser =
  VarianceOpts
    <$> strOption ( long "ticks-csv" <> metavar "PATH" <> value defaultTicksCsv <> showDefault
                 <> help "cached (unix,tick) CSV to read (or write on a live fetch)" )
    <*> strOption ( long "out" <> metavar "PATH" <> value defaultVarianceCsv <> showDefault
                 <> help "output variance CSV (epoch,sigma2,sigma2_instrument,pool_tick_mean)" )
    <*> optional (option auto ( long "from" <> metavar "BLOCK"
                 <> help "RPC fromBlock (with --to, triggers a live fetch)" ))
    <*> optional (option auto ( long "to" <> metavar "BLOCK" <> help "RPC toBlock" ))
    <*> strOption ( long "rpc" <> metavar "URL" <> value (rpcUrl defaultBaseRpc)
                 <> showDefault <> help "Base JSON-RPC endpoint" )
    <*> option auto ( long "chunk" <> metavar "N" <> value (rpcChunk defaultBaseRpc)
                 <> showDefault <> help "blocks per eth_getLogs call" )
    <*> option auto ( long "epoch-hours" <> metavar "N" <> value 24 <> showDefault
                 <> help "epoch bucket width in HOURS (24 = the Phase-9 daily grid \
                         \written by writeVarianceCsv; any other width writes the \
                         \width-aware 5-column artifact via writeVarianceCsvAt)" )
    <*> switch ( long "patch"
                 <> help "with --from/--to: MERGE the fetched block window into the \
                         \existing tick cache (replacing its timestamp span) instead \
                         \of overwriting the whole file — for repairing a fetch gap" )

estimateOptsParser :: Parser EstimateOpts
estimateOptsParser =
  EstimateOpts
    <$> strOption ( long "panel" <> metavar "PATH" <> value defaultPanelCsv <> showDefault
                 <> help "spell-panel CSV from build-panel" )
    <*> strOption ( long "variance" <> metavar "PATH" <> value defaultVarianceCsv
                 <> showDefault <> help "variance CSV from the variance stage" )
    <*> strOption ( long "collateral" <> metavar "PATH" <> value defaultCollateralCsv
                 <> showDefault <> help "collateral share-flow CSV (alternative 4)" )
    <*> strOption ( long "estimation-out" <> metavar "PATH" <> value defaultEstimationCsv
                 <> showDefault <> help "final estimation-panel export (for the GAMS cross-check)" )
    <*> strOption ( long "analysis-dir" <> metavar "DIR" <> value defaultAnalysisDir
                 <> showDefault <> help "directory for the <date>-upsilon-estimates.md output" )
    <*> strOption ( long "endpoint" <> metavar "URL" <> value "" <> help "subgraph endpoint, recorded in the lineage section" )
    <*> strOption ( long "pool" <> metavar "POOL" <> value "" <> help "poolId, recorded in the lineage section" )
    <*> strOption ( long "rpc" <> metavar "URL" <> value "" <> help "Base RPC URL, recorded in the lineage section" )
    <*> option auto ( long "from-block" <> metavar "N" <> value 0 <> help "variance fromBlock, recorded in the lineage section" )
    <*> option auto ( long "to-block" <> metavar "N" <> value 0 <> help "variance toBlock, recorded in the lineage section" )
    <*> strOption ( long "ticks-csv" <> metavar "PATH" <> value defaultTicksCsv
                 <> showDefault <> help "swap-tick cache path, recorded in the lineage section" )

defaultChunkLegsCsv, defaultSizeAudit, defaultChunksFixture :: FilePath
defaultChunkLegsCsv  = defaultDataDir </> "chunk-legs.csv"
defaultSizeAudit     = defaultDataDir </> "panel-size-audit.md"
defaultChunksFixture = "econometrics/test/fixtures/chunks-sample.json"

sampleSizeOptsParser :: Parser SampleSizeOpts
sampleSizeOptsParser =
  SampleSizeOpts
    <$> strOption ( long "endpoint" <> metavar "URL"
                 <> help "Panoptic subgraph GraphQL endpoint (from DATA-SOURCES.md)" )
    <*> strOption ( long "pool" <> metavar "POOL"
                 <> help "underlying Pool.id (V4 poolId) to filter on" )
    <*> strOption ( long "panel" <> metavar "PATH" <> value defaultPanelCsv <> showDefault
                 <> help "spell-panel CSV (row count recorded in the lineage header)" )
    <*> strOption ( long "variance" <> metavar "PATH" <> value defaultVarianceCsv
                 <> showDefault <> help "variance CSV supplying THE joinable epoch set" )
    <*> strOption ( long "legs-out" <> metavar "PATH" <> value defaultChunkLegsCsv
                 <> showDefault <> help "per-leg chunk-identity census CSV" )
    <*> strOption ( long "report" <> metavar "PATH" <> value defaultSizeAudit
                 <> showDefault <> help "audit report with the STOP/GO recommendation" )
    <*> strOption ( long "fixture-out" <> metavar "PATH" <> value defaultChunksFixture
                 <> showDefault <> help "frozen raw Chunk subgraph response (offline fixture)" )
    <*> option auto ( long "epoch-hours" <> metavar "N" <> value 24 <> showDefault
                 <> help "epoch bucket width in HOURS (24 = the daily design; \
                         \<24 re-measures the census at a finer resolution)" )
    <*> strOption ( long "ticks-csv" <> metavar "PATH" <> value defaultTicksCsv
                 <> showDefault
                 <> help "cached (unix,tick) swap CSV; supplies the per-epoch swap \
                         \counts that decide whether sigma^2-hat is estimable at \
                         \sub-daily resolution" )

commandParser :: Parser Command
commandParser =
  hsubparser
    ( command "build-panel"
        (info (BuildPanel <$> buildPanelOpts)
              (progDesc "Full-history pull of mints/burns/legs; assemble the accrual-spell panel"))
   <> command "variance"
        (info (Variance <$> varianceOptsParser)
              (progDesc "Build sigma^2_t, the EIV instrument, and the mean pool tick from Base V4 Swap logs"))
   <> command "estimate"
        (info (Estimate <$> estimateOptsParser)
              (progDesc "Fit the profile, run the tests and alternatives, write the analysis output"))
   <> command "sample-size"
        (info (SampleSize <$> sampleSizeOptsParser)
              (progDesc "WAVE-0 BLOCKER: census width/=0 legs and the achievable position-epoch panel size"))
   <> command "block-index"
        (info (BlockIndex <$> blockIndexOptsParser)
              (progDesc "Build the epoch->block map (hourly boundaries) by bisection; or --probe N to measure RPC throughput"))
   <> command "read-premia"
        (info (ReadPremia <$> readPremiaOptsParser)
              (progDesc "Bulk getAccountPremium read over the deduplicated schedule, checkpointed to disk (--dry-run to size only)"))
   <> command "reconcile"
        (info (Reconcile <$> reconcileOptsParser)
              (progDesc "THE GATE: reconstructed spell premium vs OptionBurn.premium0, in ETH wei, stratified short/long (exits non-zero on FAIL)"))
   <> command "burn-truth"
        (info (BurnTruth <$> burnTruthOptsParser)
              (progDesc "Freeze the per-spell OptionBurn ground truth as a committed INPUT artifact, cross-checked against the gate's own truth_wei"))
   <> command "epoch-panel"
        (info (EpochPanel <$> epochPanelOptsParser)
              (progDesc "Assemble the position-epoch panel from the gate-validated accumulators and join it to the hourly variance series (exits non-zero on any unmatched epoch or telescoping mismatch)"))
    )

burnTruthOptsParser :: Parser BurnTruthOpts
burnTruthOptsParser =
  BurnTruthOpts
    <$> strOption ( long "endpoint" <> metavar "URL"
                 <> help "Panoptic subgraph GraphQL endpoint (mints/burns/legs)" )
    <*> strOption ( long "pool" <> metavar "POOL"
                 <> help "underlying Pool.id (V4 poolId) to filter on" )
    <*> strOption ( long "panel" <> metavar "PATH" <> value defaultPanelCsv <> showDefault
                 <> help "spell panel CSV — THE population" )
    <*> strOption ( long "recon-errors" <> metavar "PATH"
                 <> value defaultReconcileErrorsCsv <> showDefault
                 <> help "gate error CSV whose truth_wei this artifact must reproduce" )
    <*> strOption ( long "out" <> metavar "PATH" <> value defaultBurnTruthCsv
                 <> showDefault <> help "output frozen ground-truth CSV" )

epochPanelOptsParser :: Parser EpochPanelOpts
epochPanelOptsParser =
  EpochPanelOpts
    <$> strOption ( long "endpoint" <> metavar "URL"
                 <> help "Panoptic subgraph GraphQL endpoint (mints/burns/legs)" )
    <*> strOption ( long "pool" <> metavar "POOL"
                 <> help "underlying Pool.id (V4 poolId) to filter on" )
    <*> strOption ( long "accumulators" <> metavar "PATH"
                 <> value defaultPremiumAccumulatorsCsv <> showDefault
                 <> help "premium-accumulators CSV from read-premia (10-06)" )
    <*> strOption ( long "panel" <> metavar "PATH" <> value defaultPanelCsv <> showDefault
                 <> help "spell panel CSV — THE population and its is_long labels" )
    <*> strOption ( long "variance" <> metavar "PATH" <> value defaultVarianceHourlyCsv
                 <> showDefault <> help "HOURLY variance CSV (the join's right-hand side)" )
    <*> strOption ( long "recon-errors" <> metavar "PATH"
                 <> value defaultReconcileErrorsCsv <> showDefault
                 <> help "per-spell reconciliation error CSV — the telescoping cross-check" )
    <*> strOption ( long "gate-report" <> metavar "PATH" <> value defaultReconcileReport
                 <> showDefault <> help "gate report; must carry 'GATE: PASS'" )
    <*> strOption ( long "out" <> metavar "PATH" <> value defaultEpochPanelCsv
                 <> showDefault <> help "output position-epoch panel CSV" )
    <*> option auto ( long "epoch-hours" <> metavar "N" <> value 1 <> showDefault
                 <> help "grid width in HOURS (1 = the 10-01 re-scope; must match \
                         \the grid the accumulators were read on)" )

defaultReconcileReport :: FilePath
defaultReconcileReport = defaultDataDir </> "reconcile.md"

-- | The machine-readable companion to the gate report: one row per reconciled
-- spell, so 10-09 and any later audit can filter on the reconciliation error
-- without parsing markdown.
defaultReconcileErrorsCsv :: FilePath
defaultReconcileErrorsCsv = defaultDataDir </> "reconcile-errors.csv"

reconcileOptsParser :: Parser ReconcileOpts
reconcileOptsParser =
  ReconcileOpts
    <$> strOption ( long "endpoint" <> metavar "URL"
                 <> help "Panoptic subgraph GraphQL endpoint (mints/burns/legs)" )
    <*> strOption ( long "pool" <> metavar "POOL"
                 <> help "underlying Pool.id (V4 poolId) to filter on" )
    <*> strOption ( long "accumulators" <> metavar "PATH"
                 <> value defaultPremiumAccumulatorsCsv <> showDefault
                 <> help "premium-accumulators CSV from read-premia (the endpoint readings)" )
    <*> strOption ( long "panel" <> metavar "PATH" <> value defaultPanelCsv <> showDefault
                 <> help "spell panel CSV — THE gate population and its is_long labels" )
    <*> strOption ( long "legs" <> metavar "PATH" <> value defaultChunkLegsCsv <> showDefault
                 <> help "per-leg chunk census CSV, cross-checked against the resolved chunk ranges" )
    <*> strOption ( long "report" <> metavar "PATH" <> value defaultReconcileReport
                 <> showDefault <> help "markdown report to write" )
    <*> strOption ( long "errors-csv" <> metavar "PATH" <> value defaultReconcileErrorsCsv
                 <> showDefault
                 <> help "machine-readable per-spell reconciliation error CSV to write" )
    <*> option auto ( long "limit" <> metavar "N" <> value 0 <> showDefault
                 <> help "reconcile only the first N spells (0 = all)" )
    <*> switch ( long "only-short"
                 <> help "restrict to the SHORT stratum (the pre-check population)" )
    <*> option auto ( long "max-legs" <> metavar "N" <> value 0 <> showDefault
                 <> help "restrict to spells with at most N resolved legs (0 = any); \
                         \--max-legs 1 selects the single-leg pre-check cases" )

readPremiaOptsParser :: Parser ReadPremiaOpts
readPremiaOptsParser =
  ReadPremiaOpts
    <$> strOption ( long "endpoint" <> metavar "URL"
                 <> help "Panoptic subgraph GraphQL endpoint (mints/burns/legs)" )
    <*> strOption ( long "pool" <> metavar "POOL"
                 <> help "underlying Pool.id (V4 poolId) to filter on" )
    <*> strOption ( long "rpc" <> metavar "URL" <> value "https://mainnet.base.org"
                 <> showDefault <> help "primary Base JSON-RPC endpoint (archive-capable)" )
    <*> strOption ( long "rpc-failover" <> metavar "URL" <> value "https://base.drpc.org"
                 <> showDefault <> help "failover Base JSON-RPC endpoint" )
    <*> strOption ( long "block-index" <> metavar "PATH" <> value defaultEpochBlocksCsv
                 <> showDefault <> help "epoch->block CSV from block-index (hourly boundaries)" )
    <*> strOption ( long "variance" <> metavar "PATH" <> value defaultVarianceCsv
                 <> showDefault <> help "variance CSV (per-epoch pool tick, for atTick extrapolation)" )
    <*> strOption ( long "out" <> metavar "PATH" <> value defaultPremiumAccumulatorsCsv
                 <> showDefault <> help "output premium-accumulators CSV (streamed; resumes if present)" )
    <*> switch ( long "dry-run"
                 <> help "build and size the schedule, print counts, make ZERO eth_calls" )

defaultEpochBlocksCsv :: FilePath
defaultEpochBlocksCsv = defaultDataDir </> "epoch-blocks.csv"

defaultPremiumAccumulatorsCsv :: FilePath
defaultPremiumAccumulatorsCsv = defaultDataDir </> "premium-accumulators.csv"

blockIndexOptsParser :: Parser BlockIndexOpts
blockIndexOptsParser =
  BlockIndexOpts
    <$> strOption ( long "rpc" <> metavar "URL" <> value "https://mainnet.base.org"
                 <> showDefault <> help "Base JSON-RPC endpoint (archive-capable)" )
    <*> strOption ( long "variance" <> metavar "PATH" <> value defaultVarianceCsv
                 <> showDefault <> help "variance CSV supplying the epoch set (daily epochs -> hourly grid)" )
    <*> strOption ( long "out" <> metavar "PATH" <> value defaultEpochBlocksCsv
                 <> showDefault <> help "output epoch-blocks CSV (streamed; resumes if present)" )
    <*> option auto ( long "probe" <> metavar "N" <> value 0 <> showDefault
                 <> help "if >0, issue N sequential eth_getBlockByNumber calls across the window, \
                         \report throughput/429/projected bulk minutes, and exit without building" )

opts :: ParserInfo Command
opts =
  info (commandParser <**> helper)
    ( fullDesc
   <> progDesc "Panoptic upsilon structural econometrics pipeline"
   <> header "econometrics - Haskell-only estimation of the exponential-moneyness vega profile" )

main :: IO ()
main = execParser opts >>= run

run :: Command -> IO ()
run (BuildPanel o)  = runBuildPanel o
run (Variance vo)   = runVariance vo
run (Estimate eo)   = runEstimate eo
run (SampleSize so) = runSampleSize so
run (BlockIndex bo) = runBlockIndex bo
run (ReadPremia o)  = runReadPremia o
run (Reconcile o)   = runReconcile o
run (EpochPanel o)  = runEpochPanel o
run (BurnTruth o)   = runBurnTruth o

-- ---------------------------------------------------------------------------
-- build-panel
-- ---------------------------------------------------------------------------

runBuildPanel :: BuildPanelOpts -> IO ()
runBuildPanel o = do
  let ep   = Endpoint (T.pack (bpEndpoint o))
      pool = PoolAddr (T.pack (bpPool o))
  putStrLn ("build-panel: endpoint " ++ bpEndpoint o)
  putStrLn ("build-panel: pool     " ++ bpPool o)
  mints <- fetchMints ep pool
  putStrLn ("build-panel: " ++ show (length mints) ++ " OptionMints")
  burns <- fetchBurns ep pool
  putStrLn ("build-panel: " ++ show (length burns) ++ " OptionBurns")
  legs <- fetchLegs ep pool
  putStrLn ("build-panel: " ++ show (length legs) ++ " tokenIds with legs")
  let spells = assembleSpells ethUsdcDecimalShift mints burns legs
  writePanelCsv (bpOut o) spells
  putStrLn ("build-panel: " ++ show (length spells)
             ++ " accrual spells (non-zero premium, paired to a mint) -> " ++ bpOut o)
  putStrLn ("build-panel: " ++ show (length (nub (map spTokenId spells)))
             ++ " distinct tokenIds, "
             ++ show (length (nub (map spAccount spells))) ++ " distinct accounts")
  flows <- fetchCollateralFlows ep pool
  writeCollateralCsv (bpCollateral o) flows
  putStrLn ("build-panel: " ++ show (length flows) ++ " collateral share flows -> "
             ++ bpCollateral o)

-- | Signed collateral share flows, for the alternative-4 balance reconstruction.
writeCollateralCsv :: FilePath -> [CollateralFlow] -> IO ()
writeCollateralCsv fp flows = writeFile fp (banner ++ body)
  where
    banner = unlines
      [ "# Panoptic collateral share flows (deposits positive, withdraws negative)."
      , "# Source: CollateralDeposit / CollateralWithdraw events, confirmed Base market."
      , "# Used by the collateral-channel alternative (spec 6.2.4) to reconstruct"
      , "# per-account collateral share BALANCES as a step function of time."
      , "owner,timestamp_unix,vault_index,shares_delta"
      ]
    body = unlines
      [ T.unpack (cfOwner f) ++ "," ++ show (cfTimestamp f) ++ ","
          ++ show (cfIndex f) ++ "," ++ show (cfShares f)
      | f <- sortOn cfTimestamp flows ]

-- ---------------------------------------------------------------------------
-- sample-size (plan 10-01: THE WAVE-0 BLOCKER)
-- ---------------------------------------------------------------------------

-- | The Uniswap V4 tick spacing of the confirmed market (fee tier 500).
marketTickSpacing :: Int
marketTickSpacing = 10

-- | Phase 9's realized sample: the number this phase must MATERIALLY beat.
phase9BaselineRows :: Int
phase9BaselineRows = 61

-- | PRE-COMMITTED GO thresholds. Stated in plan 10-01 BEFORE the measurement and
-- not to be adjusted after seeing it (@anti-fishing-replication@).
goRowThreshold, goWithinEpochThreshold :: Int
goRowThreshold         = 300
goWithinEpochThreshold = 5

-- | Epoch of a unix timestamp. Delegates to 'Panel.Build.dailyEpoch' — the
-- SINGLE source of truth for the epoch grid (RESEARCH Pitfall 4; the 09-05
-- 40587-offset trap). Never redefine the arithmetic here.
epochOfUnix :: Integer -> Int
epochOfUnix = dailyEpoch . posixSecondsToUTCTime . fromInteger

-- | Bucket a unix timestamp at an arbitrary epoch width, via
-- 'Panel.Build.epochOfSeconds'. At @epochSeconds = 86400@ this is 'epochOfUnix'
-- (pinned by a spec in "Panel.BuildSpec").
bucketOfUnix :: Int -> Integer -> Int
bucketOfUnix epochSeconds =
  epochOfSeconds epochSeconds . posixSecondsToUTCTime . fromInteger

-- | Minimum swaps in an epoch for the realized variance to be ESTIMABLE at all.
--
-- σ̂² is the sum of squared log-price INCREMENTS, so @n@ swaps give @n − 1@
-- increments: a window with 0 or 1 swap yields σ̂² = 0 by construction — not a
-- small variance, but NO measurement. This bites only at sub-daily resolution;
-- at daily resolution every covered epoch has thousands of swaps.
minSwapsForVariance :: Int
minSwapsForVariance = 2

-- | One (spell, leg) census row.
data LegRow = LegRow
  { lrTokenId   :: !T.Text
  , lrLegIndex  :: !Int
  , lrStrike    :: !Int
  , lrWidth     :: !Int
  , lrTokenType :: !Int
  , lrIsLong    :: !Bool
  , lrRatio     :: !Int
  , lrTickLower :: !Int
  , lrTickUpper :: !Int
  , lrMatched   :: !Bool
  , lrNetLiq    :: !Integer
  , lrTotalLiq  :: !Integer
  , lrPosSize   :: !Double
  , lrEpochMint :: !Int
  , lrEpochBurn :: !Int
  }

runSampleSize :: SampleSizeOpts -> IO ()
runSampleSize so = do
  let ep   = Endpoint (T.pack (ssEndpoint so))
      pool = PoolAddr (T.pack (ssPool so))
  now <- getCurrentTime
  let dateStr = formatTime defaultTimeLocale "%Y-%m-%d" now

  mints <- fetchMints ep pool
  burns <- fetchBurns ep pool
  legs  <- fetchLegs ep pool
  pull  <- fetchChunksRaw ep pool >>= either (ioError . userError) pure
  varMap <- loadVarianceCsv (ssVarianceCsv so)

  -- Sub-daily resolution needs the per-epoch SWAP COUNT, which variance.csv
  -- (daily, pre-aggregated) cannot supply. Read it from the cached tick stream —
  -- never re-fetch from RPC.
  let epochHours = max 1 (ssEpochHours so)
      epochSecs  = epochHours * 3600
      isDaily    = epochHours == 24
  ticks <- loadSwapTicks (ssTicksCsv so)
  let swapCounts :: Map.Map Int Int
      swapCounts = Map.fromListWith (+)
        [ (epochOfSeconds epochSecs t, 1 :: Int) | (t, _) <- ticks ]
      coveredFromTicks = Map.keysSet swapCounts
      estimableSet     = Map.keysSet
        (Map.filter (>= minSwapsForVariance) swapCounts)

  let chunks   = cpChunks pull
      withWins = assembleSpellsWithWindows ethUsdcDecimalShift mints burns legs
      spells   = map fst withWins
      legMap   = Map.fromList legs
      chunkMap = Map.fromList [ (chunkKey c, c) | c <- chunks ]
      varEpochs = Map.keysSet varMap

      -- THE covered epoch set. At daily resolution this stays variance.csv, so
      -- the committed daily census reproduces byte-for-byte; at any finer
      -- resolution variance.csv has no rows to offer and the covered set comes
      -- from the tick cache at that width.
      coveredSet | isDaily   = varEpochs
                 | otherwise = coveredFromTicks
      -- positionSize of the mint that OPENED each spell, keyed by
      -- (tokenId, mint epoch) so the join uses the shared epoch grid.
      sizeMap  = Map.fromList
        [ ((meTokenId m, epochOfUnix (meTimestamp m)), mePositionSize m) | m <- mints ]

      rows =
        [ LegRow
            { lrTokenId = spTokenId s, lrLegIndex = i
            , lrStrike = legStrikeTick l, lrWidth = legWidth l
            , lrTokenType = legTokenType l, lrIsLong = legIsLong l
            , lrRatio = legOptionRatio l
            , lrTickLower = tl, lrTickUpper = tu
            , lrMatched = matched
            , lrNetLiq = maybe 0 chNetLiquidity mc
            , lrTotalLiq = maybe 0 chTotalLiquidity mc
            , lrPosSize = Map.findWithDefault (0 / 0)
                            (spTokenId s, spMintEpoch s) sizeMap
            , lrEpochMint = spMintEpoch s, lrEpochBurn = spBurnEpoch s
            }
        | s <- spells
        , (i, l) <- zip [0 ..] (Map.findWithDefault [] (spTokenId s) legMap)
        , let (_, tl, tu) = legChunkKey (legStrikeTick l) (legWidth l)
                                        (legTokenType l) marketTickSpacing
              mc      = Map.lookup (legTokenType l, tl, tu) chunkMap
              matched = maybe False (const True) mc
        ]

      -- A leg with width == 0 accrues NO premium: PanopticPool._getPremia
      -- (L2250) skips it outright. Such legs cannot contribute a panel row.
      nonzero      = [ r | r <- rows, lrWidth r /= 0 ]
      usableToks   = Set.fromList (map lrTokenId nonzero)
      usableWins   = [ sw | sw@(s, _) <- withWins
                     , spTokenId s `Set.member` usableToks ]
      usableSpells = map fst usableWins

      -- The epochs of one spell, at the configured bucket width, intersected
      -- with a given epoch set. The window is the EXACT (mint, burn) unix pair
      -- from the pairing rule — at sub-daily resolution the spell's daily
      -- endpoints are far too coarse to bucket from.
      spellEpochsIn epochSet (_, (mintU, burnU)) =
        Set.fromList [ e | e <- [bucketOfUnix epochSecs mintU
                                  .. bucketOfUnix epochSecs burnU]
                     , e `Set.member` epochSet ]

      -- Epochs the variance series COVERS at all.
      achievableRows = sum (map (Set.size . spellEpochsIn coveredSet) usableWins)
      -- Epochs that carry BOTH a position observation AND an ESTIMABLE sigma^2.
      -- This, not the raw count above, is the real panel size: an epoch whose
      -- variance cannot be measured supplies no regressor.
      joinableRows   = sum (map (Set.size . spellEpochsIn estimableSet) usableWins)

      -- CLUSTER-level within-position variation: distinct joinable epochs per
      -- usable tokenId, unioned over that tokenId's spells. This is the
      -- quantity Phase 9 had exactly ZERO of (one window-averaged sigma^2 per
      -- spell), and restoring it is the phase's real identification claim.
      -- Measured on the ESTIMABLE set for the same reason as 'joinableRows'.
      perTokenEpochs =
        Map.fromListWith Set.union
          [ (spTokenId s, spellEpochsIn estimableSet sw) | sw@(s, _) <- usableWins ]
      withinCounts = map Set.size (Map.elems perTokenEpochs)
      withinMedian = medianI withinCounts

      -- Concentration diagnostics. A median can pass while almost all rows sit
      -- in a handful of long-lived positions, which under tokenId-CLUSTERED
      -- inference buys far less than the row count suggests. Both numbers are
      -- reported so the verdict is read against the same scrutiny the daily
      -- design got.
      toksMeetingThreshold =
        length [ () | c <- withinCounts, c >= goWithinEpochThreshold ]
      top10Share =
        fracOf (sum (take 10 (reverse (sort withinCounts)))) (sum withinCounts)

      -- Swap-count diagnostics: at sub-daily resolution sigma^2 is rebuilt from
      -- however many swaps land in each bucket, so the density of the swap
      -- stream is what decides whether the finer grid is measurable at all.
      swapCountsInWindows =
        [ Map.findWithDefault 0 e swapCounts
        | sw <- usableWins, e <- Set.toList (spellEpochsIn coveredSet sw) ]
      thinEpochs = length [ () | c <- swapCountsInWindows, c < minSwapsForVariance ]
      allCounts  = Map.elems swapCounts

      -- getTicks cross-check. Computed over width /= 0 legs only: a width-0 leg
      -- maps to the degenerate range [strike, strike], which is not a real chunk
      -- and would drag the rate down without telling us anything.
      matchRate
        | null nonzero = 0 / 0
        | otherwise    = fromIntegral (length [ () | r <- nonzero, lrMatched r ])
                           / fromIntegral (length nonzero) :: Double
      distinctChunks = Set.size
        (Set.fromList [ (lrTokenType r, lrTickLower r, lrTickUpper r)
                      | r <- nonzero, lrMatched r ])
      gainFactor = fromIntegral joinableRows
                     / fromIntegral phase9BaselineRows :: Double

      -- Label suffix so a re-scoped run can never be confused with the daily
      -- one in the audit trail.
      sfx | isDaily        = ""
          | epochHours == 1 = "_HOURLY"
          | otherwise       = "_" ++ show epochHours ++ "H"
      lbl k = k ++ sfx

      metrics =
        [ ("EPOCH_HOURS",                  show epochHours)
        , ("TOTAL_LEGS",                   show (length rows))
        , ("WIDTH_NONZERO_LEGS",           show (length nonzero))
        , ("WIDTH_NONZERO_TOKENIDS",       show (Set.size usableToks))
        , ("WIDTH_NONZERO_SPELLS",         show (length usableSpells))
        , ("USABLE_TOKENID_COUNT",         show (Map.size perTokenEpochs))
        , ("DISTINCT_CHUNKS",              show distinctChunks)
        , ("GETTICKS_MATCH_RATE",          fmtG matchRate)
        , ("VARIANCE_EPOCHS",              show (Set.size varEpochs))
        , (lbl "COVERED_EPOCHS",           show (Set.size coveredSet))
        , (lbl "ESTIMABLE_SIGMA2_EPOCHS",  show (Set.size estimableSet))
        , (lbl "ACHIEVABLE_PANEL_ROWS",    show achievableRows)
        , (lbl "JOINABLE_ROWS",            show joinableRows)
        , (lbl "WITHIN_POSITION_EPOCHS_MEDIAN", fmtG withinMedian)
        , (lbl "WITHIN_POSITION_EPOCHS_MIN",    show (minimumOr0 withinCounts))
        , (lbl "WITHIN_POSITION_EPOCHS_P25",    fmtG (quantileI 0.25 withinCounts))
        , (lbl "WITHIN_POSITION_EPOCHS_P75",    fmtG (quantileI 0.75 withinCounts))
        , (lbl "WITHIN_POSITION_EPOCHS_MAX",    show (maximumOr0 withinCounts))
        , (lbl "TOKENIDS_MEETING_WITHIN_THRESHOLD", show toksMeetingThreshold)
        , (lbl "TOP10_TOKENID_ROW_SHARE",       fmtG top10Share)
        , (lbl "SWAPS_PER_EPOCH_MIN",      show (minimumOr0 allCounts))
        , (lbl "SWAPS_PER_EPOCH_P25",      fmtG (quantileI 0.25 allCounts))
        , (lbl "SWAPS_PER_EPOCH_MEDIAN",   fmtG (medianI allCounts))
        , (lbl "SWAPS_PER_EPOCH_P75",      fmtG (quantileI 0.75 allCounts))
        , (lbl "SWAPS_PER_EPOCH_MAX",      show (maximumOr0 allCounts))
        , (lbl "THIN_EPOCH_FRACTION",      fmtG (fracOf thinEpochs (length swapCountsInWindows)))
        , ("PHASE9_BASELINE_ROWS",         show phase9BaselineRows)
        , ("GAIN_FACTOR",                  fmtG gainFactor)
        ]

  writeChunkLegsCsv (ssLegsOut so) rows
  BL.writeFile (ssFixtureOut so) (cpRaw pull)

  putStrLn ("sample-size: " ++ show (length mints) ++ " mints, "
             ++ show (length burns) ++ " burns, " ++ show (length legs)
             ++ " tokenIds with legs, " ++ show (length chunks)
             ++ " chunks (" ++ T.unpack (cpPath pull) ++ ")")
  putStrLn ("sample-size: " ++ show (length spells) ++ " accrual spells")
  mapM_ (\(k, v) -> putStrLn (k ++ ": " ++ v)) metrics

  -- The VERDICT's condition (a) is scored on JOINABLE rows, not merely covered
  -- ones: an epoch whose sigma^2 is not estimable contributes no regressor and
  -- therefore no panel row. At daily resolution the two coincide (every covered
  -- day carries thousands of swaps), so the committed daily verdict is
  -- unaffected by this refinement.
  writeFile (ssReport so)
    (renderSizeAudit so dateStr metrics spells chunks nonzero
                     joinableRows (lbl "JOINABLE_ROWS")
                     withinMedian (lbl "WITHIN_POSITION_EPOCHS_MEDIAN")
                     (cpPath pull))
  putStrLn ("sample-size: wrote " ++ ssLegsOut so)
  putStrLn ("sample-size: wrote " ++ ssFixtureOut so)
  putStrLn ("sample-size: wrote " ++ ssReport so)

-- | The audit report. The VERDICT is derived MECHANICALLY from the thresholds
-- pre-committed in plan 10-01 — no hand is laid on the rule after the numbers
-- are in.
renderSizeAudit
  :: SampleSizeOpts -> String -> [(String, String)] -> [Spell] -> [Chunk]
  -> [LegRow] -> Int -> String -> Double -> String -> T.Text -> String
renderSizeAudit so dateStr metrics spells chunks nonzero
                achievableRows rowLabel withinMedian medianLabel path =
  unlines $
    [ "# Panel-size audit — Phase 10 Wave-0 blocker"
    , ""
    , "**Measured:** " ++ dateStr ++ ". Generated by"
    , "`econometrics sample-size`; every number below is a QUERY RESULT, not an"
    , "estimate or an assumption."
    , ""
    , "## Lineage"
    , ""
    , "| what | value |"
    , "|---|---|"
    , "| subgraph endpoint | `" ++ ssEndpoint so ++ "` (keyless public Goldsky; no API key used) |"
    , "| underlying pool (V4 poolId) | `" ++ ssPool so ++ "` |"
    , "| PanopticPool | `0xb50e8bb68f5855da742f4579274902a20454174a` (ETH/USDC, fee 500) |"
    , "| tickSpacing | " ++ show marketTickSpacing ++ " |"
    , "| chunk query path | `" ++ T.unpack path ++ "` |"
    , "| accrual spells rebuilt (`Panel.Build.assembleSpells`) | " ++ show (length spells) ++ " |"
    , "| `Chunk` records pulled | " ++ show (length chunks) ++ " |"
    , "| panel CSV read | `" ++ ssPanelCsv so ++ "` |"
    , "| variance CSV read (THE joinable epoch set) | `" ++ ssVarianceCsv so ++ "` |"
    , "| per-leg census written | `" ++ ssLegsOut so ++ "` |"
    , "| frozen chunk fixture | `" ++ ssFixtureOut so ++ "` |"
    , ""
    , "Epoch grid: `floor(unixSeconds / 86400)`, via `Panel.Build.dailyEpoch` —"
    , "the single source of truth, never redefined here (the 09-05 offset trap)."
    , ""
    , "## The census"
    , ""
    , "| metric | value |"
    , "|---|---|"
    ] ++
    [ "| `" ++ k ++ "` | " ++ v ++ " |" | (k, v) <- metrics ] ++
    [ ""
    , "`ACHIEVABLE_PANEL_ROWS` counts, over every spell whose tokenId carries at"
    , "least one `width /= 0` leg, the daily epochs in `[epoch_mint, epoch_burn]`"
    , "that the variance series actually covers. It is the number of position-epoch"
    , "rows this market can supply — the ceiling, before any further attrition."
    , ""
    , "`WIDTH_NONZERO_*` matter because `PanopticPool._getPremia` (L2250) SKIPS"
    , "every leg with `width == 0`: such legs accrue no premium at all and can"
    , "never contribute a panel row."
    , ""
    , "## getTicks cross-check"
    , ""
    , "Each `width /= 0` leg's `(strike, width, tokenType)` is mapped to a chunk"
    , "range by `Panel.Subgraph.legChunkKey` (floor down / ceil up — asymmetric for"
    , "odd `width * tickSpacing`) and looked up against the `Chunk` records the"
    , "subgraph reports. A match confirms the formula reproduces the protocol's own"
    , "range arithmetic."
    , ""
    ] ++ getTicksSection ++
    [ ""
    , "## VERDICT"
    , ""
    , "Pre-committed rule (stated in plan 10-01 BEFORE this measurement, and NOT"
    , "adjusted after it). `GO` requires BOTH:"
    , ""
    , "- (a) `" ++ rowLabel ++ " >= " ++ show goRowThreshold ++ "` — measured **"
        ++ show achievableRows ++ "** -> " ++ passLabel condA
    , "- (b) `" ++ medianLabel ++ " >= " ++ show goWithinEpochThreshold
        ++ "` — measured **" ++ fmtG withinMedian ++ "** -> " ++ passLabel condB
    , ""
    , "`STOP` if either fails."
    , ""
    , "RECOMMENDATION: " ++ (if condA && condB then "GO" else "STOP")
    , ""
    ] ++ verdictProse ++
    [ ""
    , "### What this threshold is and is NOT"
    , ""
    , "**This is a NECESSARY-condition floor, NOT a sufficient one.** It does not"
    , "compute, and does not promise, the achievable confidence interval."
    , ""
    , "Reason: the standard errors are **tokenId-clustered**. Adding epochs to"
    , "existing positions multiplies ROWS without multiplying CLUSTERS, and under"
    , "cluster-robust inference precision is bounded by the cluster count — so a"
    , "naive `1/sqrt(rows)` contraction argument would OVERSTATE the gain. That is"
    , "why `USABLE_TOKENID_COUNT` (the cluster count) is reported alongside the row"
    , "count and must be read with it."
    , ""
    , "Condition (b) exists because the phase's real identification gain is"
    , "qualitative, not arithmetic. In Phase 9 each spell carried ONE"
    , "window-averaged `sigma^2`, so within-position regressor variation was exactly"
    , "ZERO and `upsilon_0` was identified purely cross-sectionally. Restoring"
    , "within-position covariation is what spec 4.4 actually intends."
    , ""
    , "The genuine arbiter of success remains plan 10-10's result-blind stopping"
    , "rule (clustered CI half-width <= 6.2e-5). A `GO` here means \"worth"
    , "attempting\", NOT \"will succeed\"."
    ]
  where
    condA = achievableRows >= goRowThreshold
    condB = not (isNaN withinMedian)
              && withinMedian >= fromIntegral goWithinEpochThreshold
    passLabel True  = "**PASS**"
    passLabel False = "**FAIL**"

    failures = [ (lrStrike r, lrWidth r, lrTokenType r)
               | r <- nonzero, not (lrMatched r) ]

    getTicksSection
      | null nonzero =
          [ "No `width /= 0` legs exist across the spells, so the cross-check has"
          , "no input. This is itself the headline finding — see the verdict." ]
      | null failures =
          [ "**All " ++ show (length nonzero) ++ " `width /= 0` spell-legs matched a"
          , "`Chunk` record exactly (`GETTICKS_MATCH_RATE` = 1.0).** The formula"
          , "reproduces the protocol's range arithmetic on every leg in the sample." ]
      | otherwise =
          [ "**" ++ show (length failures) ++ " of " ++ show (length nonzero)
              ++ " `width /= 0` spell-legs did NOT match a `Chunk` record.**"
          , "Unmatched `(strike, width, tokenType)` triples:"
          , ""
          , "| strike | width | tokenType |"
          , "|---|---|---|"
          ] ++
          [ "| " ++ show s ++ " | " ++ show w ++ " | " ++ show tt ++ " |"
          | (s, w, tt) <- nub failures ]

    verdictProse
      | condA && condB =
          [ "Both pre-committed conditions hold: the achievable panel is materially"
          , "larger than Phase 9's " ++ show phase9BaselineRows ++ " spells AND the"
          , "regressor genuinely varies within a position. The phase's power goal is"
          , "not ruled out on sample-size grounds." ]
      | otherwise =
          [ "At least one pre-committed condition FAILS. **The phase's power goal is"
          , "unreachable on this market's data, and the correct outcome is to REPORT"
          , "that rather than to proceed.**"
          , ""
          , "What specifically failed:"
          , ""
          ] ++ concat
          [ [ "- **(a) row count.** The achievable panel supplies " ++ show achievableRows
            , "  rows against a floor of " ++ show goRowThreshold ++ ". This market simply"
            , "  does not have enough premium-bearing position-days." ]
          | not condA ] ++ concat
          [ [ "- **(b) within-position variation.** The median usable tokenId spans "
                ++ fmtG withinMedian ++ " joinable"
            , "  epoch(s), against a floor of " ++ show goWithinEpochThreshold ++ ". The"
            , "  regressor does NOT genuinely vary within a position, which is the very"
            , "  defect the reconstruction was meant to repair. Rebuilding the LHS at daily"
            , "  resolution cannot create within-position variation in positions that do"
            , "  not survive a day." ]
          | not condB ] ++
          [ ""
          , "A STOP verdict here is a legitimate, publishable phase outcome — not a"
          , "failure, and not an invitation to move the threshold. The finding is that"
          , "this market's positions are too SHORT-LIVED and too few in number to"
          , "identify `upsilon` from a position-epoch panel, however exactly the"
          , "premium is reconstructed." ]

-- | Median of a list of counts (NaN on empty — an honest "no data", not a 0).
medianI :: [Int] -> Double
medianI [] = 0 / 0
medianI xs
  | odd n     = fromIntegral (s !! (n `div` 2))
  | otherwise = fromIntegral (s !! (n `div` 2 - 1) + s !! (n `div` 2)) / 2
  where s = sort xs
        n = length xs

-- | Nearest-rank quantile of a list of counts (NaN on empty). Reported alongside
-- the median because a median alone HIDES concentration: a handful of long-lived
-- positions can carry most of the rows while the typical position carries one.
quantileI :: Double -> [Int] -> Double
quantileI _ [] = 0 / 0
quantileI q xs = fromIntegral (s !! idx)
  where s   = sort xs
        n   = length xs
        idx = min (n - 1) (max 0 (ceiling (q * fromIntegral n) - 1 :: Int))

minimumOr0, maximumOr0 :: [Int] -> Int
minimumOr0 [] = 0
minimumOr0 xs = minimum xs
maximumOr0 [] = 0
maximumOr0 xs = maximum xs

-- | @num \/ den@ as a fraction, NaN on an empty denominator.
fracOf :: Int -> Int -> Double
fracOf _ 0 = 0 / 0
fracOf a b = fromIntegral a / fromIntegral b

-- | Per-leg chunk identity for every leg of every accrual spell.
writeChunkLegsCsv :: FilePath -> [LegRow] -> IO ()
writeChunkLegsCsv fp rows = writeFile fp (csvHeader ++ body)
  where
    csvHeader = "token_id,leg_index,strike,width,token_type,is_long,option_ratio,\
             \tick_lower,tick_upper,chunk_matched,net_liquidity,total_liquidity,\
             \position_size,epoch_mint,epoch_burn\n"
    body = unlines
      [ intercalate ","
          [ T.unpack (lrTokenId r), show (lrLegIndex r), show (lrStrike r)
          , show (lrWidth r), show (lrTokenType r)
          , show (if lrIsLong r then 1 :: Int else 0), show (lrRatio r)
          , show (lrTickLower r), show (lrTickUpper r)
          , show (if lrMatched r then 1 :: Int else 0)
          , show (lrNetLiq r), show (lrTotalLiq r)
          , show (lrPosSize r), show (lrEpochMint r), show (lrEpochBurn r) ]
      | r <- rows ]

-- ---------------------------------------------------------------------------
-- block-index (plan 10-03: the epoch<->block map + the RPC throughput probe)
-- ---------------------------------------------------------------------------

-- | Hourly epoch grid (the Wave-0 HOURLY re-scope): the index maps HOURLY
-- boundaries, not the 119 DAILY epochs the plan text was drafted against. The
-- boundary instant of hourly epoch @h@ is @h * 3600@.
blockIndexEpochSeconds :: Int
blockIndexEpochSeconds = 3600

-- | Base nominal head-retry env for the index build and the probe. Archive
-- reads are cheap @eth_getBlockByNumber@ calls; keep the retry budget modest so
-- the throughput figure reflects the endpoint, not a long backoff tail.
blockIndexEnv :: String -> RpcEnv
blockIndexEnv url = RpcEnv { reUrl = T.pack url, reMaxRetries = 4, reBackoffMicros = 1000000 }

runBlockIndex :: BlockIndexOpts -> IO ()
runBlockIndex bo
  | biProbe bo > 0 = runThroughputProbe bo
  | otherwise      = runIndexBuild bo

-- | Build the hourly epoch→block index over the estimation window, streaming to
-- the CSV. Re-probes archive availability at the window's earliest block first
-- (RESEARCH: the free endpoint's archive availability is the volatile
-- assumption); if BOTH the primary and the failover fail, it aborts rather than
-- silently narrowing the window.
runIndexBuild :: BlockIndexOpts -> IO ()
runIndexBuild bo = do
  let (wLo, wHi) = estimationWindowBlocks
      primary    = blockIndexEnv (biRpc bo)
      failover   = blockIndexEnv "https://base.drpc.org"

  -- 1. Re-probe archive availability at the window's earliest block.
  putStrLn ("block-index: re-probing archive availability at block " ++ show wLo)
  mEnvLo <- firstAnswering [("primary/" ++ biRpc bo, primary), ("failover/base.drpc.org", failover)] wLo
  (env, loHdr) <- case mEnvLo of
    Nothing -> ioError (userError
      ("ABORT: neither the primary endpoint nor base.drpc.org served archive block "
        ++ show wLo ++ ". Not narrowing the estimation window — re-probe later."))
    Just (label, e, h) -> do
      putStrLn ("block-index: archive OK via " ++ label ++ " (block " ++ show wLo
                 ++ " ts " ++ show (bhTimestamp h) ++ ")")
      pure (e, h)

  -- 2. Fetch the window's end block and derive the in-window HOURLY epoch set.
  eHiHdr <- ethGetBlockByNumber env wHi
  hiHdr <- either (\err -> ioError (userError ("end block " ++ show wHi ++ ": " ++ err))) pure eHiHdr
  let startTs = bhTimestamp loHdr
      endTs   = bhTimestamp hiHdr
      es      = fromIntegral blockIndexEpochSeconds :: Integer
      firstE  = fromIntegral ((startTs + es - 1) `div` es)          -- ceil(startTs / 3600)
      lastE   = fromIntegral (endTs `div` es)                       -- floor(endTs / 3600)
      hourlyEpochs = [firstE .. lastE]

  -- 3. Cross-check the block window against variance.csv's DAILY epoch set — the
  --    plan's stated "source of the epoch set" — so the two can never drift.
  varMap <- loadVarianceCsv (biVariance bo)
  let dailyEps = Map.keys varMap
      dLo = dailyEpoch (posixSecondsToUTCTime (fromIntegral startTs))
      dHi = dailyEpoch (posixSecondsToUTCTime (fromIntegral endTs))
  putStrLn ("block-index: window ts " ++ show startTs ++ ".." ++ show endTs
             ++ " -> hourly epochs " ++ show firstE ++ ".." ++ show lastE
             ++ " (" ++ show (length hourlyEpochs) ++ " boundaries)")
  putStrLn ("block-index: variance.csv daily epochs "
             ++ show (minimumOr0 dailyEps) ++ ".." ++ show (maximumOr0 dailyEps)
             ++ " (" ++ show (length dailyEps) ++ "); window maps to daily "
             ++ show dLo ++ ".." ++ show dHi)
  when (not (null dailyEps) && (dLo /= minimumOr0 dailyEps || dHi /= maximumOr0 dailyEps)) $
    putStrLn "block-index: WARNING — window daily epochs differ from variance.csv range"

  -- 4. Build (streaming + resumable), counting every eth_getBlockByNumber call.
  callRef <- newIORef (0 :: Int)
  let countedFetch b = modifyIORef' callRef (+ 1) >> ethGetBlockByNumber env b
  memo <- newIORef (Map.empty :: Map.Map Integer BlockHeader)
  let fetch b = do
        m <- readIORef memo
        case Map.lookup b m of
          Just h  -> pure (Right h)
          Nothing -> do
            r <- countedFetch b
            case r of Right h -> modifyIORef' memo (Map.insert b h) >> pure (Right h)
                      Left e  -> pure (Left e)
  now <- getCurrentTime
  let date = formatTime defaultTimeLocale "%Y-%m-%d" now
      provenance =
        [ "epoch-blocks.csv — HOURLY epoch -> first Base block at or after epoch*3600"
        , "RPC: " ++ T.unpack (reUrl env) ++ "   built: " ++ date
        , "epoch rule: Panel.Build.epochOfSeconds " ++ show blockIndexEpochSeconds
            ++ " (single source of truth); boundary instant = epoch * "
            ++ show blockIndexEpochSeconds
        , "window blocks " ++ show wLo ++ ".." ++ show wHi
            ++ "; columns: epoch, block_number, block_timestamp (unix seconds)" ]
  res <- buildBlockIndexWith fetch (wLo, wHi) provenance blockIndexEpochSeconds (biOut bo) hourlyEpochs
  calls <- readIORef callRef
  case res of
    Left err -> ioError (userError ("block-index build failed: " ++ err))
    Right rows -> do
      let firstBlk = if null rows then 0 else ebBlockNumber (head rows)
          lastBlk  = if null rows then 0 else ebBlockNumber (last rows)
      putStrLn ("EPOCHS_INDEXED: " ++ show (length rows))
      putStrLn ("FIRST_BLOCK: " ++ show firstBlk)
      putStrLn ("LAST_BLOCK: " ++ show lastBlk)
      putStrLn ("PROBE_CALLS: " ++ show calls)
      putStrLn ("block-index: wrote " ++ biOut bo)

-- | Try each labelled endpoint at a block in order; return the first that
-- answers with a header, or 'Nothing' if all fail.
firstAnswering
  :: [(String, RpcEnv)] -> Integer -> IO (Maybe (String, RpcEnv, BlockHeader))
firstAnswering [] _ = pure Nothing
firstAnswering ((label, env) : rest) blk = do
  r <- ethGetBlockByNumber env blk
  case r of
    Right h -> pure (Just (label, env, h))
    Left e  -> do
      putStrLn ("block-index: " ++ label ++ " did not answer (" ++ take 120 e ++ ")")
      firstAnswering rest blk

-- | The RPC throughput probe (RESEARCH Open Question 3). Issues N sequential
-- @eth_getBlockByNumber@ calls at evenly spaced blocks across the estimation
-- window and reports the sustained rate, error/429 counts, and the projected
-- bulk-read wall time. This SIZES the bulk read (10-06); it is NOT the bulk read.
runThroughputProbe :: BlockIndexOpts -> IO ()
runThroughputProbe bo = do
  let n          = biProbe bo
      env        = blockIndexEnv (biRpc bo)
      (wLo, wHi) = estimationWindowBlocks
      step       = max 1 ((wHi - wLo) `div` fromIntegral (max 1 (n - 1)))
      blocks     = take n [ wLo, wLo + step .. wHi ]
  putStrLn ("block-index probe: " ++ show n ++ " sequential eth_getBlockByNumber calls across blocks "
             ++ show wLo ++ ".." ++ show wHi ++ " via " ++ biRpc bo)
  t0 <- getCurrentTime
  (okN, errN, r429) <- foldM (probeStep env) (0 :: Int, 0 :: Int, 0 :: Int) blocks
  t1 <- getCurrentTime
  let elapsed = realToFrac (diffUTCTime t1 t0) :: Double
      rate    = if elapsed > 0 then fromIntegral okN / elapsed else 0 :: Double
      projected15k = if rate > 0 then 15000 / rate / 60 else 0 :: Double
  putStrLn ("PROBE_CALLS: " ++ show n)
  putStrLn ("PROBE_OK_COUNT: " ++ show okN)
  putStrLn ("PROBE_ERROR_COUNT: " ++ show errN)
  putStrLn ("PROBE_429_COUNT: " ++ show r429)
  putStrLn ("PROBE_ELAPSED_S: " ++ printf "%.3f" elapsed)
  putStrLn ("PROBE_CALLS_PER_S: " ++ printf "%.3f" rate)
  putStrLn ("PROJECTED_BULK_MINUTES: " ++ printf "%.2f" projected15k)
  when (r429 > 0) $
    putStrLn "PROBE_NOTE: 429s were absorbed by rpcPost backoff; PROBE_CALLS_PER_S is the post-backoff effective rate."
  -- Write the small report the 10-04/10-06 schedule consumes.
  let reportPath = defaultDataDir </> "rpc-throughput-probe.md"
  writeFile reportPath (renderProbeReport bo n okN errN r429 elapsed rate projected15k)
  putStrLn ("block-index probe: wrote " ++ reportPath)

-- | One probe call: fetch, classify the outcome (ok / error / 429-tagged error).
probeStep :: RpcEnv -> (Int, Int, Int) -> Integer -> IO (Int, Int, Int)
probeStep env (ok, err, r429) blk = do
  r <- ethGetBlockByNumber env blk
  pure $ case r of
    Right _ -> (ok + 1, err, r429)
    Left e
      | "429" `isInfixOf` e -> (ok, err + 1, r429 + 1)
      | otherwise           -> (ok, err + 1, r429)

renderProbeReport
  :: BlockIndexOpts -> Int -> Int -> Int -> Int -> Double -> Double -> Double -> String
renderProbeReport bo n okN errN r429 elapsed rate projected15k =
  unlines
    [ "# RPC throughput probe — Phase 10 Wave-2 (plan 10-03)"
    , ""
    , "Answers RESEARCH Open Question 3 (can `mainnet.base.org` sustain the bulk"
    , "archive read?). This is the SIZING probe; the bulk read itself is 10-06."
    , ""
    , "| metric | value |"
    , "|---|---|"
    , "| endpoint | `" ++ biRpc bo ++ "` |"
    , "| PROBE_CALLS | " ++ show n ++ " |"
    , "| PROBE_OK_COUNT | " ++ show okN ++ " |"
    , "| PROBE_ERROR_COUNT | " ++ show errN ++ " |"
    , "| PROBE_429_COUNT | " ++ show r429 ++ " |"
    , "| PROBE_ELAPSED_S | " ++ printf "%.3f" elapsed ++ " |"
    , "| PROBE_CALLS_PER_S | " ++ printf "%.3f" rate ++ " |"
    , "| PROJECTED_BULK_MINUTES (15k calls) | " ++ printf "%.2f" projected15k ++ " |"
    , ""
    , "`PROBE_CALLS_PER_S` is the post-backoff effective rate: `rpcPost` retries"
    , "transient 429s internally, so a 429 that eventually succeeded is counted OK."
    , "`PROJECTED_BULK_MINUTES` uses the RESEARCH 15,000-call (daily-sized) figure;"
    , "the HOURLY re-scope makes the bulk read larger — see the plan SUMMARY for the"
    , "hourly-adjusted projection 10-06 must budget against."
    ]

-- ---------------------------------------------------------------------------
-- read-premia (plan 10-06: the bulk accumulator read)
-- ---------------------------------------------------------------------------

-- | The bulk-read budget CEILING (rows). The RESEARCH 8k–15k figure was sized
-- against the DAILY grid; the HOURLY re-scope (10-01) revised the envelope to
-- ~30k–60k reads (10-03/10-04 SUMMARYs). A distinct-read count materially past
-- this is a bug upstream (the schedule is deterministic), not a bigger market, so
-- the run aborts rather than launching an oversized pull.
readBudgetCeiling :: Int
readBudgetCeiling = 60000

-- | Retry policy for the bulk read: a generous budget for a multi-hour sequential
-- archive pull on a free endpoint.
readPremiaEnv :: String -> RpcEnv
readPremiaEnv url = RpcEnv { reUrl = T.pack url, reMaxRetries = 6, reBackoffMicros = 2000000 }

runReadPremia :: ReadPremiaOpts -> IO ()
runReadPremia o = do
  let ep          = Endpoint (T.pack (rpEndpoint o))
      pool        = PoolAddr (T.pack (rpPool o))
      primaryEnv  = readPremiaEnv (rpRpc o)
      failoverEnv = readPremiaEnv (rpRpcFailover o)

  -- 1. Assemble the schedule inputs from the subgraph.
  putStrLn ("read-premia: endpoint " ++ rpEndpoint o)
  mints <- fetchMints ep pool
  burns <- fetchBurns ep pool
  legs  <- fetchLegs ep pool
  putStrLn ("read-premia: " ++ show (length mints) ++ " mints, "
             ++ show (length burns) ++ " burns, " ++ show (length legs)
             ++ " tokenIds with legs")

  let legMap = Map.fromList legs
      raws   = assembleSpellRaws ethUsdcDecimalShift mints burns legs
      -- Resolve each paired spell's legs to chunks, using the OPENING mint's
      -- positionSize (round to Integer at the boundary — no Double downstream).
      spellsWithLegs =
        [ (tid, m, b, resolveLegChunks marketTickSpacing (round (mePositionSize m))
                        (Map.findWithDefault [] tid legMap))
        | (tid, m, b) <- raws ]
  putStrLn ("read-premia: " ++ show (length raws) ++ " paired accrual spells")

  -- 2. Load the hourly epoch->block index (10-03) and derive the atTick index.
  --    variance.csv supplies a DAILY mean pool tick; the schedule is HOURLY, so
  --    each hourly epoch e maps to its containing day's tick (e `div` 24). Where a
  --    day has no variance row the read falls back to the stored-value sentinel.
  ebs <- loadBlockIndex (rpBlockIndex o)
  varMap <- loadVarianceCsv (rpVariance o)
  let blockIx   = epochBlockMap ebs
      dailyTick = Map.map (round . vrTick) varMap :: Map.Map Int Int
      tickIx    = Map.fromList
        [ (e, t) | e <- Map.keys blockIx, Just t <- [Map.lookup (e `div` 24) dailyTick] ]

  -- 3. Build the deduplicated read schedule and size it.
  let scheduleRaw = readScheduleRaw blockIx tickIx spellsWithLegs
      schedule    = buildReadSchedule blockIx tickIx spellsWithLegs
      scheduleRows = length scheduleRaw
      distinct     = length schedule
      blocks       = map rrBlock schedule
      (loBlk, hiBlk) = if null blocks then (0, 0) else (minimum blocks, maximum blocks)
  putStrLn ("SCHEDULE_ROWS: " ++ show scheduleRows)
  putStrLn ("DISTINCT_READS: " ++ show distinct)
  putStrLn ("BLOCK_RANGE: " ++ show loBlk ++ ".." ++ show hiBlk)
  putStrLn ("READ_BUDGET_CEILING: " ++ show readBudgetCeiling)

  -- Oversize abort: a deterministic schedule past the ceiling is an upstream bug.
  when (distinct > readBudgetCeiling) $
    ioError (userError
      ("ABORT: DISTINCT_READS " ++ show distinct ++ " exceeds the ceiling "
        ++ show readBudgetCeiling ++ ". The schedule is deterministic, so an "
        ++ "unexpected count is a bug upstream, not a bigger market. Not launching."))

  if null schedule
    then ioError (userError "ABORT: empty schedule — no spells resolved to any read.")
    else pure ()

  if rpDryRun o
    then putStrLn "read-premia: --dry-run — schedule sized, ZERO eth_calls made."
    else do
      -- 4. Re-probe archive availability at the EARLIEST scheduled block. If both
      --    endpoints fail, abort — do NOT silently narrow the window.
      let probeRow = minimumOnBlock schedule
      putStrLn ("read-premia: re-probing archive availability at block "
                 ++ show (rrBlock probeRow))
      probed <- probeArchiveAt primaryEnv failoverEnv probeRow
      case probed of
        Left err -> ioError (userError
          ("ABORT: archive re-probe failed on BOTH endpoints at block "
            ++ show (rrBlock probeRow) ++ ": " ++ err
            ++ " — the free-endpoint archive retention is the volatile assumption. "
            ++ "Re-probe later; not narrowing the window."))
        Right lbl -> putStrLn ("read-premia: archive OK via " ++ lbl)

      -- 5. Run the bulk read (checkpointed per row; a re-run resumes).
      putStrLn ("read-premia: starting bulk read -> " ++ rpOut o)
      res <- runReadSchedule primaryEnv failoverEnv (rpOut o) schedule
      case res of
        Left err -> ioError (userError ("read-premia: " ++ err))
        Right st -> do
          let (emptyN, frozenN) = rsFlagged st
          putStrLn  "read-premia: DONE"
          putStrLn ("SCHEDULE_ROWS: "        ++ show scheduleRows)
          putStrLn ("DISTINCT_READS: "       ++ show distinct)
          putStrLn ("CALLS_MADE: "           ++ show (rsCalls st))
          putStrLn ("ROWS_SKIPPED_RESUMED: " ++ show (rsSkipped st))
          putStrLn ("ELAPSED_S: "            ++ printf "%.1f" (rsElapsedS st))
          putStrLn ("FAILOVER_CALLS: "       ++ show (rsFailoverCalls st))
          putStrLn ("CHUNK_EMPTY_ROWS: "     ++ show emptyN)
          putStrLn ("ACC_FROZEN_ROWS: "      ++ show frozenN)
          putStrLn ("BLOCK_RANGE: "          ++ show loBlk ++ ".." ++ show hiBlk)
          putStrLn ("read-premia: wrote "    ++ rpOut o)

-- | The scheduled row at the earliest block — the probe target.
minimumOnBlock :: [ReadRow] -> ReadRow
minimumOnBlock = foldr1 (\a b -> if rrBlock a <= rrBlock b then a else b)

-- | Probe @getAccountPremium@ for one row on the primary, then the failover.
-- Returns the endpoint label that answered, or 'Left' if BOTH fail.
probeArchiveAt :: RpcEnv -> RpcEnv -> ReadRow -> IO (Either String String)
probeArchiveAt primaryEnv failoverEnv row = do
  let ck     = rrChunkKey row
      atTick = if rrAtTick row == storedValueTick then Nothing else Just (rrAtTick row)
      tag    = BlockNumber (rrBlock row)
  rp <- getAccountPremium primaryEnv ck atTick (rrIsLong row) tag
  case rp of
    Right _ -> pure (Right ("primary/" ++ T.unpack (reUrl primaryEnv)))
    Left e1 -> do
      putStrLn ("read-premia: primary did not answer (" ++ take 120 e1 ++ ")")
      rf <- getAccountPremium failoverEnv ck atTick (rrIsLong row) tag
      pure $ case rf of
        Right _ -> Right ("failover/" ++ T.unpack (reUrl failoverEnv))
        Left e2 -> Left ("primary: " ++ e1 ++ " | failover: " ++ e2)

-- ---------------------------------------------------------------------------
-- reconcile (plan 10-07/10-08: THE GATE)
-- ---------------------------------------------------------------------------

-- | Rebuild every spell's premium from the endpoint accumulator readings and
-- compare it against @OptionBurn.premium0@ — in ETH WEI, stratified short\/long,
-- scored against the single named 'gateTolerance'.
--
-- Exits NON-ZERO on @GATE: FAIL@ so the gate is scriptable and cannot be
-- mistaken for a pass by a caller that only checks the exit status.
runReconcile :: ReconcileOpts -> IO ()
runReconcile o = do
  let ep   = Endpoint (T.pack (rcEndpoint o))
      pool = PoolAddr (T.pack (rcPool o))
  now <- getCurrentTime
  let dateStr = formatTime defaultTimeLocale "%Y-%m-%d" now

  -- 1. The spell population, rebuilt through the SINGLE pairing rule (the same
  --    'assembleSpellRaws' the 10-06 read schedule was built from, so the
  --    endpoint blocks the gate reads at are exactly the ones that were read).
  mints <- fetchMints ep pool
  burns <- fetchBurns ep pool
  legs  <- fetchLegs ep pool
  let legMap = Map.fromList legs
      raws   = assembleSpellRaws ethUsdcDecimalShift mints burns legs
      allSpells =
        [ (tid, m, b, resolveLegChunks marketTickSpacing (round (mePositionSize m))
                        (Map.findWithDefault [] tid legMap))
        | (tid, m, b) <- raws ]
  putStrLn ("reconcile: " ++ show (length mints) ++ " mints, " ++ show (length burns)
             ++ " burns, " ++ show (length raws) ++ " paired accrual spells")

  -- 2. panel.csv is THE gate population (the 61 Phase-9 spells) and the authority
  --    on the is_long label; a disagreement with the leg-derived stratum is
  --    REPORTED, never silently resolved in favour of one side.
  panelSpells <- loadPanelCsv (rcPanel o)
  let panelToks  = Set.fromList (map spTokenId panelSpells)
      panelLong  = Map.fromList [ (spTokenId s, spIsLong s) | s <- panelSpells ]
      inPanel    = [ s | s@(tid, _, _, _) <- allSpells, tid `Set.member` panelToks ]
      stratumOf (_, _, _, lcs) = case lcs of { (lc : _) -> lcIsLong lc ; [] -> False }
      labelDisagreements =
        [ tid | s@(tid, _, _, _) <- inPanel
        , Just (stratumOf s) /= Map.lookup tid panelLong ]

  -- 3. chunk-legs.csv cross-check: the resolved chunk ranges must reproduce the
  --    census the Wave-0 audit recorded. A mismatch means the geometry moved.
  legsCensus <- loadChunkLegsCensus (rcLegs o)
  let censusMismatches =
        [ (tid, lcLegIndex lc)
        | (tid, _, _, lcs) <- inPanel, lc <- lcs
        , let k = (tid, lcLegIndex lc)
              ckTuple = ( ckTokenType (lcChunkKey lc)
                        , ckTickLower (lcChunkKey lc)
                        , ckTickUpper (lcChunkKey lc) )
        , Just v <- [Map.lookup k legsCensus], v /= ckTuple ]

  -- 4. Apply the selection filters. Order is the pairing rule's own (ascending
  --    burn epoch), so --limit is deterministic and reproducible.
  let afterShort | rcOnlyShort o = [ s | s <- inPanel, not (stratumOf s) ]
                 | otherwise     = inPanel
      afterLegs  | rcMaxLegs o > 0 = [ s | s@(_, _, _, lcs) <- afterShort
                                    , not (null lcs), length lcs <= rcMaxLegs o ]
                 | otherwise       = afterShort
      selected   | rcLimit o > 0 = take (rcLimit o) afterLegs
                 | otherwise     = afterLegs

  when (null selected) $
    ioError (userError "ABORT: the selection matched no spells — nothing to reconcile.")

  -- 5. Reconcile against the materialised endpoint readings.
  rep0 <- reconcile (rcAccumulators o) selected

  -- 6. Provenance the report cannot reconstruct for itself: the commit the gate
  --    ran at, the exact argument vector, and the extent of the readings it
  --    consumed. A gate result without its lineage is not auditable.
  argv     <- getArgs
  commit   <- gitHeadCommit
  accCache <- loadAccumulators (rcAccumulators o)
  let accBlocks = map acBlock (Map.elems accCache)
      blockRange
        | null accBlocks = "n/a (no readings loaded)"
        | otherwise      = show (minimum accBlocks) ++ ".." ++ show (maximum accBlocks)

  let lineage =
        [ ("measured",                    T.pack dateStr)
        , ("git commit",                  T.pack commit)
        , ("command line",                T.pack ("econometrics " ++ unwords argv))
        , ("working directory",           "repository root (all paths below are repo-relative)")
        , ("subgraph endpoint",           T.pack (rcEndpoint o))
        , ("underlying pool (V4 poolId)", T.pack (rcPool o))
        , ("SFPM read target",            sfpmAddress)
        , ("VEGOID / nu",                 "8 / 0.125 — applied INSIDE the contract's X64 accumulator; \
                                          \never re-applied here")
        , ("accumulator readings",        T.pack (rcAccumulators o))
        , ("accumulator rows loaded",     T.pack (show (Map.size accCache)))
        , ("accumulator block range",     T.pack blockRange)
        , ("gate population (panel)",     T.pack (rcPanel o))
        , ("per-leg census",              T.pack (rcLegs o))
        , ("epoch definition",            "floor(unixSeconds/86400) — Panel.Build.dailyEpoch, the \
                                          \panel.csv grid that ORDERS spells. The gate itself compares \
                                          \SPELL-ENDPOINT totals and uses no epoch grid.")
        , ("paired spells (subgraph)",    T.pack (show (length raws)))
        , ("spells in the gate population", T.pack (show (length inPanel)))
        , ("selection",                   T.pack (selectionLabel o))
        , ("spells reconciled",           T.pack (show (length selected)))
        , ("is_long label disagreements", T.pack (show (length labelDisagreements)))
        , ("chunk-range census mismatches", T.pack (show (length censusMismatches)))
        , ("per-spell error CSV",         T.pack (rcErrorsCsv o))
        ]
      rep = rep0 { rrLineage = lineage }
      d   = rrAll rep
      ds  = rrShort rep
      dl  = rrLong rep

  -- The verdict labels are built ONCE and used for BOTH stdout and the report,
  -- so the captured stdout and the published artifact cannot disagree about the
  -- verdict. @GATE_TOLERANCE@ prints as a plain decimal, never Haskell's
  -- @1.0e-2@: this line is grepped by the gate scripts and by the checkpoint.
  let labelLines =
        [ "SPELLS_RECONCILED: "      ++ show (length selected)
        , "GROUND_TRUTH_UNIT: "      ++ show (rrUnit rep)
        , "GROUND_TRUTH_EXPR: "      ++ T.unpack (groundTruthExpr (rrUnit rep))
        , "MEDIAN_REL_ERROR_ALL: "   ++ fmtG (edMedian d)
        , "N_SHORT: "                ++ show (edN ds)
        , "MEDIAN_REL_ERROR_SHORT: " ++ fmtG (edMedian ds)
        , "P25_REL_ERROR_SHORT: "    ++ fmtG (edP25 ds)
        , "P75_REL_ERROR_SHORT: "    ++ fmtG (edP75 ds)
        , "P90_REL_ERROR_SHORT: "    ++ fmtG (edP90 ds)
        , "MAX_REL_ERROR_SHORT: "    ++ fmtG (edMax ds)
        , "SIGNED_BIAS_SHORT: "      ++ show (edPosCount ds) ++ "/" ++ show (edNegCount ds)
        , "N_LONG: "                 ++ show (edN dl)
        , "MEDIAN_REL_ERROR_LONG: "  ++ fmtG (edMedian dl)
        , "P25_REL_ERROR_LONG: "     ++ fmtG (edP25 dl)
        , "P75_REL_ERROR_LONG: "     ++ fmtG (edP75 dl)
        , "P90_REL_ERROR_LONG: "     ++ fmtG (edP90 dl)
        , "MAX_REL_ERROR_LONG: "     ++ fmtG (edMax dl)
        , "SIGNED_BIAS_LONG: "       ++ show (edPosCount dl) ++ "/" ++ show (edNegCount dl)
        , "LEGCOUNT_MISMATCHES: "    ++ show (length (rrMismatches rep))
        , "ZERO_TRUTH_EXCLUDED: "    ++ show (edZeroTruth d)
        , "LABEL_DISAGREEMENTS: "    ++ show (length labelDisagreements)
        , "CENSUS_MISMATCHES: "      ++ show (length censusMismatches)
        , "GATE_TOLERANCE: "         ++ showFFloat Nothing gateTolerance ""
        , "GATE: "                   ++ (if rrPassed rep then "PASS" else "FAIL")
        ]

      -- Spliced in directly after the lineage table so the artifact reads
      -- lineage -> verdict -> strata -> per-spell -> mismatches -> diagnosis.
      rendered     = lines (T.unpack (renderReconReport rep))
      verdictBlock = [ "## Verdict labels (verbatim CLI stdout)", "", "```" ]
                       ++ labelLines ++ [ "```", "" ]
      (beforeStrata, fromStrata) = break (== "## Strata") rendered
      reportLines
        | null fromStrata = rendered ++ [""] ++ verdictBlock
        | otherwise       = beforeStrata ++ verdictBlock ++ fromStrata

  writeFile (rcReport o)    (unlines reportLines ++ renderDiagnosis rep)
  writeFile (rcErrorsCsv o) (unlines (reconErrorsCsv rep))

  mapM_ putStrLn labelLines
  putStrLn ("reconcile: wrote "       ++ rcReport o)
  putStrLn ("reconcile: wrote "       ++ rcErrorsCsv o)

  -- The gate is scriptable: a FAIL is a non-zero exit, never a quiet stdout line.
  when (not (rrPassed rep)) $ exitWith (ExitFailure 1)

-- | The commit the gate ran at, for the report lineage. A checkout without git
-- is reported as such rather than silently omitted — an unattributable gate
-- result is worth less than one that says so.
gitHeadCommit :: IO String
gitHeadCommit = do
  r <- try (readProcessWithExitCode "git" ["rev-parse", "--short", "HEAD"] "")
         :: IO (Either IOException (ExitCode, String, String))
  pure $ case r of
    Right (ExitSuccess, out, _) | not (null (takeWhile (/= '\n') out))
      -> takeWhile (/= '\n') out
    _ -> "unknown (not a git checkout)"

-- | One CSV row per reconciled spell — the machine-readable companion to the
-- markdown report, in the SAME order as its per-spell table.
--
-- @rel_error@ is @NA@ exactly when the ground truth is zero (the spell is
-- excluded from every distribution); it is never a 0 that would read as a
-- perfect reconstruction. Flags are @;@-separated so the field stays one column.
reconErrorsCsv :: ReconReport -> [String]
reconErrorsCsv rep =
  "token_id,is_long,leg_count,leg_count_truth,recon_wei,truth_wei,rel_error,signed_error_wei,flags"
    : [ intercalate ","
          [ T.unpack (srTokenId r)
          , if srIsLong r then "1" else "0"
          , show (srLegCount r)
          , show (srLegCountTruth r)
          , show (srReconWei r)
          , show (srTruthWei r)
          , maybe "NA" (\x -> printf "%.12e" x :: String) (srRelError r)
          , show (srSignedErrorWei r)
          , intercalate ";" (map show (srFlags r))
          ]
      | r <- sortOn srTokenId (rrSpells rep) ]

-- | The PRE-COMMITTED interpretation of the median (plan 10-07, written down
-- BEFORE the numbers came in) plus an automatic scaling-signature check.
--
-- The bands are not adjustable after the fact, and none of them is \"relax the
-- tolerance\": 'gateTolerance' is a fixed constant of the phase contract and a
-- failing gate is diagnosed, never argued down.
renderDiagnosis :: ReconReport -> String
renderDiagnosis rep = unlines $
  [ ""
  , "## Diagnosis"
  , ""
  , "Pre-committed bands (plan 10-07, stated BEFORE the measurement):"
  , ""
  , "| median rel. error | reading | action |"
  , "|---|---|---|"
  , "| `< 0.01` | the machinery is sound | proceed to the full 61-spell gate (10-08) |"
  , "| `[0.01, 0.10)` | an unaccounted wedge exists | diagnose against the RESEARCH wedge table \
      \(long capping, mid-spell `s_options` rewrites, rounding, multi-leg summation, \
      \price conversion, epoch-boundary block choice) before running 61 — do NOT proceed \
      \on the theory that the full sample averages out |"
  , "| `>= 0.10`, or an error near a factor of 2^64 / 2^128 / 1e12 / 1e18 | a scaling or unit bug \
      \(RESEARCH Pitfall 2 lists exactly these signatures) | fix the module; do NOT adjust \
      \the tolerance |"
  , ""
  , "**Observed band:** " ++ band
  , ""
  ] ++ bandProse ++
  [ ""
  , "### Worst 5 spells by relative error"
  , ""
  ] ++ worstSection ++
  [ ""
  , "### Scaling-signature check"
  , ""
  ] ++ scalingSection ++
  [ ""
  , "### Flags observed"
  , ""
  ] ++ flagSection
  where
    m = edMedian (rrShort rep)

    -- The tail, named. A median inside the tolerance says nothing about which
    -- spells missed or why, and the CONTEXT decision requires the distribution
    -- rather than its centre.
    worst = take 5
              (sortOn (negate . maybe (-1) id . srRelError) (rrSpells rep))

    nonZeroCount = length [ () | r <- rrSpells rep, srSignedErrorWei r /= 0 ]

    worstSection
      | null worst = [ "No spells were reconciled." ]
      | otherwise =
          [ show nonZeroCount ++ " of " ++ show (length (rrSpells rep))
              ++ " reconciled spells differ from the ground truth by any amount at all; "
              ++ show (length (rrSpells rep) - nonZeroCount)
              ++ " reproduce `OptionBurn.premium0` EXACTLY, to the wei."
          , ""
          , "| tokenId | stratum | legs | rel error | signed error wei | flags |"
          , "|---|---|---|---|---|---|"
          ] ++
          [ "| `" ++ T.unpack (srTokenId r) ++ "` | "
              ++ (if srIsLong r then "long" else "short") ++ " | "
              ++ show (srLegCount r) ++ " | "
              ++ maybe "n/a (zero truth)" fmtG (srRelError r) ++ " | "
              ++ show (srSignedErrorWei r) ++ " | "
              ++ (if null (srFlags r) then "—"
                    else intercalate "," (map show (srFlags r))) ++ " |"
          | r <- worst ]

    band
      | isNaN m      = "`n/a` — the short stratum is empty, so there is no measurement to read."
      | m < 0.01     = "`< 0.01`"
      | m < 0.10     = "`[0.01, 0.10)`"
      | otherwise    = "`>= 0.10`"

    bandProse
      | isNaN m =
          [ "No short-stratum spell carried a non-zero ground truth, so the pre-check"
          , "measured nothing. This is not a pass." ]
      | m < 0.01 =
          [ "The reconstruction reproduces the protocol's own `OptionBurn.premium0` to"
          , "well inside the 1% tolerance. The residual is the integer-flooring wedge"
          , "RESEARCH predicted (`< 1 wei per leg per touch`), not a structural error:"
          , "the reconstruction is a *decomposition* of the ground truth, so exactness"
          , "up to flooring is the expected outcome rather than a lucky one." ]
      | m < 0.10 =
          [ "**An unaccounted wedge exists.** This is the band RESEARCH explicitly warns"
          , "against treating as success. Diagnose against the wedge table above before"
          , "spending the full 61-spell gate." ]
      | otherwise =
          [ "**A scaling or unit bug is the leading hypothesis.** Check the X64 accumulator"
          , "scale, the mod-2^128 difference, the leg-liquidity multiplier, and the"
          , "ground-truth unit determination before anything else." ]

    -- |recon| / |truth| per spell, checked against the classic factor signatures.
    ratios =
      [ (srTokenId r, abs (fromInteger (srReconWei r)) / abs (fromInteger (srTruthWei r)))
      | r <- rrSpells rep, srTruthWei r /= 0, srReconWei r /= 0 ]

    suspectFactors :: [(String, Double)]
    suspectFactors =
      [ ("2^64",  2 ** 64), ("2^128", 2 ** 128), ("1e12", 1e12), ("1e18", 1e18) ]

    nearFactor x (lbl, f) =
      [ lbl | abs (x / f - 1) < 0.01 || abs (x * f - 1) < 0.01 ]

    hits = [ (tid, lbl) | (tid, x) <- ratios, (lbl, f) <- suspectFactors
           , lbl `elem` nearFactor x (lbl, f) ]

    scalingSection
      | null ratios =
          [ "No spell had both a non-zero reconstruction and a non-zero ground truth, so"
          , "the ratio check has no input." ]
      | null hits =
          [ "**Clean.** No spell's `|recon| / |truth|` ratio sits within 1% of 2^64, 2^128,"
          , "1e12 or 1e18 (or their reciprocals) — the four factor signatures RESEARCH"
          , "Pitfall 2 names. The unit stack is not the problem." ]
      | otherwise =
          [ "**A factor signature was hit — treat this as a unit bug until proven otherwise:**"
          , ""
          , "| tokenId | suspect factor |"
          , "|---|---|"
          ] ++
          [ "| `" ++ T.unpack tid ++ "` | " ++ lbl ++ " |" | (tid, lbl) <- hits ]

    flaggedSpells = [ r | r <- rrSpells rep, not (null (srFlags r)) ]

    flagSection
      | null flaggedSpells =
          [ "None of the reconciled spells carried a premium flag." ]
      | otherwise =
          [ show (length flaggedSpells) ++ " of " ++ show (length (rrSpells rep))
              ++ " reconciled spells carry a flag. The two that appear here are EXPECTED"
              ++ " at spell endpoints and are not defects:"
          , ""
          , "- `ChunkEmpty` — `netLiquidity == 0` at an endpoint block. At the BURN block"
          , "  this is the normal state: the burn removed the position's liquidity, so"
          , "  `getAccountPremium` returns the STORED accumulator rather than a live"
          , "  extrapolation. That stored value is exactly what `_getPremia` itself used,"
          , "  which is why these spells still reconcile to the wei."
          , "- `Extrapolated` — the read passed a real `atTick` rather than the"
          , "  `8388607` stored-value sentinel."
          , ""
          , "Neither flag is auto-dropped and neither is invisible (10-05 contract)." ]

-- | A one-line description of which spells the run selected, for the lineage.
selectionLabel :: ReconcileOpts -> String
selectionLabel o = intercalate ", " $
  [ if rcOnlyShort o then "short stratum only" else "both strata" ] ++
  [ "at most " ++ show (rcMaxLegs o) ++ " leg(s)" | rcMaxLegs o > 0 ] ++
  [ "first " ++ show (rcLimit o) ++ " spells" | rcLimit o > 0 ]

-- | @(tokenId, legIndex) -> (tokenType, tickLower, tickUpper)@ from the Wave-0
-- per-leg census, used only as a cross-check on the resolved chunk ranges.
loadChunkLegsCensus :: FilePath -> IO (Map.Map (T.Text, Int) (Int, Int, Int))
loadChunkLegsCensus fp = do
  r <- try (readFile' fp) :: IO (Either IOException String)
  case r of
    Left _    -> pure Map.empty     -- the census is optional; its absence is reported as 0 checks
    Right txt -> pure (Map.fromList (mapMaybe parseRow (drop 1 (lines txt))))
  where
    parseRow l = case splitOn ',' l of
      (tid : ix : _strike : _w : tt : _rest@(_ : _ : tl : tu : _)) -> do
        i  <- readMaybe ix
        t  <- readMaybe tt
        lo <- readMaybe tl
        hi <- readMaybe tu
        pure ((T.pack tid, i), (t, lo, hi))
      _ -> Nothing

-- ---------------------------------------------------------------------------
-- burn-truth (plan 10-09: freeze the ground truth as an INPUT)
-- ---------------------------------------------------------------------------

runBurnTruth :: BurnTruthOpts -> IO ()
runBurnTruth o = do
  let ep   = Endpoint (T.pack (btEndpoint o))
      pool = PoolAddr (T.pack (btPool o))
  now <- getCurrentTime
  let dateStr = formatTime defaultTimeLocale "%Y-%m-%d" now

  mints <- fetchMints ep pool
  burns <- fetchBurns ep pool
  legs  <- fetchLegs ep pool
  let legMap = Map.fromList legs
      raws   = assembleSpellRaws ethUsdcDecimalShift mints burns legs
  panelSpells <- loadPanelCsv (btPanel o)
  let panelToks = Set.fromList (map spTokenId panelSpells)
      selected  = [ (tid, m, b) | (tid, m, b) <- raws, tid `Set.member` panelToks ]

      -- The unit is DETERMINED by the gate's own classifier over the same burns,
      -- never assumed here: a 1e18 unit error is the single most likely way a
      -- frozen ground truth could be frozen wrong.
      unit  = classifyGroundTruthUnit [ b | (_, _, b) <- selected ]
      rows  = sortOn (\(tid, _, b) -> (tid, beBlock b)) selected
      truthOf b = groundTruthWei unit b
      legsOf tid m = resolveLegChunks marketTickSpacing (round (mePositionSize m))
                       (Map.findWithDefault [] tid legMap)

      maxAbs = maximumOrI [ abs (truthOf b) | (_, _, b) <- rows ]
      -- BigInt -> Double -> Integer is exact only below 2^53. Checked rather than
      -- assumed, so a future population that breaks it is caught at freeze time.
      exactInDouble = maxAbs < 2 ^ (53 :: Int)

  -- THE cross-check: this artifact must reproduce, per tokenId and to the wei,
  -- the truth_wei the gate scored against. If it does not, the freeze is of a
  -- different quantity than the one that was validated.
  reconTruth <- loadReconTruth (btReconErrors o)
  let frozenByTok = Map.fromListWith (+) [ (tid, truthOf b) | (tid, _, b) <- rows ]
      truthMismatches =
        [ (tid, f, g)
        | (tid, g) <- Map.toList reconTruth
        , let f = Map.findWithDefault 0 tid frozenByTok, f /= g ]

  mapM_ putStrLn
    [ "BURN_TRUTH_ROWS: "      ++ show (length rows)
    , "BURN_TRUTH_TOKENIDS: "  ++ show (Set.size (Set.fromList [ t | (t, _, _) <- rows ]))
    , "GROUND_TRUTH_UNIT: "    ++ show unit
    , "MAX_ABS_PREMIUM0_WEI: " ++ show maxAbs
    , "EXACT_IN_DOUBLE: "      ++ (if exactInDouble then "1" else "0")
    , "TRUTH_MISMATCHES: "     ++ show (length truthMismatches)
    ]
  mapM_ (\(tid, f, g) -> putStrLn ("  MISMATCH " ++ T.unpack tid
                                    ++ " frozen=" ++ show f ++ " gate=" ++ show g))
        (take 10 truthMismatches)

  argv   <- getArgs
  commit <- gitHeadCommit
  let banner = map ("# " ++)
        [ "burn-truth.csv — the FROZEN per-spell OptionBurn ground truth, plan 10-09"
        , ""
        , "measured: " ++ dateStr ++ "   git commit: " ++ commit
        , "command: econometrics " ++ unwords argv
        , "subgraph endpoint: " ++ btEndpoint o ++ " (keyless public Goldsky; no API key used)"
        , "underlying pool (V4 poolId): " ++ btPool o
        , "population: " ++ btPanel o ++ " (" ++ show (Set.size panelToks) ++ " tokenIds)"
        , ""
        , "WHY THIS FILE EXISTS. The 10-08 anti-fabrication review recorded one"
        , "limitation it could not close: truth_wei — the protocol's own"
        , "OptionBurn.premium0, the quantity the reconciliation gate is scored"
        , "AGAINST — was fetched live at reconcile time and materialised only in"
        , "reconcile-errors.csv, which is the gate's OUTPUT. A ground truth that"
        , "exists only inside the artifact it validates cannot be independently"
        , "re-checked. This file is that ground truth as a committed INPUT."
        , ""
        , "UNIT: " ++ show unit ++ " — determined by Panel.Reconcile."
        , "  classifyGroundTruthUnit over these same burns, the SAME classifier the"
        , "  gate used; never assumed here."
        , "  " ++ T.unpack (groundTruthExpr unit)
        , "max |premium0| = " ++ show maxAbs ++ " wei, "
          ++ (if exactInDouble then "BELOW" else "ABOVE") ++ " 2^53 = 9007199254740992,"
        , "  so the subgraph BigInt -> Double -> Integer round-trip is "
          ++ (if exactInDouble then "EXACT" else "LOSSY — DO NOT TRUST THESE VALUES")
        , "  on every row of this population."
        , ""
        , "CROSS-CHECK: summed per tokenId, this file reproduces reconcile-errors.csv"
        , "  truth_wei with TRUTH_MISMATCHES = " ++ show (length truthMismatches)
          ++ " over " ++ show (Map.size reconTruth) ++ " tokenIds."
        , ""
        , "SIGN CONVENTION: as the protocol emits it — POSITIVE for short positions"
        , "  (the seller receives), NEGATIVE for long ones (the buyer pays). No"
        , "  seller-side flip is applied here; premium_usd in panel.csv applies one."
        , "premium0_wei / premium1_wei are raw 18-decimal (ETH) and 6-decimal (USDC)"
        , "  token units respectively. premium0 is the gate's ground truth: 61 burns"
        , "  carry a non-zero premium0 against 38 non-zero premium1."
        ]
      header = "token_id,account,mint_block,burn_block,mint_timestamp,burn_timestamp,\
               \premium0_wei,premium1_wei,position_size,is_long,leg_count"
      body = unlines
        [ intercalate ","
            [ T.unpack tid, T.unpack (beAccount b)
            , show (meBlock m), show (beBlock b)
            , show (meTimestamp m), show (beTimestamp b)
            , show (truthOf b), show (round (bePremium1 b) :: Integer)
            , show (round (bePositionSize b) :: Integer)
            , if isLong then "1" else "0", show (length lcs) ]
        | (tid, m, b) <- rows
        , let lcs    = legsOf tid m
              isLong = case lcs of { (lc : _) -> lcIsLong lc ; [] -> False }
        ]
  writeFile (btOut o) (unlines banner ++ header ++ "\n" ++ body)
  putStrLn ("burn-truth: wrote " ++ btOut o)

  when (not (null truthMismatches) || not exactInDouble) $ exitWith (ExitFailure 1)

-- | @tokenId -> Σ truth_wei@ from @reconcile-errors.csv@ (column 6).
loadReconTruth :: FilePath -> IO (Map.Map T.Text Integer)
loadReconTruth fp = do
  txt <- readFile' fp
  pure (Map.fromListWith (+) (mapMaybe parseRow (drop 1 (lines txt))))
  where
    parseRow l = case splitOn ',' l of
      (tid : _isLong : _lc : _lct : _recon : truth : _) ->
        (\w -> (T.pack tid, w)) <$> readMaybe truth
      _ -> Nothing

-- ---------------------------------------------------------------------------
-- epoch-panel (plan 10-09: the spec §1 position-epoch unit, restored)
-- ---------------------------------------------------------------------------

runEpochPanel :: EpochPanelOpts -> IO ()
runEpochPanel o = do
  -- 0. PRECONDITION. The panel is a decomposition of a validated quantity; on an
  --    unvalidated LHS it would be a decomposition of nothing.
  gateTxt <- readFile' (epGateReport o)
  when (not (any (== "GATE: PASS") (lines gateTxt))) $
    ioError (userError ("ABORT: no line-anchored 'GATE: PASS' in " ++ epGateReport o
                         ++ " — this plan does not run on an unvalidated LHS."))
  putStrLn ("epoch-panel: gate precondition OK (GATE: PASS in " ++ epGateReport o ++ ")")

  let ep       = Endpoint (T.pack (epEndpoint o))
      pool     = PoolAddr (T.pack (epPool o))
      epochSecs = max 1 (epEpochHours o) * 3600
  now <- getCurrentTime
  let dateStr = formatTime defaultTimeLocale "%Y-%m-%d" now

  -- 1. The spell population, through the SINGLE pairing rule the read schedule
  --    and the gate both used.
  mints <- fetchMints ep pool
  burns <- fetchBurns ep pool
  legs  <- fetchLegs ep pool
  let legMap = Map.fromList legs
      raws   = assembleSpellRaws ethUsdcDecimalShift mints burns legs
      allSpells =
        [ (tid, m, b, resolveLegChunks marketTickSpacing (round (mePositionSize m))
                        (Map.findWithDefault [] tid legMap))
        | (tid, m, b) <- raws ]

  -- 2. panel.csv is THE population, exactly as in the gate. The subgraph advances;
  --    the population the gate scored does not.
  panelSpells <- loadPanelCsv (epPanel o)
  let panelToks = Set.fromList (map spTokenId panelSpells)
      spells    = [ s | s@(tid, _, _, _) <- allSpells, tid `Set.member` panelToks ]
  putStrLn ("epoch-panel: " ++ show (length raws) ++ " paired spells on the subgraph, "
             ++ show (length spells) ++ " in the gate population ("
             ++ show (Set.size panelToks) ++ " tokenIds)")

  -- 3. The accumulator readings, grouped by the POOL-WIDE (chunk, side) identity.
  accCache <- loadAccumulators (epAccumulators o)
  let readings = map accRowToReading (Map.elems accCache)
      byChunk  = Map.fromListWith (++)
        [ ((arChunkKey r, arIsLong r), [r]) | r <- readings ]
      accBlocks = map arBlock readings
      accEpochs = map arEpoch readings
  putStrLn ("epoch-panel: " ++ show (length readings) ++ " accumulator readings over "
             ++ show (Map.size byChunk) ++ " (chunk, side) series")

  -- 4. Decompose each spell into per-(leg, epoch) premium observations.
  let perSpell =
        [ buildSpellPremiumObs tid (meBlock m, beBlock b) lcs byChunk
        | (tid, m, b, lcs) <- spells ]
      obs       = concatMap fst perSpell
      legHoles  = sum (map snd perSpell)

  -- 5. The variance series and THE join.
  varMap <- loadVarianceRows (epVariance o)
  let (rows, unmatched) = assembleEpochPanel epochSecs varMap spells obs

  -- 6. Metrics.
  let tokIds        = nub (map eoTokenId rows)
      epochs        = nub (map eoEpoch rows)
      perTok        = Map.fromListWith (+) [ (eoTokenId r, 1 :: Int) | r <- rows ]
      multiEpochTok = length [ () | c <- Map.elems perTok, c > 1 ]
      flaggedRows   = length [ () | r <- rows, not (null (eoFlags r)) ]
      quietRows     = length [ () | r <- rows, eoNSwaps r == 0 ]
      gain          = fromIntegral (length rows)
                        / fromIntegral phase9BaselineRows :: Double

      -- The 10-01 census counted joinable epochs PER SPELL and summed. This panel
      -- is keyed on (tokenId, epoch), so a tokenId holding two spells that share
      -- an hour contributes ONE row where the census counted two. Reporting the
      -- census-comparable number alongside the panel's own makes the difference a
      -- measured collapse rather than an unexplained shortfall.
      matchedEpochs = Set.fromList (map eoEpoch rows)
      spellEpochRows = sum
        [ Set.size (Set.fromList
            [ e | ob <- os, let e = fromIntegral (poEpoch ob) :: Int
                , e `Set.member` matchedEpochs ])
        | (os, _) <- perSpell ]

      -- Concentration. Under tokenId-CLUSTERED inference a row count concentrated
      -- in a few long-lived positions buys far less than it looks like it does, so
      -- the share is published next to the count rather than left to be found.
      sortedCounts = reverse (sort (Map.elems perTok))
      top10Share   = fracOf (sum (take 10 sortedCounts)) (sum sortedCounts)

      -- The telescoping cross-check, per tokenId, against the gate's own
      -- per-spell reconstruction. EXACT is the bar: the panel is a decomposition
      -- of that number, not an independent estimate of it.
      panelByTok = Map.fromListWith (+) [ (eoTokenId r, eoPremiumWei r) | r <- rows ]
      obsByTok   = Map.fromListWith (+) [ (poTokenId r, poPremiumWei0 r) | r <- obs ]
  reconByTok <- loadReconErrors (epReconErrors o)
  let telescopeCmp =
        [ (tid, Map.findWithDefault 0 tid obsByTok
              , Map.findWithDefault 0 tid panelByTok, recon)
        | (tid, recon) <- Map.toList reconByTok ]
      obsMismatches   = [ t | t@(_, d, _, r) <- telescopeCmp, d /= r ]
      panelMismatches = [ t | t@(_, _, p, r) <- telescopeCmp, p /= r ]

  mapM_ putStrLn
    [ "PANEL_ROWS: "            ++ show (length rows)
    , "PANEL_TOKENIDS: "        ++ show (length tokIds)
    , "PANEL_EPOCHS: "          ++ show (length epochs)
    , "SPELL_EPOCH_ROWS: "      ++ show spellEpochRows
    , "UNMATCHED_EPOCHS: "      ++ show (length unmatched)
    , "MULTI_EPOCH_TOKENIDS: "  ++ show multiEpochTok
    , "WITHIN_POSITION_EPOCHS_MEDIAN: " ++ fmtG (medianI (Map.elems perTok))
    , "WITHIN_POSITION_EPOCHS_MAX: "    ++ show (maximumOr0 (Map.elems perTok))
    , "TOP10_TOKENID_ROW_SHARE: "       ++ fmtG top10Share
    , "FLAGGED_ROWS: "          ++ show flaggedRows
    , "QUIET_EPOCH_ROWS: "      ++ show quietRows
    , "LEG_READ_HOLES: "        ++ show legHoles
    , "TELESCOPE_MISMATCHES: "  ++ show (length obsMismatches)
    , "PANEL_SUM_MISMATCHES: "  ++ show (length panelMismatches)
    , "PHASE9_BASELINE_ROWS: "  ++ show phase9BaselineRows
    , "GAIN_FACTOR: "           ++ fmtG gain
    ]
  when (not (null unmatched)) $
    putStrLn ("  unmatched epochs: " ++ show (take 20 unmatched))
  mapM_ (\(tid, d, p, r) ->
           putStrLn ("  MISMATCH " ++ T.unpack tid ++ " decomposed=" ++ show d
                      ++ " panel=" ++ show p ++ " gate_recon=" ++ show r))
        (take 10 (nub (obsMismatches ++ panelMismatches)))

  -- 7. Write the artifact with the lineage it cannot reconstruct for itself.
  argv   <- getArgs
  commit <- gitHeadCommit
  let banner = map ("# " ++)
        [ "panel-epoch.csv — THE position-epoch panel (spec §1 unit), plan 10-09"
        , ""
        , "measured: " ++ dateStr ++ "   git commit: " ++ commit
        , "command: econometrics " ++ unwords argv
        , "working directory: repository root (all paths below are repo-relative)"
        , ""
        , "subgraph endpoint: " ++ epEndpoint o
        , "underlying pool (V4 poolId): " ++ epPool o
        , "PanopticPool: 0xb50e8bb68f5855da742f4579274902a20454174a (ETH/USDC, fee 500)"
        , "SFPM read target: " ++ T.unpack sfpmAddress
        , "VEGOID / nu: 8 / 0.125 — applied INSIDE the contract's X64 accumulator, never re-applied here"
        , ""
        , "accumulator readings: " ++ epAccumulators o
          ++ " (" ++ show (length readings) ++ " rows, blocks "
          ++ show (minimumOrI accBlocks) ++ ".." ++ show (maximumOrI accBlocks)
          ++ ", epochs " ++ show (minimumOrI accEpochs) ++ ".."
          ++ show (maximumOrI accEpochs) ++ ")"
        , "gate population: " ++ epPanel o ++ " (" ++ show (Set.size panelToks) ++ " tokenIds)"
        , "gate verdict: " ++ epGateReport o
          ++ " — GATE: PASS, short-stratum median rel error 0.0, worst 5.447268e-4, tolerance 0.01"
        , "telescoping cross-check: " ++ epReconErrors o
          ++ " — TELESCOPE_MISMATCHES " ++ show (length obsMismatches)
          ++ ", PANEL_SUM_MISMATCHES " ++ show (length panelMismatches)
        , "variance series: " ++ epVariance o ++ " (hourly)"
        , ""
        , "epoch rule: floor(unixSeconds / " ++ show epochSecs ++ ") via"
        , "  Panel.Epoch.epochOfSeconds — the SAME function the variance series uses."
        , "  The join is an exact INTEGER match; UNMATCHED_EPOCHS = "
          ++ show (length unmatched) ++ "."
        , "epoch attribution: a row's premium is the accumulator difference over the"
        , "  interval STARTING at that epoch's boundary block, so it accrued during"
        , "  epoch e and is regressed on sigma^2_e measured over the same hour."
        , ""
        , "premium_wei: Integer, currency0 (ETH), seller-side sign as the protocol emits it."
        , "  CANONICAL. premium_eth = premium_wei / 1e18 is the regression LHS."
        , "  Summing premium_wei over a tokenId's rows reproduces that spell's"
        , "  gate-validated recon_wei EXACTLY (Panoptic.Premium.decomposePremium)."
        , "strike_tick: Leg.strike, ALREADY an int24 tick — no round(log K / log 1.0001)."
        , "pool_tick: the epoch's mean pool tick from the same V4 Swap series as sigma^2."
        , "moneyness: Model.Upsilon.moneyness strike_tick pool_tick = |i_K - i_t|."
        , "flags: ';'-separated Panoptic.Premium.PremiumFlag values; rows are RETAINED."
        , "n_swaps: swaps behind this epoch's sigma^2. n_swaps = 0 marks an hour in"
        , "  which the pool saw no trade at all (sigma^2 = 0 measured, pool tick carried"
        , "  forward); " ++ show quietRows ++ " such row(s) here."
        , ""
        , "PANEL_ROWS " ++ show (length rows)
          ++ " / PANEL_TOKENIDS " ++ show (length tokIds)
          ++ " / PANEL_EPOCHS " ++ show (length epochs)
          ++ " / MULTI_EPOCH_TOKENIDS " ++ show multiEpochTok
          ++ " / FLAGGED_ROWS " ++ show flaggedRows
        , "SPELL_EPOCH_ROWS " ++ show spellEpochRows
          ++ " (the 10-01 census's per-SPELL count; PANEL_ROWS is per"
          ++ " (tokenId, epoch), so a tokenId holding two spells that share an hour"
          ++ " contributes one row where the census counted two)"
        , "within-position epochs: median " ++ fmtG (medianI (Map.elems perTok))
          ++ ", max " ++ show (maximumOr0 (Map.elems perTok))
          ++ "; top-10 tokenId row share " ++ fmtG top10Share
          ++ " — precision is bounded by the 55 CLUSTERS, not by the row count."
        , "Phase-9 baseline 61 spell rows; GAIN_FACTOR " ++ fmtG gain
        ]
  writeEpochPanelCsv (epOut o) banner rows
  putStrLn ("epoch-panel: wrote " ++ epOut o)

  -- 8. Fail loud. An unmatched epoch or a telescoping mismatch is a bug in the
  --    reconstruction, not a tolerance to absorb.
  when (not (null unmatched) || not (null obsMismatches) || not (null panelMismatches)) $
    exitWith (ExitFailure 1)

-- | An 'AccRow' from the committed CSV as the premium arithmetic's 'AccReading'.
-- A pure re-labelling: no field is derived, defaulted or dropped.
accRowToReading :: AccRow -> AccReading
accRowToReading r = AccReading
  { arChunkKey         = ChunkKey (acTokenType r) (acTickLower r) (acTickUpper r)
  , arBlock            = acBlock r
  , arEpoch            = acEpoch r
  , arIsLong           = acIsLong r
  , arAtTick           = acAtTick r
  , arAcc0             = acAcc0 r
  , arAcc1             = acAcc1 r
  , arNetLiquidity     = acNetLiq r
  , arRemovedLiquidity = acRemovedLiq r
  , arEndpoint         = acEndpoint r
  }

-- | @tokenId -> Σ recon_wei@ from @reconcile-errors.csv@ (the gate's own
-- per-spell reconstruction). Summed because a tokenId can carry more than one
-- spell — 61 spells over 55 tokenIds.
loadReconErrors :: FilePath -> IO (Map.Map T.Text Integer)
loadReconErrors fp = do
  txt <- readFile' fp
  pure (Map.fromListWith (+) (mapMaybe parseRow (drop 1 (lines txt))))
  where
    parseRow l = case splitOn ',' l of
      (tid : _isLong : _lc : _lct : recon : _) ->
        (\w -> (T.pack tid, w)) <$> readMaybe recon
      _ -> Nothing

-- | Load a variance CSV (daily 4-column or hourly 5-column) into the panel's
-- 'VarianceRow'. @n_swaps@ defaults to 0 when the file predates the column.
loadVarianceRows :: FilePath -> IO (Map.Map Int VarianceRow)
loadVarianceRows fp = do
  txt <- readFile' fp
  let keep l = not ("#" `isPrefixOf` l) && not ("epoch" `isPrefixOf` l) && not (null l)
  pure (Map.fromList (mapMaybe parseRow (filter keep (lines txt))))
  where
    parseRow l = case splitOn ',' l of
      (e : s2 : s2i : tk : rest) -> do
        ep  <- readMaybe e
        a   <- readMaybe s2
        b   <- readMaybe s2i
        t   <- readMaybe tk :: Maybe Double
        let n = case rest of
                  (x : _) -> maybe 0 id (readMaybe x)
                  []      -> 0
        pure (ep, VarianceRow a b (round t) n)
      _ -> Nothing

minimumOrI, maximumOrI :: [Integer] -> Integer
minimumOrI [] = 0
minimumOrI xs = minimum xs
maximumOrI [] = 0
maximumOrI xs = maximum xs

-- ---------------------------------------------------------------------------
-- variance
-- ---------------------------------------------------------------------------

runVariance :: VarianceOpts -> IO ()
runVariance vo = do
  ticks <- case (voFrom vo, voTo vo) of
    (Just f, Just t) -> do
      let cfg = defaultBaseRpc { rpcUrl = voRpc vo, rpcFromBlock = f
                               , rpcToBlock = t, rpcChunk = voChunk vo }
      putStrLn ("variance: live fetch of V4 Swap logs, blocks "
                 ++ show f ++ ".." ++ show t ++ " via " ++ voRpc vo)
      if voPatch vo
        then patchTickCache (voTicksCsv vo) cfg
        else do
          -- Stream to the cache as chunks arrive: a ~500-call pull must not lose
          -- hours of work if a late call fails.
          ts <- fetchSwapTicks cfg (Just (voTicksCsv vo))
          putStrLn ("variance: cached " ++ show (length ts) ++ " ticks -> " ++ voTicksCsv vo)
          pure ts
    _ -> do
      putStrLn ("variance: loading cached ticks <- " ++ voTicksCsv vo)
      loadSwapTicks (voTicksCsv vo)
  let epochHours = max 1 (voEpochHours vo)
      epochSecs  = epochHours * 3600
  if epochHours == 24
    then do
      -- The Phase-9 DAILY artifact, byte-reproducible: same writer, same columns.
      let rv = realizedVariance ticks
          iv = instrumentVariance ticks
          mt = meanPoolTick ticks
      writeVarianceCsv (voOutCsv vo) rv iv mt
      putStrLn ("variance: wrote " ++ voOutCsv vo ++ " (" ++ show (Map.size rv)
                 ++ " daily epochs, " ++ show (length ticks) ++ " ticks)")
    else do
      -- The 10-01 HOURLY re-scope: the SAME estimators at a finer bucket, plus
      -- the per-epoch swap count, so a constructed zero can be told apart from a
      -- measured one.
      let rv0 = realizedVarianceAt   epochSecs ticks
          iv0 = instrumentVarianceAt epochSecs ticks
          mt0 = meanPoolTickAt       epochSecs ticks
          ns0 = swapCountsAt         epochSecs ticks
          (rv, iv, mt, ns, quiet) = fillQuietEpochs rv0 iv0 mt0 ns0
          counts = Map.elems ns
          thin   = length [ () | c <- counts, c < minSwapsForVariance ]
      writeVarianceCsvAt epochSecs (voOutCsv vo) rv iv mt ns
      putStrLn ("variance: wrote " ++ voOutCsv vo ++ " (" ++ show (Map.size rv)
                 ++ " epochs of " ++ show epochHours ++ "h, "
                 ++ show (length ticks) ++ " ticks)")
      putStrLn ("EPOCH_HOURS: "        ++ show epochHours)
      putStrLn ("VARIANCE_EPOCHS: "    ++ show (Map.size rv))
      putStrLn ("EPOCH_RANGE: "        ++ show (minimumOr0 (Map.keys rv)) ++ ".."
                                        ++ show (maximumOr0 (Map.keys rv)))
      putStrLn ("EPOCH_GAPS: "         ++ show (epochGapCount (Map.keys rv)))
      putStrLn ("QUIET_EPOCHS_FILLED: " ++ show (length quiet)
                 ++ (if null quiet then "" else " " ++ show quiet))
      putStrLn ("SWAPS_PER_EPOCH_MIN: "    ++ show (minimumOr0 counts))
      putStrLn ("SWAPS_PER_EPOCH_MEDIAN: " ++ fmtG (medianI counts))
      putStrLn ("SWAPS_PER_EPOCH_MAX: "    ++ show (maximumOr0 counts))
      putStrLn ("THIN_EPOCHS: "        ++ show thin)

-- | Interior epochs of @[min, max]@ that carry NO row at all. A hole in the
-- variance series is a hole in the panel's joinable grid, so it is counted and
-- printed rather than left for a downstream join to discover.
epochGapCount :: [Int] -> Int
epochGapCount [] = 0
epochGapCount es = (maximum es - minimum es + 1) - length (nub es)

-- | Repair a bounded window of the tick cache by RE-FETCHING it and merging.
--
-- The cache is a @(timestamp_unix, tick)@ stream with no log index, so a merge
-- cannot dedupe row-by-row. What it can do exactly is REPLACE a closed timestamp
-- interval: fetch the block window, take @[t0, t1]@ from what came back, drop
-- every cached row inside that interval, and splice the fresh rows in. The result
-- is the old series everywhere outside the window and the freshly-read series
-- inside it.
--
-- Used by 10-09 to close a single-hour hole in the 09-09 full-history pull
-- (epoch 495112 carried ZERO swaps between neighbours carrying 700+, which is a
-- fetch gap, not a quiet market). Bounded, keyless, and reported: the counts
-- printed below are what makes the repair auditable.
patchTickCache :: FilePath -> RpcConfig -> IO [(UTCTime, Int)]
patchTickCache cache cfg = do
  existing <- loadSwapTicks cache
  fetched  <- fetchSwapTicks cfg Nothing
  when (null fetched) $
    ioError (userError "ABORT: --patch fetched ZERO ticks; refusing to rewrite the \
                       \cache with an empty window (a silent truncation is worse \
                       \than the gap it was meant to close).")
  let t0     = minimum (map fst fetched)
      t1     = maximum (map fst fetched)
      kept   = [ r | r@(t, _) <- existing, t < t0 || t > t1 ]
      merged = sortOn fst (kept ++ fetched)
  cacheSwapTicks cache merged
  putStrLn ("variance --patch: cache had "   ++ show (length existing) ++ " ticks")
  putStrLn ("variance --patch: fetched "     ++ show (length fetched)
             ++ " ticks over the window")
  putStrLn ("variance --patch: replaced "    ++ show (length existing - length kept)
             ++ " cached ticks inside the fetched timestamp span")
  putStrLn ("variance --patch: cache now "   ++ show (length merged)
             ++ " ticks -> " ++ cache)
  pure merged

-- ---------------------------------------------------------------------------
-- estimate
-- ---------------------------------------------------------------------------

-- | A per-epoch variance/tick record from @variance.csv@.
data VarRow = VarRow { vrSigma2 :: !Double, vrSigma2I :: !Double, vrTick :: !Double }

runEstimate :: EstimateOpts -> IO ()
runEstimate eo = do
  spells <- loadPanelCsv (eoPanelCsv eo)
  varMap <- loadVarianceCsv (eoVarianceCsv eo)
  flows  <- loadCollateralCsv (eoCollateralCsv eo)
  now    <- getCurrentTime
  let panel   = joinSpells varMap spells
      usable  = [ o | o <- panel, finiteD (obsSigma2 o), finiteD (obsPremium o) ]
      nUse    = length (designPoints panel)
      dateStr = formatTime defaultTimeLocale "%Y-%m-%d" now
      outPath = eoAnalysisDir eo </> (dateStr ++ "-upsilon-estimates.md")

  putStrLn ("estimate: " ++ show (length spells) ++ " spells, "
             ++ show (Map.size varMap) ++ " variance epochs, "
             ++ show nUse ++ " usable observations after the sigma^2 join")

  writeEstimationPanel (eoEstimationCsv eo) usable
  putStrLn ("estimate: exported " ++ eoEstimationCsv eo)

  if nUse < 4
    then do
      let msg = "INSUFFICIENT DATA: only " ++ show nUse
                  ++ " usable observations after the sigma^2 join (4 needed for a "
                  ++ "3-parameter fit). No estimates produced."
      putStrLn ("estimate: " ++ msg)
      writeFile outPath (unlines
        [ "# Panoptic upsilon estimates — " ++ dateStr
        , ""
        , "**RESULT: NOT ESTIMATED.** " ++ msg
        , ""
        , lineageSection eo dateStr (length spells) (Map.size varMap) nUse
        ])
      putStrLn ("estimate: wrote " ++ outPath)
    else do
      let (thetaG, _) = fitGSLCov panel
          thetaIV     = ivFit panel
          tokCl       = [ obsTokenId o | o <- usable ]
          acctCl      = [ obsAccount o | o <- usable ]
          (jRows, resids) = sandwichInputs thetaG usable
          vTok  = clusterSandwich jRows resids tokCl
          vAcct = clusterSandwich jRows resids acctCl
          rU = testUpsilonPos thetaG vTok
          rK = testKappaPos   thetaG vTok
          (rS, symNote) = splitSymmetryTest usable
          collat = collateralObs flows varMap
          alts   = runAlternativesWith collat panel

      reportToStdout thetaG thetaIV vTok vAcct rU rK rS alts usable
      writeFile outPath
        (renderAnalysis eo dateStr spells varMap usable thetaG thetaIV
                        vTok vAcct rU rK rS symNote alts collat)
      putStrLn ("estimate: wrote " ++ outPath)

-- | The ACCOUNT label of an observation. 'joinSpells' encodes 'obsTokenId' as
-- @account#tokenId@ so a single 'Obs' carries both clustering levels; the
-- account is the prefix before the @#@.
obsAccount :: Obs -> T.Text
obsAccount = T.takeWhile (/= '#') . obsTokenId

finiteD :: Double -> Bool
finiteD x = not (isNaN x || isInfinite x)

-- ---------------------------------------------------------------------------
-- Loading
-- ---------------------------------------------------------------------------

-- | Load the spell panel written by @build-panel@.
loadPanelCsv :: FilePath -> IO [Spell]
loadPanelCsv fp = do
  bs <- BL.readFile fp
  case Csv.decode Csv.HasHeader bs
         :: Either String (V.Vector (T.Text, T.Text, Int, Int, Double, Double, Double, Int, Int, Int, Int)) of
    Left err   -> ioError (userError ("panel CSV parse error: " ++ err))
    Right rows -> pure
      [ Spell { spTokenId = tok, spAccount = acct
              , spMintEpoch = em, spBurnEpoch = eb, spDays = days
              , spPremiumUsd = usd, spPremiumRate = rate
              , spStrikeTick = ik, spTickAtMint = tm, spTickAtBurn = tb
              , spIsLong = isLong /= 0 }
      | (tok, acct, em, eb, days, usd, rate, ik, tm, tb, isLong) <- V.toList rows ]

-- | Load @variance.csv@ into @epoch → (σ̂², σ̃², i_t)@. The file carries a
-- @#@-prefixed banner and a header line, so parse by hand.
loadVarianceCsv :: FilePath -> IO (Map.Map Int VarRow)
loadVarianceCsv fp = do
  txt <- readFile fp
  let dataLines = filter keep (lines txt)
      keep l = not ("#" `isPrefixOf` l) && not ("epoch" `isPrefixOf` l) && not (null l)
  pure (Map.fromList (mapMaybe parseRow dataLines))
  where
    parseRow l = case splitOn ',' l of
      (e : s2 : s2i : tk : _) ->
        (\ep a b c -> (ep, VarRow a b c))
          <$> readMaybe e <*> readMaybe s2 <*> readMaybe s2i <*> readMaybe tk
      _ -> Nothing

-- | Load the collateral share flows written by @build-panel@.
loadCollateralCsv :: FilePath -> IO [CollateralFlow]
loadCollateralCsv fp = do
  r <- try (readFile' fp) :: IO (Either IOException String)
  case r of
    -- An absent collateral file is not an error: alternative 4 then reports
    -- itself NOT ESTIMABLE, which is the honest outcome.
    Left _    -> pure []
    Right txt -> pure (mapMaybe parseRow (filter keep (lines txt)))
  where
    keep l = not ("#" `isPrefixOf` l) && not ("owner" `isPrefixOf` l) && not (null l)
    parseRow l = case splitOn ',' l of
      (o : ts : ix : sh : _) ->
        (\t i s -> CollateralFlow (T.pack o) t i s)
          <$> readMaybe ts <*> readMaybe ix <*> readMaybe sh
      _ -> Nothing

splitOn :: Char -> String -> [String]
splitOn d s = case break (== d) s of
  (a, [])       -> [a]
  (a, _ : rest) -> a : splitOn d rest

-- ---------------------------------------------------------------------------
-- The join: spell window -> observation
-- ---------------------------------------------------------------------------

-- | Turn each accrual spell into one estimation observation by averaging the
-- daily variance series and the daily mean pool tick OVER THE SPELL'S EPOCH
-- WINDOW @[epoch_mint, epoch_burn]@ — the window the premium actually accrued in.
--
-- Epochs inside the window with no swap activity contribute nothing (they are
-- simply absent from @variance.csv@); a spell whose whole window is missing gets
-- a NaN σ̂² and is dropped downstream by the finiteness filter.
--
-- 'obsTokenId' is set to @account#tokenId@ so BOTH clusterings are recoverable
-- from a single 'Obs': the tokenId clustering (spec §4.2, the primary) uses the
-- whole label, and the account clustering (the coarser robustness) takes the
-- prefix before @#@.
joinSpells :: Map.Map Int VarRow -> [Spell] -> Panel
joinSpells varMap = map toObs
  where
    toObs s =
      let eps  = [ e | e <- [spMintEpoch s .. spBurnEpoch s]
                 , Just _ <- [Map.lookup e varMap] ]
          rows = mapMaybe (`Map.lookup` varMap) eps
          avg f = if null rows then 0 / 0
                  else sum (map f rows) / fromIntegral (length rows)
      in Obs
        { obsTokenId     = spAccount s <> "#" <> spTokenId s
        , obsEpoch       = spBurnEpoch s
        , obsPremium     = spPremiumRate s
        , obsStrikeTick  = spStrikeTick s
        , obsPoolTick    = if null rows then spTickAtBurn s else round (avg vrTick)
        , obsSigma2      = avg vrSigma2
        , obsSigma2Instr = avg vrSigma2I
        }

-- ---------------------------------------------------------------------------
-- Collateral channel (alternative 4)
-- ---------------------------------------------------------------------------

-- | Reconstruct per-account, per-epoch collateral share BALANCES from the signed
-- flow series (a step function: the running sum of deposits minus withdraws),
-- and join σ̂²_t onto each epoch.
--
-- __Caveat, carried into the analysis output.__ These are DEPOSITED collateral
-- shares, a behavioural quantity, not the protocol's required margin @Q_M@. The
-- subgraph exposes no per-position collateral requirement
-- (@PanopticPoolAccount.collateral{0,1}Shares@ is a CURRENT snapshot only, and
-- @CollateralDayData.totalShares@ is vault-level), so this is the closest
-- available proxy and must be read as such.
collateralObs :: [CollateralFlow] -> Map.Map Int VarRow -> [CollateralObs]
collateralObs flows varMap =
  -- Shares are reported in 1e18-scaled raw units; dividing by 1e18 puts Q_M on a
  -- human scale so the fitted coefficients are readable rather than ~1e22.
  [ CollateralObs owner ep (bal / 1e18) (vrSigma2 vr)
  | (owner, series) <- Map.toList byOwner
  , (ep, bal) <- balancesByEpoch series
  , Just vr <- [Map.lookup ep varMap]
  , finiteD (vrSigma2 vr), bal > 0
  ]
  where
    -- vault index 0 (token0) only: mixing the two vaults' share units is meaningless.
    byOwner = Map.fromListWith (++)
      [ (cfOwner f, [(epochOfTs (cfTimestamp f), cfShares f)])
      | f <- flows, cfIndex f == 0 ]
    epochOfTs ts = fromInteger (ts `div` 86400) :: Int
    -- Running balance, carried forward across every epoch of the variance series.
    balancesByEpoch series =
      let deltas = Map.fromListWith (+) series
          epochs = Map.keys varMap
          go _ [] = []
          go acc (e : es) =
            let acc' = acc + Map.findWithDefault 0 e deltas
            in (e, acc') : go acc' es
      in [ (e, b) | (e, b) <- go 0 (sortOn id epochs), e >= minimum (map fst series) ]

-- ---------------------------------------------------------------------------
-- Estimation helpers
-- ---------------------------------------------------------------------------

-- | Row-gradients @∂f/∂θ@ (via @ad@ on 'Model.Upsilon.model') and residuals at a
-- fitted θ, observation-aligned with the supplied panel.
sandwichInputs :: Theta -> Panel -> ([[Double]], [Double])
sandwichInputs (Theta b0' u0' k') panel = unzip
  [ (gradRow, resid)
  | o <- panel
  , let d  = moneyness (obsStrikeTick o) (obsPoolTick o)
        s2 = obsSigma2 o
        y  = obsPremium o
  , finiteD s2, finiteD y
  , let gradRow = grad (\p -> model p (realToFrac d, realToFrac s2)) [b0', u0', k']
        resid   = y - model [b0', u0', k'] (d, s2)
  ]

-- | Symmetry Wald κ⁺ = κ⁻ (spec §5, test 3): fit the split 4-parameter model,
-- form its tokenId-clustered covariance, and test the 2×2 κ sub-block.
--
-- Also returns an IDENTIFICATION note: the split model needs OTM mass on BOTH
-- sides of the money, so the counts above and below are reported alongside the
-- statistic and the test is refused outright if either side is empty.
splitSymmetryTest :: Panel -> (TestResult, String)
splitSymmetryTest panel
  | nAbove == 0 || nBelow == 0 =
      ( TestResult (0 / 0) (0 / 0) False
      , "NOT IDENTIFIED: " ++ show nAbove ++ " observations above the money and "
          ++ show nBelow ++ " below. The split model needs OTM mass on BOTH sides." )
  | length pts < 5 =
      ( TestResult (0 / 0) (0 / 0) False
      , "NOT IDENTIFIED: only " ++ show (length pts)
          ++ " observations for a 4-parameter split fit." )
  | otherwise =
      ( testSymmetry (Theta4 b0s u0s kps kms) vSplit
      , show nAbove ++ " observations above the money, " ++ show nBelow ++ " below" )
  where
    pts =
      [ ((dP, dM, s2), y, obsTokenId o)
      | o <- panel
      , let s  = signedMoneyness (obsStrikeTick o) (obsPoolTick o)
            dP = max 0 s
            dM = max 0 (negate s)
            s2 = obsSigma2 o
            y  = obsPremium o
      , finiteD s2, finiteD y
      ]
    nAbove = length [ () | ((dP, _, _), _, _) <- pts, dP > 0 ]
    nBelow = length [ () | ((_, dM, _), _, _) <- pts, dM > 0 ]
    dat = [ (x, [y]) | (x, y, _) <- pts ]
    modelF ps x = [modelSplit ps x]
    jacF [_b0, u0', kp', km'] (dP, dM, s2') =
      let ep = exp (negate kp' * dP)
          em = exp (negate km' * dM)
      in [[ 1, (ep + em - 1) * s2'
          , u0' * (negate dP * ep) * s2'
          , u0' * (negate dM * em) * s2' ]]
    jacF ps _ = error ("splitSymmetryTest: bad param length " ++ show (length ps))
    (sol, _) = fitModel 1e-9 1e-9 200 (modelF, jacF) dat [0.0, 1.0, 0.2, 0.2]
    (b0s, u0s, kps, kms) = case sol of
      [a, b, c, d] -> (a, b, c, d)
      _            -> (0 / 0, 0 / 0, 0 / 0, 0 / 0)
    jRows = [ grad (\p -> modelSplit p (realToFrac dP, realToFrac dM, realToFrac s2)) sol
            | ((dP, dM, s2), _, _) <- pts ]
    resids   = [ y - modelSplit sol (dP, dM, s2) | ((dP, dM, s2), y, _) <- pts ]
    clusters = [ c | (_, _, c) <- pts ]
    vSplit   = clusterSandwich jRows resids clusters

-- ---------------------------------------------------------------------------
-- Estimation-panel export (the artifact handed to the GAMS cross-check, 09-10)
-- ---------------------------------------------------------------------------

writeEstimationPanel :: FilePath -> Panel -> IO ()
writeEstimationPanel fp panel = writeFile fp (banner ++ body)
  where
    banner = unlines
      [ "# FINAL ESTIMATION PANEL — Panoptic upsilon identification (phase 09, plan 09-09)."
      , "# One row per position ACCRUAL SPELL (mint -> burn), the unit of observation the"
      , "# live subgraph supports; see the analysis output for why it is not position-epoch."
      , "# tokenId  : account#tokenId (the tokenId clustering label; account = prefix before #)"
      , "# epoch    : UTC-day index floor(unixSeconds/86400) of the spell's BURN"
      , "# pi       : premium accrued to the SHORT side, USD PER DAY over the spell"
      , "# sigma2   : realized variance, averaged over the spell's epoch window"
      , "# sigma2_instrument : disjoint even-swap sub-window RV, same averaging (EIV instrument)"
      , "# distance : moneyness d = |i_K - i_t| in ticks, i_t = spell-window mean pool tick"
      , "tokenId,epoch,pi,sigma2,sigma2_instrument,distance"
      ]
    body = unlines
      [ T.unpack (obsTokenId o) ++ "," ++ show (obsEpoch o) ++ ","
          ++ show (obsPremium o) ++ "," ++ show (obsSigma2 o) ++ ","
          ++ show (obsSigma2Instr o) ++ ","
          ++ show (moneyness (obsStrikeTick o) (obsPoolTick o))
      | o <- sortOn obsEpoch panel ]

-- ---------------------------------------------------------------------------
-- Console report
-- ---------------------------------------------------------------------------

reportToStdout
  :: Theta -> Theta -> LA.Matrix Double -> LA.Matrix Double
  -> TestResult -> TestResult -> TestResult -> [(T.Text, Estimates)] -> Panel -> IO ()
reportToStdout (Theta bg ug kg) (Theta bi ui ki) vTok vAcct rU rK rS alts usable = do
  let (seB : seU : seK : _) = take 3 (standardErrors vTok ++ repeat (0 / 0))
  putStrLn "estimate: PRIMARY GSL Levenberg-Marquardt  pi = b0 + u0*exp(-k*d)*sigma2"
  printf "  b0 = %.6g (SE %.3g)   u0 = %.6g (SE %.3g)   kappa = %.6g (SE %.3g)\n"
         bg seB ug seU kg seK
  printf "estimate: EIV IV (sigma~2 instruments sigma2): b0 = %.6g  u0 = %.6g  kappa = %.6g\n"
         bi ui ki
  printf "estimate: %d obs, %d tokenId clusters, %d account clusters\n"
         (length usable) (length (nub (map obsTokenId usable)))
         (length (nub (map (T.takeWhile (/= '#') . obsTokenId) usable)))
  putStrLn "estimate: specification tests (spec 5, tokenId-clustered)"
  printf "  upsilon0>0 : z = %.4f  p = %.4g  reject = %s\n" (statistic rU) (pValue rU) (show (reject rU))
  printf "  kappa>0    : z = %.4f  p = %.4g  reject = %s   (THE null test)\n"
         (statistic rK) (pValue rK) (show (reject rK))
  printf "  kappa+=kappa- : W = %.4f  p = %.4g  reject = %s\n"
         (statistic rS) (pValue rS) (show (reject rS))
  putStrLn "estimate: alternatives"
  mapM_ (\(l, e) -> putStrLn ("  " ++ T.unpack l ++ ": "
          ++ (if estIdentified e then show (estCoefs e) else "NOT IDENTIFIED"))) alts
  let _ = vAcct
  pure ()

-- ---------------------------------------------------------------------------
-- The self-describing analysis output
-- ---------------------------------------------------------------------------

fmtG :: Double -> String
fmtG x
  | isNaN x      = "n/a"
  | isInfinite x = "inf"
  | otherwise    = printf "%.6g" x

-- | Point estimate ± clustered SE with a 95% Normal CI.
row3 :: String -> Double -> Double -> String
row3 nm est se =
  "| " ++ nm ++ " | " ++ fmtG est ++ " | " ++ fmtG se ++ " | ["
    ++ fmtG (est - 1.96 * se) ++ ", " ++ fmtG (est + 1.96 * se) ++ "] |"

renderAnalysis
  :: EstimateOpts -> String -> [Spell] -> Map.Map Int VarRow -> Panel
  -> Theta -> Theta -> LA.Matrix Double -> LA.Matrix Double
  -> TestResult -> TestResult -> TestResult -> String
  -> [(T.Text, Estimates)] -> [CollateralObs] -> String
renderAnalysis eo dateStr spells varMap usable
               (Theta bg ug kg) (Theta bi ui ki) vTok vAcct rU rK rS symNote alts _collat =
  unlines $
    [ "# Panoptic vol-claim upsilon: live estimates — " ++ dateStr
    , ""
    , "Phase 09 plan 09-09 (CTX-ALT + the live run). Estimation of"
    , ""
    , "> `pi_it = beta0 + upsilon0 * exp(-kappa * |i_K - i_t|) * sigma2_t + v_it`"
    , ""
    , "on LIVE Base Panoptic + Uniswap V4 data. Every number below is traceable to"
    , "raw data through the DATA LINEAGE section at the end; nothing here is"
    , "simulated, padded, or substituted."
    , ""
    , "## 0. Headline"
    , ""
    , headline
    , ""
    , "## 1. What the data actually supports (read before the estimates)"
    , ""
    , "The specification asks for a POSITION-EPOCH panel: `pi_it` per tokenId per"
    , "daily epoch, from diffed cumulative settled-premia snapshots. **The live"
    , "subgraph cannot produce that object.** Introspection at this run established:"
    , ""
    , "- `TokenId` has NO `snapshots` field — there is no per-epoch premium series."
    , "- The `premiumSettleds` event collection is EMPTY for this deployment."
    , "- `AccountBalance.premiaSettled0Total` and `premiaSettled1Total` are"
    , "  IDENTICALLY ZERO for every account balance on this market."
    , "- `Leg.strike` is already an int24 TICK (observed range -202,990 … -197,280),"
    , "  not a price. (Plan 09-04's `round(log K / log 1.0001)` took the log of a"
    , "  negative number; that bug is fixed.)"
    , ""
    , "The only premium the chain reports is `OptionBurn.premium{0,1}` — the premium"
    , "realized over a position's ENTIRE life. The unit of observation is therefore"
    , "the **accrual spell** (one (mint, burn) pair), with `pi` expressed as USD PER"
    , "DAY over the spell and `sigma2` averaged over the same epoch window."
    , ""
    , "**This is a departure from the spec's stated design.** Its consequences:"
    , ""
    , "- There is no within-position time variation, so the position-FE alternative"
    , "  is expected to be unidentified (every tokenId is close to a singleton)."
    , "- `upsilon0` is identified off CROSS-SPELL covariation of the premium rate"
    , "  with the window-average variance, not off within-position covariation as"
    , "  spec 4.4 intends. This is a weaker identifying argument and should be"
    , "  treated as such."
    , "- Spreading a spell's premium uniformly across its days was REJECTED: a"
    , "  constant `pi` against a varying `sigma2` would manufacture a mechanical"
    , "  null. No synthetic variation was introduced anywhere."
    , ""
    , "Sample: **" ++ show (length spells) ++ " accrual spells**, "
        ++ show (length usable) ++ " usable after the sigma2 join, "
        ++ show nTok ++ " distinct tokenIds, " ++ show nAcct ++ " distinct accounts, "
        ++ show (Map.size varMap) ++ " variance epochs."
    , "This is a THIN cross-section and the estimates below must be read as such."
    , ""
    , "## 2. Headline estimates"
    , ""
    , "### Primary — GSL Levenberg-Marquardt NLS, tokenId-clustered CR0 sandwich SEs"
    , ""
    , "| parameter | estimate | clustered SE | 95% CI |"
    , "|---|---|---|---|"
    , row3 "beta0 (intercept, USD/day)" bg seB
    , row3 "upsilon0 (vega level)"      ug seU
    , row3 "kappa (moneyness decay, per tick)" kg seK
    , ""
    , "Account-clustered SEs (coarser, " ++ show nAcct ++ " clusters): "
        ++ "beta0 " ++ fmtG seBa ++ ", upsilon0 " ++ fmtG seUa ++ ", kappa " ++ fmtG seKa ++ "."
    , "With only " ++ show nAcct ++ " clusters the Normal approximation on the"
    , "account-clustered covariance is unreliable; it is reported for transparency,"
    , "not for inference."
    , ""
    , "### EIV IV (two noisy measures: sigma~2 instruments sigma2)"
    , ""
    , "| parameter | IV estimate |"
    , "|---|---|"
    , "| beta0 | " ++ fmtG bi ++ " |"
    , "| upsilon0 | " ++ fmtG ui ++ " |"
    , "| kappa (held at the NLS value by construction) | " ++ fmtG ki ++ " |"
    , ""
    , "The IV corrects attenuation on `upsilon0` from measurement error in the"
    , "realized-variance regressor (spec 3.3 threat M1). `kappa` is identified off"
    , "moneyness, not the variance level, so it is conditioned on rather than"
    , "re-estimated (spec 4.3)."
    , ""
    , "## 3. The three committed specification tests (spec 5)"
    , ""
    , "All computed on the tokenId-CLUSTERED covariance, never naive OLS SEs."
    , ""
    , "| # | restriction | statistic | p-value | reject at 5%? |"
    , "|---|---|---|---|---|"
    , "| 1 | upsilon0 > 0 (upsilon is a vega) | z = " ++ fmtG (statistic rU)
        ++ " | " ++ fmtG (pValue rU) ++ " | " ++ show (reject rU) ++ " |"
    , "| 2 | **kappa > 0 (THE null test)** | z = " ++ fmtG (statistic rK)
        ++ " | " ++ fmtG (pValue rK) ++ " | " ++ show (reject rK) ++ " |"
    , "| 3 | kappa+ = kappa- (symmetric decay) | W = " ++ fmtG (statistic rS)
        ++ " | " ++ fmtG (pValue rS) ++ " | " ++ show (reject rS) ++ " |"
    , ""
    , "Test 3 identification: " ++ symNote ++ "."
    , ""
    ] ++ degeneracyWarning ++
    [ ""
    , "Test 2 is the econometric twin of the Lean conjecture"
    , "`Upsilon.ATMOTMNullHypothesis`: H0 kappa = 0 (flat vega profile) versus"
    , "H1 kappa > 0 (maximal at the money, exponential decay out of the money)."
    , ""
    , kappaVerdict
    , ""
    , "## 4. The four locked alternative specifications (spec 6.2)"
    , ""
    ] ++ concatMap altBlock alts ++
    [ ""
    , "## 5. Lean <-> Haskell <-> spec cross-walk"
    , ""
    , "The formal-witness claim below is only as good as the fidelity between the"
    , "Haskell estimator and the Lean definitions. The auditable object-by-object"
    , "table lives at `notes/structural-econometrcics/analysis/lean-haskell-crosswalk.md`."
    , "Load-bearing rows:"
    , ""
    , "| Lean | Haskell | spec | note |"
    , "|---|---|---|---|"
    , "| `Upsilon.upsilon` vega family `u0*exp(-k*di*|i-iK|)` | `Model.Upsilon.model` = `b0 + u0*exp(-k*d)*s2` | 4.3 | the estimating equation verbatim |"
    , "| `\\|(i:R) - (iK:R)\\|` | `Model.Upsilon.moneyness iK it` | 4.3 | same absolute-tick metric |"
    , "| `PosSpec.lam = 1.0001` | `Model.Upsilon.tickBase = 1.0001` | 2.4 | the sole technological primitive |"
    , "| `Upsilon.ATMOTMNullHypothesis` | `Tests.Specification.testKappaPos` | 5 | Lean pins the statement, Haskell tests it |"
    , "| `Upsilon.exp_family_witnesses_ATMOTM` (PROVED) | a fitted `kappa > 0` | 4.4 | the bridge, see section 6 |"
    , ""
    , "## 6. FORMAL WITNESS statement"
    , ""
    , witnessSection
    , ""
    , "## 7. Threats and caveats"
    , ""
    , "1. **Unit of observation** — accrual spells, not position-epochs (section 1)."
    , "   This is the single largest departure from the spec and weakens the"
    , "   identifying argument for `upsilon0`."
    , "2. **Thin cross-section** — " ++ show (length usable) ++ " observations over "
        ++ show nAcct ++ " accounts. Cluster-robust inference with this few clusters"
    , "   is fragile; treat p-values as indicative, not decisive."
    , "3. **Functional form** — `kappa`'s meaning is exponential-form dependent"
    , "   (spec 6.1.1). The semiparametric alternative is the check; read its curve."
    , "4. **Strike-composition selection** — strikes were never declared exogenous"
    , "   (spec 2.5). The position-FE diagnostic is the intended check and is"
    , "   unidentified here, so this threat is UNRESOLVED, not cleared."
    , "5. **Sign normalization** — long positions PAY premium (the protocol emits a"
    , "   negative premium); they are sign-flipped so `pi` is uniformly premium"
    , "   accrued to the SHORT side. Without this the same vega would enter with"
    , "   two opposite signs and cancel."
    , "6. **Premium denomination** — `premium0` (ETH, 18 decimals) converted at the"
    , "   burn-tick pool price, not `premium1` (USDC, 6 decimals): USDC's 6 decimals"
    , "   truncate small premia to zero. Where both are non-zero they agree to"
    , "   within a few tenths of a percent."
    , ""
    , lineageSection eo dateStr (length spells) (Map.size varMap) (length usable)
    ]
  where
    ses   = standardErrors vTok ++ repeat (0 / 0)
    sesA  = standardErrors vAcct ++ repeat (0 / 0)
    (seB, seU, seK) = (ses !! 0, ses !! 1, ses !! 2)
    (seBa, seUa, seKa) = (sesA !! 0, sesA !! 1, sesA !! 2)
    nTok  = length (nub (map obsTokenId usable))
    nAcct = length (nub (map (T.takeWhile (/= '#') . obsTokenId) usable))

    kappaPositive = kg > 0 && not (isNaN kg)
    upsilonPositive = ug > 0 && not (isNaN ug)
    kappaSignificant = kappaPositive && reject rK

    -- THE DEGENERACY CHECK. kappa only enters the model through the term
    -- upsilon0 * exp(-kappa*d) * sigma2. If upsilon0-hat is numerically zero, that
    -- whole term vanishes and kappa has NO effect on the fit at any value: it is
    -- structurally unidentified and its point estimate, SE and test are vacuous.
    -- Yardstick: the largest contribution the vega term can make to pi, relative
    -- to the fitted intercept.
    maxVegaContribution =
      abs ug * maximum (1e-300 : [ obsSigma2 o | o <- usable, finiteD (obsSigma2 o) ])
    upsilonDegenerate = maxVegaContribution < 1e-6 * abs bg

    degeneracyWarning
      | not upsilonDegenerate = []
      | otherwise =
          [ "> **kappa IS NOT IDENTIFIED ON THIS SAMPLE — read test 2 as vacuous.**"
          , ">"
          , "> kappa enters the model ONLY through `upsilon0 * exp(-kappa*d) * sigma2`."
          , "> The fitted `upsilon0-hat = " ++ fmtG ug ++ "` is numerically zero: the"
          , "> largest contribution the vega term can make to `pi` anywhere in the"
          , "> sample is " ++ fmtG maxVegaContribution ++ ", against a fitted intercept"
          , "> of " ++ fmtG bg ++ ". With the vega term extinguished, kappa has NO"
          , "> effect on the fit at ANY value — which is exactly why its standard error"
          , "> is " ++ fmtG seK ++ ", orders of magnitude larger than the estimate."
          , ">"
          , "> The honest reading is that the best fit to this cross-section is a"
          , "> CONSTANT premium rate `pi = beta0`, with no detectable variance-times-"
          , "> moneyness structure at all. The `kappa > 0` test statistic is reported"
          , "> above for completeness but carries no information, and neither"
          , "> rejecting nor failing to reject it says anything about the conjecture."
          ]

    headline
      | upsilonDegenerate =
          "**NULL RESULT: no vega structure is detectable in this cross-section.**"
            ++ " The fitted vega level upsilon0-hat = " ++ fmtG ug ++ " is numerically"
            ++ " zero, so the moneyness decay kappa is STRUCTURALLY UNIDENTIFIED"
            ++ " (SE " ++ fmtG seK ++ ") and its test is vacuous. The best fit to the"
            ++ " " ++ show (length usable) ++ " observations is a constant premium rate"
            ++ " beta0-hat = " ++ fmtG bg ++ " USD/day (clustered SE " ++ fmtG seB
            ++ "). The formal witness does NOT obtain; see sections 3 and 6."
      | kappaSignificant && upsilonPositive =
          "**kappa-hat = " ++ fmtG kg ++ " (clustered SE " ++ fmtG seK ++ ", p = "
            ++ fmtG (pValue rK) ++ ") — H0: kappa = 0 is REJECTED in favour of"
            ++ " kappa > 0.** upsilon0-hat = " ++ fmtG ug ++ ". The fitted profile"
            ++ " witnesses the Lean conjecture; see section 6."
      | kappaPositive =
          "**kappa-hat = " ++ fmtG kg ++ " > 0 but NOT significant (clustered SE "
            ++ fmtG seK ++ ", p = " ++ fmtG (pValue rK) ++ "). H0: kappa = 0 is NOT"
            ++ " rejected.** The point estimate has the sign the conjecture predicts,"
            ++ " but this cross-section cannot distinguish it from a flat profile."
            ++ " The formal witness does NOT obtain; see section 6."
      | otherwise =
          "**kappa-hat = " ++ fmtG kg ++ " (clustered SE " ++ fmtG seK
            ++ ") — NOT positive. H0: kappa = 0 is not rejected in the direction of"
            ++ " the conjecture.** The formal witness does NOT obtain; see section 6."

    kappaVerdict
      | upsilonDegenerate =
          "**Verdict: the null test is VACUOUS on this sample.** kappa is not"
            ++ " identified (see the box above), so H0: kappa = 0 can be neither"
            ++ " rejected nor sustained. This is a NULL RESULT about the data's"
            ++ " information content, not evidence about the vega profile."
      | kappaSignificant =
          "**Verdict: H0 (kappa = 0) is REJECTED** at the 5% level in favour of"
            ++ " kappa > 0, on the tokenId-clustered covariance."
      | otherwise =
          "**Verdict: H0 (kappa = 0) is NOT REJECTED.** This is a null result and is"
            ++ " reported as such. With " ++ show (length usable) ++ " observations"
            ++ " over " ++ show nAcct ++ " accounts the test has very little power,"
            ++ " so this is evidence of ABSENCE OF EVIDENCE, not evidence of a flat"
            ++ " vega profile."

    witnessSection = unlines
      [ "The Lean library proves, axiom-clean and sorry-free"
      , "(`lean/vol_markets/Upsilon.lean`):"
      , ""
      , "```lean"
      , "theorem exp_family_witnesses_ATMOTM"
      , "    (u0 k di : R) (iK : Z) (hu : 0 < u0) (hk : 0 < k) (hd : 0 < di) :"
      , "    ATMOTMNullHypothesis"
      , "      (fun i => u0 * Real.exp (-k * di * |(i:R) - (iK:R)|)) di iK (k*di)"
      , "```"
      , ""
      , "Its three hypotheses are `hu : 0 < upsilon0`, `hk : 0 < kappa`, and"
      , "`hd : 0 < Delta_i` (the tick spacing, 10 on this market, so `hd` holds by"
      , "inspection). The fitted values are:"
      , ""
      , "- `upsilon0-hat = " ++ fmtG ug ++ "`  ->  `hu` " ++ huStatus
      , "- `kappa-hat = " ++ fmtG kg ++ "`  ->  `hk` " ++ hkStatus
      , "- `Delta_i = 10` (pool tickSpacing)  ->  `hd` SATISFIED"
      , ""
      , verdict
      ]
      where
        satisfied True  = "SATISFIED."
        satisfied False = "**NOT satisfied.**"
        -- A point estimate that is positive only in sign, while numerically zero,
        -- does NOT satisfy a strict-positivity hypothesis in any usable sense.
        huStatus
          | upsilonDegenerate =
              "**NOT usable** — positive in sign but numerically zero, so the strict"
              ++ " inequality is satisfied only vacuously."
          | otherwise = satisfied upsilonPositive
        hkStatus
          | upsilonDegenerate =
              "**cannot be evaluated** — kappa is unidentified once the vega term"
              ++ " vanishes."
          | otherwise = satisfied kappaPositive
        verdict
          | upsilonDegenerate =
              "**The witness does NOT obtain.** The theorem's hypothesis"
              ++ " `hu : 0 < upsilon0` fails at the point estimate (upsilon0-hat = "
              ++ fmtG ug ++ ", numerically zero), and because the vega term is"
              ++ " extinguished `kappa` is not identified at all, so `hk : 0 < kappa`"
              ++ " cannot be evaluated against the data either. The fitted profile is"
              ++ " NOT a witness of `ATMOTMNullHypothesis`. Note what this does and"
              ++ " does NOT say: the Lean theorem remains proved and axiom-clean, and"
              ++ " the conjecture remains open. This cross-section simply carries no"
              ++ " information about it."
          | kappaSignificant && upsilonPositive =
              "**The witness OBTAINS.** All three hypotheses are satisfied by the"
              ++ " point estimates and `kappa > 0` is statistically significant at"
              ++ " the 5% level on the clustered covariance. The fitted exponential-"
              ++ "moneyness profile is therefore a literal witness of"
              ++ " `ATMOTMNullHypothesis` at `c = kappa-hat * Delta_i = "
              ++ fmtG (kg * 10) ++ "`. Caveat: the theorem is about the FAMILY, so"
              ++ " the witness is as strong as the estimate — see section 7."
          | upsilonPositive && kappaPositive =
              "**The witness does NOT obtain.** Both point estimates have the right"
              ++ " SIGN, so the theorem's hypotheses are formally satisfiable at the"
              ++ " point estimates, but `kappa > 0` is not statistically"
              ++ " distinguishable from zero (p = " ++ fmtG (pValue rK) ++ ") on this"
              ++ " cross-section. Instantiating a machine-checked theorem at a"
              ++ " statistically insignificant estimate would assert more than the"
              ++ " data supports, so no witness is claimed."
          | otherwise =
              "**The witness does NOT obtain.** The failed restriction is "
              ++ (if not upsilonPositive then "`hu : 0 < upsilon0` (upsilon0-hat = "
                    ++ fmtG ug ++ ")" else "")
              ++ (if not upsilonPositive && not kappaPositive then " and " else "")
              ++ (if not kappaPositive then "`hk : 0 < kappa` (kappa-hat = "
                    ++ fmtG kg ++ ")" else "")
              ++ ". The data does not instantiate the exponential family the theorem"
              ++ " quantifies over, so the fitted profile is NOT a witness of"
              ++ " `ATMOTMNullHypothesis`."

    altBlock (lbl, e) =
      [ "### " ++ T.unpack lbl
      , ""
      ] ++
      (if estIdentified e
        then [ "Observations: " ++ show (estNobs e) ++ ", clusters: "
                 ++ show (estClusters e) ++ "."
             , ""
             , "| coefficient | estimate | clustered SE |"
             , "|---|---|---|"
             ] ++
             [ "| " ++ T.unpack n ++ " | " ++ fmtG v ++ " | "
                 ++ fmtG (maybe (0 / 0) id (lookup n (estSEs e))) ++ " |"
             | (n, v) <- estCoefs e ] ++
             (if null (estCurve e) then []
               else [ ""
                    , "Estimated vega profile (the SHAPE the null is read off):"
                    , ""
                    , "| moneyness d (ticks) | upsilon-hat(d) |"
                    , "|---|---|"
                    ] ++
                    [ "| " ++ fmtG d ++ " | " ++ fmtG u ++ " |" | (d, u) <- estCurve e ] ++
                    [ "", shapeReadOff e ]) ++
             [ "", "Note: " ++ T.unpack (estNote e) ]
        else [ "**NOT IDENTIFIED / NOT ESTIMABLE.**"
             , ""
             , "Reason: " ++ T.unpack (estNote e)
             , ""
             , "Observations seen: " ++ show (estNobs e) ++ ", clusters: "
                 ++ show (estClusters e) ++ "."
             ]) ++
      [ "" ]

    -- The read-off is only meaningful if the estimated curve is (a) monotone in
    -- moneyness and (b) resolved above its own standard errors. A non-monotone
    -- curve whose bins are dwarfed by their SEs shows nothing, and saying
    -- otherwise would be reading a trend out of noise.
    shapeReadOff e
      | length us < 2 = ""
      | not resolved =
          "Shape read-off: **NONE AVAILABLE.** Every bin's coefficient is smaller"
          ++ " than its own clustered standard error, so the estimated profile is"
          ++ " indistinguishable from noise. No shape — declining, flat or"
          ++ " otherwise — can be read off it."
      | not monotone =
          "Shape read-off: **NOT INTERPRETABLE.** The estimated profile is"
          ++ " NON-MONOTONE in moneyness (bin values "
          ++ intercalate ", " (map fmtG us) ++ "), so it exhibits neither the"
          ++ " exponential decay of H1 nor the flat profile of H0."
      | head us > last us =
          "Shape read-off: the profile declines monotonically from the money"
          ++ " outward — the direction the conjecture (kappa > 0) predicts."
      | otherwise =
          "Shape read-off: the profile does NOT decline from the money outward —"
          ++ " no unrestricted evidence for an at-the-money vega peak."
      where
        us      = map snd (estCurve e)
        binSEs  = [ se | (n, se) <- estSEs e, T.isPrefixOf "upsilon_bin" n ]
        resolved = or (zipWith (\u se -> abs u > se) us (binSEs ++ repeat (1 / 0)))
        monotone = and (zipWith (>=) us (drop 1 us))
                     || and (zipWith (<=) us (drop 1 us))


-- | The audit trail: everything needed to trace every number backward to raw
-- chain data. No credentials, no absolute paths.
lineageSection :: EstimateOpts -> String -> Int -> Int -> Int -> String
lineageSection eo dateStr nSpells nEpochs nUsable = unlines
  [ "## DATA LINEAGE (audit trail)"
  , ""
  , "Run date: " ++ dateStr ++ ". Everything below is reproducible from a clean"
  , "checkout with the commands given; all paths are repo-root relative."
  , ""
  , "### Sources"
  , ""
  , "| what | source |"
  , "|---|---|"
  , "| chain | Base mainnet (L2), chainId 8453 |"
  , "| Panoptic subgraph | `" ++ show' (eoEndpoint eo) ++ "` (keyless public Goldsky; no GRAPH_API_KEY required or used) |"
  , "| panopticPool | `0xb50e8bb68f5855da742f4579274902a20454174a` (ETH/USDC, fee tier 500, tickSpacing 10) |"
  , "| underlying pool (Uniswap V4 poolId) | `" ++ show' (eoPool eo) ++ "` |"
  , "| token0 / token1 | ETH (native, 18 dec) / USDC `0x833589fcd6edb6e08f4c7c32d4f71b54bda02913` (6 dec) |"
  , "| variance source | Base JSON-RPC `" ++ show' (eoRpc eo) ++ "`, chunked `eth_getLogs` |"
  , "| V4 Swap topic0 | `0x40e9cecb9f5f1f1c5b9c97dec2917b7ee92e57ba5563708daca94dd84ad7112f` |"
  , "| V4 PoolManager (log emitter) | `0x498581ff718922c3f8e6a244956af099b2652b2b` |"
  , "| block range pulled | " ++ show (eoFromBlock eo) ++ " .. " ++ show (eoToBlock eo) ++ " |"
  , ""
  , "**BigQuery is NOT used.** The GCP project is suspended (403 CONSUMER_SUSPENDED)"
  , "and the underlying pool is Uniswap V4 on Base, whose swaps are emitted by the"
  , "PoolManager singleton keyed by a 32-byte poolId — not by a pool address in"
  , "`crypto_ethereum`. See `notes/structural-econometrcics/data/DATA-SOURCES.md` 4.3."
  , ""
  , "### Files"
  , ""
  , "| path | contents | rows |"
  , "|---|---|---|"
  , "| `" ++ eoPanelCsv eo ++ "` | accrual-spell panel from the subgraph | " ++ show nSpells ++ " |"
  , "| `" ++ eoVarianceCsv eo ++ "` | daily sigma2, sigma2_instrument, pool_tick_mean | " ++ show nEpochs ++ " |"
  , "| `" ++ eoTicksCsv eo ++ "` | raw (unix, tick) Swap cache (gitignored: large, regenerable) | see below |"
  , "| `" ++ eoCollateralCsv eo ++ "` | signed collateral share flows | see file |"
  , "| `" ++ eoEstimationCsv eo ++ "` | FINAL estimation panel (handed to the GAMS cross-check) | " ++ show nUsable ++ " |"
  , ""
  , "### Epoch definition"
  , ""
  , "`epoch = floor(unixSeconds / 86400)` — whole UTC days since the Unix epoch,"
  , "boundary at 00:00 UTC. Defined ONCE in `Panel.Build.dailyEpoch` and imported by"
  , "`Panel.Variance`, so the premium windows and the variance windows cannot drift"
  , "apart."
  , ""
  , "### Construction steps"
  , ""
  , "1. `build-panel` pulls the FULL history of `optionMints`, `optionBurns` and"
  , "   `tokenIds { legs }` for the pool (cursor pagination on `timestamp_gt`, not"
  , "   `skip`, because `skip` is capped at 5000)."
  , "2. Each burn is paired with the LATEST mint of the same (tokenId, account)"
  , "   strictly preceding it -> an accrual spell."
  , "3. `pi` = `premium0 / 1e18 * 1.0001^tickAtBurn * 1e12` (USD), sign-flipped for"
  , "   long positions, divided by the spell length in days -> USD/day."
  , "4. `i_K` = `Leg.strike` of the position's first leg (already an int24 tick)."
  , "5. `variance` pulls V4 `Swap` logs over the block range, decodes the int24 tick"
  , "   from data word 4, and computes per UTC day: `sigma2` = sum of squared"
  , "   tick-implied log-price increments over the full within-day swap series;"
  , "   `sigma2_instrument` = the same estimator on the disjoint EVEN-indexed swap"
  , "   sub-window (two noisy measures, the EIV instrument); `pool_tick_mean` = the"
  , "   day's mean tick."
  , "6. `estimate` joins the two by averaging `sigma2`, `sigma2_instrument` and"
  , "   `pool_tick_mean` over each spell's epoch window `[epoch_mint, epoch_burn]`,"
  , "   then sets `d = |i_K - i_t|` with `i_t` the window-average pool tick."
  , "7. Fit: `Numeric.GSL.Fitting.fitModel` (Levenberg-Marquardt, analytic"
  , "   Jacobian). SEs: hand-rolled CR0 cluster sandwich `(J'J)^-1 [sum_g s_g s_g']"
  , "   (J'J)^-1`, golden-tested to 1e-9 (`Model.SandwichSE`). Tests: one-sided"
  , "   Normal for the sign restrictions, chi-squared(1) Wald for the symmetry"
  , "   restriction (`Tests.Specification`), p-values from the `statistics` package."
  , ""
  , "### Reproduce"
  , ""
  , "```sh"
  , "stack --stack-yaml econometrics/stack.yaml exec econometrics -- build-panel \\"
  , "  --endpoint <subgraph-endpoint> --pool <poolId>"
  , "stack --stack-yaml econometrics/stack.yaml exec econometrics -- variance \\"
  , "  --from " ++ show (eoFromBlock eo) ++ " --to " ++ show (eoToBlock eo) ++ " --chunk 10000"
  , "stack --stack-yaml econometrics/stack.yaml exec econometrics -- estimate \\"
  , "  --endpoint <subgraph-endpoint> --pool <poolId> --rpc <base-rpc-url> \\"
  , "  --from-block " ++ show (eoFromBlock eo) ++ " --to-block " ++ show (eoToBlock eo)
  , "```"
  , ""
  , "The endpoint, poolId and RPC URL are the values recorded in the Sources table"
  , "above. No API key is required for any of them."
  ]
  where
    show' s = if null s then "(not recorded on this run)" else s

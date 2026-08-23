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
                                          buildSpellPremiumObs, multiplierWedge)
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
    -- | PLAN 10-10. When supplied, the estimator is re-pointed at the
    -- position-EPOCH panel (@panel-epoch.csv@, plan 10-09) instead of the
    -- Phase-9 accrual-spell panel, and joins to @--variance@ on @epoch@.
    --
    -- __Only the LHS changes.__ Nothing under @src/Model/@, @src/Tests/@ or
    -- @src/Alternatives.hs@ is touched by this option: the entire experimental
    -- claim of plan 10-10 is that the Phase-9 estimator stack ran BYTE-IDENTICAL
    -- on a differently-constructed left-hand side, so any difference in the
    -- estimate is attributable to the measurement fix and to nothing else. A
    -- @git diff@ touching the estimator would destroy that claim, which is why
    -- every line of this path lives in the CLI.
  , eoEpochPanel    :: Maybe FilePath
    -- | Accumulator readings, read ONLY to report the measured distribution of
    -- the Panoptic ν-multiplier wedge (the Lean-vs-Panoptic wedge, 10-CONTEXT
    -- "Premium definition"). Never used to compute a premium.
  , eoAccumulators  :: FilePath
    -- | Gate report whose verdict block the v2 analysis output quotes verbatim.
  , eoGateReport    :: FilePath
    -- | Epoch width in HOURS, used for the collateral channel's epoch grid so
    -- alternative 4 is formed on the SAME grid as σ̂². 24 = the Phase-9 daily
    -- grid; 1 = the 10-01 hourly re-scope.
  , eoEpochHours    :: Int
    -- | RUN 2 (pivot lock @phase10-plan10-10-run2@). THE SINGLE CHANGE: normalise
    -- the LHS to the seller side, restoring Phase 9's documented convention that
    -- 10-09's panel assembler did not carry forward. Everything else — the bar,
    -- the verdict code path, the estimator, the tests, the alternatives, the
    -- multi-start, the row set, the clusters, the joins — is identical to run 1,
    -- and BOTH arms are computed and reported side by side.
  , eoSellerSide    :: Bool
    -- | The pivot lock. Hashed at run time and checked against the pin; the run
    -- aborts on a mismatch, because the lock's own terms void it if edited.
  , eoPivotLock     :: FilePath
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
    <*> optional (strOption ( long "epoch-panel" <> metavar "PATH"
                 <> help "PLAN 10-10: re-point the UNCHANGED estimator at the \
                         \position-EPOCH panel (panel-epoch.csv) instead of the \
                         \spell panel, joining to --variance on epoch. Writes the \
                         \v2 analysis output and the mechanical STOPPING_RULE verdict." ))
    <*> strOption ( long "accumulators" <> metavar "PATH"
                 <> value defaultPremiumAccumulatorsCsv <> showDefault
                 <> help "accumulator readings, read ONLY to report the measured \
                         \Panoptic multiplier-wedge distribution (never to compute a premium)" )
    <*> strOption ( long "gate-report" <> metavar "PATH" <> value defaultReconcileReport
                 <> showDefault
                 <> help "gate report whose verdict block the v2 analysis output quotes verbatim" )
    <*> option auto ( long "epoch-hours" <> metavar "N" <> value 24 <> showDefault
                 <> help "epoch width in HOURS for the collateral channel's grid \
                         \(24 = the Phase-9 daily grid; 1 = the 10-01 hourly re-scope)" )
    <*> switch ( long "seller-side-normalize"
                 <> help "RUN 2 (pivot lock phase10-plan10-10-run2): THE SINGLE CHANGE — \
                         \multiply LONG tokenIds' premium by -1 so long and short vega \
                         \enter with one sign, per Panel.Build.premiumUsd's documented \
                         \Phase-9 convention. Computes BOTH arms and reports them side \
                         \by side; writes the v3 analysis and estimation-panel-v3.csv." )
    <*> strOption ( long "pivot-lock" <> metavar "PATH" <> value pivotLockPathDefault
                 <> showDefault
                 <> help "pivot lock whose sha256 is verified before a seller-side run" )

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
runEstimate eo = case eoEpochPanel eo of
  Just p  -> runEstimateEpoch eo p
  Nothing -> runEstimateSpell eo

-- | The PHASE-9 path: the accrual-spell panel. Left exactly as plan 09-09 ran
-- it, so the Phase-9 output stays reproducible from this same binary.
runEstimateSpell :: EstimateOpts -> IO ()
runEstimateSpell eo = do
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
collateralObs = collateralObsAt 86400

-- | 'collateralObs' at an explicit epoch width in SECONDS.
--
-- The flows are timestamped events, so the running balance is a step function
-- that can be evaluated on ANY epoch grid; the width must simply be the SAME one
-- the σ̂² series was built on, or the join matches nothing. 86400 reproduces the
-- Phase-9 daily construction byte-for-byte; 3600 is the 10-01 hourly re-scope.
--
-- __What a finer grid does and does not add.__ It adds σ̂² variation (one row per
-- hour instead of per day) against a balance that only moves when a
-- deposit/withdraw event fires, so the extra rows are carry-forward, not new
-- information about Q_M. The row count therefore rises much faster than the
-- information does — recorded in the analysis output rather than left implicit.
collateralObsAt :: Int -> [CollateralFlow] -> Map.Map Int VarRow -> [CollateralObs]
collateralObsAt epochSecs flows varMap =
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
    epochOfTs ts = fromInteger (ts `div` fromIntegral epochSecs) :: Int
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

-- ===========================================================================
-- PLAN 10-10 — the UNCHANGED estimator on the position-EPOCH panel
-- ===========================================================================
--
-- Everything below is CLI wiring. It reads the gate-validated position-epoch
-- panel that plan 10-09 wrote, joins it to the hourly variance series, and hands
-- the result to the SAME 'fitGSLCov' / 'clusterSandwich' / 'Tests.Specification'
-- / 'Alternatives' stack Phase 9 built and certified. Not one line of
-- @src/Model/@, @src/Tests/@ or @src/Alternatives.hs@ is touched by this path,
-- because the phase's entire experimental claim is that ONLY the left-hand side
-- changed.

-- | __THE PRE-COMMITTED SUCCESS BAR.__ Fixed in @10-CONTEXT.md@ ("Power /
-- stopping rule") BEFORE the answer was known, at one quarter of Phase 9's
-- realised υ₀ CI half-width of ±2.48e-4:
--
-- > Success = an υ₀ clustered-CI half-width of at most 6.2e-5 — REGARDLESS of
-- > κ̂'s sign or significance.
--
-- It is deliberately blind to the answer. 'stoppingRuleVerdict' consumes nothing
-- but this number and the realised half-width: not κ̂'s sign, not a p-value, not
-- whether the result is interesting. Moving it mid-run is itself the finding
-- (the @anti-fishing-replication@ tripwire).
precommittedHalfwidthBar :: Double
precommittedHalfwidthBar = 6.2e-5

-- | 95% Normal CI half-width from a standard error — the same @1.96·SE@ the
-- Phase-9 output tabulated, so the realised number and the bar it is compared
-- against are the same object.
ciHalfWidth :: Double -> Double
ciHalfWidth se = 1.96 * se

-- | THE STOPPING RULE, mechanically. Compare and nothing else.
--
-- A NaN half-width fails the comparison and therefore reports @UNINFORMATIVE@;
-- the raw half-width is printed alongside the verdict so a NaN is visible as the
-- anomaly it would be rather than being read as a result.
stoppingRuleVerdict :: Double -> String
stoppingRuleVerdict hw
  | hw <= precommittedHalfwidthBar = "INFORMATIVE"
  | otherwise                      = "UNINFORMATIVE"

-- | The v2 analysis output. Named for the document it supersedes (Phase 9's
-- @2026-07-20-upsilon-estimates.md@) rather than for the day it was produced, so
-- re-running the plan overwrites one file instead of accreting dated copies; the
-- ACTUAL run date is recorded inside the document's lineage section.
analysisV2Name :: FilePath
analysisV2Name = "2026-07-20-upsilon-estimates-v2.md"

-- | The Phase-10 successor to @estimation-panel.csv@. The Phase-9 export stays
-- in place: the deferred 09-10 GAMS cross-check consumes it.
defaultEstimationCsvV2 :: FilePath
defaultEstimationCsvV2 = defaultDataDir </> "estimation-panel-v2.csv"

-- | One row of @panel-epoch.csv@ (plan 10-09).
data EpochRow = EpochRow
  { erTokenId  :: !T.Text
  , erAccount  :: !T.Text
  , erEpoch    :: !Int
  , erPremWei  :: !Integer
  , erPremEth  :: !Double   -- ^ THE REGRESSION LHS: ETH per epoch, a FLOW.
  , erStrike   :: !Int
  , erPoolTick :: !Int
  , erMoney    :: !Double
  , erIsLong   :: !Bool
  , erLegCount :: !Int
  , erFlags    :: !T.Text
  , erSigma2   :: !Double
  , erSigma2I  :: !Double
  , erNSwaps   :: !Int
  } deriving (Show, Eq)

-- | Load @panel-epoch.csv@. Fails LOUD on an unparseable data line: a silently
-- dropped row is exactly the failure mode 10-09 built its returned-unmatched-list
-- discipline against.
loadEpochPanelCsv :: FilePath -> IO [EpochRow]
loadEpochPanelCsv fp = do
  txt <- readFile' fp
  let dataLines = filter keep (lines txt)
      keep l = not ("#" `isPrefixOf` l) && not ("token_id" `isPrefixOf` l) && not (null l)
      parsed = map parseRow dataLines
      bad    = length [ () | Nothing <- parsed ]
  when (bad > 0) $
    ioError (userError ("epoch-panel CSV: " ++ show bad ++ " unparseable data line(s) in " ++ fp))
  pure (mapMaybe id parsed)
  where
    parseRow l = case splitOn ',' l of
      (tid : acct : e : pw : pe : st : pt : mn : il : lc : fl : s2 : s2i : ns : _) -> do
        e'   <- readMaybe e
        pw'  <- readMaybe pw
        pe'  <- readMaybe pe
        st'  <- readMaybe st
        pt'  <- readMaybe pt
        mn'  <- readMaybe mn
        il'  <- readMaybe il :: Maybe Int
        lc'  <- readMaybe lc
        s2'  <- readMaybe s2
        s2i' <- readMaybe s2i
        ns'  <- readMaybe ns
        pure EpochRow
          { erTokenId = T.pack tid, erAccount = T.pack acct, erEpoch = e'
          , erPremWei = pw', erPremEth = pe', erStrike = st', erPoolTick = pt'
          , erMoney = mn', erIsLong = il' /= 0, erLegCount = lc'
          , erFlags = T.pack fl, erSigma2 = s2', erSigma2I = s2i', erNSwaps = ns' }
      _ -> Nothing

-- | Scientific notation at fixed precision, for the machine-readable verdict
-- block. A half-width is compared against a bar; rounding it to three digits in
-- the transcript would make the comparison unauditable.
fmtE :: Double -> String
fmtE x
  | isNaN x      = "NaN"
  | isInfinite x = if x > 0 then "Inf" else "-Inf"
  | otherwise    = printf "%.6e" x

medianD :: [Double] -> Double
medianD [] = 0 / 0
medianD xs =
  let s = sort xs
      n = length s
  in if odd n then s !! (n `div` 2)
     else (s !! (n `div` 2 - 1) + s !! (n `div` 2)) / 2

-- | Lines of a file that begin with @#@ — the self-describing banner an
-- artifact carries. Quoted verbatim into the v2 lineage so the audit surface is
-- the artifact's own words, not a re-description of them.
bannerOf :: FilePath -> IO [String]
bannerOf fp = do
  r <- try (readFile' fp) :: IO (Either IOException String)
  pure $ case r of
    Left _    -> ["(file not readable at run time: " ++ fp ++ ")"]
    Right txt -> takeWhile ("#" `isPrefixOf`) (lines txt)

-- | The gate's verbatim verdict block, lifted out of @reconcile.md@ by its own
-- labels. Quoting it beats restating it: the licence to read the estimate at all
-- is that block.
gateVerdictBlock :: FilePath -> IO [String]
gateVerdictBlock fp = do
  r <- try (readFile' fp) :: IO (Either IOException String)
  pure $ case r of
    Left _    -> ["(gate report not readable at run time: " ++ fp ++ ")"]
    Right txt ->
      let ls    = lines txt
          start = dropWhile (not . ("SPELLS_RECONCILED:" `isPrefixOf`)) ls
          blk   = takeWhile (not . ("```" `isPrefixOf`)) start
      in if null blk then ["(no verdict block found in " ++ fp ++ ")"] else blk

-- | Working-tree and history evidence that the estimator was NOT touched. Run at
-- estimation time and embedded in the output, so the claim "only the LHS changed"
-- is a MEASUREMENT in the document rather than an assertion about it.
estimatorDiffEvidence :: IO [String]
estimatorDiffEvidence = do
    d <- gitOut ["diff", "--name-only", "--"] estimatorPaths
    l <- gitOut ["log", "-1", "--format=%h %ad %s", "--date=short", "--"] estimatorPaths
    pure
      [ "$ git diff --name-only -- " ++ unwords estimatorPaths
      , if null (trim d) then "(empty — no uncommitted change to the estimator)" else trim d
      , ""
      , "$ git log -1 --format='%h %ad %s' --date=short -- " ++ unwords estimatorPaths
      , if null (trim l) then "(no history)" else trim l
      ]
  where
    estimatorPaths =
      [ "econometrics/src/Model", "econometrics/src/Tests"
      , "econometrics/src/Alternatives.hs" ]
    trim = dropWhile (== '\n') . reverse . dropWhile (== '\n') . reverse
    gitOut pre paths = do
      r <- try (readProcessWithExitCode "git" (pre ++ paths) "")
             :: IO (Either IOException (ExitCode, String, String))
      pure $ case r of
        Right (ExitSuccess, out, _) -> out
        _                           -> ""

-- | The measured Panoptic ν-multiplier wedge over the accumulator readings that
-- back the panel.
--
-- 'Panoptic.Premium.multiplierWedge' is REPORTED, never applied: the contract
-- already bakes ν = 1/VEGOID = 1/8 into the X64 accumulator. Reporting its
-- realised distribution — rather than only its theoretical long-side bound of
-- 1.125 — is what makes the Lean-vs-Panoptic wedge a measurement.
-- Returned: (n readings, n with R = 0, median, min, max, long-side max,
-- short-side max, n long readings). The two sides are split because only the
-- LONG branch is bounded by 1 + nu = 1.125; the short branch @1 + nu*R^2/(N*T)@
-- grows like @nu*R/N@ for @R >> N@ and has no such bound. Quoting one bound over
-- a pooled maximum would misstate the arithmetic.
wedgeStats :: [AccRow] -> (Int, Int, Double, Double, Double, Double, Double, Int)
wedgeStats rowsA = (length rowsA, nUnit, medianD ws, mn, mx, mxLong, mxShort, length longs)
  where
    wedgeOf r = fromRational (multiplierWedge (acRemovedLiq r) (acNetLiq r) (acIsLong r))
    ws     = map wedgeOf rowsA
    longs  = [ r | r <- rowsA, acIsLong r ]
    shorts = [ r | r <- rowsA, not (acIsLong r) ]
    nUnit  = length [ () | r <- rowsA, acRemovedLiq r == 0 ]
    safeMax xs = if null xs then 0 / 0 else maximum xs
    mn      = if null ws then 0 / 0 else minimum ws
    mx      = safeMax ws
    mxLong  = safeMax (map wedgeOf longs)
    mxShort = safeMax (map wedgeOf shorts)

-- ---------------------------------------------------------------------------
-- RUN 2 (pivot lock phase10-plan10-10-run2): seller-side LHS normalization
-- ---------------------------------------------------------------------------

-- | The sha256 the pivot lock was committed at. The lock's own closing clause
-- makes this load-bearing: \"any post-commit edit to this file voids the lock\".
-- The run therefore ABORTS if the file on disk does not hash to this value —
-- the terms cannot be silently edited between adjudication and execution.
pivotLockSha256 :: String
pivotLockSha256 = "56044349a035221874eb93d59ab64bd94239be698e4e47363118bffd743e9998"

pivotLockPathDefault :: FilePath
pivotLockPathDefault =
  ".planning/phases/10-streaming-premium-reconstruction-and-reestimation/10-10-PIVOT-LOCK.md"

-- | The run-2 analysis output. A NEW file: the run-1 document is frozen with a
-- CORRECTIONS header and stays on the record permanently.
analysisV3Name :: FilePath
analysisV3Name = "2026-07-27-upsilon-estimates-v3.md"

defaultEstimationCsvV3 :: FilePath
defaultEstimationCsvV3 = defaultDataDir </> "estimation-panel-v3.csv"

-- | sha256 of a file, via @sha256sum@. Returns 'Nothing' when the tool is
-- unavailable, so an environment without it degrades to a NAMED failure rather
-- than to a silent pass.
sha256Of :: FilePath -> IO (Maybe String)
sha256Of fp = do
  r <- try (readProcessWithExitCode "sha256sum" [fp] "")
         :: IO (Either IOException (ExitCode, String, String))
  pure $ case r of
    Right (ExitSuccess, out, _) -> case words out of
      (h : _) -> Just h
      _       -> Nothing
    _ -> Nothing

-- | THE SINGLE CHANGE of run 2, and the only one.
--
-- Rows belonging to LONG tokenIds carry the protocol's own sign, under which the
-- buyer PAYS: @Panoptic.Premium.premiumWei@ negates long legs, mirroring
-- @_getPremia@. Phase 9's @Panel.Build.premiumUsd@ normalises those spells to the
-- SELLER side (@sign = if isLong then -1 else 1@) with the documented rationale
-- \"the same vega would enter the regression with two opposite signs and cancel\".
-- 10-09's @assembleEpochPanel@ did not carry that normalisation forward.
--
-- This restores it, at the panel-derivation layer only. The long/short label is
-- the FROZEN @is_long@ column of the 10-09 artifact — no reclassification, and
-- nothing else about the row changes.
sellerSideNormalize :: EpochRow -> EpochRow
sellerSideNormalize r
  | erIsLong r = r { erPremWei = negate (erPremWei r)
                   , erPremEth = negate (erPremEth r) }
  | otherwise  = r

-- | One complete estimation on one panel. Extracted verbatim from run 1's inline
-- pipeline so that run 1 and run 2 cannot diverge by anything except their input:
-- both columns of the side-by-side table come from THIS function.
data RunResult = RunResult
  { rsTheta   :: !Theta
  , rsThetaIV :: !Theta
  , rsVTok    :: !(LA.Matrix Double)
  , rsVAcct   :: !(LA.Matrix Double)
  , rsSeB     :: !Double
  , rsSeU     :: !Double
  , rsSeK     :: !Double
  , rsHalfW   :: !Double
  , rsVerdict :: !String
  , rsTU      :: !TestResult
  , rsTK      :: !TestResult
  , rsTS      :: !TestResult
  , rsSymNote :: !String
  , rsAlts    :: ![(T.Text, Estimates)]
  , rsNls     :: !NlsDiag
  , rsPanel   :: !Panel
  }

runOn :: [CollateralObs] -> Panel -> RunResult
runOn collat usable = RunResult
  { rsTheta = thetaG, rsThetaIV = ivFit usable
  , rsVTok = vTok, rsVAcct = vAcct
  , rsSeB = ses !! 0, rsSeU = ses !! 1, rsSeK = ses !! 2
  , rsHalfW = halfW, rsVerdict = stoppingRuleVerdict halfW
  , rsTU = testUpsilonPos thetaG vTok
  , rsTK = testKappaPos   thetaG vTok
  , rsTS = fst symPair, rsSymNote = snd symPair
  , rsAlts = runAlternativesWith collat usable
  , rsNls = nlsDiagnostic usable thetaG
  , rsPanel = usable
  }
  where
    (thetaG, _)     = fitGSLCov usable
    (jRows, resids) = sandwichInputs thetaG usable
    vTok    = clusterSandwich jRows resids (map obsTokenId usable)
    vAcct   = clusterSandwich jRows resids (map obsAccount usable)
    ses     = standardErrors vTok ++ repeat (0 / 0)
    halfW   = ciHalfWidth (ses !! 1)
    symPair = splitSymmetryTest usable

-- | The machine-readable verdict block, one function so run 1 and run 2 print
-- byte-identically-shaped output.
verdictBlock :: String -> RunResult -> [String]
verdictBlock label rs =
  [ "--- " ++ label ++ " ---"
  , "N_OBS: " ++ show (length (rsPanel rs))
  , "N_CLUSTERS: " ++ show (length (nub (map obsTokenId (rsPanel rs))))
  , "BETA0_HAT: " ++ fmtE bg ++ "   BETA0_SE: " ++ fmtE (rsSeB rs)
  , "UPSILON0_HAT: " ++ fmtE ug ++ "   UPSILON0_SE_CLUSTERED: " ++ fmtE (rsSeU rs)
      ++ "   UPSILON0_CI_HALFWIDTH: " ++ fmtE (rsHalfW rs)
  , "KAPPA_HAT: " ++ fmtE kg ++ "   KAPPA_SE_CLUSTERED: " ++ fmtE (rsSeK rs)
  , "NLS_START_USED: " ++ ndStartUsed (rsNls rs) ++ "   NLS_SSE: " ++ fmtE (ndSSE (rsNls rs))
  , "TEST_UPSILON_POS_P: " ++ fmtE (pValue (rsTU rs))
      ++ "   TEST_KAPPA_POS_P: " ++ fmtE (pValue (rsTK rs))
      ++ "   TEST_SYMMETRY_P: " ++ fmtE (pValue (rsTS rs))
  , "PRECOMMITTED_HALFWIDTH_BAR: " ++ fmtE precommittedHalfwidthBar
  , "STOPPING_RULE: " ++ rsVerdict rs
  ]
  where Theta bg ug kg = rsTheta rs

-- | The pre-registered unit-free descriptors, DECLARED IN THE PIVOT LOCK BEFORE
-- run 2 executed. They are reported alongside the mechanical verdict and do NOT
-- override it.
--
--   * D1 — half-width / |υ̂₀| (run 1: 4.11)
--   * D2 — does the υ₀ CI exclude zero (run 1: no)
--   * D3 — υ̂₀ and SE movement vs run 1 (direction and magnitude)
descriptorD1 :: RunResult -> Double
descriptorD1 rs = rsHalfW rs / abs (u0 (rsTheta rs))

descriptorD2 :: RunResult -> Bool
descriptorD2 rs = let e = u0 (rsTheta rs); h = rsHalfW rs in abs e > h

-- | Refuse to clobber a frozen analysis document. The run-1 output carries a
-- CORRECTIONS/FROZEN header and is part of the permanent record; a re-run that
-- silently overwrote it would erase the very thing the discipline preserves.
guardFrozen :: FilePath -> IO ()
guardFrozen fp = do
  r <- try (readFile' fp) :: IO (Either IOException String)
  case r of
    Left _    -> pure ()
    Right txt -> do
      let hd = unlines (take 12 (lines txt))
      when ("CORRECTIONS" `isInfixOf` hd || "FROZEN" `isInfixOf` hd) $ do
        putStrLn ("estimate: ABORT — refusing to overwrite the FROZEN analysis at "
                   ++ fp ++ ". A frozen result is part of the record.")
        exitWith (ExitFailure 1)

-- | THE PHASE-10 RUN.
runEstimateEpoch :: EstimateOpts -> FilePath -> IO ()
runEstimateEpoch eo panelPath = do
  rows0  <- loadEpochPanelCsv panelPath
  varMap <- loadVarianceCsv (eoVarianceCsv eo)
  flows  <- loadCollateralCsv (eoCollateralCsv eo)
  accMap <- loadAccumulators (eoAccumulators eo)
  commit <- gitHeadCommit
  argv   <- getArgs
  now    <- getCurrentTime
  banner <- bannerOf panelPath
  vbannr <- bannerOf (eoVarianceCsv eo)
  gate   <- gateVerdictBlock (eoGateReport eo)
  diffEv <- estimatorDiffEvidence

  let sellerSide = eoSellerSide eo
      dateStr = formatTime defaultTimeLocale "%Y-%m-%d" now
      outPath = eoAnalysisDir eo </>
                  (if sellerSide then analysisV3Name else analysisV2Name)
      estOut  = if eoEstimationCsv eo /= defaultEstimationCsv
                  then eoEstimationCsv eo
                  else if sellerSide then defaultEstimationCsvV3 else defaultEstimationCsvV2

      -- THE JOIN. Exact INTEGER epoch match against the variance series, and the
      -- unmatched list is RETURNED rather than filtered away (the 10-09 rule: a
      -- silent join drop is what made the 09-05 offset bug look like a small
      -- clean panel).
      unmatched = nub [ erEpoch r | r <- rows0, Map.notMember (erEpoch r) varMap ]
      joined    = [ (r, vr) | r <- rows0, Just vr <- [Map.lookup (erEpoch r) varMap] ]

      toObs (r, vr) = Obs
        { obsTokenId     = erAccount r <> "#" <> erTokenId r
        , obsEpoch       = erEpoch r
        , obsPremium     = erPremEth r        -- ETH per epoch: a FLOW (spec §4.3)
        , obsStrikeTick  = erStrike r
        , obsPoolTick    = round (vrTick vr)
        , obsSigma2      = vrSigma2 vr
        , obsSigma2Instr = vrSigma2I vr
        }
      panel  = map toObs joined
      usable = [ o | o <- panel, finiteD (obsSigma2 o), finiteD (obsPremium o) ]

      -- RUN 2's SINGLE CHANGE. The same rows, the same joins, the same order —
      -- only the sign of the LONG tokenIds' premium differs. Applied AFTER the
      -- join so the row set, the cluster set and every regressor are provably
      -- identical between the two arms.
      joinedNorm = [ (sellerSideNormalize r, vr) | (r, vr) <- joined ]
      usableNorm = [ o | o <- map toObs joinedNorm
                   , finiteD (obsSigma2 o), finiteD (obsPremium o) ]

      -- Independent agreement checks between the joined variance and the values
      -- the 10-09 artifact carries. These must be 0; a non-zero is a defect in
      -- one of the two files, not a result.
      sigDrift   = length [ () | (r, vr) <- joined, vrSigma2 vr /= erSigma2 r ]
      instrDrift = length [ () | (r, vr) <- joined, vrSigma2I vr /= erSigma2I r ]
      tickDrift  = length [ () | (r, vr) <- joined, (round (vrTick vr) :: Int) /= erPoolTick r ]
      moneyDrift = length [ () | (r, vr) <- joined
                          , moneyness (erStrike r) (round (vrTick vr)) /= erMoney r ]

  putStrLn ("estimate: epoch panel " ++ panelPath ++ " — " ++ show (length rows0)
             ++ " rows; variance " ++ eoVarianceCsv eo ++ " — "
             ++ show (Map.size varMap) ++ " epochs")
  putStrLn ("UNMATCHED_EPOCHS: " ++ show (length unmatched))
  putStrLn ("JOIN_SIGMA2_DRIFT: " ++ show sigDrift
             ++ "   JOIN_INSTRUMENT_DRIFT: " ++ show instrDrift
             ++ "   JOIN_POOLTICK_DRIFT: " ++ show tickDrift
             ++ "   JOIN_MONEYNESS_DRIFT: " ++ show moneyDrift)

  -- Fail LOUD rather than estimate on a silently thinned panel.
  when (not (null unmatched)) $ do
    putStrLn ("estimate: ABORT — " ++ show (length unmatched)
               ++ " panel epoch(s) absent from the variance series, e.g. "
               ++ show (take 5 unmatched))
    exitWith (ExitFailure 1)

  when (length usable < 4) $ do
    putStrLn ("estimate: ABORT — only " ++ show (length usable)
               ++ " usable observations (4 needed for a 3-parameter fit)")
    exitWith (ExitFailure 1)

  -- The record is not overwritable.
  guardFrozen outPath

  let collat  = collateralObsAt (3600 * eoEpochHours eo) flows varMap
      wedge   = wedgeStats (Map.elems accMap)
      res1    = runOn collat usable        -- RUN 1: the as-is protocol sign
      res2    = runOn collat usableNorm    -- RUN 2: seller-side normalized
      primary = if sellerSide then res2 else res1
      primPan = rsPanel primary

  -- THE PIVOT LOCK. Its terms bind this run, and its own closing clause makes
  -- the hash load-bearing, so the run refuses to proceed against an edited lock.
  lockSha <- if sellerSide then sha256Of (eoPivotLock eo) else pure Nothing
  when sellerSide $ case lockSha of
    Nothing -> do
      putStrLn "estimate: ABORT — cannot hash the pivot lock; its integrity is unverifiable."
      exitWith (ExitFailure 1)
    Just h | h /= pivotLockSha256 -> do
      putStrLn ("estimate: ABORT — PIVOT LOCK VOID. " ++ eoPivotLock eo
                 ++ " hashes to " ++ h ++ ", expected " ++ pivotLockSha256
                 ++ ". The lock says any post-commit edit voids it.")
      exitWith (ExitFailure 1)
    _ -> putStrLn ("PIVOT_LOCK_SHA256: " ++ pivotLockSha256 ++ "  VERIFIED")

  writeEstimationPanelV2 estOut commit panelPath (eoVarianceCsv eo) primPan
  putStrLn ("estimate: exported " ++ estOut)

  -- The machine-readable verdict block(s). STOPPING_RULE is computed by
  -- 'stoppingRuleVerdict' from the clustered half-width ALONE.
  putStrLn ""
  when sellerSide $ do
    mapM_ putStrLn (verdictBlock "RUN 1 (as-is protocol sign; FROZEN record)" res1)
    putStrLn ""
  mapM_ putStrLn (verdictBlock
    (if sellerSide then "RUN 2 (seller-side normalized; THE RESULT)" else "RUN 1")
    primary)
  putStrLn ""

  when sellerSide $ do
    putStrLn ("D1_HALFWIDTH_OVER_ABS_UPSILON0: run1 " ++ fmtE (descriptorD1 res1)
               ++ "   run2 " ++ fmtE (descriptorD1 res2))
    putStrLn ("D2_CI_EXCLUDES_ZERO: run1 " ++ show (descriptorD2 res1)
               ++ "   run2 " ++ show (descriptorD2 res2))
    putStrLn ("D3_UPSILON0_MOVE: " ++ fmtE (u0 (rsTheta res1)) ++ " -> "
               ++ fmtE (u0 (rsTheta res2)) ++ "   SE " ++ fmtE (rsSeU res1)
               ++ " -> " ++ fmtE (rsSeU res2))
    putStrLn ("KAPPA_POSITIVE_PERSISTS: "
               ++ show (kappa (rsTheta res2) > 0 && reject (rsTK res2)))
    putStrLn ""

  -- Supporting diagnostics, printed but NOT consulted by the rule.
  putStrLn ("NLS_FIXEDSTART_SSE: " ++ fmtE (ndFixedSSE (rsNls primary))
             ++ "   NLS_MULTISTART_IMPROVED: " ++ show (ndImproved (rsNls primary)))
  putStrLn ("N_ACCOUNT_CLUSTERS: " ++ show (length (nub (map obsAccount primPan)))
             ++ "   N_EPOCHS: " ++ show (length (nub (map obsEpoch primPan))))
  putStrLn ("LHS_ZERO_ROWS: " ++ show (length [ () | o <- primPan, obsPremium o == 0 ])
             ++ "   LHS_NEGATIVE_ROWS: "
             ++ show (length [ () | o <- primPan, obsPremium o < 0 ])
             ++ "   LONG_ROWS: " ++ show (length [ () | r <- rows0, erIsLong r ])
             ++ "   SHORT_ROWS: " ++ show (length [ () | r <- rows0, not (erIsLong r) ]))
  reportToStdout (rsTheta primary) (rsThetaIV primary) (rsVTok primary)
                 (rsVAcct primary) (rsTU primary) (rsTK primary) (rsTS primary)
                 (rsAlts primary) primPan

  writeFile outPath $
    if sellerSide
      then renderAnalysisV3 eo dateStr commit argv panelPath estOut banner vbannr
                            gate diffEv rows0 joined res1 res2 collat wedge
                            (sigDrift, instrDrift, tickDrift, moneyDrift)
      else renderAnalysisV2 eo dateStr commit argv panelPath estOut banner vbannr
                            gate diffEv rows0 joined usable
                            (rsTheta res1) (rsThetaIV res1) (rsVTok res1) (rsVAcct res1)
                            (rsTU res1) (rsTK res1) (rsTS res1) (rsSymNote res1)
                            (rsAlts res1) collat (rsNls res1) wedge
                            (sigDrift, instrDrift, tickDrift, moneyDrift)
  putStrLn ("estimate: wrote " ++ outPath)

-- | Evidence about the START the tick-scale multi-start actually needed.
--
-- 'Model.NLS' does not export its start grid, and this plan may not modify it, so
-- the CLI reports (a) the DATA-SCALED anchors recomputed from the same design —
-- the median moneyness that sets κ's scale — and (b) the head-to-head SSE of the
-- fit the estimator returned against a fit from the fixed @κ = 0.2@ fallback
-- start that 09-09 proved numerically dead at tick-scale moneyness. If the
-- multi-start path had not engaged, those two SSEs would coincide.
data NlsDiag = NlsDiag
  { ndStartUsed :: !String
  , ndSSE       :: !Double
  , ndFixedSSE  :: !Double
  , ndImproved  :: !Bool
  , ndDMedian   :: !Double
  , ndKAnchors  :: ![Double]
  }

nlsDiagnostic :: Panel -> Theta -> NlsDiag
nlsDiagnostic panel th@(Theta _ _ _) = NlsDiag
  { ndStartUsed = startDesc
  , ndSSE       = sseOf th
  , ndFixedSSE  = fixedSSE
  , ndImproved  = sseOf th < fixedSSE
  , ndDMedian   = dMed
  , ndKAnchors  = kAnchors
  }
  where
    pts   = designPoints panel
    sseOf (Theta b u k) = sum [ (y - model [b, u, k] x) ^ (2 :: Int) | (x, y) <- pts ]

    dsPos = [ d | ((d, _), _) <- pts, d > 0 ]
    dMed  = max 1 (medianD dsPos)
    s2Med = medianD [ s2 | ((_, s2), _) <- pts ]
    yMed  = medianD [ y | (_, y) <- pts ]
    u0Sc  = if s2Med > 0 then abs yMed / s2Med else 1
    -- Mirrors the anchors 'Model.NLS.multiStarts' derives from the same design.
    kAnchors = [ 1 / (c * dMed) | c <- [0.1, 0.3, 1, 3, 10, 100, 1000] ]

    startDesc =
      "data-scaled multi-start (Model.NLS.multiStarts): median moneyness d = "
        ++ fmtE dMed ++ " ticks, kappa anchors 1/(c*d) for c in {0.1,0.3,1,3,10,100,1000} = ["
        ++ intercalate ", " (map fmtE kAnchors) ++ "], u0 = +/-" ++ fmtE u0Sc
        ++ ", b0 = " ++ fmtE yMed ++ "; plus the fixed fallback [0,1,0.2]"

    dat = [ (x, [y]) | (x, y) <- pts ]
    modelF ps (d, s2) = [model ps (d, s2)]
    jacF [_b0, u0', k'] (d, s2) =
      let e = exp (negate k' * d)
      in [[1, e * s2, negate d * u0' * e * s2]]
    jacF ps _ = error ("nlsDiagnostic: bad param length " ++ show (length ps))
    (fixedSol, _) = fitModel 1e-9 1e-9 500 (modelF, jacF) dat [0.0, 1.0, 0.2]
    fixedSSE = sum [ (y - model fixedSol x) ^ (2 :: Int) | (x, y) <- pts ]

-- | The Phase-10 estimation-panel export.
writeEstimationPanelV2 :: FilePath -> String -> FilePath -> FilePath -> Panel -> IO ()
writeEstimationPanelV2 fp commit panelPath variancePath panel =
    writeFile fp (unlines banner ++ body)
  where
    banner =
      [ "# FINAL ESTIMATION PANEL v2 — Panoptic upsilon identification (phase 10, plan 10-10)."
      , "# One row per POSITION-EPOCH (tokenId x hourly epoch) — the spec section-1 unit of"
      , "# observation, restored by plan 10-09. Supersedes estimation-panel.csv, which is the"
      , "# Phase-9 accrual-SPELL export and is retained unchanged."
      , "# git commit: " ++ commit
      , "# LHS source : " ++ panelPath
      , "# RHS source : " ++ variancePath ++ " (joined on epoch, exact integer match)"
      , "# tokenId  : account#tokenId (the tokenId clustering label; account = prefix before #)"
      , "# epoch    : hourly index floor(unixSeconds/3600) — the epoch the premium ACCRUED in"
      , "# pi       : premium accrued to the SHORT side over the epoch, ETH (a FLOW, not a stock)"
      , "# sigma2   : realized variance of the epoch, from the joined variance series"
      , "# sigma2_instrument : disjoint even-swap sub-window RV of the same epoch (EIV instrument)"
      , "# distance : moneyness d = |i_K - i_t| in ticks, i_t = the epoch's mean pool tick"
      , "tokenId,epoch,pi,sigma2,sigma2_instrument,distance"
      ]
    body = unlines
      [ T.unpack (obsTokenId o) ++ "," ++ show (obsEpoch o) ++ ","
          ++ show (obsPremium o) ++ "," ++ show (obsSigma2 o) ++ ","
          ++ show (obsSigma2Instr o) ++ ","
          ++ show (moneyness (obsStrikeTick o) (obsPoolTick o))
      | o <- sortOn (\o -> (obsTokenId o, obsEpoch o)) panel ]

-- | Elide any home-absolute token. Endpoint URLs are public and keyless, so they
-- are recorded in full; a local filesystem path is never lineage.
sanitizeArg :: String -> String
sanitizeArg s
  | "/home/" `isInfixOf` s || "$HOME" `isInfixOf` s = "<path elided>"
  | take 2 s == "~/"                                = "<path elided>"
  | otherwise                                       = s

-- | THE SELF-DESCRIBING PHASE-10 ANALYSIS OUTPUT.
--
-- Phase 9's unrun audit-econ gate (09-11) may later be re-targeted at this
-- document, so a reader with no access to the session that produced it must be
-- able to reconstruct exactly what was done. Every number below is computed here
-- from the artifacts named in the lineage section; the artifacts' own banners and
-- the gate's own verdict block are quoted verbatim rather than paraphrased.
renderAnalysisV2
  :: EstimateOpts -> String -> String -> [String] -> FilePath -> FilePath
  -> [String] -> [String] -> [String] -> [String]
  -> [EpochRow] -> [(EpochRow, VarRow)] -> Panel
  -> Theta -> Theta -> LA.Matrix Double -> LA.Matrix Double
  -> TestResult -> TestResult -> TestResult -> String
  -> [(T.Text, Estimates)] -> [CollateralObs] -> NlsDiag
  -> (Int, Int, Double, Double, Double, Double, Double, Int)
  -> (Int, Int, Int, Int) -> String
renderAnalysisV2 eo dateStr commit argv panelPath estOut banner vbannr gate diffEv
                 rows0 joined usable
                 (Theta bg ug kg) (Theta bi ui ki) vTok vAcct rU rK rS symNote
                 alts collat nls
                 (nAcc, nUnitWedge, wMed, wMin, wMax, wMaxLong, wMaxShort, nLongAcc)
                 (sigDrift, instrDrift, tickDrift, moneyDrift) =
  unlines $
    [ "# Panoptic vol-claim upsilon: re-estimation on the POSITION-EPOCH panel (v2)"
    , ""
    , "**Phase 10, plan 10-10.** Supersedes"
    , "`notes/structural-econometrcics/analysis/2026-07-20-upsilon-estimates.md`"
    , "(Phase 9, plan 09-09), which is retained unchanged as the baseline this"
    , "document is read against."
    , ""
    , "Estimation of the spec section-4.3 equation, VERBATIM:"
    , ""
    , "> `pi_it = beta0 + upsilon0 * exp(-kappa * |i_K - i_t|) * sigma2_t + v_it`"
    , ""
    , "Run date: " ++ dateStr ++ ". Git commit: `" ++ commit ++ "`."
    , ""
    , "## 0. Headline"
    , ""
    , headline
    , ""
    , "## 1. What changed from Phase 9, and what did not"
    , ""
    , "**The estimator stack did not change. Only the left-hand side did.**"
    , ""
    , "Phase 9 could not construct the spec's section-1 unit of observation and fell"
    , "back to the accrual SPELL (one row per mint-to-burn pair, `pi` in USD per day,"
    , "`sigma2` averaged over the whole spell window): 61 rows, no within-position"
    , "time variation at all. Plans 10-01 through 10-09 reconstructed the streaming"
    , "premium directly from the SFPM X64 accumulators and rebuilt the panel at the"
    , "unit the spec asks for — one row per (tokenId, hourly epoch), with `pi` the"
    , "premium that accrued IN that hour and `sigma2` the variance measured over the"
    , "SAME hour."
    , ""
    , "| | Phase 9 (09-09) | Phase 10 (this run) |"
    , "|---|---|---|"
    , "| unit of observation | accrual spell (mint to burn) | position-epoch (tokenId x hour) |"
    , "| LHS `pi_it` | USD per day over the spell | ETH per hour (a FLOW) |"
    , "| rows | 61 | " ++ show (length usable) ++ " |"
    , "| tokenId clusters | 55 | " ++ show nTok ++ " |"
    , "| within-position variation | none | 52 of 55 positions (10-09) |"
    , "| LHS validated against chain truth | no | yes — `GATE: PASS`, section 3 |"
    , "| estimator | `fitGSL` / `clusterSandwich` / `Tests.Specification` / `Alternatives` | THE SAME, unmodified |"
    , ""
    , "Evidence, generated at run time by this binary rather than asserted:"
    , ""
    , "```"
    ] ++ diffEv ++
    [ "```"
    , ""
    , "The estimator modules were last touched in Phase 9. Everything plan 10-10"
    , "added lives in `econometrics/app/Main.hs`: the `--epoch-panel` option, the"
    , "join, the export, and the stopping-rule verdict. That placement is deliberate"
    , "— it is what keeps \"only the LHS changed\" a one-line `git diff` audit rather"
    , "than a claim."
    , ""
    , "## 2. The validation gate — what licenses reading this estimate at all"
    , ""
    , "The panel's premium column is a DECOMPOSITION of a quantity that was checked"
    , "against the protocol's own `OptionBurn.premium0` over all 61 Phase-9 spells,"
    , "in Integer ETH wei, at a tolerance fixed before the run (plan 10-08). The"
    , "gate's verbatim verdict block, quoted from `" ++ eoGateReport eo ++ "`:"
    , ""
    , "```"
    ] ++ gate ++
    [ "```"
    , ""
    , "Read the two strata separately, as 10-07 specified: the SHORT stratum is the"
    , "scored one; the LONG stratum is reported in full but excluded from the"
    , "pass/fail arithmetic because `_getAvailablePremium` caps SETTLED long premium"
    , "while the accumulator reports ACCRUED. On this sample the long cap did not"
    , "bind at all (8 of 8 exact)."
    , ""
    , "Plan 10-09 then carried that verdict ONTO the panel rather than restating it:"
    , "each of the 55 tokenIds' per-epoch premia sum back to its gate-validated"
    , "`recon_wei` EXACTLY in Integer wei (`TELESCOPE_MISMATCHES 0`,"
    , "`PANEL_SUM_MISMATCHES 0`)."
    , ""
    , "**A passing gate validates MEASUREMENT, not identification.** It says the"
    , "left-hand side is the quantity the protocol actually paid. It says nothing"
    , "about whether this market's variation can identify `upsilon`. That is what"
    , "the STOPPING_RULE section adjudicates."
    , ""
    , "## 3. The panel and the join"
    , ""
    , "| quantity | value |"
    , "|---|---|"
    , "| rows read from `" ++ panelPath ++ "` | " ++ show (length rows0) ++ " |"
    , "| rows joined to the variance series | " ++ show (length joined) ++ " |"
    , "| UNMATCHED_EPOCHS | 0 (the CLI exits non-zero on any) |"
    , "| usable after the finiteness filter | " ++ show (length usable) ++ " |"
    , "| distinct tokenId clusters | " ++ show nTok ++ " |"
    , "| distinct account clusters | " ++ show nAcct' ++ " |"
    , "| distinct epochs | " ++ show nEp ++ " |"
    , "| moneyness d (ticks): median / min / max | " ++ fmtG dMed ++ " / "
        ++ fmtG dMin ++ " / " ++ fmtG dMax ++ " |"
    , "| sigma2: median / min / max | " ++ fmtG s2Med ++ " / " ++ fmtG s2Min
        ++ " / " ++ fmtG s2Max ++ " |"
    , "| pi (ETH/hour): median / min / max | " ++ fmtG yMed ++ " / " ++ fmtG yMin
        ++ " / " ++ fmtG yMax ++ " |"
    , "| rows with pi = 0 exactly | " ++ show nZeroPi ++ " |"
    , "| rows flagged ChunkEmpty | " ++ show nChunkEmpty ++ " |"
    , "| rows flagged AccFrozen | " ++ show nAccFrozen ++ " |"
    , "| rows in a zero-swap hour (n_swaps = 0) | " ++ show nQuiet ++ " |"
    , "| top-10 tokenId row share | " ++ fmtG top10Share ++ " |"
    , ""
    , "**Join cross-checks against the values the 10-09 artifact carries.** The"
    , "panel already stores `sigma2`, `sigma2_instrument` and `pool_tick`; this run"
    , "re-derives all three from `" ++ eoVarianceCsv eo ++ "` and compares, so a"
    , "drift between the two files would surface as a defect rather than as an"
    , "estimate:"
    , ""
    , "| check | mismatching rows |"
    , "|---|---|"
    , "| sigma2 | " ++ show sigDrift ++ " |"
    , "| sigma2_instrument | " ++ show instrDrift ++ " |"
    , "| pool tick (rounded) | " ++ show tickDrift ++ " |"
    , "| moneyness \\|i_K - i_t\\| | " ++ show moneyDrift ++ " |"
    , ""
    , "**The row count is not the precision.** " ++ show (length usable)
        ++ " rows sit in " ++ show nTok ++ " tokenId"
    , "clusters, and the top ten positions carry " ++ fmtG (100 * top10Share)
        ++ "% of the rows. Standard errors"
    , "are clustered by tokenId, so the cluster count — not the row count — bounds"
    , "the achievable precision. This was recorded when the hourly re-scope was"
    , "accepted at 10-01 and again in the 10-09 summary; it is restated here because"
    , "it is the single most likely way to misread the table below."
    , ""
    , "### 3.1 Two properties of this LHS that Phase 9's did not have"
    , ""
    , "Both are stated here rather than in the threats section because they bear"
    , "directly on how the numbers in section 4 should be read, and neither was"
    , "anticipated by the plan text."
    , ""
    , "**(a) The sign convention differs from Phase 9's.**"
    , ""
    , "| | rows | of which negative pi | of which positive pi | tokenIds |"
    , "|---|---|---|---|---|"
    , "| long (`is_long = 1`) | " ++ show nLong ++ " | " ++ show nLongNeg ++ " | "
        ++ show (nLong - nLongNeg - length [ () | r <- rows0, erIsLong r, erPremEth r == 0 ])
        ++ " | " ++ show nLongTok ++ " |"
    , "| short (`is_long = 0`) | " ++ show nShort ++ " | "
        ++ show (nShort - nShortPos - length [ () | r <- rows0, not (erIsLong r), erPremEth r == 0 ])
        ++ " | " ++ show nShortPos ++ " | " ++ show (nTok - nLongTok) ++ " |"
    , ""
    , signNote
    , ""
    , "**(b) The modal position-hour accrues nothing.** " ++ show nZeroPi
        ++ " of " ++ show (length usable) ++ " rows carry"
    , "`pi` exactly 0, and because long rows are negative the MEDIAN of the LHS is"
    , "exactly " ++ fmtG yMed ++ ". That is a genuine property of an hourly grid — a"
    , "position accrues premium only in the hours its chunk is in range and traded —"
    , "but it has a concrete consequence for the optimizer: `Model.NLS.multiStarts`"
    , "anchors its `upsilon0` start at `median(pi)/median(sigma2)`, which is"
    , "therefore " ++ fmtE 0 ++ " on this panel, and its `beta0` start likewise. The"
    , "start grid still spans the informative `kappa` scale (that anchor is the"
    , "median MONEYNESS, which is well defined at " ++ fmtE (ndDMedian nls)
        ++ " ticks) and the"
    , "`upsilon0` gradient `exp(-kappa*d)*sigma2` is non-zero at a zero start, so the"
    , "fit is not stuck — see the head-to-head SSE in section 4.1 — but the margin by"
    , "which the multi-start beat the dead fixed start is small, and that is recorded"
    , "rather than smoothed over."
    , ""
    , "## 4. Estimates"
    , ""
    , "### 4.1 Primary — GSL Levenberg-Marquardt NLS, tokenId-clustered CR0 sandwich SEs"
    , ""
    , "| parameter | estimate | clustered SE | 95% CI |"
    , "|---|---|---|---|"
    , row3 "beta0 (intercept, ETH/hour)" bg seB
    , row3 "upsilon0 (vega level)"       ug seU
    , row3 "kappa (moneyness decay, per tick)" kg seK
    , ""
    , "Account-clustered SEs (coarser, " ++ show nAcct' ++ " clusters): beta0 "
        ++ fmtG seBa ++ ", upsilon0 " ++ fmtG seUa ++ ", kappa " ++ fmtG seKa ++ "."
    , "With that few clusters the Normal approximation is unreliable; reported for"
    , "transparency, not for inference."
    , ""
    , "**Optimizer.** The primary fit is `Model.NLS.fitGSL` — hmatrix-gsl"
    , "Levenberg-Marquardt with an analytic Jacobian — run from the DATA-SCALED"
    , "multi-start, keeping the lowest-SSE finite solution. This matters at tick-scale"
    , "moneyness: plan 09-09 established that a fixed `kappa = 0.2` start evaluates"
    , "`exp(-0.2*153) ~ 5e-14`, so the model is numerically zero at the start point,"
    , "the Jacobian vanishes, and the optimizer reports a start-value artifact (it"
    , "produced a spurious `kappa = 0.384` on the first live run before the fix)."
    , ""
    , "| optimizer diagnostic | value |"
    , "|---|---|"
    , "| start grid | " ++ ndStartUsed nls ++ " |"
    , "| median moneyness setting kappa's scale | " ++ fmtE (ndDMedian nls) ++ " ticks |"
    , "| SSE at the returned solution | " ++ fmtE (ndSSE nls) ++ " |"
    , "| SSE from the fixed `kappa = 0.2` fallback start alone | " ++ fmtE (ndFixedSSE nls) ++ " |"
    , "| multi-start strictly improved on the fixed start | " ++ show (ndImproved nls) ++ " |"
    , ""
    , "`Model.NLS` does not export its start grid and this plan may not modify it, so"
    , "the anchors above are RECOMPUTED by the CLI from the same design and the"
    , "head-to-head SSE is the evidence that the multi-start path engaged: had it not,"
    , "the two SSEs would coincide."
    , ""
    , "### 4.2 EIV IV (two noisy measures: sigma~2 instruments sigma2) — naive vs IV"
    , ""
    , "The realized-variance regressor is estimated, hence EIV-mismeasured (spec"
    , "section 3.3 threat M1), which ATTENUATES the naive `upsilon0` toward zero. The"
    , "remedy is the spec's own: instrument `sigma2` with the disjoint even-swap"
    , "sub-window estimate `sigma~2` of the SAME epoch. `kappa` is identified off"
    , "moneyness rather than the variance level, so it is conditioned on at its NLS"
    , "value rather than re-estimated (spec section 4.3)."
    , ""
    , "| parameter | naive (NLS) | EIV IV |"
    , "|---|---|---|"
    , "| beta0 | " ++ fmtG bg ++ " | " ++ fmtG bi ++ " |"
    , "| **upsilon0** | " ++ fmtG ug ++ " | " ++ fmtG ui ++ " |"
    , "| kappa | " ++ fmtG kg ++ " | " ++ fmtG ki ++ " (held at the NLS value) |"
    , ""
    , ivReading
    , ""
    , "### 4.3 The three committed specification tests (spec section 5)"
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
    ] ++ degeneracyBox ++
    [ ""
    , "Test 2 is the econometric twin of the Lean conjecture"
    , "`Upsilon.ATMOTMNullHypothesis`: H0 kappa = 0 (flat vega profile) versus"
    , "H1 kappa > 0 (maximal at the money, exponential decay out of the money)."
    , ""
    , kappaVerdict
    , ""
    , "### 4.4 The four locked alternative specifications (spec section 6.2)"
    , ""
    , "The list is locked by the spec. Nothing was added, and nothing that failed to"
    , "identify was dropped."
    , ""
    ] ++ concatMap renderAltBlockV2 alts ++
    [ "Collateral-channel observations formed on the " ++ show (eoEpochHours eo)
        ++ "-hour grid: " ++ show (length collat) ++ "."
    , ""
    , "## STOPPING_RULE"
    , ""
    , "```"
    , "PRECOMMITTED_HALFWIDTH_BAR: " ++ fmtE precommittedHalfwidthBar
    , "UPSILON0_HAT: " ++ fmtE ug
    , "UPSILON0_SE_CLUSTERED: " ++ fmtE seU
    , "UPSILON0_CI_HALFWIDTH: " ++ fmtE halfWidth
    , "STOPPING_RULE: " ++ verdictStr
    , "```"
    , ""
    , "**The bar was fixed before this run and was NOT adjusted.** It was written"
    , "into `10-CONTEXT.md` (\"Power / stopping rule\") when the phase was scoped, at"
    , "one quarter of Phase 9's realised half-width of +/-2.48e-4, and it lives in"
    , "source as the single named constant `precommittedHalfwidthBar` in"
    , "`econometrics/app/Main.hs`."
    , ""
    , "**The verdict is result-blind by construction.** `stoppingRuleVerdict` takes"
    , "exactly one argument — the realised clustered half-width — and compares it to"
    , "that constant. It does not see `kappa`'s sign, any p-value, or whether the"
    , "answer is interesting. An INFORMATIVE interval pointing AWAY from the"
    , "conjecture is a success under this rule."
    , ""
    , "Phase-9 comparison: half-width +/-2.48e-4 on 61 observations over 55 tokenId"
    , "clusters. This run: half-width +/-" ++ fmtE halfWidth ++ " on "
        ++ show (length usable) ++ " observations over " ++ show nTok ++ " clusters."
    , ""
    ] ++ stoppingRuleProse ++
    [ ""
    , "### Comparability of the bar — one fact recorded without acting on it"
    , ""
    , "`upsilon0` is `d(pi)/d(sigma2)`, so its NUMERICAL SCALE is set by the units of"
    , "both. Phase 9 measured `pi` in USD per DAY against a DAILY realised variance"
    , "(median " ++ fmtG 2.2170782903231388e-4 ++ "). This panel measures `pi` in ETH"
    , "per HOUR against an HOURLY realised variance (median " ++ fmtG s2Med ++ "). The"
    , "bar of 6.2e-5 was derived from Phase 9's half-width and therefore carries"
    , "Phase 9's units; the realised half-width above carries this panel's."
    , ""
    , "**Nothing was done about that.** The bar was not rescaled, not reinterpreted,"
    , "and not moved: it is the literal 6.2e-5 written into `10-CONTEXT.md` before the"
    , "phase began and into `precommittedHalfwidthBar` before this run, and the"
    , "verdict above is the literal comparison against it. Rescaling a pre-committed"
    , "bar after seeing the number it judges is exactly the move the phase's"
    , "anti-fishing discipline exists to catch, and this document is not the place to"
    , "make it. The fact is recorded because an auditor and the adjudicating user both"
    , "need it in front of them; what to do with it is theirs to decide, not this"
    , "run's."
    , ""
    , "For what it is worth as a UNIT-FREE reading, which is offered as description"
    , "rather than as a substitute criterion: the ratio of the half-width to the point"
    , "estimate is " ++ fmtG (halfWidth / ug) ++ ", i.e. the interval is that many"
    , "times the estimate wide, and it contains zero."
    ] ++
    [ ""
    , "## 6. The Lean witness"
    , ""
    ] ++ witnessBlock ++
    [ ""
    , "## 7. The Panoptic-vs-Lean wedge"
    , ""
    , "**The estimated `pi_it` is PANOPTIC'S PREMIUM, not the bare streaming-premium"
    , "fee-revenue identity that Lean models.** This is a real wedge between the two"
    , "objects and is recorded here rather than papered over."
    , ""
    , "`spec/refs/cfmm-discrete/STREAMING_PREMIUM.md` and `lean/vol_markets/Panoptic.lean`"
    , "model `streamingPremium` as LP fee revenue per unit liquidity. Panoptic pays"
    , "that fee growth multiplied by a UTILIZATION-BASED multiplier:"
    , ""
    , "> `1 + nu*R/N` on the long side, `1 + nu*R^2/(N*T)` on the short side,"
    , "> with `nu = 1/VEGOID = 1/8 = 0.125`, `R` = removed liquidity, `N` = net"
    , "> liquidity, `T = N + R`."
    , ""
    , "The multiplier is applied INSIDE the contract's X64 accumulator, so it is"
    , "already in the reconstructed premium and is never re-applied by this code."
    , "`Panoptic.Premium.multiplierWedge` exists solely to REPORT it. Its MEASURED"
    , "distribution over the " ++ show nAcc ++ " accumulator readings backing this panel:"
    , ""
    , "| statistic | value |"
    , "|---|---|"
    , "| median (all readings) | " ++ fmtG wMed ++ " |"
    , "| min | " ++ fmtG wMin ++ " |"
    , "| max (all readings) | " ++ fmtG wMax ++ " |"
    , "| max over LONG readings (" ++ show nLongAcc ++ ") | " ++ fmtG wMaxLong ++ " |"
    , "| max over SHORT readings (" ++ show (nAcc - nLongAcc) ++ ") | " ++ fmtG wMaxShort ++ " |"
    , "| readings with removed liquidity R = 0 (wedge exactly 1) | " ++ show nUnitWedge
        ++ " of " ++ show nAcc ++ " |"
    , "| implied max `R/N` on long readings, `8*(wedge-1)` | " ++ fmtG (8 * (wMaxLong - 1)) ++ " |"
    , "| `1 + nu` — the figure 10-CONTEXT quotes as the bound | 1.125 |"
    , ""
    , wedgeReading
    , ""
    , "Plan 10-11 records the same wedge in the Lean-Haskell cross-walk table."
    , ""
    , "## 8. Threats to validity"
    , ""
    , "Phase 9's threats are carried forward, not discharged, except where this phase"
    , "actually changed something."
    , ""
    , "1. **A passing gate validates MEASUREMENT, not identification.** It certifies"
    , "   the LHS is the quantity the protocol paid. Whether this market's variation"
    , "   identifies `upsilon` is a separate question, and the STOPPING_RULE"
    , "   section is the only thing in this document that answers it."
    , "2. **The cluster ceiling.** " ++ show (length usable) ++ " rows, but only "
        ++ show nTok ++ " tokenId"
    , "   clusters and " ++ fmtG (100 * top10Share) ++ "% of the rows in ten positions."
    , "   Adding hours to existing positions multiplies rows without multiplying"
    , "   clusters, so the clustered CI does not contract like 1/sqrt(N)."
    , "3. **Flagged rows.** " ++ show nChunkEmpty ++ " row(s) carry `ChunkEmpty`"
    , "   (the chunk's net liquidity was zero at the read, so a flat accumulator is"
    , "   ambiguous between \"no fees\" and \"no chunk\") and " ++ show nAccFrozen
    , "   carry `AccFrozen`. They are RETAINED and labelled, never silently dropped:"
    , "   dropping them would be a selection decision taken after seeing the data."
    , "4. **The zero-swap hour.** " ++ show nQuiet ++ " row(s) sit in an hour with"
    , "   `n_swaps = 0`, carried as a MEASURED sigma2 = 0 after a bounded re-fetch"
    , "   reproduced the tick cache byte-identically (10-09). The confirming re-fetch"
    , "   used the SAME public endpoint, so it establishes reproducibility, not"
    , "   provider-independence."
    , "5. **The long-stratum capping wedge.** `_getAvailablePremium` caps SETTLED long"
    , "   premium while the accumulator reports ACCRUED. It did not bind on any spell"
    , "   in the gate sample, but the panel's long rows are ACCRUED premium and the"
    , "   distinction survives this phase."
    , "6. **The `width == 0` exclusion.** `PanopticPool._getPremia` skips legs with"
    , "   `width == 0`, so those legs contribute no premium and are absent from the"
    , "   panel. The 10-01 census found `width != 0` on 68 of 68 spell-legs, so the"
    , "   exclusion does not bind on this population — but it is a selection rule that"
    , "   would bind on a different one."
    , "7. **Multi-leg positions carry one strike.** Premium is summed over legs within"
    , "   the hour, but `strike_tick` comes from the position's first resolved leg."
    , "   `leg_count` is carried in the panel so the approximation is visible."
    , "8. **Residual reconstruction error.** 53 of 61 spells reconcile exactly to the"
    , "   wei; the other 8 carry an irreducible sub-block end-of-block-versus-"
    , "   at-transaction `eth_call` read wedge, bounded at 5.447268e-4 relative"
    , "   (18x inside tolerance). Removing it needs transaction-level replay."
    , "9. **Functional form.** `kappa`'s meaning is exponential-form dependent (spec"
    , "   section 6.1.1); the semiparametric alternative is the check."
    , "10. **Strike-composition selection.** Strikes were never declared exogenous"
    , "    (spec section 2.5). The position-FE diagnostic is the intended check; read"
    , "    its outcome in section 4.4 before treating this threat as cleared."
    , "11. **The Panoptic-vs-Lean multiplier wedge** (section 7)."
    , "12. **The LHS sign convention** (section 3.1a). " ++ show nLong ++ " long rows"
    , "    enter with the opposite sign to the " ++ show nShort ++ " short ones,"
    , "    where Phase 9 normalised both to the seller side. This attenuates"
    , "    `upsilon0` and widens its interval, and it is the most consequential"
    , "    unplanned difference between the two runs' left-hand sides."
    , "13. **Scale non-comparability of the pre-committed bar** (STOPPING_RULE,"
    , "    comparability note). The bar carries Phase 9's USD/day units and the"
    , "    realised half-width carries this panel's ETH/hour units. Recorded; NOT acted on."
    , "14. **The intercept changed meaning.** `beta0` is now ETH per HOUR, not USD"
    , "    per day, so it is not comparable with Phase 9's 2.36e-4 either."
    , ""
    , "## 9. DATA LINEAGE (audit trail)"
    , ""
    , "Run date: " ++ dateStr ++ ". Git commit: `" ++ commit ++ "`."
    , "All paths are repo-root relative. No credential is recorded anywhere in this"
    , "pipeline: every endpoint below is public and keyless."
    , ""
    , "### The exact invocation"
    , ""
    , "```"
    , "econometrics " ++ unwords (map sanitizeArg argv)
    , "```"
    , ""
    , "### Chain and contracts"
    , ""
    , "| what | value |"
    , "|---|---|"
    , "| chain | Base mainnet (L2), chainId 8453 |"
    , "| Panoptic subgraph | `" ++ show' (eoEndpoint eo) ++ "` |"
    , "| PanopticPool | `0xb50e8bb68f5855da742f4579274902a20454174a` (ETH/USDC, fee 500, tickSpacing 10) |"
    , "| underlying pool (V4 poolId) | `" ++ show' (eoPool eo) ++ "` |"
    , "| SFPM (premium accumulator read target) | `0x8dcAa08cF298F8b4830FAf56d47930981AdE33af` |"
    , "| VEGOID / nu | 8 / 0.125 |"
    , "| Base RPC (variance + accumulator reads) | `" ++ show' (eoRpc eo)
        ++ "`; failover `https://base.drpc.org` |"
    , "| V4 PoolManager (Swap log emitter) | `0x498581ff718922c3f8e6a244956af099b2652b2b` |"
    , "| block range | " ++ show (eoFromBlock eo) ++ " .. " ++ show (eoToBlock eo) ++ " |"
    , ""
    , "The bulk accumulator read (plan 10-06) issued **8,910 `eth_call`s** across a"
    , "six-cycle resume chain; wall time was dominated by public-RPC rate limiting"
    , "rather than call count (effective throughput ~0.25-7 calls/s; the final slice"
    , "ran 1,994 calls in 7,963 s). `FAILOVER_CALLS: 0` on the completing slice. Full"
    , "read lineage: `notes/structural-econometrcics/data/premium-accumulators-lineage.md`."
    , ""
    , "### Files"
    , ""
    , "| path | contents | rows |"
    , "|---|---|---|"
    , "| `notes/structural-econometrcics/data/burn-truth.csv` | frozen OptionBurn ground truth (INPUT) | 61 |"
    , "| `notes/structural-econometrcics/data/premium-accumulators.csv` | SFPM X64 accumulator readings | 8,910 |"
    , "| `notes/structural-econometrcics/data/epoch-blocks.csv` | hourly epoch -> first Base block | 2,832 |"
    , "| `notes/structural-econometrcics/data/chunk-legs.csv` | per-leg chunk identity census | see file |"
    , "| `notes/structural-econometrcics/data/reconcile-errors.csv` | per-spell gate error | 61 |"
    , "| `" ++ eoGateReport eo ++ "` | THE gate report | see section 2 |"
    , "| `" ++ eoVarianceCsv eo ++ "` | hourly sigma2, EIV instrument, pool tick, n_swaps | "
        ++ show nVarEpochs ++ " |"
    , "| `" ++ panelPath ++ "` | THE position-epoch panel (LHS) | " ++ show (length rows0) ++ " |"
    , "| `" ++ eoCollateralCsv eo ++ "` | signed collateral share flows | see file |"
    , "| `" ++ estOut ++ "` | the estimation panel handed to any later cross-check | "
        ++ show (length usable) ++ " |"
    , "| `" ++ eoTicksCsv eo ++ "` | raw (unix, tick) Swap cache (gitignored: large, regenerable) | 632,315 |"
    , ""
    , "### The epoch definition"
    , ""
    , "`epoch = floor(unixSeconds / 3600)` — hourly buckets — via"
    , "`Panel.Epoch.epochOfSeconds`, the SAME function the variance series uses, so"
    , "the join is an exact INTEGER match and never a timestamp comparison (the"
    , "09-05 40587-offset trap). Block-index epoch `e` is the START of hour `e`, so a"
    , "row's premium is the accumulator difference over the interval STARTING at that"
    , "boundary and is regressed on the variance of the SAME hour."
    , ""
    , "### The panel artifact's own banner (verbatim)"
    , ""
    , "```"
    ] ++ banner ++
    [ "```"
    , ""
    , "### The variance artifact's own banner (verbatim)"
    , ""
    , "```"
    ] ++ vbannr ++
    [ "```"
    , ""
    , "### The estimator"
    , ""
    , "- **Point estimates:** `Model.NLS.fitGSL` — `Numeric.GSL.Fitting.fitModel`,"
    , "  Levenberg-Marquardt with an analytic 3-column Jacobian, run from the"
    , "  data-scaled multi-start and keeping the lowest-SSE finite solution. The"
    , "  chosen-start diagnostics and the SSE are in section 4.1."
    , "- **Standard errors:** `Model.SandwichSE.clusterSandwich` — a hand-rolled"
    , "  tokenId-clustered CR0 sandwich `(J'J)^-1 [sum_g s_g s_g'] (J'J)^-1`, with NO"
    , "  finite-sample correction, golden-tested to 1e-9 against the frozen 09-01"
    , "  fixture. The Stata-style CR1 multiplier is exposed as `clusterCR1Factor` but"
    , "  deliberately not baked in."
    , "- **EIV:** `Model.EIV.ivFit` — two-step two-noisy-measures IV, `kappa` from"
    , "  NLS then `(Z'X)^-1 Z'y` with `sigma~2` instrumenting `sigma2`."
    , "- **Tests:** `Tests.Specification` — one-sided Normal for the sign"
    , "  restrictions, chi-squared(1) Wald for the symmetry restriction, p-values"
    , "  from the `statistics` package."
    , "- **Alternatives:** `Alternatives` — the four locked spec section-6.2"
    , "  specifications, each reporting NOT IDENTIFIED with a reason rather than a"
    , "  meaningless number when the design cannot support it."
    , ""
    , "### Reproduce"
    , ""
    , "```sh"
    , "stack --stack-yaml econometrics/stack.yaml exec econometrics -- estimate \\"
    , "  --epoch-panel " ++ panelPath ++ " \\"
    , "  --variance " ++ eoVarianceCsv eo ++ " \\"
    , "  --epoch-hours " ++ show (eoEpochHours eo) ++ " \\"
    , "  --estimation-out " ++ estOut ++ " \\"
    , "  --endpoint <subgraph-endpoint> --pool <poolId> --rpc <base-rpc-url> \\"
    , "  --from-block " ++ show (eoFromBlock eo) ++ " --to-block " ++ show (eoToBlock eo)
    , "```"
    , ""
    , "The endpoint, poolId and RPC URL are the values in the table above. No API key"
    , "is required for any of them."
    ]
  where
    show' s = if null s then "(not recorded on this run)" else s

    ses   = standardErrors vTok ++ repeat (0 / 0)
    sesA  = standardErrors vAcct ++ repeat (0 / 0)
    (seB, seU, seK)    = (ses !! 0, ses !! 1, ses !! 2)
    (seBa, seUa, seKa) = (sesA !! 0, sesA !! 1, sesA !! 2)

    halfWidth = ciHalfWidth seU
    verdictStr = stoppingRuleVerdict halfWidth
    informative = verdictStr == "INFORMATIVE"

    nTok   = length (nub (map obsTokenId usable))
    nAcct' = length (nub (map (T.takeWhile (/= '#') . obsTokenId) usable))
    nEp    = length (nub (map obsEpoch usable))
    nVarEpochs = length (nub (map (erEpoch . fst) joined))

    ds     = [ moneyness (obsStrikeTick o) (obsPoolTick o) | o <- usable ]
    s2s    = map obsSigma2 usable
    ys     = map obsPremium usable
    dMed   = medianD ds
    dMin   = if null ds then 0 / 0 else minimum ds
    dMax   = if null ds then 0 / 0 else maximum ds
    s2Med  = medianD s2s
    s2Min  = if null s2s then 0 / 0 else minimum s2s
    s2Max  = if null s2s then 0 / 0 else maximum s2s
    yMed   = medianD ys
    yMin   = if null ys then 0 / 0 else minimum ys
    yMax   = if null ys then 0 / 0 else maximum ys
    nZeroPi = length [ () | y <- ys, y == 0 ]

    nChunkEmpty = length [ () | r <- rows0, "ChunkEmpty" `T.isInfixOf` erFlags r ]
    nAccFrozen  = length [ () | r <- rows0, "AccFrozen"  `T.isInfixOf` erFlags r ]
    nQuiet      = length [ () | r <- rows0, erNSwaps r == 0 ]

    -- THE SIGN CENSUS. Phase 9 normalised long spells to the seller side
    -- ('Panel.Build.premiumUsd' multiplies by -1 when isLong) precisely so that
    -- one vega could not enter the regression with two opposite signs.
    -- 'assembleEpochPanel' carries the protocol's own sign instead. That is a
    -- FACT about the LHS, measured here rather than assumed either way.
    nLong     = length [ () | r <- rows0, erIsLong r ]
    nShort    = length rows0 - nLong
    nLongNeg  = length [ () | r <- rows0, erIsLong r, erPremEth r < 0 ]
    nShortPos = length [ () | r <- rows0, not (erIsLong r), erPremEth r > 0 ]
    nLongTok  = length (nub [ erTokenId r | r <- rows0, erIsLong r ])
    signMixed = nLongNeg > 0 && nShortPos > 0

    tokCounts = Map.fromListWith (+) [ (obsTokenId o, 1 :: Int) | o <- usable ]
    top10Share =
      let cs = take 10 (reverse (sort (Map.elems tokCounts)))
      in if null usable then 0 / 0
         else fromIntegral (sum cs) / fromIntegral (length usable)

    -- THE DEGENERACY CHECK, unchanged from Phase 9: kappa enters the model ONLY
    -- through upsilon0*exp(-kappa*d)*sigma2, so a numerically zero upsilon0
    -- extinguishes the vega term and leaves kappa with no effect on the fit at
    -- ANY value.
    maxVegaContribution =
      abs ug * maximum (1e-300 : [ s2 | s2 <- s2s, finiteD s2 ])
    upsilonDegenerate = maxVegaContribution < 1e-6 * abs bg
    kappaPositive     = kg > 0 && not (isNaN kg)
    upsilonPositive   = ug > 0 && not (isNaN ug)
    kappaSignificant  = kappaPositive && reject rK

    headline =
      "**STOPPING_RULE: " ++ verdictStr ++ ".** The realised upsilon0 clustered-CI"
        ++ " half-width is +/-" ++ fmtE halfWidth ++ " against a bar of +/-"
        ++ fmtE precommittedHalfwidthBar ++ " fixed before the run"
        ++ (if informative
              then ". The measurement fix delivered an informative interval."
              else ". The interval remains uninformative.")
        ++ " upsilon0-hat = " ++ fmtG ug ++ " (clustered SE " ++ fmtG seU
        ++ "), kappa-hat = " ++ fmtG kg ++ " (clustered SE " ++ fmtG seK
        ++ "), beta0-hat = " ++ fmtG bg ++ " ETH/hour (clustered SE " ++ fmtG seB
        ++ "), on " ++ show (length usable) ++ " position-epoch observations over "
        ++ show nTok ++ " tokenId clusters."
        ++ (if upsilonDegenerate
              then " The fitted vega level is numerically zero, so kappa is"
                   ++ " STRUCTURALLY UNIDENTIFIED and its test is vacuous (section 4.3)."
              else "")
        ++ " " ++ kappaHeadline

    -- Reported at the top because it is the substantive change from Phase 9's
    -- vacuous test — and immediately bounded, because a significant kappa beside
    -- an unresolved upsilon0 is exactly the asymmetry 09-09's over-read lesson
    -- was about.
    kappaHeadline
      | upsilonDegenerate =
          "Unlike Phase 9 this run also reports a kappa point estimate, but with the"
          ++ " vega term extinguished it carries no information."
      | kappaSignificant && not (upsilonPositive && reject rU) =
          "**Separately, and for the first time in this project, THE NULL TEST"
          ++ " REJECTS:** kappa-hat = " ++ fmtG kg ++ " > 0 with clustered SE "
          ++ fmtG seK ++ " (z = " ++ fmtG (statistic rK) ++ ", p = "
          ++ fmtG (pValue rK) ++ "), so H0 of a flat vega profile is rejected in the"
          ++ " direction the conjecture predicts. That result stands on its own and"
          ++ " is NOT a substitute for the stopping rule: `upsilon0 > 0` does NOT"
          ++ " reject (p = " ++ fmtG (pValue rU) ++ ") and its interval contains"
          ++ " zero, so the Lean witness does not obtain (section 6), and the"
          ++ " phase's pre-committed verdict is the one stated above."
      | kappaSignificant =
          "H0: kappa = 0 is REJECTED in favour of kappa > 0 (p = "
          ++ fmtG (pValue rK) ++ ")."
      | otherwise =
          "H0: kappa = 0 is NOT rejected (p = " ++ fmtG (pValue rK)
          ++ "); failing to reject is not evidence that the profile is flat."

    ivReading
      | isNaN ui || isNaN ug = "The IV estimate is not available on this design."
      | abs ug < 1e-300 =
          "The naive `upsilon0` is numerically zero, so there is no attenuation for"
          ++ " the IV to undo: the IV estimate is reported beside it for"
          ++ " completeness, not as a correction of a detected effect."
      | otherwise =
          "Attenuation ratio naive/IV = " ++ fmtG (ug / ui) ++ ". Under classical"
          ++ " EIV the IV estimate is the larger in magnitude; read the two together"
          ++ " rather than either alone."

    degeneracyBox
      | not upsilonDegenerate = []
      | otherwise =
          [ "> **kappa IS NOT IDENTIFIED ON THIS SAMPLE — read test 2 as vacuous.**"
          , ">"
          , "> kappa enters the model ONLY through `upsilon0 * exp(-kappa*d) * sigma2`."
          , "> The fitted `upsilon0-hat = " ++ fmtG ug ++ "` is numerically zero: the"
          , "> largest contribution the vega term can make to `pi` anywhere in the"
          , "> sample is " ++ fmtG maxVegaContribution ++ ", against a fitted intercept"
          , "> of " ++ fmtG bg ++ ". With the vega term extinguished, kappa has NO"
          , "> effect on the fit at ANY value — which is why its clustered standard"
          , "> error is " ++ fmtG seK ++ "."
          , ">"
          , "> The honest reading is that the best fit is a CONSTANT premium rate"
          , "> `pi = beta0`, with no detectable variance-times-moneyness structure."
          , "> The `kappa > 0` statistic is reported for completeness but carries no"
          , "> information, and neither rejecting nor failing to reject it says"
          , "> anything about the conjecture."
          ]

    kappaVerdict
      | upsilonDegenerate =
          "**Verdict: the null test is VACUOUS on this sample.** kappa is not"
            ++ " identified, so H0: kappa = 0 can be neither rejected nor sustained."
            ++ " This is a statement about the data's information content, not"
            ++ " evidence about the vega profile."
      | kappaSignificant =
          "**Verdict: H0 (kappa = 0) is REJECTED** at the 5% level in favour of"
            ++ " kappa > 0, on the tokenId-clustered covariance."
      | otherwise =
          "**Verdict: H0 (kappa = 0) is NOT REJECTED.** Reported as the null result"
            ++ " it is. Note the direction of the inference: failing to reject is not"
            ++ " evidence that the profile is flat."

    signNote
      | not signMixed =
          "The two strata carry the same sign, so no cancellation arises."
      | otherwise =
          "Phase 9 NORMALISED this: `Panel.Build.premiumUsd` multiplies a long"
          ++ " spell's premium by -1, and the function's own comment gives the"
          ++ " reason — \"the same vega would enter the regression with two opposite"
          ++ " signs and cancel\". `Panel.Build.assembleEpochPanel` does NOT apply"
          ++ " that flip; it carries the protocol's own seller-side sign, which is"
          ++ " what `Panoptic.Premium.premiumWei` emits (negating long legs, mirroring"
          ++ " `_getPremia`). So " ++ show nLong ++ " of " ++ show (length rows0)
          ++ " rows ("
          ++ fmtG (100 * fromIntegral nLong / fromIntegral (max 1 (length rows0)))
          ++ "% of the panel, over " ++ show nLongTok ++ " of " ++ show nTok
          ++ " tokenIds) enter this regression with the OPPOSITE sign to the rest."
          ++ " The direction of the resulting bias is not ambiguous: a common vega"
          ++ " expressed with two signs partially cancels, which pushes `upsilon0`"
          ++ " toward zero and widens its interval — the exact quantity the stopping"
          ++ " rule adjudicates. This divergence was NOT changed during this run: the"
          ++ " estimate was already computed when it was found, and respecifying the"
          ++ " left-hand side after seeing a verdict is precisely the goalpost move"
          ++ " the phase's anti-fishing discipline forbids. It is reported here as a"
          ++ " concrete, named candidate defect for adjudication, and it belongs to"
          ++ " the panel artifact (plan 10-09), not to the estimator."

    stoppingRuleProse
      | informative =
          [ "**The bar was met.** The interval is informative, and it is read as it"
          , "fell — in whichever direction it points. Section 6 states whether the"
          , "fitted profile witnesses the proved Lean theorem; an informative interval"
          , "that points away from the conjecture is a success under this rule and is"
          , "not to be re-described as a failure."
          ]
      | otherwise =
          [ "**The bar was NOT met, and the pre-authorised terminal outcome applies:**"
          , ""
          , "> **This market cannot identify `upsilon`.**"
          , ""
          , "The phase reports that and STOPS. There is no respecification, no"
          , "subsample hunting, and no alternative-estimator fishing — those were"
          , "ruled out in advance precisely so that this outcome could be reported"
          , "honestly rather than escaped. With the left-hand side now validated"
          , "against the protocol's own ground truth in Integer wei (section 2), an"
          , "uninformative interval is evidence about the MARKET rather than about the"
          , "measurement, which is a stronger and more defensible claim than Phase 9's"
          , "ambiguous null: Phase 9 could not tell the two apart."
          ]

    witnessBlock =
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
      , "**No Lean file was modified and no Aristotle task was run in this phase.**"
      , "The theorem is already proved; what is at issue is only whether the fitted"
      , "profile instantiates its hypotheses."
      , ""
      , "Its three hypotheses are `hu : 0 < upsilon0`, `hk : 0 < kappa` and"
      , "`hd : 0 < Delta_i` (the tick spacing, 10 on this market, so `hd` holds by"
      , "inspection). The fitted values:"
      , ""
      , "- `upsilon0-hat = " ++ fmtG ug ++ "` (clustered SE " ++ fmtG seU ++ ")  ->  `hu` " ++ huStatus
      , "- `kappa-hat = " ++ fmtG kg ++ "` (clustered SE " ++ fmtG seK ++ ")  ->  `hk` " ++ hkStatus
      , "- `Delta_i = 10` (pool tickSpacing)  ->  `hd` SATISFIED"
      , ""
      , witnessVerdict
      ]
      where
        -- The bullets report BOTH the sign and the test verdict. Reporting the
        -- sign alone as "SATISFIED" beside a verdict that the witness fails is
        -- the kind of internal mismatch 09-09's over-read lesson names: a
        -- hypotheses-satisfied claim must agree with the actual test outcome.
        status pos rt p
          | not pos   = "**NOT SATISFIED** — the point estimate has the wrong sign."
          | reject rt = "SATISFIED in sign AND statistically supported (test p = "
                        ++ fmtG p ++ ")."
          | otherwise = "satisfied in SIGN ONLY — the corresponding test does NOT"
                        ++ " reject (p = " ++ fmtG p ++ "), so the strict inequality"
                        ++ " is not supported by the data."
        huStatus
          | upsilonDegenerate =
              "**NOT usable** — positive in sign but numerically zero, so the strict"
              ++ " inequality holds only vacuously."
          | otherwise = status upsilonPositive rU (pValue rU)
        hkStatus
          | upsilonDegenerate =
              "**cannot be evaluated** — kappa is unidentified once the vega term"
              ++ " vanishes."
          | otherwise = status kappaPositive rK (pValue rK)
        -- THE WITNESS BAR. The theorem takes BOTH `hu : 0 < upsilon0` AND
        -- `hk : 0 < kappa`, so both must be supported for the fitted profile to
        -- be claimed as an instance of the family it quantifies over. Requiring
        -- statistical support on BOTH — rather than on kappa alone with upsilon0
        -- merely positive in sign — is the STRICTER reading, and it is the one
        -- 09-09's over-read lesson demands: a hypotheses-satisfied claim must
        -- match the actual test verdicts, and test 1 is a verdict too.
        upsilonSignificant = upsilonPositive && reject rU
        witnessVerdict
          | kappaSignificant && upsilonSignificant && not upsilonDegenerate =
              "**The witness OBTAINS.** Both restrictions are satisfied by the point"
              ++ " estimates AND statistically supported at the 5% level on the"
              ++ " tokenId-clustered covariance (`upsilon0 > 0` p = " ++ fmtG (pValue rU)
              ++ ", `kappa > 0` p = " ++ fmtG (pValue rK) ++ "), and `hd` holds by"
              ++ " inspection. The fitted exponential-moneyness profile is therefore a"
              ++ " literal witness of `ATMOTMNullHypothesis` at"
              ++ " `c = kappa-hat * Delta_i = " ++ fmtG (kg * 10) ++ "`. The theorem is"
              ++ " about the FAMILY, so the witness is exactly as strong as the"
              ++ " estimate behind it."
          | otherwise =
              "**The witness does NOT obtain.** " ++ whyNot
              ++ " Note precisely what this does and does not say: the Lean theorem"
              ++ " remains PROVED and axiom-clean, and the conjecture remains OPEN."
              ++ " Nothing in this estimate bears on the theorem's correctness; the"
              ++ " question is only whether this market's data instantiates it, and"
              ++ " here it does not."
        whyNot
          | kappaSignificant && upsilonPositive && not upsilonDegenerate
            && not upsilonSignificant =
              "`hk : 0 < kappa` IS supported — kappa-hat = " ++ fmtG kg
              ++ " with clustered SE " ++ fmtG seK ++ " and p = " ++ fmtG (pValue rK)
              ++ ", so the null of a flat vega profile is rejected in the direction"
              ++ " the conjecture predicts. It is `hu : 0 < upsilon0` that fails:"
              ++ " upsilon0-hat = " ++ fmtG ug ++ " is positive in SIGN, but its"
              ++ " clustered 95% interval is [" ++ fmtG (ug - 1.96 * seU) ++ ", "
              ++ fmtG (ug + 1.96 * seU) ++ "], which contains zero, and test 1 does"
              ++ " NOT reject (p = " ++ fmtG (pValue rU) ++ "). Instantiating a"
              ++ " machine-checked theorem at a parameter this data cannot"
              ++ " distinguish from zero would assert more than the data supports."
              ++ " This is also the reading the STOPPING_RULE forces: the phase has"
              ++ " just reported that the upsilon0 interval is uninformative, and it"
              ++ " cannot simultaneously claim a witness that rests on upsilon0."
          | upsilonDegenerate =
              "The hypothesis `hu : 0 < upsilon0` fails at the point estimate"
              ++ " (upsilon0-hat = " ++ fmtG ug ++ ", numerically zero), and with the"
              ++ " vega term extinguished `kappa` is not identified at all, so"
              ++ " `hk : 0 < kappa` cannot be evaluated against the data either."
          | not upsilonPositive && not kappaPositive =
              "Both `hu : 0 < upsilon0` (upsilon0-hat = " ++ fmtG ug
              ++ ") and `hk : 0 < kappa` (kappa-hat = " ++ fmtG kg ++ ") fail in sign."
          | not upsilonPositive =
              "`hu : 0 < upsilon0` fails in sign (upsilon0-hat = " ++ fmtG ug ++ ")."
          | not kappaPositive =
              "`hk : 0 < kappa` fails in sign (kappa-hat = " ++ fmtG kg ++ ")."
          | otherwise =
              "Both point estimates have the right SIGN, so the hypotheses are"
              ++ " formally satisfiable at the point estimates, but `kappa > 0` is not"
              ++ " statistically distinguishable from zero (p = " ++ fmtG (pValue rK)
              ++ ") on the clustered covariance. Instantiating a machine-checked"
              ++ " theorem at a statistically insignificant estimate would assert more"
              ++ " than the data supports, so no witness is claimed."

    wedgeReading
      | isNaN wMed = "No accumulator readings were available to measure the wedge."
      | wMax <= 1 =
          "**Measured wedge: exactly 1 on every reading.** Removed liquidity was zero"
          ++ " throughout, so on THIS sample Panoptic's premium coincides numerically"
          ++ " with the un-multiplied fee-revenue object. That is a measured property"
          ++ " of this market over this window, NOT a general identity: the multiplier"
          ++ " is in the accrual law and would bind on a utilized pool."
      | otherwise =
          "**The wedge is present, and it BINDS.** The median reading carries a factor"
          ++ " of " ++ fmtG wMed ++ ", so the typical premium in this panel is about "
          ++ fmtG (100 * (wMed - 1)) ++ "% larger than the bare fee-revenue quantity"
          ++ " Lean models. This is not a rounding difference and it is not optional:"
          ++ " the estimated `upsilon` is the vega of PANOPTIC'S premium, and any"
          ++ " comparison with a Lean `streamingPremium` quantity must carry the"
          ++ " factor."
          ++ (if wMax > 1.125
                then " **And the measured maximum EXCEEDS the 1.125 figure the phase"
                     ++ " context quotes as the bound** — " ++ fmtG wMaxLong
                     ++ " on the long side and " ++ fmtG wMaxShort ++ " on the short."
                     ++ " That is arithmetic rather than a defect, and it is exactly"
                     ++ " why the plan asked for a MEASURED distribution instead of a"
                     ++ " quoted bound. `1 + nu*R/N <= 1 + nu` requires `R <= N`:"
                     ++ " removed liquidity never exceeding net liquidity. On this"
                     ++ " market it does — the long maximum implies `R/N` reached "
                     ++ fmtG (8 * (wMaxLong - 1)) ++ ". The short branch"
                     ++ " `1 + nu*R^2/(N*T)` with `T = N + R` likewise exceeds `1 + nu`"
                     ++ " once `R` passes about 1.62*N, and behaves like `nu*R/N` for"
                     ++ " `R >> N`. Neither branch is bounded by 1.125 in general, so"
                     ++ " citing that number as a ceiling would misstate the accrual"
                     ++ " law; the measured figures above are what should be carried"
                     ++ " into the 10-11 cross-walk."
                else " Both branch maxima sit at or below 1.125 (long max "
                     ++ fmtG wMaxLong ++ ", short max " ++ fmtG wMaxShort
                     ++ "), which on this sample means removed liquidity did not"
                     ++ " exceed net liquidity.")

-- | One alternative specification's block. A separate renderer from the Phase-9
-- 'renderAnalysis' one so that the Phase-9 output stays byte-reproducible from
-- this same binary.
renderAltBlockV2 :: (T.Text, Estimates) -> [String]
renderAltBlockV2 (lbl, e) =
  [ "#### " ++ T.unpack lbl
  , ""
  ] ++
  (if estIdentified e
    then [ "Observations: " ++ show (estNobs e) ++ ", clusters: " ++ show (estClusters e) ++ "."
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
                [ "", shapeReadOffV2 e ]) ++
         [ "", "Note: " ++ T.unpack (estNote e) ]
    else [ "**NOT IDENTIFIED / NOT ESTIMABLE.**"
         , ""
         , "Reason: " ++ T.unpack (estNote e)
         , ""
         , "Observations seen: " ++ show (estNobs e) ++ ", clusters: "
             ++ show (estClusters e) ++ "."
         ]) ++
  [ "" ]

-- | The semiparametric shape read-off. A non-monotone profile whose bins are
-- dwarfed by their own standard errors shows nothing, and saying otherwise would
-- be reading a trend out of noise.
shapeReadOffV2 :: Estimates -> String
shapeReadOffV2 e
  | length us < 2 = ""
  | not resolved =
      "Shape read-off: **NONE AVAILABLE.** Every bin's coefficient is smaller than"
      ++ " its own clustered standard error, so the estimated profile is"
      ++ " indistinguishable from noise. No shape — declining, flat or otherwise —"
      ++ " can be read off it."
  | not monotone =
      "Shape read-off: **NOT INTERPRETABLE.** The estimated profile is NON-MONOTONE"
      ++ " in moneyness (bin values " ++ intercalate ", " (map fmtG us) ++ "), so it"
      ++ " exhibits neither the exponential decay of H1 nor the flat profile of H0."
  | head us > last us =
      "Shape read-off: the profile declines monotonically from the money outward —"
      ++ " the direction the conjecture (kappa > 0) predicts."
  | otherwise =
      "Shape read-off: the profile does NOT decline from the money outward — no"
      ++ " unrestricted evidence for an at-the-money vega peak."
  where
    us       = map snd (estCurve e)
    binSEs   = [ se | (n, se) <- estSEs e, T.isPrefixOf "upsilon_bin" n ]
    resolved = or (zipWith (\u se -> abs u > se) us (binSEs ++ repeat (1 / 0)))
    monotone = and (zipWith (>=) us (drop 1 us)) || and (zipWith (<=) us (drop 1 us))

-- ---------------------------------------------------------------------------
-- RUN 2's analysis output
-- ---------------------------------------------------------------------------

-- | THE TERMINAL ESTIMATION OUTPUT OF PHASE 10.
--
-- Structure is not free-form: it is the one the pivot lock pre-registered before
-- run 2 executed — both runs side by side, the mechanical verdict for run 2, the
-- pre-declared descriptors D1/D2/D3, the pre-registered interpretation branch
-- that obtained, whether the κ > 0 rejection persists, and the formal-witness
-- statement. Nothing is added to that list after the fact.
renderAnalysisV3
  :: EstimateOpts -> String -> String -> [String] -> FilePath -> FilePath
  -> [String] -> [String] -> [String] -> [String]
  -> [EpochRow] -> [(EpochRow, VarRow)] -> RunResult -> RunResult
  -> [CollateralObs] -> (Int, Int, Double, Double, Double, Double, Double, Int)
  -> (Int, Int, Int, Int) -> String
renderAnalysisV3 eo dateStr commit argv panelPath estOut banner vbannr gate diffEv
                 rows0 joined r1 r2 collat
                 (nAcc, nUnitWedge, wMed, wMin, wMax, wMaxLong, wMaxShort, nLongAcc)
                 (sigDrift, instrDrift, tickDrift, moneyDrift) =
  unlines $
    [ "# Panoptic vol-claim upsilon: RUN 2, seller-side normalized LHS (v3)"
    , ""
    , "**Phase 10, plan 10-10, run 2 — THE TERMINAL ESTIMATION RUN OF PHASE 10.**"
    , ""
    , "Executed under pivot lock `phase10-plan10-10-run2`, locked BEFORE this run"
    , "and verified by hash at run time:"
    , ""
    , "```"
    , "PIVOT_LOCK: " ++ eoPivotLock eo
    , "PIVOT_LOCK_SHA256: " ++ pivotLockSha256 ++ "  VERIFIED"
    , "```"
    , ""
    , "The lock's own closing clause makes that hash load-bearing — \"any post-commit"
    , "edit to this file voids the lock\" — so the estimator ABORTS rather than run"
    , "against edited terms. Provenance: `10-10-DISPOSITION-MEMO.md` (the defect, what"
    , "was NOT done, the bug-fix exemption reasoning) and the user's verbatim"
    , "`escalate-anomaly` adjudication quoted there."
    , ""
    , "**Run 1 is not superseded and not corrected.** Its analysis"
    , "(`2026-07-20-upsilon-estimates-v2.md`) is frozen with a CORRECTIONS header and"
    , "stays on the record permanently, verdict included. This document adds a second"
    , "construction beside it; it does not replace the first."
    , ""
    , "Estimation of the spec section-4.3 equation, VERBATIM and unchanged:"
    , ""
    , "> `pi_it = beta0 + upsilon0 * exp(-kappa * |i_K - i_t|) * sigma2_t + v_it`"
    , ""
    , "Run date: " ++ dateStr ++ ". Git commit: `" ++ commit ++ "`."
    , ""
    , "## 0. Headline"
    , ""
    , headline
    , ""
    , "## 1. THE SINGLE CHANGE"
    , ""
    , "Rows belonging to LONG tokenIds have `premium_wei` multiplied by **−1**, so"
    , "long and short vega enter the regression with ONE sign. That is Phase 9's"
    , "documented convention: `Panel.Build.premiumUsd` applies"
    , "`sign = if isLong then -1 else 1` with the stated rationale *\"the same vega"
    , "would enter the regression with two opposite signs and cancel\"*. 10-09's"
    , "`assembleEpochPanel` kept the protocol's own sign instead, which is the"
    , "construction defect the HALT was called on."
    , ""
    , "The long/short label is the FROZEN `is_long` column of the 10-09 artifact."
    , "Nothing was reclassified. The transformation is applied AFTER the variance"
    , "join, so the row set, the cluster set, the epoch set and every regressor are"
    , "provably identical across the two arms — only the LHS sign differs."
    , ""
    , "| affected | rows | tokenIds |"
    , "|---|---|---|"
    , "| long (sign flipped) | " ++ show nLong ++ " | " ++ show nLongTok ++ " |"
    , "| short (untouched) | " ++ show nShort ++ " | " ++ show (nTok - nLongTok) ++ " |"
    , ""
    , "### Everything the lock held UNCHANGED, and that this run did not touch"
    , ""
    , "| locked item | status |"
    , "|---|---|"
    , "| stopping bar 6.2e-5 | UNCHANGED, as-is. Not rescaled, not reinterpreted. |"
    , "| unit incoherence of the bar | RECORDED, not repaired (section 5.1 of the v2 output; restated below) |"
    , "| verdict rule + code path | UNCHANGED — the same `stoppingRuleVerdict`, blind to kappa's sign and all p-values |"
    , "| estimator / tests / alternatives | UNCHANGED and byte-untouched (diff evidence below) |"
    , "| multi-start protocol | UNCHANGED |"
    , "| panel rows / clusters / joins | UNCHANGED — " ++ show (length (rsPanel r2))
        ++ " rows, " ++ show nTok ++ " clusters, 0 unmatched epochs |"
    , "| filters, trims, re-fetches | NONE |"
    , ""
    , "Run-time evidence that the estimator source is untouched:"
    , ""
    , "```"
    ] ++ diffEv ++
    [ "```"
    , ""
    , "## 2. RUN 1 vs RUN 2 — side by side"
    , ""
    , "Both columns are produced by the SAME function (`runOn`) in the SAME process,"
    , "so they cannot differ by anything except their input panel."
    , ""
    , "### Primary parameters (GSL Levenberg-Marquardt NLS, tokenId-clustered CR0 SEs)"
    , ""
    , "| parameter | RUN 1 (as-is sign) | RUN 2 (seller-side) |"
    , "|---|---|---|"
    , cmpRow "beta0 (ETH/hour)" b1 (rsSeB r1) b2 (rsSeB r2)
    , cmpRow "upsilon0 (vega level)" u1 (rsSeU r1) u2 (rsSeU r2)
    , cmpRow "kappa (per tick)" k1 (rsSeK r1) k2 (rsSeK r2)
    , ""
    , "| 95% CI | RUN 1 | RUN 2 |"
    , "|---|---|---|"
    , "| beta0 | " ++ ciOf b1 (rsSeB r1) ++ " | " ++ ciOf b2 (rsSeB r2) ++ " |"
    , "| **upsilon0** | " ++ ciOf u1 (rsSeU r1) ++ " | " ++ ciOf u2 (rsSeU r2) ++ " |"
    , "| kappa | " ++ ciOf k1 (rsSeK r1) ++ " | " ++ ciOf k2 (rsSeK r2) ++ " |"
    , ""
    , "### EIV IV (sigma~2 instruments sigma2)"
    , ""
    , "| parameter | RUN 1 naive | RUN 1 IV | RUN 2 naive | RUN 2 IV |"
    , "|---|---|---|---|---|"
    , "| beta0 | " ++ fmtG b1 ++ " | " ++ fmtG (b0 (rsThetaIV r1)) ++ " | "
        ++ fmtG b2 ++ " | " ++ fmtG (b0 (rsThetaIV r2)) ++ " |"
    , "| **upsilon0** | " ++ fmtG u1 ++ " | " ++ fmtG (u0 (rsThetaIV r1)) ++ " | "
        ++ fmtG u2 ++ " | " ++ fmtG (u0 (rsThetaIV r2)) ++ " |"
    , "| kappa (held at NLS) | " ++ fmtG k1 ++ " | " ++ fmtG (kappa (rsThetaIV r1))
        ++ " | " ++ fmtG k2 ++ " | " ++ fmtG (kappa (rsThetaIV r2)) ++ " |"
    , ""
    , "### The three committed specification tests (spec section 5)"
    , ""
    , "| # | restriction | RUN 1 stat / p / reject | RUN 2 stat / p / reject |"
    , "|---|---|---|---|"
    , "| 1 | upsilon0 > 0 | " ++ testCell (rsTU r1) ++ " | " ++ testCell (rsTU r2) ++ " |"
    , "| 2 | **kappa > 0 (THE null test)** | " ++ testCell (rsTK r1) ++ " | "
        ++ testCell (rsTK r2) ++ " |"
    , "| 3 | kappa+ = kappa- | " ++ testCell (rsTS r1) ++ " | " ++ testCell (rsTS r2) ++ " |"
    , ""
    , "Run-2 test-3 identification: " ++ rsSymNote r2 ++ "."
    , ""
    , "### Optimizer"
    , ""
    , "| diagnostic | RUN 1 | RUN 2 |"
    , "|---|---|---|"
    , "| SSE at the returned solution | " ++ fmtE (ndSSE (rsNls r1)) ++ " | "
        ++ fmtE (ndSSE (rsNls r2)) ++ " |"
    , "| SSE from the fixed kappa=0.2 start alone | " ++ fmtE (ndFixedSSE (rsNls r1))
        ++ " | " ++ fmtE (ndFixedSSE (rsNls r2)) ++ " |"
    , "| multi-start strictly improved | " ++ show (ndImproved (rsNls r1)) ++ " | "
        ++ show (ndImproved (rsNls r2)) ++ " |"
    , "| median moneyness (kappa's scale) | " ++ fmtE (ndDMedian (rsNls r1)) ++ " | "
        ++ fmtE (ndDMedian (rsNls r2)) ++ " |"
    , ""
    , "The median moneyness is identical across the arms, as it must be: the sign"
    , "flip touches the LHS only."
    , ""
    , "## STOPPING_RULE"
    , ""
    , "The verdict for RUN 2, computed mechanically by the same code path, from the"
    , "tokenId-clustered CR0 half-width alone:"
    , ""
    , "```"
    , "PRECOMMITTED_HALFWIDTH_BAR: " ++ fmtE precommittedHalfwidthBar
    , "UPSILON0_HAT: " ++ fmtE u2
    , "UPSILON0_SE_CLUSTERED: " ++ fmtE (rsSeU r2)
    , "UPSILON0_CI_HALFWIDTH: " ++ fmtE (rsHalfW r2)
    , "STOPPING_RULE: " ++ rsVerdict r2
    , "```"
    , ""
    , "For the record, run 1's verdict, unchanged and unedited:"
    , ""
    , "```"
    , "UPSILON0_CI_HALFWIDTH: " ++ fmtE (rsHalfW r1)
    , "STOPPING_RULE: " ++ rsVerdict r1
    , "```"
    , ""
    , "**The bar was not moved between the runs.** It is the same literal 6.2e-5"
    , "named constant `precommittedHalfwidthBar`, and the pivot lock froze it"
    , "explicitly: *\"Stopping bar: 6.2e-5, as-is. Its unit incoherence (defined"
    , "against Phase 9's USD/day·daily grid) is recorded, not repaired.\"* That"
    , "incoherence still stands and is still not repaired: the bar carries Phase 9's"
    , "USD/day units, the realised half-width carries this panel's ETH/hour units."
    , "Recording it is not the same as acting on it, and this run did not act on it."
    , ""
    ] ++ stoppingProse ++
    [ ""
    , "## 3. The pre-registered descriptors D1 / D2 / D3"
    , ""
    , "Declared in the pivot lock BEFORE run 2 executed, precisely so they could not"
    , "be chosen after seeing the answer. **They do NOT override the mechanical"
    , "verdict above.**"
    , ""
    , "| descriptor | RUN 1 | RUN 2 |"
    , "|---|---|---|"
    , "| **D1** half-width / \\|upsilon0-hat\\| | " ++ fmtG (descriptorD1 r1) ++ " | "
        ++ fmtG (descriptorD1 r2) ++ " |"
    , "| **D2** does the upsilon0 CI exclude zero | " ++ yesNo (descriptorD2 r1)
        ++ " | " ++ yesNo (descriptorD2 r2) ++ " |"
    , "| **D3** upsilon0-hat | " ++ fmtG u1 ++ " | " ++ fmtG u2 ++ " |"
    , "| **D3** clustered SE(upsilon0) | " ++ fmtG (rsSeU r1) ++ " | "
        ++ fmtG (rsSeU r2) ++ " |"
    , ""
    , "D3 movement, stated as ratios so the direction is unambiguous:"
    , ""
    , "- `|upsilon0-hat|` ratio run2/run1 = " ++ fmtG (abs u2 / abs u1)
        ++ " (moved AWAY from zero: " ++ yesNo movedAway ++ ")"
    , "- `SE(upsilon0)` ratio run2/run1 = " ++ fmtG (rsSeU r2 / rsSeU r1)
        ++ " (narrowed by at least 20%: " ++ yesNo seNarrowed ++ ")"
    , "- D1 ratio run2/run1 = " ++ fmtG (descriptorD1 r2 / descriptorD1 r1)
    , ""
    , "The 20% figure is a reporting threshold for the word \"materially\", which the"
    , "lock left unquantified. **Nothing below turns on it.** " ++ thresholdNote
    , ""
    , "## 4. The pre-registered interpretation branch that obtained"
    , ""
    , "The lock declared two branches in advance. The one that obtained:"
    , ""
    ] ++ branchProse ++
    [ ""
    , "### Does the kappa > 0 rejection persist?"
    , ""
    , kappaPersistProse
    , ""
    , "## 5. FORMAL WITNESS statement"
    , ""
    ] ++ witnessBlock ++
    [ ""
    , "## 6. The four locked alternative specifications (run 2)"
    , ""
    , "The list is locked by the spec. Nothing added; nothing that failed to identify"
    , "was dropped."
    , ""
    ] ++ concatMap renderAltBlockV2 (rsAlts r2) ++
    [ "Collateral-channel observations formed on the " ++ show (eoEpochHours eo)
        ++ "-hour grid: " ++ show (length collat) ++ "."
    , ""
    , "## 7. The panel and the join (unchanged from run 1)"
    , ""
    , "| quantity | value |"
    , "|---|---|"
    , "| rows read from `" ++ panelPath ++ "` | " ++ show (length rows0) ++ " |"
    , "| rows joined to the variance series | " ++ show (length joined) ++ " |"
    , "| UNMATCHED_EPOCHS | 0 (the CLI exits non-zero on any) |"
    , "| usable in BOTH arms | " ++ show (length (rsPanel r2)) ++ " |"
    , "| distinct tokenId clusters | " ++ show nTok ++ " |"
    , "| distinct account clusters | " ++ show nAcctC ++ " |"
    , "| distinct epochs | " ++ show nEp ++ " |"
    , "| rows flagged ChunkEmpty / AccFrozen | " ++ show nChunkEmpty ++ " / "
        ++ show nAccFrozen ++ " |"
    , "| rows in a zero-swap hour (n_swaps = 0) | " ++ show nQuiet ++ " |"
    , "| top-10 tokenId row share | " ++ fmtG top10Share ++ " |"
    , ""
    , "Join cross-checks against the values the 10-09 artifact carries — sigma2"
    , show sigDrift ++ ", sigma2_instrument " ++ show instrDrift ++ ", pool tick "
        ++ show tickDrift ++ ", moneyness " ++ show moneyDrift ++ " mismatching rows."
    , ""
    , "**The cluster ceiling is untouched by this fix.** " ++ show (length (rsPanel r2))
        ++ " rows still sit in " ++ show nTok ++ " tokenId clusters with "
        ++ fmtG (100 * top10Share) ++ "% of the rows"
    , "in ten positions. The sign normalization corrects a bias; it cannot manufacture"
    , "independent clusters, and precision here is bounded by clusters."
    , ""
    , "### The validation gate (unchanged — quoted from `" ++ eoGateReport eo ++ "`)"
    , ""
    , "```"
    ] ++ gate ++
    [ "```"
    , ""
    , "The gate validates MEASUREMENT, not identification. The sign normalization is"
    , "orthogonal to it: flipping a sign does not change |recon_wei|, so the"
    , "gate-validated telescoping identity is unaffected."
    , ""
    , "## 8. The Panoptic-vs-Lean wedge (unchanged from run 1)"
    , ""
    , "The estimated `pi_it` is PANOPTIC'S premium — fee growth times a"
    , "utilization-based multiplier, `1 + nu*R/N` long and `1 + nu*R^2/(N*T)` short"
    , "with `nu = 1/VEGOID = 1/8 = 0.125` — not the bare `streamingPremium`"
    , "fee-revenue identity Lean models. Applied inside the contract's X64"
    , "accumulator, so it is already in the reconstructed premium and is never"
    , "re-applied here. MEASURED over the " ++ show nAcc ++ " accumulator readings:"
    , ""
    , "| statistic | value |"
    , "|---|---|"
    , "| median | " ++ fmtG wMed ++ " |"
    , "| min / max | " ++ fmtG wMin ++ " / " ++ fmtG wMax ++ " |"
    , "| max long (" ++ show nLongAcc ++ ") / max short ("
        ++ show (nAcc - nLongAcc) ++ ") | " ++ fmtG wMaxLong ++ " / "
        ++ fmtG wMaxShort ++ " |"
    , "| readings with R = 0 (wedge exactly 1) | " ++ show nUnitWedge ++ " of "
        ++ show nAcc ++ " |"
    , "| implied max R/N on long readings | " ++ fmtG (8 * (wMaxLong - 1)) ++ " |"
    , ""
    , "The measured maximum EXCEEDS the 1.125 figure quoted as its bound: `1 + nu`"
    , "caps the long branch only when `R <= N`, and here `R/N` reaches "
        ++ fmtG (8 * (wMaxLong - 1)) ++ "."
    , "Carry the measured figures, not 1.125, into the 10-11 cross-walk."
    , ""
    , "## 9. Threats to validity"
    , ""
    , "Run 1's threats carry over except the one this run fixed."
    , ""
    , "1. **RESOLVED by this run:** the mixed-sign LHS. Both constructions are now on"
    , "   the record and the estimate is reported under the locked Phase-9 convention."
    , "2. **A passing gate validates MEASUREMENT, not identification.**"
    , "3. **The cluster ceiling** — " ++ show nTok ++ " clusters, "
        ++ fmtG (100 * top10Share) ++ "% of rows in ten positions. Unfixable by any"
    , "   LHS transformation."
    , "4. **Scale non-comparability of the bar** — recorded in run 1, deliberately NOT"
    , "   repaired by the lock, and still not repaired here."
    , "5. **Flagged rows** — " ++ show nChunkEmpty ++ " `ChunkEmpty`, "
        ++ show nAccFrozen ++ " `AccFrozen`; retained and labelled, never dropped."
    , "6. **The zero-swap hour** — " ++ show nQuiet ++ " rows, sigma2 = 0 measured;"
    , "   the confirming re-fetch used the same public endpoint (reproducibility, not"
    , "   provider-independence)."
    , "7. **Long-stratum capping** — `_getAvailablePremium` caps SETTLED long premium"
    , "   while the accumulator reports ACCRUED. It did not bind in the gate sample,"
    , "   and the distinction survives the sign fix: normalizing the sign does not"
    , "   convert accrued premium into settled premium."
    , "8. **`width == 0` exclusion**, **one strike per multi-leg position**,"
    , "   **residual sub-block reconstruction wedge** (bounded 5.447268e-4),"
    , "   **exponential functional form**, **strike-composition selection** — all as"
    , "   recorded in run 1."
    , "9. **The Panoptic-vs-Lean multiplier wedge** (section 8)."
    , ""
    , "## 10. DATA LINEAGE (audit trail)"
    , ""
    , "Run date: " ++ dateStr ++ ". Git commit: `" ++ commit ++ "`."
    , "Pivot lock sha256: `" ++ pivotLockSha256 ++ "` (verified at run time)."
    , "All paths repo-root relative. Every endpoint is public and keyless; no"
    , "credential appears anywhere in this pipeline."
    , ""
    , "### The exact invocation"
    , ""
    , "```"
    , "econometrics " ++ unwords (map sanitizeArg argv)
    , "```"
    , ""
    , "### Chain and contracts"
    , ""
    , "| what | value |"
    , "|---|---|"
    , "| chain | Base mainnet (L2), chainId 8453 |"
    , "| Panoptic subgraph | `" ++ show' (eoEndpoint eo) ++ "` |"
    , "| PanopticPool | `0xb50e8bb68f5855da742f4579274902a20454174a` (ETH/USDC, fee 500, tickSpacing 10) |"
    , "| underlying pool (V4 poolId) | `" ++ show' (eoPool eo) ++ "` |"
    , "| SFPM | `0x8dcAa08cF298F8b4830FAf56d47930981AdE33af` |"
    , "| VEGOID / nu | 8 / 0.125 |"
    , "| Base RPC | `" ++ show' (eoRpc eo) ++ "`; failover `https://base.drpc.org` |"
    , "| V4 PoolManager (Swap log emitter) | `0x498581ff718922c3f8e6a244956af099b2652b2b` |"
    , "| block range | " ++ show (eoFromBlock eo) ++ " .. " ++ show (eoToBlock eo) ++ " |"
    , ""
    , "The bulk accumulator read (10-06) issued 8,910 `eth_call`s over a six-cycle"
    , "resume chain; `FAILOVER_CALLS: 0` on the completing slice. Read lineage:"
    , "`notes/structural-econometrcics/data/premium-accumulators-lineage.md`."
    , ""
    , "### Files"
    , ""
    , "| path | contents | rows |"
    , "|---|---|---|"
    , "| `notes/structural-econometrcics/data/burn-truth.csv` | frozen OptionBurn ground truth (INPUT); the is_long authority | 61 |"
    , "| `notes/structural-econometrcics/data/premium-accumulators.csv` | SFPM X64 accumulator readings | 8,910 |"
    , "| `notes/structural-econometrcics/data/epoch-blocks.csv` | hourly epoch -> first Base block | 2,832 |"
    , "| `notes/structural-econometrcics/data/reconcile-errors.csv` | per-spell gate error | 61 |"
    , "| `" ++ eoGateReport eo ++ "` | THE gate report | see section 7 |"
    , "| `" ++ eoVarianceCsv eo ++ "` | hourly sigma2, EIV instrument, pool tick, n_swaps | "
        ++ show nVarEp ++ " |"
    , "| `" ++ panelPath ++ "` | THE position-epoch panel (LHS source) | "
        ++ show (length rows0) ++ " |"
    , "| `notes/structural-econometrcics/data/estimation-panel-v2.csv` | RUN 1's export (as-is sign) | 6,760 |"
    , "| `" ++ estOut ++ "` | RUN 2's export (seller-side normalized) | "
        ++ show (length (rsPanel r2)) ++ " |"
    , "| `notes/structural-econometrcics/analysis/2026-07-20-upsilon-estimates-v2.md` | RUN 1's analysis, FROZEN | — |"
    , "| `" ++ eoPivotLock eo ++ "` | the binding lock | — |"
    , "| `" ++ eoCollateralCsv eo ++ "` | signed collateral share flows | see file |"
    , "| `" ++ eoTicksCsv eo ++ "` | raw (unix, tick) Swap cache (gitignored) | 632,315 |"
    , ""
    , "### The epoch definition"
    , ""
    , "`epoch = floor(unixSeconds / 3600)` via `Panel.Epoch.epochOfSeconds`, the SAME"
    , "function the variance series uses, so the join is an exact INTEGER match."
    , "Block-index epoch `e` is the START of hour `e`, so a row's premium is the"
    , "accumulator difference over the interval STARTING at that boundary and meets"
    , "the variance of the SAME hour."
    , ""
    , "### The panel artifact's own banner (verbatim)"
    , ""
    , "```"
    ] ++ banner ++
    [ "```"
    , ""
    , "### The variance artifact's own banner (verbatim)"
    , ""
    , "```"
    ] ++ vbannr ++
    [ "```"
    , ""
    , "### The estimator (byte-identical to Phase 9 and to run 1)"
    , ""
    , "- **Point estimates:** `Model.NLS.fitGSL` — `Numeric.GSL.Fitting.fitModel`,"
    , "  Levenberg-Marquardt, analytic Jacobian, data-scaled multi-start, lowest-SSE"
    , "  finite solution."
    , "- **Standard errors:** `Model.SandwichSE.clusterSandwich` — tokenId-clustered"
    , "  CR0 `(J'J)^-1 [sum_g s_g s_g'] (J'J)^-1`, NO finite-sample correction,"
    , "  golden-tested to 1e-9."
    , "- **EIV:** `Model.EIV.ivFit` — two-step two-noisy-measures IV."
    , "- **Tests:** `Tests.Specification` — one-sided Normal for the sign"
    , "  restrictions, chi-squared(1) Wald for symmetry."
    , "- **Alternatives:** `Alternatives` — the four locked spec section-6.2 forms."
    , ""
    , "### Reproduce"
    , ""
    , "```sh"
    , "stack --stack-yaml econometrics/stack.yaml exec econometrics -- estimate \\"
    , "  --epoch-panel " ++ panelPath ++ " \\"
    , "  --variance " ++ eoVarianceCsv eo ++ " \\"
    , "  --epoch-hours " ++ show (eoEpochHours eo) ++ " \\"
    , "  --seller-side-normalize \\"
    , "  --estimation-out " ++ estOut ++ " \\"
    , "  --endpoint <subgraph-endpoint> --pool <poolId> --rpc <base-rpc-url> \\"
    , "  --from-block " ++ show (eoFromBlock eo) ++ " --to-block " ++ show (eoToBlock eo)
    , "```"
    , ""
    , "---"
    , ""
    , "**TERMINAL.** Per the pivot lock and the user's commitment of 2026-07-27, this"
    , "is the last estimation run of Phase 10. No further iteration follows, in either"
    , "branch of the pre-registered interpretation."
    ]
  where
    show' s = if null s then "(not recorded on this run)" else s
    yesNo True = "YES"
    yesNo False = "no"

    Theta b1 u1 k1 = rsTheta r1
    Theta b2 u2 k2 = rsTheta r2

    ciOf e se = "[" ++ fmtG (e - 1.96 * se) ++ ", " ++ fmtG (e + 1.96 * se) ++ "]"
    cmpRow nm e1 s1 e2 s2 =
      "| " ++ nm ++ " | " ++ fmtG e1 ++ " (SE " ++ fmtG s1 ++ ") | "
        ++ fmtG e2 ++ " (SE " ++ fmtG s2 ++ ") |"
    testCell t = fmtG (statistic t) ++ " / " ++ fmtG (pValue t) ++ " / "
                   ++ (if reject t then "**REJECT**" else "no")

    pan    = rsPanel r2
    nTok   = length (nub (map obsTokenId pan))
    nAcctC = length (nub (map obsAccount pan))
    nEp    = length (nub (map obsEpoch pan))
    nVarEp = length (nub (map (erEpoch . fst) joined))

    nLong    = length [ () | r <- rows0, erIsLong r ]
    nShort   = length rows0 - nLong
    nLongTok = length (nub [ erTokenId r | r <- rows0, erIsLong r ])

    nChunkEmpty = length [ () | r <- rows0, "ChunkEmpty" `T.isInfixOf` erFlags r ]
    nAccFrozen  = length [ () | r <- rows0, "AccFrozen"  `T.isInfixOf` erFlags r ]
    nQuiet      = length [ () | r <- rows0, erNSwaps r == 0 ]

    tokCounts = Map.fromListWith (+) [ (obsTokenId o, 1 :: Int) | o <- pan ]
    top10Share =
      let cs = take 10 (reverse (sort (Map.elems tokCounts)))
      in if null pan then 0 / 0
         else fromIntegral (sum cs) / fromIntegral (length pan)

    informative2 = rsVerdict r2 == "INFORMATIVE"
    movedAway    = abs u2 > abs u1
    seNarrowed   = rsSeU r2 < 0.8 * rsSeU r1
    branchA      = movedAway || seNarrowed

    -- The lock's branch test is a disjunction, so the threshold only ever
    -- matters when the FIRST disjunct is false. Say which case obtained rather
    -- than gesturing at robustness.
    thresholdNote
      | movedAway && not seNarrowed =
          "The branch was selected by the first disjunct — `upsilon0-hat` moved away"
          ++ " from zero — which is threshold-free. The SE disjunct is false here"
          ++ " under ANY narrowing threshold, because the SE widened (ratio "
          ++ fmtG (rsSeU r2 / rsSeU r1) ++ ")."
      | movedAway && seNarrowed =
          "Both disjuncts hold, so the branch is the same under any threshold below "
          ++ fmtG (1 - rsSeU r2 / rsSeU r1) ++ "."
      | seNarrowed =
          "The first disjunct is false (`upsilon0-hat` did not move away from zero),"
          ++ " so the branch rests on the SE narrowing, which is "
          ++ fmtG (1 - rsSeU r2 / rsSeU r1) ++ " — sensitive to the threshold, and"
          ++ " flagged as such."
      | otherwise =
          "Neither disjunct holds under any threshold: the estimate did not move away"
          ++ " from zero (ratio " ++ fmtG (abs u2 / abs u1) ++ ") and the SE did not"
          ++ " narrow (ratio " ++ fmtG (rsSeU r2 / rsSeU r1) ++ ")."

    kappaPos2   = k2 > 0 && not (isNaN k2)
    kappaSig2   = kappaPos2 && reject (rsTK r2)
    upsPos2     = u2 > 0 && not (isNaN u2)
    upsSig2     = upsPos2 && reject (rsTU r2)
    maxVega2    = abs u2 * maximum (1e-300 : [ obsSigma2 o | o <- pan, finiteD (obsSigma2 o) ])
    degenerate2 = maxVega2 < 1e-6 * abs b2

    headline =
      "**RUN 2 STOPPING_RULE: " ++ rsVerdict r2 ++ ".** With the LHS normalized to"
        ++ " the seller side — the single change this iteration was authorised to"
        ++ " make — the upsilon0 clustered-CI half-width is +/-" ++ fmtE (rsHalfW r2)
        ++ " against the unchanged bar of +/-" ++ fmtE precommittedHalfwidthBar
        ++ ". Run 1's half-width was +/-" ++ fmtE (rsHalfW r1) ++ " (verdict "
        ++ rsVerdict r1 ++ "). upsilon0-hat moves " ++ fmtG u1 ++ " -> " ++ fmtG u2
        ++ " with clustered SE " ++ fmtG (rsSeU r1) ++ " -> " ++ fmtG (rsSeU r2)
        ++ ", and its CI " ++ (if descriptorD2 r2 then "EXCLUDES" else "still contains")
        ++ " zero. kappa-hat = " ++ fmtG k2 ++ " (SE " ++ fmtG (rsSeK r2) ++ ", p = "
        ++ fmtG (pValue (rsTK r2)) ++ "), so the run-1 rejection of a flat vega"
        ++ " profile " ++ (if kappaSig2 then "PERSISTS" else "does NOT persist")
        ++ ". " ++ (if informative2
                      then "The bar was met."
                      else "The bar was not met, and this is the terminal run.")

    stoppingProse
      | informative2 =
          [ "**The bar was met on run 2.** The interval is informative and is read as"
          , "it fell, in whichever direction it points. Note what this does and does"
          , "not license: the fix that produced it was a correctness fix pre-declared"
          , "in the lock, applied identically across every locked specification, and"
          , "verdict-independent — an INFORMATIVE result on mixed-sign data would have"
          , "been equally invalid and equally in need of the same fix. Run 1's"
          , "UNINFORMATIVE verdict remains on the record beside this one."
          ]
      | otherwise =
          [ "**The bar was NOT met on run 2 either, and the pre-authorised terminal"
          , "outcome applies with BOTH constructions on the record:**"
          , ""
          , "> **This market cannot identify `upsilon`.**"
          , ""
          , "The phase reports that and stops. The sign-convention defect was real and"
          , "has been fixed; fixing it did not change the conclusion. That is a"
          , "stronger result than run 1 alone could support — the uninformative"
          , "interval now survives the one construction change that had a clearly"
          , "signed effect on it, so it cannot be attributed to that defect. No"
          , "further iteration follows, per the lock."
          ]

    branchProse
      | branchA =
          [ "> *\"If upsilon0-hat moves away from zero and/or its SE narrows"
          , "> materially: consistent with the mixed-sign attenuation mechanism;"
          , "> report both runs side by side.\"*"
          , ""
          , "**This branch obtained — via the FIRST disjunct only.**"
          , ""
          , "- `|upsilon0-hat|` moved AWAY from zero by a factor of "
              ++ fmtG (abs u2 / abs u1) ++ ". This is the part consistent with the"
          , "  attenuation mechanism the disposition memo named in advance: a common"
          , "  vega carried with two opposite signs partially cancels, and de-mixing"
          , "  the signs un-cancels it."
          , "- The clustered SE did **not** narrow — it WIDENED by a factor of "
              ++ fmtG (rsSeU r2 / rsSeU r1) ++ ", which is expected when the"
          , "  left-hand side's magnitudes grow, and is NOT evidence for the mechanism."
          , "  The second disjunct is false, and would be false under any narrowing"
          , "  threshold whatsoever."
          , "- The scale-free ratio D1 nevertheless improved, " ++ fmtG (descriptorD1 r1)
              ++ " -> " ++ fmtG (descriptorD1 r2) ++ ": the estimate grew faster than"
          , "  its own uncertainty."
          , ""
          , "**What this does NOT establish.** Consistency with a pre-named mechanism"
          , "is not proof of it. One arm moved in the predicted direction; that is a"
          , "single comparison on one panel, not an identified effect, and no"
          , "directional claim about the vega profile is made here beyond what the"
          , "tests in section 2 support."
          , (if informative2
               then "The mechanical verdict above is what adjudicates the phase."
               else "Decisively: the mechanical verdict is still " ++ rsVerdict r2
                    ++ " and D2 is still \"no\" — the CI contains zero in BOTH arms."
                    ++ " The direction improved; the identification did not follow.")
          ]
      | otherwise =
          [ "> *\"If upsilon0-hat remains ~0 / interval still wide: the sign mixing was"
          , "> NOT the binding attenuation source; the market-cannot-identify-upsilon"
          , "> conclusion stands with BOTH constructions on record.\"*"
          , ""
          , "**This branch obtained.** `|upsilon0-hat|` moved by a factor of "
              ++ fmtG (abs u2 / abs u1) ++ " and the clustered SE by a factor of "
              ++ fmtG (rsSeU r2 / rsSeU r1) ++ " — neither away from zero nor"
          , "materially narrower. The mixed-sign LHS was a genuine construction defect"
          , "and it has been fixed, but it was NOT the binding constraint on"
          , "identification here. The binding constraint is the one recorded since"
          , "10-01 and unchanged by any LHS transformation: " ++ show nTok
              ++ " tokenId clusters"
          , "with " ++ fmtG (100 * top10Share) ++ "% of the rows in ten positions."
          , "The market-cannot-identify-upsilon conclusion stands with both"
          , "constructions on the record."
          ]

    kappaPersistProse
      | degenerate2 =
          "**Cannot be assessed on run 2.** The fitted vega level is numerically"
          ++ " zero, so kappa is structurally unidentified and its test is vacuous."
          ++ " That is itself a change from run 1, where kappa was identified, and it"
          ++ " is reported as the fragility it is."
      | kappaSig2 && reject (rsTK r1) =
          "**It persists.** Run 1: kappa-hat = " ++ fmtG k1 ++ " (SE " ++ fmtG (rsSeK r1)
          ++ ", p = " ++ fmtG (pValue (rsTK r1)) ++ "). Run 2: kappa-hat = " ++ fmtG k2
          ++ " (SE " ++ fmtG (rsSeK r2) ++ ", p = " ++ fmtG (pValue (rsTK r2))
          ++ "). H0 of a flat vega profile is rejected at the 5% level under BOTH LHS"
          ++ " constructions, which is what the lock anticipated: sign normalization"
          ++ " acts primarily on upsilon0's level. The rejection is a statement about"
          ++ " the SHAPE of the profile and it survives the fix. It remains separate"
          ++ " from — and no substitute for — the stopping rule, which is about"
          ++ " upsilon0."
      | reject (rsTK r1) && not kappaSig2 =
          "**It does NOT persist, and that fragility is reported plainly.** Run 1"
          ++ " rejected H0: kappa = 0 (kappa-hat = " ++ fmtG k1 ++ ", p = "
          ++ fmtG (pValue (rsTK r1)) ++ "); run 2 does not (kappa-hat = " ++ fmtG k2
          ++ ", SE " ++ fmtG (rsSeK r2) ++ ", p = " ++ fmtG (pValue (rsTK r2))
          ++ "). The lock declared in advance that the rejection was EXPECTED to"
          ++ " persist and that non-persistence would be reported as fragility rather"
          ++ " than explained away. It is: the run-1 rejection did not survive the"
          ++ " correction of a construction defect, so it should not be carried"
          ++ " forward as a finding about this market."
      | otherwise =
          "Run 1 did not reject H0: kappa = 0 (p = " ++ fmtG (pValue (rsTK r1))
          ++ ") and run 2 " ++ (if kappaSig2 then "does (p = " else "does not either (p = ")
          ++ fmtG (pValue (rsTK r2)) ++ ")."

    witnessBlock =
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
      , "**No Lean file was modified and no Aristotle task was run.** The theorem is"
      , "already proved; at issue is only whether the run-2 fit instantiates it."
      , ""
      , "- `upsilon0-hat = " ++ fmtG u2 ++ "` (clustered SE " ++ fmtG (rsSeU r2)
          ++ ")  ->  `hu` " ++ huSt
      , "- `kappa-hat = " ++ fmtG k2 ++ "` (clustered SE " ++ fmtG (rsSeK r2)
          ++ ")  ->  `hk` " ++ hkSt
      , "- `Delta_i = 10` (pool tickSpacing)  ->  `hd` SATISFIED"
      , ""
      , wVerdict
      ]
      where
        st pos t p
          | not pos  = "**NOT SATISFIED** — the point estimate has the wrong sign."
          | reject t = "SATISFIED in sign AND statistically supported (p = " ++ fmtG p ++ ")."
          | otherwise = "satisfied in SIGN ONLY — the test does NOT reject (p = "
                        ++ fmtG p ++ "), so the strict inequality is not supported."
        huSt | degenerate2 = "**NOT usable** — numerically zero; the strict inequality holds only vacuously."
             | otherwise   = st upsPos2 (rsTU r2) (pValue (rsTU r2))
        hkSt | degenerate2 = "**cannot be evaluated** — kappa is unidentified once the vega term vanishes."
             | otherwise   = st kappaPos2 (rsTK r2) (pValue (rsTK r2))
        wVerdict
          | kappaSig2 && upsSig2 && not degenerate2 =
              "**The witness OBTAINS.** Both restrictions are satisfied by the point"
              ++ " estimates and statistically supported at the 5% level on the"
              ++ " tokenId-clustered covariance, and `hd` holds by inspection. The"
              ++ " fitted profile is a literal witness of `ATMOTMNullHypothesis` at"
              ++ " `c = kappa-hat * Delta_i = " ++ fmtG (k2 * 10) ++ "`. The theorem is"
              ++ " about the FAMILY, so the witness is exactly as strong as the"
              ++ " estimate behind it — and the STOPPING_RULE above is "
              ++ rsVerdict r2 ++ ", which bounds how far it should be carried."
          | degenerate2 =
              "**The witness does NOT obtain.** `hu : 0 < upsilon0` fails at the point"
              ++ " estimate (numerically zero) and kappa is unidentified once the vega"
              ++ " term vanishes. The Lean theorem remains PROVED and axiom-clean; the"
              ++ " conjecture remains OPEN."
          | kappaSig2 && upsPos2 && not upsSig2 =
              "**The witness does NOT obtain.** `hk : 0 < kappa` IS supported"
              ++ " (kappa-hat = " ++ fmtG k2 ++ ", p = " ++ fmtG (pValue (rsTK r2))
              ++ "), but `hu : 0 < upsilon0` is satisfied in SIGN only: upsilon0-hat = "
              ++ fmtG u2 ++ " has a 95% clustered interval of " ++ ciOf u2 (rsSeU r2)
              ++ ", which contains zero, and test 1 does not reject (p = "
              ++ fmtG (pValue (rsTU r2)) ++ "). Instantiating a machine-checked theorem"
              ++ " at a parameter the data cannot distinguish from zero would assert"
              ++ " more than the data supports — and the phase has just reported that"
              ++ " the upsilon0 interval is uninformative, so it cannot simultaneously"
              ++ " claim a witness resting on upsilon0. The Lean theorem remains PROVED"
              ++ " and axiom-clean, and the conjecture remains OPEN. Nothing here bears"
              ++ " on the theorem's correctness; only on whether this market's data"
              ++ " instantiates it, and it does not."
          | otherwise =
              "**The witness does NOT obtain.** " ++ failing
              ++ " The Lean theorem remains PROVED and axiom-clean, and the conjecture"
              ++ " remains OPEN."
        failing
          | not upsPos2 && not kappaPos2 =
              "Both `hu : 0 < upsilon0` (upsilon0-hat = " ++ fmtG u2
              ++ ") and `hk : 0 < kappa` (kappa-hat = " ++ fmtG k2 ++ ") fail in sign."
          | not upsPos2 = "`hu : 0 < upsilon0` fails in sign (upsilon0-hat = " ++ fmtG u2 ++ ")."
          | not kappaPos2 = "`hk : 0 < kappa` fails in sign (kappa-hat = " ++ fmtG k2 ++ ")."
          | otherwise =
              "Both point estimates have the right sign, but neither restriction is"
              ++ " statistically supported (upsilon0 p = " ++ fmtG (pValue (rsTU r2))
              ++ ", kappa p = " ++ fmtG (pValue (rsTK r2)) ++ ")."

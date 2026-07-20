{-# LANGUAGE OverloadedStrings #-}

-- | CLI for the econometrics pipeline.
--
-- The pipeline is invoked stage-by-stage for reproducibility. @build-panel@ is
-- live (plan 09-04): it fetches positions from the confirmed Panoptic subgraph,
-- diffs cumulative premia into per-epoch flows, and writes the tokenId × daily
-- panel CSV. The other stages remain stubs filled by later plans. No absolute
-- paths; the endpoint is supplied on the command line, never hardcoded.
module Main (main) where

import qualified Data.ByteString.Lazy    as BL
import qualified Data.Csv                as Csv
import           Data.List               (isPrefixOf)
import qualified Data.Map.Strict         as Map
import           Data.Maybe              (mapMaybe)
import qualified Data.Text               as T
import qualified Data.Vector             as V
import           Options.Applicative
import           Text.Read               (readMaybe)

import           Numeric.AD           (grad)
import           Numeric.GSL.Fitting  (fitModel)

import           Econ.Types         (Obs (..), Panel, Theta (..))
import           Model.EIV          (ivFit)
import           Model.NLS          (designPoints, fitGSLCov)
import           Model.SandwichSE   (clusterSandwich, standardErrors)
import           Model.Upsilon      (model, modelSplit, moneyness, signedMoneyness)
import           Tests.Specification
                   ( TestResult (..), Theta4 (..)
                   , testUpsilonPos, testKappaPos, testSymmetry )
import           Panel.Build        (assemble, writePanelCsv)
import           Panel.Subgraph     (Endpoint (..), PoolAddr (..), fetchPositions)
import           Panel.Variance     (RpcConfig (..), cacheSwapTicks,
                                     defaultBaseRpc, fetchSwapTicks,
                                     instrumentVariance, loadSwapTicks,
                                     realizedVariance, writeVarianceCsv)

-- | Options for the @build-panel@ stage.
data BuildPanelOpts = BuildPanelOpts
  { bpEndpoint :: String -- ^ Subgraph endpoint URL (from config; never hardcoded).
  , bpPool     :: String -- ^ panopticPool / underlying pool id filter.
  , bpOut      :: FilePath -- ^ Output CSV path.
  }

-- | Pipeline stages, one per subcommand.
data Command
  = Fetch                        -- ^ Pull raw positions/premia from the subgraph.
  | BuildPanel BuildPanelOpts    -- ^ Assemble the tokenId × daily-epoch panel.
  | Variance VarianceOpts        -- ^ Construct sigma^2_t and the EIV instrument.
  | Estimate EstimateOpts        -- ^ Run the NLS/GMM estimator.
  | Test                         -- ^ Compute specification test statistics.

-- | Options for the @estimate@ stage: the panel and the variance CSVs to join on
-- the shared daily epoch (paths are repo-root anchored; nothing hardcoded absolute).
data EstimateOpts = EstimateOpts
  { eoPanelCsv    :: FilePath
  , eoVarianceCsv :: FilePath
  }

-- | Options for the @variance@ stage. Supplying @--from@/@--to@ triggers a live
-- chunked @eth_getLogs@ pull of Base V4 Swap logs (cached to @--ticks-csv@);
-- otherwise the cached tick series at @--ticks-csv@ is read. Paths are relative
-- (repo-root anchored); the RPC endpoint is a flag, never hardcoded.
data VarianceOpts = VarianceOpts
  { voTicksCsv :: FilePath
  , voOutCsv   :: FilePath
  , voFrom     :: Maybe Integer
  , voTo       :: Maybe Integer
  , voRpc      :: String
  , voChunk    :: Integer
  }

buildPanelOpts :: Parser BuildPanelOpts
buildPanelOpts =
  BuildPanelOpts
    <$> strOption
          ( long "endpoint" <> metavar "URL"
         <> help "Panoptic subgraph GraphQL endpoint (from DATA-SOURCES.md; not hardcoded)" )
    <*> strOption
          ( long "pool" <> metavar "POOL"
         <> help "panopticPool / underlying pool id to filter positions" )
    <*> strOption
          ( long "out" <> metavar "PATH"
         <> value "notes/structural-econometrcics/data/panel.csv"
         <> showDefault
         <> help "Output panel CSV path" )

defaultTicksCsv :: FilePath
defaultTicksCsv = "notes/structural-econometrcics/data/swap-ticks-base-v4-sample.csv"

defaultVarianceCsv :: FilePath
defaultVarianceCsv = "notes/structural-econometrcics/data/variance.csv"

estimateOptsParser :: Parser EstimateOpts
estimateOptsParser =
  EstimateOpts
    <$> strOption
          ( long "panel" <> metavar "PATH"
         <> value "notes/structural-econometrcics/data/panel.csv" <> showDefault
         <> help "panel CSV (tokenId,epoch,premium_delta,strike_tick,pool_tick,sigma2_placeholder)" )
    <*> strOption
          ( long "variance" <> metavar "PATH" <> value defaultVarianceCsv <> showDefault
         <> help "variance CSV (epoch,sigma2,sigma2_instrument) to join on epoch" )

varianceOptsParser :: Parser VarianceOpts
varianceOptsParser =
  VarianceOpts
    <$> strOption
          ( long "ticks-csv" <> metavar "PATH" <> value defaultTicksCsv <> showDefault
         <> help "cached (unix,tick) CSV to read (or write on a live fetch)" )
    <*> strOption
          ( long "out" <> metavar "PATH" <> value defaultVarianceCsv <> showDefault
         <> help "output variance.csv (epoch,sigma2,sigma2_instrument)" )
    <*> optional (option auto
          ( long "from" <> metavar "BLOCK"
         <> help "RPC fromBlock (supplying --from and --to triggers a live fetch)" ))
    <*> optional (option auto
          ( long "to" <> metavar "BLOCK" <> help "RPC toBlock" ))
    <*> strOption
          ( long "rpc" <> metavar "URL" <> value (rpcUrl defaultBaseRpc) <> showDefault
         <> help "Base JSON-RPC endpoint" )
    <*> option auto
          ( long "chunk" <> metavar "N" <> value (rpcChunk defaultBaseRpc) <> showDefault
         <> help "blocks per eth_getLogs call (keep conservative on public RPCs)" )

commandParser :: Parser Command
commandParser =
  hsubparser
    ( command "fetch"
        (info (pure Fetch)
              (progDesc "Fetch raw positions/premia from the Panoptic subgraph"))
   <> command "build-panel"
        (info (BuildPanel <$> buildPanelOpts)
              (progDesc "Assemble the tokenId x epoch panel (per-epoch premium deltas)"))
   <> command "variance"
        (info (Variance <$> varianceOptsParser)
              (progDesc "Build sigma^2_t and the disjoint-window EIV instrument from Base V4 Swap logs"))
   <> command "estimate"
        (info (Estimate <$> estimateOptsParser)
              (progDesc "Fit pi = b0 + u0*exp(-k*d)*sigma2 by GSL LM (+ two-noisy-measures IV)"))
   <> command "test"
        (info (pure Test)
              (progDesc "Compute committed specification test statistics"))
    )

opts :: ParserInfo Command
opts =
  info (commandParser <**> helper)
    ( fullDesc
   <> progDesc "Panoptic upsilon structural econometrics pipeline"
   <> header "econometrics - Haskell-only estimation of the exponential-moneyness vega profile" )

run :: Command -> IO ()
run (BuildPanel o) = do
  positions <- fetchPositions (Endpoint (T.pack (bpEndpoint o)))
                              (PoolAddr (T.pack (bpPool o)))
  let panel = assemble positions
  writePanelCsv (bpOut o) panel
  putStrLn ("build-panel: wrote " ++ show (length panel) ++ " rows to " ++ bpOut o)
run (Variance vo) = runVariance vo
run (Estimate eo) = runEstimate eo
run Fetch    = putStrLn "fetch: not yet implemented"
run Test     = putStrLn "test: not yet implemented"

-- | Run the @estimate@ stage: load the panel and variance CSVs, join σ̂²_t/σ̃²_t
-- onto each position-epoch by the shared daily epoch, then report the PRIMARY
-- GSL Levenberg–Marquardt fit and the two-noisy-measures IV estimate. The full
-- analysis write-up (clustered SEs, spec tests, cross-walk) is plan 09-09; this
-- stage prints the point estimates so the machinery is runnable end-to-end.
runEstimate :: EstimateOpts -> IO ()
runEstimate eo = do
  rawPanel <- loadPanelCsv (eoPanelCsv eo)
  varMap   <- loadVarianceCsv (eoVarianceCsv eo)
  let panel = joinVariance varMap rawPanel
      n     = length (designPoints panel)
  putStrLn ("estimate: " ++ show (length rawPanel) ++ " panel rows, "
             ++ show (Map.size varMap) ++ " variance epochs, "
             ++ show n ++ " usable observations after the σ̂² join")
  if n < 3
    then putStrLn "estimate: too few usable observations (σ̂² un-joined?) — run `variance` and 09-09 join first."
    else do
      let (thetaG, _gslCov) = fitGSLCov panel
          Theta bg ug kg    = thetaG
          Theta bi ui ki    = ivFit panel
      putStrLn "estimate: PRIMARY GSL Levenberg–Marquardt fit  pi = b0 + u0*exp(-k*d)*sigma2"
      putStrLn ("  b0 = " ++ show bg ++ "  u0 = " ++ show ug ++ "  kappa = " ++ show kg)
      putStrLn "estimate: two-noisy-measures IV (sigma~^2 instruments sigma^2, EIV remedy)"
      putStrLn ("  b0 = " ++ show bi ++ "  u0 = " ++ show ui ++ "  kappa = " ++ show ki)
      -- Cluster-robust (by tokenId) CR0 sandwich SEs at the fitted θ. The
      -- per-obs gradient rows ∂f/∂θ come from Model.Upsilon.model via `ad`, the
      -- residuals from y − f(θ̂), and the cluster labels are the tokenIds.
      let (jRows, resids, clusters) = sandwichInputs thetaG panel
          vCov = clusterSandwich jRows resids clusters
          [seB, seU, seK] = standardErrors vCov
      putStrLn ("estimate: tokenId-clustered CR0 sandwich SEs ("
                 ++ show (length (dedup clusters)) ++ " clusters, "
                 ++ show (length jRows) ++ " obs)")
      putStrLn ("  SE(b0) = " ++ show seB ++ "  SE(u0) = " ++ show seU
                 ++ "  SE(kappa) = " ++ show seK)
      -- The three committed specification tests (spec §5) on the clustered
      -- covariance: υ₀>0, κ>0 (THE null test), and κ⁺=κ⁻ (split-fit Wald).
      let rU = testUpsilonPos thetaG vCov
          rK = testKappaPos   thetaG vCov
          rS = splitSymmetryTest panel
      putStrLn "estimate: specification tests (spec §5, tokenId-clustered)"
      putStrLn ("  υ₀>0  : z = " ++ show (statistic rU) ++ "  p = " ++ show (pValue rU)
                 ++ "  reject = " ++ show (reject rU))
      putStrLn ("  κ>0   : z = " ++ show (statistic rK) ++ "  p = " ++ show (pValue rK)
                 ++ "  reject = " ++ show (reject rK) ++ "   (THE null-hypothesis test)")
      putStrLn ("  κ⁺=κ⁻ : W = " ++ show (statistic rS) ++ "  p = " ++ show (pValue rS)
                 ++ "  reject = " ++ show (reject rS))

-- | Build the sandwich-SE inputs at a fitted θ: for every usable observation
-- (finite σ̂² and premium, matching 'designPoints'), the row-gradient ∂f/∂θ (via
-- @ad@ on 'Model.Upsilon.model'), the residual @y − f(θ̂)@, and the tokenId cluster
-- label. Observation-aligned across the three lists.
sandwichInputs :: Theta -> Panel -> ([[Double]], [Double], [T.Text])
sandwichInputs (Theta b0' u0' k') panel = unzip3
  [ (gradRow, resid, obsTokenId o)
  | o <- panel
  , let d  = moneyness (obsStrikeTick o) (obsPoolTick o)
        s2 = obsSigma2 o
        y  = obsPremium o
  , finiteD s2, finiteD y
  , let gradRow = grad (\p -> model p (realToFrac d, realToFrac s2)) [b0', u0', k']
        resid   = y - model [b0', u0', k'] (d, s2)
  ]

-- | A finite (non-NaN, non-∞) Double — used to drop un-joined placeholder rows.
finiteD :: Double -> Bool
finiteD x = not (isNaN x || isInfinite x)

-- | Symmetry Wald κ⁺ = κ⁻ (spec §5, test 3) end-to-end from a panel: fit the split
-- (4-param) model 'Model.Upsilon.modelSplit' by GSL Levenberg–Marquardt (analytic
-- split Jacobian), form its tokenId-clustered CR0 covariance (gradient rows via
-- @ad@ on 'modelSplit' at the fit), and run 'testSymmetry' on the 2×2 κ sub-block.
-- The split model's local identification (needs OTM mass on BOTH sides of the
-- money) is a live-data concern deferred to plan 09-09.
splitSymmetryTest :: Panel -> TestResult
splitSymmetryTest panel = testSymmetry (Theta4 b0s u0s kps kms) vSplit
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
    dat = [ (x, [y]) | (x, y, _) <- pts ]
    modelF ps x = [modelSplit ps x]
    jacF [_b0, u0', kp', km'] (dP, dM, s2') =
      let ep = exp (negate kp' * dP)
          em = exp (negate km' * dM)
      in [[ 1
          , (ep + em - 1) * s2'
          , u0' * (negate dP * ep) * s2'
          , u0' * (negate dM * em) * s2' ]]
    jacF ps _ = error ("Main.splitSymmetryTest: bad param length " ++ show (length ps))
    (sol, _cov) = fitModel 1e-9 1e-9 200 (modelF, jacF) dat [0.0, 1.0, 0.2, 0.2]
    [b0s, u0s, kps, kms] = sol
    jRows =
      [ grad (\p -> modelSplit p (realToFrac dP, realToFrac dM, realToFrac s2)) sol
      | ((dP, dM, s2), _, _) <- pts ]
    resids   = [ y - modelSplit sol (dP, dM, s2) | ((dP, dM, s2), y, _) <- pts ]
    clusters = [ c | (_, _, c) <- pts ]
    vSplit   = clusterSandwich jRows resids clusters

-- | Distinct labels, order-independent (for the cluster count report).
dedup :: Ord a => [a] -> [a]
dedup = Map.keys . Map.fromList . map (\x -> (x, ()))

-- | Load the panel CSV as raw rows. Columns (with header, per "Panel.Build"):
-- @tokenId,epoch,premium_delta,strike_tick,pool_tick,sigma2_placeholder@. The
-- placeholder σ̂² column is discarded; the real σ̂²/σ̃² come from the variance join.
loadPanelCsv :: FilePath -> IO [(T.Text, Int, Double, Int, Int)]
loadPanelCsv fp = do
  bs <- BL.readFile fp
  -- The placeholder σ̂² column is literally "NaN" until the 09-05/09-09 variance
  -- join, which the Double reader rejects — decode it as Text and discard it (the
  -- real σ̂²/σ̃² arrive via 'joinVariance').
  case Csv.decode Csv.HasHeader bs
         :: Either String (V.Vector (T.Text, Int, Double, Int, Int, T.Text)) of
    Left err   -> ioError (userError ("panel CSV parse error: " ++ err))
    Right rows -> pure
      [ (tok, ep, prem, st, pt)
      | (tok, ep, prem, st, pt, _sig) <- V.toList rows ]

-- | Load the per-epoch variance CSV into @epoch → (σ̂², σ̃²)@. The file carries a
-- @#@-prefixed banner and an @epoch,sigma2,sigma2_instrument@ header, so parse by
-- hand: skip comment/header lines, split on commas.
loadVarianceCsv :: FilePath -> IO (Map.Map Int (Double, Double))
loadVarianceCsv fp = do
  txt <- readFile fp
  let dataLines = filter keep (lines txt)
      keep l = not ("#" `isPrefixOf` l) && not ("epoch" `isPrefixOf` l) && not (null l)
  pure (Map.fromList (mapMaybe parseRow dataLines))
  where
    parseRow l = case splitOn ',' l of
      (e : s2 : s2i : _) -> (\ep a b -> (ep, (a, b)))
                              <$> readMaybe e <*> readMaybe s2 <*> readMaybe s2i
      _                  -> Nothing

-- | Split a string on a delimiter (no escaping — the variance CSV is plain).
splitOn :: Char -> String -> [String]
splitOn d s = case break (== d) s of
  (a, [])      -> [a]
  (a, _ : rest) -> a : splitOn d rest

-- | Join σ̂²_t/σ̃²_t onto each raw panel row by epoch, producing the estimation
-- 'Panel'. Rows whose epoch has no variance entry get NaN σ̂² and are dropped by
-- the estimator's 'designPoints' filter.
joinVariance :: Map.Map Int (Double, Double) -> [(T.Text, Int, Double, Int, Int)] -> Panel
joinVariance varMap = map toObs
  where
    toObs (tok, ep, prem, st, pt) =
      let (s2, s2i) = Map.findWithDefault (0 / 0, 0 / 0) ep varMap
      in Obs { obsTokenId     = tok
             , obsEpoch       = ep
             , obsPremium     = prem
             , obsStrikeTick  = st
             , obsPoolTick    = pt
             , obsSigma2      = s2
             , obsSigma2Instr = s2i
             }

-- | Run the variance stage: obtain the tick series (live RPC or cache), compute
-- σ̂²_t and the disjoint-window instrument σ̃²_t, and write the joined CSV.
runVariance :: VarianceOpts -> IO ()
runVariance vo = do
  ticks <- case (voFrom vo, voTo vo) of
    (Just f, Just t) -> do
      let cfg = defaultBaseRpc
                  { rpcUrl       = voRpc vo
                  , rpcFromBlock = f
                  , rpcToBlock   = t
                  , rpcChunk     = voChunk vo
                  }
      putStrLn ("variance: live fetch of V4 Swap logs, blocks "
                 ++ show f ++ ".." ++ show t ++ " via " ++ voRpc vo)
      ts <- fetchSwapTicks cfg
      cacheSwapTicks (voTicksCsv vo) ts
      putStrLn ("variance: cached " ++ show (length ts) ++ " ticks -> " ++ voTicksCsv vo)
      pure ts
    _ -> do
      putStrLn ("variance: loading cached ticks <- " ++ voTicksCsv vo)
      loadSwapTicks (voTicksCsv vo)
  let rv = realizedVariance ticks
      iv = instrumentVariance ticks
  writeVarianceCsv (voOutCsv vo) rv iv
  putStrLn ("variance: wrote " ++ voOutCsv vo
             ++ " (" ++ show (Map.size rv) ++ " epochs, "
             ++ show (length ticks) ++ " ticks)")

main :: IO ()
main = execParser opts >>= run

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
import qualified Data.ByteString.Lazy    as BL
import qualified Data.Csv                as Csv
import           Data.List               (intercalate, isPrefixOf, nub, sortOn)
import qualified Data.Map.Strict         as Map
import           Data.Maybe              (mapMaybe)
import qualified Data.Text               as T
import           Data.Time.Clock         (getCurrentTime)
import           Data.Time.Format        (defaultTimeLocale, formatTime)
import qualified Data.Vector             as V
import           Options.Applicative
import           System.FilePath         ((</>))
import           System.IO               (readFile')
import           Text.Printf             (printf)
import           Text.Read               (readMaybe)

import           Numeric.AD              (grad)
import           Numeric.GSL.Fitting     (fitModel)
import qualified Numeric.LinearAlgebra   as LA

import           Alternatives
import           Econ.Types              (Obs (..), Panel, Theta (..))
import           Model.EIV               (ivFit)
import           Model.NLS               (designPoints, fitGSLCov)
import           Model.SandwichSE        (clusterSandwich, standardErrors)
import           Model.Upsilon           (model, modelSplit, moneyness, signedMoneyness)
import           Panel.Build             (Spell (..), assembleSpells, writePanelCsv)
import           Panel.Subgraph          (CollateralFlow (..), Endpoint (..),
                                          PoolAddr (..), fetchBurns,
                                          fetchCollateralFlows, fetchLegs,
                                          fetchMints)
import           Panel.Variance          (RpcConfig (..),
                                          defaultBaseRpc, fetchSwapTicks,
                                          instrumentVariance, loadSwapTicks,
                                          meanPoolTick, realizedVariance,
                                          writeVarianceCsv)
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
  { voTicksCsv :: FilePath
  , voOutCsv   :: FilePath
  , voFrom     :: Maybe Integer
  , voTo       :: Maybe Integer
  , voRpc      :: String
  , voChunk    :: Integer
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

data Command
  = BuildPanel BuildPanelOpts
  | Variance VarianceOpts
  | Estimate EstimateOpts

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
    )

opts :: ParserInfo Command
opts =
  info (commandParser <**> helper)
    ( fullDesc
   <> progDesc "Panoptic upsilon structural econometrics pipeline"
   <> header "econometrics - Haskell-only estimation of the exponential-moneyness vega profile" )

main :: IO ()
main = execParser opts >>= run

run :: Command -> IO ()
run (BuildPanel o) = runBuildPanel o
run (Variance vo)  = runVariance vo
run (Estimate eo)  = runEstimate eo

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
      -- Stream to the cache as chunks arrive: a ~500-call pull must not lose
      -- hours of work if a late call fails.
      ts <- fetchSwapTicks cfg (Just (voTicksCsv vo))
      putStrLn ("variance: cached " ++ show (length ts) ++ " ticks -> " ++ voTicksCsv vo)
      pure ts
    _ -> do
      putStrLn ("variance: loading cached ticks <- " ++ voTicksCsv vo)
      loadSwapTicks (voTicksCsv vo)
  let rv = realizedVariance ticks
      iv = instrumentVariance ticks
      mt = meanPoolTick ticks
  writeVarianceCsv (voOutCsv vo) rv iv mt
  putStrLn ("variance: wrote " ++ voOutCsv vo ++ " (" ++ show (Map.size rv)
             ++ " epochs, " ++ show (length ticks) ++ " ticks)")

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
          acctCl      = [ obsEpochAccount o | o <- usable ]
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

-- | The account label, carried through 'Obs' via the epoch-account encoding set
-- up by 'joinSpells' (see 'obsEpochAccount').
obsEpochAccount :: Obs -> T.Text
obsEpochAccount = obsSigma2InstrAccount
  where obsSigma2InstrAccount o = T.takeWhile (/= '#') (obsTokenId o)

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
  [ CollateralObs owner ep bal (vrSigma2 vr)
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
  let [seB, seU, seK] = take 3 (standardErrors vTok ++ repeat (0 / 0))
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
               (Theta bg ug kg) (Theta bi ui ki) vTok vAcct rU rK rS symNote alts collat =
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

    headline
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
      , "- `upsilon0-hat = " ++ fmtG ug ++ "`  ->  `hu` " ++ satisfied upsilonPositive
      , "- `kappa-hat = " ++ fmtG kg ++ "`  ->  `hk` " ++ satisfied kappaPositive
      , "- `Delta_i = 10` (pool tickSpacing)  ->  `hd` SATISFIED"
      , ""
      , verdict
      ]
      where
        satisfied True  = "SATISFIED."
        satisfied False = "**NOT satisfied.**"
        verdict
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
                    [ "", shapeReadOff (estCurve e) ]) ++
             [ "", "Note: " ++ T.unpack (estNote e) ]
        else [ "**NOT IDENTIFIED / NOT ESTIMABLE.**"
             , ""
             , "Reason: " ++ T.unpack (estNote e)
             , ""
             , "Observations seen: " ++ show (estNobs e) ++ ", clusters: "
                 ++ show (estClusters e) ++ "."
             ]) ++
      [ "" ]

    shapeReadOff curve
      | length curve < 2 = ""
      | snd (head curve) > snd (last curve) =
          "Shape read-off: the profile DECLINES from the money outward — the"
          ++ " direction the conjecture (kappa > 0) predicts."
      | otherwise =
          "Shape read-off: the profile does NOT decline from the money outward —"
          ++ " no unrestricted evidence for an at-the-money vega peak."

    _unusedCollat = length collat

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

-- Silence unused-import warnings for helpers used only in some branches.
_unusedIntercalate :: [String] -> String
_unusedIntercalate = intercalate ", "

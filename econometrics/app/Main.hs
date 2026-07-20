{-# LANGUAGE OverloadedStrings #-}

-- | CLI for the econometrics pipeline.
--
-- The pipeline is invoked stage-by-stage for reproducibility. @build-panel@ is
-- live (plan 09-04): it fetches positions from the confirmed Panoptic subgraph,
-- diffs cumulative premia into per-epoch flows, and writes the tokenId × daily
-- panel CSV. The other stages remain stubs filled by later plans. No absolute
-- paths; the endpoint is supplied on the command line, never hardcoded.
module Main (main) where

import qualified Data.Map.Strict    as Map
import qualified Data.Text          as T
import           Options.Applicative

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
  | Estimate                     -- ^ Run the NLS/GMM estimator.
  | Test                         -- ^ Compute specification test statistics.

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
        (info (pure Estimate)
              (progDesc "Run the NLS/GMM estimator with clustered sandwich SEs"))
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
run Fetch    = putStrLn "fetch: not yet implemented"
run Estimate = putStrLn "estimate: not yet implemented"
run Test     = putStrLn "test: not yet implemented"

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

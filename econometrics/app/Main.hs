{-# LANGUAGE OverloadedStrings #-}

-- | CLI for the econometrics pipeline.
--
-- The pipeline is invoked stage-by-stage for reproducibility. @build-panel@ is
-- live (plan 09-04): it fetches positions from the confirmed Panoptic subgraph,
-- diffs cumulative premia into per-epoch flows, and writes the tokenId × daily
-- panel CSV. The other stages remain stubs filled by later plans. No absolute
-- paths; the endpoint is supplied on the command line, never hardcoded.
module Main (main) where

import qualified Data.Text          as T
import           Options.Applicative

import           Panel.Build        (assemble, writePanelCsv)
import           Panel.Subgraph     (Endpoint (..), PoolAddr (..), fetchPositions)

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
  | Variance                     -- ^ Construct sigma^2_t and the EIV instrument.
  | Estimate                     -- ^ Run the NLS/GMM estimator.
  | Test                         -- ^ Compute specification test statistics.

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
        (info (pure Variance)
              (progDesc "Construct sigma^2_t and the second-window instrument"))
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
run Fetch    = putStrLn "fetch: not yet implemented"
run Variance = putStrLn "variance: not yet implemented"
run Estimate = putStrLn "estimate: not yet implemented"
run Test     = putStrLn "test: not yet implemented"

main :: IO ()
main = execParser opts >>= run

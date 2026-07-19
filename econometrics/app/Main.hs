-- | CLI skeleton for the econometrics pipeline.
--
-- The pipeline is invoked stage-by-stage for reproducibility. Each subcommand is
-- a stub for now (prints "not yet implemented" and exits 0); later plans fill in
-- the real fetch / panel / variance / estimate / test logic. No absolute paths.
module Main (main) where

import Options.Applicative

-- | Pipeline stages, one per subcommand.
data Command
  = Fetch        -- ^ Pull raw positions/premia from the Panoptic subgraph.
  | BuildPanel   -- ^ Assemble the tokenId x daily-epoch panel (per-epoch deltas).
  | Variance     -- ^ Construct sigma^2_t and the second-window EIV instrument.
  | Estimate     -- ^ Run the NLS/GMM estimator with clustered sandwich SEs.
  | Test         -- ^ Compute the committed specification test statistics.
  deriving (Show, Eq)

commandParser :: Parser Command
commandParser =
  hsubparser
    ( command "fetch"
        (info (pure Fetch)
              (progDesc "Fetch raw positions/premia from the Panoptic subgraph"))
   <> command "build-panel"
        (info (pure BuildPanel)
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
run c = putStrLn (stageName c ++ ": not yet implemented")
  where
    stageName Fetch      = "fetch"
    stageName BuildPanel = "build-panel"
    stageName Variance   = "variance"
    stageName Estimate   = "estimate"
    stageName Test       = "test"

main :: IO ()
main = execParser opts >>= run

{-# LANGUAGE OverloadedStrings #-}

-- |
-- THE FEE-SPLIT DIFFERENTIAL. The one capture in this repository whose subject is the prover
-- REFUSING something.
--
-- @GamsConformance.hs@ records what the real toolchain does with shocks it ACCEPTS -- versions,
-- exit codes, byte identity under three environments, the rendering fingerprint. Every one of its
-- nine observations is about a run that worked. This tool records the opposite fact, which is the
-- one FEE-02 actually claims: that @Fee.Split.is_admissible@ and @volume_path.gms@'s own
-- @ellTest@ gate agree about which @(phiXpips, phiMpips, txlVolumeRate)@ triples are admissible,
-- measured ONE PIP either side of four exact boundaries.
--
-- == THE DISCRIMINATOR IS THE MODEL'S SOURCE LINE, NOT THE EXIT CODE
--
-- MEASURED over 160 real invocations (@26-PROVER-SWEEP.md@) and re-measured by this tool on every
-- run: @gams@ exits 3 for at least six different reasons, and the abort message reaches neither
-- stdout nor stderr (both are 0 bytes in every GAMS mode). It lands in @volume_path.log@ in
-- @curdir@ and it names the model's own source line:
--
-- >  *** Error at line 109: Execution halted: abort$1 'dStar outside the half-ellipse: ...'
--
-- and those line numbers are a taxonomy:
--
-- >  91       equal fees                    -- Gams.Argv.distinct_fees refuses this first
-- >  103      kappa outside a solvable range -- a FIXTURE property, not a fee-pair property
-- >  109      dStar outside the half-ellipse -- THIS IS ellipse_test, and it is the only refusal
-- >  171/173  solveStat / modelStat          -- CONOPT could not solve an ADMISSIBLE point
--
-- So @gams_admits@ is derived as @abort_line \/= 109@ and NEVER as @exit == 0@. That distinction is
-- the whole design: at this fixture's @volTgtWad@ and @nEvents@, three of the four pairs are
-- CONOPT-infeasible at their own boundary, so deriving the verdict from the exit code would report
-- a disagreement on eight of the twelve grid rows and call a solver limitation a splitter bug.
-- An @admissible-but-unsolved@ row is not a disagreement, and this file is where that is decided.
--
-- == WHY THE GRID ROWS AND THE CONTROLS TAKE DIFFERENT PATHS THROUGH THE SAME LIBRARY
--
-- The four @boundary - 1@ rows are exactly the shocks 'Gams.Argv.render_argv' refuses -- that is
-- FEE-03, and it is not being weakened. They are rendered with 'Gams.Argv.render_argv_ungated',
-- whose haddock names this file as its ONE permitted consumer, and driven through
-- 'Gams.Invoke.raw_gams', which returns the run's log so the abort line can be read.
--
-- The four CONTROLS go through 'Gams.Invoke.invoke_shock' -- the unmodified PRODUCTION composition,
-- all nine refusals, the whitelisted environment, 'Gams.Run.run_prover''s six verdict conjuncts.
-- That is what makes them controls: a pair whose control 'Gams.Run.Produced' an artifact through
-- the production path is a pair the toolchain can answer at all, so an abort at that pair's
-- boundary is attributable to something that varies with @dStar@ rather than to the pair being
-- unrunnable. The line number then says WHICH thing.
--
-- == aeson IS PERMITTED HERE, AND ONLY BECAUSE NO ARTIFACT BYTE REACHES IT
--
-- Same ruling as the two capture tools beside it. This writes a REPORT -- a description of an
-- experiment. Every byte-level fact travels as a length or a BARE hex digest computed by
-- 'Store.Types.sha256_hex' over the bytes themselves, so a writer that never carries bytes cannot
-- re-render a number or reorder a key.
--
-- == COMPLETENESS IS THE ATOMIC RENAME, NOT A FIELD ORDER
--
-- @complete@ starts 'False' and is flipped only after every row and every control has returned.
-- \"Written last\" is NOT observable in a single JSON document and no check pretends otherwise:
-- the guarantee is that the FILE is written exactly once, at the end, through
-- 'Driver.Capture.write_json_atomically', which renames into place. A partial run leaves the
-- committed artifact untouched because it never opened it.
--
-- == USAGE
--
-- > fee-split-conformance <scratch-directory>
--
-- The scratch directory is prepared by @offchain\/rig\/capture-fee-split.sh@ and is never inside the
-- working tree and never inside @model\/@, which is another workstream's territory.
module Main (main) where

import Data.Aeson (Value, object, (.=))
import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as C8
import Data.Char (isDigit)
import Data.IORef (newIORef, readIORef, writeIORef)
import Data.List (isPrefixOf, tails)
import System.Directory (createDirectoryIfMissing, doesDirectoryExist, doesFileExist)
import System.Environment (getArgs)
import System.Exit (exitFailure)
import System.FilePath ((</>))
import System.IO (hPutStrLn, stderr)
import System.Process (readProcess)

import Driver.Capture (write_json_atomically)
import Fee.Split (ellipse_test, is_admissible, min_admissible_dstar)
import Gams.Argv (Shock (..), render_argv_ungated)
import Gams.Config (fee_split_conformance_path)
import Gams.Invoke
  ( EnvChoice (..)
  , InvokeError
  , RawRun (..)
  , invoke_shock
  , raw_gams
  , resolve_gams_bin
  , resolve_gams_model
  )
import Gams.Run (ProverOutcome (..), ToolchainIdentity (..))
import Gams.Version (conopt_version_text, gams_version_text)
import Store.Types (sha256_hex)

-- ---------------------------------------------------------------------------------------------
-- The pinned grid
-- ---------------------------------------------------------------------------------------------

-- | One fee pair, its EXACT integer boundary, and the target its control is driven at.
data Pair = Pair
  { p_x        :: Integer
  , p_m        :: Integer
  , p_boundary :: Integer
    -- ^ the LEAST @txlVolumeRate@ this pair admits. Not transcribed on faith: 'check_boundaries'
    --   re-bisects it with 'Fee.Split.min_admissible_dstar' before a single process is started, and
    --   a mismatch kills the capture rather than being recorded.
  , p_control  :: Integer
    -- ^ a target this pair MEASURED as solvable at the fixture's volume. There is no single one
    --   that works for all four: 490000 solves three of the four and 497000 solves the other three.
  }

-- | FOUR PAIRS, ALL AT @phi >= 100@ PIPS.
--
-- @26-RESEARCH.md@ M5 measured the exact-vs-double sign margin at @phi = (3, 7)@ pips at 4.4e-18,
-- only 4e4 times the double noise floor. GAMS evaluates @ellTest@ in double and "Fee.Split"
-- evaluates it exactly, so a grid at single-digit-pip fees would be measuring floating-point noise
-- rather than agreement.
--
-- The control targets are MEASURED, not chosen. @26-PROVER-SWEEP.md@ swept 160 real invocations:
-- 490000 -- which is ROADMAP SC-2's own 0.49 -- solves (500,6000), (100,900) and (1000,3000), and
-- 497000 solves (700,800), which ellipse-refuses everything below 495954 and is the outlier of the
-- four. Raising @volTgtWad@ to rescue a pair is NOT an option and that is measured too: six values
-- and three @nEvents@ settings were swept and all still abort, because the model's own @u@ box of
-- @[1e-3, 1e3]@ bounds what any volume can reach.
pinned_pairs :: [Pair]
pinned_pairs =
  [ Pair 500  6000 82804  490000
  , Pair 100  900  109769 490000
  , Pair 1000 3000 300361 490000
  , Pair 700  800  495953 497000
  ]

-- | The model source line the ELLIPSE gate aborts at, and the only line number that means
-- \"inadmissible\".
--
-- It is pinned against the model's sha256, which this capture records: a source line is stable
-- exactly as long as the file is, and the recorded digest is what says whether it still is.
ellipse_abort_line :: Int
ellipse_abort_line = 109

-- | The other five shock fields, from @VOLUME_PATH.md@ section 2's fixture.
fixture_sqrt_price_x96, fixture_liquidity_raw, fixture_vol_tgt_wad, fixture_n_events :: Integer
fixture_sqrt_price_x96 = 79228162514264337593543950336
fixture_liquidity_raw  = 18446744073709551616
fixture_vol_tgt_wad    = 28000000000000000000
fixture_n_events       = 8

-- | The freshness oracle's subject: the module whose arithmetic every @haskell_admits@ below came
-- from. The suite recomputes this digest from its own disk, so editing the splitter without
-- re-capturing reddens.
splitter_source_path :: FilePath
splitter_source_path = "offchain/lib/Fee/Split.hs"

shock_at :: Pair -> Integer -> Shock
shock_at pair target = Shock
  { sh_sqrt_price_x96  = fixture_sqrt_price_x96
  , sh_liquidity_raw   = fixture_liquidity_raw
  , sh_txl_volume_rate = target
  , sh_phi_x_pips      = p_x pair
  , sh_phi_m_pips      = p_m pair
  , sh_vol_tgt_wad     = fixture_vol_tgt_wad
  , sh_n_events        = fixture_n_events
  }

-- ---------------------------------------------------------------------------------------------
-- Entry point
-- ---------------------------------------------------------------------------------------------

main :: IO ()
main = do
  args <- getArgs
  case args of
    [scratch] -> capture scratch
    _         -> do
      hPutStrLn stderr "usage: fee-split-conformance <scratch-directory>"
      hPutStrLn stderr "       the directory is prepared by offchain/rig/capture-fee-split.sh"
      exitFailure

-- | Fail loudly, naming the subject, and write NOTHING.
die :: [String] -> IO a
die messages = do
  mapM_ (hPutStrLn stderr) messages
  hPutStrLn stderr "              No artifact was written; the committed one is untouched."
  exitFailure

resolved :: String -> Either InvokeError a -> IO a
resolved what outcome =
  case outcome of
    Right value -> pure value
    Left why    -> die ["CAPTURE FAIL: " ++ what ++ ": " ++ show why]

capture :: FilePath -> IO ()
capture scratch = do
  complete <- newIORef False
  out      <- fee_split_conformance_path

  scratch_there <- doesDirectoryExist scratch
  if not scratch_there
    then die [ "CAPTURE FAIL: the scratch directory " ++ scratch ++ " does not exist."
             , "              offchain/rig/capture-fee-split.sh makes it, outside the working tree."
             ]
    else pure ()

  splitter_there <- doesFileExist splitter_source_path
  if not splitter_there
    then die [ "CAPTURE FAIL: the freshness oracle's subject " ++ splitter_source_path
                 ++ " is not on disk."
             , "              Every haskell_admits below comes from that module; recording a digest"
             , "              for a file that is gone would make the oracle compare nothing."
             ]
    else pure ()
  splitter_sha <- sha256_hex <$> BS.readFile splitter_source_path

  -- --- The boundaries are RE-BISECTED before any process is started ---------------------------
  check_boundaries

  binary <- resolve_gams_bin   >>= resolved "the prover binary could not be resolved"
  model  <- resolve_gams_model >>= resolved "the model could not be resolved"

  -- --- (a) The twelve grid rows, through the UNGATED renderer and the raw invocation -----------
  rows <- mapM (grid_row scratch binary model) grid_points

  -- --- (b) The four controls, through the unmodified PRODUCTION composition ---------------------
  controls <- mapM control_row pinned_pairs

  identity <- case [i | (_, _, Just i) <- controls] of
    (i : _) -> pure i
    []      -> die [ "CAPTURE FAIL: not one control reached the production path's Produced arm, so"
                   , "              there is no ToolchainIdentity and the recorded versions would"
                   , "              be strings about nothing."
                   ]
  conopt <- case ti_conopt_version identity of
    Just v  -> pure (conopt_version_text v)
    Nothing -> die [ "CAPTURE FAIL: the control's log carries no CONOPT banner."
                   , "              A run that Produced an artifact reached the solver, so a"
                   , "              missing banner means the parse stopped working, not that CONOPT"
                   , "              was absent."
                   ]
  model_sha <- case ti_model_sources identity of
    [(_, d)] -> pure d
    other    -> die [ "CAPTURE FAIL: the run recorded " ++ show (length other) ++ " model sources,"
                        ++ " expected exactly 1."
                    , "              The abort LINE NUMBER this capture keys its verdict on is a"
                    , "              line of that one file; with includes in play the line no longer"
                    , "              identifies a gate."
                    ]

  stamp <- generated_at
  writeIORef complete True
  done <- readIORef complete

  write_json_atomically out $ object
    [ "complete"                .= done
    , "generatedAt"             .= stamp
    , "splitter_source_sha256"  .= splitter_sha
    , "model_sha256"            .= model_sha
    , "gams_version"            .= gams_version_text (ti_gams_version identity)
    , "conopt_version"          .= conopt
    , "ellipse_abort_line"      .= ellipse_abort_line
    , "vol_tgt_wad"             .= show fixture_vol_tgt_wad
    , "n_events"                .= fixture_n_events
    , "grid"                    .= map row_json rows
    , "controls"                .= map control_json controls
    ]

  putStrLn ("wrote " ++ out)
  putStrLn ("  GAMS       " ++ gams_version_text (ti_gams_version identity) ++ "   CONOPT " ++ conopt)
  putStrLn ("  MODEL      " ++ model_sha)
  putStrLn ("  SPLITTER   " ++ splitter_sha)
  mapM_ (putStrLn . row_line) rows
  mapM_ (putStrLn . control_line) controls

-- ---------------------------------------------------------------------------------------------
-- The rows
-- ---------------------------------------------------------------------------------------------

-- | @(pair, target)@ for every grid point: one pip below each boundary, the boundary, one pip above.
--
-- TWO-SIDED BY CONSTRUCTION, which is @26-RESEARCH.md@ pitfall C: the first of each triple is
-- INADMISSIBLE and the other two are ADMISSIBLE, so the agreement asserted over this grid is
-- asserted over a sample carrying both verdicts. A one-sided grid would let a function that
-- answered one way always pass.
grid_points :: [(Pair, Integer)]
grid_points =
  [ (pair, p_boundary pair + offset) | pair <- pinned_pairs, offset <- [-1, 0, 1] ]

data Row = Row
  { r_x         :: Integer
  , r_m         :: Integer
  , r_target    :: Integer
  , r_e         :: Integer
  , r_haskell   :: Bool
  , r_exit      :: Int
  , r_line      :: Maybe Int
  }

grid_row :: FilePath -> FilePath -> FilePath -> (Pair, Integer) -> IO Row
grid_row scratch binary model (pair, target) = do
  let shock = shock_at pair target
      tag = show (p_x pair) ++ "-" ++ show (p_m pair) ++ "-" ++ show target
      dir = scratch </> ("row-" ++ tag)
  argv <- case render_argv_ungated shock of
    Right tokens -> pure tokens
    Left why     ->
      die [ "CAPTURE FAIL: the grid shock at " ++ tag ++ " did not render even UNGATED: " ++ show why
          , "              The eight pre-existing refusals are range and model facts about the"
          , "              fixture, not about admissibility; one of them firing means the grid is"
          , "              wrong rather than that the prover refused anything."
          ]
  createDirectoryIfMissing True dir
  run <- raw_gams binary dir minimal_env
           ([model, "action=ce", "curdir=" ++ dir, "lo=2"] ++ argv)
  pure Row
    { r_x       = p_x pair
    , r_m       = p_m pair
    , r_target  = target
    , r_e       = ellipse_test (p_x pair) (p_m pair) target
    , r_haskell = is_admissible (p_x pair) (p_m pair) target
    , r_exit    = raw_exit run
    , r_line    = maybe Nothing abort_line (raw_log run)
    }

-- | @abort_line \/= Just 109@. THE derivation, and it is pinned here rather than left implicit.
--
-- A run that SOLVED has no abort line at all and is admissible; a run that halted at 171 or 173 is
-- an ADMISSIBLE point CONOPT could not reach and is still admissible; only 109 is the model saying
-- the pair does not admit this target.
row_admits :: Row -> Bool
row_admits row = r_line row /= Just ellipse_abort_line

row_json :: Row -> Value
row_json row = object
  [ "phiXpips"       .= r_x row
  , "phiMpips"       .= r_m row
  , "txlVolumeRate"  .= r_target row
  , "haskell_E"      .= show (r_e row)
  , "haskell_admits" .= r_haskell row
  , "gams_exit"      .= r_exit row
  , "gams_abort_line" .= maybe 0 id (r_line row)
  , "gams_admits"    .= row_admits row
  ]

row_line :: Row -> String
row_line row =
  "  ROW        (" ++ show (r_x row) ++ ", " ++ show (r_m row) ++ ") @ " ++ show (r_target row)
    ++ "   haskell " ++ verdict (r_haskell row)
    ++ "   gams " ++ verdict (row_admits row)
    ++ "   exit " ++ show (r_exit row)
    ++ "   line " ++ maybe "none" show (r_line row)
    ++ (if r_haskell row == row_admits row then "" else "   *** DISAGREE ***")
  where verdict b = if b then "ADMIT " else "REFUSE"

-- | One control: the pair, the target, the exit code, and the identity when the production path
-- reached its 'Gams.Run.Produced' arm.
control_row :: Pair -> IO (Pair, Int, Maybe ToolchainIdentity)
control_row pair = do
  outcome <- invoke_shock WhitelistEnv (shock_at pair (p_control pair))
             >>= resolved ("the control for the pair " ++ show (p_x pair, p_m pair))
  pure $ case outcome of
    Produced _ identity _ -> (pair, 0, Just identity)
    Aborted _ code _      -> (pair, code, Nothing)

control_json :: (Pair, Int, Maybe ToolchainIdentity) -> Value
control_json (pair, code, identity) = object
  [ "phiXpips"                 .= p_x pair
  , "phiMpips"                 .= p_m pair
  , "txlVolumeRate"            .= p_control pair
  , "control_exit"             .= code
  , "control_artifact_present" .= maybe False (const True) identity
  ]

control_line :: (Pair, Int, Maybe ToolchainIdentity) -> String
control_line (pair, code, identity) =
  "  CONTROL    (" ++ show (p_x pair) ++ ", " ++ show (p_m pair) ++ ") @ "
    ++ show (p_control pair) ++ "   exit " ++ show code
    ++ "   artifact " ++ maybe "no" (const "yes") identity

-- ---------------------------------------------------------------------------------------------
-- Preconditions and helpers
-- ---------------------------------------------------------------------------------------------

-- | The four pinned boundaries, RE-BISECTED, before a single process is started.
--
-- A capture whose boundaries were transcribed rather than recomputed would drive twelve rows that
-- bracket nothing, and every one of them would agree with itself.
check_boundaries :: IO ()
check_boundaries =
  case [ (p_x pair, p_m pair, p_boundary pair, min_admissible_dstar (p_x pair) (p_m pair))
       | pair <- pinned_pairs
       , min_admissible_dstar (p_x pair) (p_m pair) /= Just (p_boundary pair)
       ] of
    [] -> pure ()
    wrong ->
      die ( [ "CAPTURE FAIL: a pinned boundary is not the one Fee.Split.min_admissible_dstar"
                ++ " bisects:" ]
              ++ [ "              (" ++ show x ++ ", " ++ show m ++ "): pinned " ++ show b
                     ++ ", bisected " ++ show got
                 | (x, m, b, got) <- wrong ]
              ++ [ "              The grid brackets each boundary by one pip; a wrong boundary"
                 , "              brackets nothing and the capture would record twelve rows that"
                 , "              measure the interior."
                 ] )

-- | The child's environment for the RAW runs. The controls get the production whitelist through
-- 'Gams.Invoke.environment_for'; these twelve get the minimal vector, which
-- @gams-conformance.json@ MEASURED as reproducing the golden bytes exactly.
minimal_env :: [(String, String)]
minimal_env = [("LC_ALL", "C"), ("PATH", "/usr/bin")]

-- | The model's own source line, read out of the run's log.
--
-- The abort message reaches neither stdout nor stderr -- both MEASURED at 0 bytes in every GAMS
-- mode -- so this is the only place the discriminator exists.
abort_line :: BS.ByteString -> Maybe Int
abort_line bytes =
  case [ read digits :: Int
       | l <- C8.lines bytes
       , suffix <- tails (C8.unpack l)
       , abort_marker `isPrefixOf` suffix
       , let digits = takeWhile isDigit (drop (length abort_marker) suffix)
       , not (null digits)
       ] of
    (n : _) -> Just n
    []      -> Nothing

abort_marker :: String
abort_marker = "*** Error at line "

-- | @date@ rather than a new dependency, matching every other capture tool in this tree.
--
-- IT CARRIES A WALL CLOCK, so this artifact is NOT byte-stable across two consecutive captures --
-- the same fact 24-05 recorded for @gams-conformance.json@, stated here rather than discovered
-- later. Everything else in the document is a measurement and reproduces.
generated_at :: IO String
generated_at = trim <$> readProcess "date" ["-u", "+%Y-%m-%dT%H:%M:%SZ"] ""
  where trim = reverse . dropWhile (`elem` (" \t\r\n" :: String)) . reverse

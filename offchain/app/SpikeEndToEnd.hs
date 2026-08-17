-- |
-- THROWAWAY BY CONSTRUCTION. This is not a phase, not a requirement, not a check, and nothing
-- depends on it. It exists to answer ONE question -- do the five components phases 23-26 shipped
-- actually connect? -- while each is still fresh, instead of discovering the answer in phase 28
-- where five integration bugs would surface at once. Delete it whenever it stops being useful.
--
-- WHAT IT DRIVES, IN ORDER
-- ------------------------
-- The fee splitter's chosen pair reaches a real @Shock@; the real toolchain's versions and the real
-- model's digest reach a real 'KeyIdentity'; the content key is computed; 'Store.Cache.decide' is
-- called TWICE with the same shock against a 'Store.Solver' that is wired to 'Gams.Run.run_prover'.
-- That last wire is the one that did not exist anywhere in this repository before this file, and it
-- is the whole point.
--
-- THE THREE SEAM OBSERVATIONS THIS FILE HAD TO WORK AROUND, RECORDED HERE RATHER THAN PAPERED OVER
-- ------------------------------------------------------------------------------------------------
-- 1. __A 'KeyIdentity' can only be obtained from a COMPLETED RUN.__ 'Store.Key.key_identity' takes
--    a 'ToolchainIdentity', and the only producer of one in this package is the @Produced@ arm of
--    'Gams.Run.run_prover'. But 'Store.Cache.decide' needs the identity BEFORE it can compute the
--    key, which is before the first solve. There is no @detect_toolchain@ anywhere. So the spike
--    pays a BOOTSTRAP SOLVE whose only product is the identity, and the elision claim is then made
--    over the two 'decide' calls that follow it. A long-running caller would detect once at start
--    and reuse; there is nothing in the library that lets it do so without solving.
-- 2. __'Gams.Invoke.invoke_shock' does not fit the 'Store.Solver' seam.__ Its type is
--    @EnvChoice -> Shock -> IO (Either InvokeError ProverOutcome)@ and the seam wants
--    @Shock -> IO ProverOutcome@; 'Gams.Run.AbortReason' has no constructor for \"the binary or the
--    model could not be resolved\", so an 'InvokeError' arriving inside a solver has nowhere
--    truthful to go. The wiring below therefore resolves the binary and the model ONCE, outside the
--    seam, and the solver closes over them and calls 'Gams.Run.run_prover' directly -- which is what
--    "Store.Solver"'s own haddock says a caller should do.
-- 3. __'Store.Cache.Decision' drops 'Gams.Run.CapturedStreams'.__ @NotPersisted@ carries the reason
--    and the exit code and nothing else, and the abort LINE NUMBER -- the discriminator 26's prover
--    sweep measured, line 109 = the ellipse refusal versus 171\/173 = CONOPT infeasible -- lives
--    only in @volume_path.log@ inside a run directory that 'Gams.Run' deletes on every exit path.
--    A caller of 'decide' therefore cannot tell an INADMISSIBLE shock from an UNSOLVABLE one. The
--    solver wrapper below stashes the outcome it saw so this executable can classify; a phase-28
--    poller would need the same wrapper or a wider @Decision@.
module Main (main) where

import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as C8
import Data.Char (isDigit)
import Data.IORef (atomicModifyIORef', newIORef, readIORef, writeIORef)
import Data.List (isPrefixOf, tails)
import System.Directory (createDirectoryIfMissing, getHomeDirectory, getTemporaryDirectory)
import System.Exit (exitFailure)
import System.FilePath (takeFileName, (</>))
import System.IO (hPutStrLn, stderr)

import Fee.Split (FeeSplit (..), refusal_message, split_for)
import Gams.Argv (Shock (..))
import Gams.Env (whitelist_for)
import Gams.Invoke (raw_budget_s, raw_kill_after_s, resolve_gams_bin, resolve_gams_model)
import Gams.Run
  ( AbortReason
  , CapturedStreams (..)
  , ProverOutcome (..)
  , RunRequest (..)
  , run_prover
  )
import Gams.Version (conopt_version_text, gams_version_text)
import Store.Cache (Decision (..), decide)
import Store.Key (KeyIdentity (..), content_key, content_key_hex, key_identity)
import Store.Memory (new_memory_store)
import Store.Solver (Solver (..))
import Store.Types (artifact_bytes, current_key_scheme, sha256_hex)

-- ---------------------------------------------------------------------------------------------
-- The one hardcoded shock
-- ---------------------------------------------------------------------------------------------

-- | @VOLUME_PATH.md@ section 2's fixture price, @2^96@, written in decimal.
spike_sqrt_price_x96 :: Integer
spike_sqrt_price_x96 = 79228162514264337593543950336

-- | The fixture liquidity, @2^64@, written in decimal.
spike_liquidity_raw :: Integer
spike_liquidity_raw = 18446744073709551616

-- | The fixture volume target, 28e18 in wad.
spike_vol_tgt_wad :: Integer
spike_vol_tgt_wad = 28000000000000000000

-- | The fixture event count.
spike_n_events :: Integer
spike_n_events = 8

-- | @delta*@, in pips. MEASURED by 26-PROVER-SWEEP over 160 real invocations: 490000 SOLVES for
-- (500,6000), (100,900) and (1000,3000), and it is the single most useful grid point there is.
spike_dstar :: Integer
spike_dstar = 490000

-- | The pool fee, in pips. 6497 is the composed fee of the fixture pair -- @999500 * 994000@ keeps
-- 99.3503% -- and it is the one fee in this codebase that admits an EXACT integer-pip split, so the
-- residual printed below is a zero that was computed rather than a tolerance that was met.
spike_pool_fee :: Integer
spike_pool_fee = 6497

-- | The seed, CHOSEN so the splitter lands on the pair the prover was measured to solve.
--
-- Stated plainly because it is a fixture choice and not a discovery: the band at
-- @(f = 6497, delta* = 490000)@ has 2900 members and @(500, 6000)@ sits at index 499, so this seed
-- is the least 'Data.Word.Word32' whose mixed value is congruent to 499. Seed 0 selects
-- @(1036, 5467)@ instead -- admissible, but a pair 26-PROVER-SWEEP never drove, so a CONOPT
-- infeasibility there would have told us about the fixture rather than about the wiring. The
-- SPLITTER still does the choosing; only the seed handed to it was picked with the sweep in hand.
spike_seed :: Word
spike_seed = 4411

-- ---------------------------------------------------------------------------------------------
-- Entry point
-- ---------------------------------------------------------------------------------------------

main :: IO ()
main = do
  putStrLn "=== SPIKE end-to-end: fee split -> key -> real solve -> store -> elision =========="

  -- --- (1) the fee split -----------------------------------------------------------------------
  fee <- case split_for (fromIntegral spike_seed) spike_pool_fee spike_dstar of
           Left why  -> die ["SPIKE STOP: the fee split refused: " ++ refusal_message why]
           Right ok  -> pure ok
  putStrLn ("SPLIT     seed " ++ show spike_seed ++ "  f " ++ show (fs_pool_fee_pips fee)
             ++ " pips  dstar " ++ show (fs_dstar_pips fee) ++ " pips  band "
             ++ show (fs_band_size fee) ++ " members")
  putStrLn ("SPLIT     pair (phi_X, phi_M) = (" ++ show (fs_phi_x_pips fee) ++ ", "
             ++ show (fs_phi_m_pips fee) ++ ") pips")
  putStrLn ("SPLIT     realized " ++ show (fs_realized_scaled fee)
             ++ " scaled units (= composed fee x 1000000)")
  putStrLn ("SPLIT     residual " ++ show (fs_residual_scaled fee) ++ " scaled units, is_exact "
             ++ show (fs_is_exact fee))
  putStrLn ("SPLIT     ellipse E " ++ show (fs_ellipse_e fee) ++ "  boundary "
             ++ show (fs_boundary_pips fee) ++ " pips  splitter " ++ fs_splitter_version fee)

  let shock = Shock
        { sh_sqrt_price_x96  = spike_sqrt_price_x96
        , sh_liquidity_raw   = spike_liquidity_raw
        , sh_txl_volume_rate = fs_dstar_pips fee
        , sh_phi_x_pips      = fs_phi_x_pips fee
        , sh_phi_m_pips      = fs_phi_m_pips fee
        , sh_vol_tgt_wad     = spike_vol_tgt_wad
        , sh_n_events        = spike_n_events
        }

  -- --- (2) the live toolchain, resolved ONCE, outside the solver seam --------------------------
  binary <- resolve_gams_bin   >>= either (\w -> die ["SPIKE STOP: " ++ show w]) pure
  model  <- resolve_gams_model >>= either (\w -> die ["SPIKE STOP: " ++ show w]) pure
  environment <- whitelist_for <$> getHomeDirectory
  let go sh = run_prover RunRequest
        { rr_binary       = binary
        , rr_model        = model
        , rr_shock        = sh
        , rr_env          = Just environment
        , rr_budget_s     = raw_budget_s
        , rr_kill_after_s = raw_kill_after_s
        }
  putStrLn ("TOOLCHAIN " ++ binary)
  putStrLn ("MODEL     " ++ model)

  -- --- (3) the BOOTSTRAP solve, which exists only because a KeyIdentity needs a completed run ---
  bootstrap <- go shock
  identity <- case bootstrap of
    Produced _ ident _ -> pure ident
    Aborted why code streams -> do
      report_abort "BOOTSTRAP" why code streams
      die ["SPIKE STOP: the bootstrap solve produced no toolchain identity, so there is no key."]
  ident <- case key_identity identity of
    Left why -> die ["SPIKE STOP: key_identity refused the measured toolchain: " ++ show why]
    Right ok -> pure ok
  putStrLn ("IDENTITY  GAMS " ++ gams_version_text (ki_gams_version ident)
             ++ "   CONOPT " ++ conopt_version_text (ki_conopt_version ident))
  putStrLn ("IDENTITY  sources " ++ show (ki_model_sources ident))
  putStrLn ("IDENTITY  options " ++ show (ki_fixed_options ident) ++ "  pipsdenom "
             ++ show (ki_pips_denom ident))

  -- --- (4) the content key ---------------------------------------------------------------------
  let model_name = takeFileName model
  key <- case content_key current_key_scheme model_name shock ident of
           Left why -> die ["SPIKE STOP: the key refused to compute: " ++ show why]
           Right ok -> pure ok
  putStrLn ("KEY       " ++ content_key_hex key)

  -- --- (5) the wire: Gams.Run behind a Store.Solver, counted ------------------------------------
  store    <- new_memory_store
  hits     <- newIORef (0 :: Int)
  last_out <- newIORef Nothing
  let solver = Solver
        { solver_label = "SpikeEndToEnd -> Gams.Run.run_prover"
        , solver_run   = \sh -> do
            atomicModifyIORef' hits (\n -> (n + 1, ()))
            outcome <- go sh
            writeIORef last_out (Just outcome)
            pure outcome
        }

  -- --- (6) decide, twice, with the SAME shock ---------------------------------------------------
  first_decision <- decide store solver current_key_scheme model_name shock ident
  first_bytes <- case first_decision of
    Left why -> die ["SPIKE STOP: decide refused the shock: " ++ show why]
    Right (NotPersisted why code) -> do
      seen <- readIORef last_out
      case seen of
        Just (Aborted r c streams) -> report_abort "DECIDE 1" r c streams
        _ -> putStrLn ("DECIDE 1  NotPersisted " ++ show why ++ " at exit " ++ show code
                        ++ " and the solver kept no outcome to classify from")
      die ["SPIKE STOP: the first decide did not persist; see the classification above."]
    Right (Elided _) ->
      die ["SPIKE STOP: the FIRST decide elided against an empty store. That is impossible unless"
          ,"            the lookup is answering hits it never stored."]
    Right (Stored art) -> do
      let bytes = artifact_bytes art
      n <- readIORef hits
      seen <- readIORef last_out
      let line = case seen of
                   Just (Produced _ _ streams) -> abort_line (cs_log streams)
                   _                           -> Nothing
      putStrLn ("SOLVE 1   GAMS exit 0 (Produced: Gams.Exit.classify_exit said Solved; the Produced"
                 ++ " arm carries no exit code)")
      putStrLn ("SOLVE 1   abort line in volume_path.log: " ++ maybe "none" show line
                 ++ "  -- " ++ classify_abort line)
      putStrLn ("DECIDE 1  Stored   sha256 " ++ sha256_hex bytes ++ "  " ++ show (BS.length bytes)
                 ++ " bytes   solver invocations " ++ show n)
      pure bytes

  second_decision <- decide store solver current_key_scheme model_name shock ident
  second_bytes <- case second_decision of
    Right (Elided art) -> do
      n <- readIORef hits
      let bytes = artifact_bytes art
      putStrLn ("DECIDE 2  Elided   sha256 " ++ sha256_hex bytes ++ "  " ++ show (BS.length bytes)
                 ++ " bytes   solver invocations " ++ show n)
      pure bytes
    Right other -> do
      n <- readIORef hits
      putStrLn ("DECIDE 2  " ++ show_decision other ++ "   solver invocations " ++ show n)
      die ["SPIKE STOP: the second decide did not elide. STORE-01 is not delivered end to end."]
    Left why -> die ["SPIKE STOP: the second decide refused: " ++ show why]

  invocations <- readIORef hits
  putStrLn ("ELISION   solver invocations " ++ show invocations ++ " (expected 1)   bytes identical "
             ++ show (first_bytes == second_bytes))

  -- --- (7) the fixture, to a SCRATCH path ------------------------------------------------------
  tmp <- getTemporaryDirectory
  let out_dir = tmp </> "cfmm-spike-end-to-end"
      out_path = out_dir </> "volume_path.json"
  createDirectoryIfMissing True out_dir
  BS.writeFile out_path second_bytes
  putStrLn ("FIXTURE   " ++ out_path)
  putStrLn ("FIXTURE   sha256 " ++ sha256_hex second_bytes ++ "  " ++ show (BS.length second_bytes)
             ++ " bytes")
  putStrLn "=== SPIKE COMPLETE ==============================================================="

-- ---------------------------------------------------------------------------------------------
-- Diagnosis
-- ---------------------------------------------------------------------------------------------

-- | Every fact an abort carries, including the one 'Decision' cannot pass on.
report_abort :: String -> AbortReason -> Int -> CapturedStreams -> IO ()
report_abort tag why code streams = do
  let line = abort_line (cs_log streams)
  putStrLn (tag ++ "  ABORTED " ++ show why ++ " at exit " ++ show code)
  putStrLn (tag ++ "  abort line in volume_path.log: " ++ maybe "none" show line)
  putStrLn (tag ++ "  " ++ classify_abort line)
  putStrLn (tag ++ "  log " ++ show (BS.length (cs_log streams)) ++ " bytes, stdout "
             ++ show (BS.length (cs_stdout streams)) ++ ", stderr "
             ++ show (BS.length (cs_stderr streams)))

-- | The model's own source line, read out of the run's log.
--
-- 26-PROVER-SWEEP: the abort message reaches neither stdout nor stderr (both MEASURED at 0 bytes in
-- every GAMS mode), it lands in @volume_path.log@ in @curdir@, and it names the LINE.
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

-- | Which of the two kinds of exit 3 this is. 26-PROVER-SWEEP measured that exit 3 means at least
-- six different things and that the exit code alone cannot tell them apart.
classify_abort :: Maybe Int -> String
classify_abort Nothing = "no source-line abort in the log: this run did not halt at an abort$"
classify_abort (Just 109) =
  "line 109 = THE ELLIPSE REFUSAL. The fee pair is INADMISSIBLE at this delta*, which is a fixture"
    ++ " choice and is exactly what Fee.Split.is_admissible predicts; move delta*, not the volume."
classify_abort (Just n)
  | n == 171 || n == 173 =
      "line " ++ show n ++ " = CONOPT INFEASIBLE. The point is ADMISSIBLE and the solver could not"
        ++ " reach it at this volTgtWad/nEvents. Do NOT raise volTgtWad -- six values and three"
        ++ " nEvents settings were swept and all still abort."
  | n == 91 = "line 91 = equal fees, which Fee.Split refuses before any process exists."
  | otherwise =
      "line " ++ show n ++ " = one of the other aborts 26-PROVER-SWEEP catalogued (103 kappa range,"
        ++ " 195-199 tolerance misses, 77/88/89/90 input shape). Read volume_path.gms at that line."

show_decision :: Decision -> String
show_decision (Elided _)          = "Elided"
show_decision (Stored _)          = "Stored"
show_decision (NotPersisted w c)  = "NotPersisted " ++ show w ++ " at exit " ++ show c

die :: [String] -> IO a
die messages = do
  mapM_ (hPutStrLn stderr) messages
  exitFailure

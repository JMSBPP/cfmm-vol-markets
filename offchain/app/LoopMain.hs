{-# LANGUAGE OverloadedStrings #-}
-- |
-- THE RESIDENT LOOP'S EXECUTABLE. Thin by construction: it resolves, it detects, it wires, it
-- loops, and it exits by 'Loop.Config.exit_table'. Every decision it makes is somebody else's
-- function, called once.
--
-- It is an EXECUTABLE and not a check for the reason every capture in this package is one: it
-- reaches a chain, a database and a solver, and @cabal test@ reaches none of the three. The
-- LOOP-01 proofs live in the suite, driven against synthetic logs and @Store.Memory@; what is here
-- is the composition those proofs cannot exercise.
--
-- WHY THE RESOLVING MODULE IS IMPORTED HERE AND NEVER UNDER @offchain\/lib\/Loop\/@
-- --------------------------------------------------------------------------------
-- That is what keeps S2 closed. 28-01's ruling: resolution is a STARTUP precondition, so the
-- solver seam takes already-resolved paths and no @AbortReason@ has to lie about a startup fact.
-- The structural property is the DIRECTORY -- every importer of the resolving module is under
-- @offchain\/app\/@ -- and @grep -rc@ over @offchain\/lib\/Loop\/@ reports 0 for every file there.
--
-- EVERY EXIT IS A CODE FROM ONE TABLE
-- ----------------------------------
-- Preconditions exit by 'Loop.Config.exit_code_for_precondition' and halts by
-- 'Loop.Config.exit_code_for_halt'. Nothing in this file writes a number.
--
-- PUBLICATION IS REAL FROM 28-03 ON
-- --------------------------------
-- The directory comes from 'Loop.Config.fixture_dir' -- one resolver, an env override, a
-- repo-relative default -- and the writing is 'Loop.Publish.publish_fixture', called from
-- 'Loop.Run' for every outcome that carries an artifact. This file no longer states the fixture
-- path: it resolves it, which is what makes @FIXTURE_DIR@ something a falsification can be aimed
-- through.
--
-- CHAIN-01 IS BLOCKED, AND THIS EXECUTABLE IS WHERE THAT IS FELT. Issue #26 is the plank
-- workstream landing a contract that MINES a @Shock@; until it does, the rig manifest names no
-- emitter and the chain-surface precondition below stops with that sentence. Nothing in
-- @cabal test@ waits on it.
module Main (main) where

import qualified Data.ByteString.Char8 as C8
import Data.List (isInfixOf)
import qualified Data.Text as T
import System.Directory (doesDirectoryExist, getHomeDirectory)
import System.Environment (getArgs, getProgName)
import System.Exit (ExitCode (ExitFailure), exitSuccess, exitWith)
import System.FilePath (takeFileName, (</>))
import System.IO (hPutStrLn, stderr)

import Crypto.Ethereum.Utils (keccak256)
import Data.Solidity.Prim.Address (Address, toHexString)

import Chain.Shock (shock_signature)
import Gams.Detect (detect_toolchain)
import Gams.Env (whitelist_for)
import Gams.Invoke (raw_budget_s, raw_kill_after_s, resolve_gams_bin, resolve_gams_model)
import Loop.Chain (resolved_chain_source)
import Loop.Config
  ( Halt
  , Precondition (..)
  , exit_code_for_halt
  , exit_code_for_precondition
  , exit_usage
  , fixture_dir
  , fixture_file_name
  , loop_poll_ms
  )
import Loop.Ledger (new_postgres_ledger)
import Loop.Poll (ChainSource (..))
import Loop.Run (Env (..), Mode (..), run_loop)
import Loop.Solve (ProverPaths (..), solver_for)
import qualified Rig.Manifest as Rig
import Store.Config (migrations_dir, pgstore_dsn)
import Store.Key (key_identity)
import Store.Postgres (new_postgres_store, run_migrations_or_exit, with_connection)
import Store.Types (current_key_scheme)
import VolOrder.Decode (be_integer, hex_to_integer)

-- ---------------------------------------------------------------------------------------------
-- The values this plan does not yet resolve, stated once and labelled
-- ---------------------------------------------------------------------------------------------

-- | The contract in the rig manifest that EMITS the shock this loop consumes.
--
-- It does not exist on the rig yet. The name is stated here so the precondition failure can quote
-- it rather than saying \"a contract\".
shock_emitter_contract :: T.Text
shock_emitter_contract = "ShockWriter"

-- | The @Shock@ event's topic0, RECOMPUTED from the signature string the decoder states.
--
-- Never transcribed and never read from a pin file: the decoder and the filter must agree about
-- which event this is, and the only way to guarantee that is for both to derive it from the one
-- string. There is no @Shock@ entry in @offchain\/rig\/rig-pins.json@ today for the same reason
-- there is no emitter -- CHAIN-01.
shock_topic0 :: Integer
shock_topic0 = be_integer (keccak256 (C8.pack shock_signature))

-- | @VOLUME_PATH.md@ section 2's fixture volume target, in wad, and its event count.
--
-- These are the two shock fields that come from neither the log nor the pool read, and they are
-- the fixture's own values rather than a resolver's, because nothing in phases 23-28 has yet said
-- where a live one would come from. They are NOT zero: a zero volume target is refused by the
-- argument renderer for every fee pair, so a placeholder there would make every event inadmissible
-- and the ledger would fill with refusals that say nothing about the chain.
loop_vol_tgt_wad :: Integer
loop_vol_tgt_wad = 28000000000000000000

loop_n_events :: Integer
loop_n_events = 8

-- ---------------------------------------------------------------------------------------------
-- Entry point
-- ---------------------------------------------------------------------------------------------

main :: IO ()
main = do
  args <- getArgs
  mode <- parse_mode args

  -- (1) THE CHAIN SURFACE. The endpoint is resolved ONCE, by the module that owns the transport,
  --     and returned alongside the source so this file reports the authority it actually used.
  rig     <- Rig.load_rig
  manager <- required (Rig.resolve_contract rig "PoolManager")
  emitter <- required (Rig.resolve_contract rig shock_emitter_contract)
  pool_id <- required_pool rig
  (endpoint, source) <- resolved_chain_source manager emitter shock_topic0
  putStrLn ("ENDPOINT  " ++ endpoint)
  putStrLn ("SOURCE    " ++ source_label source)

  -- (2) THE PROVER PATHS. Here, in app/, and never in offchain/lib/Loop/.
  binary <- precondition_either (ProverPathsUnresolvable . show) =<< resolve_gams_bin
  model  <- precondition_either (ProverPathsUnresolvable . show) =<< resolve_gams_model
  putStrLn ("TOOLCHAIN " ++ binary)
  putStrLn ("MODEL     " ++ model)

  -- (3) S1: THE IDENTITY, BEFORE THE FIRST SOLVE.
  environment <- whitelist_for <$> getHomeDirectory
  detected  <- detect_toolchain binary model (Just environment)
  toolchain <- precondition_either (ToolchainUnreadable . show) detected
  ident     <- precondition_either (ToolchainUnreadable . show) (key_identity toolchain)
  putStrLn "IDENTITY  probed once, with no production model and no production solve"

  -- (4) LOOP-04: THE PUBLICATION DIRECTORY. The loop never creates it. One resolver, and the
  --     failure names the path it RESOLVED rather than the default it might not have used.
  publish_dir <- fixture_dir
  there <- doesDirectoryExist publish_dir
  if there then pure () else stop (FixtureDirMissing (publish_dir </> fixture_file_name))

  -- The chain id the fixture is stamped with, asked for ONCE.
  chain <- source_chain_id source
  putStrLn ("CHAIN ID  " ++ show chain)

  -- (5) THE STORE AND THE LEDGER, on one connection.
  dsn  <- pgstore_dsn
  poll <- loop_poll_ms
  with_connection dsn $ \connection -> do
    run_migrations_or_exit connection migrations_dir
    (solver, read_identity) <-
      solver_for ProverPaths
        { pp_binary       = binary
        , pp_model        = model
        , pp_env          = Just environment
        , pp_budget_s     = raw_budget_s
        , pp_kill_after_s = raw_kill_after_s
        }
    let env = Env
          { env_store         = new_postgres_store connection
          , env_ledger        = new_postgres_ledger connection
          , env_solver        = solver
          , env_read_identity = read_identity
          , env_source        = source
          , env_model         = takeFileName model
          , env_scheme        = current_key_scheme
          , env_emitter       = hex_to_integer (toHexString emitter)
          , env_topic0        = shock_topic0
          , env_pool_id       = pool_id
          , env_chain_id      = chain
          , env_vol_tgt_wad   = loop_vol_tgt_wad
          , env_n_events      = loop_n_events
          , env_fixture_dir   = publish_dir
          , env_poll_ms       = poll
          , env_log           = putStrLn
          }
    finished <- run_loop mode env ident
    case finished of
      Right ()    -> exitSuccess
      Left halted -> halt halted

-- ---------------------------------------------------------------------------------------------
-- Arguments
-- ---------------------------------------------------------------------------------------------

-- | @--once@ or nothing. One argument, because the mode decides one thing.
parse_mode :: [String] -> IO Mode
parse_mode args
  | any (`elem` ["--help", "-h"]) args = do
      self <- getProgName
      mapM_ putStrLn (usage self)
      exitSuccess
  | args == ["--once"] = pure Once
  | null args          = pure Resident
  | otherwise = do
      self <- getProgName
      mapM_ (hPutStrLn stderr) (("unrecognised arguments: " ++ unwords args) : usage self)
      exitWith (ExitFailure exit_usage)

usage :: String -> [String]
usage self =
  [ "usage: " ++ self ++ " [--once]"
  , ""
  , "  (no arguments)  run forever, polling the head at LOOP_POLL_MS."
  , "  --once          process every block from the watermark to the current head, then exit 0."
  , ""
  , "Both are ONE iteration function; the mode decides only whether it is re-entered."
  , "Every exit is a code from Loop.Config.exit_table."
  ]

-- ---------------------------------------------------------------------------------------------
-- Exits
-- ---------------------------------------------------------------------------------------------

-- | A precondition failure, by the table.
stop :: Precondition -> IO a
stop p = do
  hPutStrLn stderr ("PRECONDITION " ++ show p)
  hPutStrLn stderr (precondition_advice p)
  exitWith (ExitFailure (exit_code_for_precondition p))

-- | A halt, by the table.
halt :: Halt -> IO a
halt h = do
  hPutStrLn stderr ("HALT " ++ show h)
  exitWith (ExitFailure (exit_code_for_halt h))

-- | What an operator can do about it. Prose, on stderr, beside the machine-readable exit code.
precondition_advice :: Precondition -> String
precondition_advice (FixtureDirMissing path) =
  "  The loop NEVER creates the publication directory (LOOP-04). " ++ path
    ++ " is owned by the mev_tax_model_one track -- GitHub issues #24 and #25. This is a STOP"
    ++ " rather than a publication to a path this workstream invented. Point FIXTURE_DIR at a"
    ++ " directory that exists to publish somewhere else."
precondition_advice (ToolchainUnreadable why) =
  "  The startup probe could not name the toolchain: " ++ why
    ++ ". An empty key component is never written, so there is nothing to fall back to."
precondition_advice (EndpointUnresolvable why) =
  "  The chain surface could not be resolved: " ++ why
precondition_advice (ProverPathsUnresolvable why) =
  "  " ++ why ++ ". Resolution is a startup precondition, which is why it is reported here rather"
    ++ " than as a solver failure."
precondition_advice (LedgerUnreachable why) =
  "  The ledger could not be reached: " ++ why

-- | An @Either@ from a resolver, or a precondition exit.
precondition_either :: (a -> Precondition) -> Either a b -> IO b
precondition_either as_precondition = either (stop . as_precondition) pure

-- | A rig lookup, or a precondition exit that quotes what was looked for.
required :: Either String Address -> IO Address
required (Right address) = pure address
required (Left why)      = stop (EndpointUnresolvable (why ++ chain01_note why))

-- | The pool id, from the manifest, as the number the reads take.
required_pool :: Rig.Rig -> IO Integer
required_pool rig =
  case Rig.hex_to_integer "pool.poolId" (Rig.rig_pool_id (Rig.rig_pool (Rig.rig_addrs rig))) of
    Right n  -> pure n
    Left why -> stop (EndpointUnresolvable why)

-- | The one sentence CHAIN-01 is owed, attached to the one failure that means it.
chain01_note :: String -> String
chain01_note why
  | T.unpack shock_emitter_contract `isInfixOf` why =
      ". CHAIN-01 IS BLOCKED: GitHub issue #26 is the plank workstream landing a contract that"
        ++ " MINES a Shock event, and until it does the rig manifest names no emitter. Every"
        ++ " LOOP-01 proof in cabal test is chain-free by construction and does not wait on it;"
        ++ " this executable does."
  | otherwise = ""

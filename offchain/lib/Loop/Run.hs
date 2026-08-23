-- |
-- ONE ITERATION FUNCTION, AND THE MODE DECIDES ONLY WHETHER IT IS RE-ENTERED.
--
-- 'process_block' is the whole pipeline for a single block. 'run_loop' picks the blocks and, in
-- 'Resident', sleeps when caught up. There is no second code path: @--once@ is not a rehearsal of
-- the resident loop, it IS the resident loop with the re-entry removed, which is what makes the
-- LOOP-01 restart proof evidence about the thing that runs in production.
--
-- WHY A QUIET BLOCK STILL COMMITS
-- ------------------------------
-- A block with no logs commits an EMPTY row list and advances the watermark anyway. That is what
-- makes a restart skip a quiet stretch instead of re-scanning it, and it is why
-- 'Loop.Ledger.ledger_commit_block' takes the block and its rows in one call: a watermark that
-- could be advanced separately from the rows it covers would let a caller advance it for a block
-- whose rows were refused.
--
-- WHERE THE HALT SITS RELATIVE TO THE COMMIT
-- ------------------------------------------
-- BEFORE it. A @cl_halts@ outcome returns without committing, so the watermark is not advanced
-- past that block and a restart re-processes it. 28-CONTEXT gives the two failure classes opposite
-- policies and 28-01 MEASURED that they already arrive on two different constructors: an
-- inadmissible shock is refused before the solver is reachable and gets a row, an unsolvable one
-- reached the solver and stops the loop.
--
-- WHY A CACHE HIT IS STILL PUBLISHED
-- ----------------------------------
-- The fixture tracks the newest EVENT, not the newest solve. An @elided@ outcome carries the
-- stored bytes and they are published, stamped with the block THIS event was read at. The bytes
-- are content-keyed and the identity fields are per-event; those are different things and 28-CONTEXT
-- rules that the second one is what the consuming test attaches to.
--
-- WHY THERE IS NO JSON LIBRARY HERE
-- ---------------------------------
-- @offchain\/lib\/Loop@ is on the scanned artifact path, and the report line is rendered by hand
-- for the same reason @Chain.Read.render_fixture_identity@ is: a re-render of numbers by a general
-- serializer is exactly the failure mode BYTE-03 exists to prevent, and a line that leaves this
-- workstream and is parsed by CI is a place where a reordered key costs a day.
module Loop.Run
  ( -- * The mode
    Mode (..)
    -- * What one iteration needs
  , Env (..)
    -- * What one iteration reports
  , EventReport (..)
  , BlockReport (..)
  , block_report_line
    -- * The iteration, and the loop around it
  , process_block
  , run_loop
    -- * The drift ruling, as a pure function
  , adopt_identity
  , render_key_identity
    -- * The per-event splitter seed
  , split_seed
    -- * Re-exported so a caller needs one import to decide its exit
  , Halt (..)
  ) where

import Control.Concurrent (threadDelay)
import Control.Exception (SomeException, try)
import Data.Bits (shiftL)
import Data.List (intercalate, sortOn)
import Data.Word (Word32)

import Network.Ethereum.Api.Types (Change)

import Chain.Read (BlockRef (AtBlock))
import Chain.Shock (ShockEvent (..), decode_shock)
import Fee.Split (FeeSplit (..), refusal_message, split_for)
import Gams.Argv (Shock (..))
import Gams.Version (conopt_version_text, gams_version_text)
import Loop.Config (Halt (..))
import Loop.Ledger (EventId (..), Ledger (..), LedgerRow (..))
import Loop.Poll (ChainSource (..), event_identity, next_range)
import Loop.Solve (Classified (..), Outcome (..), classify, outcome_token)
import Store.Cache (decide)
import Store.Class (Store)
import Store.Key (ContentKey (..), KeyIdentity (..), content_key, content_key_hex, key_identity)
import Store.Solver (Solver)
import Store.Types (Artifact, KeyScheme)
import Gams.Run (ToolchainIdentity)

-- ---------------------------------------------------------------------------------------------
-- The mode
-- ---------------------------------------------------------------------------------------------

-- | Whether the iteration is re-entered. NOTHING else differs between the two.
data Mode
  = Once
    -- ^ process every block from the watermark to the current head, then return.
  | Resident
    -- ^ the same, forever, sleeping when caught up.
  deriving (Eq, Show)

-- ---------------------------------------------------------------------------------------------
-- What one iteration needs
-- ---------------------------------------------------------------------------------------------

-- | Everything an iteration touches, as values it was handed.
--
-- The pool MANAGER is deliberately not a field: it is closed over by 'source_reads', which is the
-- only thing that uses it, and a record field whose value is never the one used is a value that
-- can drift with nothing noticing.
data Env = Env
  { env_store         :: Store
  , env_ledger        :: Ledger
  , env_solver        :: Solver
  , env_read_identity :: IO (Maybe ToolchainIdentity)
    -- ^ the stash "Loop.Solve" writes on every completed run. This is the ONLY route to the
    -- toolchain a solve actually used, because @Store.Cache.decide@ throws it away.
  , env_source        :: ChainSource
  , env_model         :: String
    -- ^ the model NAME the key is over -- a basename, never a path.
  , env_scheme        :: KeyScheme
  , env_emitter       :: Integer
    -- ^ the contract the logs must have been emitted BY. An event topic is unauthenticated.
  , env_topic0        :: Integer
  , env_pool_id       :: Integer
  , env_vol_tgt_wad   :: Integer
  , env_n_events      :: Integer
  , env_fixture_path  :: FilePath
  , env_publish       :: Integer -> Artifact -> IO ()
    -- ^ block and bytes. 28-03 supplies the atomic implementation; the block is an argument
    -- because the fixture is stamped with the block the EVENT was read at.
  , env_poll_ms       :: Int
  , env_log           :: String -> IO ()
  }

-- ---------------------------------------------------------------------------------------------
-- What one iteration reports
-- ---------------------------------------------------------------------------------------------

-- | One decided event, as the report line carries it.
data EventReport = EventReport
  { er_tx         :: !String
  , er_log_index  :: !Integer
  , er_outcome    :: !String
  , er_key_prefix :: !String
    -- ^ the first sixteen hex characters of the content key, or the empty string for an
    -- inadmissible event -- which has no key, because it was refused before one could be computed.
  } deriving (Eq, Show)

-- | One block, as the report line carries it.
data BlockReport = BlockReport
  { br_block     :: !Integer
  , br_events    :: !Int
  , br_published :: !Bool
  , br_fixture   :: !FilePath
  , br_outcomes  :: ![EventReport]
  , br_halt      :: !(Maybe Halt)
    -- ^ @Just@ means this block was NOT committed and the watermark did not move.
  , br_notes     :: ![String]
    -- ^ everything that happened which is not an outcome: a skipped replay, a log that could not
    -- be decoded, an adopted toolchain identity.
  } deriving (Eq, Show)

-- ---------------------------------------------------------------------------------------------
-- The report line
-- ---------------------------------------------------------------------------------------------

-- | ONE LINE PER BLOCK, rendered by hand.
--
-- The field order is fixed and stated once, here. Notes are NOT in the line: they go to the same
-- stream as prose through 'env_log', because a machine-parseable line whose shape depends on
-- whether something unusual happened is a line no consumer can rely on.
block_report_line :: BlockReport -> String
block_report_line report =
  "{\"block\":" ++ show (br_block report)
    ++ ",\"events\":" ++ show (br_events report)
    ++ ",\"published\":" ++ (if br_published report then "true" else "false")
    ++ ",\"fixture\":" ++ json_token (br_fixture report)
    ++ ",\"outcomes\":[" ++ intercalate "," (map event_object (br_outcomes report)) ++ "]}"
  where
    event_object e =
      "{\"tx\":" ++ json_token (er_tx e)
        ++ ",\"logIndex\":" ++ show (er_log_index e)
        ++ ",\"outcome\":" ++ json_token (er_outcome e)
        ++ ",\"keyPrefix\":" ++ json_token (er_key_prefix e)
        ++ "}"

-- | A JSON string token.
--
-- Two characters are escaped and no more, and that is a CONTRACT rather than an omission: three of
-- the four values that reach this function are a hex token, an outcome word from a fixed
-- vocabulary and a hex prefix, none of which can carry either. The fourth is a filesystem path,
-- which can -- so it is escaped rather than assumed innocent.
json_token :: String -> String
json_token s = '"' : concatMap esc s ++ "\""
  where
    esc '"'  = "\\\""
    esc '\\' = "\\\\"
    esc c    = [c]

-- | The first sixteen hex characters of a key. Enough to tell two runs apart in a log and short
-- enough to read; the ledger holds the whole key.
key_prefix_of :: ContentKey -> String
key_prefix_of = take 16 . content_key_hex

-- ---------------------------------------------------------------------------------------------
-- The drift ruling
-- ---------------------------------------------------------------------------------------------

-- | A key identity as one line, so two of them can be COMPARED and NAMED by the same expression.
--
-- Rendered rather than derived through equality on purpose: the note the loop logs has to say what
-- changed, and a comparison made by one expression and a message built by another is two places
-- for the same question.
render_key_identity :: KeyIdentity -> String
render_key_identity ident =
  "gams " ++ gams_version_text (ki_gams_version ident)
    ++ " conopt " ++ conopt_version_text (ki_conopt_version ident)
    ++ " sources " ++ show (ki_model_sources ident)

-- | THE USER RULING OF 28-CONTEXT, AS A PURE FUNCTION: ADOPT AND CONTINUE.
--
-- When a completed run reports a toolchain that differs from the pinned one, the NEW identity is
-- returned along with a note naming both. The loop logs the note and keeps going; it does not
-- halt. A resident process is not stopped for a toolchain upgrade.
--
-- What makes that safe is the ledger rather than this function: every row carries the versions
-- that KEYED it, so the switch is reconstructible after the fact from rows that were already
-- being written. A drift policy whose only record was a log line would be a policy nobody could
-- audit.
--
-- Two returns are the same value with different reasons, and they are kept apart in the NOTE: a
-- reported identity that cannot become a key identity is not adopted, because a key cannot be
-- computed from it -- so the pinned one is kept and the refusal is said out loud. Silently
-- keeping it would make an unusable toolchain look like an unchanged one.
adopt_identity
  :: KeyIdentity
  -> Maybe ToolchainIdentity
  -> (KeyIdentity, Maybe String)
adopt_identity pinned Nothing = (pinned, Nothing)
adopt_identity pinned (Just reported) =
  case key_identity_of reported of
    Left why ->
      ( pinned
      , Just ("TOOLCHAIN the completed run reported an identity that cannot key anything ("
               ++ why ++ "). The pinned identity is KEPT: " ++ render_key_identity pinned) )
    Right fresh
      | render_key_identity fresh == render_key_identity pinned -> (pinned, Nothing)
      | otherwise ->
          ( fresh
          , Just ("TOOLCHAIN ADOPTED. was: " ++ render_key_identity pinned
                   ++ " -- now: " ++ render_key_identity fresh
                   ++ ". The loop continues; every row from here carries the new versions, so the"
                   ++ " switch is reconstructible from the ledger.") )

-- | 'Store.Key.key_identity' with its refusal rendered, so 'adopt_identity' stays pure and total.
key_identity_of :: ToolchainIdentity -> Either String KeyIdentity
key_identity_of reported =
  case key_identity reported of
    Left why -> Left (show why)
    Right ok -> Right ok

-- ---------------------------------------------------------------------------------------------
-- The splitter seed
-- ---------------------------------------------------------------------------------------------

-- | The seed the fee splitter picks a pair with, derived from the event's POSITION.
--
-- Deterministic in the event and in nothing else. That matters because the chosen pair is an input
-- to the content key: a seed drawn from a clock or a counter would give the same shock a different
-- key on every run, and the store would never elide anything. The position is the one thing about
-- an event that a replay reproduces exactly.
-- The reduction to thirty-two bits is 'fromInteger' at 'Data.Word.Word32', which is defined to be
-- the modular one. A hand-written mask here would be an eight-hex literal on a line that has
-- nothing to do with a selector, and 'sc3_literal_purge' reads it as one -- MEASURED at 28-02,
-- which is how this note came to exist.
split_seed :: Integer -> Integer -> Word32
split_seed block log_index = fromInteger ((block `shiftL` 16) + log_index)

-- ---------------------------------------------------------------------------------------------
-- One block
-- ---------------------------------------------------------------------------------------------

-- | The pipeline for ONE block, ending in ONE commit.
--
-- The logs are ordered by @(blockNumber, logIndex)@ before anything is decided, because the
-- ledger's chronology is the chain's and not the transport's: nothing in the JSON-RPC contract
-- promises an order, and a ledger written in arrival order would record a chronology that depends
-- on which node answered.
process_block :: Env -> KeyIdentity -> Integer -> IO (KeyIdentity, BlockReport)
process_block env ident block = do
  logs <- source_logs (env_source env) block block
  outcome <- step ident (sortOn event_index logs) [] [] [] False
  case outcome of
    Left (halted, ident', reports, notes, published) ->
      pure (ident', (blank reports notes published) { br_halt = Just halted })
    Right (ident', rows, reports, notes, published) -> do
      committed <- try (ledger_commit_block (env_ledger env) block (reverse rows))
      case committed of
        Left err ->
          pure ( ident'
               , (blank reports notes published)
                   { br_halt = Just (HaltDb (show (err :: SomeException))) } )
        Right () -> pure (ident', blank reports notes published)
  where
    blank reports notes published = BlockReport
      { br_block     = block
      , br_events    = length reports
      , br_published = published
      , br_fixture   = env_fixture_path env
      , br_outcomes  = reverse reports
      , br_halt      = Nothing
      , br_notes     = reverse notes
      }

    step current [] rows reports notes published =
      pure (Right (current, rows, reports, notes, published))
    step current (entry : rest) rows reports notes published =
      case event_identity entry of
        Left why -> step current rest rows reports (note block why : notes) published
        Right eid -> do
          already <- ledger_seen (env_ledger env) eid
          if already
            then
              step current rest rows reports
                (note block ("SKIP the event at " ++ ev_tx_hash eid ++ "#"
                              ++ show (ev_log_index eid) ++ " is already in the ledger: no row and"
                              ++ " no solve. A replay must leave the pipeline doing NOTHING.")
                  : notes)
                published
            else
              case decode_shock (env_topic0 env) (env_emitter env) entry of
                Left why ->
                  step current rest rows reports
                    (note block ("SKIP the log at " ++ ev_tx_hash eid ++ "#"
                                  ++ show (ev_log_index eid) ++ " is not a shock for this loop: "
                                  ++ show why) : notes)
                    published
                Right shock_event -> do
                  read_back <- source_reads (env_source env) (env_pool_id env) (AtBlock block)
                  case read_back of
                    Left why ->
                      pure (Left ( HaltRpcExhausted block 1
                                 , current
                                 , reports
                                 , note block ("READ the pinned pool read at block " ++ show block
                                                ++ " refused: " ++ why) : notes
                                 , published ))
                    Right (price, liquidity, lp_fee) ->
                      decided current rest rows reports notes published eid shock_event
                        price liquidity lp_fee

    decided current rest rows reports notes published eid shock_event price liquidity lp_fee =
      let dstar = se_norm_rate shock_event
          seed  = split_seed block (ev_log_index eid)
      in case split_for seed lp_fee dstar of
           Left refusal ->
             let reason = refusal_message refusal
                 row = LedgerRow
                   { lr_event      = eid
                   , lr_block      = block
                   , lr_model      = env_model env
                   , lr_key_scheme = env_scheme env
                   , lr_key        = Nothing
                   , lr_outcome    = OutcomeInadmissible
                   , lr_reason     = reason
                   , lr_gams_ver   = gams_version_text (ki_gams_version current)
                   , lr_conopt_ver = conopt_version_text (ki_conopt_version current)
                   }
                 entry_report = EventReport
                   { er_tx         = ev_tx_hash eid
                   , er_log_index  = ev_log_index eid
                   , er_outcome    = outcome_token OutcomeInadmissible
                   , er_key_prefix = ""
                   }
             in step current rest (row : rows) (entry_report : reports) notes published
           Right fee ->
             let shock = Shock
                   { sh_sqrt_price_x96  = price
                   , sh_liquidity_raw   = liquidity
                   , sh_txl_volume_rate = fs_dstar_pips fee
                   , sh_phi_x_pips      = fs_phi_x_pips fee
                   , sh_phi_m_pips      = fs_phi_m_pips fee
                   , sh_vol_tgt_wad     = env_vol_tgt_wad env
                   , sh_n_events        = env_n_events env
                   }
             in do
               answered <-
                 try (decide (env_store env) (env_solver env) (env_scheme env)
                        (env_model env) shock current)
               case answered of
                 Left err ->
                   pure (Left ( HaltSolverException (show (err :: SomeException))
                              , current
                              , reports
                              , note block ("SOLVER the seam threw rather than returning an"
                                             ++ " outcome for the event at " ++ ev_tx_hash eid)
                                  : notes
                              , published ))
                 Right verdict -> do
                   let decision = classify verdict
                       prefix = case content_key (env_scheme env) (env_model env) shock current of
                                  Right key -> key_prefix_of key
                                  Left _    -> ""
                       row = LedgerRow
                         { lr_event      = eid
                         , lr_block      = block
                         , lr_model      = env_model env
                         , lr_key_scheme = env_scheme env
                         , lr_key        = case content_key (env_scheme env) (env_model env)
                                                  shock current of
                                             Right (ContentKey bytes) -> Just bytes
                                             Left _                   -> Nothing
                         , lr_outcome    = cl_outcome decision
                         , lr_reason     = cl_reason decision
                         , lr_gams_ver   = gams_version_text (ki_gams_version current)
                         , lr_conopt_ver = conopt_version_text (ki_conopt_version current)
                         }
                       entry_report = EventReport
                         { er_tx         = ev_tx_hash eid
                         , er_log_index  = ev_log_index eid
                         , er_outcome    = outcome_token (cl_outcome decision)
                         , er_key_prefix = if cl_outcome decision == OutcomeInadmissible
                                             then ""
                                             else prefix
                         }
                   published' <- case cl_artifact decision of
                     Nothing -> pure published
                     Just bytes -> do
                       env_publish env block bytes
                       pure True
                   reported <- env_read_identity env
                   let (next_ident, drift) = adopt_identity current reported
                       notes' = maybe notes (\n -> note block n : notes) drift
                   if cl_halts decision
                     then pure (Left ( HaltUnsolvable eid
                                     , next_ident
                                     , entry_report : reports
                                     , notes'
                                     , published' ))
                     else
                       step next_ident rest (row : rows) (entry_report : reports) notes' published'

-- | @(blockNumber, logIndex)@, with an absent field sorting first so an unidentifiable log is
-- refused in a stable place rather than wherever the transport happened to put it.
event_index :: Change -> (Integer, Integer)
event_index entry =
  case event_identity entry of
    Right eid -> (0, ev_log_index eid)
    Left _    -> (-1, 0)

-- | A note, stamped with the block it happened in.
note :: Integer -> String -> String
note block message = "block " ++ show block ++ ": " ++ message

-- ---------------------------------------------------------------------------------------------
-- The loop around it
-- ---------------------------------------------------------------------------------------------

-- | Blocks in, halts out. The mode decides ONE thing.
--
-- The watermark is re-read from the LEDGER on every pass rather than carried in a local: the
-- watermark is a row in the store, and a loop that trusted its own memory of it would report a
-- restart-safe watermark while holding an in-process one. That is the difference LOOP-01 is about.
run_loop :: Mode -> Env -> KeyIdentity -> IO (Either Halt ())
run_loop mode env = pass
  where
    pass ident = do
      watermark  <- ledger_watermark (env_ledger env)
      head_block <- source_head (env_source env)
      case next_range watermark head_block of
        Nothing -> caught_up ident
        Just (from, to) -> do
          walked <- walk ident from to
          case walked of
            Left halted   -> pure (Left halted)
            Right ident'  -> case mode of
              Once     -> pure (Right ())
              Resident -> pass ident'

    caught_up ident = case mode of
      Once     -> pure (Right ())
      Resident -> do
        threadDelay (env_poll_ms env * 1000)
        pass ident

    walk ident b to
      | b > to = pure (Right ident)
      | otherwise = do
          (ident', report) <- process_block env ident b
          env_log env (block_report_line report)
          mapM_ (env_log env) (br_notes report)
          case br_halt report of
            Just halted -> pure (Left halted)
            Nothing     -> walk ident' (b + 1) to
